module up_dwn_cnt4(
    input en,
    input dwn,
    input clk,
    input rst_n,
    output logic [3:0] cnt
);

logic [3:0] d1;

always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        cnt <= 4'b0;
    end
    else begin
        cnt <= d1;
        d1 <= en ? (dwn ? cnt - 1 : cnt + 1) : cnt;
    end
end

endmodule