/*
UART Receiver Testbench
*/
module UART_rx_tb;

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

    // Instantiate the DUT
    UART_rx dut (
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .rx_data(rx_data),
        .rdy(rdy)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        RX = 1; // Idle state is high

        // Release reset
        #(CLK_PERIOD * 5);
        rst_n = 1;

        // Wait for a few clock cycles
        #(CLK_PERIOD * 10);

        // Test case 1: Receive a byte (0xA5)
        fork
            begin
                // Start bit
                RX = 0;
                #(BIT_PERIOD);
                // Data bits (0xA5 = 10100101)
                RX = 1; #(BIT_PERIOD); // Bit 0
                RX = 0; #(BIT_PERIOD); // Bit 1
                RX = 1; #(BIT_PERIOD); // Bit 2
                RX = 0; #(BIT_PERIOD); // Bit 3
                RX = 0; #(BIT_PERIOD); // Bit 4
                RX = 1; #(BIT_PERIOD); // Bit 5
                RX = 0; #(BIT_PERIOD); // Bit 6
                RX = 1; #(BIT_PERIOD); // Bit 7
                // Stop bit
                RX = 1;
                #(BIT_PERIOD);
            end

            begin
                wait(rdy == 1);
                $display("Received byte: %h", rx_data);
            end
        join

        // Wait a bit before next test case
        #(CLK_PERIOD * 20);

        // Test case 2: Receive another byte (0x3C)
        fork
            begin
                // Start bit
                RX = 0;
                #(BIT_PERIOD);
                // Data bits (0x3C = 00111100)
                RX = 0; #(BIT_PERIOD); // Bit 0
                RX = 0; #(BIT_PERIOD); // Bit 1
                RX = 1; #(BIT_PERIOD); // Bit 2
                RX = 1; #(BIT_PERIOD); // Bit 3
                RX = 1; #(BIT_PERIOD); // Bit 4
                RX = 1; #(BIT_PERIOD); // Bit 5
                RX = 0; #(BIT_PERIOD); // Bit 6
                RX = 0; #(BIT_PERIOD); // Bit 7
                // Stop bit
                RX = 1;
                #(BIT_PERIOD);
            end

            begin
                wait(rdy == 1);
                $display("Received byte: %h", rx_data);
                $finish;
            end
        join
    end
endmodule