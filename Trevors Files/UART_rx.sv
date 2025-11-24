module UART_rx(
    input clk,
    input rst_n,
    input RX,
    input clr_rdy,
    output reg [7:0] rx_data,
    output reg rdy
);

    parameter BAUD_DIV = 5208;

    reg [12:0] baud_cnt;
    reg [3:0] bit_cnt;
    reg [9:0] rx_shft_reg;
    reg receiving;
    reg RX_ff1, RX_ff2;
    
    typedef enum reg [1:0] {
        IDLE = 2'b00,
        RECEIVING = 2'b01
    } state_t;
    
    state_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            RX_ff1 <= 1'b1;
            RX_ff2 <= 1'b1;
        end else begin
            RX_ff1 <= RX;
            RX_ff2 <= RX_ff1;
        end
    end

    // Detect falling edge (start bit) - only when in IDLE state
    wire start = RX_ff2 & ~RX_ff1 & (state == IDLE);

    // Baud rate counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 13'd0;
        end else if (state == IDLE) begin
            baud_cnt <= 13'd0;
        end else if (start) begin
            // Start counting from half bit time when start bit detected
            baud_cnt <= (BAUD_DIV >> 1);  // Half bit time = 2604
        end else if (state == RECEIVING) begin
            if (baud_cnt == BAUD_DIV - 1) begin
                baud_cnt <= 13'd0;
            end else begin
                baud_cnt <= baud_cnt + 1'b1;
            end
        end
    end

    // Generate shift signal when baud counter reaches terminal count
    wire shift = (state == RECEIVING && baud_cnt == BAUD_DIV - 1);

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = RECEIVING;
                end else begin
                    next_state = IDLE;
                end
            end
            RECEIVING: begin
                if (bit_cnt == 4'd9 && shift) begin
                    next_state = IDLE;
                end else begin
                    next_state = RECEIVING;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Control signals
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            receiving <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        receiving <= 1'b1;
                    end
                end
                RECEIVING: begin
                    if (bit_cnt == 4'd9 && shift) begin
                        receiving <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Bit counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 4'd0;
        end else if (state == IDLE) begin
            bit_cnt <= 4'd0;  // Keep reset in IDLE
        end else if (shift) begin
            bit_cnt <= bit_cnt + 1'b1;
        end
    end

    // Shift register - shifts in data from RX, right shifting
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shft_reg <= 10'h000;  // Initialize to zeros
        end else if (shift) begin
            // Shift right, MSB gets current RX value (sample RX_ff1 for stability)
            rx_shft_reg <= {RX_ff1, rx_shft_reg[9:1]};
        end
    end

    // rx_data output - extract data bits from shift register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 8'h00;
        end else if (state == RECEIVING && bit_cnt == 4'd9 && shift) begin
            rx_data <= rx_shft_reg[8:1];
        end
    end

    // rdy signal
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdy <= 1'b0;
        end else if (clr_rdy || start) begin
            rdy <= 1'b0;  // Clear when clr_rdy asserted or starting new reception
        end else if (state == RECEIVING && bit_cnt == 4'd9 && shift) begin
            rdy <= 1'b1;
        end
    end

endmodule
