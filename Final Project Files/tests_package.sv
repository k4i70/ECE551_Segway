package tests_package;

localparam int AUTH_TIMEOUT  = 200_000;
localparam int STEER_TIMEOUT = 300_000;
localparam int PIEZO_TIMEOUT = 200_000_000;

task automatic wait_cycles(ref logic clk, input int cycles);
  repeat (cycles) @(posedge clk);
endtask

task automatic wait_rider_off(
  ref logic clk,
  ref logic rider_off,
  input bit expected,
  input string tag
);
  int cycles;
  for (cycles = 0; cycles < STEER_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (rider_off === expected)
      return;
  end
  $display("[%s] Timeout waiting for rider_off=%0b (last=%0b)", tag, expected, rider_off);
  $stop;
endtask

task automatic wait_en_steer(
  ref logic clk,
  ref logic en_steer,
  input bit expected,
  input string tag
);
  int cycles;
  for (cycles = 0; cycles < STEER_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (en_steer === expected)
      return;
  end
  $display("[%s] Timeout waiting for en_steer=%0b (last=%0b)", tag, expected, en_steer);
  $stop;
endtask

task automatic wait_pwr_up(
  ref logic clk,
  ref logic pwr_up,
  input bit expected,
  input string tag
);
  int cycles;
  for (cycles = 0; cycles < AUTH_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (pwr_up === expected)
      return;
  end
  $display("[%s] Timeout waiting for pwr_up=%0b (last=%0b)", tag, expected, pwr_up);
  $stop;
endtask

task automatic wait_batt_low(
  ref logic clk,
  ref logic batt_low,
  input bit expected,
  input string tag
);
  int cycles;
  for (cycles = 0; cycles < PIEZO_TIMEOUT; cycles++) begin
    @(posedge clk);
    if (batt_low === expected)
      return;
  end
  $display("[%s] Timeout waiting for batt_low=%0b (last=%0b)", tag, expected, batt_low);
  $stop;
endtask

task automatic wait_piezo_active(
  ref logic clk,
  ref logic piezo,
  input int timeout_cycles,
  input string tag
);
  bit last_state;
  int cycles;
  last_state = piezo;
  for (cycles = 0; cycles < timeout_cycles; cycles++) begin
    @(posedge clk);
    if (piezo !== last_state) begin
      $display("[%0t] %s: piezo toggled", $time, tag);
      return;
    end
    last_state = piezo;
  end
  $display("[%s] Timeout waiting for piezo activity (last=%0b)", tag, piezo);
  $stop;
endtask

task automatic wait_piezo_idle(
  ref logic clk,
  ref logic piezo,
  input int timeout_cycles,
  input int stable_cycles,
  input string tag
);
  int cycles;
  int stable_count;
  stable_count = (piezo == 1'b0) ? 1 : 0;
  for (cycles = 0; cycles < timeout_cycles; cycles++) begin
    @(posedge clk);
    if (piezo == 1'b0) begin
      stable_count++;
      if (stable_count >= stable_cycles) begin
        $display("[%0t] %s: piezo idle", $time, tag);
        return;
      end
    end else begin
      stable_count = 0;
    end
  end
  $display("[%s] Timeout waiting for piezo to go idle (last=%0b)", tag, piezo);
  $stop;
endtask

task automatic send_uart_byte(
  ref logic clk,
  ref logic cmd_sent,
  ref logic send_cmd,
  ref logic [7:0] cmd,
  input [7:0] data,
  input string tag
);
  wait (cmd_sent === 1'b1);
  @(posedge clk);
  cmd = data;
  send_cmd = 1'b1;
  @(posedge clk);
  send_cmd = 1'b0;
  wait (cmd_sent === 1'b0);
  wait (cmd_sent === 1'b1);
  $display("[%0t] %s: UART byte 0x%02h sent", $time, tag, data);
endtask

task automatic power_up_with_rider(
  ref logic clk,
  ref logic [11:0] ld_cell_lft,
  ref logic [11:0] ld_cell_rght,
  ref logic [11:0] steer_pot,
  ref logic signed [15:0] rider_lean,
  ref logic cmd_sent,
  ref logic send_cmd,
  ref logic [7:0] cmd,
  ref logic pwr_up,
  ref logic en_steer,
  ref logic rider_off,
  input string tag
);
  ld_cell_lft = 12'h480;
  ld_cell_rght = 12'h480;
  steer_pot = 12'h800;
  rider_lean = 16'sh0000;
  wait_rider_off(clk, rider_off, 1'b0, tag);
  send_uart_byte(clk, cmd_sent, send_cmd, cmd, 8'h47, {tag, "_G"});
  wait_pwr_up(clk, pwr_up, 1'b1, tag);
  wait_en_steer(clk, en_steer, 1'b1, tag);
  $display("[%0t] %s: rider engaged and system powered", $time, tag);
endtask

task automatic startup_test(
  ref logic clk,
  ref logic pwr_up,
  ref logic en_steer,
  ref logic rider_off,
  ref logic piezo
);
  $display("[%0t] ---- Startup test ----", $time);
  wait_cycles(clk, 2000);
  if (pwr_up !== 1'b0) begin
    $display("[Startup] pwr_up should be low after reset");
    $stop;
  end
  if (en_steer !== 1'b0) begin
    $display("[Startup] en_steer should be low after reset");
    $stop;
  end
  if (rider_off !== 1'b1) begin
    $display("[Startup] rider_off should be high after reset");
    $stop;
  end
  if (piezo !== 1'b0) begin
    $display("[Startup] piezo should be idle after reset");
    $stop;
  end
  $display("[%0t] Startup test passed", $time);
endtask

task automatic step_on_test(
  ref logic clk,
  ref logic [11:0] ld_cell_lft,
  ref logic [11:0] ld_cell_rght,
  ref logic [11:0] steer_pot,
  ref logic signed [15:0] rider_lean,
  ref logic cmd_sent,
  ref logic send_cmd,
  ref logic [7:0] cmd,
  ref logic pwr_up,
  ref logic en_steer,
  ref logic rider_off
);
  $display("[%0t] ---- Step on test ----", $time);
  power_up_with_rider(clk, ld_cell_lft, ld_cell_rght, steer_pot, rider_lean,
                      cmd_sent, send_cmd, cmd, pwr_up, en_steer, rider_off, "StepOn");
  $display("[%0t] Step on test passed", $time);
endtask

task automatic rider_off_test(
  ref logic clk,
  ref logic [11:0] ld_cell_lft,
  ref logic [11:0] ld_cell_rght,
  ref logic pwr_up,
  ref logic en_steer,
  ref logic rider_off
);
  $display("[%0t] ---- Rider off test ----", $time);
  ld_cell_lft = 12'h020;
  ld_cell_rght = 12'h020;
  wait_rider_off(clk, rider_off, 1'b1, "RiderOff");
  wait_en_steer(clk, en_steer, 1'b0, "RiderOff");
  wait_pwr_up(clk, pwr_up, 1'b0, "RiderOff");
  $display("[%0t] Rider off test passed", $time);
endtask

task automatic piezo_test(
  ref logic clk,
  ref logic [11:0] ld_cell_lft,
  ref logic [11:0] ld_cell_rght,
  ref logic [11:0] steer_pot,
  ref logic signed [15:0] rider_lean,
  ref logic cmd_sent,
  ref logic send_cmd,
  ref logic [7:0] cmd,
  ref logic [11:0] batt,
  ref logic pwr_up,
  ref logic en_steer,
  ref logic rider_off,
  ref logic batt_low,
  ref logic piezo
);
  $display("[%0t] ---- Piezo test ----", $time);
  power_up_with_rider(clk, ld_cell_lft, ld_cell_rght, steer_pot, rider_lean,
                      cmd_sent, send_cmd, cmd, pwr_up, en_steer, rider_off, "Piezo");
  batt = 12'h700;
  wait_batt_low(clk, batt_low, 1'b1, "Piezo_low_batt");
  wait_piezo_active(clk, piezo, PIEZO_TIMEOUT, "Piezo_low_batt_active");
  batt = 12'h900;
  wait_batt_low(clk, batt_low, 1'b0, "Piezo_recover");
  wait_piezo_idle(clk, piezo, PIEZO_TIMEOUT, 10_000, "Piezo_recover_idle");
  batt = 12'hC00;
  wait_batt_low(clk, batt_low, 1'b0, "Piezo_recover");
  wait_piezo_idle(clk, piezo, PIEZO_TIMEOUT, 10_000, "Piezo_recover_idle2");
  $display("[%0t] Piezo test passed", $time);
endtask

task automatic disconnection_test(
  ref logic clk,
  ref logic [11:0] ld_cell_lft,
  ref logic [11:0] ld_cell_rght,
  ref logic cmd_sent,
  ref logic send_cmd,
  ref logic [7:0] cmd,
  ref logic pwr_up,
  ref logic en_steer,
  ref logic rider_off
);
  $display("[%0t] ---- Disconnection test ----", $time);
  wait_rider_off(clk, rider_off, 1'b0, "Disconnect_pre");
  wait_pwr_up(clk, pwr_up, 1'b1, "Disconnect_pre");
  send_uart_byte(clk, cmd_sent, send_cmd, cmd, 8'h53, "Disconnect_S");
  repeat (50_000) begin
    @(posedge clk);
    if (pwr_up !== 1'b1) begin
      $display("[%0t] [Disconnection] pwr_up dropped before rider stepped off", $time);
      $stop;
    end
  end
  ld_cell_lft = 12'h010;
  ld_cell_rght = 12'h010;
  wait_rider_off(clk, rider_off, 1'b1, "Disconnect_post");
  wait_pwr_up(clk, pwr_up, 1'b0, "Disconnect_post");
  wait_en_steer(clk, en_steer, 1'b0, "Disconnect_post");
  $display("[%0t] Disconnection test passed", $time);
endtask


endpackage