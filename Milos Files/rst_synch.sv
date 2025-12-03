module rst_synch(
    input clk,
    input RST_n,
    output rst_n
);

logic q1 = 1'b0;

always_ff @(negedge clk) begin
    if(!RST_n) begin
    q1 <= 1'b0;
    rst_n <= q1;
    end
    else  begin
    q1 <= 1'b1;
    rst_n <= q1;
    end
end
endmodule