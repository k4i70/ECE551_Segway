module UART_tx(
    input clk,
    input rst_n,
    input trmt,
    input [7:0] tx_data,
    output reg TX,
    output reg tx_done
);

    parameter BAUD_DIV = 5208;

    reg [12:0] baud_cnt;
    reg [3:0] bit_cnt;
    reg [8:0] shift_reg;
    reg transmitting;
    
    typedef enum reg [1:0] {
        IDLE = 2'b00,
        TRANSMIT = 2'b01
    } state_t;
    
    state_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 13'd0;
        end else if (transmitting) begin
            if (baud_cnt == BAUD_DIV - 1) begin
                baud_cnt <= 13'd0;
            end else begin
                baud_cnt <= baud_cnt + 1'b1;
            end
        end else begin
            baud_cnt <= 13'd0;
        end
    end

    // Generate shift signal when baud counter reaches terminal count
    wire shift = transmitting && (baud_cnt == BAUD_DIV - 1);

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
                if (trmt) begin
                    next_state = TRANSMIT;
                end else begin
                    next_state = IDLE;
                end
            end
            TRANSMIT: begin
                if (bit_cnt == 4'd9 && shift) begin
                    next_state = IDLE;
                end else begin
                    next_state = TRANSMIT;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Control signals
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transmitting <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (trmt) begin
                        transmitting <= 1'b1;
                    end
                end
                TRANSMIT: begin
                    if (bit_cnt == 4'd9 && shift) begin
                        transmitting <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Bit counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 4'd0;
        end else if (state == IDLE && trmt) begin
            bit_cnt <= 4'd0;
        end else if (shift) begin
            bit_cnt <= bit_cnt + 1'b1;
        end
    end

    // Shift register - loads with start bit (0) + data, shifts right
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 9'h1FF;
        end else if (state == IDLE && trmt) begin
            // Load shift register with start bit (0) + tx_data
            shift_reg <= {tx_data, 1'b0};  // Start bit is LSB
        end else if (shift) begin
            // Shift right, fill with 1 (stop bit/idle)
            shift_reg <= {1'b1, shift_reg[8:1]};
        end
    end

    // TX output
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            TX <= 1'b1;  // Idle high
        end else if (transmitting) begin
            TX <= shift_reg[0];  // Output LSB
        end else begin
            TX <= 1'b1;  // Idle high
        end
    end

    // tx_done signal
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_done <= 1'b0;
        end else if (trmt) begin
            tx_done <= 1'b0;  // Clear when starting new transmission
        end else if (state == TRANSMIT && bit_cnt == 4'd9 && shift) begin
            tx_done <= 1'b1;
        end
    end

endmodule
