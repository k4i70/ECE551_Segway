module steer_en_tb;
  logic clk;
  logic rst_n;
  logic [11:0] lft_ld;
  logic [11:0] rght_ld;
  logic en_steer;
  logic rider_off;

  steer_en #(.fast_sim(1'b1)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .lft_ld(lft_ld),
    .rght_ld(rght_ld),
    .en_steer(en_steer),
    .rider_off(rider_off)
  );

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    lft_ld = 12'h000;
    rght_ld = 12'h000;
    #25;
    rst_n = 1'b1;
    repeat (5) @(posedge clk);
    lft_ld = 12'h480;
    rght_ld = 12'h480;
    repeat (100000) begin
      @(posedge clk);
      if (rider_off == 1'b0) begin
        $display("[%0t] rider_off deasserted", $time);
        $finish;
      end
    end
    $display("Timeout waiting for rider_off to deassert, rider_off=%b", rider_off);
    $finish;
  end

  always #10 clk = ~clk;
endmodule
