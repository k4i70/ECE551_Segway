module Segway_tb();
`timescale 1ns/1ps
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo,piezo_n;
wire cmd_sent;
wire rst_n;					// synchronized global reset

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;				// command host is sending to DUT
reg send_cmd;				// asserted to initiate sending of command
reg signed [15:0] rider_lean;
reg [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
reg OVR_I_lft, OVR_I_rght;

///// Internal registers for testing purposes??? /////////


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
UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

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
    end
  endtask

  // Exercise steering by sweeping steerPot while steering enabled
  task automatic steering_sweep();
    int i;
    begin
      // Sweep left
      for (i = 0; i < 6; i++) begin
        steerPot = 12'h200 + (i*12'h100); // within saturation range 0x200..0xE00
        wait_cycles(30);
        $display("[%0t] Steering sweep step %0d steerPot=0x%0h lft_spd=%0d rght_spd=%0d", $time, i, steerPot, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      end
      // Sweep right
      for (i = 5; i >= 0; i--) begin
        steerPot = 12'h200 + (i*12'h100);
        wait_cycles(30);
        $display("[%0t] Steering sweep (return) step %0d steerPot=0x%0h lft_spd=%0d rght_spd=%0d", $time, i, steerPot, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      end
    end
  endtask

  // Test rider lean forward/backward
  task automatic rider_lean_test();
    int j;
    begin
      // Forward lean increments
      foreach (j[3:0]) begin end // dummy to avoid lint
      rider_lean = 16'sh0200; wait_cycles(40);
      $display("[%0t] Forward lean 0x0200 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      rider_lean = 16'sh0400; wait_cycles(40);
      $display("[%0t] Forward lean 0x0400 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      // Backward lean
      rider_lean = -16'sh0200; wait_cycles(40);
      $display("[%0t] Backward lean -0x0200 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      rider_lean = -16'sh0400; wait_cycles(40);
      $display("[%0t] Backward lean -0x0400 speeds lft=%0d rght=%0d", $time, $signed(iDUT.lft_spd), $signed(iDUT.rght_spd));
      rider_lean = 16'sh0000; wait_cycles(20);
    end
  endtask

  // Induce overspeed (too_fast) by large lean value
  task automatic induce_too_fast();
    begin
      rider_lean = 16'sh18FF; // large forward lean within allowed limit
      wait_cycles(200);
      if (iDUT.too_fast) begin
        $display("[%0t] too_fast asserted (overspeed)", $time);
      end else begin
        $display("[%0t] WARNING: too_fast not asserted yet", $time);
      end
    end
  endtask

  // Simulate repeated overcurrent events to force motor shutdown
  task automatic overcurrent_test();
    int k;
    begin
      $display("[%0t] Starting overcurrent test", $time);
      for (k = 0; k < 60 && (iDUT.iDRV.OVR_I_shtdwn===1'b0); k++) begin
        // Pulse overcurrent
        OVR_I_lft = 1'b1; OVR_I_rght = 1'b1;
        wait_cycles(2);
        OVR_I_lft = 1'b0; OVR_I_rght = 1'b0;
        wait_cycles(20);
      end
      if (iDUT.iDRV.OVR_I_shtdwn) begin
        $display("[%0t] OVR_I_shtdwn asserted after %0d pulses. PWM outputs should be forced low.", $time, k);
      end else begin
        $display("[%0t] WARNING: OVR_I_shtdwn NOT asserted after %0d pulses", $time, k);
      end
    end
  endtask

  // Optional power down sequence
  task automatic power_down();
    begin
      send_uart_cmd(8'h53); // 'S'
      ld_cell_lft = 12'd0; ld_cell_rght = 12'd0; // remove rider weight triggers rider_off
      wait_cycles(100);
      $display("[%0t] Power down sequence complete", $time);
    end
  endtask

  // Monitor important status changes
  initial begin
    $display("[%0t] Testbench start", $time);
    apply_reset();
    // Auth power up
    send_uart_cmd(8'h47); // 'G'
    // Enable steering
    enable_steering();
    steering_sweep();
    // Rider lean test
    rider_lean_test();
    // Induce overspeed
    induce_too_fast();
    // Overcurrent scenario
    overcurrent_test();
    // Power down
    power_down();
    $display("[%0t] Testbench completed", $time);
    $finish;
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
