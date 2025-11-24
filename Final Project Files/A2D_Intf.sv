module A2D_intf(
    input logic clk,
    input logic rst_n,
    input logic nxt,
    output logic [11:0] lft_ld,
    output logic [11:0] rght_ld,
    output logic [11:0] steer_pot,
    output logic [11:0] batt,
    input logic MISO,
    output logic MOSI,
    output logic SCLK,
    output logic SS_n
);

/*• We use 4 channels of the A2D converter for our Segway
• Channel 0 → Left load cell
• Channel 4 → Right load cell
• Channel 5 → Steering Potentiometer
• Channel 6 → Battery Voltage
• The A2D converter (ADC128S) on the DE0-Nano board
is a SPI based device
• We will use our SPI_mnrch to access it
• We will perform two transactions nearly back to back
• First transaction we tell the ADCC128S what channel to
convert
• Second transaction we read the converted analog data for
that channel.


In HW4 you produced a SPI monarch (SPI_mnrch.sv). We
are now going to use that block to make a block that does
round robin conversions on channels 0,4,5,6.
You will be producing a module called A2D_Intf.sv with the
following interface:
Signal: Dir: Description:
clk,rst_n in 50MHz clock and active low asynch reset
nxt in Initiates A2D conversion on next measurand
lft_ld[11:0] out Result of last conversion on channel 0 (left load cell)
rght_ld[11:0] out Result of last conversion on channel 4 (right load cell)
steer_pot[11:0] Result of last conversion on channel 5 (steering potentiometer)
batt[11:0] out Result of last conversion on channel 5 (battery voltage)
SPI Interface Out/
in
SS_n, SCLK, MOSI, MISO of a SPI interface. Comes from copy
of SPI_mnrch embedded into this unit.


The SM will sit idle till it is told to perform a conversion (nxt asserted). Then it will kick off two SPI transactions
via SPI_mnrch. The first SPI transaction determines what channel to convert, and the second SPI transaction
reads the result for that channel. The round robin counter is then incremented, and on the nxt request it will
convert the next channel in the sequence.
You also need 4 holding registers to hold the respective results. The round robin counter determines where to store
the results as well
*/



// Internal signals
logic start_txn;
logic [2:0] channel;
logic lft_ld_en;
logic rght_ld_en;
logic steer_pot_en;
logic batt_en;
logic txn_done;
logic update_chnl;
logic [11:0] data_out;

// State machine states
typedef enum logic [2:0] {
    IDLE,
    WAIT_TXN_W,
    DELAY_CYCLE,
    WAIT_TXN_R,
    STORE_RESULT
} state_t;

state_t current_state, next_state;

// SPI monarch instance
SPI_mnrch spi_inst (
    .clk(clk),
    .rst_n(rst_n),
    .wrt(start_txn), // Always write to start transaction
    .wt_data({2'b00, channel, 11'h000}), // Command to select channel
    .MOSI(MOSI),
    .MISO(MISO),
    .SCLK(SCLK),
    .SS_n(SS_n),
    .rd_data(data_out),
    .done(txn_done)
);



// State machine sequential logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lft_ld <= 12'h000;
    end else if (lft_ld_en) begin
        lft_ld <= data_out;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rght_ld <= 12'h000;
    end else if (rght_ld_en) begin
        rght_ld <= data_out;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        steer_pot <= 12'h000;
    end else if (steer_pot_en) begin
        steer_pot <= data_out;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        batt <= 12'h000;
    end else if (batt_en) begin
        batt <= data_out;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        channel <= 0;
    end else if (update_chnl) begin
        case (channel)
            3'b000: channel <= 3'b100; // Next channel 4
            3'b100: channel <= 3'b101; // Next channel 5
            3'b101: channel <= 3'b110; // Next channel 6
            3'b110: channel <= 3'b000; // Back to channel 0
            default: channel <= 3'b000;
        endcase
    end
end

// State machine combinational logic
always_comb begin
    // Default values
    next_state = current_state;
    start_txn = 0;
    lft_ld_en = 0;
    rght_ld_en = 0;
    steer_pot_en = 0;
    batt_en = 0;
    update_chnl = 0;

    case (current_state)
        IDLE: begin
            if (nxt) begin
                start_txn = 1;
                next_state = WAIT_TXN_W;
            end
        end

        WAIT_TXN_W: begin
            if (txn_done) begin
                next_state = DELAY_CYCLE;
                start_txn = 1; // Start second transaction to read data
            end
        end

        DELAY_CYCLE: begin
            // Wait one clock cycle to ensure proper timing between transactions
            next_state = WAIT_TXN_R;
        end

        WAIT_TXN_R: begin
            if (txn_done) begin
                // Store result based on channel
            case (channel)
                3'b000: lft_ld_en = 1; // Channel 0
                3'b100: rght_ld_en = 1; // Channel 4
                3'b101: steer_pot_en = 1; // Channel 5
                3'b110: batt_en = 1; // Channel 6
            endcase
                next_state = STORE_RESULT;
            end
        end

        STORE_RESULT: begin
            update_chnl = 1;
            next_state = IDLE;
            end

        default: next_state = IDLE;
    endcase
end

endmodule