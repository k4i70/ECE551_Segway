module PB_release(
    input PB,
    input clk,
    input rst_n,
    output released
);

logic q1, q2, q3;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        q1 = 1'b1;
        q2 = 1'b1;
        q3 = 1'b1;
    end
    else begin
        q1 <= PB;
        q2 <= q1;
        q3 <= q2;
    end
end

assign released = (q2 & (~q3));
endmodule