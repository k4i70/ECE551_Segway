`timescale 1ns/1ps
module SegwayMath (
    input logic signed [12:0] lft_torque, // Registered left torque from balance controller
    input logic signed [12:0] rght_torque, // Registered right torque from balance controller
    input logic pwr_up, // If ~pwr_up then both lft_spd & rght_spd are forced to zero
    output logic signed [11:0] lft_spd, // Signed 12-bit speed command to left motor controller
    output logic signed [11:0] rght_spd, // Signed 12-bit speed command to right motor controller
    output logic too_fast // If either lft_spd or right_spd exceed 12’d1792 then this signal is asserted. Used to warn rider of approaching control limits.
);
    // Stage-1 soft-start and steering mix now live in balance_cntrl; this block only shapes/saturates the registered torques.

    // Local Parameters
    localparam signed MIN_DUTY = 13'h0A8;
    localparam signed LOW_TORQUE_BAND = 7'h2A;
    localparam signed GAIN_MULT = 4'h4;

    // Internal signals
    logic signed [12:0] lft_torque_shaped;
    logic signed [12:0] lft_torque_abs;  
    logic signed [12:0] lft_spd_unsat;
    logic signed [12:0] rght_spd_unsat;
    logic signed [12:0] lft_torque_comp;
    logic signed [12:0] rght_torque_comp;
    logic signed [12:0] rght_torque_shaped;
    logic signed [12:0] rght_torque_abs;
    logic signed [12:0] rght_shaped;
    logic signed [12:0] lft_shaped;

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
    // Check if either greater than d1792, either positive or negative
    assign too_fast = (lft_spd > 12'sd1792) ||
                      (lft_spd < -12'sd1792) ||
                      (rght_spd > 12'sd1792) ||
                      (rght_spd < -12'sd1792);



endmodule