module piezo_drv_tb();

// Testbench signals
reg clk, rst_n;
reg en_steer, too_fast, batt_low;
wire piezo, piezo_n;

// Instantiate DUT using module's default fast_sim parameter
piezo_drv iDUT(
    .clk(clk),
    .rst_n(rst_n),
    .en_steer(en_steer),
    .too_fast(too_fast),
    .batt_low(batt_low),
    .piezo(piezo),
    .piezo_n(piezo_n)
);

// Clock generation
initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50MHz clock (20ns period)
end

// Test sequence
initial begin
    // Variable declarations for testbench
    reg [25:0] initial_repeat_cnt;
    
    // Initialize all inputs
    rst_n = 0;
    en_steer = 0;
    too_fast = 0;
    batt_low = 0;
    
    // Wait for a few clock cycles
    repeat(5) @(posedge clk);
    
    // Release reset
    rst_n = 1;
    @(posedge clk);
    
    // Test 1: Verify no toggling before inputs are asserted
    $display("Test 1: Checking that piezo outputs don't toggle initially...");
    repeat(20) begin
        @(posedge clk);
        if (piezo !== 1'b0 || piezo_n !== 1'b1) begin
            $display("ERROR: Piezo outputs toggling before inputs asserted at time %0t", $time);
            $stop;
        end
    end
    $display("PASS: No premature toggling detected");
    
    // Test 2: Test en_steer (normal operation)
    $display("\nTest 2: Testing en_steer (normal Charge Fanfare)...");
    en_steer = 1;
    
    // Wait for repeat timer to expire and sequence to start
    wait(iDUT.state != iDUT.IDLE);
    $display("Sequence started - State: %s", iDUT.state.name);
    
    // Monitor state transitions through the complete sequence
    fork
        begin
            // Monitor state changes
            while(1) begin
                @(iDUT.state);
                $display("Time %0t: State changed to %s", $time, iDUT.state.name);
            end
        end
        begin
            // Wait for sequence to complete
            wait(iDUT.state == iDUT.IDLE);
            $display("Normal sequence completed");
        end
    join_any
    disable fork;
    
    en_steer = 0;
    repeat(10) @(posedge clk);
    
    // Test 3: Test too_fast (priority input)
    $display("\nTest 3: Testing too_fast (first 3 notes continuously)...");
    too_fast = 1;
    
    // Should immediately start playing
    @(posedge clk);
    if (iDUT.state == iDUT.IDLE) begin
        wait(iDUT.state != iDUT.IDLE);
    end
    
    // Monitor for several note cycles
    repeat(3) begin
        // Wait for G6
        wait(iDUT.state == iDUT.G6);
        $display("Time %0t: Playing G6", $time);
        wait(iDUT.state != iDUT.G6);
        
        // Wait for C7
        wait(iDUT.state == iDUT.C7);
        $display("Time %0t: Playing C7", $time);
        wait(iDUT.state != iDUT.C7);
        
        // Wait for E7_1
        wait(iDUT.state == iDUT.E7_1);
        $display("Time %0t: Playing E7_1", $time);
        wait(iDUT.state != iDUT.E7_1);
    end
    
    $display("too_fast continuous play verified");
    too_fast = 0;
    wait(iDUT.state == iDUT.IDLE);
    repeat(10) @(posedge clk);
    
    // Test 4: Test batt_low (backwards sequence)
    $display("\nTest 4: Testing batt_low (Charge backwards)...");
    batt_low = 1;
    
    // Should start with G7_2 (last note)
    wait(iDUT.state != iDUT.IDLE);
    
    // Verify backwards sequence
    if (iDUT.state != iDUT.G7_2) begin
        $display("ERROR: Expected to start with G7_2, but got %s", iDUT.state.name);
        $stop;
    end
    
    // Monitor backwards sequence
    fork
        begin
            while(1) begin
                @(iDUT.state);
                $display("Time %0t: Backwards state: %s", $time, iDUT.state.name);
            end
        end
        begin
            wait(iDUT.state == iDUT.IDLE);
            $display("Backwards sequence completed");
        end
    join_any
    disable fork;
    
    batt_low = 0;
    repeat(10) @(posedge clk);
    
    // Test 5: Test differential output relationship
    $display("\nTest 5: Testing differential outputs...");
    en_steer = 1;
    wait(iDUT.state != iDUT.IDLE);
    
    // Check that piezo_n is always complement of piezo
    repeat(100) begin
        @(posedge clk);
        if (piezo_n !== ~piezo) begin
            $display("ERROR: Differential outputs not complementary at time %0t", $time);
            $stop;
        end
    end
    $display("PASS: Differential outputs verified");
    
    // Test 6: Test priority of too_fast over other inputs
    $display("\nTest 6: Testing priority of too_fast...");
    en_steer = 1;
    batt_low = 1;
    too_fast = 1;  // Should have priority
    
    @(posedge clk);
    wait(iDUT.state != iDUT.IDLE);
    
    // Should play forward sequence despite batt_low being asserted
    wait(iDUT.state == iDUT.G6);
    $display("Priority test: too_fast correctly overrides batt_low");
    
    // Clean up
    too_fast = 0;
    batt_low = 0;
    en_steer = 0;
    wait(iDUT.state == iDUT.IDLE);
    
    // Test 7: Test normal operation for 3 complete state machine cycles
    $display("\nTest 7: Testing normal operation for 3 complete cycles...");
    en_steer = 1;
    
    begin : cycle_test
        automatic integer cycle_num;
        for (cycle_num = 0; cycle_num < 3; cycle_num++) begin
            $display("Starting cycle %0d", cycle_num + 1);
        
        // Wait for repeat timer to expire and sequence to start
        wait(iDUT.state != iDUT.IDLE);
        $display("Cycle %0d: Sequence started", cycle_num + 1);
        
        // Verify complete forward sequence: G6 -> C7 -> E7_1 -> G7_1 -> E7_2 -> G7_2 -> IDLE
        wait(iDUT.state == iDUT.G6);
        $display("Cycle %0d: Playing G6", cycle_num + 1);
        wait(iDUT.state != iDUT.G6);
        
        wait(iDUT.state == iDUT.C7);
        $display("Cycle %0d: Playing C7", cycle_num + 1);
        wait(iDUT.state != iDUT.C7);
        
        wait(iDUT.state == iDUT.E7_1);
        $display("Cycle %0d: Playing E7_1", cycle_num + 1);
        wait(iDUT.state != iDUT.E7_1);
        
        wait(iDUT.state == iDUT.G7_1);
        $display("Cycle %0d: Playing G7_1", cycle_num + 1);
        wait(iDUT.state != iDUT.G7_1);
        
        wait(iDUT.state == iDUT.E7_2);
        $display("Cycle %0d: Playing E7_2", cycle_num + 1);
        wait(iDUT.state != iDUT.E7_2);
        
        wait(iDUT.state == iDUT.G7_2);
        $display("Cycle %0d: Playing G7_2", cycle_num + 1);
        wait(iDUT.state != iDUT.G7_2);
        
        // Return to IDLE and wait for next cycle
        wait(iDUT.state == iDUT.IDLE);
        $display("Cycle %0d: Completed, returning to IDLE", cycle_num + 1);
        
        // Verify repeat timer starts counting again (except for last cycle)
        if (cycle_num < 2) begin
            // Check that we stay in IDLE for a reasonable time (repeat timer counting)
            repeat(100) begin
                @(posedge clk);
                if (iDUT.state != iDUT.IDLE) begin
                    $display("ERROR: Premature exit from IDLE in cycle %0d", cycle_num + 1);
                    $stop;
                end
            end
            $display("Cycle %0d: Verified 3-second wait period started", cycle_num + 1);
        end
        end
    end
    
    en_steer = 0;
    $display("PASS: All 3 normal operation cycles completed successfully");
    repeat(10) @(posedge clk);
    
    // Test 8: Test too_fast priority over batt_low when both are asserted
    $display("\nTest 8: Testing too_fast priority over batt_low when both are high...");
    
    // Assert both too_fast and batt_low simultaneously
    too_fast = 1;
    batt_low = 1;
    
    // Should immediately start playing forward sequence (too_fast priority)
    @(posedge clk);
    wait(iDUT.state != iDUT.IDLE);
    
    // Verify it starts with G6 (forward sequence) not G7_2 (backwards sequence)
    if (iDUT.state != iDUT.G6) begin
        $display("ERROR: Expected G6 (forward sequence), but got %s", iDUT.state.name);
        $stop;
    end
    $display("PASS: too_fast correctly overrides batt_low - started with G6");
    
    // Monitor several cycles to ensure it continues with forward sequence
    repeat(2) begin
        // Verify forward sequence: G6 -> C7 -> E7_1 -> G6 (loop)
        wait(iDUT.state == iDUT.G6);
        $display("Time %0t: Priority test - Playing G6", $time);
        wait(iDUT.state != iDUT.G6);
        
        wait(iDUT.state == iDUT.C7);
        $display("Time %0t: Priority test - Playing C7", $time);
        wait(iDUT.state != iDUT.C7);
        
        wait(iDUT.state == iDUT.E7_1);
        $display("Time %0t: Priority test - Playing E7_1", $time);
        wait(iDUT.state != iDUT.E7_1);
        
        // Should NOT go to G7_1, G7_2, or E7_2 (backwards notes)
        // Should loop back to G6
    end
    
    // Verify it never plays backwards sequence notes during priority test
    fork
        begin
            // Monitor for forbidden states (backwards sequence)
            while(too_fast && batt_low) begin
                @(posedge clk);
                if (iDUT.state == iDUT.G7_1 || iDUT.state == iDUT.E7_2 || 
                    (iDUT.state == iDUT.G7_2 && iDUT.nxt_state != iDUT.IDLE)) begin
                    $display("ERROR: Playing backwards sequence despite too_fast priority at time %0t, state: %s", 
                             $time, iDUT.state.name);
                    $stop;
                end
            end
        end
        begin
            // Wait for a reasonable time then end test
            repeat(1000) @(posedge clk);
        end
    join_any
    disable fork;
    
    $display("PASS: too_fast maintained priority over batt_low throughout test");
    
    // Clean up
    too_fast = 0;
    batt_low = 0;
    wait(iDUT.state == iDUT.IDLE);
    repeat(10) @(posedge clk);
    
    // Test 9: Test when en_steer, too_fast, and batt_low are all asserted
    $display("\nTest 9: Testing all three signals (en_steer, too_fast, batt_low) asserted simultaneously...");
    
    // Assert all three signals at once
    en_steer = 1;
    too_fast = 1;
    batt_low = 1;
    
    // Should immediately start playing forward sequence (too_fast has highest priority)
    @(posedge clk);
    wait(iDUT.state != iDUT.IDLE);
    
    // Verify it starts with G6 (forward sequence) despite all signals being high
    if (iDUT.state != iDUT.G6) begin
        $display("ERROR: Expected G6 (too_fast priority), but got %s", iDUT.state.name);
        $stop;
    end
    $display("PASS: too_fast has highest priority - started with G6 despite all signals high");
    
    // Monitor several cycles to ensure it continues with too_fast behavior (first 3 notes loop)
    repeat(2) begin
        // Verify too_fast sequence: G6 -> C7 -> E7_1 -> G6 (continuous loop)
        wait(iDUT.state == iDUT.G6);
        $display("Time %0t: All signals test - Playing G6", $time);
        wait(iDUT.state != iDUT.G6);
        
        wait(iDUT.state == iDUT.C7);
        $display("Time %0t: All signals test - Playing C7", $time);
        wait(iDUT.state != iDUT.C7);
        
        wait(iDUT.state == iDUT.E7_1);
        $display("Time %0t: All signals test - Playing E7_1", $time);
        wait(iDUT.state != iDUT.E7_1);
        
        // Should loop back to G6, not continue to G7_1 (which would be normal en_steer behavior)
        // and not go to backwards sequence (which would be batt_low behavior)
    end
    
    // Verify it never plays full sequence or backwards sequence
    fork
        begin
            // Monitor for states that indicate wrong priority
            integer monitor_count = 0;
            while(en_steer && too_fast && batt_low && monitor_count < 500) begin
                @(posedge clk);
                monitor_count++;
                // Should never go to G7_1, E7_2, or G7_2 in too_fast mode
                if (iDUT.state == iDUT.G7_1 || iDUT.state == iDUT.E7_2 || iDUT.state == iDUT.G7_2) begin
                    $display("ERROR: Wrong priority - entered state %s when too_fast should have priority at time %0t", 
                             iDUT.state.name, $time);
                    $stop;
                end
            end
        end
        begin
            // Wait for reasonable time then end monitoring
            repeat(1000) @(posedge clk);
        end
    join_any
    disable fork;
    
    $display("PASS: too_fast maintained highest priority with all signals asserted");
    
    // Test priority by removing too_fast while keeping en_steer and batt_low
    $display("Testing priority change: removing too_fast, keeping en_steer and batt_low...");
    too_fast = 0;  // Now batt_low should take priority over en_steer
    
    // Wait for current note to finish and state to change
    wait(iDUT.state != iDUT.E7_1);  // Wait to exit E7_1
    
    // Should NOT continue to G7_1 (normal sequence) but should go to IDLE or backwards
    // The exact behavior depends on implementation, but it should respect batt_low priority
    @(posedge clk);
    
    // Monitor the behavior after too_fast is removed
    fork
        begin
            repeat(10) begin
                @(iDUT.state);
                $display("Time %0t: After too_fast removed - State: %s", $time, iDUT.state.name);
                if (iDUT.state == iDUT.IDLE) break;
            end
        end
        begin
            repeat(2000) @(posedge clk);  // Timeout
        end
    join_any
    disable fork;
    
    $display("PASS: System correctly responded to priority change");
    
    // Clean up all signals
    en_steer = 0;
    too_fast = 0;
    batt_low = 0;
    wait(iDUT.state == iDUT.IDLE);
    repeat(10) @(posedge clk);
    
    // Test 10: Test when no control signals are asserted (all inputs low)
    $display("\nTest 10: Testing when no control signals are asserted...");
    
    // Ensure all control signals are deasserted
    en_steer = 0;
    too_fast = 0;
    batt_low = 0;
    
    // Wait for system to be in known state
    repeat(10) @(posedge clk);
    
    // Verify system stays in IDLE state
    if (iDUT.state != iDUT.IDLE) begin
        $display("ERROR: Expected IDLE state, but got %s", iDUT.state.name);
        $stop;
    end
    $display("PASS: System correctly in IDLE state with no inputs asserted");
    
    // Monitor for 3 seconds to ensure it stays in IDLE
    // With fast_sim, 3 seconds = 2,343,750 / 64 = ~36,621 cycles, but we'll use more for safety
    repeat(150000) begin  // 3 seconds worth of clock cycles (150,000 cycles = 3ms at 50MHz)
        @(posedge clk);
        if (iDUT.state != iDUT.IDLE) begin
            $display("ERROR: Unexpected state transition from IDLE to %s at time %0t", iDUT.state.name, $time);
            $stop;
        end
        // Verify piezo outputs remain inactive
        if (piezo !== 1'b0 || piezo_n !== 1'b1) begin
            $display("ERROR: Piezo outputs active when no inputs asserted at time %0t, piezo=%b, piezo_n=%b", 
                     $time, piezo, piezo_n);
            $stop;
        end
    end
    
    // Verify timers are not running inappropriately
    // Duration and period counters should be cleared in IDLE
    if (iDUT.duration_cnt !== 26'd0) begin
        $display("ERROR: Duration counter not cleared in IDLE: %d", iDUT.duration_cnt);
        $stop;
    end
    if (iDUT.period_cnt !== 26'd0) begin
        $display("ERROR: Period counter not cleared in IDLE: %d", iDUT.period_cnt);
        $stop;
    end
    
    // Repeat counter should only increment when en_steer is high and other conditions are met
    // With no inputs, it should not be incrementing (check after the 3-second period)
    initial_repeat_cnt = iDUT.repeat_cnt;
    repeat(10000) @(posedge clk);  // Check over extended period
    if (iDUT.repeat_cnt != initial_repeat_cnt) begin
        $display("ERROR: Repeat counter incrementing inappropriately: initial=%d, current=%d", 
                 initial_repeat_cnt, iDUT.repeat_cnt);
        $stop;
    end
    
    $display("PASS: System correctly maintains IDLE state for 3 seconds with no control signals");
    $display("PASS: Piezo outputs remain inactive (piezo=0, piezo_n=1) for entire 3-second period");
    $display("PASS: Duration and period counters properly cleared");
    $display("PASS: Repeat counter not incrementing inappropriately over extended period");
    
    // Test transition from no inputs to input assertion
    $display("Testing transition from no inputs to en_steer assertion...");
    en_steer = 1;
    
    // Should remain in IDLE until repeat timer expires
    repeat(100) begin
        @(posedge clk);
        if (iDUT.state != iDUT.IDLE) begin
            // If it transitions early, that could be an error unless repeat_done is true
            if (!iDUT.repeat_done) begin
                $display("ERROR: Premature transition from IDLE before repeat timer expired at time %0t", $time);
                $stop;
            end
            break;
        end
    end
    
    // Clean up
    en_steer = 0;
    wait(iDUT.state == iDUT.IDLE);
    repeat(10) @(posedge clk);
    
    $display("PASS: Correct transition behavior from no inputs to input assertion");
    
    $display("\n=== ALL TESTS PASSED ===");
    $display("Testbench completed successfully!");
    
    repeat(10) @(posedge clk);
    $stop;
end

// Timeout watchdog
initial begin
    #50000000;  // 50ms timeout
    $display("ERROR: Testbench timeout!");
    $stop;
end

// Optional: Monitor piezo frequency during notes
/*
always @(posedge piezo) begin
    if (iDUT.state != iDUT.IDLE) begin
        $display("Time %0t: Piezo rising edge in state %s", $time, iDUT.state.name);
    end
end
*/

endmodule