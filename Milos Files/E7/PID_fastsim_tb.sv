module PID_dbg_tb();

////////////////////////////
// Stimulus to DUT below //
//////////////////////////
reg clk, rst_n;
reg vld_sel,vld_tggle;
reg pwr_up;
reg rider_off;
reg [15:0] ptch,ptch_rt;

///////////////////////////////////////
// Declare wires for outputs of DUT //
/////////////////////////////////////
wire signed [11:0] PID_cntrl;
wire [7:0] ss_tmr;
wire vld;	// actually stimulus to DUT formed by vld_sel & vld_tggle

  localparam P_COEFF = 5'h09;
   
initial begin
  //// initialize all inputs to DUT ////
  clk = 0;
  rst_n = 0;
  ptch = 16'h0000;
  ptch_rt = 16'h0000;
  vld_sel = 1;		// forces vld high all the time
  rider_off = 1;
  pwr_up = 0;		// ss_tmr should stay at zero
  
  /// hold reset and deassert at negedge ///
  repeat(2) @(negedge clk);
  rst_n = 1;
  
  /// Initial test...does zero in give zero out? ///
  @(negedge clk);
  if ((PID_cntrl===12'h000) || (PID_cntrl===12'hFFF))
    $display("GOOD1: zero in should give zero out");
  else begin
    $display("ERROR: PID_cntrl should be near zero");
	$stop();
  end

  /// non-zero pitch...checking P_term ///
  ptch = 16'h0002;
  @(negedge clk);
  if ((PID_cntrl>=(P_COEFF*2)-1) || (PID_cntrl<=(P_COEFF*2)))
    $display("GOOD2: PID_cntrl should be P_term only");
  else begin
    $display("ERROR: Output should be determined by P_term");	
	$stop();
  end
  
  /// check that ss_tmr stays at zero since pwr_up=0 ///
  repeat(2150) @(posedge clk);
  if (ss_tmr===8'h00)
    $display("GOOD3: ss_tmr should be 0x00 since pwr_up=0");
  else begin
    $display("ERROR: ss_tmr should be zero");	
	$stop();
  end 
  
  pwr_up = 1;	// enable ss_tmr to start
  /// Basic test of D_term next ///
  ptch_rt = 16'h0100;			// set ptch_rt to check D_term
  @(negedge clk);		// give time for D queue to clear
  if ((PID_cntrl>(P_COEFF*2-7)) && (PID_cntrl<(P_COEFF*2-2)))
    $display("GOOD4: D_term in proper range");
  else begin
    $display("ERROR: D_term should be -4 or -5");	
	$stop();
  end 
  
  /// Let integrator wind up next with vld high all the time ///
  ptch = 16'h007F;		// increase magnitude of error
  rider_off = 0;		// let integrator integrate  
  repeat (3)@(negedge clk);
  if ((PID_cntrl>=12'h52F) && (PID_cntrl<=12'h533))
    $display("GOOD5: I_term should be around 0x00be");
  else begin
    $display("ERROR: I_term should be 0x00be at this time with");
	$display("       D_term in -5 to -6 range");
	$stop();
  end

  /// Now increase error to check saturation of PID_cntrl to 12-bits ///
  ptch = 16'h00FF;		// increase magnitude of error 
  repeat (3)@(negedge clk);
  if (PID_cntrl===12'h7FF)
    $display("GOOD6: I_term should be 0x023d");
  else begin
    $display("ERROR: I_term should be 0x023d and P_term should be 0x08f7");
	$display("       Positive saturation of PID_cntrl should occur");
	$stop();
  end
  

  /// Now lower error, but let integrate + for long time ///
  ptch = 16'h003F;				// lower magnitude of error 
  repeat (600)@(negedge clk);	// long enough to saturate positive
  if (PID_cntrl===12'h7FF)
    $display("GOOD7: I_term should be saturated at 0x3fff");
  else begin
    $display("ERROR: I_term should be 0x3fff and P_term should be 0x0237");
	$display("       Positive saturation of PID_cntrl should occur at 0x7ff");
	$stop();
  end
  

  /// Now take P_term to negative and check non saturated.
  ptch = 16'hFE00;
  repeat(52) @(negedge clk);	// let it integrate a while
  if (PID_cntrl<12'h7FF)
    $display("GOOD8: I_term should be 0x1811");
  else begin
    $display("ERROR: I_term should be 0x1811 at this time with P_term 0x6E00");
	$display("       D_term in -5 to -6 range");
	$stop();
  end
        

  /// Now assert rider_off which should clear I_term ///
  rider_off = 1;
  ptch = 16'h0010;
  @(negedge clk);
  rider_off = 0;
  if ((PID_cntrl>=12'h089) && (PID_cntrl<=12'h08f))
    $display("GOOD9: I_term should be 0, P_term should be 0x0090");
  else begin
    $display("ERROR: I_term should be 0 at this time with P_term 0x0090");
	$stop();
  end 
  

  /// Now take ptch negative and vld at 50% instead of 100% ///
  vld_sel = 0;
  ptch = 16'hFF80;
  ptch_rt = 16'h0000;
  repeat (6) @(negedge clk);
  if ((PID_cntrl>=12'hABC) && (PID_cntrl<=12'hAC4))
    $display("GOOD10: I_term should be 0x7f40, P_term should be 0x7b80");
  else begin
    $display("ERROR: I_term should be 0x7f40 at this time with P_term 0x7b80");
	$stop();
  end  


  /// Now take ptch negative more negative so we see neg saturation of PID_cntrl ///
  ptch = 16'hFF00;
  @(negedge clk);
  if (PID_cntrl===12'h800)
    $display("GOOD11: PID_cntrl should be saturated negative");
  else begin
    $display("ERROR: I_term should be 0x7f40 at this time with P_term 0x7700");
	$stop();
  end   
            

  /// Now run till integrator saturates negative ///
  ptch = 16'hFF80;
  repeat(600) @(negedge clk);
  /// Now integrator should be sat neg ///
  /// change ptch to positive and run till PID_cntrl not saturated ///
  ptch = 16'h07ff;
  repeat(105) @(negedge clk);
  if (PID_cntrl>$signed(12'h800))
    $display("GOOD12: I_term should be 0x67A6, P_term should be 0x11F7");
  else begin
    $display("ERROR: I_term should be 0x67A6 at this time with P_term 0x11F7");
	$stop();
  end

  
  /// Finally check that ss_tmr increments ///
    /// check that ss_tmr stays at zero since pwr_up=0 ///
  repeat(750) @(posedge clk);
  if (ss_tmr===8'h01)
    $display("GOOD13: ss_tmr should be 0x01");
  else begin
    $display("ERROR: ss_tmr should be 0x01");	
	$stop();
  end   
 
  $display("YAHOO!! all tests passed!\n");
  $stop();
	 
end

/////////////////////////////////
// Make a toggling flop for producing
// a vld signal that is high every
// other time
///////////////////////////////
always @(posedge clk, negedge rst_n)
  if (!rst_n)
    vld_tggle <= 1'b0;
  else
    vld_tggle <= ~vld_tggle;
	
assign vld = (vld_sel) ? 1'b1 : vld_tggle;
	
always
  #5 clk = ~clk;

					
//////////////////////
// Instantiate DUT //
////////////////////
PID iDUT(.clk(clk),.rst_n(rst_n),.vld(vld),.ptch(ptch),.ptch_rt(ptch_rt),
		 .pwr_up(pwr_up),.rider_off(rider_off),.PID_cntrl(PID_cntrl),
		 .ss_tmr(ss_tmr));
		 
endmodule