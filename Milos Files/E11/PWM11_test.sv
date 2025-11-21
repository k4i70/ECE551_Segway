module PWM11_test(clk,RST_n,inc,LED);

	input clk;		// our 50MHz clock from DE0-Nano
	input RST_n;	// from push button, goes to our rst_synch block
	input inc;		// from push button, goes to our PB_release detector
	

	output [7:0] LED;		// LED[0] intensity controlled by PWM
								// LED[7:4] provide observability of our 4-bit counter

	////////////////////////////////////////
	// Declare any internal signals here //
	//////////////////////////////////////
	wire rst_n;			// global reset to all other blocks, produced by rst_synch
	wire btn_release;	// from PB_release unit, goes high 1 clock with button release
	wire [3:0] cnt;		// used to hook to output of up/dwn counter
	wire [10:0] duty;	// upper 4-bit from your counter, lower 7-bits all zero
	wire nxt_dwn;		// output of combinational logic that determines up vs dwn
	wire PWM1,PWM2;		// output signals from PWM11
	
	//////////////////////////////////////////////////////////////
	// Next is declaration of flop that will form the dwn that //
	// determines if 4-bit counter is counting up or down     //
	///////////////////////////////////////////////////////////
	reg dwn;

	/////////////////////////////////////
	// Instantiate reset synchronizer //
	///////////////////////////////////
	rst_synch iRST(.RST_n(RST_n), .clk(clk), .rst_n(rst_n));

	///////////////////////////////////////////////
	// Instantiate push button release detector //
	/////////////////////////////////////////////
	PB_release iPB(.clk(clk), .rst_n(rst_n), .PB(inc), .released(btn_release));
	
	//////////////////////////////////////////
	// Always block to infer dwn flip flop //
	////////////////////////////////////////
	always_ff @(posedge clk, negedge rst_n)
	  if (!rst_n)
	    dwn <= 0;
	  else
	    dwn <= nxt_dwn;
		
	assign nxt_dwn = (~dwn & &cnt) ? 1'b1 :
	                 (dwn & ~|cnt) ? 1'b0 :
						  dwn;

	///////////////////////////////////////////////
	// Instantiate of your 4-bit up/dwn counter //
    /////////////////////////////////////////////
	up_dwn_cnt4 iCNT(.clk(clk), .rst_n(rst_n), .en(btn_release), .dwn(dwn), .cnt(cnt));
	
    ////////////////////////////////////////////////////
	// Use assign to set duty to PWM11 from your counter //
	//////////////////////////////////////////////////
	assign duty = {cnt,7'b0000000};
	
	///////////////////////////////////////////
	// Instantiate PWM11 (which is the DUT) //
	/////////////////////////////////////////
	PWM11 iDUT(.clk(clk), .rst_n(rst_n), .duty(duty), .PWM1(PWM1), .PWM2(PWM2),
	           .PWM_synch(), .ovr_I_blank());
	
	/////////////////////////////////////////////////
	// MS 4-bits is cnt for observability, lowest //
	// LED varies in intensity with duty cycle   //
    // LED[2] varies with inverse of duty.      //
	/////////////////////////////////////////////	
	assign LED = {cnt,1'b0,PWM2,1'b0,PWM1};
	

endmodule

