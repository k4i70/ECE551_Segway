module rst_synch (
    input logic clk,
    input logic RST_n,
    output logic rst_n
);

    logic rst_n_ff1;

    always_ff @(negedge clk or negedge RST_n) begin
        if (!RST_n) begin
            rst_n_ff1 <= 1'b0;
        end else begin
            rst_n_ff1 <= 1'b1;
        end
    end

    always_ff @(negedge clk or negedge RST_n) begin
        if (!RST_n) begin
            rst_n <= 1'b0;
        end else begin
            rst_n <= rst_n_ff1;
        end
    end

endmodule