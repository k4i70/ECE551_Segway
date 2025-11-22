module PID_Math (
    input  logic signed [15:0] ptch,        // pitch from inertial interface
    input  logic signed [15:0] ptch_rt,     // pitch rate from inertial interface
    input  logic signed [17:0] integrator,  // integrator accumulation register
    output logic signed [11:0] PID_cntrl    // 12-bit signed PID control output
);

    // Local parameters
    localparam [4:0] PCOEFF = 5'sh09;// Example value, can be changed

    // Internal signals
    logic signed [9:0]  ptch_err_sat;
    logic signed [14:0] P_term;
    logic signed [14:0] I_term;
    logic signed [12:0] D_term;
    logic signed [15:0] PID_sum;

    // Saturate ptch to signed 10 bits
    assign ptch_err_sat = (ptch[15] && ~(&ptch[14:10])) ? 10'sb1000000000 : // too positive
                          (~ptch[15] && (|ptch[14:10])) ? 10'sh1FF : // too negative
                          ptch[9:0];

    // Proportional term (signed multiply)
    assign P_term = ptch_err_sat * $signed(PCOEFF);

    // Integral term: divide integrator by 64, sign-extend to 15 bits
    assign I_term = { {6{integrator[17]}}, integrator[17:6] };

    // Derivative term: divide ptch_rt by 64, sign-extend to 13 bits, negate
    assign D_term = -{ {3{ptch_rt[15]}}, ptch_rt[15:6] };

    // PID sum (add all terms, sign-extend as needed)
    assign PID_sum = $signed(P_term) + $signed(I_term) + $signed(D_term);

    // Saturate PID_sum to 12 bits
    assign PID_cntrl = (PID_sum[15] && ~(&PID_sum[14:12])) ? 12'sh800 : // too positive
                       (~PID_sum[15] && (|PID_sum[14:12])) ? 12'sh7FF : // too negative
                       PID_sum[11:0];
endmodule