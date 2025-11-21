// PWM11 Testbench
module PWM11_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // Clock period in time units

    // Inputs
    logic clk;
    logic rst_n;
    logic [10:0] duty;

    // Outputs
    wire PWM1;
    wire PWM2;
    wire PWM_synch;
    wire ovr_I_blank;

    // Instantiate the DUT (Device Under Test)
    PWM11 dut (
        .clk(clk),
        .rst_n(rst_n),
        .duty(duty),
        .PWM1(PWM1),
        .PWM2(PWM2),
        .PWM_synch(PWM_synch),
        .ovr_I_blank(ovr_I_blank)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize inputs
        rst_n = 0;
        duty = 11'h000; // Start with 0% duty cycle

        // Apply reset
        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Test different duty cycles
        repeat (30) begin
            #(CLK_PERIOD * 2048); // Wait for 2048 clock cycles
            duty = duty + 11'h066; // Increment duty cycle by ~20%
            if (duty > 11'h7FF) duty = 11'h000; // Wrap around if exceeding max
        end

        // Finish simulation
        #(CLK_PERIOD * 2048);
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("Time: %0t | Duty: %h | PWM1: %b | PWM2: %b | PWM_synch: %b | ovr_I_blank: %b", 
                 $time, duty, PWM1, PWM2, PWM_synch, ovr_I_blank);
    end
endmodule
