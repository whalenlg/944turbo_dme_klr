// ============================================================
//  KLR 951 Phase Monitor  —  paste into klr_tb module body
//  via `include "klr_phase_monitor.v"
//
//  NOTE: do NOT list this file on the iverilog command line.
//  It is pulled in by `include inside klr_tb, so it compiles
//  within klr_tb's module scope.  Listing it separately causes
//  "Variable declarations must be contained within a module".
//
//  Requires: klr_tb.v wires: clk, ign_out, ign_out_n, full_load, p1_mon, p2_mon
//  knock_out and CV_PWM are declared here from p1_mon/p2_mon.
//
//  Uses top.xxx relative paths for hierarchical RAM/core access.
//  Works in both standalone (klr_tb top) and combined (u_klr nested) modes.
//  Timing uses $time (ns) — avoids clk_count hierarchical scope issues.
//
//  Time display: KLR milliseconds via $time
//    timescale 1ns/1ps  →  $time / 1_000_000 = ms
// ============================================================

// ── KLR RAM convenience macro ─────────────────────────────
`define KLRRAM top.i8048_core_1.ram

// ── ms from $time ────────────────────────────────────────
`define KLR_MS(n) ($time / 1_000_000)

// ── Signals not declared in klr_tb — derived here ────────
// knock_out: P1.6 per KLR hardware mapping (p1_mon available in klr_tb scope)
// CV_PWM: correction-voltage PWM — TODO confirm exact p2_mon bit
wire knock_out = p1_mon[6];
wire CV_PWM    = p2_mon[4];   // TODO: confirm bit — P2.4 placeholder

// ── Previous-value registers for edge detection ───────────
reg        ph_klr_ign_prev;
reg        ph_klr_knock_prev;
reg        ph_klr_fullload_prev;
reg        ph_klr_mb_prev;
reg        ph_klr_mb1_reached;   // latched once — MB1 first entry
reg [11:0] ph_klr_pc_prev;       // previous PC for knock-entry edge detect
reg        ph_klr_ign_in_prev;  // ign_in edge tracker (trigger reference)
reg [63:0] ph_klr_ign_in_time;  // $time(ns) of last ign_in falling edge
reg [63:0] ph_klr_ign_out_time; // $time(ns) of last ign_out assert
reg [63:0] ph_klr_next_snap;
reg        ph_klr_res_n_prev;   // reset-release edge detector
reg  [7:0] ph_klr_knock_sensor_prev; // knock_sensor value tracker (TEST_KNOCK_PULSE)
reg [31:0] ph_klr_knock_count;  // increments on each knock_out 1->0 transition

initial begin
    ph_klr_ign_prev       = 1'b0;
    ph_klr_knock_prev     = 1'b0;
    ph_klr_fullload_prev  = 1'b0;
    ph_klr_mb_prev        = 1'b0;
    ph_klr_mb1_reached    = 1'b0;
    ph_klr_pc_prev        = 12'h000;
    ph_klr_ign_in_prev    = 1'b0;
    ph_klr_ign_in_time    = 64'd0;
    ph_klr_ign_out_time   = 64'd0;
    ph_klr_next_snap      = 64'd10_000_000;  // first snapshot at 10ms ($time ns)
    ph_klr_res_n_prev     = 1'b0;
    ph_klr_knock_sensor_prev = knock_sensor;
    ph_klr_knock_count    = 32'd0;
end

