module UART_tx_tb();

    // Testbench signals
    reg clk, rst_n, trmt;
    reg [7:0] tx_data;
    wire TX, tx_done;
    
    // Instantiate UART transmitter
    UART_tx iDUT (
        .clk(clk),
        .rst_n(rst_n),
        .trmt(trmt),
        .tx_data(tx_data),
        .TX(TX),
        .tx_done(tx_done)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        trmt = 0;
        tx_data = 8'h00;
        
        // Reset sequence
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Test case 1: Transmit 0x55
        $display("Starting test case 1: Transmit 0x55");
        tx_data = 8'h55;
        trmt = 1;
        @(posedge clk);
        trmt = 0;
        #10;
        
        // Wait for transmission to complete
        wait(tx_done);
        @(posedge clk);
        
        // Test case 2: Transmit 0xAA
        $display("Starting test case 2: Transmit 0xAA");
        tx_data = 8'hAA;
        trmt = 1;
        @(posedge clk);
        trmt = 0;
        #10;
        
        wait(tx_done);
        @(posedge clk);
        
        // Test case 3: Transmit 0x00
        $display("Starting test case 3: Transmit 0x00");
        tx_data = 8'h00;
        trmt = 1;
        @(posedge clk);
        trmt = 0;
        #10;
        
        wait(tx_done);
        @(posedge clk);
        
        $display("All tests completed");
        $stop;
    end
    
endmodule