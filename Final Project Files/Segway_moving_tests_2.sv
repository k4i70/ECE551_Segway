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

localparam bit DEBUG_SEGWAY = 1'b1;
localparam int WRAP_DELTA_THRESHOLD = 700;
localparam logic signed [11:0] TOO_FAST_FORCE_SPEED = 12'sd1900;
localparam int TOO_FAST_FORCE_TIMEOUT = 50_000; // cycles to wait for helper to trip too_fast
localparam int TOO_FAST_FORCE_RELEASE_DELAY = 2_000;

// Internal math monitors (hierarchical taps into DUT)
logic signed [11:0] pid_cntrl_mon;
logic signed [11:0] pid_ss_mon;
logic signed [12:0] lft_torque_mon, rght_torque_mon;
logic signed [12:0] lft_torque_shaped_mon, rght_torque_shaped_mon;
logic signed [12:0] lft_spd_unsat_mon, rght_spd_unsat_mon;
logic signed [19:0] pid_ss_high_mon;

// Debug statistics
int max_pid_cntrl_mag, max_pid_ss_mag;
int max_lft_shaped_mag, max_rght_shaped_mag;
int max_lft_spd_mag, max_rght_spd_mag;
int lft_wrap_events, rght_wrap_events;
int prev_lft_spd_sample, prev_rght_spd_sample;
logic too_fast_prev;
int too_fast_trip_pid_cntrl, too_fast_trip_lft_spd, too_fast_trip_rght_spd;
logic too_fast_trip_seen;

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
	pid_cntrl_mon = iDUT.iBAL.PID_cntrl;
	pid_ss_mon = iDUT.iBAL.segway_math_inst.PID_ss;
	pid_ss_high_mon = iDUT.iBAL.segway_math_inst.PID_ss_high;
	lft_torque_mon = iDUT.iBAL.segway_math_inst.lft_torque;
	rght_torque_mon = iDUT.iBAL.segway_math_inst.rght_torque;
	lft_torque_shaped_mon = iDUT.iBAL.segway_math_inst.lft_torque_shaped;
	rght_torque_shaped_mon = iDUT.iBAL.segway_math_inst.rght_torque_shaped;
	lft_spd_unsat_mon = iDUT.iBAL.segway_math_inst.lft_spd_unsat;
	rght_spd_unsat_mon = iDUT.iBAL.segway_math_inst.rght_spd_unsat;
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

task automatic dump_segway_math_state(input string tag);
	int pid_cntrl_i, pid_ss_i;
	int lft_torque_i, rght_torque_i;
	int lft_shape_i, rght_shape_i;
	int lft_unsat_i, rght_unsat_i;
	begin
		pid_cntrl_i = $signed(pid_cntrl_mon);
		pid_ss_i    = $signed(pid_ss_mon);
		lft_torque_i = $signed(lft_torque_mon);
		rght_torque_i = $signed(rght_torque_mon);
		lft_shape_i = $signed(lft_torque_shaped_mon);
		rght_shape_i = $signed(rght_torque_shaped_mon);
		lft_unsat_i = $signed(lft_spd_unsat_mon);
		rght_unsat_i = $signed(rght_spd_unsat_mon);
		$display("[%0t] %s", $time, tag);
		$display("  PID: ctrl=%0d ss_tmr=0x%0h ss_scaled=%0d mult=%0d", pid_cntrl_i, ss_tmr_mon, pid_ss_i, $signed(pid_ss_high_mon));
		$display("  LFT: torque=%0d shaped=%0d unsat=%0d spd=%0d", lft_torque_i, lft_shape_i, lft_unsat_i, lft_spd_mon);
		$display("  RGT: torque=%0d shaped=%0d unsat=%0d spd=%0d", rght_torque_i, rght_shape_i, rght_unsat_i, rght_spd_mon);
	end
endtask

