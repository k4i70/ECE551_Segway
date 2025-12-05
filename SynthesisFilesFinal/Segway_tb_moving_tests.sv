`timescale 1ns/1ps
module Segway_tb_moving_tests();
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo,piezo_n;
reg cmd_sent;
wire rst_n;					// synchronized global reset

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;				// command host is sending to DUT
reg send_cmd;				// asserted to initiate sending of command
reg signed [15:0] rider_lean;
reg [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
reg OVR_I_lft, OVR_I_rght;

// Self-checking bookkeeping
int pass_cnt = 0;
int fail_cnt = 0;

// Monitors for passing by-ref into tests_package tasks
logic pwr_up_mon, en_steer_mon, rider_off_mon, batt_low_mon, piezo_mon;

// Generic check helper
task automatic check(input bit cond, input string msg);
  if (!cond) begin
    $error("[%0t] CHECK FAIL: %s", $time, msg); fail_cnt++;
  end else begin
    pass_cnt++;
  end
endtask

// Summarize results
task automatic report_results();
  if (fail_cnt == 0) begin
    $display("[%0t] ALL %0d CHECKS PASSED", $time, pass_cnt);
  end else begin
    $display("[%0t] TEST FAILED: %0d passed, %0d failed", $time, pass_cnt, fail_cnt);
  end
endtask

////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Segway with Inertial sensor //
//////////////////////////////////////////////////////////////	
SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                  .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM1_lft(PWM1_lft),
				  .PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
				  .PWM2_rght(PWM2_rght),.rider_lean(rider_lean));				  

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S_FC iA2D(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
             .MISO(A2D_MISO),.MOSI(A2D_MOSI),.ld_cell_lft(ld_cell_lft),.ld_cell_rght(ld_cell_rght),
			 .steerPot(steerPot),.batt(batt));			
	 
////// Instantiate DUT ////////
Segway iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
            .INERT_SCLK(SCLK),.INERT_MISO(MISO),.INERT_INT(INT),.A2D_SS_n(A2D_SS_n),
			.A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
			.PWM1_lft(PWM1_lft),.PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
			.PWM2_rght(PWM2_rght),.OVR_I_lft(OVR_I_lft),.OVR_I_rght(OVR_I_rght),
			.piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));

//// Instantiate UART_tx (mimics command from BLE module) //////
UART_TX iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

// Drive monitor mirrors from DUT internals (for passing by ref to package tasks)
always @* begin
  pwr_up_mon    = iDUT.pwr_up;
  en_steer_mon  = iDUT.en_steer;
  rider_off_mon = iDUT.rider_off;
  batt_low_mon  = iDUT.batt_low;
  piezo_mon     = piezo;
end

// Testbench tasks and stimulus added
// Utility task to wait N clock cycles
  task automatic wait_cycles(input int cycles);
    repeat(cycles) @(posedge clk);
  endtask

  // Apply async reset then release
  task automatic apply_reset();
    begin
      clk = 0;
      RST_n = 0;
      send_cmd = 0;
      cmd = 8'h00;
      rider_lean = 16'sh0000;
      ld_cell_lft = 12'd0;
      ld_cell_rght = 12'd0;
      steerPot = 12'h800; // mid value
      batt = 12'h900; // above threshold
      OVR_I_lft = 1'b0;
      OVR_I_rght = 1'b0;
      wait_cycles(10);
      RST_n = 1;
      wait_cycles(50);
      $display("[%0t] Reset released", $time);
      check(iDUT.pwr_up==0, "pwr_up should be low after reset before 'G' command");
      check(iDUT.en_steer==0, "en_steer should be low before rider weight applied");
    end
  endtask

  // Send a UART command byte (simulate BLE command)
  task automatic send_uart_cmd(input byte value);
    begin
      cmd = value;
      send_cmd = 1'b1;
      @(posedge clk);
      send_cmd = 1'b0; // pulse
      // Wait for cmd_sent
      wait(cmd_sent === 1'b1);
      $display("[%0t] UART cmd 0x%0h sent", $time, value);
      // Allow done to drop
      wait(cmd_sent === 1'b0);
      if (value==8'h47) begin
        // Expect power-up
        wait_cycles(5);
        check(iDUT.pwr_up==1, "pwr_up should assert after 'G' command");
      end
      if (value==8'h53) begin
        // Expect power-down after rider_off becomes true
        wait_cycles(20);
        check(iDUT.pwr_up==0, "pwr_up should deassert after 'S' command & rider_off");
      end
    end
  endtask

  // Apply balanced rider weight to enable steering
  task automatic enable_steering();
    begin
      ld_cell_lft = 12'd400;
      ld_cell_rght = 12'd400; // sum = 800 (> 576 threshold with hysteresis)
      wait_cycles(10);
      // Wait for en_steer to assert (hierarchical wire inside DUT)
      wait(iDUT.en_steer === 1'b1);
      $display("[%0t] Steering enabled (en_steer=1)", $time);
      check(iDUT.en_steer==1, "en_steer must assert after sufficient rider weight");
    end
  endtask

  // Exercise steering by sweeping steerPot while steering enabled
  task automatic steering_sweep();
    int i; int changed_cnt=0; logic signed [11:0] prev_lft, prev_rght;
    begin
      prev_lft = iDUT.lft_spd; prev_rght = iDUT.rght_spd;
      // Sweep left
      for (i = 0; i < 6; i++) begin
        steerPot = 12'h200 + (i*12'h100); // within saturation range 0x200..0xE00
        wait_cycles(10000);
        if (iDUT.lft_spd!=prev_lft || iDUT.rght_spd!=prev_rght) changed_cnt++;
        prev_lft = iDUT.lft_spd; prev_rght = iDUT.rght_spd;
        $display("[%0t] Steering sweep step %0d steerPot=0x%0h lft_spd=%0d rght_spd=%0d", $time, i, steerPot, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      end
      // Sweep right
      for (i = 5; i >= 0; i--) begin
        steerPot = 12'h200 + (i*12'h100);
        wait_cycles(10000); // longer wait to observe return
        if (iDUT.lft_spd!=prev_lft || iDUT.rght_spd!=prev_rght) changed_cnt++;
        prev_lft = iDUT.lft_spd; prev_rght = iDUT.rght_spd;
        $display("[%0t] Steering sweep (return) step %0d steerPot=0x%0h lft_spd=%0d rght_spd=%0d", $time, i, steerPot, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      end
      check(changed_cnt>=6, "Steering sweep should produce multiple speed changes");
      steerPot = 12'h800; // return to center
      wait_cycles(10000);
    end
  endtask

  // Test rider lean forward/backward
  task automatic rider_lean_test();
    begin
      rider_lean = 16'h0F00; wait_cycles(100000);
      $display("[%0t] Forward lean 0x0F00 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      check(iDUT.lft_spd>0 && iDUT.rght_spd>0, "Forward lean 0x0F00 should drive positive speeds");
      rider_lean = 16'h0800; wait_cycles(100000);
      $display("[%0t] Forward lean 0x0800 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      check(iDUT.lft_spd>0 && iDUT.rght_spd>0, "Forward lean 0x0800 should drive positive speeds");
      // Backward lean
      rider_lean = 16'hE000; wait_cycles(100000);
      $display("[%0t] Backward lean -0x0200 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      check(iDUT.lft_spd<0 && iDUT.rght_spd<0, "Backward lean -0x0200 should drive negative speeds");
      rider_lean = 16'hFF00; wait_cycles(100000);
      $display("[%0t] Backward lean -0x0400 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      check(iDUT.lft_spd<0 && iDUT.rght_spd<0, "Backward lean -0x0400 should drive negative speeds");
      rider_lean = 16'h0000; wait_cycles(100000);
      check(iDUT.lft_spd==0 && iDUT.rght_spd==0, "Neutral lean should return speeds to zero");
    end
  endtask

  // Induce overspeed (too_fast) by large lean value
  task automatic induce_too_fast();
    begin
      rider_lean = 16'sh18FF; // large forward lean within allowed limit
      wait_cycles(10000);
      if (iDUT.too_fast) begin
        $display("[%0t] too_fast asserted (overspeed)", $time);
      end else begin
        $display("[%0t] WARNING: too_fast not asserted yet", $time);
      end
      check(iDUT.too_fast==1, "too_fast should assert under large forward lean");
    end
  endtask

  // Simulate repeated overcurrent events to force motor shutdown
  task automatic overcurrent_test();
    int k;
    begin
      $display("[%0t] Starting overcurrent test", $time);
      for (k = 0; k < 60 && (iDUT.iDRV.OVR_I_shtdwn===1'b0); k++) begin
        OVR_I_lft = 1'b1; OVR_I_rght = 1'b1;
        wait_cycles(2);
        OVR_I_lft = 1'b0; OVR_I_rght = 1'b0;
        wait_cycles(10000);
      end
      if (iDUT.iDRV.OVR_I_shtdwn) begin
        $display("[%0t] OVR_I_shtdwn asserted after %0d pulses. PWM outputs should be forced low.", $time, k);
        // Give a few cycles for PWM gating
        wait_cycles(10);
        check(PWM1_lft==0 && PWM2_lft==0 && PWM1_rght==0 && PWM2_rght==0, "All PWM outputs must be low after overcurrent shutdown");
      end else begin
        $display("[%0t] WARNING: OVR_I_shtdwn NOT asserted after %0d pulses", $time, k);
      end
      check(iDUT.iDRV.OVR_I_shtdwn==1, "OVR_I_shtdwn should assert after repeated overcurrent pulses");
    end
  endtask

  // Optional power down sequence
  task automatic power_down();
    begin
      // Use package UART helper to send 'S' and then check shutdown behavior
      tests_package::send_uart_byte(clk, cmd_sent, send_cmd, cmd, 8'h53, "PowerDown_S");
      ld_cell_lft = 12'd0; ld_cell_rght = 12'd0; // remove rider weight triggers rider_off
      wait_cycles(100000);
      $display("[%0t] Power down sequence complete", $time);
      check(iDUT.rider_off==1, "rider_off should assert after load cells cleared");
      check(iDUT.en_steer==0, "en_steer should deassert when rider_off asserted");
      check(iDUT.pwr_up==0, "pwr_up should remain low after power down");
      check(iDUT.lft_spd==0 && iDUT.rght_spd==0, "Speeds should be zero after power down");
    end
  endtask

  // Monitor important status changes
  initial begin
    $display("[%0t] Testbench start", $time);
    apply_reset();
    // Use tests_package to perform startup checks and step-on sequence
    tests_package::startup_test(clk, pwr_up_mon, en_steer_mon, rider_off_mon, piezo_mon);
    tests_package::step_on_test(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
                                cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon);
    steering_sweep();
    rider_lean_test();
    induce_too_fast();
    overcurrent_test();
    power_down();
    report_results();
    if (fail_cnt==0) begin
      $finish;
    end else begin
      $fatal(1, "Self-checking failures detected");
    end
  end

  // Simple event monitors
  always @(posedge iDUT.en_steer) $display("[%0t] EVENT: en_steer asserted", $time);
  always @(posedge iDUT.too_fast) $display("[%0t] EVENT: too_fast asserted", $time);
  always @(posedge iDUT.iDRV.OVR_I_shtdwn) $display("[%0t] EVENT: OVR_I_shtdwn asserted", $time);

initial begin
  // Original empty block replaced by structured test sequence above
end

always
  #10 clk = ~clk;

endmodule
