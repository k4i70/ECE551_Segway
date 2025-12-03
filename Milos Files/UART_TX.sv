module UART_TX(
    input logic clk,
    input logic rst_n,
    input logic trmt,
    input logic [7:0] tx_data,
    output logic TX,
    output logic tx_done
);
typedef enum logic { 
    IDLE = 1'b0,
    TRANSMIT = 1'b1
 } state_t;
logic [3:0] bit_cnt;
logic [15:0] baud_cnt;
logic [9:0] tx_shift_reg;
logic shift;
logic load;
logic transmitting;
state_t current_state, next_state;
logic set_done;
// Baud rate generator 50MHz clk to 9600 baud, approx 5208 clk cycles per bit
always_ff @(posedge clk) begin
    baud_cnt <= (load | shift) ? 16'd0 : (transmitting ? baud_cnt + 16'd1 : baud_cnt);
    if (baud_cnt == 16'd5207) begin
        shift <= 1'b1;
    end
    else begin
        shift <= 1'b0;
    end
end

always_ff @(posedge clk) begin
    bit_cnt <= (load) ? 4'd0 : (shift) ? bit_cnt + 4'd1 : bit_cnt;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_shift_reg <= 10'b1111111111; // Idle state
    end
    else
    tx_shift_reg <= (load) ? {1'b1, tx_data, 1'b0} : (shift) ? {1'b1, tx_shift_reg[9:1]} : tx_shift_reg;

    TX <= tx_shift_reg[0];
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

always_comb begin 
    //set default values
    load = 1'b0;
    transmitting = 1'b0;
    set_done = 1'b0;
    case (current_state)
        IDLE: begin
            if (trmt) begin
                load = 1'b1;
                next_state = TRANSMIT;
            end
            else begin
                next_state = IDLE;
            end
        end
        TRANSMIT: begin
            transmitting = 1'b1;
            if (bit_cnt == 4'd8 && shift) begin
                set_done = 1'b1;
                next_state = IDLE;
            end
            else begin
                next_state = TRANSMIT;
            end
        end
        default: next_state = IDLE;
    endcase
end


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_done <= 1'b0;
    end
    else if(set_done) begin
        tx_done <= 1'b1;
    end
    else if(load) begin
        tx_done <= 1'b0;
    end
end
endmodule