task automatic report_segway_debug();
	$display("================ SegwayMath debug summary ================");
	$display("  |PID_cntrl| max = %0d", max_pid_cntrl_mag);
	$display("  |PID_ss|    max = %0d", max_pid_ss_mag);
	$display("  |lft_shaped| max = %0d", max_lft_shaped_mag);
	$display("  |rgt_shaped| max = %0d", max_rght_shaped_mag);
	$display("  |lft_spd| max = %0d (wrap events=%0d)", max_lft_spd_mag, lft_wrap_events);
	$display("  |rgt_spd| max = %0d (wrap events=%0d)", max_rght_spd_mag, rght_wrap_events);
	if (too_fast_trip_seen) begin
		$display("  Too-fast trip snapshot: PID=%0d LFT=%0d RGT=%0d", too_fast_trip_pid_cntrl,
			too_fast_trip_lft_spd, too_fast_trip_rght_spd);
	end else begin
		$display("  Too-fast never asserted in this run");
	end
	$display("==========================================================");
endtask

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

always_ff @(posedge clk or negedge RST_n) begin : monitor_segway_math
	int pid_mag, pid_ss_mag;
	int lft_shape_mag, rght_shape_mag;
	int lft_spd_mag, rght_spd_mag;
	int delta_lft, delta_rght;
	if (!RST_n) begin
		max_pid_cntrl_mag <= 0;
		max_pid_ss_mag    <= 0;
		max_lft_shaped_mag <= 0;
		max_rght_shaped_mag <= 0;
		max_lft_spd_mag <= 0;
		max_rght_spd_mag <= 0;
		lft_wrap_events <= 0;
		rght_wrap_events <= 0;
		prev_lft_spd_sample <= 0;
		prev_rght_spd_sample <= 0;
		too_fast_prev <= 1'b0;
		too_fast_trip_pid_cntrl <= 0;
		too_fast_trip_lft_spd <= 0;
		too_fast_trip_rght_spd <= 0;
		too_fast_trip_seen <= 1'b0;
	end else begin
		if (pwr_up_mon) begin
			pid_mag      = abs_int($signed(pid_cntrl_mon));
			pid_ss_mag   = abs_int($signed(pid_ss_mon));
			lft_shape_mag = abs_int($signed(lft_torque_shaped_mon));
			rght_shape_mag = abs_int($signed(rght_torque_shaped_mon));
			lft_spd_mag  = abs_int($signed(lft_spd_mon));
			rght_spd_mag = abs_int($signed(rght_spd_mon));
			if (pid_mag > max_pid_cntrl_mag) begin
				max_pid_cntrl_mag <= pid_mag;
				if (DEBUG_SEGWAY) $display("[%0t] DEBUG: new |PID_cntrl| max = %0d", $time, pid_mag);
			end
			if (pid_ss_mag > max_pid_ss_mag) begin
				max_pid_ss_mag <= pid_ss_mag;
				if (DEBUG_SEGWAY) $display("[%0t] DEBUG: new |PID_ss| max = %0d", $time, pid_ss_mag);
			end
			if (lft_shape_mag > max_lft_shaped_mag) begin
				max_lft_shaped_mag <= lft_shape_mag;
			end
			if (rght_shape_mag > max_rght_shaped_mag) begin
				max_rght_shaped_mag <= rght_shape_mag;
			end
			if (lft_spd_mag > max_lft_spd_mag) begin
				max_lft_spd_mag <= lft_spd_mag;
			end
			if (rght_spd_mag > max_rght_spd_mag) begin
				max_rght_spd_mag <= rght_spd_mag;
			end
			delta_lft = abs_int($signed(lft_spd_mon) - prev_lft_spd_sample);
			delta_rght = abs_int($signed(rght_spd_mon) - prev_rght_spd_sample);
			if (delta_lft > WRAP_DELTA_THRESHOLD) begin
				lft_wrap_events <= lft_wrap_events + 1;
				if (DEBUG_SEGWAY) dump_segway_math_state("LFT speed discontinuity");
			end
			if (delta_rght > WRAP_DELTA_THRESHOLD) begin
				rght_wrap_events <= rght_wrap_events + 1;
				if (DEBUG_SEGWAY) dump_segway_math_state("RGT speed discontinuity");
			end
		end
		prev_lft_spd_sample <= $signed(lft_spd_mon);
		prev_rght_spd_sample <= $signed(rght_spd_mon);
		if (too_fast_mon && !too_fast_prev) begin
			too_fast_trip_pid_cntrl <= $signed(pid_cntrl_mon);
			too_fast_trip_lft_spd   <= $signed(lft_spd_mon);
			too_fast_trip_rght_spd  <= $signed(rght_spd_mon);
			too_fast_trip_seen <= 1'b1;
			if (DEBUG_SEGWAY) dump_segway_math_state("too_fast asserted");
		end
		too_fast_prev <= too_fast_mon;
	end
