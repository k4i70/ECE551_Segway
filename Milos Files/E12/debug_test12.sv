module debug_test12();

reg clk, rst_n;
reg vld_sel, vld_tggle;
reg pwr_up;
reg rider_off;
reg [15:0] ptch, ptch_rt;

wire signed [11:0] PID_cntrl;
wire [7:0] ss_tmr;
wire vld;

// Internal signals for debugging
wire signed [9:0] ptch_saturated;
wire signed [14:0] P_term;
wire signed [17:0] integrator;
wire signed [14:0] I_term;
wire signed [12:0] D_term;
wire signed [15:0] PID_sum;
wire ov;

assign ptch_saturated = iDUT.ptch_saturated;
assign P_term = iDUT.P_term;
assign integrator = iDUT.integrator;
assign I_term = iDUT.I_term;
assign D_term = iDUT.D_term;
assign PID_sum = iDUT.PID_sum;
assign ov = iDUT.ov;

initial begin
  clk = 0;
  rst_n = 0;
  ptch = 16'h0000;
  ptch_rt = 16'h0000;
  vld_sel = 0; // 50% duty cycle for vld
  rider_off = 1;
  pwr_up = 0;
  
  repeat(2) @(negedge clk);
  rst_n = 1;
  
  // Set up previous test conditions to get to test 12 state
  pwr_up = 1;
  rider_off = 0;
  
  // Run negative integration for a while to saturate integrator negative
  ptch = 16'hFF80; // -128 decimal
  ptch_rt = 16'h0000;
  
  $display("Starting negative saturation phase...");
  repeat(10) begin
    @(negedge clk);
    $display("Time: %0t | ptch: %h | integrator: %h | I_term: %h | P_term: %h | PID_cntrl: %h", 
             $time, ptch, integrator, I_term, P_term, PID_cntrl);
  end
  
  // Run for long time to saturate
  repeat(2400) @(negedge clk);
  
  $display("\nAfter 2400 cycles of negative integration:");
  $display("Time: %0t | ptch: %h | integrator: %h | I_term: %h | P_term: %h | PID_cntrl: %h", 
           $time, ptch, integrator, I_term, P_term, PID_cntrl);
  
  // Now change to positive ptch
  ptch = 16'h0040; // 64 decimal
  @(negedge clk);
  
  $display("\nAfter changing to positive ptch:");
  $display("Time: %0t | ptch: %h | integrator: %h | I_term: %h | P_term: %h | D_term: %h | PID_sum: %h | PID_cntrl: %h", 
           $time, ptch, integrator, I_term, P_term, D_term, PID_sum, PID_cntrl);
  
  $display("\nExpected: I_term=7801, P_term=0240, PID_cntrl=A40-A42");
  
  $finish;
end

always @(posedge clk, negedge rst_n)
  if (!rst_n)
    vld_tggle <= 1'b0;
  else
    vld_tggle <= ~vld_tggle;
    
assign vld = (vld_sel) ? 1'b1 : vld_tggle;

always
  #5 clk = ~clk;

PID iDUT(.clk(clk),.rst_n(rst_n),.vld(vld),.ptch(ptch),.ptch_rt(ptch_rt),
         .pwr_up(pwr_up),.rider_off(rider_off),.PID_cntrl(PID_cntrl),
         .ss_tmr(ss_tmr));
         
endmodule
