module steer_en_tb();

  // Clock and reset signals
  reg clk, rst_n;
  
  // Inputs to DUT
  reg [11:0] lft_ld, rght_ld;
  
  // Outputs from DUT
  wire en_steer, rider_off;
  
  // Test variables
  integer test_num;
  reg [12:0] sum_test;
  reg [11:0] diff_test;
  
  // Instantiate DUT with FAST_SIM enabled for quick testing
  steer_en #(.FAST_SIM(1)) iDUT(.clk(clk), .rst_n(rst_n), .lft_ld(lft_ld), 
                                .rght_ld(rght_ld), .en_steer(en_steer), 
                                .rider_off(rider_off));
  
  // Clock generation
  always #10 clk = ~clk;
  
  initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    lft_ld = 12'h000;
    rght_ld = 12'h000;
    test_num = 0;
    
    $display("Starting steer_en testbench...");
    
    // Reset sequence
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    
    ///////////////////////////////////////////////////
    // Test 1: Initial state - rider_off should be 1 //
    ///////////////////////////////////////////////////
    test_num = 1;
    $display("Test %0d: Initial state test", test_num);
    lft_ld = 12'h100;  // Low weight
    rght_ld = 12'h100;
    repeat(5) @(posedge clk);
    
    if (!rider_off) begin
      $display("ERROR Test %0d: rider_off should be 1 in initial state", test_num);
      $stop;
    end
    if (en_steer) begin
      $display("ERROR Test %0d: en_steer should be 0 in initial state", test_num);
      $stop;
    end
    $display("PASS Test %0d: Initial state correct", test_num);
    
    //////////////////////////////////////////////////////////////////
    // Test 2: Transition to WAIT state when sum exceeds threshold //
    //////////////////////////////////////////////////////////////////
    test_num = 2;
    $display("Test %0d: Transition to WAIT state", test_num);
    lft_ld = 12'h150;  // Total = 0x2A0 > (0x200 + 0x40 = 0x240)
    rght_ld = 12'h150;
    repeat(5) @(posedge clk);
    
    if (rider_off) begin
      $display("ERROR Test %0d: rider_off should be 0 in WAIT state", test_num);
      $stop;
    end
    if (en_steer) begin
      $display("ERROR Test %0d: en_steer should be 0 in WAIT state", test_num);
      $stop;
    end
    $display("PASS Test %0d: Transition to WAIT state correct", test_num);
    
    ///////////////////////////////////////////////////////////////////
    // Test 3: Timer timeout - should transition to EN state        //
    ///////////////////////////////////////////////////////////////////
    test_num = 3;
    $display("Test %0d: Wait for timer timeout to EN state", test_num);
    // Keep balanced load and wait for timer
    lft_ld = 12'h150;
    rght_ld = 12'h150;
    
    // Wait for timer to expire (FAST_SIM checks bits [14:0])
    wait(iDUT.tmr_full);
    repeat(3) @(posedge clk);
    
    if (rider_off) begin
      $display("ERROR Test %0d: rider_off should be 0 in EN state", test_num);
      $stop;
    end
    if (!en_steer) begin
      $display("ERROR Test %0d: en_steer should be 1 in EN state", test_num);
      $stop;
    end
    $display("PASS Test %0d: Timer timeout transition to EN state correct", test_num);
    
    /////////////////////////////////////////////////////////////////
    // Test 4: Large difference should go back to INIT            //
    /////////////////////////////////////////////////////////////////
    test_num = 4;
    $display("Test %0d: Large difference transition back to INIT", test_num);
    lft_ld = 12'h200;  // Large difference - rider stepping off
    rght_ld = 12'h050;
    repeat(5) @(posedge clk);
    
    if (!rider_off) begin
      $display("ERROR Test %0d: rider_off should be 1 when returning to INIT", test_num);
      $stop;
    end
    if (en_steer) begin
      $display("ERROR Test %0d: en_steer should be 0 when returning to INIT", test_num);
      $stop;
    end
    $display("PASS Test %0d: Large difference transition back to INIT correct", test_num);
    
    ////////////////////////////////////////////////////////////////
    // Test 5: Test diff_gt_1_4 in WAIT state (timer reset)      //
    ////////////////////////////////////////////////////////////////
    test_num = 5;
    $display("Test %0d: Test timer reset due to unbalanced rider in WAIT state", test_num);
    // First get to WAIT state
    lft_ld = 12'h150;
    rght_ld = 12'h150;
    wait(!rider_off);  // Wait to get to WAIT state
    repeat(5) @(posedge clk);
    
    // Now create imbalance that should reset timer but stay in WAIT
    lft_ld = 12'h180;  // Create difference > 1/4 of sum
    rght_ld = 12'h120;
    repeat(10) @(posedge clk);
    
    // Should still be in WAIT state
    if (rider_off) begin
      $display("ERROR Test %0d: Should stay in WAIT state with timer reset", test_num);
      $stop;
    end
    if (en_steer) begin
      $display("ERROR Test %0d: en_steer should be 0 in WAIT state", test_num);
      $stop;
    end
    $display("PASS Test %0d: Timer reset in WAIT state works correctly", test_num);
    
    ////////////////////////////////////////////////////////////////
    // Test 6: Low weight transition back to INIT from WAIT      //
    ////////////////////////////////////////////////////////////////
    test_num = 6;
    $display("Test %0d: Low weight transition from WAIT to INIT", test_num);
    lft_ld = 12'h080;  // Total = 0x100 < (0x200 - 0x40 = 0x1C0)
    rght_ld = 12'h080;
    repeat(5) @(posedge clk);
    
    if (!rider_off) begin
      $display("ERROR Test %0d: rider_off should be 1 when transitioning to INIT", test_num);
      $stop;
    end
    if (en_steer) begin
      $display("ERROR Test %0d: en_steer should be 0 when transitioning to INIT", test_num);
      $stop;
    end
    $display("PASS Test %0d: Low weight transition from WAIT to INIT correct", test_num);
    
    ////////////////////////////////////////////////////////////////
    // Test 7: Full scenario - INIT -> WAIT -> EN -> INIT        //
    ////////////////////////////////////////////////////////////////
    test_num = 7;
    $display("Test %0d: Complete scenario test", test_num);
    
    // Start with no rider
    lft_ld = 12'h080;
    rght_ld = 12'h080;
    repeat(5) @(posedge clk);
    
    // Rider gets on
    lft_ld = 12'h150;
    rght_ld = 12'h150;
    wait(!rider_off);  // Wait for WAIT state
    repeat(5) @(posedge clk);
    
    // Wait for timer and transition to EN
    wait(en_steer);
    repeat(5) @(posedge clk);
    
    // Rider steps off (low weight)
    lft_ld = 12'h080;
    rght_ld = 12'h080;
    repeat(5) @(posedge clk);
    
    if (!rider_off || en_steer) begin
      $display("ERROR Test %0d: Should be back in INIT state", test_num);
      $stop;
    end
    $display("PASS Test %0d: Complete scenario works correctly", test_num);
    
    ////////////////////////////////////////////////////////////////
    // Test 8: Reset functionality                               //
    ////////////////////////////////////////////////////////////////
    test_num = 8;
    $display("Test %0d: Reset functionality", test_num);
    
    // Get to EN state first
    lft_ld = 12'h150;
    rght_ld = 12'h150;
    wait(en_steer);
    
    // Apply reset
    rst_n = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    
    if (!rider_off || en_steer) begin
      $display("ERROR Test %0d: Reset should return to INIT state", test_num);
      $stop;
    end
    $display("PASS Test %0d: Reset functionality works correctly", test_num);
    
    $display("All tests passed!");
    $display("Testbench completed successfully");
    $stop;
  end
  
  // Monitor for debugging
  initial begin
    $monitor("Time=%0t: lft_ld=%h rght_ld=%h rider_off=%b en_steer=%b sum=%h diff=%h state=%h", 
             $time, lft_ld, rght_ld, rider_off, en_steer, 
             iDUT.sum_13, iDUT.diff_12, iDUT.iSM.state);
  end

endmodule