`timescale 1ns/1ps
module steer_en (
    input logic clk,
    input logic rst_n,
    input logic [11:0] lft_ld,
    input logic [11:0] rght_ld,
    output logic en_steer,
    output logic rider_off
);

    localparam [9:0] MIN_RIDER_WEIGHT = 10'h200;
    localparam [6:0] WT_HYSTERESIS = 7'h40;
    parameter fast_sim = 1'b1; // set to 0 for real timing

    // Use generate block to select between fast and real timing
    localparam TMR_MAX = fast_sim ? 16'h7FFF : 16'hD09A; // 1.34 sec at 50MHz

    // Signals for state machine and timer
    logic clr_tmr;
    logic tmr_full;
    logic sum_gt_min;
    logic sum_lt_min;
    logic diff_gt_1_4;
    logic diff_gt_15_16;
    
    // Instantiate the steer_en_SM
    steer_en_SM isteer_en_sm (
        .clk(clk),
        .rst_n(rst_n),
        .sum_gt_min(sum_gt_min),
        .sum_lt_min(sum_lt_min),
        .diff_gt_1_4(diff_gt_1_4),
        .diff_gt_15_16(diff_gt_15_16),
        .clr_tmr(clr_tmr),
        .tmr_full(tmr_full),
        .en_steer(en_steer),
        .rider_off(rider_off)
    );

    // Implement a 1.34 second timer given 50MHz clock
    // When fast sim is true, truncate to only checking [14:0]
    logic [15:0] tmr_cnt;

    // Register inputs first to ensure both load cells are captured together
    // This prevents transient differences when A2D values arrive at different times
    logic [11:0] lft_ld_reg, rght_ld_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lft_ld_reg <= '0;
            rght_ld_reg <= '0;
        end else begin
            lft_ld_reg <= lft_ld;
            rght_ld_reg <= rght_ld;
        end
    end

    // Sum and difference calculations (from registered inputs)
    logic [13:0] sum_ld;
    logic [12:0] diff_signed;
    logic [12:0] diff_abs;

    assign sum_ld = lft_ld_reg + rght_ld_reg;
    assign diff_signed = lft_ld_reg - rght_ld_reg;
    assign diff_abs = diff_signed[12] ? -diff_signed : diff_signed; // Absolute value

    // Scaled sums for comparisons (combinational, from registered sum)
    logic [13:0] sum_scaled_1_4;
    logic [17:0] sum_scaled_15_16;

    assign sum_scaled_1_4 = sum_ld >> 2; // Divide by 4
    assign sum_scaled_15_16 = (sum_ld * 15) >> 4; // Multiply by 15/16

    // Generate sum_gt_min with hysteresis (sum > MIN_RIDER_WEIGHT + HYSTERESIS)
    assign sum_gt_min = (sum_ld > (MIN_RIDER_WEIGHT + WT_HYSTERESIS));

    // Generate sum_lt_min with hysteresis (sum < MIN_RIDER_WEIGHT - HYSTERESIS)
    assign sum_lt_min = (sum_ld < (MIN_RIDER_WEIGHT - WT_HYSTERESIS));

    // Generate diff_gt_1_4 (|diff| > sum/4)
    assign diff_gt_1_4 = ({1'b0, diff_abs} > sum_scaled_1_4);

    // Generate diff_gt_15_16 (|diff| > sum*15/16)
    assign diff_gt_15_16 = ({5'b0, diff_abs} > sum_scaled_15_16);

    // Timer implementation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tmr_cnt <= 16'h0000;
        else if (clr_tmr)
            tmr_cnt <= 16'h0000;
        else if (!tmr_full)
            tmr_cnt <= tmr_cnt + 1;
    end

    // Timer full logic - use fast_sim to truncate checking to [14:0]
    assign tmr_full = fast_sim ? (&tmr_cnt[14:0]) : (tmr_cnt >= TMR_MAX);

endmodule