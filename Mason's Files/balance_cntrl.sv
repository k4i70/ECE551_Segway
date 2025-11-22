module balance_cntrl (
    input clk, rst_n,
    input vld,
    input [15:0] ptch,
    input [15:0] ptch_rt,
    input pwr_up,
    input rider_off,
    input [11:0] steer_pot,
    input en_steer,
    output [11:0] lft_spd,
    output [11:0] rght_spd,
    output too_fast
);
// Internal signals
logic signed [11:0] PID_cntrl;
logic [7:0] ss_tmr;

// Instantiate SegwayMath module
SegwayMath iSEGWAY (
    .PID_cntrl(PID_cntrl),
    .ss_tmr(ss_tmr),
    .steer_pot(steer_pot),
    .en_steer(en_steer),
    .pwr_up(pwr_up),
    .lft_spd(lft_spd),
    .rght_spd(rght_spd),
    .too_fast(too_fast)
);

// Instantiate PID module
PID iPID (
    .clk(clk),
    .rst_n(rst_n),
    .vld(vld),
    .ptch(ptch),
    .ptch_rt(ptch_rt),
    .pwr_up(pwr_up),
    .rider_off(rider_off),
    .PID_cntrl(PID_cntrl),
    .ss_tmr(ss_tmr)
);
parameter fast_sim = 1;

endmodule