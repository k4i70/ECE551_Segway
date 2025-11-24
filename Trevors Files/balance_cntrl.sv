module balance_cntrl(
    input  logic signed [15:0] ptch,
    input  logic signed [15:0] ptch_rt,
    input  logic vld,
    input  logic clk,
    input  logic rst_n,
    input  logic pwr_up,
    input  logic rider_off,
    input  logic [11:0] steer_pot,
    input  logic en_steer,
    output logic [11:0] lft_spd,
    output logic [11:0] rgt_spd,
    output logic too_fast
);
    logic signed [11:0] PID_cntrl;
    logic [7:0] ss_tmr;
    PID pid_inst (
        .ptch(ptch),
        .ptch_rt(ptch_rt),
        .vld(vld),
        .clk(clk),
        .rst_n(rst_n),
        .pwr_up(pwr_up),
        .rider_off(rider_off),
        .PID_cntrl(PID_cntrl),
        .ss_tmr(ss_tmr)
    );

    SegwayMath segway_math_inst (
        .PID_cntrl(PID_cntrl),
        .ss_tmr(ss_tmr),
        .steer_pot(steer_pot),
        .en_steer(en_steer),
        .pwr_up(pwr_up),
        .lft_spd(lft_spd),
        .rght_spd(rgt_spd),
        .too_fast(too_fast)
    );

endmodule