// ── Unified monitor ───────────────────────────────────────
always @(posedge clk) begin  // klr_phase_monitor

    ph_klr_res_n_prev <= top.res_n;

    if (top.res_n === 1'b0) begin
        // Hold prevs during reset
        ph_klr_ign_prev      <= ign_out;
        ph_klr_knock_prev    <= knock_out;
        ph_klr_fullload_prev <= full_load;
        ph_klr_pc_prev       <= top.i8048_core_1.pc;
        ph_klr_ign_in_prev   <= ign_in_mux;
        ph_klr_mb_prev       <= top.i8048_core_1.mb_latch;
    end else if (!ph_klr_res_n_prev && top.res_n) begin
        // Reset just released — sample actual signal values to prevent
        // false edges. vlt inits all regs to 0 so signals may already
        // be non-zero before the firmware runs.
        ph_klr_ign_prev      <= ign_out;
        ph_klr_knock_prev    <= knock_out;
        ph_klr_fullload_prev <= full_load;
        ph_klr_pc_prev       <= top.i8048_core_1.pc;
        ph_klr_ign_in_prev   <= ign_in_mux;
        ph_klr_mb_prev       <= top.i8048_core_1.mb_latch;
    end else begin

        // ── ign_in: track edge (trigger reference for spark-delay calc) ──
        if (ign_in_mux && !ph_klr_ign_in_prev)
            ph_klr_ign_in_time <= $time;
        ph_klr_ign_in_prev <= ign_in_mux;

        // ── ign_out: spark timing with dwell validation ───
        // Minimum real dwell = 1 ms (1_000_000 ns). Pulses shorter than this
        // are wait_ign_2 loop re-assertion artifacts that cannot energise the
        // coil — flagged as spurious, not counted as real sparks.
        if (ign_out && !ph_klr_ign_prev) begin
            ph_klr_ign_out_time <= $time;
            $display("KLR: [PHASE] t=%0d ms  IGN_OUT asserted   delay_from_ign_in=%0d.%03d us",
                     `KLR_MS(0),
                     ($time - ph_klr_ign_in_time) / 1000,
                     ($time - ph_klr_ign_in_time) % 1000);
        end
        if (!ign_out && ph_klr_ign_prev) begin
            if (($time - ph_klr_ign_out_time) >= 64'd1_000_000)
                $display("KLR: [PHASE] t=%0d ms  IGN_OUT deasserted pulse_width=%0d.%03d ms",
                         `KLR_MS(0),
                         ($time - ph_klr_ign_out_time) / 1_000_000,
                         (($time - ph_klr_ign_out_time) % 1_000_000) / 1000);
            else
                $display("KLR: [PHASE] t=%0d ms  IGN_OUT spurious pulse filtered  (width=%0d ns — wait_ign_2 artifact)",
                         `KLR_MS(0),
                         ($time - ph_klr_ign_out_time));
        end
        ph_klr_ign_prev <= ign_out;

        // ── knock_out: knock detected ─────────────────────
        if (knock_out && !ph_klr_knock_prev)
            $display("KLR: [PHASE] t=%0d ms  KNOCK_OUT asserted  (knock event detected — P1.6)",
                     `KLR_MS(0));
        if (!knock_out && ph_klr_knock_prev) begin
            $display("KLR: [PHASE] t=%0d ms  KNOCK_OUT cleared   (knock window closed)",
                     `KLR_MS(0));
            ph_klr_knock_count <= ph_klr_knock_count + 32'd1;
        end
        ph_klr_knock_prev <= knock_out;

        // ── knock_sensor: value change (TEST_KNOCK_PULSE) ─────
        // Edge-detected rather than a fixed-delay $display in klr_tb.v
        // itself, so this reports the actual transition regardless of
        // exactly when/how the testbench drives it — no timing values
        // to keep in sync between two files. "dropping"/"restoring"
        // wording matches what validate_dash_log.py's expect_knock_pulse
        // check searches for; outside TEST_KNOCK_PULSE, knock_sensor is
        // a constant wire and this simply never fires.
        if (knock_sensor != ph_klr_knock_sensor_prev) begin
            if (knock_sensor < ph_klr_knock_sensor_prev)
                $display("KLR: [PHASE] t=%0d ms  Knock pulse: dropping knock_sensor %0d -> %0d",
                         `KLR_MS(0), ph_klr_knock_sensor_prev, knock_sensor);
            else
                $display("KLR: [PHASE] t=%0d ms  Knock pulse: restoring knock_sensor %0d -> %0d",
                         `KLR_MS(0), ph_klr_knock_sensor_prev, knock_sensor);
        end
        ph_klr_knock_sensor_prev <= knock_sensor;

        // ── knock logic execution (PC enters knock map axis read @0x900) ──
        // Edge-detected on PC so we log once per entry, not every clock the
        // CPU sits at 0x900. 0x900 = load_axis_hi_read (knock timing-map lookup).
        if ((top.i8048_core_1.pc == 12'h900) && (ph_klr_pc_prev != 12'h900))
            $display("KLR: [PHASE] t=%0d ms  KNOCK_LOGIC exec   (knock map axis read @0x900)",
                     `KLR_MS(0));
        ph_klr_pc_prev <= top.i8048_core_1.pc;

        // ── full_load: WOT engaged ────────────────────────
        if (full_load && !ph_klr_fullload_prev)
            $display("KLR: [PHASE] t=%0d ms  FULL_LOAD set       (WOT — P1.5 high)",
                     `KLR_MS(0));
        if (!full_load && ph_klr_fullload_prev)
            $display("KLR: [PHASE] t=%0d ms  FULL_LOAD cleared   (part-throttle)",
                     `KLR_MS(0));
        ph_klr_fullload_prev <= full_load;

        // ── mb_latch: bank switch ─────────────────────────
        if (top.i8048_core_1.mb_latch && !ph_klr_mb_prev) begin
            //$display("KLR: [PHASE] t=%0d ms  SEL MB1             (housekeeping bank selected)",
            //         `KLR_MS(0));
            if (!ph_klr_mb1_reached) begin
                ph_klr_mb1_reached <= 1'b1;
                $display("KLR: [PHASE] t=%0d ms  MB1 FIRST ENTRY     (housekeeping loop starting)",
                         `KLR_MS(0));
            end
        end
        if (!top.i8048_core_1.mb_latch && ph_klr_mb_prev)
        //    $display("KLR: [PHASE] t=%0d ms  SEL MB0             (main loop bank selected)",
        //             `KLR_MS(0));
        ph_klr_mb_prev <= top.i8048_core_1.mb_latch;

        // ── Periodic STATUS snapshot ──────────────────────
        // Every ~100ms KLR time (≈1,111,100 half-cycles)
        if ($time >= ph_klr_next_snap) begin
            $display("KLR: [STATUS] t=%0d ms  pc=%03h  mb=%0b  SP=%0d  irq=%0b  ign_out=%0b  knock=%0b  full_load=%0b  CV_PWM=%0b  tps_raw=%02h  tps_deg=%02h  R0=%02h  R2=%02h  R4=%02h  R5=%02h  ram[16]=%02h  ram[17]=%02h  ram[26]=%02h  ram[33]=%02h  ram[38]=%02h  knock_count=%0d  timer_val=%02h",
                `KLR_MS(0),
                top.i8048_core_1.pc,
                top.i8048_core_1.mb_latch,
                top.i8048_core_1.psw[2:0],
                top.i8048_core_1.irq_in_progress,
                ign_out,
                knock_out,
                full_load,
                CV_PWM,
                `KLRRAM[8'h3C],  // tps_raw — throttle raw wiper (ram[3Ch])
                `KLRRAM[8'h3A],  // tps_deg — throttle degrees processed (ram[3Ah])
                `KLRRAM[8'h00],  // R0 bank0 — ISR context pointer
                `KLRRAM[8'h02],  // R2 bank0 — retard counter
                `KLRRAM[8'h04],  // R4 bank0 — slow tick / ADC dispatch
                `KLRRAM[8'h05],  // R5 bank0 — CV PWM reload
                `KLRRAM[8'h16],  // MB1 jump target low byte
                `KLRRAM[8'h17],  // MB1 jump target high byte (0x08=MB1)
                `KLRRAM[8'h26],  // retard accumulator
                `KLRRAM[8'h33],  // should stay 0 once initialised — see validate_dash_log.py
                `KLRRAM[8'h38],  // timer ISR A-save area
                ph_klr_knock_count,  // testbench-side count of knock_out 1->0 transitions
                top.i8048_core_1.timer_val
            );
            ph_klr_next_snap <= ph_klr_next_snap + 64'd100_000_000;  // +100ms
            $fflush();
        end

    end // res_n

end // always klr_phase_monitor
