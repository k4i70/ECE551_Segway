//testbench for exhaustive self-checking testing of MSFF

module MSFF_tb;
    reg d, clk;
    wire q;

    MSFF dut (.d(d), .clk(clk), .q(q));

    initial begin 
        clk = 0;
        forever #5 clk = ~clk; // Clock period of 10 time units
    end

    initial begin
        // Initialize inputs
        d = 0;

        // Test sequence
        #10 d = 1; 
        #10 d = 1;
        #10 d = 0;
        #10 d = 0;
        #20 d = 1;
        #15 d = 0;
        #10 d = 1;

        // Finish simulation
        #10 $finish;
    end
endmodule
