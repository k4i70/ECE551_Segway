// Creating rx module for the acompanying tx module

module UART_RX (
    input logic clk, rst_n,
    input logic RX,
    input logic clr_rdy,
    output logic [7:0] rx_data,
    output logic rdy // Asserted when byte received, stays high until start bit of next byte starts, or until clr_rdy asserted
);

    // State encoding
    // Should just have IDLE and RECEIVING states
    typedef enum logic {
        IDLE,
        RECEIVING
    } state_t;

    state_t current_state, next_state;

    logic [3:0] bit_count; // 0-9 (1 start, 8 data, 1 stop)
    logic [12:0] baud_cnt; // To generate baud rate from 50MHz clock
    logic start;
    logic shift;
    logic receiving;
    logic [9:0] shift_reg; // 1 start, 8 data, 1 stop
    logic set_rdy;
    logic rx_stable;
    logic rx_stable_1;

    // Double flop RX to avoid metastability
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_stable <= 1'b1; // Idle state is high
            rx_stable_1 <= 1'b1;
        end else begin
            rx_stable_1 <= rx_stable;
            rx_stable <= RX;
        end
    end


    // Always FF to count down from 5208
    // At start, reset to 5208/2 = 2604 (to sample in middle of bit)
    // Shift is sent by this module when baud rate tick and in RECEIVING state
    // Start resets to 2604, shift decrements on baud rate tick, hold otherwise
    // 50MHz / 9600 = 5208.33, so count to 5208
    always_ff @(posedge clk) begin
        if (start) begin
            baud_cnt <= 13'd2604; // Start in middle of start bit
        end else if (baud_cnt == 13'd0) begin
            baud_cnt <= 13'd5208;
        end else if (receiving) begin
            baud_cnt <= baud_cnt - 1;
        end else begin
            baud_cnt <= baud_cnt; // Not receiving, hold at current value
        end
    end

    // Always FF to manage bit_count
    // Functionality depends on {start, shift}
    // Count to 9 (1 start, 8 data, 1 stop)
    // Start resets to 0, increment on shift. 
    always_ff @(posedge clk) begin
        if (start) begin
            bit_count <= 4'd0;
        end else if (shift) begin
            bit_count <= bit_count + 1;
        end
    end

    // Always FF to manage RX input
// On shift, sample RX and shift into shift register (LSB first)
// Right shift passes in new RX sample at LSB
always_ff @(posedge clk) begin
    if (shift) begin
        shift_reg <= {rx_stable, shift_reg[9:1]};
    end
end

    // SR Latch to manage set_rdy and start setting rdy
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdy <= 1'b0;
        end else if (start || clr_rdy) begin
            rdy <= 1'b0;
        end else if (set_rdy) begin
            rdy <= 1'b1;
        end
    end

    // Always FF to assign rx_data from shift register
    always_ff @(posedge clk) begin
        if (set_rdy) begin
            rx_data <= shift_reg[9:2]; // Assign only data bits
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

    // Always COMB to manage next_state
    always_comb begin
        // Default assignments
        next_state = current_state;
        receiving = 1'b0;
        start = 1'b0;
        set_rdy = 1'b0;
        shift = 1'b0; // Default shift to 0

        case (current_state)
            IDLE: begin
                if (rx_stable == 1'b0) begin // Start bit detected using synchronized signal
                    start = 1'b1;
                    next_state = RECEIVING;
                end
            end
            RECEIVING: begin
                receiving = 1'b1;
                if (baud_cnt == 13'd0) begin
                    if (bit_count == 4'd9) begin // All bits received
                        next_state = IDLE;
                        set_rdy = 1'b1; // Set set_rdy
                    end else begin
                        shift = 1'b1; // Generate shift signal at baud rate tick
                    end
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule