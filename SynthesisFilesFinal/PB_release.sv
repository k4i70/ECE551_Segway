`timescale 1ns/1ps
// 3 flops, 2 for meta, and then one anding with ff2 and ff3
// All flops async preset not reset

module PB_release (
    input logic clk,
    input logic PB,
    input logic rst_n,
    output logic released
);

    logic ff1, ff2, ff3;

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            ff1 <= 1'b1;
            ff2 <= 1'b1;
            ff3 <= 1'b1;
        end else begin
            ff1 <= PB;
            ff2 <= ff1;
            ff3 <= ff2;
        end
    end

    // Detect an edge
    assign released = ff2 & ~ff3;


endmodule