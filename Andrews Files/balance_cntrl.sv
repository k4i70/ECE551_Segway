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

    // Note PID_cntrl[11:0] and ss_tmr[7:0] are outputs from PID module and inputs to SegwayMath
    logic signed [11:0] PID_cntrl;
    logic [7:0] ss_tmr;

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

    SegwayMath segway_math_inst (
        .pwr_up(pwr_up),
        .steer_pot(steer_pot),
        .en_steer(en_steer),
        .PID_cntrl(PID_cntrl),
        .ss_tmr(ss_tmr),
        .lft_spd(lft_spd),
        .rght_spd(rght_spd),
        .too_fast(too_fast)
    );





endmodule 