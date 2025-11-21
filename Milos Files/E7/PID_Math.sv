// PID Math Module
// This module provides mathematical functions for PID control

module PID_Math(
    input  logic signed [15:0] ptch,
    input  logic signed [15:0] ptch_rt,
    input  logic signed [17:0] integrator,
    output logic signed [11:0] PID_cntrl
);
    localparam P_COEFF = 5'h09; // Proportional coefficient
    //saturate ptch to 10 bits
    logic signed [9:0] ptch_saturated;
    assign ptch_saturated = (|ptch[15:9] & ~&ptch[15:9]) ? (ptch[15] ? 10'h200 : 10'h1FF) : ptch[9:0];
    //multiply ptch by P_COEFF
    logic signed [14:0] P_term;
    assign P_term = ptch_saturated * $signed(P_COEFF);

    logic signed [14:0] I_term;
    //divide integrator by 64
    assign I_term = {{6{integrator[17]}}, integrator[17:6]};

    logic signed [12:0] D_term;
    //divide ptch_rt by 64
    // Take 2's complement of ptch_rt[15:5] with sign extension
    assign D_term = -{{3{ptch_rt[15]}}, ptch_rt[15:5]};

    //add P, I, and D terms
    logic signed [15:0] PID_sum;
    assign PID_sum = P_term + I_term + D_term;
    //saturate PID_sum to 12 bits
    assign PID_cntrl = (|PID_sum[15:9] & ~&PID_sum[15:9]) ? (PID_sum[15] ? 12'h800 : 12'h7FF) : PID_sum[11:0];

endmodule