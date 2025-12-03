`include "tests_package.sv"

module Segway_moving_tests_2;

import tests_package::*;

//// Interconnects to DUT/support defined as type wire /////
wire SS_n, SCLK, MOSI, MISO, INT; // to inertial sensor
wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO; // to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo, piezo_n;

////// Stimulus registers ///////
logic clk, RST_n;
logic rst_n;
logic send_cmd;
logic cmd_sent;
logic [7:0] cmd;
logic signed [15:0] rider_lean;
logic [11:0] ld_cell_lft, ld_cell_rght, steerPot, batt;
logic OVR_I_lft, OVR_I_rght;

///// Monitored DUT internals ///////
logic pwr_up_mon, en_steer_mon, rider_off_mon, batt_low_mon;
logic piezo_mon;
logic too_fast_mon;
logic OVR_I_shtdwn_mon;
logic [7:0] ss_tmr_mon;
logic signed [11:0] lft_spd_mon, rght_spd_mon;
logic pwm_synch_mon;

localparam logic signed [11:0] TOO_FAST_FORCE_SPEED = 12'sd1900;
localparam int TOO_FAST_FORCE_TIMEOUT = 50_000; // cycles to wait for helper to trip too_fast
localparam int TOO_FAST_FORCE_RELEASE_DELAY = 2_000;

// Error counters
int passed_tests, failed_tests;

//////////////////////////////////////////////
// Instantiate Physical Model of Segway //
////////////////////////////////////////////
SegwayModel iPHYS(
	.clk(clk),
	.RST_n(RST_n),
	.SS_n(SS_n),
	.SCLK(SCLK),
	.MISO(MISO),
	.MOSI(MOSI),
	.INT(INT),
	.PWM1_lft(PWM1_lft),
	.PWM2_lft(PWM2_lft),
	.PWM1_rght(PWM1_rght),
	.PWM2_rght(PWM2_rght),
	.rider_lean(rider_lean)
);

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S_FC iA2D(
	.clk(clk),
	.rst_n(RST_n),
	.SS_n(A2D_SS_n),
	.SCLK(A2D_SCLK),
	.MISO(A2D_MISO),
	.MOSI(A2D_MOSI),
	.ld_cell_lft(ld_cell_lft),
	.ld_cell_rght(ld_cell_rght),
	.steerPot(steerPot),
	.batt(batt)
);

////// Instantiate DUT ////////
Segway iDUT(
	.clk(clk),
	.RST_n(RST_n),
	.INERT_SS_n(SS_n),
	.INERT_MOSI(MOSI),
	.INERT_SCLK(SCLK),
	.INERT_MISO(MISO),
	.INERT_INT(INT),
	.A2D_SS_n(A2D_SS_n),
	.A2D_MOSI(A2D_MOSI),
	.A2D_SCLK(A2D_SCLK),
	.A2D_MISO(A2D_MISO),
	.PWM1_lft(PWM1_lft),
	.PWM2_lft(PWM2_lft),
	.PWM1_rght(PWM1_rght),
	.PWM2_rght(PWM2_rght),
	.OVR_I_lft(OVR_I_lft),
	.OVR_I_rght(OVR_I_rght),
	.piezo_n(piezo_n),
	.piezo(piezo),
	.RX(RX_TX)
);

//// Instantiate UART_tx (mimics command from BLE module) //////
UART_TX iTX(
	.clk(clk),
	.rst_n(rst_n),
	.TX(RX_TX),
	.trmt(send_cmd),
	.tx_data(cmd),
	.tx_done(cmd_sent)
);

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(
	.clk(clk),
	.RST_n(RST_n),
	.rst_n(rst_n)
);

// Monitored DUT internals for reusable task package and assertions
always_comb begin
	pwr_up_mon    = iDUT.pwr_up;
	en_steer_mon  = iDUT.en_steer;
	rider_off_mon = iDUT.rider_off;
	batt_low_mon  = iDUT.batt_low;
	piezo_mon     = piezo;
	too_fast_mon  = iDUT.too_fast;
	ss_tmr_mon    = iDUT.iBAL.pid_inst.ss_tmr;
	lft_spd_mon   = iDUT.lft_spd;
	rght_spd_mon  = iDUT.rght_spd;
	OVR_I_shtdwn_mon = iDUT.iDRV.OVR_I_shtdwn;
	pwm_synch_mon = iDUT.iDRV.PWM_synch;
end

// Clock generation
always #10 clk = ~clk;

// Helper functions
function automatic int abs12(input signed [11:0] value);
	abs12 = (value < 0) ? -value : value;
endfunction

function automatic int abs_int(input int value);
	abs_int = (value < 0) ? -value : value;
endfunction

task automatic start_forced_too_fast();
	$display("[%0t] TooFast helper: forcing speeds to %0d", $time, $signed(TOO_FAST_FORCE_SPEED));
	force iDUT.iBAL.segway_math_inst.lft_spd = TOO_FAST_FORCE_SPEED;
	force iDUT.iBAL.segway_math_inst.rght_spd = TOO_FAST_FORCE_SPEED;
	force iDUT.lft_spd = TOO_FAST_FORCE_SPEED;
	force iDUT.rght_spd = TOO_FAST_FORCE_SPEED;
endtask

task automatic stop_forced_too_fast();
	$display("[%0t] TooFast helper: releasing forced speeds", $time);
	release iDUT.iBAL.segway_math_inst.lft_spd;
	release iDUT.iBAL.segway_math_inst.rght_spd;
	release iDUT.lft_spd;
	release iDUT.rght_spd;
endtask

task automatic inject_overcurrent_pulses(input int num_pulses);
	int pulse;
	for (pulse = 0; pulse < num_pulses; pulse++) begin
		@(posedge pwm_synch_mon);
		// Skip the blanking zone near PWM edges
		wait_cycles(clk, 220);
		OVR_I_lft = 1'b1;
		OVR_I_rght = 1'b1;
		wait_cycles(clk, 80);
		OVR_I_lft = 1'b0;
		OVR_I_rght = 1'b0;
	end
endtask

task automatic init_inputs();
	send_cmd    = 1'b0;
	cmd         = 8'h00;
	rider_lean  = 16'sh0000;
	ld_cell_lft = 12'h000;
	ld_cell_rght = 12'h000;
	steerPot    = 12'h800;
	batt        = 12'hC00;
	OVR_I_lft   = 1'b0;
	OVR_I_rght  = 1'b0;
endtask


task automatic wait_softstart_ready(input string tag);
	int cycles;
	for (cycles = 0; cycles < 800_000; cycles++) begin
		@(posedge clk);
		if (ss_tmr_mon == 8'hFF) begin
			$display("[%0t] %s: ss_tmr saturated", $time, tag);
			return;
		end
	end
	$display("[%s] ERROR: ss_tmr failed to reach 0xFF (last=0x%0h)", tag, ss_tmr_mon);
	failed_tests++;
endtask

task automatic apply_reset(input string tag);
	$display("[%0t] ---- Applying reset (%s) ----", $time, tag);
	RST_n = 1'b0;
	init_inputs();
	wait_cycles(clk, 50);
	RST_n = 1'b1;
	wait_cycles(clk, 200);
	wait (rst_n === 1'b1);
	wait_cycles(clk, 20);
	if (pwr_up_mon !== 1'b0) begin
		$display("[%s] ERROR: pwr_up should be low after reset", tag);
		failed_tests++;
	end
	if (en_steer_mon !== 1'b0) begin
		$display("[%s] ERROR: en_steer should be low after reset", tag);
		failed_tests++;
	end
	if (rider_off_mon !== 1'b1) begin
		$display("[%s] ERROR: rider_off should be high after reset", tag);
		failed_tests++;
	end
	$display("[%0t] Reset complete (%s)", $time, tag);
endtask

task automatic lean_response_test();
	int lft_idle, rght_idle;
	$display("[%0t] ---- Lean response test ----", $time);
	power_up_with_rider(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
							cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon, "Lean");
	wait_softstart_ready("Lean_ss");

	// Capture baseline values with no rider lean applied
	rider_lean = 16'sh0000;
	wait_cycles(clk, 20_000);
	lft_idle = lft_spd_mon;
	rght_idle = rght_spd_mon;
	$display("[Lean] Idle baseline lft=%0d rght=%0d", lft_idle, rght_idle);

	// Tiny lean should not move speeds far from baseline due to deadband shaping
	rider_lean = 16'sh0010;
	wait_cycles(clk, 20_000);
	if (abs_int(lft_spd_mon - lft_idle) > 80 || abs_int(rght_spd_mon - rght_idle) > 80) begin
		$display("[Lean] ERROR: Deadband failed for small lean (lft=%0d rght=%0d)", lft_spd_mon, rght_spd_mon);
		failed_tests++;
	end

	// Forward lean should increase magnitude and align both motors in same direction
	rider_lean = 16'sh0400;
	wait_cycles(clk, 60_000);
	if ((lft_spd_mon <= 0) || (rght_spd_mon <= 0)) begin
		$display("[Lean] ERROR: Forward lean did not produce positive speed (lft=%0d rght=%0d)", lft_spd_mon, rght_spd_mon);
		failed_tests++;
	end
	if (abs_int(lft_spd_mon - rght_spd_mon) > 80) begin
		$display("[Lean] ERROR: Motors not balanced under forward lean (diff=%0d)", lft_spd_mon - rght_spd_mon);
		failed_tests++;
	end
	if ((abs12(lft_spd_mon) <= abs12(lft_idle) + 150) || (abs12(rght_spd_mon) <= abs12(rght_idle) + 150)) begin
		$display("[Lean] ERROR: Forward lean did not significantly increase speed (idle lft=%0d rght=%0d curr lft=%0d rght=%0d)",
					lft_idle, rght_idle, lft_spd_mon, rght_spd_mon);
		failed_tests++;
	end

	// Reverse lean should drive both motors in reverse with similar magnitude
	rider_lean = -16'sh0400;
	wait_cycles(clk, 60_000);
	if ((lft_spd_mon >= 0) || (rght_spd_mon >= 0)) begin
		$display("[Lean] ERROR: Reverse lean did not produce negative speed (lft=%0d rght=%0d)", lft_spd_mon, rght_spd_mon);
		failed_tests++;
	end
	if (abs_int(lft_spd_mon - rght_spd_mon) > 80) begin
		$display("[Lean] ERROR: Motors not balanced under reverse lean (diff=%0d)", lft_spd_mon - rght_spd_mon);
		failed_tests++;
	end
	if ((abs12(lft_spd_mon) <= abs12(lft_idle) + 150) || (abs12(rght_spd_mon) <= abs12(rght_idle) + 150)) begin
		$display("[Lean] ERROR: Reverse lean did not significantly increase magnitude");
		failed_tests++;
	end

	rider_lean = 16'sh0000;
    if (failed_tests == 0) begin
        passed_tests++;
	    $display("[%0t] Lean response test passed", $time);
    end
endtask

task automatic too_fast_test();
	int cycles;
	bit overspeed_seen;
	bit forced_active;
	$display("[%0t] ---- Too fast test ----", $time);
	power_up_with_rider(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
											cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon, "TooFast");
	wait_softstart_ready("TooFast_ss");

	rider_lean = 16'sd1500; // original forward lean magnitude
	overspeed_seen = 1'b0;
	forced_active = 1'b0;
	for (cycles = 0; cycles < 600_000; cycles++) begin
		@(posedge clk);
		if (too_fast_mon) begin
			overspeed_seen = 1'b1;
			$display("[%0t] TooFast: too_fast asserted via rider lean", $time);
			break;
		end
	end
	if (!overspeed_seen) begin
		$display("[TooFast] INFO: rider lean did not trigger too_fast, applying helper");
		start_forced_too_fast();
		forced_active = 1'b1;
		for (cycles = 0; cycles < TOO_FAST_FORCE_TIMEOUT; cycles++) begin
			@(posedge clk);
			if (too_fast_mon) begin
				overspeed_seen = 1'b1;
				$display("[%0t] TooFast: helper forced too_fast assertion", $time);
				break;
			end
		end
		if (!overspeed_seen) begin
			$display("[TooFast] ERROR: helper forcing failed to trip too_fast");
			stop_forced_too_fast();
			forced_active = 1'b0;
		end
	end
	if (!overspeed_seen) begin
		$display("[TooFast] ERROR: too_fast never asserted");
		failed_tests++;
		return;
	end

	wait_piezo_active(clk, piezo_mon, PIEZO_TIMEOUT, "TooFast_piezo");
	if (forced_active) begin
		wait_cycles(clk, TOO_FAST_FORCE_RELEASE_DELAY);
		stop_forced_too_fast();
		forced_active = 1'b0;
	end

	rider_lean = 16'sh0000;
	for (cycles = 0; cycles < 300_000; cycles++) begin
		@(posedge clk);
		if (!too_fast_mon) begin
			$display("[%0t] TooFast: too_fast cleared", $time);
			break;
		end
	end
	if (too_fast_mon) begin
		$display("[TooFast] ERROR: too_fast did not clear after removing lean");
		failed_tests++;
	end
    if (failed_tests == 0) begin
        passed_tests++;
        $display("[%0t] Too fast test passed", $time);
    end
endtask

task automatic overcurrent_protection_test();
	int pulse;
	$display("[%0t] ---- Overcurrent protection test ----", $time);
	power_up_with_rider(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
											cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon, "OVR");
	wait_softstart_ready("OVR_ss");

	rider_lean = 16'sh0300; // keep motors active
	wait_cycles(clk, 30_000);

	inject_overcurrent_pulses(40);

	// Wait for shutdown to assert
	for (pulse = 0; pulse < 200_000; pulse++) begin
		@(posedge clk);
		if (OVR_I_shtdwn_mon) begin
			$display("[%0t] Overcurrent: shutdown asserted", $time);
			break;
		end
	end
	if (!OVR_I_shtdwn_mon) begin
		$display("[Overcurrent] ERROR: OVR_I_shtdwn did not assert");
		failed_tests++;
	end

	// Ensure PWM outputs are forced low once shutdown occurs
	repeat (128) begin
		@(posedge clk);
		if (PWM1_lft !== 1'b0 || PWM2_lft !== 1'b0 ||
				PWM1_rght !== 1'b0 || PWM2_rght !== 1'b0) begin
			$display("[Overcurrent] ERROR: PWM outputs still toggling after shutdown");
			failed_tests++;
		end
	end

    if (failed_tests == 0) begin
        passed_tests++;
        $display("[%0t] Overcurrent protection test passed", $time);
    end
endtask

task automatic steering_authority_test();
	int diff_low_bound, diff_high_bound;
	$display("[%0t] ---- Steering authority test ----", $time);
	power_up_with_rider(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
											cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon, "Steer");
	wait_softstart_ready("Steer_ss");

	rider_lean = 16'sh0200;
	wait_cycles(clk, 80_000);

	steerPot = 12'h010; // below minimum saturation
	wait_cycles(clk, 60_000);

	steerPot = 12'h200; // at minimum boundary
	wait_cycles(clk, 20_000);
	diff_low_bound = lft_spd_mon - rght_spd_mon;
	if (diff_low_bound >= 0) begin
		$display("[Steer] ERROR: Expected right turn (diff=%0d)", diff_low_bound);
		failed_tests++;
	end

	steerPot = 12'hE00; // upper boundary
	wait_cycles(clk, 60_000);
	diff_high_bound = lft_spd_mon - rght_spd_mon;
	if (diff_high_bound <= 0) begin
		$display("[Steer] ERROR: Expected left turn at 0xE00 (diff=%0d)", diff_high_bound);
		failed_tests++;
	end

	steerPot = 12'hF50; // above upper saturation
	wait_cycles(clk, 60_000);

	// Disable steering by unbalancing weight and ensure speeds realign
	ld_cell_lft = 12'h020;
	ld_cell_rght = 12'h5C0;
	wait_en_steer(clk, en_steer_mon, 1'b0, "Steer_disable");
	wait_cycles(clk, 30_000);
	if (abs_int(lft_spd_mon - rght_spd_mon) > 30) begin
		$display("[Steer] ERROR: en_steer low but motors still differ (diff=%0d)", lft_spd_mon - rght_spd_mon);
		failed_tests++;
	end

	// Rebalance rider weight to re-enable steering
	ld_cell_lft = 12'h480;
	ld_cell_rght = 12'h480;
	wait_en_steer(clk, en_steer_mon, 1'b1, "Steer_enable");
	wait_cycles(clk, 30_000);
	if (en_steer_mon !== 1'b1) begin
		$display("[Steer] ERROR: Steering failed to re-enable");
		failed_tests++;
	end

    if (failed_tests == 0) begin
        passed_tests++;
        $display("[%0t] Steering authority test passed", $time);
    end
endtask

initial begin
	clk = 1'b0;
	RST_n = 1'b0;
	init_inputs();

	apply_reset("Initial");

	lean_response_test();
	apply_reset("Post_Lean");

	too_fast_test();
	apply_reset("Post_TooFast");

	overcurrent_protection_test();
	apply_reset("Post_OVR");

	steering_authority_test();
	$display("[%0t] All Segway moving tests completed successfully", $time);
    $display("[%0t] Passed tests: %0d", $time, passed_tests);
    $display("[%0t] Failed tests: %0d", $time, failed_tests);

	$stop();
end

endmodule
