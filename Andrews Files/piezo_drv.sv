module piezo_drv (
    input logic clk, // 50MHz clock
    input logic rst_n,
    input logic en_steer, // "Normal" operation
    input logic too_fast, // Priority over other inputs
    input logic batt_low, // Charge played backwards
    output logic piezo,
    output logic piezo_n // Differential piezo output
);
// note State machine to control the notes being played on the piezo
    // 7 state, 
    // IDLE, 
    // G6 (1568hz and 2^23 clocks), 
    // C7 (2093, 2^23), 
    // E7(2637, 2^23), 
    // G7 (3136, 2^23+2^22), 
    // E7 (2637, 2^22), 
    // G7(3136, 2^25) 
    typedef enum logic [3:0] {
        IDLE, 
        G6, 
        C7, 
        E7, 
        G7, 
        E7_2, 
        G7_2
    } state_t;

    state_t current_state, next_state;
    // Internal signals and parameters
    parameter FAST_SIM = 1; // Set to 1 for fast simulation, 0 for real timing
    
    // Signal declarations
    logic [31:0] duration_cnt;
    logic [31:0] duration_target;
    logic duration_done;
    
    logic [27:0] repeat_cnt;
    logic repeat_done;
    
    logic [31:0] period_cnt;
    logic [31:0] period_target;
    logic period_done;
    
    logic [15:0] frequency;
    logic [31:0] duration;
    
    // Generate increment values based on FAST_SIM parameter
    localparam DURATION_INC = FAST_SIM ? 64 : 1;
    localparam PERIOD_INC = FAST_SIM ? 64 : 1;
    localparam REPEAT_INC = FAST_SIM ? 64 : 1;
    
    // 3 second repeat timer at 50MHz = 150,000,000 clocks
    localparam REPEAT_TIMEOUT = FAST_SIM ? (150_000_000 / 64) : 150_000_000;
    
    // Duration timer
    // Counter to determine duration note is played, when count value equals duration SM is looking for, note is over and SM moves to next state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duration_cnt <= 32'h0;
        end else if (current_state == IDLE) begin
            duration_cnt <= 32'h0;
        end else if (duration_cnt >= duration_target) begin
            duration_cnt <= 32'h0;
        end else begin
            duration_cnt <= duration_cnt + DURATION_INC;
        end
    end
    
    assign duration_target = (FAST_SIM) ? (duration >> 6) : duration;
    assign duration_done = (duration_cnt >= duration_target);

    // Repeat timer
    // Capable of timing out 3 seconds, plays charge every 3 seconds
    // Runs continuously, doesn't reset when leaving IDLE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            repeat_cnt <= 28'h0;
        end else if (repeat_cnt >= (REPEAT_TIMEOUT - REPEAT_INC)) begin
            repeat_cnt <= 28'h0;
        end else begin
            repeat_cnt <= repeat_cnt + REPEAT_INC;
        end
    end
    
    assign repeat_done = (repeat_cnt >= (REPEAT_TIMEOUT - REPEAT_INC));

    // Period (frequency) timer
    // Used to establish the note frequency (actually period). When the timer hits the note period from SM the timer resets
    // When the timer reaches half value of note period the piezo switches from high to low
    // Period = (50_000_000 / frequency) for 50MHz clock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            period_cnt <= 32'h0;
        end else if (current_state == IDLE) begin
            period_cnt <= 32'h0;
        end else if (period_cnt >= period_target) begin
            period_cnt <= 32'h0;
        end else begin
            period_cnt <= period_cnt + PERIOD_INC;
        end
    end
    
    assign period_target = (frequency == 0) ? 32'd1 : 
                           (FAST_SIM) ? ((50_000_000 / 64) / frequency) : (50_000_000 / frequency);
    assign period_done = (period_cnt >= period_target);
    
    // Piezo output generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            piezo <= 1'b0;
        end else if (current_state == IDLE) begin
            piezo <= 1'b0;
        end else if (period_cnt < (period_target >> 1)) begin
            piezo <= 1'b1;
        end else begin
            piezo <= 1'b0;
        end
    end
    
    assign piezo_n = ~piezo;

    

    // Always ff for note state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    

    // Combinational logic for next note state
    always_comb begin
        // Defaults
        next_state = current_state;
        duration = 32'h0;
        frequency = 16'h0;
        case (current_state)
            IDLE: begin
                if (too_fast) begin
                    next_state = G6; // Play first three notes continuously
                end else if (batt_low && repeat_done) begin
                    next_state = G7_2; // Play fanfare backwards
                end else if (en_steer && repeat_done) begin
                    next_state = G6;
                end
            end
            G6: begin
                duration = 32'd8388608; // 2**23
                frequency = 16'd1568; // Hz
                if (duration_done) begin
                    if (too_fast) begin
                        next_state = C7; // In too_fast play first 3 notes continuously
                    end else if (batt_low) begin
                        next_state = IDLE; // In batt_low play backwards so go to IDLE after G6
                    end else if (en_steer) begin
                        next_state = C7;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            C7: begin
                duration = 32'd8388608; // 2**23
                frequency = 16'd2093; // Hz
                if (duration_done) begin
                    if (too_fast) begin
                        next_state = E7; // In too_fast play first 3 notes continuously
                    end else if (batt_low) begin
                        next_state = G6; // In batt_low play backwards so go to G6 after C7
                    end else if (en_steer) begin
                        next_state = E7;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            E7: begin
                duration = 32'd8388608; // 2**23
                frequency = 16'd2637; // Hz
                if (duration_done) begin
                    if (too_fast) begin
                        next_state = IDLE; // In too_fast only play first 3 notes, loop back to IDLE
                    end else if (batt_low) begin
                        next_state = C7; // In batt_low play backwards so go to C7 after E7
                    end else if (en_steer) begin
                        next_state = G7;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            G7: begin
                duration = 32'd12582912; // 2**23 + 2**22
                frequency = 16'd3136; // Hz
                if (duration_done) begin
                    if (too_fast) begin
                        next_state = IDLE; // too_fast only plays first 3 notes
                    end else if (batt_low) begin
                        next_state = E7; // In batt_low play backwards so go to E7 after G7
                    end else if (en_steer) begin
                        next_state = E7_2;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            E7_2: begin
                duration = 32'd4194304; // 2**22
                frequency = 16'd2637; // Hz
                if (duration_done) begin
                    if (too_fast) begin
                        next_state = IDLE; // too_fast only plays first 3 notes
                    end else if (batt_low) begin
                        next_state = G7; // In batt_low play backwards so go to G7 after E7
                    end else if (en_steer) begin
                        next_state = G7_2;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            G7_2: begin
                duration = 32'd33554432; // 2**25
                frequency = 16'd3136; // Hz
                if (duration_done) begin
                    if (too_fast) begin
                        next_state = IDLE; // too_fast only plays first 3 notes
                    end else if (batt_low) begin
                        next_state = E7_2; // In batt_low play backwards so go to E7_2 after G7_2
                    end else if (en_steer) begin
                        next_state = IDLE;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    

endmodule