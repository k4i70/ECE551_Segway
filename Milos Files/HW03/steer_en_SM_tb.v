module steer_en_SM_tb();

  ////////////////////////////////////////////////
  // Declare any registers needed for stimulus //
  //////////////////////////////////////////////
  
  reg clk,rst_n;
  reg tmr_full;				// 1.3sec expired
  reg sum_gt_min;			// weight exceed minimum rider weight + hysteresis
  reg sum_lt_min;			// weight is less than minimum rider weight - hysteresis
  reg diff_gt_1_4;		    // Rider not balanced side to side
  reg diff_gt_15_16;			// Rider stepping off
  
  ////////////////////////////////////////////
  // declare wires to hook SM output up to //
  //////////////////////////////////////////
  wire clr_tmr, en_steer, rider_off;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  steer_en_SM iDUT(.clk(clk),.rst_n(rst_n),.tmr_full(tmr_full),.sum_gt_min(sum_gt_min),
                   .sum_lt_min(sum_lt_min),.diff_gt_1_4(diff_gt_1_4),
				   .diff_gt_15_16(diff_gt_15_16),.clr_tmr(clr_tmr),.en_steer(en_steer),
				   .rider_off(rider_off));
  
  initial begin
    clk=0;
	rst_n = 0;
	tmr_full = 0;
	sum_gt_min = 0;
	sum_lt_min = 1;
	diff_gt_1_4 = 0;
	diff_gt_15_16 = 0;
	
	@(posedge clk);
	@(negedge clk);
	rst_n = 1;			// deassert reset at negedge of clock
	/////////////////////////////////////////////////////////////
	// First check no outputs occur when both differences are //
	// less than, but sum_gt_min has not yet occurred.       //
	//////////////////////////////////////////////////////////
	repeat (2) begin
	  if (en_steer) begin
	    $display("ERROR: no en_steer should not be asserted yet\n");
		$stop();
	  end	  
	  @(negedge clk);
	  if (!rider_off) begin
	    $display("ERROR: rider_off should be asserted\n");
		$stop();
	  end
	end
	
	//////////////////////////////////////////////////
	// Now assert sum_gt_min and check for clr_tmr //
	////////////////////////////////////////////////
	sum_gt_min = 1;
	sum_lt_min = 0;
	diff_gt_1_4 = 1;
	@(negedge clk);
	if (!clr_tmr) begin
	  $display("ERROR: clr_tmr should be asserted after sum_gt_min becomes true\n");
	  $stop();
	end
	///////////////////////////////
	// rider_off shoud deassert //
	/////////////////////////////
	if (rider_off) begin
	  $display("ERROR: rider_off should be deasserted now that sum > MIN\n");
	  $stop();
	end	

	//////////////////////////////////////////////////////////////
	// Check no outputs occur when diff_gt_1_4 is asserted.    //
	// Also check that clr_tmr is asserted in this condition. //
	///////////////////////////////////////////////////////////
	repeat (3) begin
	  if (en_steer | rider_off) begin
	    $display("ERROR: no outputs be asserted.  Need left/right balance\n");
		$stop();
	  end
	  if (!clr_tmr) begin
	    $display("ERROR: clr_tmr should be asserted this time\n");
	    $stop();
	  end
	  @(negedge clk);
	end
	
	////////////////////////////////////////////////////////////
	// Now ensure that timer has to expire prior to en_steer //
	//////////////////////////////////////////////////////////
	diff_gt_1_4 = 0;
	repeat (2) begin
	  if (en_steer | rider_off) begin
	    $display("ERROR: no outputs should occur until timer expires\n");
		$stop();
	  end
	  @(negedge clk);
	end	

	/////////////////////////////////////////////////////////////////////////////
	// When tmr_full becomes true en_steer should become true one clock later //
	///////////////////////////////////////////////////////////////////////////	
	tmr_full = 1;
	@(negedge clk);
	if (!en_steer) begin
	  $display("ERROR: en_steer should be set now\n");
	  $stop();
	end	

	//////////////////////////////////////////////////////////////	
    // Nothing should happend until diff_gt_15_16 becomes true //
    ////////////////////////////////////////////////////////////
	diff_gt_1_4 = 1;
	@(negedge clk);
	repeat (2) begin
	  if (!en_steer | rider_off) begin
	    $display("ERROR: no outputs should change until diff_gt_15_16\n");
		$stop();
	  end
	  @(negedge clk);
	end	
	
	/////////////////////////////////////////////////////////////////
	// Now diff_gt_15_16 is asserted and it should clear en_steer //
	///////////////////////////////////////////////////////////////
	diff_gt_15_16 = 1;
	tmr_full = 0;
	@(negedge clk)
	if (en_steer) begin
	  $display("ERROR: clr_en_steer should be set now, should be in wait for balance state\n");
	  $stop();
	end	
	
	///////////////////////////////////////////////////////
	// should now be waiting for sum_lt_min (rider off) //
	/////////////////////////////////////////////////////
	@(negedge clk);
	if (iDUT.state==2'b00) begin
	  $display("ERROR: you should not be in first state again, you\n");
	  $display("       need to wait for sum_lt_min to rise first.\n");
	  $stop();
	end

	///////////////////////////////////////////////////////////////////////////
	// Now assert sum_lt_min and it should transition back to initial state //
	/////////////////////////////////////////////////////////////////////////
	sum_gt_min = 0;
    sum_lt_min = 1;
    @(negedge clk);
	if (iDUT.state==2'b00) begin
	  $display("Yahoo! test passed!\n");
	  $display("However, We did not test that when in normal mode with\n");
	  $display("steering enabled you transition to the initial state and\n");
	  $display("assert rider_off if sum_lt_min occurs.  You should test that\n");
	  $stop();
	end	else begin
	  $display("ERROR: You should be back to reset state\n");
	  $stop();
	end
	
  end
  
  always
    #10 clk = ~clk;
	
endmodule