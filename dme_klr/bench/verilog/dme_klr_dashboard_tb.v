// ============================================================
//  dme_klr_dashboard_tb.v  —  DME 951 + KLR combined testbench
//
//  Signal interconnect:
//    DME A_1_tach_pulse  → KLR ext_ign     (DME tach → KLR, inverted)
//    DME A_5_KLR_ign_out → KLR ext_trigger (DME ign out → KLR, inverted)
//    KLR ign_out         → (not connected to DME — spark output, not key switch)
//    KLR full_load       → DME full_load   (WOT flag → DME TPS ch6)
//    DME afm_wiper      → KLR tps_wiper   (TPS angle ch7)
//    DME ref_rpm        → KLR rpm_in      (RPM, only used by -DBOOST)
//    DME clk/tdc/speed_sensor → KLR dme_clk/tdc/speed_sensor
//                        (drives KLR's internal knock_signal_generator —
//                         see klr_tb.v / klr_knock_gen.v)
//
//  Snapshot format (every DASH_INTERVAL_MS, latched to DME clock):
//    [DS]  <ms>,<256hex_dme_iram>,<p1p2p3>,<rpm>
//    KLR: [DS] <ms>,<256hex_klr_ram>,<p1p2>,<ign><ignout><fl>
// ============================================================

`include "timescale.v"

`ifndef DASH_INTERVAL_MS
  `define DASH_INTERVAL_MS 100
`endif

