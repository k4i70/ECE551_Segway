module SegwayMath (
    input  logic signed [11:0] PID_cntrl,
    input  logic       [7:0]  ss_tmr,
    input  logic       [11:0] steer_pot,
    input  logic              en_steer,
    input  logic              pwr_up,
    output logic signed [11:0] lft_spd,
    output logic signed [11:0] rght_spd,
    output logic              too_fast
);

    // Local parameters
    localparam logic signed [12:0] MIN_DUTY         = 13'h0A8;
    localparam logic signed [6:0]  LOW_TORQUE_BAND  = 7'h2A;
    localparam logic signed [3:0]  GAIN_MULT        = 4'h4;
    localparam logic signed [11:0] SPEED_LIMIT      = 12'd1536;

    // Soft start scaling
    logic signed [19:0] pid_scaled;
    assign pid_scaled = PID_cntrl * $signed({1'b0, ss_tmr}); // signed multiply

    logic signed [11:0] PID_ss;
    assign PID_ss = pid_scaled[19:8]; // Divide by 256, keep sign

    // Steering input processing
    logic [11:0] steer_pot_clip;
    assign steer_pot_clip = (steer_pot < 12'h200) ? 12'h200 :
                            (steer_pot > 12'hE00) ? 12'hE00 : steer_pot;

    logic signed [12:0] steer_signed;
    assign steer_signed = $signed({1'b0, steer_pot_clip}) - 12'h7ff; // 12'h7ff = 2047
    logic signed [12:0] steer_term;
    assign steer_term = (steer_signed >>> 3) + (steer_signed >>> 4); // 3/16 scaling

    logic signed [12:0] pid_ss_ext;
    assign pid_ss_ext = $signed({PID_ss[11], PID_ss}); // sign extend to 13 bits

    logic signed [12:0] lft_torque, rght_torque;
    assign lft_torque  = en_steer ? (pid_ss_ext + steer_term) : pid_ss_ext;
    assign rght_torque = en_steer ? (pid_ss_ext - steer_term) : pid_ss_ext;

    // Deadzone shaping for left motor
    logic signed [12:0] lft_torque_comp;
    assign lft_torque_comp = lft_torque[12] ? (lft_torque - MIN_DUTY) : (lft_torque + MIN_DUTY);

    logic signed [12:0] lft_shaped;
    assign lft_shaped = !pwr_up ? 13'h0000 :
                        ( ( (lft_torque < 0 ? -lft_torque : lft_torque ) < LOW_TORQUE_BAND ) ?
                          (lft_torque * $signed(GAIN_MULT)) :
                          lft_torque_comp );

    // Deadzone shaping for right motor
    logic signed [12:0] rght_torque_comp;
    assign rght_torque_comp = rght_torque[12] ? (rght_torque - MIN_DUTY) : (rght_torque + MIN_DUTY);

    logic signed [12:0] rght_shaped;
    assign rght_shaped = !pwr_up ? 13'h0000 :
                         ( ( (rght_torque < 0 ? -rght_torque : rght_torque ) < LOW_TORQUE_BAND ) ?
                           (rght_torque * $signed(GAIN_MULT)) :
                           rght_torque_comp );

    // Saturation logic
    function logic signed [11:0] sat12(input logic signed [12:0] val);
        if (val > 13'sd2047)      return 12'sd2047;
        else if (val < -13'sd2048) return -12'sd2048;
        else                      return val[11:0];
    endfunction

    assign lft_spd  = sat12(lft_shaped);
    assign rght_spd = sat12(rght_shaped);

    // Overspeed detection
    assign too_fast = (lft_spd > $signed(SPEED_LIMIT)) ||
                      (rght_spd > $signed(SPEED_LIMIT)); //rght_shaped

endmodule