module SegwayMath (
    input logic [11:0] PID_cntrl, // PID control signal (12-bit signed)
    input logic [7:0] ss_tmr,   // slow start timer (8-bit unsigned)
    input logic [11:0] steer_pot, // steering potentiometer (12-bit unsigned)
    input en_steer, // enable steering
    input logic pwr_up, // power up signal
    output logic [11:0] lft_spd, // left speed command (12-bit signed)
    output logic [11:0] rgt_spd,  // right speed command (12-bit signed)
    output logic too_fast         // too fast flag (1-bit unsigned)
);

localparam MIN_DUTY = 13'h0A8;
localparam LOW_TORQUE_BAND = 7'h2A;
localparam GAIN_MULT = 4'h4; // 4x gain multiplier

logic [11:0] PID_ss; // PID after slow start adjustment
logic [19:0] PID_mid;

assign PID_mid = (PID_cntrl * $signed({1'b0, ss_tmr})); // Scale PID by slow start timer
assign PID_ss = PID_mid >>> 8;

// Limit steer_pot to 0x200 and 0xE00 range
logic signed [11:0] steer_limited;
logic signed [11:0] steer_scaled;
assign steer_limited = ((steer_pot < 12'h200) ? 12'h200 :
                       (steer_pot > 12'hE00) ? 12'hE00 : steer_pot) - 12'h7ff;

assign steer_scaled = (steer_limited >>> 3) + (steer_limited >>> 4); // Scale steering by 3/16

logic [12:0] lft_torque; // left torque command (13-bit signed)
logic [12:0] rght_torque; // right torque command (13-bit signed)
assign lft_torque = $signed({PID_ss[11], PID_ss}) + (en_steer ? $signed({steer_scaled[11], steer_scaled}) : 12'sd0);
assign rght_torque = $signed({PID_ss[11], PID_ss}) - (en_steer ? $signed({steer_scaled[11], steer_scaled}) : 12'sd0);

logic [12:0] lft_torque_comp;
logic [12:0] rght_torque_comp;
logic [12:0] lft_shaped;
logic [12:0] rght_shaped;
logic lft_gt_ltb;
logic rght_gt_ltb;
assign lft_gt_ltb = (lft_torque[12]) ? (lft_torque < -LOW_TORQUE_BAND) : (lft_torque > LOW_TORQUE_BAND);
assign rght_gt_ltb = (rght_torque[12]) ? (rght_torque < -LOW_TORQUE_BAND) : (rght_torque > LOW_TORQUE_BAND);

assign lft_torque_comp = (lft_torque[12]) ? (lft_torque - MIN_DUTY) : (lft_torque + MIN_DUTY);
assign rght_torque_comp = (rght_torque[12]) ? (rght_torque - MIN_DUTY) : (rght_torque + MIN_DUTY);

assign lft_shaped = (pwr_up) ? (lft_gt_ltb ? lft_torque_comp : lft_torque * $signed(GAIN_MULT)) : 13'sd0;
assign rght_shaped = (pwr_up) ? (rght_gt_ltb ? rght_torque_comp : rght_torque * $signed(GAIN_MULT)) : 13'sd0;

// Saturate outputs with 12 bit signed limits
assign lft_spd = (&lft_shaped[12:11]) ? lft_shaped[11:0] :
                 (lft_shaped[12]) ? 12'sh800 : (lft_shaped[11] ? 12'sh7ff : lft_shaped[11:0]);
assign rgt_spd = (&rght_shaped[12:11]) ? rght_shaped[11:0] :
                  (rght_shaped[12]) ? 12'sh800 : (rght_shaped[11] ? 12'sh7ff : rght_shaped[11:0]);

assign too_fast = ((lft_spd > $signed(12'd1536)) || (rgt_spd > $signed(12'd1536)));
endmodule