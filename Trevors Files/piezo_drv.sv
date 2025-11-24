module piezo_drv(clk, rst_n, en_steer, too_fast, batt_low, piezo, piezo_n);

parameter fast_sim = 1;  // Default to fast simulation

input clk, rst_n;
input en_steer;     // "normal" operation - play Charge Fanfare every 3 seconds
input too_fast;     // priority over other inputs - play first 3 notes continuously
input batt_low;     // Charge fanfare backwards every 3 seconds
output reg piezo;
output piezo_n;

// Piezo complement output
assign piezo_n = ~piezo;

// Note frequencies (in clock cycles for 50MHz clock)
// Formula: 50MHz / frequency = period in clocks
localparam G6_FREQ = 31888;  // 50MHz / 1568Hz
localparam C7_FREQ = 23900;  // 50MHz / 2093Hz  
localparam E7_FREQ = 18962;  // 50MHz / 2637Hz
localparam G7_FREQ = 15949;  // 50MHz / 3136Hz

// Note durations (in clock cycles)
localparam SHORT_DUR = (1 << 23);           // 2^23 clocks
localparam LONG_DUR = (1 << 23) + (1 << 22); // 2^23 + 2^22 clocks
localparam MED_DUR = (1 << 22);             // 2^22 clocks
localparam LONGEST_DUR = (1 << 25);        // 2^25 clocks

// 3 second timer (150M clocks at 50MHz)
localparam THREE_SEC = 150000000;

// State machine states
typedef enum logic [3:0] {
    IDLE,
    G6_NOTE,
    C7_NOTE,
    E7_NOTE1,
    G7_NOTE1,
    E7_NOTE2,
    G7_NOTE2,
    PAUSE
} state_t;

state_t state, nxt_state;

// Timers/Counters
reg [31:0] duration_timer;
reg [31:0] repeat_timer;
reg [31:0] period_timer;

// Timer control signals
reg duration_done, repeat_done, period_half, period_done;
reg clr_duration, clr_repeat, clr_period;

// Current note parameters
reg [31:0] current_freq;
reg [31:0] current_duration;

// Generate increment amount based on fast_sim parameter
generate
    if (fast_sim) begin : fast_increment
        localparam INCREMENT = 64;
    end else begin : normal_increment
        localparam INCREMENT = 1;
    end
endgenerate

// Duration timer
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        duration_timer <= 0;
    else if (clr_duration)
        duration_timer <= 0;
    else if (fast_sim)
        duration_timer <= duration_timer + fast_increment.INCREMENT;
    else
        duration_timer <= duration_timer + normal_increment.INCREMENT;
end

assign duration_done = (duration_timer >= current_duration);

// Repeat timer (3 second timer)
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        repeat_timer <= 0;
    else if (clr_repeat)
        repeat_timer <= 0;
    else if (fast_sim)
        repeat_timer <= repeat_timer + fast_increment.INCREMENT;
    else
        repeat_timer <= repeat_timer + normal_increment.INCREMENT;
end

assign repeat_done = (repeat_timer >= (THREE_SEC / (fast_sim ? 64 : 1)));

// Period timer (frequency generation)
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        period_timer <= 0;
    else if (clr_period)
        period_timer <= 0;
    else if (fast_sim)
        period_timer <= period_timer + fast_increment.INCREMENT;
    else
        period_timer <= period_timer + normal_increment.INCREMENT;
end

assign period_half = (period_timer >= (current_freq / (fast_sim ? 64 : 1)) / 2);
assign period_done = (period_timer >= (current_freq / (fast_sim ? 64 : 1)));

// State machine FF
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