`define DME_KLR_MS ($time / 1_000_000)

module dme_klr_dashboard_tb;

    // ── Interconnect ──────────────────────────────────────────
    wire tach_dme_to_klr;     // DME A_1_tach_pulse  (active-high)
    wire ign_out_dme_to_klr;  // DME A_5_KLR_ign_out (active-high)
    wire klr_ign_out;         // KLR spark output (NOT connected to DME ign)
    wire full_load_klr;        // KLR's own computed full_load output — see
                                // TEST_KLR_FULL_LOAD_STUCK_LOW override below,
                                // which feeds full_load (what the DME
                                // actually sees) from this instead of
                                // connecting it directly.
    wire full_load;            // KLR full_load → DME TPS ch6
    wire tdc;                  // DME crank-model TDC marker (see
                                // var_interrupt_generator/_cl) — not
                                // connected to the KLR, exposed for
                                // observation/logging at this top level
    // TPS angle: DME AFM wiper → KLR TPS angle ch7
    // TPS supply is fixed 201 in klr_tb (5V regulated, independent of battery)
    wire [7:0] tps_wiper_sig;
`ifdef LIVE
    // ── Live-debugger inputs ──────────────────────────────────
    // Written between evals by dme_klr/live/sim_main.cpp when the web UI
    // changes a control; read by the DME/KLR sub-testbenches under LIVE.
    // The engine runs on the closed-loop model (CL_MODE + AFM_CL_RAMP):
    // live_tps is the driver's throttle; AFM follows it ~250 ms later,
    // the firmware fuels for that airflow and RPM comes out of the
    // torque balance in var_interrupt_gen_cl.v. 16'hFFFF on live_rpm /
    // live_afm / live_boost means "use the model"; any other value pins
    // that signal.
    reg [15:0] live_rpm       /*verilator public_flat_rw*/ = 16'hFFFF;
    reg [15:0] live_afm       /*verilator public_flat_rw*/ = 16'hFFFF;
    reg [7:0]  live_tps       /*verilator public_flat_rw*/ = 8'h28;     // idle throttle
    reg [7:0]  live_coolant   /*verilator public_flat_rw*/ = `_COOLANT_RAW;
    reg [7:0]  live_airtemp   /*verilator public_flat_rw*/ = `_AIRTEMP_RAW;
    reg [7:0]  live_battery   /*verilator public_flat_rw*/ = `_BATTERY;
    reg [7:0]  live_altitude  /*verilator public_flat_rw*/ = `_ALTITUDE;
    reg [7:0]  live_fuel_qual /*verilator public_flat_rw*/ = `_FUEL_QUAL;
    reg [15:0] live_boost     /*verilator public_flat_rw*/ = 16'hFFFF;  // KLR MAP (ch4)
    // Snapshot on demand: sim_main bumps req, the scheduler below emits
    // one DS pair and copies req to ack.
    reg [31:0] live_snap_req  /*verilator public_flat_rw*/ = 32'd0;
    reg [31:0] live_snap_ack  /*verilator public_flat_rd*/ = 32'd0;
    assign tps_wiper_sig = u_dme.afm_wiper;   // throttle after its slew (see i8051_dashboard_tb)

    // Instruction-start trackers for breakpoints, stepping and the PC
    // trace. *_ipc is the address of the opcode most recently fetched and
    // *_icount bumps once per instruction; sim_main watches the count.
    // DME: opcode latch happens at S3P2 (osc_cnt==5) outside cycle 2 and
    // outside interrupt entry — the same condition i8051_core uses.
    // KLR: state 1 of a first machine cycle drives the opcode address.
    reg [15:0] live_dme_ipc    /*verilator public_flat_rd*/ = 16'd0;
    reg [31:0] live_dme_icount /*verilator public_flat_rd*/ = 32'd0;
    reg [15:0] live_klr_ipc    /*verilator public_flat_rd*/ = 16'd0;
    reg [31:0] live_klr_icount /*verilator public_flat_rd*/ = 32'd0;
    always @(posedge u_dme.i8051_top.u_cpu.clk)
        if (u_dme.i8051_top.u_cpu.res_n && u_dme.i8051_top.u_cpu.osc_cnt == 4'd5 &&
            !u_dme.i8051_top.u_cpu.cycle_2 && !u_dme.i8051_top.u_cpu.irq_pending) begin
            live_dme_ipc    <= u_dme.i8051_top.u_cpu.pc;
            live_dme_icount <= live_dme_icount + 32'd1;
        end
    always @(posedge u_klr.top.i8048_core_1.clk)
        if (u_klr.top.i8048_core_1.res_n && u_klr.top.i8048_core_1.state_clk_en &&
            u_klr.top.i8048_core_1.state == 3'd1 && !u_klr.top.i8048_core_1.cycle_2) begin
            live_klr_ipc    <= {4'd0, u_klr.top.i8048_core_1.pc};
            live_klr_icount <= live_klr_icount + 32'd1;
        end

    // Ignition pulse widths for the web UI's engine row and charts:
    // DME A_5 ign out (active-high) and the KLR spark output. Pulses
    // under 100 us are the KLR's wait_ign_2 re-assertion artifacts
    // (see klr_phase_monitor.v) and are skipped.
    time live_dme_ign_rise = 0, live_klr_ign_rise = 0;
    always @(posedge ign_out_dme_to_klr) live_dme_ign_rise = $time;
    always @(negedge ign_out_dme_to_klr)
        if ($time - live_dme_ign_rise >= 100_000)
            $display("SIM: [IGN] dme t_ns=%0d width_ns=%0d", $time, $time - live_dme_ign_rise);
    // Injector: fire_inj drives P1.0 (A_0_inj_driver) low and the T0
    // overflow ISR sets it high again, so the low time is the real pulse.
    time live_inj_fall = 0;
    always @(negedge u_dme.A_0_inj_driver) live_inj_fall = $time;
    always @(posedge u_dme.A_0_inj_driver)
        if (live_inj_fall != 0)
            $display("SIM: [INJ] t_ns=%0d width_ns=%0d", $time, $time - live_inj_fall);
    always @(posedge klr_ign_out) live_klr_ign_rise = $time;
    always @(negedge klr_ign_out)
        if ($time - live_klr_ign_rise >= 100_000)
            $display("SIM: [IGN] klr t_ns=%0d width_ns=%0d", $time, $time - live_klr_ign_rise);
`else
    assign tps_wiper_sig = u_dme.afm_wiper;
