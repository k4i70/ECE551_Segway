module inertial_integrator_tb();

    // Testbench signals
    reg clk;
    reg rst_n;
    reg vld;
    reg signed [15:0] ptch_rt;
    reg signed [15:0] AZ;
    wire signed [15:0] ptch;
    
    // Instantiate the DUT (Device Under Test)
    inertial_integrator iDUT (
        .clk(clk),
        .rst_n(rst_n),
        .vld(vld),
        .ptch_rt(ptch_rt),
        .AZ(AZ),
        .ptch(ptch)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock (10ns period)
    end
    
    // Test stimulus - Following exact sequence from images
    initial begin
        // Initialize signals
        rst_n = 0;
        vld = 0;
        ptch_rt = 0;
        AZ = 0;
        
        $display("Starting Inertial Integrator Test - Following Specification");
        
        // Apply reset and wait for deassertion
        #20;
        rst_n = 1;
        #10;
        
        // Step 1: After reset deassertion, apply ptch_rt of 16'h1000 + PTCH_RT_OFFSET
        // Apply AZ stimulus of 16'h0000. Ensure vld is held high.
        $display("Step 1: Applying ptch_rt = 16'h1050 (16'h1000 + PTCH_RT_OFFSET), AZ = 16'h0000");
        ptch_rt = 16'h1050;  // 16'h1000 + 16'h0050 (PTCH_RT_OFFSET)
        AZ = 16'h0000;       // 0 in decimal
        vld = 1;             // Enable valid signal
        
        // Step 2: Maintain this stimulus for 500 clocks
        // The ptch output should be trending more and more negative since we integrate the negative of ptch_rt
        $display("Step 2: Maintaining stimulus for 500 clocks - ptch should trend negative");
        #5000;  // 500 clocks
        
        // Step 3: Zero out the pitch rate by applying PTCH_RT_OFFSET to ptch_rt
        $display("Step 3: Zeroing out pitch rate (applying PTCH_RT_OFFSET to cancel out)");
        ptch_rt = 16'h0050;  // Just the offset, so ptch_rt_comp = 0
        
        // Step 4: Hold this stimulus for 1000 clocks
        // Due to fusion with AZ reading of zero, should see ptch trending slowly back toward zero
        $display("Step 4: Holding for 1000 clocks - ptch should trend back toward zero due to fusion");
        #10000;  // 1000 clocks
        
        // Step 5: Apply stimulus of PTCH_RT_OFFSET - 16'h1000 to ptch_rt for 500 clocks
        // The ptch output should trend steeply into positive territory
        $display("Step 5: Applying negative pitch rate - ptch should trend positive");
        ptch_rt = 16'h0050 - 16'h1000; // PTCH_RT_OFFSET - 16'h1000
        #5000;  // 500 clocks
        
        // Step 6: Again zero out the pitch rate by applying PTCH_RT_OFFSET to ptch_rt
        $display("Step 6: Zeroing pitch rate again");
        ptch_rt = 16'h0050;  // Just the offset
        
        // Step 7: Hold for 1000 clocks - ptch should trend slowly back toward zero
        $display("Step 7: Holding for 1000 clocks - ptch trending back to zero");
        #10000;  // 1000 clocks
        
        // Step 8: Finally adjust AZ to 16'h0800 (2048 decimal)
        // When ptch gets down to about 100 it should level off as the ptch calculated 
        // from AZ should match that from fusion and offset should start toggling -1024 to +1024
        $display("Step 8: Setting AZ to 16'h0800 (2048) - should see fusion leveling and toggling");
        AZ = 16'h0800;  // 2048 in decimal
        #15000;  // Hold for 1500 clocks to observe the leveling behavior
        
        $display("Test sequence completed - check waveforms for expected behavior");
        $finish;
    end
    
    // Additional monitoring for debug
    initial begin
        #10;
        forever begin
            @(posedge clk);
            // Check for fusion offset changes
            if (iDUT.fusion_ptch_offset != 0) begin
                $display("Time %0t: Fusion active - offset=%d, ptch=%d, ptch_acc=%d", 
                         $time, iDUT.fusion_ptch_offset, ptch, iDUT.ptch_acc);
            end
        end
    end
    
    // Waveform dump for viewing
    initial begin
        $dumpfile("inertial_integrator_tb.vcd");
        $dumpvars(0, inertial_integrator_tb);
    end
    
endmodule