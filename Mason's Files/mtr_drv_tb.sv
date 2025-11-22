module mtr_drv_tb;

  // Testbench signals
  reg clk, rst_n;
  reg [11:0] lft_spd, rght_spd;
  reg OVR_I_lft, OVR_I_rght;
  
  wire PWM1_lft, PWM2_lft, PWM1_rght, PWM2_rght;
  wire OVR_I_shtdwn;
  
  // Instantiate the DUT (Device Under Test)
  mtr_drv iDUT (
    .clk(clk),
    .rst_n(rst_n),
    .lft_spd(lft_spd),
    .rght_spd(rght_spd),
    .OVR_I_lft(OVR_I_lft),
    .OVR_I_rght(OVR_I_rght),
    .PWM1_lft(PWM1_lft),
    .PWM2_lft(PWM2_lft),
    .PWM1_rght(PWM1_rght),
    .PWM2_rght(PWM2_rght),
    .OVR_I_shtdwn(OVR_I_shtdwn)
  );
  
  // Clock generation - 50MHz (20ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end
  
  // Test variables
  integer pwm_cycle_count;
  integer ovr_pulse_count;
  reg test_pass;
  
  // Main test sequence
  initial begin
    // Initialize signals
    rst_n = 0;
    lft_spd = 12'h000;
    rght_spd = 12'h000;
    OVR_I_lft = 0;
    OVR_I_rght = 0;
    test_pass = 1;
    
    $display("Starting mtr_drv testbench...");
    
    // Reset pulse
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(10) @(posedge clk);
    
    // Set moderate speed values to enable PWM operation
    lft_spd = 12'h400;  // Positive speed
    rght_spd = 12'h400;  // Positive speed
    repeat(10) @(posedge clk);
    
    $display("Reset complete, starting tests...");
    
    // TEST 1: 40+ OVR_I pulses during blanking window should NOT cause shutdown
    $display("\n=== TEST 1: OVR_I pulses during blanking window ===");
    test_ovr_during_blanking();
    
    // Reset for next test
    reset_dut();
    
    // TEST 2: 40+ OVR_I pulses outside blanking window should cause shutdown
    $display("\n=== TEST 2: OVR_I pulses outside blanking window ===");
    test_ovr_outside_blanking();
    
    // Reset for next test
    reset_dut();
    
    // TEST 3: 40+ OVR_I pulses (both lft AND rght) during blanking window should NOT cause shutdown
    $display("\n=== TEST 3: Both OVR_I_lft AND OVR_I_rght pulses during blanking window ===");
    test_both_ovr_during_blanking();
    
    // Reset for next test
    reset_dut();
    
    // TEST 4: 40+ OVR_I pulses (both lft AND rght) outside blanking window should cause shutdown
    $display("\n=== TEST 4: Both OVR_I_lft AND OVR_I_rght pulses outside blanking window ===");
    test_both_ovr_outside_blanking();
    
    // Final results
    $display("\n=== TEST RESULTS ===");
    if (test_pass) begin
      $display("ALL TESTS PASSED!");
    end else begin
      $display("SOME TESTS FAILED!");
    end
    
    $display("Testbench complete.");
    $stop;
  end
  
  // Task to reset the DUT
  task reset_dut;
    begin
      rst_n = 0;
      OVR_I_lft = 0;
      OVR_I_rght = 0;
      repeat(10) @(posedge clk);
      rst_n = 1;
      repeat(10) @(posedge clk);
      lft_spd = 12'h400;
      rght_spd = 12'h400;
      repeat(10) @(posedge clk);
    end
  endtask
  
  // Task to wait for PWM_synch pulse (indicates start of new PWM cycle)
  task wait_for_pwm_synch;
    begin
      @(posedge iDUT.PWM_synch);
    end
  endtask
  
  // Task to test OVR_I pulses during blanking window
  task test_ovr_during_blanking;
    begin
      pwm_cycle_count = 0;
      ovr_pulse_count = 0;
      
      $display("Testing 45 PWM cycles with OVR_I during blanking periods...");
      
      // Test for 45 PWM cycles (more than the required 40)
      while (pwm_cycle_count < 45) begin
        // Wait for start of PWM cycle
        wait_for_pwm_synch();
        pwm_cycle_count++;
        
        // Wait for blanking period to start - look for ovr_I_blank to go high
        // The blanking period starts at NONOVERLAP (0x40) clocks after PWM_synch
        repeat(65) @(posedge clk); // Wait for blanking period to be active
        
        // Verify we're actually in blanking period
        if (iDUT.ovr_I_blank) begin
          // Generate OVR_I pulse during blanking window
          OVR_I_lft = 1;
          repeat(2) @(posedge clk);
          OVR_I_lft = 0;
          ovr_pulse_count++;
          
          // Display status every 10 cycles
          if (pwm_cycle_count % 10 == 0) begin
            $display("Cycle %0d: During blanking, OVR_I_cnt = %0d, ovr_I_blank = %b", 
                     pwm_cycle_count, iDUT.OVR_I_cnt, iDUT.ovr_I_blank);
          end
        end else begin
          $display("WARNING: Not in blanking period at expected time in cycle %0d", pwm_cycle_count);
        end
        
        // Check that shutdown hasn't occurred
        if (OVR_I_shtdwn) begin
          $display("ERROR: OVR_I_shtdwn asserted during blanking test at cycle %0d", pwm_cycle_count);
          test_pass = 0;
          break;
        end
      end
      
      $display("Completed %0d PWM cycles with %0d OVR_I pulses during blanking", pwm_cycle_count, ovr_pulse_count);
      
      // Final check - shutdown should NOT be active
      if (OVR_I_shtdwn) begin
        $display("FAIL: OVR_I_shtdwn is asserted when it should not be!");
        test_pass = 0;
      end else begin
        $display("PASS: OVR_I_shtdwn correctly remained inactive during blanking window test");
      end
    end
  endtask
  
  // Task to test OVR_I pulses outside blanking window
  task test_ovr_outside_blanking;
    begin
      pwm_cycle_count = 0;
      ovr_pulse_count = 0;
      
      $display("Testing PWM cycles with OVR_I outside blanking periods...");
      
      // Test for up to 35 PWM cycles, expect shutdown around cycle 31
      while (pwm_cycle_count < 35 && !OVR_I_shtdwn) begin
        // Wait for start of PWM cycle
        wait_for_pwm_synch();
        pwm_cycle_count++;
        
        // Wait for a time when we're definitely outside blanking
        // Go to middle of PWM period where blanking should be inactive
        repeat(20) @(posedge clk); 
        
        // Find a time when ovr_I_blank is low (outside blanking period)
        while (iDUT.ovr_I_blank && !OVR_I_shtdwn) begin
          @(posedge clk);
        end
        
        // Only generate pulse if we're outside blanking and not shutdown
        if (!iDUT.ovr_I_blank && !OVR_I_shtdwn) begin
          // Generate OVR_I pulse outside blanking window
          OVR_I_rght = 1;
          repeat(2) @(posedge clk);
          OVR_I_rght = 0;
          ovr_pulse_count++;
          
          // Display progress every 5 cycles
          if (pwm_cycle_count % 5 == 0) begin
            $display("Cycle %0d: Outside blanking, OVR_I_cnt = %0d, ovr_I_blank = %b, OVR_I_shtdwn = %b", 
                     pwm_cycle_count, iDUT.OVR_I_cnt, iDUT.ovr_I_blank, OVR_I_shtdwn);
          end
        end
        
        // Wait a bit before next cycle
        repeat(10) @(posedge clk);
      end
      
      $display("Completed %0d PWM cycles with %0d OVR_I pulses outside blanking", pwm_cycle_count, ovr_pulse_count);
      
      // Check if shutdown occurred as expected
      if (OVR_I_shtdwn) begin
        $display("PASS: OVR_I_shtdwn correctly asserted after %0d cycles (OVR_I_cnt reached %0d)", 
                 pwm_cycle_count, iDUT.OVR_I_cnt);
      end else begin
        $display("FAIL: OVR_I_shtdwn should have asserted but didn't after %0d cycles (OVR_I_cnt = %0d)", 
                 pwm_cycle_count, iDUT.OVR_I_cnt);
        test_pass = 0;
      end
    end
  endtask
  
  // Task to test both OVR_I_lft AND OVR_I_rght pulses during blanking window
  task test_both_ovr_during_blanking;
    begin
      pwm_cycle_count = 0;
      ovr_pulse_count = 0;
      
      $display("Testing 45 PWM cycles with BOTH OVR_I_lft AND OVR_I_rght during blanking periods...");
      
      // Test for 45 PWM cycles (more than the required 40)
      while (pwm_cycle_count < 45) begin
        // Wait for start of PWM cycle
        wait_for_pwm_synch();
        pwm_cycle_count++;
        
        // Wait for blanking period to start - look for ovr_I_blank to go high
        // The blanking period starts at NONOVERLAP (0x40) clocks after PWM_synch
        repeat(65) @(posedge clk); // Wait for blanking period to be active
        
        // Verify we're actually in blanking period
        if (iDUT.ovr_I_blank) begin
          // Generate simultaneous OVR_I pulses on both channels during blanking window
          OVR_I_lft = 1;
          OVR_I_rght = 1;
          repeat(2) @(posedge clk);
          OVR_I_lft = 0;
          OVR_I_rght = 0;
          ovr_pulse_count++;
          
          // Display status every 10 cycles
          if (pwm_cycle_count % 10 == 0) begin
            $display("Cycle %0d: Both signals during blanking, OVR_I_cnt = %0d, ovr_I_blank = %b", 
                     pwm_cycle_count, iDUT.OVR_I_cnt, iDUT.ovr_I_blank);
          end
        end else begin
          $display("WARNING: Not in blanking period at expected time in cycle %0d", pwm_cycle_count);
        end
        
        // Check that shutdown hasn't occurred
        if (OVR_I_shtdwn) begin
          $display("ERROR: OVR_I_shtdwn asserted during blanking test (both signals) at cycle %0d", pwm_cycle_count);
          test_pass = 0;
          break;
        end
      end
      
      $display("Completed %0d PWM cycles with %0d simultaneous OVR_I pulses during blanking", pwm_cycle_count, ovr_pulse_count);
      
      // Final check - shutdown should NOT be active
      if (OVR_I_shtdwn) begin
        $display("FAIL: OVR_I_shtdwn is asserted when it should not be (both signals during blanking)!");
        test_pass = 0;
      end else begin
        $display("PASS: OVR_I_shtdwn correctly remained inactive during blanking window test (both signals)");
      end
    end
  endtask
  
  // Task to test both OVR_I_lft AND OVR_I_rght pulses outside blanking window
  task test_both_ovr_outside_blanking;
    begin
      pwm_cycle_count = 0;
      ovr_pulse_count = 0;
      
      $display("Testing PWM cycles with BOTH OVR_I_lft AND OVR_I_rght outside blanking periods...");
      
      // Test for up to 35 PWM cycles, expect shutdown around cycle 31
      while (pwm_cycle_count < 35 && !OVR_I_shtdwn) begin
        // Wait for start of PWM cycle
        wait_for_pwm_synch();
        pwm_cycle_count++;
        
        // Wait for a time when we're definitely outside blanking
        // Go to middle of PWM period where blanking should be inactive
        repeat(20) @(posedge clk); 
        
        // Find a time when ovr_I_blank is low (outside blanking period)
        while (iDUT.ovr_I_blank && !OVR_I_shtdwn) begin
          @(posedge clk);
        end
        
        // Only generate pulse if we're outside blanking and not shutdown
        if (!iDUT.ovr_I_blank && !OVR_I_shtdwn) begin
          // Generate simultaneous OVR_I pulses on both channels outside blanking window
          OVR_I_lft = 1;
          OVR_I_rght = 1;
          repeat(2) @(posedge clk);
          OVR_I_lft = 0;
          OVR_I_rght = 0;
          ovr_pulse_count++;
          
          // Display progress every 5 cycles
          if (pwm_cycle_count % 5 == 0) begin
            $display("Cycle %0d: Both signals outside blanking, OVR_I_cnt = %0d, ovr_I_blank = %b, OVR_I_shtdwn = %b", 
                     pwm_cycle_count, iDUT.OVR_I_cnt, iDUT.ovr_I_blank, OVR_I_shtdwn);
          end
        end
        
        // Wait a bit before next cycle
        repeat(10) @(posedge clk);
      end
      
      $display("Completed %0d PWM cycles with %0d simultaneous OVR_I pulses outside blanking", pwm_cycle_count, ovr_pulse_count);
      
      // Check if shutdown occurred as expected
      if (OVR_I_shtdwn) begin
        $display("PASS: OVR_I_shtdwn correctly asserted after %0d cycles (both signals, OVR_I_cnt reached %0d)", 
                 pwm_cycle_count, iDUT.OVR_I_cnt);
      end else begin
        $display("FAIL: OVR_I_shtdwn should have asserted but didn't after %0d cycles (both signals, OVR_I_cnt = %0d)", 
                 pwm_cycle_count, iDUT.OVR_I_cnt);
        test_pass = 0;
      end
    end
  endtask
  
  // Monitor shutdown signal changes
  always @(posedge OVR_I_shtdwn) begin
    $display("*** SHUTDOWN ASSERTED at time %0t after %0d PWM cycles, OVR_I_cnt = %0d ***", 
             $time, iDUT.PWM_cycle_cnt, iDUT.OVR_I_cnt);
  end

endmodule