`endif

    // ── Always-on FST visibility for the interconnect above ──────────
    // klr_vcd_combined.v (compiled into this build, in files/files_cl)
    // was meant to add these to the FST but its module is never
    // instantiated anywhere, so its dumpvars calls never ran — see the
    // ORPHANED MODULE note at the top of that file. Added here instead,
    // directly in this module (guaranteed to run, since this IS the
    // top-level testbench), so the six DME<->KLR interconnect signals
    // show up in every FST trace regardless of debug flags. One
    // $dumpvars line per signal (not a level-1 sweep of the whole
    // module) so dme_clk and the snapshot-task bookkeeping regs
    // (snapshot_busy, next_snap_ns) stay out of the always-on trace.
    // The DME/KLR sub-testbenches each already set up their own
    // $dumpfile (vcd.v / klr_vcd.v); this only adds more variables to
    // whichever of those opens the file first — no new $dumpfile call
    // needed here.
    initial begin
        $dumpvars(1, tach_dme_to_klr);
        $dumpvars(1, ign_out_dme_to_klr);
        $dumpvars(1, klr_ign_out);
        $dumpvars(1, full_load);
        $dumpvars(1, tdc);
        $dumpvars(1, tps_wiper_sig);
        $dumpvars(1, ext_trigger);
        $dumpvars(1, ext_ign);
    end

    // ── DME sub-TB ───────────────────────────────────────────
    // ign tied high — ignition switch always on.
    // klr_ign_out is the spark output and must NOT drive ign (key switch).
    i8051_dashboard_tb u_dme (
        .ign            ( 1'b1               ),
        .A_1_tach_pulse ( tach_dme_to_klr    ),
        .A_5_KLR_ign_out( ign_out_dme_to_klr ),
        .full_load      ( full_load          ),
        .tdc            ( tdc                )
    );

    wire dme_clk = u_dme.clk;

    // ── ext_trigger / ext_ign wire loss faults ────────────────
    // trigger_in is wired directly to the KLR's CPU /RESET (res_n =
    // ~trigger_in — see klr_top.v header) and ign_in drives T1/INT.
    // Both wires are driven straight through from the DME with no
    // fault-injection point of their own, so — same pattern as
    // KLR_FULL_LOAD_STUCK_LOW below — the generator-driven signal is
    // renamed to _gen and a fault-gated override sits between it and
    // the KLR port.
    //   KLR_TRIGGER_STUCK_HIGH → trigger_in stuck 1 → res_n stuck 0 →
    //     KLR CPU held in permanent reset (never runs again). Real-run
    //     confirmed: no DTC (CPU can't run diagnostic code), but the
    //     DME's own IGN_OUT stops pulsing (a general "KLR not
    //     responding" fail-safe — see cl_ramp_to_3000_KLR_TRIGGER_STUCK_HIGH
    //     in validate_dash_log.py) and full_load reads stuck asserted.
    //   KLR_TRIGGER_STUCK_LOW  → trigger_in stuck 0 (its normal idle
    //     level between pulses) → res_n stuck 1 → the OPPOSITE failure
    //     mode from STUCK_HIGH: the CPU runs continuously and NEVER
    //     gets reset again, so it free-runs forever without ever
    //     re-syncing to TDC — unconfirmed against real hardware yet.
    //   KLR_IGN_IN_STUCK_HIGH  → ign_in stuck 1 → T1/INT frozen high;
    //     the CPU keeps running (trigger_in still resets it each
    //     cycle) but any T1/INT-based timing on the DME ign signal is
    //     lost. Real-run confirmed: full_load/TPS-bucket unaffected,
    //     but the same DME IGN_OUT fail-safe as TRIGGER_STUCK_HIGH
    //     still trips.
    //   KLR_IGN_IN_STUCK_LOW   → ign_in stuck 0 (its normal idle level)
    //     instead — unconfirmed against real hardware yet.
    wire ext_trigger_gen = ~ign_out_dme_to_klr;  // DME A_5_KLR_ign_out → KLR trigger (inverted)
    wire ext_ign_gen     = ~tach_dme_to_klr;     // DME tach → KLR ign (inverted)

`ifdef KLR_TRIGGER_STUCK_HIGH
  `ifndef TRIGGER_LOSS_T_MS
  `define TRIGGER_LOSS_T_MS 3000
  `endif
    wire ext_trigger = (`DME_KLR_MS >= `TRIGGER_LOSS_T_MS) ? 1'b1 : ext_trigger_gen;
`elsif KLR_TRIGGER_STUCK_LOW
  `ifndef TRIGGER_LOSS_T_MS
  `define TRIGGER_LOSS_T_MS 3000
  `endif
    wire ext_trigger = (`DME_KLR_MS >= `TRIGGER_LOSS_T_MS) ? 1'b0 : ext_trigger_gen;
`else
    wire ext_trigger = ext_trigger_gen;
