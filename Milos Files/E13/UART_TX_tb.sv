//testbench for UART_TX

module UART_TX_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    parameter BAUD_PERIOD = 5208 * CLK_PERIOD; // Approximate period for 9600 baud

    // Signals
    logic clk;
    logic rst_n;
    logic trmt;
    logic [7:0] tx_data;
    logic TX;
    logic tx_done;

    // Instantiate the DUT
    UART_TX dut (
        .clk(clk),
        .rst_n(rst_n),
        .trmt(trmt),
        .tx_data(tx_data),
        .TX(TX),
        .tx_done(tx_done)
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
        trmt = 0;
        tx_data = 8'h00;

        // Release reset
        #(CLK_PERIOD * 5);
        rst_n = 1;

        // Wait for a few clock cycles
        #(CLK_PERIOD * 10);

        // Test case 1: Transmit a byte (0xA5)
        tx_data = 8'hA5;
        trmt = 1; // Trigger transmission
        #(CLK_PERIOD);
        trmt = 0; // Clear trigger

        // Wait for transmission to complete
        wait(tx_done == 1);
        #(CLK_PERIOD * 10); // Wait a bit after done
        // Check TX line (should be idle high)
        //send another byte
        tx_data = 8'h3C;
        trmt = 1; // Trigger transmission
        #(CLK_PERIOD);
        trmt = 0; // Clear trigger
        wait(tx_done == 1);
        #(CLK_PERIOD * 10); // Wait a bit after done
        // Finish simulation
        $finish;
    end
endmodule