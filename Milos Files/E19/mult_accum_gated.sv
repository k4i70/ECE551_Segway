module mult_accum(clk,clr,en,A,B,accum);

input clk,clr,en;
input [15:0] A,B;
output reg [63:0] accum;

reg [31:0] prod_reg;
reg en_stg2;
logic en_clk1;
logic gated_clk;
logic gated_clk_stg2;
logic en_clk2;
logic [31:0] product;

    
assign product = A*B;


//latch for clk enable
always_latch begin 
    if(~clk)
        en_clk1 <= en;
end

assign gated_clk = clk & en_clk1;


always_latch begin
    if(~clk)
        en_clk2 <= en_stg2 | clr;
end

assign gated_clk_stg2 = clk & en_clk2;

///////////////////////////////////////////
// Generate and flop product if enabled //
/////////////////////////////////////////
always_ff @(posedge gated_clk)
      prod_reg <= product;

/////////////////////////////////////////////////////
// Pipeline the enable signal to accumulate stage //
///////////////////////////////////////////////////
always_ff @(posedge clk)
    en_stg2 <= en;

always_ff @(posedge gated_clk_stg2)
    if (clr)
      accum <= 64'h0000000000000000;
    else
      accum <= accum + prod_reg;

endmodule



