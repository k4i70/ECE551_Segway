// UART testbench that links both UART_tx and UART_rx modules and tests end-to-end transmission extensively
module UART_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50 MHz clock
    parameter BAUD_RATE = 9600;
    parameter BIT_PERIOD = 1000000000 / BAUD_RATE; // in ns

    // Signals
    logic clk;
    logic rst_n;
    logic RX;
    logic [7:0] rx_data;
    logic rdy;
    logic clr_rdy;

    //Instantiate the DUT
    logic trmt;
    logic [7:0] tx_data;
    logic TX;
    logic tx_done;
    UART_TX uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .trmt(trmt),
        .tx_data(tx_data),
        .TX(TX),
        .tx_done(tx_done)
    );

    // Instantiate the DUT
    UART_rx dut (
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .rx_data(rx_data),
        .rdy(rdy),
        .clr_rdy(clr_rdy)
    );

        // Connect TX to RX
    assign RX = TX;
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test sequence
    logic [7:0] i; // Declare loop variable at module scope
    initial begin
        // Initialize signals
        rst_n = 0;
        trmt = 0;
        tx_data = 8'h00;

        // Release reset
        #(CLK_PERIOD * 5);
        rst_n = 1;

        // Wait for a few clock cycles
        #(CLK_PERIOD * 10);
        // Test case 1: Transmit and receive a byte (0xA5)

        trmt = 1;
        tx_data = 8'hA5;
        #(CLK_PERIOD);
        trmt = 0;
        wait(rdy == 1);
        wait(tx_done == 1);
        
        $display("Test 1 - Sent: %h, Received: %h", tx_data, rx_data);
        if (rx_data !== 8'hA5) $error("Test 1 Failed");
        clr_rdy = 1;
        #(CLK_PERIOD);
        #(CLK_PERIOD * 10);
        // Test case 2: Transmit and receive another byte (0x3C)
        trmt = 1;
        tx_data = 8'h3C;
        #(CLK_PERIOD);
        trmt = 0;
        wait(rdy == 1);
        wait(tx_done == 1);
        
        $display("Test 2 - Sent: %h, Received: %h", tx_data, rx_data);
        if (rx_data !== 8'h3C) $error("Test 2 Failed");
        clr_rdy = 1;
        #(CLK_PERIOD);
        #(CLK_PERIOD * 10);
        // Test case 3: Transmit 0xFF 
        trmt = 1;
        tx_data = 8'hFF;
        #(CLK_PERIOD);
        trmt = 0;
        wait(rdy == 1);
        wait(tx_done == 1);

        $display("Test 3 - Sent: %h, Received: %h", tx_data, rx_data);
        if (rx_data !== 8'hFF) $error("Test 3 Failed");
        clr_rdy = 1;
        #(CLK_PERIOD);
        #(CLK_PERIOD * 10);

        // Test case 4: Transmit 0x00
        trmt = 1;
        tx_data = 8'h00;
        #(CLK_PERIOD);
        trmt = 0;
        wait(rdy == 1);
        wait(tx_done == 1);

        $display("Test 4 - Sent: %h, Received: %h", tx_data, rx_data);
        if (rx_data !== 8'h00) $error("Test 4 Failed");
        clr_rdy = 1;
        #(CLK_PERIOD);
        #(CLK_PERIOD * 10);
        // Test case 5: Transmit a sequence of bytes
        for (i = 0; i < 16; i = i + 1) begin
            trmt = 1;
            tx_data = i * 16'h11; // Transmit 0x00, 0x11, 0x22, ..., 0xFF
            #(CLK_PERIOD);
            trmt = 0;
            wait(rdy == 1);
            wait(tx_done == 1);

            $display("Test 5 - Sent: %h, Received: %h", tx_data, rx_data);
            if (rx_data !== (i * 16'h11)) $error("Test 5 Failed at iteration %0d", i);
            clr_rdy = 1;
            #(CLK_PERIOD);
            #(CLK_PERIOD * 10);
        end
        $finish;
    end
endmodule