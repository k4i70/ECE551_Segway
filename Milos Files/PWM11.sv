module PWM11(
    input clk,
    input rst_n,
    input unsigned [10:0] duty,
    output logic PWM1,
    output logic PWM2,
    output logic PWM_synch,
    output logic ovr_I_blank
);

localparam NONOVERLAP = 11'h040;

logic [10:0] cnt;
logic S1;
logic S2;
logic R1;
logic R2;
logic D1;
logic D2;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt <= 11'h000;
    else 
        cnt <= cnt + 1;
end
        
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        PWM1 <= 0;
        PWM2 <= 0;
    end
    else begin
        PWM1 <= D1;
        PWM2 <= D2;
    end
end
    
always_comb begin
    // Check for overflow condition when duty + NONOVERLAP exceeds counter max
    if (duty > (11'h7FF - NONOVERLAP)) begin
        // When overflow would occur, disable PWM2 to prevent overlap
        S2 = 1'b0;
    end else begin
        S2 = (cnt >= (duty + NONOVERLAP));
    end
    
    S1 = (cnt >= NONOVERLAP);
    R1 = (cnt >= duty);
    R2 = (&cnt);

    D1 = ~(R1) & S1;
    D2 = ~(R2) & S2;

    PWM_synch = ~|cnt;
    ovr_I_blank = ((cnt > NONOVERLAP && cnt < NONOVERLAP+128) || (cnt > NONOVERLAP+duty && cnt < NONOVERLAP+duty+128));
end


endmodule