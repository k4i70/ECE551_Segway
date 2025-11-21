module steer_en(clk, rst_n, lft_ld, rght_ld, en_steer, rider_off);

  parameter FAST_SIM = 1;  // Parameter to speed up timer for simulation
  
  input clk, rst_n;
  input [11:0] lft_ld;      // Left load cell reading
  input [11:0] rght_ld;     // Right load cell reading
  output en_steer;          // Enable steering signal
  output rider_off;         // Rider off signal
  
  // Internal signals
  wire [12:0] sum_13;       // 13-bit sum of load cells
  wire [11:0] diff_12;      // 12-bit absolute difference
  wire sum_gt_min;          // Sum greater than minimum
  wire sum_lt_min;          // Sum less than minimum  
  wire diff_gt_1_4;         // Difference greater than 1/4 of sum
  wire diff_gt_15_16;       // Difference greater than 15/16 of sum
  wire clr_tmr;             // Clear timer signal
  wire tmr_full;            // Timer full signal
  
  // Timer counter - 1.34 seconds at 50MHz = 67,000,000 cycles
  localparam TIMER_MAX = FAST_SIM ? 16'hFFFF : 26'd67_000_000;
  reg [25:0] timer;
  
  // Constants for comparison
  localparam MIN_RIDER_WT = 12'h200;      // 0x200 (512)
  localparam WT_HYSTERESIS = 12'h040;     // 0x40 (64)
  
  //////////////////////////////////
  // Calculate sum of load cells  //
  //////////////////////////////////
  assign sum_13 = {1'b0, lft_ld} + {1'b0, rght_ld};
  
  //////////////////////////////////
  // Calculate difference         //
  //////////////////////////////////
  assign diff_12 = (lft_ld > rght_ld) ? (lft_ld - rght_ld) : (rght_ld - lft_ld);
  
  //////////////////////////////////
  // Generate comparison signals  //
  //////////////////////////////////
  assign sum_gt_min = (sum_13 > (MIN_RIDER_WT + WT_HYSTERESIS));
  assign sum_lt_min = (sum_13 < (MIN_RIDER_WT - WT_HYSTERESIS));
  
  // Scale sum by 1/4 for comparison
  wire [10:0] sum_scaled_1_4 = sum_13[12:2];  // Divide by 4
  assign diff_gt_1_4 = (diff_12 > {1'b0, sum_scaled_1_4});
  
  // Scale sum by 15/16 for comparison  
  wire [12:0] sum_scaled_15_16 = sum_13 - sum_13[12:4]; // Multiply by 15/16
  assign diff_gt_15_16 = ({1'b0, diff_12} > unsigned(sum_scaled_15_16));
  
  //////////////////////////////////
  // Timer implementation         //
  //////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      timer <= 26'h0;
    else if (clr_tmr)
      timer <= 26'h0;
    else
      timer <= timer + 1;  // Count normally
  end
  
  // Timer full signal - check appropriate bits based on FAST_SIM
  assign tmr_full = FAST_SIM ? (&timer[14:0]) : (timer >= TIMER_MAX);
  
  //////////////////////////////////
  // Instantiate state machine    //
  //////////////////////////////////
  steer_en_SM iSM(.clk(clk), .rst_n(rst_n), .tmr_full(tmr_full), 
                  .sum_gt_min(sum_gt_min), .sum_lt_min(sum_lt_min),
                  .diff_gt_1_4(diff_gt_1_4), .diff_gt_15_16(diff_gt_15_16),
                  .clr_tmr(clr_tmr), .en_steer(en_steer), .rider_off(rider_off));

endmodule