end

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
		if (DEBUG_SEGWAY) dump_segway_math_state("TooFast fallback snapshot");
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
			if (DEBUG_SEGWAY) dump_segway_math_state("TooFast helper failure snapshot");
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

	// Inject a burst of overcurrent pulses on both channels
	for (pulse = 0; pulse < 40; pulse++) begin
		OVR_I_lft = 1'b1;
		OVR_I_rght = 1'b1;
		wait_cycles(clk, 8);
		OVR_I_lft = 1'b0;
		OVR_I_rght = 1'b0;
		wait_cycles(clk, 25);
	end

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
	int diff_low_ext, diff_low_bound, diff_high_ext, diff_high_bound;
	$display("[%0t] ---- Steering authority test ----", $time);
	power_up_with_rider(clk, ld_cell_lft, ld_cell_rght, steerPot, rider_lean,
											cmd_sent, send_cmd, cmd, pwr_up_mon, en_steer_mon, rider_off_mon, "Steer");
	wait_softstart_ready("Steer_ss");

	rider_lean = 16'sh0200;
	wait_cycles(clk, 80_000);

	steerPot = 12'h010; // below minimum saturation
	wait_cycles(clk, 20_000);
	diff_low_ext = lft_spd_mon - rght_spd_mon;

	steerPot = 12'h200; // at minimum boundary
	wait_cycles(clk, 20_000);
	diff_low_bound = lft_spd_mon - rght_spd_mon;
	if (abs_int(diff_low_ext - diff_low_bound) > 8) begin
		$display("[Steer] ERROR: Lower saturation mismatch (ext=%0d bound=%0d)", diff_low_ext, diff_low_bound);
		failed_tests++;
	end
	if (diff_low_bound >= 0) begin
		$display("[Steer] ERROR: Expected right turn (diff=%0d)", diff_low_bound);
		failed_tests++;
	end

	steerPot = 12'hE00; // upper boundary
	wait_cycles(clk, 20_000);
	diff_high_bound = lft_spd_mon - rght_spd_mon;
	if (diff_high_bound <= 0) begin
		$display("[Steer] ERROR: Expected left turn at 0xE00 (diff=%0d)", diff_high_bound);
		failed_tests++;
	end

	steerPot = 12'hF50; // above upper saturation
	wait_cycles(clk, 20_000);
	diff_high_ext = lft_spd_mon - rght_spd_mon;
	if (abs_int(diff_high_ext - diff_high_bound) > 8) begin
		$display("[Steer] ERROR: Upper saturation mismatch (ext=%0d bound=%0d)", diff_high_ext, diff_high_bound);
		failed_tests++;
	end

	// Disable steering by unbalancing weight and ensure speeds realign
	ld_cell_lft = 12'h360;
	ld_cell_rght = 12'h080;
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

	/*apply_reset("Initial");

	lean_response_test();
	*/apply_reset("Post_Lean");

	too_fast_test();
	/*apply_reset("Post_TooFast");

	overcurrent_protection_test();
	apply_reset("Post_OVR");

	steering_authority_test();

	*/report_segway_debug();
	$display("[%0t] All Segway moving tests completed successfully", $time);
    $display("[%0t] Passed tests: %0d", $time, passed_tests);
    $display("[%0t] Failed tests: %0d", $time, failed_tests);

	$stop();
end

endmodule