`endif

`ifdef KLR_IGN_IN_STUCK_HIGH
  `ifndef IGN_IN_LOSS_T_MS
  `define IGN_IN_LOSS_T_MS 3000
  `endif
    wire ext_ign = (`DME_KLR_MS >= `IGN_IN_LOSS_T_MS) ? 1'b1 : ext_ign_gen;
`elsif KLR_IGN_IN_STUCK_LOW
  `ifndef IGN_IN_LOSS_T_MS
  `define IGN_IN_LOSS_T_MS 3000
  `endif
    wire ext_ign = (`DME_KLR_MS >= `IGN_IN_LOSS_T_MS) ? 1'b0 : ext_ign_gen;
`else
    wire ext_ign = ext_ign_gen;
`endif

    // ── KLR sub-TB ───────────────────────────────────────────
    // EXT_STIM=1: external trigger/ign signals (not internal generator)
    // Signals are inverted: DME active-high → KLR active-low inputs
    klr_tb #(.EXT_STIM(1)) u_klr (
        .ext_trigger     ( ext_trigger         ),  // DME A_5_KLR_ign_out → KLR trigger (inverted)
        .ext_ign         ( ext_ign             ),  // DME tach → KLR ign (inverted)
        .ign_out         ( klr_ign_out         ),  // KLR spark output → DME ign
        .full_load       ( full_load_klr       ),  // KLR WOT flag → DME
        .tps_wiper   ( tps_wiper_sig       ),  // AFM → KLR TPS angle ch7
        .rpm_in          ( u_dme.ref_rpm       ),  // DME tick-measured RPM (reg [31:0]) → KLR -DBOOST map (unused if -DBOOST undefined)
        .dme_clk         ( dme_clk             ),  // → KLR's knock_signal_generator (crank-synced knock_sensor waveform)
        .tdc             ( tdc                 ),  // → KLR's knock_signal_generator
        .speed_sensor    ( u_dme.speed_sensor  )   // → KLR's knock_signal_generator
    );

    // KLR_FULL_LOAD_STUCK_LOW: the KLR's own full_load computation
    // stays correct internally (its own ram[0x3A]/DTC logic sees
    // whatever real throttle position exists), but the wire actually
    // reaching the DME is stuck low — the WOT indication itself "isn't
    // happening" regardless of real throttle, e.g. a broken P1.5 wire
    // or connector between the two ECUs. Distinct from the KLR-side TPS
    // faults (which make the KLR itself misread throttle position) —
    // here the KLR computes full_load correctly, it just never reaches
    // the DME. No TEST_ prefix, matching the KLR_BATT_LOW/
    // KLR_TPS_SUPPLY_LOW/etc. naming convention for KLR-side fault
    // macros elsewhere in this test suite.
`ifdef KLR_FULL_LOAD_STUCK_LOW
    assign full_load = 1'b0;
