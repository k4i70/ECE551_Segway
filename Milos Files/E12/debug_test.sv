module debug_test();

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
  vld_sel = 1;
  rider_off = 1;
  pwr_up = 0;
  
  repeat(2) @(negedge clk);
  rst_n = 1;
  
  // Set up for test 5 conditions
  ptch = 16'h0002;
  @(negedge clk);
  
  ptch_rt = 16'h0100;
  @(negedge clk);
  
  pwr_up = 1;
  ptch = 16'h007F;
  rider_off = 0;
  
  // Debug for 5 cycles
  repeat(5) begin
    @(negedge clk);
    $display("Time: %0t | ptch: %h | integrator: %h | I_term: %h | P_term: %h | D_term: %h | PID_sum: %h | ov: %b | PID_cntrl: %h", 
             $time, ptch, integrator, I_term, P_term, D_term, PID_sum, ov, PID_cntrl);
  end
  
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