// State machine combinational logic
always_comb begin
    nxt_state = state;
    clr_duration = 0;
    clr_repeat = 0;
    clr_period = period_done; // Clear period timer when period is complete
    current_freq = G6_FREQ;
    current_duration = SHORT_DUR / (fast_sim ? 64 : 1);

    case (state)
        IDLE: begin
            if (too_fast) begin
                nxt_state = G6_NOTE;
                clr_duration = 1;
                clr_period = 1;
            end else if (batt_low && (repeat_done || repeat_timer == 0)) begin
                nxt_state = G7_NOTE2;  // Start backwards sequence
                clr_duration = 1;
                clr_period = 1;
                clr_repeat = 1;
            end else if (en_steer && (repeat_done || repeat_timer == 0)) begin
                nxt_state = G6_NOTE;   // Start normal sequence
                clr_duration = 1;
                clr_period = 1;
                clr_repeat = 1;
            end
        end

        G6_NOTE: begin
            current_freq = G6_FREQ;
            current_duration = SHORT_DUR / (fast_sim ? 64 : 1);
            if (duration_done) begin
                clr_duration = 1;
                clr_period = 1;
                if (too_fast)
                    nxt_state = C7_NOTE;  // Continue to next note for too_fast
                else if (batt_low)
                    nxt_state = E7_NOTE2; // Backwards: go to previous note
                else
                    nxt_state = C7_NOTE;  // Normal: go to next note
            end
        end

        C7_NOTE: begin
            current_freq = C7_FREQ;
            current_duration = SHORT_DUR / (fast_sim ? 64 : 1);
            if (duration_done) begin
                clr_duration = 1;
                clr_period = 1;
                if (too_fast)
                    nxt_state = E7_NOTE1; // Continue to next note for too_fast
                else if (batt_low)
                    nxt_state = G6_NOTE;  // Backwards: go to previous note
                else
                    nxt_state = E7_NOTE1; // Normal: go to next note
            end
        end

        E7_NOTE1: begin
            current_freq = E7_FREQ;
            current_duration = SHORT_DUR / (fast_sim ? 64 : 1);
            if (duration_done) begin
                clr_duration = 1;
                clr_period = 1;
                if (too_fast)
                    nxt_state = G6_NOTE;  // Loop back for too_fast (only first 3 notes)
                else if (batt_low)
                    nxt_state = C7_NOTE;  // Backwards: go to previous note
                else
                    nxt_state = G7_NOTE1; // Normal: go to next note
            end
        end

        G7_NOTE1: begin
            current_freq = G7_FREQ;
            current_duration = LONG_DUR / (fast_sim ? 64 : 1);
            if (duration_done) begin
                clr_duration = 1;
                clr_period = 1;
                if (batt_low)
                    nxt_state = E7_NOTE1; // Backwards: go to previous note
                else
                    nxt_state = E7_NOTE2; // Normal: go to next note
            end
        end

        E7_NOTE2: begin
            current_freq = E7_FREQ;
            current_duration = MED_DUR / (fast_sim ? 64 : 1);
            if (duration_done) begin
                clr_duration = 1;
                clr_period = 1;
                if (batt_low)
                    nxt_state = G7_NOTE1; // Backwards: go to previous note
                else
                    nxt_state = G7_NOTE2; // Normal: go to next note
            end
        end

        G7_NOTE2: begin
            current_freq = G7_FREQ;
            current_duration = LONGEST_DUR / (fast_sim ? 64 : 1);
            if (duration_done) begin
                clr_duration = 1;
                clr_period = 1;
                if (batt_low)
                    nxt_state = E7_NOTE2; // Backwards: go to previous note
                else
                    nxt_state = PAUSE;    // Normal: go to pause
            end
        end

        PAUSE: begin
            current_freq = G6_FREQ; // Doesn't matter, piezo will be off
            if (too_fast) begin
                nxt_state = G6_NOTE;
                clr_duration = 1;
                clr_period = 1;
            end else begin
                nxt_state = IDLE;
            end
        end

        default: nxt_state = IDLE;
    endcase

    // Priority handling
    if (too_fast && (state != G6_NOTE && state != C7_NOTE && state != E7_NOTE1)) begin
        nxt_state = G6_NOTE;
        clr_duration = 1;
        clr_period = 1;
    end
end

// Piezo output generation
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        piezo <= 0;
    end else if (state == IDLE || state == PAUSE) begin
        piezo <= 0;  // Silent during idle and pause
    end else if (period_done) begin
        piezo <= ~piezo;  // Toggle piezo when period is complete
    end
end

endmodule