`else
    assign full_load = full_load_klr;
`endif

    // ── Snapshot-busy flag ───────────────────────────────────
    reg snapshot_busy;
    initial snapshot_busy = 1'b0;

    // ── Combined snapshot task ───────────────────────────────
    task emit_combined_snapshot;
        integer i;
        begin
            snapshot_busy = 1'b1;

            // ── [DS] — DME 8051 iram (128 bytes) ─────────────
            $write("DME: [DS] %0d,", `DME_KLR_MS);
            for (i = 0; i < 128; i = i + 1)
                $write("%02h", u_dme.i8051_top.u_cpu.iram[i[6:0]]);
            // Source input-only pins from driven *_in signals (not the CPU
            // output latch) so O2 (P1.7:6) and serial (P3.1:0) don't emit X.
            $write(",%02h%02h%02h",
               {u_dme.p1_in[7:6], u_dme.p1[5:0]},
               u_dme.p2,
               {u_dme.p3[7:6], u_dme.t1, u_dme.t0, u_dme.speed_sensor, u_dme.reference_sensor, u_dme.p3_in[1:0]});
	    //$write(",%02h%02h%02h", u_dme.p1, u_dme.p2, u_dme.p3_in);
            $write(",%0d\n", u_dme.ref_rpm);

            // ── KLR: [DS] — 8048 RAM (128 bytes) ─────────────────
            $write("KLR: [DS] %0d,", `DME_KLR_MS);
            for (i = 0; i < 128; i = i + 1)
                $write("%02h", u_klr.top.i8048_core_1.ram[i[6:0]]);
            // TODO: confirm KLR port hierarchy for p1/p2
            $write(",%02h%02h", u_klr.top.p1, u_klr.top.p2);
            // Trailing bit tail — appended, not reordered, so any
            // existing positional readers of the first 3 bits are
            // unaffected. ext_trigger/ext_ign are the actual signals
            // reaching the KLR ports (post fault-injection override,
            // if any — see KLR_TRIGGER_STUCK_HIGH/KLR_IGN_IN_STUCK_HIGH
            // above), unlike tach_dme_to_klr which is the raw DME
            // signal before invert and before any override.
            $write(",%0b%0b%0b%0b%0b\n",
                tach_dme_to_klr,    // ign input to KLR (before invert)
                klr_ign_out,        // KLR ign output
                full_load,          // full load / WOT flag
                ext_trigger,        // KLR trigger_in, post fault-injection override
                ext_ign);           // KLR ign_in, post fault-injection override

            snapshot_busy = 1'b0;
        end
    endtask

    // ── Snapshot scheduler — latched to DME clock ────────────
    reg [63:0] next_snap_ns;
    initial    next_snap_ns = `DASH_INTERVAL_MS * 64'd1_000_000;

    always @(posedge dme_clk) begin
        if ($time >= next_snap_ns) begin
            emit_combined_snapshot;
            next_snap_ns <= next_snap_ns + (`DASH_INTERVAL_MS * 64'd1_000_000);
        end
`ifdef LIVE
        else if (live_snap_req != live_snap_ack)
            emit_combined_snapshot;
        live_snap_ack <= live_snap_req;
`endif
    end

    // Hard simulation boundary — terminates at exactly SIM_TIME.
    // SIM_TIME must be passed via -DSIM_TIME=<ns> from the run script.
    // No default — intentional, so a missing define causes a compile error
    // rather than silently capping a long test at 10s.
`ifndef SIM_TIME
  ERROR_SIM_TIME_must_be_defined  // force compile error if omitted
`endif
    initial begin
        #`SIM_TIME;
        // ── DME memory dumps ──────────────────────────────────
        $writememh("dme_rom_out.hex", u_dme.i8051_top.u_eprom.mem);
        $writememh("dme_ram_out.hex", u_dme.i8051_top.u_cpu.iram);
        // ── KLR memory dumps ──────────────────────────────────
        $writememh("klr_rom_out.hex", u_klr.top.rom_1.rom);
        $writememh("klr_ram_out.hex", u_klr.top.i8048_core_1.ram);
        $finish;
    end

endmodule
