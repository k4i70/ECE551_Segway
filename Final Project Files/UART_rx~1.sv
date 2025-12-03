// UART receiver module
module UART_rx (
    input logic clk,
    input logic rst_n,
    input logic RX,
    input logic clr_rdy,
    output logic [7:0] rx_data,
    output logic rdy
);

//state encoding

typedef enum logic { IDLE, DATA} state_t;
state_t current_state, next_state;
logic [12:0] baud_count; // To count clock cycles for baud rate
logic [3:0] bit_index; // To index the bits being received
logic [7:0] shift_reg; // Shift register to store received bits
logic start;
logic receiving;
logic RX_sync_0, RX_sync_1; // Synchronizers for RX line
logic set_rdy;
logic shift;

// Synchronize RX to clk domain
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        RX_sync_0 <= 1'b1;
        RX_sync_1 <= 1'b1;
    end else begin
        RX_sync_0 <= RX;
        RX_sync_1 <= RX_sync_0;
    end
end
assign start = (current_state == IDLE) && (RX_sync_1 == 1'b0); // Detect start bit
assign shift = (current_state == DATA) && (baud_count == 13'd0) && (!set_rdy); // Shift at baud rate
assign set_rdy = (current_state == DATA) && (bit_index == 4'd9) && (baud_count == 13'd0); // Set ready when byte is received
assign rx_data = shift_reg;

assign receiving = (current_state == DATA);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdy <= 1'b0;
    end else if (set_rdy) begin
        rdy <= 1'b1;
    end else if (clr_rdy) begin
        rdy <= 1'b0;
    end
end
// State transition
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end
// Next state logic
always_comb begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (start) begin
                next_state = DATA;
            end
        end
        DATA: begin
            if (set_rdy) begin
                next_state = IDLE;
            end
        end
    endcase
end

// Baud rate counter, counts half a baud period first, then full baud periods
always_ff @(posedge clk) begin
    if (start || shift) begin
        baud_count <= (start) ? 13'd2604 : 13'd5208; // Half baud period for start, full for data bits
    end else if (receiving) begin
        baud_count <= baud_count - 13'd1;
    end
end

// Bit index counter
always_ff @(posedge clk) begin
    bit_index <= (start) ? 4'd0 : (shift) ? (bit_index + 4'd1) : bit_index;
end

//shift register
always_ff @(posedge clk) begin
    if (start) begin
        shift_reg <= 8'd0;
    end else if (shift) begin
        shift_reg <= {RX_sync_1, shift_reg[7:1]};
    end
end

endmodule