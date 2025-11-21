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
                                                    (lft_torque <<< 2) :
                                                    lft_torque_comp );

    // Deadzone shaping for right motor
    logic signed [12:0] rght_torque_comp;
    assign rght_torque_comp = rght_torque[12] ? (rght_torque - MIN_DUTY) : (rght_torque + MIN_DUTY);

        logic signed [12:0] rght_shaped;
        assign rght_shaped = !pwr_up ? 13'h0000 :
                                                 ( ( (rght_torque < 0 ? -rght_torque : rght_torque ) < LOW_TORQUE_BAND ) ?
                                                     (rght_torque <<< 2) :
                                                     rght_torque_comp );

    // Saturation logic (optimized): detect overflow via top two bits [12:11]
    // For reducing a 13-bit signed value to 12-bit signed range:
    //  - Positive overflow if [12:11] == 2'b01  (value > +2047)
    //  - Negative overflow if [12:11] == 2'b10  (value < -2048)
    function automatic logic signed [11:0] sat12(input logic signed [12:0] val);
        logic pos_ovf, neg_ovf;
        begin
            pos_ovf = (~val[12]) & val[11];
            neg_ovf = val[12] & (~val[11]);
            sat12 = pos_ovf ? 12'sd2047 :
                    neg_ovf ? -12'sd2048 :
                              val[11:0];
        end
    endfunction

    assign lft_spd  = sat12(lft_shaped);
    assign rght_spd = sat12(rght_shaped);

    // Overspeed detection
    // Compute directly from 13-bit shaped values to avoid waiting for saturation datapath.
    // For signed 13-bit x, x > 1536 (0x600) iff:
    //  - sign == 0 and (bit[11] == 1) OR (bits[11:9] == 3'b011 and any lower bit set)
    logic l_gt_limit, r_gt_limit;
    assign l_gt_limit = (~lft_shaped[12]) & ( lft_shaped[11]
                          | (lft_shaped[10] & lft_shaped[9] & (|lft_shaped[8:0])) );
    assign r_gt_limit = (~rght_shaped[12]) & ( rght_shaped[11]
                          | (rght_shaped[10] & rght_shaped[9] & (|rght_shaped[8:0])) );
    assign too_fast = l_gt_limit | r_gt_limit;

endmodule