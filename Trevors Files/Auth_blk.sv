module Auth_blk(
    input clk,
    input rst_n,
    input RX,
    input rider_off,
    output pwr_up
);

    wire [7:0] rx_data;
    wire rx_rdy;
    reg clr_rx_rdy;
    
    typedef enum reg [1:0] {
        PWR_OFF = 2'b00,
        PWR_ON = 2'b01,
        WAIT_RIDER_OFF = 2'b10
    } state_t;
    
    state_t state, next_state;
    
    localparam GO_CODE = 8'h47;
    localparam STOP_CODE = 8'h53;
    
    UART_rx iUART_rx (
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .clr_rdy(clr_rx_rdy),
        .rx_data(rx_data),
        .rdy(rx_rdy)
    );
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= PWR_OFF;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic and output logic
    always_comb begin
        // Default values
        next_state = state;
        clr_rx_rdy = 1'b0;
        
        case (state)
            PWR_OFF: begin
                if (rx_rdy) begin
                    clr_rx_rdy = 1'b1;
                    if (rx_data == GO_CODE) begin
                        next_state = PWR_ON;
                    end
                    // Ignore STOP_CODE when already powered off
                end
            end
            
            PWR_ON: begin
                if (rx_rdy) begin
                    clr_rx_rdy = 1'b1;  // Clear the ready signal
                    if (rx_data == STOP_CODE) begin
                        if (rider_off) begin
                            // Rider is off, can power down immediately
                            next_state = PWR_OFF;
                        end else begin
                            // Rider still on, wait for rider to get off
                            next_state = WAIT_RIDER_OFF;
                        end
                    end
                    // Ignore GO_CODE when already powered on
                end
            end
            
            WAIT_RIDER_OFF: begin
                if (rx_rdy) begin
                    clr_rx_rdy = 1'b1;  // Clear the ready signal
                    if (rx_data == GO_CODE) begin
                        // New GO command received, stay powered on
                        next_state = PWR_ON;
                    end
                    // STOP_CODE doesn't change state, still waiting for rider off
                end else if (rider_off) begin
                    // Rider got off, now we can power down
                    next_state = PWR_OFF;
                end
            end
            
            default: next_state = PWR_OFF;
        endcase
    end
    
    // Output assignment
    assign pwr_up = (state == PWR_ON) || (state == WAIT_RIDER_OFF);

endmodule
