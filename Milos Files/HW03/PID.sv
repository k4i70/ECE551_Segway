// PID Math Module
// This module provides mathematical functions for PID control

module PID(
    input  logic signed [15:0] ptch,
    input  logic signed [15:0] ptch_rt,
    input vld,
    input clk,
    input rst_n,
    input pwr_up,
    input rider_off,
    output logic signed [11:0] PID_cntrl,
    output logic [7:0] ss_tmr
);
    localparam P_COEFF = 5'h09; // Proportional coefficient
    logic ov;
    logic [26:0] long_tmr;
    logic signed [14:0] P_term;
    logic signed [17:0] integrator;
    logic signed [17:0] I_and_ptch;
    logic signed [14:0] I_term;
    logic signed [12:0] D_term;
    //saturate ptch to 10 bits
    logic signed [9:0] ptch_saturated;
    assign ptch_saturated = (|ptch[15:9] & ~&ptch[15:9]) ? (ptch[15] ? 10'h200 : 10'h1FF) : ptch[9:0];
    //multiply ptch by P_COEFF
    
    assign P_term = ptch_saturated * $signed(P_COEFF);

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            integrator <= 18'h00000;
        else begin
            integrator <= rider_off ? 18'h00000 : (vld & !ov) ? I_and_ptch : integrator;
        end
    end

    assign ov = (ptch_saturated[9] == integrator[17]) ? (ptch_saturated[9] != I_and_ptch[17]) : 1'b0;

    assign I_and_ptch = ({{8{ptch_saturated[9]}}, ptch_saturated[9:0]} + integrator);

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            long_tmr <= 27'h0000000;
        else
            long_tmr <= pwr_up ? (&long_tmr[26:19] ? long_tmr : long_tmr + 1) : 27'h0000000;
    end

    assign ss_tmr = long_tmr[26:19];
    //divide integrator by 64
    assign I_term = {{6{integrator[17]}}, integrator[17:6]};

    //divide ptch_rt by 64
    // Take 2's complement of ptch_rt[15:5] with sign extension
    assign D_term = ~{{4{ptch_rt[15]}}, ptch_rt[15:6]} + 1'b1;

    //add P, I, and D terms
    logic signed [15:0] PID_sum;
    //sign extend P_term, I_term, and D_term to 16 bits before addition
    assign PID_sum = {{1{P_term[14]}}, P_term} + {{1{I_term[14]}}, I_term} + {{3{D_term[12]}}, D_term};
    //saturate PID_sum to 12 bits
    assign PID_cntrl = (|PID_sum[15:11] & ~&PID_sum[15:11]) ? (PID_sum[15] ? 12'h800 : 12'h7FF) : PID_sum[11:0];

endmodule