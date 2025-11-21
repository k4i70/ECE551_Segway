//testbencg for SegwayMath.sv


module SegwayMath_tb;

    // Inputs
    logic signed [11:0] PID_cntrl; // PID control signal (12-bit signed)
    logic unsigned [7:0] ss_tmr;   // slow start timer (8-bit unsigned)
    logic unsigned [11:0] steer_pot; // steering potentiometer (12-bit unsigned)
    logic en_steer; // enable steering
    logic pwr_up; // power up signal

    // Outputs
    logic [11:0] lft_spd; // left speed command (12-bit signed)
    logic [11:0] rgt_spd;  // right speed command (12-bit signed)
    logic too_fast;         // too fast flag (1-bit unsigned)

    // Instantiate the device Under Test (DUT)
    SegwayMath dut (
        .PID_cntrl(PID_cntrl),
        .ss_tmr(ss_tmr),
        .steer_pot(steer_pot),
        .en_steer(en_steer),
        .pwr_up(pwr_up),
        .lft_spd(lft_spd),
        .rgt_spd(rgt_spd),
        .too_fast(too_fast)
    );

    initial begin
        // Initialize Inputs
        PID_cntrl = 12'sd0;
        ss_tmr = 8'd0;
        steer_pot = 12'd2048; // Center position
        en_steer = 1'b0;
        pwr_up = 1'b1;

        // Wait for global reset to finish
        #10;
        
        PID_cntrl = 12'h5FF;
        repeat (255) begin
            ss_tmr = ss_tmr + 1;
            #1;
        end
        repeat (2047) begin
            PID_cntrl = PID_cntrl - 1;
            #1;
        end


        //test 2
        #100
        steer_pot = 12'h000;
        en_steer = 1'b1;
        PID_cntrl = 12'h3FF;
        ss_tmr = 8'hFF;

        repeat (2047) begin
            PID_cntrl = PID_cntrl - 1;
            steer_pot = steer_pot + 2;
            #1;
        end

        pwr_up = 1'b0;
    
    end

endmodule