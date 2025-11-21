/*
PID Math Testbench
This testbench verifies the functionality of the PID_Math module.
*/
module PID_Math_tb;

    /*This is a simulation where ptch starts at 16’hFF00 (-256), ramps to 16’h0FF (+255).
Simultaneously integrator is smoothly ramping up/down four times from 18’h3C000 to
18’h03FFF and then back down to 18’h3C000. While all that is occurring ptch_rt is
ramping down/up eight times with extents of its ramp being 16’h0FFF to 16’hF000*/

    logic signed [15:0] ptch;
    logic signed [17:0] integrator;
    logic signed [15:0] ptch_rt;
    logic signed [11:0] PID_cntrl;

    PID_Math pid_math_inst (
        .ptch(ptch),
        .ptch_rt(ptch_rt),
        .integrator(integrator),
        .PID_cntrl(PID_cntrl)
    );
    initial begin
        // Initialize inputs
        ptch = 16'hFF00; // -256
        integrator = 18'h3C000; // Initial value
        ptch_rt = 16'h0FFF; // Initial value

        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator + 18'h00010; // Ramp integrator up
            ptch_rt = ptch_rt - 16'h0010; // Ramp ptch_rt down

        end

        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator + 18'h00010; // Ramp integrator up
            ptch_rt = ptch_rt + 16'h0010; // Ramp ptch_rt up

        end
        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator - 18'h00010; // Ramp integrator down
            ptch_rt = ptch_rt - 16'h0010; // Ramp ptch_rt down

        end
        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator - 18'h00010; // Ramp integrator down
            ptch_rt = ptch_rt + 16'h0010; // Ramp ptch_rt up

        end

        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator + 18'h00010; // Ramp integrator up
            ptch_rt = ptch_rt - 16'h0010; // Ramp ptch_rt down

        end

        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator + 18'h00010; // Ramp integrator up
            ptch_rt = ptch_rt + 16'h0010; // Ramp ptch_rt up

        end
        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator - 18'h00010; // Ramp integrator down
            ptch_rt = ptch_rt - 16'h0010; // Ramp ptch_rt down

        end
        repeat (64) begin
            #2;
            ptch = ptch + 16'h0001; // Ramp ptch from -256 to +255
            integrator = integrator - 18'h00010; // Ramp integrator down
            ptch_rt = ptch_rt + 16'h0010; // Ramp ptch_rt up

        end


    end
endmodule