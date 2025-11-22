module rst_synch(
    input RST_n,    // raw input from push button
    input clk,      // clock, negative edge triggered
    output rst_n    // synchronized output reset
);

    // Internal signals for the two flip-flops
    reg ff1, ff2;
    
    // Two flip-flops triggered on negative edge of clock
    // Asynchronously reset when RST_n is low

    // First flip-flop
    always_ff @(negedge clk or negedge RST_n) begin
        if (~RST_n)
            ff1 <= 1'b0;
        else
            ff1 <= 1'b1;
    end

    // Second flip-flop
    always_ff @(negedge clk or negedge RST_n) begin
        if (~RST_n)
            ff2 <= 1'b0;
        else
            ff2 <= ff1;
    end
    // Output is the result of the second flip-flop
    assign rst_n = ff2;

endmodule