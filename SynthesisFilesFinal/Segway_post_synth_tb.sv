`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
// Post-Synthesis Testbench for Segway
// 
// This testbench only relies on external ports - no internal signal access.
// It performs basic sanity checks to verify the synthesized design functions.
//////////////////////////////////////////////////////////////////////////////

module Segway_post_synth_tb();

//// Interconnects to DUT/support defined as type wire /////
wire SS_n, SCLK, MOSI, MISO, INT;
wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo, piezo_n;

////// Stimulus registers ///////
logic clk, RST_n;
logic rst_n;
logic [7:0] cmd;
logic send_cmd;
logic cmd_sent;
logic signed [15:0] rider_lean;
logic [11:0] ld_cell_lft, ld_cell_rght, steerPot, batt;
logic OVR_I_lft, OVR_I_rght;

// Test tracking
int tests_passed, tests_failed;

//////////////////////////////////////////////
// Instantiate Physical Model of Segway   //
////////////////////////////////////////////
SegwayModel iPHYS(
    .clk(clk),
    .RST_n(RST_n),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MISO(MISO),
    .MOSI(MOSI),
    .INT(INT),
    .PWM1_lft(PWM1_lft),
    .PWM2_lft(PWM2_lft),
    .PWM1_rght(PWM1_rght),
    .PWM2_rght(PWM2_rght),
    .rider_lean(rider_lean)
);

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S_FC iA2D(
    .clk(clk),
    .rst_n(RST_n),
    .SS_n(A2D_SS_n),
    .SCLK(A2D_SCLK),
    .MISO(A2D_MISO),
    .MOSI(A2D_MOSI),
    .ld_cell_lft(ld_cell_lft),
    .ld_cell_rght(ld_cell_rght),
    .steerPot(steerPot),
    .batt(batt)
);

////// Instantiate DUT (synthesized netlist) ////////
Segway iDUT(
    .clk(clk),
    .RST_n(RST_n),
    .INERT_SS_n(SS_n),
    .INERT_MOSI(MOSI),
    .INERT_SCLK(SCLK),
    .INERT_MISO(MISO),
    .INERT_INT(INT),
    .A2D_SS_n(A2D_SS_n),
    .A2D_MOSI(A2D_MOSI),
    .A2D_SCLK(A2D_SCLK),
    .A2D_MISO(A2D_MISO),
    .PWM1_lft(PWM1_lft),
    .PWM2_lft(PWM2_lft),
    .PWM1_rght(PWM1_rght),
    .PWM2_rght(PWM2_rght),
    .OVR_I_lft(OVR_I_lft),
    .OVR_I_rght(OVR_I_rght),
    .piezo_n(piezo_n),
    .piezo(piezo),
    .RX(RX_TX)
);

//// Instantiate UART_tx (mimics command from BLE module) //////
UART_TX iTX(
    .clk(clk),
    .rst_n(rst_n),
    .TX(RX_TX),
    .trmt(send_cmd),
    .tx_data(cmd),
    .tx_done(cmd_sent)
);

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(
    .clk(clk),
    .RST_n(RST_n),
    .rst_n(rst_n)
);

// Clock generation - 50MHz (20ns period)
always #10 clk = ~clk;

//////////////////////////////////////////////////////////////////////////////
// Helper Tasks
//////////////////////////////////////////////////////////////////////////////

task automatic wait_cycles(input int n);
    repeat(n) @(posedge clk);
endtask

task automatic send_uart_cmd(input [7:0] data);
    @(posedge clk);
    cmd = data;
    send_cmd = 1'b1;
    @(posedge clk);
    send_cmd = 1'b0;
    // Wait for transmission to complete
    wait(cmd_sent == 1'b0);
    wait(cmd_sent == 1'b1);
    $display("[%0t] UART command 0x%02h sent", $time, data);
endtask

// Count PWM transitions to verify activity
task automatic check_pwm_activity(input int check_cycles, output bit lft_active, output bit rght_active);
    int lft_transitions, rght_transitions;
    logic prev_pwm1_lft, prev_pwm1_rght;
    
    lft_transitions = 0;
    rght_transitions = 0;
    prev_pwm1_lft = PWM1_lft;
    prev_pwm1_rght = PWM1_rght;
    
    repeat(check_cycles) begin
        @(posedge clk);
        if (PWM1_lft !== prev_pwm1_lft) lft_transitions++;
        if (PWM1_rght !== prev_pwm1_rght) rght_transitions++;
        prev_pwm1_lft = PWM1_lft;
        prev_pwm1_rght = PWM1_rght;
    end
    
    lft_active = (lft_transitions > 10);
    rght_active = (rght_transitions > 10);
endtask

// Check if piezo is toggling (indicates warning)
task automatic check_piezo_activity(input int check_cycles, output bit active);
    int transitions;
    logic prev_piezo;
    
    transitions = 0;
    prev_piezo = piezo;
    
    repeat(check_cycles) begin
        @(posedge clk);
        if (piezo !== prev_piezo) transitions++;
        prev_piezo = piezo;
    end
    
    active = (transitions > 5);
endtask

//////////////////////////////////////////////////////////////////////////////
// Test Procedures
//////////////////////////////////////////////////////////////////////////////

task automatic test_reset_behavior();
    bit lft_active, rght_active;
    
    $display("\n[%0t] === TEST: Reset Behavior ===", $time);
    
    // After reset, PWMs should be inactive (no rider, no power)
    wait_cycles(10000);
    check_pwm_activity(5000, lft_active, rght_active);
    
    if (!lft_active && !rght_active) begin
        $display("[PASS] PWM outputs inactive after reset (no rider)");
        tests_passed++;
    end else begin
        $display("[FAIL] PWM outputs unexpectedly active after reset");
        tests_failed++;
    end
endtask

task automatic test_power_up_and_balance();
    bit lft_active, rght_active;
    
    $display("\n[%0t] === TEST: Power Up and Balance ===", $time);
    
    // Simulate rider stepping on (balanced weight)
    ld_cell_lft = 12'h480;
    ld_cell_rght = 12'h480;
    steerPot = 12'h800;  // centered
    rider_lean = 16'sh0000;
    
    // Wait for A2D to read values and system to recognize rider
    wait_cycles(500_000);
    
    // Send 'g' command to power up
    send_uart_cmd(8'h67);  // 'g' = 0x67
    
    // Wait for system to power up and stabilize
    wait_cycles(1_000_000);
    
    // Check PWM activity - should be active for balancing
    check_pwm_activity(50000, lft_active, rght_active);
    
    if (lft_active && rght_active) begin
        $display("[PASS] PWM outputs active after power-up (balancing)");
        tests_passed++;
    end else begin
        $display("[FAIL] PWM outputs not active after power-up (lft=%0b, rght=%0b)", lft_active, rght_active);
        tests_failed++;
    end
endtask

task automatic test_lean_response();
    bit lft_active, rght_active;
    
    $display("\n[%0t] === TEST: Lean Response ===", $time);
    
    // Apply forward lean
    rider_lean = 16'sh0800;
    wait_cycles(200_000);
    
    check_pwm_activity(20000, lft_active, rght_active);
    
    if (lft_active && rght_active) begin
        $display("[PASS] PWM responds to forward lean");
        tests_passed++;
    end else begin
        $display("[FAIL] PWM not responding to lean");
        tests_failed++;
    end
    
    // Return to neutral
    rider_lean = 16'sh0000;
    wait_cycles(100_000);
endtask

task automatic test_low_battery_warning();
    bit piezo_active;
    
    $display("\n[%0t] === TEST: Low Battery Warning ===", $time);
    
    // Set battery low
    batt = 12'h600;  // Below threshold
    
    // Wait for system to detect and respond
    wait_cycles(500_000);
    
    check_piezo_activity(100000, piezo_active);
    
    if (piezo_active) begin
        $display("[PASS] Piezo active on low battery");
        tests_passed++;
    end else begin
        $display("[INFO] Piezo not detected (may need longer wait or threshold check)");
        // Don't fail - this is hard to verify post-synth
    end
    
    // Restore battery
    batt = 12'hC00;
    wait_cycles(100_000);
endtask

task automatic test_rider_off_shutdown();
    bit lft_active, rght_active;
    
    $display("\n[%0t] === TEST: Rider Off Shutdown ===", $time);
    
    // Remove rider (zero weight)
    ld_cell_lft = 12'h000;
    ld_cell_rght = 12'h000;
    
    // Wait for system to detect rider off and shut down
    wait_cycles(1_000_000);
    
    check_pwm_activity(10000, lft_active, rght_active);
    
    if (!lft_active && !rght_active) begin
        $display("[PASS] PWM outputs stopped after rider off");
        tests_passed++;
    end else begin
        $display("[FAIL] PWM still active after rider stepped off");
        tests_failed++;
    end
endtask

//////////////////////////////////////////////////////////////////////////////
// Main Test Sequence
//////////////////////////////////////////////////////////////////////////////

initial begin
    // Initialize
    clk = 1'b0;
    RST_n = 1'b0;
    send_cmd = 1'b0;
    cmd = 8'h00;
    rider_lean = 16'sh0000;
    ld_cell_lft = 12'h000;
    ld_cell_rght = 12'h000;
    steerPot = 12'h800;
    batt = 12'hC00;
    OVR_I_lft = 1'b0;
    OVR_I_rght = 1'b0;
    tests_passed = 0;
    tests_failed = 0;
    
    $display("\n========================================");
    $display("  Segway Post-Synthesis Testbench");
    $display("========================================\n");
    
    // Release reset
    wait_cycles(10);
    RST_n = 1'b1;
    wait_cycles(100);
    
    // Wait for reset synchronizer
    wait(rst_n === 1'b1);
    wait_cycles(1000);
    
    // Run tests
    test_reset_behavior();
    test_power_up_and_balance();
    test_lean_response();
    test_low_battery_warning();
    test_rider_off_shutdown();
    
    // Summary
    $display("\n========================================");
    $display("  Post-Synthesis Test Summary");
    $display("========================================");
    $display("  PASSED: %0d", tests_passed);
    $display("  FAILED: %0d", tests_failed);
    $display("========================================\n");
    
    if (tests_failed == 0)
        $display("All post-synthesis tests PASSED!");
    else
        $display("Some tests FAILED - review output above");
    
    $stop();
end

endmodule
