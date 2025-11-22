module UART_tx(
    input logic clk,
    input logic rst_n,
    input logic trmt,
    input logic [7:0] tx_data,
    output logic TX,
    output logic tx_done
);

    // Internal signals
    logic [12:0] baud_cnt;
    logic [3:0] bit_cnt;
    logic [8:0] tx_shft_reg;
    logic shift, load, transmitting, set_done;
    
    // State machine states
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        LOAD = 2'b01,
        TRANSMITTING = 2'b10
    } state_t;
    
    state_t state, next_state;

    // Always block 1: Baud rate counter
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 13'h0000;
        else if (shift || load)
            baud_cnt <= 13'h0000;
        else if (transmitting)
            baud_cnt <= baud_cnt + 1;
    end

    // Always block 2: Bit counter
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 4'h0;
        else if (load)
            bit_cnt <= 4'h0;
        else if (shift)
            bit_cnt <= bit_cnt + 1;
    end

    // Always block 3: Shift register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            tx_shft_reg <= 9'h1FF;
        else if (load)
            tx_shft_reg <= {tx_data, 1'b0}; // Load data with start bit
        else if (shift)
            tx_shft_reg <= {1'b1, tx_shft_reg[8:1]}; // Shift right, shift in stop bit
    end

    // Always block 4: State machine
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Always block 5: tx_done register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            tx_done <= 1'b0;
        else if (set_done)
            tx_done <= 1'b1;
        else if (trmt)
            tx_done <= 1'b0;
    end

    // Combinational logic for state transitions and control signals
    always_comb begin
        next_state = state;
        load = 1'b0;
        shift = 1'b0;
        transmitting = 1'b0;
        set_done = 1'b0;
        
        case (state)
            IDLE: begin
                if (trmt) begin
                    next_state = LOAD;
                    load = 1'b1;
                end
            end
            
            LOAD: begin
                next_state = TRANSMITTING;
                transmitting = 1'b1;
            end
            
            TRANSMITTING: begin
                transmitting = 1'b1;
                if (baud_cnt == 13'h1458) begin // Baud rate divisor for standard rates
                    shift = 1'b1;
                    if (bit_cnt == 4'h9) begin // Transmitted all 10 bits (start + 8 data + stop)
                        next_state = IDLE;
                        set_done = 1'b1;
                    end
                end
            end
        endcase
    end

    // Output assignment
    assign TX = tx_shft_reg[0];

endmodule