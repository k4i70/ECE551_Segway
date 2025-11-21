module SegwayMath (
    input logic signed [11:0] PID_cntrl, // Signed 12-bit control from PID that dictates frwrd/rev
    input logic [7:0] ss_tmr, // Unsigned 8-bit scaling quantity used to provide a softstart to control loop. PID_cntrl is scaled by this timer that ramps up slowly from power on.
    input logic [11:0] steer_pot, // 12-bit unsigned measure of steering potentiometer. Comes from A2D_intf. Limited and converted to signed version internal to Segway_math
    input logic en_steer, // Indicates steering has been enabled. Enabled by rider having equal weight distribution on load cells.
    input logic pwr_up, // If ~pwr_up then both lft_spd & rght_spd are forced to zero
    output logic signed [11:0] lft_spd, // Signed 12-bit speed command to left motor controller
    output logic signed [11:0] rght_spd, // Signed 12-bit speed command to right motor controller
    output logic too_fast // If either lft_spd or right_spd exceed 12’d1792 then this signal is asserted. Used to warn rider of approaching control limits.
);
    // Local Parameters
    localparam signed MIN_DUTY = 13'h0A8;
    localparam signed LOW_TORQUE_BAND = 7'h2A;
    localparam signed GAIN_MULT = 4'h4;

    // Internal signals
    logic signed [11:0] PID_ss;
    logic signed [11:0] steer_pot_sat;
    logic signed [11:0] steer_signed;
    logic signed [12:0] steer_term;
    logic signed [12:0] lft_torque;
    logic signed [12:0] rght_torque;
    logic signed [12:0] lft_torque_shaped;
    logic signed [12:0] lft_torque_abs;  
    logic signed [12:0] lft_spd_unsat;
    logic signed [12:0] rght_spd_unsat;
    logic signed [12:0] PID_ss_ext;
    logic signed [19:0] PID_ss_high; // Intermediate 20-bit product of PID_cntrl * ss_tmr
    logic signed [12:0] lft_torque_comp;
    logic signed [12:0] rght_torque_comp;
    logic signed [12:0] rght_torque_shaped;
    logic signed [12:0] rght_torque_abs;
    logic signed [12:0] rght_shaped;
    logic signed [12:0] lft_shaped;


    // Zero extend ss_tmr to form a 9-bit quantity that is multipled by PID_cntrl to form a 20 bit product. You must still case the zero extended ss_tmr to signed to infer a signed multiple. 
    // $signed({1'b0,ss_tmr}) should be multipled by PID_ctrl
    // Scale PID_cntrl by ss_tmr to provide a softstart.
    assign PID_ss_high = PID_cntrl * $signed({1'b0,ss_tmr}); // 20-bit signed quantity
    // Arithmetic right shift by 8 to complete the scaling by ss_tmr/256
    assign PID_ss = $signed(PID_ss_high) >>> 8; // Signed 12-bit quantity

    // Create a saturation of steer_pot to 0x200 to 0xE00
    // Saturate steer_pot to 0x200 (512) to 0xE00 (3584) using bitwise logic
    // 0x200 = 12'b0010_0000_0000, 0xE00 = 12'b1110_0000_0000
    assign steer_pot_sat = steer_pot[11] ? 12'hE00 : // Above upper bound
                       (~|steer_pot[11:9]) ? 12'h200 : // Below lower bound
                       steer_pot; // In range

    // Convert to signed by subtracting 12'h7FF
    assign steer_signed = $signed({1'b0, steer_pot_sat}) - 12'h7ff; // Signed 12-bit quantity

    // Scale by 3/16 using bit shifts like SegwayMath2
    assign steer_term = (steer_signed >>> 3) + (steer_signed >>> 4); // 3/16 scaling

    // Sign extend PID_ss to 13 bits, and sum with steer_term to form lft_torque and rght_torque
    assign PID_ss_ext = {PID_ss[11], PID_ss}; // Sign-extend to 13 bits
    assign lft_torque = en_steer ? (PID_ss_ext + steer_term) : PID_ss_ext; // Signed 13-bit quantity
    assign rght_torque = en_steer ? (PID_ss_ext - steer_term) : PID_ss_ext; // Signed 13-bit quantity

    // Shape torque to provide a deadband around zero torque and a minimum torque at higher levels
    // if lft_torque[12] == 1, MIN_DUTY is subtracted
    // if lft_torque[12] == 0, MIN_DUTY is added
    assign lft_torque_comp = lft_torque[12] ? (lft_torque + (-MIN_DUTY)) : (lft_torque + MIN_DUTY);

    // Create a deadband when |desired torque| <= LOW_TORQUE_BAND. 
    // Then it will be lft_torque * $signed(GAIN_MULT)
    assign lft_torque_abs = lft_torque[12] ? -lft_torque : lft_torque; // Absolute value of original torque
    assign lft_torque_shaped = (lft_torque_abs <= LOW_TORQUE_BAND) ? (lft_torque * $signed(GAIN_MULT)) : lft_torque_comp; // Signed 13-bit quantity

    // Only pass lft_torque_shaped to lft_shaped if pwr_up is high
    assign lft_shaped = pwr_up ? lft_torque_shaped : 13'h0000;

    // Copy for right side
    assign rght_torque_comp = rght_torque[12] ? (rght_torque + (-MIN_DUTY)) : (rght_torque + MIN_DUTY);
    assign rght_torque_abs = rght_torque[12] ? -rght_torque : rght_torque;
    assign rght_torque_shaped = (rght_torque_abs <= LOW_TORQUE_BAND) ? (rght_torque * $signed(GAIN_MULT)) : rght_torque_comp;
    assign rght_shaped = pwr_up ? rght_torque_shaped : 13'h0000;

    // Saturate lft_shaped from [12:0] to form lft_spd [11:0]
    assign lft_spd_unsat = (lft_shaped > 13'sd2047) ? 13'sd2047 : // Positive overflow
                          (lft_shaped < -13'sd2048) ? -13'sd2048 : // Negative overflow
                          lft_shaped; // No overflow
    assign lft_spd = lft_spd_unsat[11:0]; // Truncate to 12 bits
    // Saturate rght_shaped from [12:0] to form rght_spd [11:0]
    assign rght_spd_unsat = (rght_shaped > 13'sd2047) ? 13'sd2047 : // Positive overflow
                          (rght_shaped < -13'sd2048) ? -13'sd2048 : // Negative overflow
                          rght_shaped; // No overflow
    assign rght_spd = rght_spd_unsat[11:0]; // Truncate to 12 bits

    // Overspeed detection - only check positive speeds like SegwayMath2
    assign too_fast = (lft_spd > 12'sd1536) || (rght_spd > 12'sd1536);



endmodule