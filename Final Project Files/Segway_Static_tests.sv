module Segway_tb();
			
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

// ---------------------------------------------------------------------------
// Helper constants and tasks used by the directed test sequences below.
// ---------------------------------------------------------------------------
localparam int AUTH_TIMEOUT   = 200_000;
localparam int STEER_TIMEOUT  = 300_000;
localparam int PIEZO_TIMEOUT  = 4_000_000;

task automatic wait_cycles(input int cycles);
  repeat (cycles) @(posedge clk);
endtask

task automatic wait_rider_off(input bit expected, input string tag);
  int cycles;
  for (cycles = 0; cycles < STEER_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (iDUT.iSTR.rider_off === expected)
      return;
  end
  $fatal(1,"[%s] Timeout waiting for rider_off=%0b", tag, expected);
endtask

task automatic wait_en_steer(input bit expected, input string tag);
  int cycles;
  for (cycles = 0; cycles < STEER_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (iDUT.iSTR.en_steer === expected)
      return;
  end
  $fatal(1,"[%s] Timeout waiting for en_steer=%0b", tag, expected);
endtask

task automatic wait_pwr_up(input bit expected, input string tag);
  int cycles;
  for (cycles = 0; cycles < AUTH_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (iDUT.iAuth.pwr_up === expected)
      return;
  end
  $fatal(1,"[%s] Timeout waiting for pwr_up=%0b", tag, expected);
endtask

task automatic wait_batt_low(input bit expected, input string tag);
  int cycles;
  for (cycles = 0; cycles < PIEZO_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (iDUT.batt_low === expected)
      return;
  end
  $fatal(1,"[%s] Timeout waiting for batt_low=%0b", tag, expected);
endtask

task automatic expect_piezo_toggle(input string tag);
  bit start_val;
  int cycles;
  start_val = piezo;
  for (cycles = 0; cycles < PIEZO_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (piezo !== start_val)
      return;
  end
  $fatal(1,"[%s] Piezo output did not toggle", tag);
endtask

task automatic send_uart_byte(input [7:0] data, input string tag);
  wait (cmd_sent === 1'b1);
  @(posedge clk);
  cmd <= data;
  send_cmd <= 1'b1;
  @(posedge clk);
  send_cmd <= 1'b0;
  wait (cmd_sent === 1'b0);
  wait (cmd_sent === 1'b1);
  $display("[%0t] %s: UART byte 0x%02h sent", $time, tag, data);
endtask

task automatic power_up_with_rider(input string tag);
  ld_cell_lft <= 12'h480;
  ld_cell_rght <= 12'h480;
  steerPot <= 12'h800;
  rider_lean <= 16'sh0000;
  wait_rider_off(1'b0, tag);
  send_uart_byte(8'h47, {tag, "_G"});
  wait_pwr_up(1'b1, tag);
  wait_en_steer(1'b1, tag);
  $display("[%0t] %s: rider engaged and system powered", $time, tag);
endtask

task automatic startup_test();
  $display("[%0t] ---- Startup test ----", $time);
  wait_cycles(2000);
  if (iDUT.iAuth.pwr_up !== 1'b0)
    $fatal(1,"[Startup] pwr_up should be low after reset");
  if (iDUT.iSTR.en_steer !== 1'b0)
    $fatal(1,"[Startup] en_steer should be low after reset");
  if (iDUT.iSTR.rider_off !== 1'b1)
    $fatal(1,"[Startup] rider_off should be high after reset");
  if (piezo !== 1'b0)
    $fatal(1,"[Startup] piezo should be idle after reset");
  $display("[%0t] Startup test passed", $time);
endtask

task automatic step_on_test();
  $display("[%0t] ---- Step on test ----", $time);
  power_up_with_rider("StepOn");
  $display("[%0t] Step on test passed", $time);
endtask

task automatic rider_off_test();
  $display("[%0t] ---- Rider off test ----", $time);
  ld_cell_lft <= 12'h020;
  ld_cell_rght <= 12'h020;
  wait_rider_off(1'b1, "RiderOff");
  wait_en_steer(1'b0, "RiderOff");
  wait_pwr_up(1'b0, "RiderOff");
  $display("[%0t] Rider off test passed", $time);
endtask

task automatic piezo_test();
  $display("[%0t] ---- Piezo test ----", $time);
  power_up_with_rider("Piezo");
  batt <= 12'h700;
  wait_batt_low(1'b1, "Piezo_low_batt");
  expect_piezo_toggle("Piezo_low_batt");
  batt <= 12'hC00;
  wait_batt_low(1'b0, "Piezo_recover");
  $display("[%0t] Piezo test passed", $time);
endtask

task automatic disconnection_test();
  $display("[%0t] ---- Disconnection test ----", $time);
  wait_rider_off(1'b0, "Disconnect_pre");
  wait_pwr_up(1'b1, "Disconnect_pre");
  send_uart_byte(8'h53, "Disconnect_S");
  repeat (50_000) begin
    @(posedge clk);
    if (iDUT.iAuth.pwr_up !== 1'b1)
      $fatal(1,"[Disconnection] pwr_up dropped before rider stepped off");
  end
  ld_cell_lft <= 12'h010;
  ld_cell_rght <= 12'h010;
  wait_rider_off(1'b1, "Disconnect_post");
  wait_pwr_up(1'b0, "Disconnect_post");
  wait_en_steer(1'b0, "Disconnect_post");
  $display("[%0t] Disconnection test passed", $time);
endtask

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

  wait_cycles(5);
  RST_n = 1'b1;
  wait_cycles(5000);

  startup_test();
  step_on_test();
  rider_off_test();
  piezo_test();
  disconnection_test();

  $display("[%0t] All Segway static tests completed successfully", $time);
  $stop();
end

always
  #10 clk = ~clk;

endmodule	
