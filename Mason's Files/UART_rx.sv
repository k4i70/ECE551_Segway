module UART_rx (
    input logic clk,
    input logic rst_n,
    input logic RX,
    input logic clr_rdy,
    output logic rdy,
    output logic [7:0] rx_data
);
    // Internal signals
    logic start, shift, shift_receiving;
    logic [3:0] bit_cnt;
    logic [12:0] baud_cnt;
    logic [9:0] rx_shft_reg;
    logic set_rdy;
    
    // State machine states
    typedef enum logic [1:0] {IDLE, START, RECEIVING} state_t;
    state_t state, nxt_state;

    // Always block 1: State machine sequential logic
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

// Double flip-flop for RX signal (meta-stability protection)
logic RX_ff1, RX_ff2;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        RX_ff1 <= 1'b1;
        RX_ff2 <= 1'b1;
    end else begin
        RX_ff1 <= RX;
        RX_ff2 <= RX_ff1;
    end
end

    // Always block 2: State machine combinational logic
    always_comb begin
        nxt_state = state;
        start = 1'b0;
        shift_receiving = 1'b0;
        
        case (state)
            IDLE: begin
                if (!RX_ff2) begin  // Use synchronized RX signal
                    start = 1'b1;
                    nxt_state = RECEIVING;  // Go to RECEIVING state first
                end
            end
            RECEIVING: begin
                shift_receiving = 1'b1;
                if (bit_cnt == 4'd10)  // 8 data bits + stop bit
                    nxt_state = IDLE;
            end
        endcase
    end

// Shift signal generation
    always_comb begin
        shift = shift_receiving && (baud_cnt == 13'd0);
    end

// Always block 4b: Shift register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            rx_shft_reg <= 10'd0;  // Initialize shift register
        end else if (shift) begin
            rx_shft_reg <= {RX_ff2, rx_shft_reg[9:1]}; // Shift in received bit
        end
    end
    
    // Always block 3: Baud counter
    always_ff @(posedge clk) begin
        if (start)
            baud_cnt <= 13'd2603; // Half bit period (5208/2 - 1) for start bit centering
        else if (shift)
            baud_cnt <= 13'd5207; // Full bit period (5208 - 1) for data bits
        else if (shift_receiving)
            baud_cnt <= baud_cnt - 1'b1;
    end
    
    // Always block 4a: Bit counter
    always_ff @(posedge clk) begin
        if (start)
            bit_cnt <= 4'd0;
        else if (shift)
            bit_cnt <= bit_cnt + 1'b1;
    end
// Combinational logic to set rdy when a full byte is received
    always_comb begin
        set_rdy = 1'b0;
        if (bit_cnt == 4'd9) begin  // 8 data bits + stop bit received and shifted
            set_rdy = 1'b1;
        end
    end
    // Always block 5: Ready flag and output data
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            rdy <= 1'b0;
            rx_data <= 8'd0;  // Initialize rx_data on reset
        end else if (clr_rdy) begin
            rdy <= 1'b0;
            rx_data <= 8'd0;  // Clear rx_data when clr_rdy is asserted
        end else if (set_rdy) begin
            rdy <= 1'b1;
            rx_data <= rx_shft_reg[9:2];
        end
    end

endmodule