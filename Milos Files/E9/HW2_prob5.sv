// DFF with active high synchronous reset
module DFF_sr(
    input logic clk,
    input logic rst, // synchronous reset
    input logic d,
    output logic q
);
    always_ff @(posedge clk) begin
        if (rst) begin
            q <= 1'b0;
        end else begin
            q <= d;
        end
    end
endmodule

//DFF with asynchronous active low reset and active high enable
module DFF_ar_en(
    input logic clk,
    input logic rst_n, // asynchronous active low reset
    input logic en,    // active high enable
    input logic d,
    output logic q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 1'b0;
        end else if (en) begin
            q <= d;
        end
    end
endmodule

//SR FF with active high synchronous set and reset and active low async reset
module SRFF_sr_ar(
    input logic clk,
    input logic rst_n, // asynchronous active low reset
    input logic s,
    input logic r,
    output logic q,
    
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 1'b0;
        end 
        else if (r) begin
            q <= 1'b0;
        end 
        else if (s) begin
            q <= 1'b1;
        end
    end
endmodule


/* Answers to the questions: The latch code is not correct because the sensitivity list is incomplete. It should include d, since a change in d might also change q if clock is high. The correct sensitivity list should be (clk or d). 
 The always_ff will not ensure that the code will infer a flop, but it is good practice when coding flip flops. The synthesis tool will infer a flop based on the behavior described in the always block, not just the use of always_ff.
  However, using always_ff helps to clarify the intent of the code and the compiler will also run additional checks to ensure that the logic models flip flop behavior */