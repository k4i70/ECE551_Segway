module PWM11(
    input logic clk,
    input logic rst_n,
    input logic [10:0] duty,
    output logic PWM1,
    output logic PWM2,
    output logic PWM_synch,
    output logic ovr_I_blank
);

    localparam NONOVERLAP = 11'h040;
    logic [10:0] cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 11'h000;
        else
            cnt <= cnt + 1'b1;
    end
    
    // PWM1: high from 0 to duty
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            PWM1 <= 1'b0;
        else if (cnt == NONOVERLAP)
            PWM1 <= 1'b1;  // Set at start
        else if (cnt == duty)
            PWM1 <= 1'b0;  // Reset at duty
    end
    
    // PWM2: high from NONOVERLAP to NONOVERLAP+duty
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            PWM2 <= 1'b0;
        else if (cnt == NONOVERLAP + duty)
            PWM2 <= 1'b1;  // Set at NONOVERLAP
        else if (cnt == 11'h000)  // Wrap around
            PWM2 <= 1'b0;  // Reset at end of period
    end
    
    assign PWM_synch = ~|cnt;
    assign ovr_I_blank = (cnt >= NONOVERLAP) && (cnt < (NONOVERLAP + 128)) | 
    (cnt >= (NONOVERLAP + duty)) && (cnt < (NONOVERLAP + duty + 128));

endmodule
/*Testbench tests a variety of duty cycles including edge cases*/