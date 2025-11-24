module SegwayMath(
    input  logic signed [11:0] PID_cntrl,
    input  logic        [7:0]  ss_tmr,
    input  logic        [11:0] steer_pot,
    input  logic               en_steer,
    input  logic               pwr_up,
    output logic        [11:0] lft_spd,
    output logic        [11:0] rght_spd,
    output logic               too_fast
);

    // Local parameters for deadzone shaping
    localparam MIN_DUTY = 13'h0A8;
    localparam LOW_TORQUE_BAND = 7'h2A;
    localparam GAIN_MULT = 4'h4;

    // Internal signals 
    logic signed [11:0] steer_pot_sat;
    logic signed [12:0] steer_signed;
    logic signed [12:0] steer_scaled;
    logic signed [12:0] steer_val_signed;
    logic signed [11:0] PID_ss;
    logic signed [19:0] PID_ss_high;
    logic signed [12:0] PID_ss_ext;
    logic signed [12:0] lft_torque, rght_torque;
    logic signed [12:0] lft_torque_comp, rght_torque_comp;
    logic signed [12:0] lft_torque_abs, rght_torque_abs;
    logic signed [12:0] lft_torque_shaped, rght_torque_shaped;
    logic signed [12:0] lft_shaped, rght_shaped;
    logic signed [12:0] lft_spd_unsat, rght_spd_unsat;
    
    assign PID_ss_high = $signed(PID_cntrl) * $signed({1'b0, ss_tmr}); // 20-bit result

    assign PID_ss = $signed(PID_ss_high) >>> 8; // Divide by 256

    // Saturate steer_pot to [0x200, 0xE00]
    assign steer_pot_sat = (steer_pot > 12'hE00) ? 12'hE00 : 
                          (steer_pot < 12'h200) ? 12'h200 : steer_pot;
    
    assign steer_signed = $signed({1'b0, steer_pot_sat}) - 12'h7ff;
    
    assign steer_scaled = (steer_signed >>> 3) + (steer_signed >>> 4); // 3/16 scaling
    
    assign PID_ss_ext = {PID_ss[11], PID_ss}; // Extend bits for steering addition/subtraction
    
    // Apply steering if enabled to form lft_torque and rght_torque
    assign lft_torque = en_steer ? (PID_ss_ext + steer_scaled) : PID_ss_ext;
    assign rght_torque = en_steer ? (PID_ss_ext - steer_scaled) : PID_ss_ext;
    // Apply minimum duty cycle compensation
    assign lft_torque_comp = lft_torque[12] ? (lft_torque + (-MIN_DUTY)) : (lft_torque + MIN_DUTY);
    // Absolute value of lft_torque
    assign lft_torque_abs = lft_torque[12] ? -lft_torque : lft_torque;
    // Apply gain shaping if within low torque band
    assign lft_torque_shaped = (lft_torque_abs < LOW_TORQUE_BAND) ? (lft_torque * $signed(GAIN_MULT)) : lft_torque_comp;
    // Zero output if power is down
    assign lft_shaped = pwr_up ? lft_torque_shaped : 13'd0;

    // Apply minimum duty cycle compensation
    assign rght_torque_comp = rght_torque[12] ? (rght_torque + (-MIN_DUTY)) : (rght_torque + MIN_DUTY);
    // Absolute value of rght_torque
    assign rght_torque_abs = rght_torque[12] ? -rght_torque : rght_torque;
    // Apply gain shaping if within low torque band
    assign rght_torque_shaped = (rght_torque_abs < LOW_TORQUE_BAND) ? (rght_torque * $signed(GAIN_MULT)) : rght_torque_comp;
    // Zero output if power is down
    assign rght_shaped = pwr_up ? rght_torque_shaped : 13'd0;
    // 13-bit signed saturation before final 12-bit output
    assign lft_spd_unsat = (lft_shaped > 13'sd2047) ? 13'sd2047 :
                    (lft_shaped < -13'sd2048) ? -13'sd2048 : lft_shaped;
    // 13-bit signed saturation before final 12-bit output
    assign rght_spd_unsat = (rght_shaped > 13'sd2047) ? 13'sd2047 :
                    (rght_shaped < -13'sd2048) ? -13'sd2048 : rght_shaped;
    // Final 12-bit outputs
    assign lft_spd = lft_spd_unsat[11:0];
    assign rght_spd = rght_spd_unsat[11:0];

    // too_fast output check if speed exceeds ±1536
    assign too_fast = ($signed(lft_spd) > 12'sd1536) || ($signed(rght_spd) > 12'sd1536);
endmodule
