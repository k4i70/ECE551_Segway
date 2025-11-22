module PB_release (
    input clk,
    input rst_n,
    input PB,
    output released
);
// Internal signals for the three flip-flops
logic ff1_q, ff2_q, ff3_q;

//Asynch preset when rst_n is low for all flip-flops
// First flip-flop for metastability prevention
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        ff1_q <= 1'b1;
    else
        ff1_q <= PB;
end

// Second flip-flop for additional metastability prevention
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        ff2_q <= 1'b1;
    else
        ff2_q <= ff1_q;
end

// Third flip-flop for rising edge detection
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        ff3_q <= 1'b1;
    else
        ff3_q <= ff2_q;
end

// Rising edge detector: output high when ff2_q is high but ff3_q is low
assign released = ff2_q & ~ff3_q;

endmodule