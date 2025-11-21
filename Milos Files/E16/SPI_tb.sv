
module SPI_mnrch_tb;
  // DUT interface
  logic        clk;
  logic        rst_n;
  logic        wrt;
  logic [15:0] wt_data;
  logic        MOSI;
  logic        MISO;
  logic        SCLK;
  logic        SS_n;
  logic [15:0] rd_data;
  logic        done;
  // add test variable at module scope to avoid declaration-after-statement error
  logic [15:0] r;

  // iNEMO interrupt
  logic        INT;

  // Instantiate SPI master (Device Under Test)
  SPI_mnrch dut (
    .clk(clk),
    .rst_n(rst_n),
    .wrt(wrt),
    .wt_data(wt_data),
    .MOSI(MOSI),
    .MISO(MISO),
    .SCLK(SCLK),
    .SS_n(SS_n),
    .rd_data(rd_data),
    .done(done)
  );

  // Instantiate iNEMO sensor model (SPI serf)
  SPI_iNEMO1 nemo (
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MISO(MISO),
    .MOSI(MOSI),
    .INT(INT)
  );

  // Clock generation: 100MHz
  initial clk = 0;
  always #5 clk = ~clk;

  // Simple 16-bit transfer task
  task automatic xfer(input logic [15:0] tx, output logic [15:0] rx);
    begin
      // load and start
      @(negedge clk);
      wt_data <= tx;
      wrt     <= 1'b1;
      @(posedge clk);
      wrt     <= 1'b1;
      // wait for completion
      @(posedge done);
      rx = rd_data;
      // small wait to avoid back-to-back race
      @(posedge clk);
      wrt <= 1'b0;
    end
  endtask

  // Wait for INT with timeout (safety)
  task automatic wait_for_int_high(input int max_cycles = 1_000_000);
    int i;
    begin
      for (i = 0; i < max_cycles; i++) begin
        @(posedge clk);
        if (INT) return;
      end
      $fatal(1, "Timeout waiting for INT to assert");
    end
  endtask

  // Wait for INT deassert with timeout
  task automatic wait_for_int_low(input int max_cycles = 100_000);
    int i;
    begin
      for (i = 0; i < max_cycles; i++) begin
        @(posedge clk);
        if (!INT) return;
      end
      $fatal(1, "Timeout waiting for INT to deassert");
    end
  endtask

  // Test sequence
  initial begin
    // Defaults
    rst_n   = 0;
    wrt     = 0;
    wt_data = 16'h0000;

    // Apply reset
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    // 1) WHO_AM_I read at address 0x0F => expect 0x6A in low byte
    xfer(16'h8F00, r); // 0x8Fxx: read addr 0x0F
    if (r[7:0] !== 8'h6A) begin
      $error("WHO_AM_I mismatch: got 0x%02h, expected 0x6A (full rd_data=0x%04h)", r[7:0], r);
      $fatal(1);
    end else begin
      $display("WHO_AM_I OK: rd_data=0x%04h", r);
    end

    // 2) Configure INT: write 0x02 to register 0x0D
    xfer(16'h0D02, r); // write; device will respond with 0xA5 on MISO (optional check)

    // 3) Wait for INT to assert, then read ptchL (0x22) — expect 0x63 from @00
    wait_for_int_high();
    xfer(16'hA200, r); // 0xA2xx: read addr 0x22 (ptchL)
    if (r[7:0] !== 8'h63) begin
      $error("ptchL (first INT) mismatch: got 0x%02h, expected 0x63 (full rd_data=0x%04h)", r[7:0], r);
      $fatal(1);
    end else begin
      $display("ptchL @0 OK: 0x%02h", r[7:0]);
    end
    // INT should drop when ptchL is read
    wait_for_int_low();

    // 4) Wait for a second INT and read a few registers from @01
    wait_for_int_high();

    // ptchL (0x22) from @01: cd0d -> low=0x0d
    xfer(16'hA200, r);
    if (r[7:0] !== 8'h0D) begin
      $error("ptchL (@01) mismatch: got 0x%02h, expected 0x0D", r[7:0]);
      $fatal(1);
    end

    // ptchH (0x23) from @01: cd0d -> high=0xCD
    xfer(16'hA300, r);
    if (r[7:0] !== 8'hCD) begin
      $error("ptchH (@01) mismatch: got 0x%02h, expected 0xCD", r[7:0]);
      $fatal(1);
    end

    // rollL (0x24) from @01: f176 -> low=0x76
    xfer(16'hA400, r);
    if (r[7:0] !== 8'h76) begin
      $error("rollL (@01) mismatch: got 0x%02h, expected 0x76", r[7:0]);
      $fatal(1);
    end

    // rollH (0x25) from @01: f176 -> high=0xF1
    xfer(16'hA500, r);
    if (r[7:0] !== 8'hF1) begin
      $error("rollH (@01) mismatch: got 0x%02h, expected 0xF1", r[7:0]);
      $fatal(1);
    end

    $display("All checks passed.");
    #1000;
    $finish;
  end

endmodule
