`timescale 1ns/1ps
module balance_cntrl (
    input logic clk, rst_n,
    input logic vld,
    input logic [15:0] ptch,
    input logic [15:0] ptch_rt,
    input logic pwr_up,
    input logic rider_off,
    input logic [11:0] steer_pot,
    input logic en_steer,
    output logic signed [11:0] lft_spd,
    output logic signed [11:0] rght_spd,
    output logic too_fast
);

    // Fast sim should be a parameter passed to PID module, defaulted to 1
    parameter fast_sim = 1'b1; // Default is fast simulation

    // Note PID_cntrl[11:0] and ss_tmr[7:0] are outputs from PID module and inputs to the
    // intermediate pipeline stage before SegwayMath.
    logic signed [11:0] PID_cntrl;
    logic [7:0] ss_tmr;

    // Stage 1 (formerly inside SegwayMath) produces registered torques to shorten timing paths.
    logic signed [19:0] pid_ss_high;
    logic signed [11:0] pid_ss_comb;
    logic [11:0] steer_pot_sat;
    logic signed [12:0] steer_signed;
    logic signed [12:0] steer_term_comb;
    logic signed [12:0] pid_ss_ext;
    logic signed [12:0] lft_torque_comb;
    logic signed [12:0] rght_torque_comb;

    // Pipeline registers inserted between PID soft-start arithmetic and SegwayMath shaping logic.
    (* keep = "true" *) logic signed [11:0] pid_ss_q;
    (* keep = "true" *) logic signed [12:0] steer_term_q;
    logic signed [12:0] lft_torque_q;
    logic signed [12:0] rght_torque_q;
    (* keep = "true" *) logic en_steer_q;
    (* keep = "true" *) logic pwr_up_q;

    PID #(.fast_sim(fast_sim)) pid_inst (
        .ptch(ptch),
        .ptch_rt(ptch_rt),
        .PID_cntrl(PID_cntrl),
        .clk(clk),
        .rst_n(rst_n),
        .vld(vld),
        .ss_tmr(ss_tmr),
        .pwr_up(pwr_up),
        .rider_off(rider_off)
    );

    // Stage 1 combinational logic mirrors the original SegwayMath pre-processing.
    assign pid_ss_high = PID_cntrl * $signed({1'b0, ss_tmr});
    assign pid_ss_comb = $signed(pid_ss_high) >>> 8;

    assign steer_pot_sat = (steer_pot <= 12'h200) ? 12'h200 :
                           (steer_pot >= 12'hE00) ? 12'hE00 :
                           steer_pot;

    assign steer_signed = $signed({1'b0, steer_pot_sat}) - 13'sd2048;
    assign steer_term_comb = (steer_signed >>> 3) + (steer_signed >>> 4);

    assign pid_ss_ext = {pid_ss_comb[11], pid_ss_comb};
    assign lft_torque_comb = en_steer ? (pid_ss_ext + steer_term_comb) : pid_ss_ext;
    assign rght_torque_comb = en_steer ? (pid_ss_ext - steer_term_comb) : pid_ss_ext;

    // Pipeline stage capturing the heavy arithmetic before the shaping logic.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pid_ss_q <= '0;
            steer_term_q <= '0;
            lft_torque_q <= '0;
            rght_torque_q <= '0;
            en_steer_q <= 1'b0;
            pwr_up_q <= 1'b0;
        end else begin
            pid_ss_q <= pid_ss_comb;
            steer_term_q <= steer_term_comb;
            lft_torque_q <= lft_torque_comb;
            rght_torque_q <= rght_torque_comb;
            en_steer_q <= en_steer;
            pwr_up_q <= pwr_up;
        end
    end

    // Stage 2 (SegwayMath) now operates on the registered torques.
    SegwayMath segway_math_inst (
        .lft_torque(lft_torque_q),
        .rght_torque(rght_torque_q),
        .pwr_up(pwr_up_q),
        .lft_spd(lft_spd),
        .rght_spd(rght_spd),
        .too_fast(too_fast)
    );





endmodule 