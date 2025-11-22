module PID(
    input logic         clk,
    input logic         rst_n,
    input logic         vld,
    input logic signed [15:0] ptch,
    input logic signed [15:0] ptch_rt,
    input logic         pwr_up,
    input logic         rider_off,
    output logic signed [11:0] PID_cntrl,
    output logic [7:0]  ss_tmr
);

parameter logic fast_sim = 1;  // Toggle between versions

localparam logic signed [4:0] PCOEFF = 5'h09;
logic signed [17:0] integrator;
logic [26:0] long_tmr;

// Saturate ptch to signed 10 bits
logic signed [9:0] ptch_err_sat;
assign ptch_err_sat = (~ptch[15] & |ptch[14:9]) ? 10'b0111111111 :
                      (ptch[15] & ~(&ptch[14:9])) ? 10'b1000000000 :
                      ptch[9:0];

// P_term: signed multiply
logic signed [14:0] P_term;
assign P_term = ptch_err_sat * PCOEFF;

// I_term: integrator / 64 (normal) or saturated from 17 bits (fast_sim)
// For fast_sim integrator: tap bits [15:1] to form I_term with saturation
logic signed [14:0] I_term;
generate
    if (fast_sim) begin : fast_I_term
        // Check for saturation by examining bits [17:15]
        
        // Saturate if bits [17:15] indicate overflow
        assign I_term = (|integrator[17:15] & ~&integrator[17:15]) ? 
                        (integrator[17] ? 15'b100000000000000 : 15'b011111111111111) :
                        integrator[15:1]; // No saturation, take bits [15:1]
    end else begin : normal_I_term
        assign I_term =  {{3{integrator[17]}},integrator[17:6]}; // sign-extend integrator[17:6] to 15 bits
    end
endgenerate

// D_term: sign-extend ptch_rt[15:6] to 13 bits then negate
logic signed [12:0] D_term;
assign D_term = -{ {3{ptch_rt[15]}}, ptch_rt[15:6] };

// sign-extend all terms to 16 bits, sum and saturate to 12 bits
logic signed [15:0] PID_sum;
assign PID_sum = {{1{P_term[14]}}, P_term} +
                 {{1{I_term[14]}}, I_term} +
                 {{3{D_term[12]}}, D_term};

// Saturate 16-bit sum to 12 bits
assign PID_cntrl = (~PID_sum[15] & |PID_sum[14:11]) ? 12'b011111111111 :
                   (PID_sum[15] & ~(&PID_sum[14:11])) ? 12'b100000000000 :
                   PID_sum[11:0];

// Integrator logic - accumulate when vld is high and not rider_off
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        integrator <= 18'h00000;
    end else if (rider_off) begin
        integrator <= 18'h00000;  // Clear integrator when rider is off
    end else if (vld) begin
        // Calculate the addition
        logic signed [17:0] ptch_err_ext;
        logic signed [17:0] sum;
        ptch_err_ext = {{8{ptch_err_sat[9]}}, ptch_err_sat};
        sum = integrator + ptch_err_ext;
        
        // Simple saturation instead of freezing on overflow
        if (sum[17] & ~(&sum[16:15])) begin
            // Negative overflow - saturate to most negative value
            integrator <= 18'b100000000000000000;
        end else if (~sum[17] & |sum[16:15]) begin
            // Positive overflow - saturate to most positive value
            integrator <= 18'b011111111111111111;
        end else begin
            integrator <= sum;
        end
    end
end

// Soft start timer with generate conditional
generate
    if (fast_sim) begin : fast_timer
        always @(posedge clk, negedge rst_n) begin
            if (!rst_n) begin
                long_tmr <= 27'h0000000;
            end else if (!pwr_up) begin
                long_tmr <= 27'h0000000;
            end else begin
                if (&long_tmr[26:19]) begin
                    long_tmr <= long_tmr;
                end else begin
                    long_tmr <= long_tmr + 256;
                end
            end
        end
    end else begin : normal_timer
        always @(posedge clk, negedge rst_n) begin
            if (!rst_n) begin
                long_tmr <= 27'h0000000;
            end else if (!pwr_up) begin
                long_tmr <= 27'h0000000;
            end else begin
                if (&long_tmr[26:19]) begin
                    long_tmr <= long_tmr;
                end else begin
                    long_tmr <= long_tmr + 1;
                end
            end
        end
    end
endgenerate

// Output upper 8 bits of timer as ss_tmr
assign ss_tmr = long_tmr[26:19];

endmodule
/*parameter logic fast_sim = 1;  // Toggle between versions

localparam logic signed [4:0] PCOEFF = 5'b01001;
logic signed [17:0] integrator;
logic [26:0] long_tmr;

// Saturate ptch to signed 10 bits
logic signed [9:0] ptch_err_sat;
assign ptch_err_sat = (~ptch[15] & |ptch[14:9]) ? 10'b0111111111 :
                      (ptch[15] & ~(&ptch[14:9])) ? 10'b1000000000 :
                      ptch[9:0];

// P_term: signed multiply
logic signed [14:0] P_term;
assign P_term = ptch_err_sat * PCOEFF;

// I_term: integrator / 64
logic signed [14:0] I_term;
assign I_term = integrator >>> 6;

// D_term: sign-extend ptch_rt[15:6] to 13 bits then negate
logic signed [12:0] D_term;
assign D_term = -{ {3{ptch_rt[15]}}, ptch_rt[15:6] };

// sign-extend all terms to 16 bits, sum and saturate to 12 bits
logic signed [15:0] PID_sum;
assign PID_sum = {{1{P_term[14]}}, P_term} +
                 {{1{I_term[14]}}, I_term} +
                 {{3{D_term[12]}}, D_term};

// Saturate 16-bit sum to 12 bits
assign PID_cntrl = (~PID_sum[15] & |PID_sum[14:11]) ? 12'b011111111111 :
                   (PID_sum[15] & ~(&PID_sum[14:11])) ? 12'b100000000000 :
                   PID_sum[11:0];

// Integrator logic - accumulate when vld is high and not rider_off
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        integrator <= 18'h00000;
    end else if (rider_off) begin
        integrator <= 18'h00000;  // Clear integrator when rider is off
    end else if (vld) begin
        // Calculate the addition
        logic signed [17:0] ptch_err_ext;
        logic signed [17:0] sum;
        ptch_err_ext = {{8{ptch_err_sat[9]}}, ptch_err_sat};
        sum = integrator + ptch_err_ext;
        
        // Overflow detection: if MSBs of both operands match but don't match result MSB
        if ((integrator[17] == ptch_err_ext[17]) && (integrator[17] != sum[17])) begin
            // Overflow detected, freeze integrator at current value
            integrator <= integrator;
        end else begin
            integrator <= sum;
        end
    end
end

// Soft start timer
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        long_tmr <= 27'h0000000;
    end else if (!pwr_up) begin
        long_tmr <= 27'h0000000;
    end else begin
        if (&long_tmr[26:19]) begin
            long_tmr <= long_tmr;
        end else begin
            long_tmr <= long_tmr + 1;
        end
    end
end

// Output upper 8 bits of timer as ss_tmr
assign ss_tmr = long_tmr[26:19];
endmodule*/