// We're creating a UART transmitter module in SystemVerilog
// Taking parallel data input and sending it serially
// The phases are IDLE, 8 bits of data, and a single stop bit
// Use a state machine to manage the transmission process, IDLE and transmitting
// Use 5 always_ff blocks, and a always_comb for the state machine. 
// Baud rate is 9600 bps, clock is 50MHz
// Can get away with only using 9 bits but always shifting in a 1'b1, and then only passing in {tx_data, 1'b0}

module UART_TX (
    input logic clk, rst_n,
    input logic [7:0] tx_data,
    output logic TX,
    input logic trmt, // Asserted for 1 clk to initiate transmission
    output logic tx_done
);

    // State encoding
    // Should just have IDLE and TRANSMIT states
    typedef enum logic {
        IDLE,
        TRANSMIT
    } state_t;

    state_t current_state, next_state;

    logic [3:0] bit_count; // 0-9 (1 start, 8 data, 1 stop)
    logic [12:0] baud_cnt; // To generate baud rate from 50MHz clock
    logic load;
    logic shift;
    logic transmitting;
    logic [9:0] shift_reg; // 1 start, 8 data, 1 stop
    logic set_done;

    // Always FF to count to 5208
    // If load, reset to 0
    // Shift is sent by this module when baud rate tick and in TRANSMIT state
    // Load resets to 0, shift increments on baud rate tick, hold otherwise
    // 50MHz / 9600 = 5208.33, so count to 5208
    always_ff @(posedge clk) begin
        if (load) begin
            baud_cnt <= 13'b0;
        end else if (baud_cnt == 13'd5208) begin
            baud_cnt <= 13'b0;
        end else if (transmitting) begin
            baud_cnt <= baud_cnt + 1;
        end else begin
            baud_cnt <= baud_cnt; // Not transmitting, hold at current value
        end
    end


    // Always FF to manage bit_count
    // Functionality depends on {load, shift}
    // Count to 9 (1 start, 8 data, 1 stop)
    // Load resets to 0, increment on shift. 
    always_ff @(posedge clk) begin
        if (load) begin
            bit_count <= 4'd0;
        end else if (shift && (baud_cnt == 13'd5208)) begin
            bit_count <= bit_count + 1;
        end
    end


    // Always FF to manage TX output
    // Depending on {load, shift} will either load {tx_data, 1'b0}, right shift, or hold. 
    // Pass in {1'b1, tx_data, 1'b0} to shift register on load
    // Right shift passes in 1'b1 for idle state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 10'b1111111111; // Idle state is high
            TX <= 1'b1;
        end else if (load) begin
            shift_reg <= {1'b1, tx_data, 1'b0}; // Load stop, data, start (MSB to LSB)
        end else if (shift && (baud_cnt == 13'd5208)) begin
            shift_reg <= {1'b1, shift_reg[9:1]}; // Shift right, fill with 1
        end
        
        // TX always outputs the LSB of shift register
        if (!rst_n) begin
            TX <= 1'b1;
        end else begin
            TX <= shift_reg[0];
        end
    end

    // SR Latch to manage tx_done with set_done signal or load signal setting tx_done
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_done <= 1'b1;
        end else if (set_done) begin
            tx_done <= 1'b1;
        end else if (load) begin
            tx_done <= 1'b0;
        end
    end

    // Always FF to manage current_state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Always Comb to manage next_state
    always_comb begin
        // Default assignments
        next_state = current_state;
        load = 1'b0;
        transmitting = 1'b0;
        set_done = 1'b0;
        shift = 1'b0;

        case (current_state)
            IDLE: begin
                if (trmt && tx_done) begin
                    next_state = TRANSMIT;
                    load = 1'b1; // Load shift register
                end
            end
            TRANSMIT: begin
                transmitting = 1'b1;
                if (baud_cnt == 13'd5208) begin
                    if (bit_count == 4'd9) begin // All bits sent
                        next_state = IDLE;
                        set_done = 1'b1; // Set tx_done
                    end else begin
                        shift = 1'b1; // Shift the register
                    end
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule