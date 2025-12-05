`timescale 1ns/1ps
`include "tests_package.sv"
module Segway_Static_tests();

// Pull shared test utilities into scope
import tests_package::*;
			
//// Interconnects to DUT/support defined as type wire /////
wire SS_n, SCLK, MOSI, MISO, INT; // to inertial sensor
wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO; // to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo, piezo_n;
logic cmd_sent;
logic rst_n; // synchronized global reset

////// Stimulus registers ///////
logic clk, RST_n;
logic [7:0] cmd; // command host is sending to DUT
logic send_cmd; // asserted to initiate sending of command
logic signed [15:0] rider_lean;
logic [11:0] ld_cell_lft, ld_cell_rght, steerPot, batt; // A2D values
logic OVR_I_lft, OVR_I_rght;

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
UART_TX iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

// Monitored DUT internals for reusable task package
logic pwr_up_mon, en_steer_mon, rider_off_mon, batt_low_mon;
logic piezo_mon;
logic [7:0] ss_tmr_mon;
logic signed [11:0] lft_spd_mon, rght_spd_mon;

always_comb begin
  pwr_up_mon   = iDUT.pwr_up;
  en_steer_mon = iDUT.en_steer;
  rider_off_mon = iDUT.rider_off;
  batt_low_mon = iDUT.batt_low;
  piezo_mon = piezo;
  ss_tmr_mon = iDUT.iBAL.pid_inst.ss_tmr;
  lft_spd_mon = iDUT.lft_spd;
  rght_spd_mon = iDUT.rght_spd;
end

// ---------------------------------------------------------------------------
// Helper constants and tasks used by the directed test sequences below.
// ---------------------------------------------------------------------------
initial begin
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

  wait_cycles(clk, 5);
  RST_n = 1'b1;
  wait_cycles(clk, 5000);

  startup_test(clk, pwr_up_mon, en_steer_mon, rider_off_mon, piezo_mon);
  step_on_test(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
               cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon);
  rider_off_test(clk, ld_cell_lft, ld_cell_rght, pwr_up_mon, en_steer_mon, rider_off_mon);
  piezo_test(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
             cmd_sent, send_cmd, cmd, batt,
             pwr_up_mon, en_steer_mon, rider_off_mon, batt_low_mon, piezo_mon);
  disconnection_test(clk, ld_cell_lft, ld_cell_rght,
                     cmd_sent, send_cmd, cmd,
                     pwr_up_mon, en_steer_mon, rider_off_mon);
  
  // New Trevor tests
  soft_start_test(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
                  cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon,
                  ss_tmr_mon, lft_spd_mon, rght_spd_mon);
  weight_hysteresis_test(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
                         cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon);
  steer_pot_saturation_test(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
                            cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon,
                            lft_spd_mon, rght_spd_mon);

  $display("[%0t] All Segway static tests completed successfully", $time);
  $stop();
end

always
  #10 clk = ~clk;

endmodule	
