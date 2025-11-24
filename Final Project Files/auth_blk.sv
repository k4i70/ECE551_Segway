module auth_blk (
    input logic RX,
    input logic clk, rst_n,
    output logic pwr_up,
    input logic rider_off
);

    logic [7:0] rx_data;
    logic rx_rdy;
    logic clr_rx_rdy;

    // Instantiate UART_RX
    UART_RX uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .clr_rdy(clr_rx_rdy),
        .rx_data(rx_data),
        .rdy(rx_rdy)
    );

    // auth_SM to manage power up
    // If block recieves a "G" on rx it will send pwr_up high
    // G is deasserted after the last reception was ‘S’ and the rider_off signal is high.
    // An S (0x53) is when the phone app disconnects or is disconnected. The segway should shut down
    typedef enum logic [1:0] {
        IDLE,
        POWERED_UP,
        WAIT_FOR_RIDER_OFF
    } auth_state_t;

    auth_state_t current_state, next_state;

    // State management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        // Default assignments
        next_state = current_state;
        pwr_up = 1'b0;
        clr_rx_rdy = 1'b0;

        case (current_state)
            IDLE: begin
                if (rx_rdy && (rx_data == 8'h47)) begin // 'G'
                    next_state = POWERED_UP;
                end
            end
            POWERED_UP: begin
                pwr_up = 1'b1;
                if (rx_rdy && (rx_data == 8'h53)) begin // 'S'
                    next_state = WAIT_FOR_RIDER_OFF;
                end
                if (rider_off) begin
                    next_state = IDLE;
                end
            end
            WAIT_FOR_RIDER_OFF: begin
                pwr_up = 1'b1;
                if (rider_off) begin
                    next_state = IDLE;
                end
            end
        endcase

        // Clear rx_rdy after processing
        if (rx_rdy) begin
            clr_rx_rdy = 1'b1;
        end
    end


endmodule 