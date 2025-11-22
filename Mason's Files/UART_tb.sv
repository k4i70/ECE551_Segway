module UART_tb();
// Self-checking UART testbench
logic clk, rst_n;
logic trmt;
logic [7:0] tx_data;
logic tx_done;
logic TX;
logic rdy;
logic [7:0] rx_data;
logic clr_rdy;

// Test tracking
int test_count = 0;
int pass_count = 0;

// Instantiate UART transmitter
UART_tx iUART_tx(
    .clk(clk),
    .rst_n(rst_n),
    .trmt(trmt),
    .tx_data(tx_data),
    .TX(TX),
    .tx_done(tx_done)
);

// Instantiate UART receiver
UART_rx iUART_rx(
    .clk(clk),
    .rst_n(rst_n),
    .RX(TX),
    .rdy(rdy),
    .rx_data(rx_data),
    .clr_rdy(clr_rdy)
);

// Clock generation
always #5 clk = ~clk;

initial begin
    // Initialize
    clk = 0;
    rst_n = 0;
    trmt = 0;
    clr_rdy = 0;
    
    // Reset
    #20 rst_n = 1;
    #10;
    
    // Test several values
    send_and_verify(8'hA5);
    send_and_verify(8'h3C);
    send_and_verify(8'hFF);   
    send_and_verify(8'h00);
    send_and_verify(8'h55);
    
    // Test tx_done functionality
    test_tx_done();
    
    // Test rdy and clr_rdy functionality
    test_rdy_clr_rdy();
    
    $display("\nTest Summary: %0d/%0d tests passed", pass_count, test_count);
    $stop;
end

task send_and_verify(input [7:0] data);
    test_count++;
    $display("Test %0d: Sending 0x%h", test_count, data);
    
    tx_data = data;
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    
    // Wait for transmission complete and reception ready
    wait(tx_done && rdy);
    
    if (rx_data == data) begin
        $display("PASS: Transmitted 0x%h matches received 0x%h", data, rx_data);
        pass_count++;
    end else begin
        $display("FAIL: Transmitted 0x%h, received 0x%h", data, rx_data);
    end
    
    // Clear ready
    clr_rdy = 1;
    @(posedge clk);
    clr_rdy = 0;
    @(posedge clk);
endtask

task test_tx_done();
    test_count++;
    $display("Test %0d: Testing tx_done functionality", test_count);
    
    tx_data = 8'h96;
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    
    // tx_done should go low during transmission
    @(negedge tx_done);
    $display("tx_done went low during transmission");
    
    // Wait for tx_done to go high
    @(posedge tx_done);
    $display("PASS: tx_done asserted when transmission complete");
    pass_count++;
    
    // Clear the receiver
    wait(rdy);
    clr_rdy = 1;
    @(posedge clk);
    clr_rdy = 0;
endtask

task test_rdy_clr_rdy();
    test_count++;
    $display("Test %0d: Testing rdy and clr_rdy functionality", test_count);
    
    tx_data = 8'h7E;
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    
    // Wait for data ready
    wait(rdy);
    $display("rdy asserted when data ready");
    
    // Test clr_rdy
    clr_rdy = 1;
    @(posedge clk);
    clr_rdy = 0;
    @(posedge clk);
    
    if (!rdy) begin
        $display("PASS: rdy cleared by clr_rdy");
        pass_count++;
    end else begin
        $display("FAIL: rdy not cleared by clr_rdy");
    end
endtask
endmodule