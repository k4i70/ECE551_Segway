`timescale 1ns/1ps
`default_nettype none

module A2D_Intf_tb;
  // Clock/Reset
  logic clk;
  logic rst_n;

  // Control
  logic nxt;

  // SPI
  wire  MISO;
  wire  MOSI;
  wire  SCLK;
  wire  SS_n;

  // DUT outputs
  wire [11:0] lft_ld;
  wire [11:0] rght_ld;
  wire [11:0] steer_pot;
  wire [11:0] batt;

  // Clock generation: 50 MHz (20 ns period)
  initial clk = 1'b0;
  always #10 clk = ~clk;

  // Reset sequence
  initial begin
    rst_n = 1'b0;
    nxt   = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  A2D_Intf dut (
    .clk(clk),
    .rst_n(rst_n),
    .nxt(nxt),
    .lft_ld(lft_ld),
    .rght_ld(rght_ld),
    .steer_pot(steer_pot),
    .batt(batt),
    .MISO(MISO),
    .MOSI(MOSI),
    .SCLK(SCLK),
    .SS_n(SS_n)
  );

  //////////////////////////////////
  // Instantiate ADC128S (model) //
  ////////////////////////////////
  ADC128S iADC (
    .clk(clk),
    .rst_n(rst_n),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MISO(MISO),
    .MOSI(MOSI)
  );

  // Utility: wait for N rising edges of SS_n (i.e., N completed SPI transactions)
  // Note: timing controls are illegal in functions, so implement as a task
  task automatic wait_n_ssn_rises(input int n, input int max_cycles, output bit result);
    int rises = 0;
    int cycles = 0;
    bit last_ssn;
    last_ssn = SS_n;
    // Wait until first activity starts (SS_n low)
    while (SS_n === 1'b1 && cycles < max_cycles) begin
      @(posedge clk); cycles++;
    end
    // Count rising edges
    while (rises < n && cycles < max_cycles) begin
      @(posedge clk); cycles++;
      if (last_ssn == 1'b0 && SS_n == 1'b1) rises++;
      last_ssn = SS_n;
    end
    result = (rises == n);
  endtask

  // Pulse nxt for one clock
  task automatic kick_next();
    nxt <= 1'b1;
    @(posedge clk);
    nxt <= 1'b0;
  endtask

  // Compute expected 12-bit value given base (multiple of 0x10) and channel (ORs in low 3 bits)
  function automatic logic [11:0] expect_val(input logic [11:0] base, input logic [2:0] ch);
    return (base | {9'b0, ch});
  endfunction

  // Check one conversion for a channel
  task automatic do_and_check(
      input logic [2:0] ch,
      input logic [11:0] expected,
      output bit pass);
    // Local declarations must precede procedural statements
    logic [11:0] got;
    bit ok;

    pass = 1'b0;

    // Start conversion sequence on DUT
    kick_next();

  // Each conversion in this interface performs two SPI transactions
    wait_n_ssn_rises(2, 5000, ok);
    if (!ok) begin
      $error("Timeout waiting for two SPI transactions for channel %0d", ch);
      return;
    end

    // Allow one cycle for DUT to store result
    @(posedge clk);
    case (ch)
      3'd0: got = lft_ld;
      3'd4: got = rght_ld;
      3'd5: got = steer_pot;
      3'd6: got = batt;
      default: begin
        $error("Unexpected channel requested in testbench: %0d", ch);
        return;
        end
    endcase

    if (got !== expected) begin
      $error("Mismatch ch=%0d got=0x%03h exp=0x%03h", ch, got, expected);
    end else begin
      $display("PASS ch=%0d val=0x%03h", ch, got);
      pass = 1'b1;
    end
  endtask

  // Main stimulus
  initial begin : tb_main
    // Declarations must appear before any procedural statements in a block
    bit pass;
    static int pass_cnt = 0;
    static int test_cnt = 0;
    static logic [11:0] base = 12'hC00; // Expected value progression from ADC model
    logic [2:0] seq [0:3]; // Channel round-robin ordering

    // Wait for reset release
    @(posedge rst_n);
    repeat (2) @(posedge clk);

    // Initialize sequence (statements allowed after declarations)
    seq[0] = 3'd0; seq[1] = 3'd4; seq[2] = 3'd5; seq[3] = 3'd6;

    // Run several conversions and self-check
    for (int i = 0; i < 12; i++) begin
      // Per-iteration temporaries should be automatic when initialized from
      // non-static references (avoids static-initializer errors).
      automatic logic [2:0] ch = seq[i % 4];
      automatic logic [11:0] exp = expect_val(base, ch);
      test_cnt++;
      do_and_check(ch, exp, pass);
      if (pass) pass_cnt++;
      // After each full conversion, ADC model decrements by 0x10
      base = base - 12'h010;
      // Small idle gap
      repeat (3) @(posedge clk);
    end

    $display("\nSummary: %0d/%0d passed", pass_cnt, test_cnt);
    if (pass_cnt != test_cnt) begin
      $error("Self-check FAILED");
    end else begin
      $display("Self-check PASSED");
    end

    $finish;
  end

endmodule

`default_nettype wire
