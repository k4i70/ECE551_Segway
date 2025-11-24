// Creating a PWM module that includes a counter from 0 to 2047 and a NONOVERLAP localparam to ensure both PWM 1 and 2 are never both set high

module PWM11 (
    input logic clk, 
    input logic rst_n, // Active low reset
    input logic [10:0] duty, // Specifies duty cycle (unsigned 12-bit)
    output logic PWM1, PWM2, // Complementary glitch free PWM signals with non-overlap
    output logic PWM_sync, // Used to sync changes in duty cycle
    output logic ovr_I_blank // Used to blank out over current mitigation
);

    localparam NONOVERLAP = 11'h040; // Non-overlap value to ensure PWM1 and PWM2 are never high at the same time
    logic [10:0] cnt; // 11-bit counter for PWM generation


    // Counter logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 11'h000; // Reset counter to 0
        end else begin
            if (cnt < 11'h7FF) begin // Count up to 2047
                cnt <= cnt + 1;
            end else begin
                cnt <= 11'h000; // Reset counter after reaching max value
            end
        end
    end

    // PWM1 turns on when counter reaches NONOVERLAP
    // PWM1 turns off when counter reaches duty
    // PWM2 turns on when counter reaches duty + NONOVERLAP
    // PWM2 turns off when counter reaches 2047
    // Use SR Latches to ensure glitch-free operation

    logic S_PWM1, R_PWM1, S_PWM2, R_PWM2; // Set and Reset signals for PWM1 and PWM2
    assign S_PWM1 = cnt>=NONOVERLAP;
    assign R_PWM1 = cnt>=duty;
    assign S_PWM2 = cnt>=(duty + NONOVERLAP);
    assign R_PWM2 = &cnt; // Reset PWM2 when counter reaches 2047

    // SR latch for PWM1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PWM1 <= 1'b0; // Reset PWM1 to low
        end 
        else if (R_PWM1) begin
            PWM1 <= 1'b0; // Reset PWM1 when R_PWM1 is high
        end else if (S_PWM1) begin
            PWM1 <= 1'b1; // Set PWM1 when S_PWM1 is high
        end
    end

    // SR latch for PWM2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PWM2 <= 1'b0; // Reset PWM2 to low
        end 
        else if (R_PWM2) begin
            PWM2 <= 1'b0; // Reset PWM2 when R_PWM2 is high
        end else if (S_PWM2) begin
            PWM2 <= 1'b1; // Set PWM2 when S_PWM2 is high
        end
    end


    // PWM_sync logic
    assign PWM_sync= ~|cnt;

    // ovr_I_blank is high when NONOVERLAP<cnt<NONOVERLAP+128
    // OR when NONOVERLAP+duty<cnt<NONOVERLAP+duty+128
    assign ovr_I_blank = ((cnt > NONOVERLAP) && (cnt < (NONOVERLAP + 11'h080))) || 
                         ((cnt > (duty + NONOVERLAP)) && (cnt < (duty + NONOVERLAP + 11'h080)));


endmodule