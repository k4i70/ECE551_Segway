module PID(
    input logic signed [15:0] ptch,
    input logic signed [15:0] ptch_rt,
    output logic signed [11:0] PID_cntrl,
    input logic clk,
    input logic rst_n,
    input logic vld,
    output logic [7:0] ss_tmr, // Soft start timer
    input logic pwr_up,
    input logic rider_off
);
    // PID constants P_Coeff, I_Coeff, D_Coeff
    localparam [4:0] P_Coeff = 5'h09; // Proportional coefficient

    // Introduce a parameter called fast_sim that speeds up PID math calculations
    parameter fast_sim = 1'b1; // Default is fast simulation

    // Internal signals
    logic signed [9:0] ptch_err_sat;  // Saturated pitch error
    logic signed [14:0] P_term;
    logic signed [14:0] I_term;
    logic signed [12:0] D_term;
    logic signed [15:0] PID_ctrl_unsat;  // Changed from [11:0] to [15:0]
    logic signed [15:0] P_term_ext; // Sign-extended P_term to 16 bits
    logic signed [15:0] I_term_ext; // Sign-extended I_term to 16 bits
    logic signed [15:0] D_term_ext; // Sign-extended D_term to 16 bits
    logic signed [17:0] integrator;

    // Proportional term calculation
    // Saturate incoming 16-bit ptch to signed 10-bit ptch_err_sat term
    assign ptch_err_sat = (ptch[15] && ~(&ptch[14:9])) ? 10'b1000000000 : // -512
                          (~ptch[15] && (|ptch[14:9])) ? 10'b0111111111 : // +511
                          ptch[9:0];
    
    // Generate P_term by multiplying saturated error with P_Coeff
    assign P_term = ptch_err_sat * $signed(P_Coeff);

    // Integral term calculation
    // Integrator is now a new thing we haven't used
    // On overy VLD reading from the inertial sensor the saturated version of ptch_err
    // is accumulated to the 10 bit accumulator register
    // We use the upper bits ([17:6]) of this accumulator to form the I_term that summed with 
    // our P_term and D_term to form PID_cntrl
    // We also want to add a mux to reset the integrator to zero when rider_off is true
    // Implement as multiple flip-flops for synthesis purposes
   
    logic signed [17:0] ptch_err_sat_signext;
    logic signed [17:0] sum;
    logic signed [17:0] after_vld;
    logic signed [17:0] after_rider_off;
    logic ov;
    
    // Sign extend ptch_err_sat to 18 bits for accumulation
    assign ptch_err_sat_signext = {{8{ptch_err_sat[9]}}, ptch_err_sat}; // Copy sign bit to upper bits

    // Accumulator logic (combinational)
    assign sum = ptch_err_sat_signext + integrator;
    
    // Overflow detection: overflow occurs when both operands have same sign but result has different sign
    assign ov = ((ptch_err_sat_signext[17] && integrator[17] && !sum[17]) ||
                 (!ptch_err_sat_signext[17] && !integrator[17] && sum[17]));

    // VLD mux
    assign after_vld = (vld && !ov) ? sum : integrator;

    // Rider off mux
    assign after_rider_off = rider_off ? 18'd0 : after_vld;

    // Final flip-flop to hold integrator value
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integrator <= 18'd0;
        end else begin
            integrator <= after_rider_off;
        end
    end

    

    generate
        if (fast_sim) begin : GEN_FAST_SIM_I
            // Fast simulation: tap bits [15:1] with proper saturation using [17:15]
            // Pass-through when upper bits equal the new sign bit (000 or 111).
            // Otherwise, saturate toward +MAX (3FFF) for positive, -MIN (4000) for negative.
        assign I_term = ((integrator[17]) && (~&integrator[16:15])) ? 15'h4000 : // -16384
                         ((!integrator[17]) && (|integrator[16:15])) ? 15'h3FFF : // +16383
                         {integrator[17], integrator[15:1]};
        end else begin : GEN_NORMAL_I
            // Normal operation: tap bits [17:6]
            assign I_term = {{3{integrator[17]}}, integrator[17:6]};
        end
    endgenerate

    // Soft start timer logic
    // ramp of ss_tmr to be in the 2-3 second range. Given 50MHz clock.
    // ss_tmr will be formed from the uppper 8-bits of a 27 bit timer. 
    // Should be held in a zero state until pwr_up is true
    // Will run until &[26:19] are all ones (0xFF) then hold there
    logic [26:0] ss_counter;

    generate
        if (fast_sim) begin : GEN_FAST_SIM_SS
            // Fast simulation: increment by 256 each clk to speed up timer
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    ss_counter <= 27'd0;
                end else if (!pwr_up) begin
                    ss_counter <= 27'd0; // Hold at zero when not powered up
                end else if (ss_counter != 27'h7FFFFFF) begin
                    ss_counter <= ss_counter + 27'd256; // <<<< increment by 256 for fast_sim
                end
            end
        end else begin : GEN_NORMAL_SS
            // Normal operation: increment by 1 each clk
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    ss_counter <= 27'd0;
                end else if (!pwr_up) begin
                    ss_counter <= 27'd0; // Hold at zero when not powered up
                end else if (ss_counter != 27'h7FFFFFF) begin
                    ss_counter <= ss_counter + 27'd1;
                end
            end
        end
    endgenerate

    assign ss_tmr = ss_counter[26:19]; // Upper 8 bits for soft start timer

    // Derivative term calculation
    // D_Term is a 13 bit signed quantity and is simply ptch_rt/64. 
    // Then use 2's complement to get negative of this value
    assign D_term = - $signed(ptch_rt >>> 6); // Arithmetic right shift by 6 to divide by 64

    // Combine P, I, D terms to generate PID_cntrl
    // PID_cntrl is simply the sum of P_term, I_term and D_term (all sign extended to 16) saturated to 12 bits
    // Sign extend to 16 bits
    assign P_term_ext = {{1{P_term[14]}}, P_term}; // Sign-extend P_term to 16 bits
    assign I_term_ext = {{1{I_term[14]}}, I_term}; // Sign-extend I_term to 16 bits
    assign D_term_ext = {{3{D_term[12]}}, D_term}; // Sign-extend D_term to 16 bits
    assign PID_ctrl_unsat = (P_term_ext + I_term_ext + D_term_ext);
    assign PID_cntrl = (PID_ctrl_unsat[15] && (~&PID_ctrl_unsat[14:11])) ? 12'b100000000000 : // -2048
                  (~PID_ctrl_unsat[15] && (|PID_ctrl_unsat[14:11])) ? 12'b011111111111 : // +2047
                  PID_ctrl_unsat[11:0];


endmodule