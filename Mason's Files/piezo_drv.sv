module piezo_drv(clk, rst_n, en_steer, too_fast, batt_low, piezo, piezo_n);

parameter fast_sim = 1'b0;  // Parameter to speed up simulation, default true

input clk, rst_n;
input en_steer;    // "normal" operation - play Charge Fanfare every 3 seconds
input too_fast;    // priority over other inputs - play 1st 3 of Charge Fanfare continuously
input batt_low;    // play Charge backwards
output reg piezo;
output piezo_n;

// State definitions
typedef enum reg [2:0] {
    IDLE = 3'b000,
    G6   = 3'b001,
    C7   = 3'b010,
    E7_1 = 3'b011,
    G7_1 = 3'b100,
    E7_2 = 3'b101,
    G7_2 = 3'b110
} state_t;

state_t state, nxt_state;

// Timer and counter declarations
reg [25:0] duration_cnt;
reg [25:0] period_cnt;
reg [25:0] repeat_cnt;
reg duration_done, period_done, repeat_done;
reg clr_duration, clr_period, clr_repeat;

// Frequency period values (based on 50MHz clock)
reg [15:0] note_period;
reg [25:0] note_duration;
reg [25:0] increment;

// Generate increment value based on fast_sim parameter
generate
    if (fast_sim)
        assign increment = 26'd64;  // 64x faster for simulation
    else
        assign increment = 26'd1;   // Normal speed
endgenerate

// Differential output
assign piezo_n = ~piezo;

// Note period lookup (periods for 50MHz clock)
always_comb begin
    case (state)
        G6:   note_period = 16'd31887;  // 1568 Hz: 50M/1568 = 31887
        C7:   note_period = 16'd23891;  // 2093 Hz: 50M/2093 = 23891
        E7_1, E7_2: note_period = 16'd18962;  // 2637 Hz: 50M/2637 = 18962
        G7_1, G7_2: note_period = 16'd15949;  // 3136 Hz: 50M/3136 = 15949
        default: note_period = 16'd0;
    endcase
end

// Note duration lookup
always_comb begin
    case (state)
        G6, C7, E7_1: note_duration = (fast_sim) ? 26'd131072 : 26'd8388608;   // 2^23 clocks / 64
        G7_1: note_duration = (fast_sim) ? 26'd196608 : 26'd12582912;  // 2^23 + 2^22 clocks / 64
        E7_2: note_duration = (fast_sim) ? 26'd65536 : 26'd4194304;    // 2^22 clocks / 64
        G7_2: note_duration = (fast_sim) ? 26'd524288 : 26'd33554432;  // 2^25 clocks / 64
        default: note_duration = 26'd0;
    endcase
end

// Duration timer
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        duration_cnt <= 26'd0;
    else if (clr_duration)
        duration_cnt <= 26'd0;
    else if (state != IDLE)
        duration_cnt <= duration_cnt + increment;
end

assign duration_done = (duration_cnt >= note_duration);

// Period timer for frequency generation
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        period_cnt <= 26'd0;
    else if (clr_period)
        period_cnt <= 26'd0;
    else if (state != IDLE)
        period_cnt <= period_cnt + 1'b1;
end

assign period_done = (period_cnt >= {10'd0, note_period});

// Repeat timer (3 second timer)
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        repeat_cnt <= 26'd0;
    else if (clr_repeat)
        repeat_cnt <= 26'd0;
    else if ((en_steer || batt_low) && state == IDLE && !too_fast && !repeat_done) //repeat timer runs for both en_steer and batt_low
        repeat_cnt <= repeat_cnt + increment;
end

assign repeat_done = (fast_sim) ? (repeat_cnt >= 26'd2343750) : (repeat_cnt >= 26'd150000000); // 3 seconds

// Piezo output generation
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        piezo <= 1'b0;
    else if (clr_period)
        piezo <= 1'b0;
    else if (state != IDLE && period_cnt >= {11'd0, note_period[15:1]})  // Toggle at half period
        piezo <= ~piezo;
end

// State machine
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

// Next state logic
always_comb begin
    nxt_state = state;
    clr_duration = 1'b0;
    clr_period = 1'b0;
    clr_repeat = 1'b0;
    
    case (state)
        IDLE: begin
            clr_duration = 1'b1;
            clr_period = 1'b1;
            if (too_fast) begin
                nxt_state = G6;
                clr_repeat = 1'b1;
            end else if (batt_low & !too_fast && repeat_done) begin
                nxt_state = G7_2;  // Start backwards after 3 second delay
                clr_repeat = 1'b1;
            end else if (en_steer && repeat_done) begin
                nxt_state = G6;
                clr_repeat = 1'b1;  // Clear repeat timer when starting new sequence
            end else if (!en_steer && !too_fast && !batt_low) begin
                nxt_state = IDLE;  // Stay in IDLE if no conditions met
            end
        end
        
        G6: begin
            if (period_done) clr_period = 1'b1;
            if (duration_done) begin
                clr_duration = 1'b1;
                if (too_fast)
                    nxt_state = C7;
                else if (batt_low & !too_fast)
                    nxt_state = IDLE;
                else
                    nxt_state = C7;
            end
        end
        
        C7: begin
            if (period_done) clr_period = 1'b1;
            if (duration_done) begin
                clr_duration = 1'b1;
                if (too_fast)
                    nxt_state = E7_1;
                else if (batt_low & !too_fast)
                    nxt_state = G6;
                else
                    nxt_state = E7_1;
            end
        end
        
        E7_1: begin
            if (period_done) clr_period = 1'b1;
            if (duration_done) begin
                clr_duration = 1'b1;
                if (too_fast)
                    nxt_state = G6;  // Loop back for continuous play
                else if (batt_low & !too_fast)
                    nxt_state = C7;
                else
                    nxt_state = G7_1;
            end
        end
        
        G7_1: begin
            if (period_done) clr_period = 1'b1;
            if (duration_done) begin
                clr_duration = 1'b1;
                if (batt_low & !too_fast)
                    nxt_state = E7_1;
                else
                    nxt_state = E7_2;
            end
        end
        
        E7_2: begin
            if (period_done) clr_period = 1'b1;
            if (duration_done) begin
                clr_duration = 1'b1;
                if (batt_low & !too_fast)
                    nxt_state = G7_1;
                else
                    nxt_state = G7_2;
            end
        end
        
        G7_2: begin
            if (period_done) clr_period = 1'b1;
            if (duration_done) begin
                clr_duration = 1'b1;
                if (batt_low & !too_fast)
                    nxt_state = E7_2;
                else begin
                    nxt_state = IDLE;
                end
            end
        end
        
        default: nxt_state = IDLE;
    endcase
end

endmodule