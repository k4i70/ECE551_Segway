module rst_synch(RST_n, clk, rst_n);

	input RST_n;
	input clk;
	output rst_n;
	
	reg ff1, ff2;
	
	
	// These flops are asynchronously reset when button is pushed
	always_ff @(negedge clk, negedge RST_n) begin
		if (!RST_n) begin
			ff1 <= 1'b0;
			ff2 <= 1'b0;
		end else begin
			ff1 <= 1'b1;
			ff2 <= ff1;
		end
	end
	
	assign rst_n = ff2;

endmodule
