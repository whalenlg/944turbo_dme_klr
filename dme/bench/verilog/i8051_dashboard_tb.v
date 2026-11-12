`include "timescale.v"

// ============================================================
//  i8051_dashboard_tb.v  —  89 DME 951 Dashboard Testbench
//
//  Emits compact [DS] snapshot lines covering ALL 128 iram bytes +
//  P1/P2/P3, readable by the React dashboard, plus inlined PHASE
//  event lines (see the PHASE MONITOR section below) so the
//  dashboard Phase tab works from this file alone.
//
//  Compile (example — same flags as i8051_dashboard_tb.v):
//    iverilog -o dash.vvp \
//      -f files \
//      -I rtl/verilog -I bench/verilog \
//      -s i8051_dashboard_tb \
//      -DTEST_WARM_IDLE \
//      i8051_dashboard_tb.v
//
//    vvp dash.vvp > warm_idle.ds.log
//
//  Log format — one line per DASH_INTERVAL_MS:
//    [DS] <time_ms>,<256hex_iram>,<p1hex><p2hex><p3hex>
//
//  DASH_INTERVAL_MS default: 100  (override with -DDASH_INTERVAL_MS=50)
// ============================================================

// The test selection and per-test options: see test_opts.vh
`include "test_opts.vh"

// ============================================================
//  Clock constants
// ============================================================
`ifndef RPMCONST
  `define RPMCONST (60 * 1000 * `DME_FREQ / 132)  // posedge-clk per RPM unit per tooth
  // 132 = flywheel teeth; period_current = RPMCONST/RPM = clk events per tooth at that RPM
  // ref_period (one revolution) = 132 × period_current → ref_rpm = (132×RPMCONST)/ref_period
`endif
`define DME_FREQ  6000    // DME 8051 clock half-periods per ms (6 MHz)

`ifdef DME_KLR_COMBINED
  `define DME_MS  ($time / 1_000_000)   // wall-clock ms — avoids KLR clock freq bleed
`else
  `define DME_MS  (i8051_dashboard_tb.i8051_top.u_cpu.cycle_count / `DME_FREQ)
`endif

module i8051_dashboard_tb (
    // External I/O signals
    input  wire ign,              // Ignition switch input
    output wire A_1_tach_pulse,   // Tachometer output (P1.1)
    output wire A_5_KLR_ign_out,  // KLR / ignition coil primary (P1.5)
    input  wire full_load,        // Full-load (WOT) switch from KLR → ADC ch6 / TPS
    output wire tdc               // Top Dead Center marker (crank model —
                                   // see var_interrupt_generator/_cl). Driven
                                   // 0 when RPMRAMP/CL_MODE crank models
                                   // aren't in use (plain interrupt_generator
                                   // or NOINT builds have no TDC concept).
);

`ifndef FRQ_SCALE
  `define FRQ_SCALE  500000   // half-period scale (ns × kHz); DELAY = FRQ_SCALE/FREQ
`endif
parameter DELAY = `FRQ_SCALE / `DME_FREQ;

// ─── Clocks & reset ─────────────────────────────────────────
reg  rst, clk;

// ─── I/O ports ──────────────────────────────────────────────
reg  [7:0] p0_in, p1_in, p2_in, p3_in;
wire [7:0] p0, p1, p2, p3;

// Initialise all port inputs to safe defaults at t=0 so the firmware
// never sees X on any pin — especially T0 (P3.4) and T1 (P3.5) which
// are 8051 timer/counter inputs.  Open-collector 8051 port pins idle
// high, so unused inputs are driven 1'b1.
initial begin
    p0_in = 8'hFF;
    p1_in = 8'hFF;
    p2_in = 8'hFF;
    // P3 specific safe state:
    //   [7:6] unused            — 1
    //   [5]   T1 (timer input)  — 1 (idle/inactive)
    //   [4]   T0 (timer input)  — 1 (idle/inactive)
    //   [3]   speed_sensor      — 1 (no tooth)
    //   [2]   reference_sensor  — 1 (no ref pulse)
    //   [1]   TXD/int_uart      — 1
    //   [0]   RXD/bit_out       — 1
    p3_in = 8'hFF;
end

// ─── Misc wires (match i8051_dashboard_tb.v declarations) ─────────────
wire [15:0] ext_addr;
wire        write, write_uart;
wire        rxd, int_uart, bit_out;
wire        reference_sensor, speed_sensor;
wire        reference_sensor_gen;   // generator's raw pulse output — see
                                     // TEST_REF_SENSOR_LOSS override below,
                                     // which feeds reference_sensor from this
                                     // instead of driving it directly.
wire        speed_sensor_gen;       // generator's raw pulse output — see
                                     // TEST_SPEED_SENSOR_LOSS override below,
                                     // which feeds speed_sensor from this
                                     // instead of driving it directly.
wire        tdc_marker;   // drives the tdc output port
assign      tdc = tdc_marker;
// T0 (P3.4) and T1 (P3.5) are separate top-level ports on i8051_top —
// not derived from p3_in. Must be driven explicitly or the timer module
// sees X and MOV C,bitaddr reads of port-derived bits are corrupted.
// T0: firmware uses as has-cat flag (0 = cat fitted). Drive low.
// T1: AC compressor status input. 0=off (default), 1=on.
//     Override with -DAC_COMP_ON for always-on, or -DCL_AC_HALFWAY
//     for mid-simulation switch (fires at SIM_TIME/2).
`ifdef LIVE
// Live debugger / log replay: the live panel's AC switch
wire t1;
assign t1 = dme_klr_dashboard_tb.live_ac[0];
`else
// CL_AC_HALFWAY: AC on at SIM_TIME/2. CL_CONDITION_CYCLE_ACTIVE: an AC
// phase whose timing depends on the variant (the idle version starts
// phases much sooner since there's no ramp to wait through, see the
// schedule in test_opts.vh). AC_COMP_ON: always on. Otherwise off.
reg t1_sched;
initial begin
    t1_sched = 1'b0;            // nominal (AC off)
    if (`OPT_CL_AC_HALFWAY) begin
        // 64'd2 keeps the division 64-bit: with a bare 2, Verilator 5.050
        // sizes SIM_TIME (e.g. 20000000000) to its 35 bits as a signed value,
        // so SIM_TIME / 2 came out negative and t1 never switched on
        #(`VAL_SIM_TIME / 64'd2);   // switch AC on halfway through simulation
        t1_sched = 1'b1;
    end else if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
        if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
            #(64'd30_000_000_000);  // t=30s
        else
            #(64'd59_000_000_000);  // t=59s
        t1_sched = 1'b1;            // AC on
        #(64'd5_000_000_000);       // 5s later
        t1_sched = 1'b0;            // back to nominal
    end
end
wire t1;
assign t1 = (`OPT_AC_COMP_ON && !`OPT_CL_AC_HALFWAY && !`OPT_CL_CONDITION_CYCLE_ACTIVE)
            ? 1'b1 : t1_sched;  // T1 = AC compressor active
`endif

// CL_CONDITION_CYCLE_ACTIVE: a cat phase (timing as for the AC phase
// above). Otherwise T0 = has catalytic converter (0 = fitted).
reg t0;
initial begin
    t0 = 1'b0;                  // nominal (has cat)
    if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
        if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
            #(64'd23_000_000_000);  // t=23s
        else
            #(64'd52_000_000_000);  // t=52s
        t0 = 1'b1;                  // no cat
        #(64'd5_000_000_000);       // 5s later
        t0 = 1'b0;                  // back to nominal
    end
end
wire        stb_o, ack_i, ack_uart;
wire        cyc_o, iack_i, istb_o, icyc_o;
wire [7:0]  data_in, data_out, data_out_uart;
wire        o2_6, o2_7;
wire [15:0] addr_bus;
wire [15:0] xaddr;
wire [7:0]  xdata;
reg [7:0] diag_data,diag_addr;
reg  [7:0]  xdata_in;
wire [7:0]  adc_data, xadc_data_out, adc_data_out;
wire        ale, txd;
wire        xrd_n, xwr_n;

// ─── P1 signal aliases — A_1_tach_pulse and A_5_KLR_ign_out are module ports
wire A_0_inj_driver;
wire A_2_dme_relay;
wire A_3_unused_p1_3;
wire A_4_idle_speed;

assign A_0_inj_driver  = p1[0];
assign A_1_tach_pulse  = p1[1];  // module output port
assign A_2_dme_relay   = p1[2];
assign A_3_unused_p1_3 = p1[3];
assign A_4_idle_speed  = p1[4];

// ── ISV (idle speed valve, P1.4) duty, sim only: the share of each PWM period the pin is high,
// in %, updated at every rising edge (high = open, as the replay's
// icv_pct and CL_ISV_AIR count it). A pin that hasn't moved for 100 ms
// reads 0 or 100. Dumped in every VCD/FST (vcd.v / klr_vcd.v).
real     isv_duty_pct = 0.0;
realtime isv_duty_pct_rise = 0, isv_duty_pct_fall = 0, isv_duty_pct_edge = 0;
always @(posedge A_4_idle_speed) begin
    if (isv_duty_pct_rise > 0)
        isv_duty_pct = isv_duty_pct_fall > isv_duty_pct_rise
                 ? 100.0 * (isv_duty_pct_fall - isv_duty_pct_rise) / ($realtime - isv_duty_pct_rise) : 100.0;
    isv_duty_pct_rise = $realtime;
    isv_duty_pct_edge = $realtime;
end
always @(negedge A_4_idle_speed) begin
    isv_duty_pct_fall = $realtime;
    isv_duty_pct_edge = $realtime;
end
always #10_000_000
    if ($realtime - isv_duty_pct_edge > 100_000_000) isv_duty_pct = (A_4_idle_speed === 1'b1) ? 100.0 : 0.0;
assign A_5_KLR_ign_out = p1[5];  // module output port

// ─── VCD dump ───────────────────────────────────────────────
dumpvcd u_dumpvcd(.clk(clk), .pc(`TB.i8051_top.u_cpu.pc));

// ─── DUT ────────────────────────────────────────────────────
i8051_system  i8051_top (
    .res_n   ( rst              ),
    .clk     ( clk              ),
    .int0_n  ( reference_sensor ),
    .int1_n  ( speed_sensor     ),
    .p0      ( p0               ),
    .p0_in   ( p0_in            ),
    .p1      ( p1               ),
    .p1_in   ( p1_in            ),
    .p2      ( p2               ),
    .p2_in   ( p2_in            ),
    .p3      ( p3               ),
    .p3_in   ( p3_in            ),
    .rxd     ( rxd              ),
    .txd     ( txd              ),
    .t0      ( t0               ),
    .t1      ( t1               ),
    .ale     ( ale              ),
    .xdata   ( xdata            ),
    .xaddr   ( xaddr            ),
    .xrd_n   ( xrd_n            ),
    .xwr_n   ( xwr_n            )
);

// ─── Dynamic coolant warmup ───────────────────────────────────
// Active for: TEST_ISV_COLD_IDLE, TEST_COLD_START, TEST_CL_COLD_START
// NTC inverse: lower raw = hotter. Ramps from starting temp to 0x20 (~80°C).
// ISV_COLD_IDLE : 0x68 (~5°C) → 0x20 over 50s  @ 4,166,667 clk/step
// COLD_START    : 0x68 (~5°C) → 0x20 over 100s @ 3,750,000 clk/step
// CL_COLD_START : 0x68 (~5°C) → 0x20 over 100s @ 3,750,000 clk/step
// COLD_START/CL_COLD_START previously started at 0xC0 (~52°C) — far too
// warm for a genuine cold start; changed to match ISV_COLD_IDLE's ~5°C.
// Tick rate (ramp speed) unchanged — only the starting value moved.
reg [7:0]  coolant_dynamic;
reg [31:0] coolant_tick;
wire       coolant_warmup_on = `OPT_TEST_ISV_COLD_IDLE || `OPT_TEST_COLD_START || `OPT_TEST_CL_COLD_START;
wire [31:0] coolant_tick_max = `OPT_TEST_ISV_COLD_IDLE ? 32'd4_166_667 : 32'd3_750_000;
initial begin coolant_dynamic=8'h68; coolant_tick=32'd0; end
always @(posedge clk) if (coolant_warmup_on) begin : coolant_warmup
    if (!rst) begin coolant_dynamic<=8'h68; coolant_tick<=32'd0;
    end else if (coolant_dynamic>8'h20) begin
        if (coolant_tick>=coolant_tick_max) begin
            coolant_dynamic<=coolant_dynamic-8'h01; coolant_tick<=32'd0;
        end else coolant_tick<=coolant_tick+32'd1;
    end
end

// ─── Condition-cycle dynamic signals (CL_CONDITION_CYCLE_ACTIVE) ─
// Air temp, coolant temp, altitude, and battery voltage each get
// their own timed step-and-revert sequence here; T0 (cat) and T1 (AC)
// are handled near their own existing declarations above, following
// the same schedule. Shared by TEST_CL_CONDITION_CYCLE (ramped to
// 3000rpm) and TEST_CL_CONDITION_CYCLE_IDLE (held at idle) — see both
// compile-flag blocks near the top of the file for their respective
// full phase timelines; only the delay before each phase starts
// differs between them (idle has no ~25-30s ramp to wait through
// first). Values reused from existing precedent: 0x68 (~5C) matches
// TEST_ISV_COLD_IDLE's cold value; 0x00 altitude matches
// TEST_IDLE_HIGH_ALT; 0xAD battery is ~20% below the 0xD8 nominal
// used everywhere else (see TEST_IDLE_BATTERY_LOW's own lower
// `_BATTERY value for comparison — that one isn't percentage-based).
// (only CL_CONDITION_CYCLE_ACTIVE runs the phases)
// Air temp phase.
reg [7:0] airtemp_dynamic_cycle;
initial begin
    airtemp_dynamic_cycle = 8'h50;   // nominal
    if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
        if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
            #(64'd2_000_000_000);  // t=2s
        else
            #(64'd31_000_000_000);  // t=31s
        airtemp_dynamic_cycle = 8'h68;   // cold (~5C)
        #(64'd5_000_000_000);                // 5s later
        airtemp_dynamic_cycle = 8'h50;   // back to nominal
    end
end

// Coolant temp phase.
reg [7:0] coolant_dynamic_cycle;
initial begin
    coolant_dynamic_cycle = 8'h20;   // nominal (warm)
    if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
        if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
            #(64'd9_000_000_000);  // t=9s
        else
            #(64'd38_000_000_000);  // t=38s
        coolant_dynamic_cycle = 8'h68;   // cold (~5C)
        #(64'd5_000_000_000);                // 5s later
        coolant_dynamic_cycle = 8'h20;   // back to nominal
    end
end

// Altitude phase.
reg [7:0] altitude_dynamic_cycle;
initial begin
    altitude_dynamic_cycle = 8'hF8;  // nominal (sea level)
    if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
        if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
            #(64'd16_000_000_000);  // t=16s
        else
            #(64'd45_000_000_000);  // t=45s
        altitude_dynamic_cycle = 8'h00;  // high altitude
        #(64'd5_000_000_000);                // 5s later
        altitude_dynamic_cycle = 8'hF8;  // back to nominal
    end
end

// Battery voltage phase. 0xAD is ~20% below nominal 0xD8
// (216 * 0.8 = 172.8 -> 173 = 0xAD), a straight raw-ADC-count
// reduction — same convention as TEST_IDLE_BATTERY_LOW's own
// lower `_BATTERY value, just calibrated to a specific percentage
// instead of a fixed constant.
reg [7:0] battery_dynamic_cycle;
initial begin
    battery_dynamic_cycle = 8'hD8;   // nominal
    if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
        if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
            #(64'd37_000_000_000);  // t=37s
        else
            #(64'd66_000_000_000);  // t=66s
        battery_dynamic_cycle = 8'hAD;   // reduced ~20%
        #(64'd5_000_000_000);                // 5s later
        battery_dynamic_cycle = 8'hD8;   // back to nominal
    end
end

// ─── Tippy-in AFM step override ─────────────────────────────// iram[53h] is updated by the ADC scan every crank cycle — so a
// free-running step always finds delta=0 by the time airflow_calc runs.
// Fix: spike AFM ON the reference sensor rising edge. The ADC scan
// has just finished (iram[53h] = 0x28). The spike makes iram[10h]=0x78
// BEFORE airflow_calc reads it, creating delta=0x50 within the same
// crank event. Spike held for 2 seconds (~28 crank cycles at 840 RPM)
// to simulate a realistic sustained throttle opening.
reg [7:0]  afm_tippy;
reg [7:0]  tippy_crank_count;
reg        tippy_fired;

initial begin
    afm_tippy         = 8'h28;
    tippy_crank_count = 8'd0;
    tippy_fired       = 1'b0;
end

// Skip the t=0 edge: the generator's initial block sets int_0 to 1 at
// t=0, and whether that first 0/X->1 step counts as a posedge differs
// between simulators. Counting it put the tippy one crank (70 ms at
// 840 RPM) earlier in the Verilator run of cl_tippy_in than in the
// Icarus one (step at 1840 vs 1910 ms with identical RPM up to then).
always @(posedge reference_sensor) if (`OPT_AFM_TIPPY && $time != 0) begin
    if (!tippy_fired) begin
        tippy_crank_count <= tippy_crank_count + 8'd1;
        // Fire at crank #25 — well past fuel cut end (~15 cranks at 840 RPM)
        if (tippy_crank_count == 8'd25) begin
            afm_tippy   <= 8'h78;   // large step: +80 counts over idle
            tippy_fired <= 1'b1;
        end
    end else begin
        // Hold for ~28 more crank pulses (~2 seconds at 840 RPM), then return
        tippy_crank_count <= tippy_crank_count + 8'd1;
        if (tippy_crank_count >= 8'd53)   // 25 + 28 = 53
            afm_tippy <= 8'h28;
    end
end

// ─── CL ramp AFM/TPS override ─────────────────────────────────
// Driver-commanded throttle event at t=2000ms (past fuel cut/ASE):
// TPS (afm_wiper) ramps toward the commanded target at a FIXED
// per-count rate (~1.42ms/count, matching the 6000-family's
// original cadence — see STEP_NS below for why this is fixed
// rather than scaled per-target). AFM (afm_cl) gets its OWN
// identical ramp, triggered on an ADDITIONAL ~250ms delay (airflow
// reacting to the throttle change) — so AFM's whole trajectory is
// TPS's trajectory, time-shifted ~250ms later, not AFM chasing
// TPS's live value at matching speed (that only ever falls ~1 step
// behind, since a same-speed follower starting from equal position
// never accumulates real separation from a moving target — verified
// this doesn't produce a meaningful lag before settling on the
// time-shifted-trigger approach instead). This replaces the old
// instant-step-to-AFM_CL_TARGET behavior for BOTH signals.
//
// Target is `AFM_CL_TARGET — the SAME per-test macro already used by
// every CL ramp test (0x72 for 3000rpm, 0xD8 for the 6000-family
// after the fix above, 0xEB for redline) — not a new hardcoded
// value, so cl_ramp_to_3000 and cl_ramp_to_redline are completely
// unaffected by this change; only the 6000-family's target actually
// moved (via the `define change above).
//
// The per-count rate (STEP_NS) is now FIXED across every target,
// not scaled to force a fixed total ramp time — total ramp time
// instead varies with each target's range (~105ms for the
// 3000-family, ~250ms for 6000, ~277ms for redline). Originally
// every target was scaled to complete in exactly 250ms, which meant
// the 3000-family's smaller range (74 counts) used ~2.4x coarser
// step spacing than the 6000-family's (176 counts) to hit that same
// total time. That coarser command-update cadence was suspected of
// disturbing the 3000-family's RPM convergence (noisier steady-state
// RPM, and a lost timing-retard differentiation that traced back
// through timing_adv_next to an RPM/load-dependent shift, not a
// direct bug) — while the 6000-family's finer cadence stayed
// unaffected, matching old vs new comparisons for that family being
// nearly identical. The fixed-rate values here are still not exact
// data — adjust STEP_NS/AFM_LAG_NS if you have real numbers.
//
// Scope: AFM_CL_RAMP only — every other mode (default/idle,
// AFM_TIPPY, AFM_FAULT) is unaffected; afm_wiper there still comes
// straight from the crpm-based generator curve, unchanged.
// (Always built; its clocked parts run only under AFM_CL_RAMP.)
    // Per-count ramp step rate — fixed (matches the 6000-family's original
    // 250ms/176-count cadence) rather than scaled per-target, so total
    // ramp time varies with each target's range instead of being forced
    // to a fixed 250ms. A fixed 250ms total forced the 3000-family's ramp
    // (a smaller range, 74 counts) to use ~2.4x coarser step spacing than
    // the 6000-family's (176 counts) to hit the same total time —
    // suspected of disturbing that family's RPM convergence. Fixed rate
    // keeps every family's command-update cadence identical instead.
    //
    // Overridable via -DAFM_CL_STEP_NS on the iverilog/verilator command
    // line (e.g. to slow specific test variants down without touching the
    // default used by every other CL test) — defaults to the fixed rate
    // below when not overridden.
    `ifndef AFM_CL_STEP_NS
      `define AFM_CL_STEP_NS 1_420_454
    `endif
    `ifndef AFM_CL_TARGET               // set by every AFM_CL_RAMP test;
      `define AFM_CL_TARGET 8'h28       // idle for the others (unused there)
    `endif
    wire       [63:0]       STEP_NS        = `VAL_AFM_CL_STEP_NS;
    localparam integer      AFM_LAG_NS     = 250_000_000;            // additional AFM reaction lag behind TPS's own trigger

    // TPS commanded target -- driver presses the gas at t=2000ms
    //
    // (The -DBOOST_HIGH TPS-ramp reversal tried here previously was
    // reverted: it had no effect on the injected boost reading, which
    // empirically still rose from ~0x50 to ~0xD0 exactly as in the
    // unreversed case. Root cause: that reading tracks boost_adc4_raw
    // in klr_tb.v, itself driven off the RPM axis of the MAP table —
    // RPM's multi-second torque-balance ramp dominates the whole
    // trajectory's timing regardless of which way TPS moves in its own
    // ~250ms transition, so reversing TPS alone couldn't change it. The
    // actual fix is in klr_tb.v's boost_adc4_high formula instead — see
    // the comment there. Reverting TPS to the normal ramp also matters
    // for that fix: it keeps throttle CLOSED during the early low-RPM
    // window where the fault is now deliberately at its highest, giving
    // the genuinely implausible "high boost, closed throttle" combination
    // instead of accidentally recreating "high boost, WOT" — plausible,
    // not anomalous — by having TPS open during that same window.)
`ifdef LIVE
    // Live debugger: the web UI's throttle (live_tps) is the command,
    // and AFM gets the same command AFM_LAG_NS later, just as the
    // scripted t=2000ms event below does.
    wire [7:0] tps_commanded = dme_klr_dashboard_tb.live_tps;
    // public: after a snapshot load sim_main makes the lagged writes itself
    reg  [7:0] afm_commanded /*verilator public_flat_rw*/ = 8'h28;
    always @(tps_commanded)
        afm_commanded <= #AFM_LAG_NS tps_commanded;
`else
    reg [7:0] tps_commanded;
    initial begin
        tps_commanded = 8'h28;         // idle until engine settled
        #2_000_000_000;                // 2000ms — past fuel cut and ASE
        tps_commanded = `VAL_AFM_CL_TARGET;   // driver presses the gas
        if (`OPT_TEST_OVERRUN_CUTOFF) begin
            #30_000_000_000;               // hold open to t=32s — long enough to
                                            // fully settle near the target (see
                                            // TEST_CL_RAMP_TO_2100's own 30s figure)
            tps_commanded = 8'h28;          // driver lifts off — coast begins
        end
    end

    // AFM commanded target -- triggers on TPS's OWN event, but an
    // additional ~250ms later (airflow reacting to a throttle
    // position CHANGE, on top of the throttle linkage's own response
    // time). Using its own time-shifted trigger (rather than chasing
    // TPS's live value at the same speed) is deliberate: chasing a
    // moving target at matching speed only ever falls ~1 step behind,
    // not a genuine ~250ms lag — this instead gives AFM's entire
    // trajectory as a clean time-shifted copy of TPS's, which is what
    // "reacts to that, with about 250ms of its own lag" actually
    // means here.
    reg [7:0] afm_commanded;
    initial begin
        afm_commanded = 8'h28;
        #2_000_000_000;
        #AFM_LAG_NS;
        afm_commanded = `VAL_AFM_CL_TARGET;
        if (`OPT_TEST_OVERRUN_CUTOFF) begin
            #30_000_000_000;
            afm_commanded = 8'h28;
        end
    end

`endif

    // TPS (afm_wiper): slews toward tps_commanded, ~250ms full-range.
    // This IS the afm_wiper used everywhere else in the file/hierarchy
    // (including the hierarchical u_dme.afm_wiper reference that feeds
    // the KLR's TPS input) — see the afm_wiper wire
    // declaration near the ADC mux section below.
    reg        [7:0]  afm_wiper_ramp;
    reg        [63:0] tps_last_step_time;
    initial begin
        afm_wiper_ramp     = 8'h28;
        tps_last_step_time = 0;
    end
    always @(posedge clk) if (`OPT_AFM_CL_RAMP) begin
        if (afm_wiper_ramp < tps_commanded && ($time - tps_last_step_time) >= STEP_NS) begin
            afm_wiper_ramp     <= afm_wiper_ramp + 8'd1;
            tps_last_step_time <= $time;
        end else if (afm_wiper_ramp > tps_commanded && ($time - tps_last_step_time) >= STEP_NS) begin
            afm_wiper_ramp     <= afm_wiper_ramp - 8'd1;
            tps_last_step_time <= $time;
        end
    end

    // AFM (afm_cl): slews toward afm_commanded (its own time-shifted
    // trigger — see above), at the SAME per-count rate as TPS. Net
    // effect: AFM's entire trajectory is TPS's trajectory, shifted
    // ~250ms later — a genuine sustained lag through the transient,
    // closing back to zero once both reach the same final target.
    reg        [7:0]  afm_cl;
    reg        [63:0] afm_last_step_time;
    initial begin
        afm_cl             = 8'h28;
        afm_last_step_time = 0;
    end
    always @(posedge clk) if (`OPT_AFM_CL_RAMP) begin
        if (afm_cl < afm_commanded && ($time - afm_last_step_time) >= STEP_NS) begin
            afm_cl             <= afm_cl + 8'd1;
            afm_last_step_time <= $time;
        end else if (afm_cl > afm_commanded && ($time - afm_last_step_time) >= STEP_NS) begin
            afm_cl             <= afm_cl - 8'd1;
            afm_last_step_time <= $time;
        end
    end

// ─── ADC mux ────────────────────────────────────────────────
// AFM idle threshold: below = TPS closed (0x40), above = TPS open (0xDB)
// At 840 RPM afm_wiper=0x28; threshold must be > 0x28 so idle reads closed.
// At spike afm_tippy=0x78 >> threshold so TPS correctly reads open.
`define AFM_IDLE_THR 8'h30

// Under AFM_CL_RAMP, afm_wiper is the TPS ramp above (afm_wiper_ramp).
// Every other mode gets the crpm-based generator curve, via the port
// connection below (afm_wiper_gen).
wire [7:0] afm_wiper_gen;
wire [7:0] afm_wiper = `OPT_AFM_CL_RAMP ? afm_wiper_ramp : afm_wiper_gen;
// Idle switch derived from airflow: grounded (0) at idle, open (1) just
// off idle.  This is the throttle idle-stop contact — internal because
// afm_wiper/afm_tippy/afm_cl are all generated in this TB.
//
// idle_sw must track whichever signal is actually driving the AFM ADC
// channel (adc_mux case 3'b000 below) — NOT always afm_wiper. Under
// AFM_TIPPY/AFM_CL_RAMP the real AFM reading comes from an override
// signal (afm_tippy / afm_cl) that afm_wiper knows nothing about;
// wiring idle_sw to afm_wiper unconditionally desyncs TPS from the
// AFM event it's supposed to follow (e.g. tippy_in/cl_tippy_in: AFM
// steps via afm_tippy while afm_wiper — and hence TPS — moves on its
// own unrelated timeline).
`ifdef LIVE
// Live debugger: AFM follows the throttle model (afm_cl, built with
// AFM_CL_RAMP) unless the web UI pins it (16'hFFFF = follow the model).
wire [7:0] afm_effective = (dme_klr_dashboard_tb.live_afm == 16'hFFFF)
                           ? afm_cl : dme_klr_dashboard_tb.live_afm[7:0];
`else
wire [7:0] afm_effective = `OPT_AFM_FAULT    ? 8'hFF :
                           `OPT_AFM_CL_RAMP  ? afm_cl :
                           `OPT_AFM_TIPPY    ? afm_tippy :
                           afm_wiper;   // the engine model's (AFM_FROM_ENGINE_MODEL, see test_opts.vh)
`endif

// Every closed-loop build runs the ISV's bypass air (var_interrupt_gen_cl.v,
// CL_ISV_AIR, see test_opts.vh), except cl_cold_start's scripted crank ramp
`ifdef CL_MODE
// The ISV's bypass air (var_interrupt_gen_cl.v) shows on the AFM but
// doesn't move the throttle, so the throttle switch here and the KLR's
// throttle angle follow the AFM without it. Otherwise opening the ISV
// reads as opening the throttle (idle switch off, ch6 off-idle), which
// turns the firmware's idle control off.
// (Only where the AFM is the engine model's: the ramp/tippy/fault/live
// AFMs are commanded and don't carry the ISV air.)
integer throttle_afm_i;
always @(*) throttle_afm_i = $signed({1'b0, afm_effective}) - var_interrupt_generator_1.isv_afm_add;
wire [7:0] throttle_afm = !(`OPT_CL_ISV_AIR && `OPT_AFM_FROM_ENGINE_MODEL) ? afm_effective :
                          throttle_afm_i < 0 ? 8'd0 : throttle_afm_i > 255 ? 8'd255 : throttle_afm_i[7:0];
`else
wire [7:0] throttle_afm = afm_effective;
`endif
// Closed-loop builds on the engine model's AFM (cl_warm_idle,
// cl_ac_halfway, cl_cold_start, cl_condition_cycle_idle,
// cl_idle_controlled_by_isv) have no driver throttle: the engine model
// makes RPM from the fuel and the AFM from RPM, so the AFM follows RPM,
// not a pedal. The driver's foot is off, so the throttle is closed
// whatever RPM does. Deriving it from that AFM made any RPM rise read as
// opening the throttle: ch6 off-idle, idle loop off, off-idle fuel, more
// RPM, WOT (cl_warm_idle ran away to 6800 rpm once idle lambda drifted
// rich). The scripted-RPM ramps (ramp_to_*) keep the AFM as their
// throttle: there RPM is the driver's command.
// (CL_THROTTLE_CLOSED is defined in var_interrupt_gen_cl.v, compiled
// first, which also holds the AFM at the closed-throttle idle base.)
wire idle_sw = `OPT_CL_THROTTLE_CLOSED ? 1'b0 : (throttle_afm >= `AFM_IDLE_THR);

// The KLR's throttle angle (dme_klr_dashboard_tb.throttle_pos, normal
// and live builds alike): the throttle itself (afm_wiper), closed in the
// CL_THROTTLE_CLOSED builds above, or, where the AFM is the (scripted-RPM)
// engine model's, that AFM without the ISV's bypass air
wire [7:0] klr_throttle = `OPT_CL_THROTTLE_CLOSED   ? 8'h28 :
                          `OPT_AFM_FROM_ENGINE_MODEL ? throttle_afm : afm_wiper;

// ch6 (throttle switch) at closed throttle. The car reads 2.94-3.07 V
// here (0x96-0x9D); 0x99 is 3.0 V. The firmware classifies ch6 with
// table 0x1124 (0x0659 at reset, 0x1BC1 while running) into 23h.0/.1:
// < 0x89 code 3, 0x89-0xB7 code 2, 0xB8-0xE6 code 1 (WOT 0xCC here),
// >= 0xE7 code 0 (off-idle 0xF2). Its idle-speed PI loop (0x08DE ->
// 0x106B -> 0x0942) only runs on code 2; the 0x85 used before was code
// 3, which holds the ISV at a fixed position.
`ifndef TPS_IDLE_ADC
  `define TPS_IDLE_ADC 8'h99
`endif
// The KLR's full_load line (P1.5) reaches ch6 through the DME's input
// network (R762 47k into the ADC pin's 100n, tau ~4.7 ms). The 8048's
// ports float high while it's held in reset — on every crank trigger —
// and stay high until the firmware rewrites P1, so the raw line pulses
// "WOT" each trigger; on the car the RC averages those away. Without it
// the DME's ADC could catch an instant of a pulse (cl_ramp_to_3000_FQS2
// read ch6 = 0xCC at part throttle). full_load_rc is that RC, 0..1000000.
`ifndef FULL_LOAD_TAU_US
  `define FULL_LOAD_TAU_US 4700
`endif
// full_load is X until the KLR's firmware first writes P1; `full_load ?`
// would then load X into the integer for good (4-state simulators only,
// so iverilog, not Verilator), so only a known 1 charges the RC.
integer full_load_rc = 0;
always #10_000 full_load_rc = full_load_rc + (((full_load === 1'b1) ? 1000000 : 0) - full_load_rc) / (`FULL_LOAD_TAU_US / 10);
// ch6 with the throttle open: off-idle 0xF2 .. WOT 0xCC along the RC
wire [7:0] ch6_open = 8'hF2 - (38 * full_load_rc) / 1000000;
reg  [7:0] adc_mux;
// Each channel's input, all eight at once, so the [DS] snapshot can log
// what the ADC is being fed (adc_ch0..7) and not only what the firmware
// has stored from it; adc_mux selects the one P2[2:0] asks for.
reg  [7:0] adc_ch0, adc_ch1, adc_ch2, adc_ch3, adc_ch4, adc_ch5, adc_ch6, adc_ch7;

// NOTE: was previously `@(p2[2:0] or afm_wiper)`. Now that idle_sw can
// depend on afm_tippy/afm_cl (not just afm_wiper) under AFM_TIPPY/
// AFM_CL_RAMP, an explicit sensitivity list would go stale on every
// signal that idle_sw transitively depends on unless each one is added
// here too. `always @(*)` re-evaluates on any input change and avoids
// re-introducing the same class of staleness bug this file just had.
// ── Altitude: air density ─────────────────────────────────────
// The altitude input (ch4) is a pressure switch: below 0x80 it says
// "high altitude" (0x00; 0xF8 = low, 0xFF = open circuit). Up there the
// air is thinner, ALT_DENSITY_X1000/1000 of sea level (default 0.88,
// ~1000 m). The engine breathes about the same volume, so:
//   - real air per stroke drops by rho (var_interrupt_gen_cl.v torque),
//   - the flap AFM, deflected by dynamic pressure, reads flow x sqrt(rho):
//     it drops, but only half as far, so it over-reads mass by
//     1/sqrt(rho). The DME's altitude switch removes that: 0x1D3C scales
//     fuel by 0x11CB = 0x78 (x0.9375 = sqrt(0.88)).
// The firmware's AFM linearisation (0x03B2, tables 0x10F4/0x10FC/0x1104)
// is exponential: flow x1.837 per 32 ADC counts. So sqrt(rho) on the flow
// is a constant ADC shift, alt_afm_shift = 32 ln(sqrt(rho)) / ln(1.837)
// (-3 counts at 0.88), applied to the AFM the sensor reports.
`ifndef ALT_DENSITY_X1000
  `define ALT_DENSITY_X1000 880
`endif
integer alt_afm_shift;
integer alt_sqrt_x1000;
initial begin
    alt_sqrt_x1000 = $rtoi($sqrt(`ALT_DENSITY_X1000 / 1000.0) * 1000.0 + 0.5);
    alt_afm_shift  = $rtoi(32.0 * $ln($sqrt(`ALT_DENSITY_X1000 / 1000.0)) / $ln(1.837) - 0.5);
end
// from ch4's source (adc_ch4 itself is assigned in the same block as ch0)
`ifdef LIVE
wire [7:0] alt_switch = dme_klr_dashboard_tb.live_altitude;
`else
wire [7:0] alt_switch = `OPT_CL_CONDITION_CYCLE_ACTIVE ? altitude_dynamic_cycle : `VAL__ALTITUDE;
`endif
wire alt_high = (alt_switch < 8'h80);
// Air flow after a fuel cut (combined DME+KLR build): the AFM models
// here follow the throttle alone, i.e. the flow at the RPM and boost the
// throttle settles at. During and after a cut the engine falls away from
// that point, and the KLR model gives the flow ratio
// (RPM x MAP) / (RPM x MAP at the start of the cut)
// (klr_tb.v, afm_flow_ratio_x1000). The AFM sits upstream of the turbo,
// at ambient density, so (unlike altitude) it reads the whole drop: with
// the firmware's exponential linearisation that is a shift of
// 32 ln(ratio) / ln(1.837) ADC counts.
`ifdef DME_KLR_COMBINED
integer boost_afm_shift;
always @(*) begin
    if (dme_klr_dashboard_tb.u_klr.afm_flow_ratio_x1000 >= 1000)
        boost_afm_shift = 0;
    else
        boost_afm_shift = $rtoi(32.0 * $ln(dme_klr_dashboard_tb.u_klr.afm_flow_ratio_x1000 / 1000.0) / $ln(1.837) - 0.5);
end
`else
localparam integer boost_afm_shift = 0;
`endif
function automatic [7:0] afm_at_alt;
    input [7:0] afm;
    input signed [31:0] boost_shift;   // boost_afm_shift, passed in so @(*) sees it
    integer v;
    begin
        v = afm + (alt_high ? alt_afm_shift : 0) + boost_shift;
        afm_at_alt = v < 0 ? 8'd0 : v > 255 ? 8'd255 : v[7:0];
    end
endfunction

`ifdef LIVE
// Live debugger: every ADC channel reads the value the web UI last set
// in dme_klr_dashboard_tb (see dme_klr/live/). TPS (ch6) keeps the
// normal idle-switch / KLR full_load logic below unless live_dme_tps
// pins it (16'hFFFF = follow that logic), as the log replay does.
always @(*) begin
        adc_ch0 = (dme_klr_dashboard_tb.live_afm == 16'hFFFF) ? afm_at_alt(afm_effective, boost_afm_shift) : afm_effective;  // a pinned AFM is the sensor reading itself
        adc_ch1 = dme_klr_dashboard_tb.live_battery;
        adc_ch2 = dme_klr_dashboard_tb.live_airtemp;
        adc_ch3 = dme_klr_dashboard_tb.live_coolant;
        adc_ch4 = dme_klr_dashboard_tb.live_altitude;
        adc_ch5 = 8'hFF;
        adc_ch6 = (dme_klr_dashboard_tb.live_dme_tps != 16'hFFFF) ? dme_klr_dashboard_tb.live_dme_tps[7:0]
                        : idle_sw ? ch6_open : `TPS_IDLE_ADC;
        adc_ch7 = dme_klr_dashboard_tb.live_fuel_qual;
end
`else
always @(*) begin
        adc_ch0 = `OPT_AFM_FAULT           ? 8'hFF :
                  `OPT_AFM_SHORT_TO_GROUND ? 8'h00 :  // AFM wiper shorted to ground (afm_short_to_ground)
                  `OPT_AFM_CL_RAMP         ? afm_at_alt(afm_cl, boost_afm_shift) :
                  `OPT_AFM_TIPPY           ? afm_at_alt(afm_tippy, boost_afm_shift) :
                                             afm_at_alt(afm_wiper, boost_afm_shift);
        adc_ch1 = `OPT_DME_BATT_DISCONNECTED     ? 8'h00 :  // battery sense open — reads no voltage (battery_disconnected)
                  `OPT_CL_CONDITION_CYCLE_ACTIVE ? battery_dynamic_cycle :
                                                   `VAL__BATTERY;
        adc_ch2 = `OPT_TEST_AIRTEMP_FAIL         ? 8'h00 :  // shorted sensor: 0V → ADC 0x00 → matches normal TB
                  `OPT_AIRTEMP_OPEN_CIRCUIT      ? 8'hFF :  // open NTC: pull-up takes it to the rail (airtemp_open_circuit)
                  `OPT_CL_CONDITION_CYCLE_ACTIVE ? airtemp_dynamic_cycle :
                                                   `VAL__AIRTEMP_RAW;
        adc_ch3 = coolant_warmup_on              ? coolant_dynamic :  // TEST_ISV_COLD_IDLE / TEST_COLD_START / TEST_CL_COLD_START
                  `OPT_CL_CONDITION_CYCLE_ACTIVE ? coolant_dynamic_cycle :
                  `OPT_TEST_COOLANT_FAIL         ? 8'h00 :  // shorted sensor: matches normal TB
                  `OPT_COOLANT_OPEN_CIRCUIT      ? 8'hFF :  // open NTC: pull-up takes it to the rail (coolant_open_circuit)
                                                   `VAL__COOLANT_RAW;
        adc_ch4 = `OPT_CL_CONDITION_CYCLE_ACTIVE ? altitude_dynamic_cycle : `VAL__ALTITUDE;
        adc_ch5 = 8'hFF;
        // TPS_FIXED pins ch6; otherwise from the idle switch / KLR full_load:
        // open: WOT=4.0V / off-idle=4.75V, closed throttle (see TPS_IDLE_ADC)
        adc_ch6 = `OPT_TPS_FIXED ? `VAL_TPS_FIXED
                               : idle_sw ? ch6_open : `TPS_IDLE_ADC;
        adc_ch7 = `VAL__FUEL_QUAL;
end
`endif // LIVE
always @(*)
    case (p2[2:0])
        3'b000: adc_mux = adc_ch0;
        3'b001: adc_mux = adc_ch1;
        3'b010: adc_mux = adc_ch2;
        3'b011: adc_mux = adc_ch3;
        3'b100: adc_mux = adc_ch4;
        3'b101: adc_mux = adc_ch5;
        3'b110: adc_mux = adc_ch6;
        3'b111: adc_mux = adc_ch7;
    endcase

assign adc_data      = adc_mux;
assign xadc_data_out = adc_data_out;
assign xdata         = (!xrd_n) ? xadc_data_out : 8'bz;

adc_delay_8 adc_delay_8_1 (
    .clk     ( ale          ),
    .rst     ( rst          ),
    .data_in ( adc_data     ),
    .start   ( ~xrd_n       ),
    .data_out( adc_data_out )
);

// ─── O2 sensor ──────────────────────────────────────────────
// o2_6/o2_7 say what the sensor voltage is (matches o2_gen.v):
//   Rich (~0.9V):         o2_6=1, o2_7=1
//   Crossover (~0.5V):    o2_6=1, o2_7=0
//   Lean (~0.1V):         o2_6=0, o2_7=0
// The DME's comparators (S800 CA139, analog/o2.jpg) take the sensor on
// their inverting inputs against a ~0.6 V ladder and drive P1.7/P1.6
// open-collector, so the pins are the inverse: rich reads low, lean
// high. The firmware agrees (0x0A7F: P1.7 high adds fuel). See p1_in.
//   Disconnected (open):  both pins low (o2_pins_low) — the analog
//                          recovery-circuit sim: an open input floats both
//                          comparator outputs low.
// O2_FLAT_DISCONNECTED / O2_FLAT_LEAN: both low; O2_FLAT_RICH: both
// high; otherwise the sensor model below (or the live panel's pin).
wire o2_pins_low = `OPT_O2_FLAT_DISCONNECTED;
wire o2_flat     = `OPT_O2_FLAT_DISCONNECTED || `OPT_O2_FLAT_LEAN || `OPT_O2_FLAT_RICH;
wire o2_6_model, o2_7_model;
assign o2_6 = o2_flat ? `OPT_O2_FLAT_RICH : o2_6_model;
assign o2_7 = o2_flat ? `OPT_O2_FLAT_RICH : o2_7_model;
`ifdef O2_SQUARE_WAVE
    // The old free-running square wave (o2_gen.v), on request only
    wire _o2_6, _o2_7;
    o2_generator o2_generator_1 (
        .clk       ( clk   ),
        .rst       ( rst   ),
        .o2_top    ( _o2_7 ),
        .o2_bottom ( _o2_6 )
    );
`else
    // The sensor follows the mixture the firmware actually delivers, so
    // the lambda integrator (1Bh) limit-cycles around stoich. It needs
    // only the firmware's own fuel and load, so it serves the scripted-
    // RPM builds as well as the CL engine model. (The free-running
    // o2_generator square wave, -DO2_SQUARE_WAVE, ignores the mixture;
    // its 267 ms "lean" vs 250 ms "rich" walked 1Bh to its +15% clamp at
    // idle.)
    //   mixture  = fuel time 4B:4A / air per stroke 46:47 (the firmware's
    //              own load from the AFM and RPM), rich above O2_STOICH_X1000
    //              (1.025: warm idle with lambda held off, 1Bh = 0x80;
    //              part load's base map sits ~4% richer, full load ~20%)
    //   delay    = O2_DELAY_MS of exhaust transport (a shift register,
    //              sampled every ms), then the sensor's own ~O2_TAU_MS
    //              first-order swing between 100 mV lean and 850 mV rich
    //   o2_7/o2_6 = sensor above 550 / 450 mV (top/bottom comparator;
    //              crossover is between them)
`ifndef O2_STOICH_X1000
  `define O2_STOICH_X1000 1025
`endif
`ifndef O2_DELAY_MS
  `define O2_DELAY_MS 150
`endif
`ifndef O2_TAU_MS
  `define O2_TAU_MS 30
`endif
    wire _o2_6, _o2_7;
    reg  [255:0] o2_rich_line = 256'd0;
    integer      o2_mv = 100;
    reg          o2_rich_now;
    always #1_000_000 begin : o2_mixture
        integer fuel, load;
        fuel = {i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h4B], i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h4A]};
        load = {i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h46], i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h47]};
        // fuel cut (23h.5) or rev limit: fire_inj is skipped, so nothing
        // is injected whatever 4B:4A says, and the exhaust goes lean.
        // No firing for 2+ of the usual firing intervals means skipped.
        if (i8051_dashboard_tb.inj_skipping) fuel = 0;
        // the real air per stroke: at altitude the firmware's load comes
        // from an AFM reading flow x sqrt(rho) while the real air is x rho
        // (see "Altitude: air density"), a further x sqrt(rho)
        if (alt_high) load = load * alt_sqrt_x1000 / 1000;
        o2_rich_now  = (load != 0) && (fuel * 1000 > load * `VAL_O2_STOICH_X1000);
        o2_rich_line = {o2_rich_line[254:0], o2_rich_now};
        o2_mv = o2_mv + ((o2_rich_line[`VAL_O2_DELAY_MS - 1] ? 850 : 100) - o2_mv) / `VAL_O2_TAU_MS;
    end
    assign _o2_7 = (o2_mv > 550);
    assign _o2_6 = (o2_mv > 450);
`endif
`ifdef LIVE
    // Live debugger / log replay: live_o2 = {o2_7, o2_6} pins the
    // comparator outputs (0 lean, 1 crossover, 3 rich); 16'hFFFF = generator.
    assign o2_6_model = (dme_klr_dashboard_tb.live_o2 == 16'hFFFF) ? _o2_6 : dme_klr_dashboard_tb.live_o2[0];
    assign o2_7_model = (dme_klr_dashboard_tb.live_o2 == 16'hFFFF) ? _o2_7 : dme_klr_dashboard_tb.live_o2[1];
`else
    assign o2_6_model = _o2_6;
    assign o2_7_model = _o2_7;
`endif

// ─── P1 / P3 input assignments ──────────────────────────────
always @(clk) begin
    p1_in[0] = 1'b1;
    p1_in[1] = 1'b1;
    p1_in[2] = 1'b1;
    p1_in[3] = 1'b1;
    p1_in[4] = 1'b1;
    p1_in[5] = 1'b1;
    p1_in[6] = ~o2_6 & ~o2_pins_low;   // comparator inverts (see O2 sensor)
    p1_in[7] = ~o2_7 & ~o2_pins_low;

    p3_in[7:6] = 2'b11;           // unused, idle high
    p3_in[5]   = t1;              // T1 (P3.5) — AC compressor status (driven via t1 assign)
    p3_in[4]   = 1'b0;            // T0 (P3.4) — has-cat flag (0 = catalytic converter fitted)
    p3_in[1:0] = {bit_out, int_uart};
    p3_in[2]   = reference_sensor;
    p3_in[3]   = speed_sensor;
    p3_in[4]   = 1'b0;
end

// ─── RPM / crank generator ──────────────────────────────────
`ifdef RPMRAMP
`ifdef CL_MODE
// Closed-loop engine dynamics — RPM driven by fuel pulse feedback.
// RPM physics (rpm_fp/crpm) run identically regardless of what its
// afm_wiper OUTPUT port connects to below — that output is a
// read-only derived value, not a feedback input to the module's own
// RPM computation, so discarding it under AFM_CL_RAMP is safe.
// (Under AFM_CL_RAMP the TPS/AFM come from the driver-commanded ramp
// above instead, and afm_wiper_gen goes unused: see afm_wiper.)
var_interrupt_generator_cl var_interrupt_generator_1 (
    .clk       ( clk                  ),
    .rst       ( rst                  ),
    .int_0     ( reference_sensor_gen ),
    .int_1     ( speed_sensor_gen     ),
    .tdc       ( tdc_marker           ),
    .afm_wiper ( afm_wiper_gen        )
);
`else
// Open-loop RPM ramp — STEP_CLOCKS supplied via -DSTEP_CLOCKS from run script
var_interrupt_generator var_interrupt_generator_1 (
    .clk       ( clk                  ),
    .rst       ( rst                  ),
    .int_0     ( reference_sensor_gen ),
    .int_1     ( speed_sensor_gen     ),
    .tdc       ( tdc_marker           ),
    .afm_wiper ( afm_wiper_gen        )
);
`endif
`else
  `ifdef NOINT
    assign reference_sensor_gen = 1'b1;
    assign speed_sensor_gen     = 1'b1;
    assign tdc_marker           = 1'b0;   // no crank model in NOINT builds
  `else
interrupt_generator interrupt_generator_1 (
    .clk   ( clk                  ),
    .rst   ( rst                  ),
    .int_0 ( reference_sensor_gen ),
    .int_1 ( speed_sensor_gen     )
);
    assign tdc_marker = 1'b0;   // plain interrupt_generator has no TDC concept
  `endif
`endif

// A fault time can't sit in the continuous assign itself: Icarus does not
// re-evaluate an assign when only $time changes, so the fault would land
// at the next edge of the _gen signal, not at the fault time, while the
// other simulator applies it on time. A clocked flag fires at the same
// clock in both.
//
// TEST_REF_SENSOR_LOSS: the reference (crank position) sensor wire
// breaks/opens partway through the test — the generator underneath
// keeps computing real RPM physics (so the engine model stays
// internally consistent), but the DME's actual input pin (P3.2/INT0)
// stops seeing any pulses from REF_LOSS_T_MS onward, same as a broken
// wire or connector between the sensor and the ECU. Held high (no
// pulse) rather than low, matching the open-collector idle-high
// convention documented above (`p3_in[2] — 1 = no ref pulse`).
// REF_SENSOR_STUCK_LOW: the opposite fault — the INT0 line shorted to
// ground from REF_LOSS_T_MS onward (ref_sensor_stuck_low).
// REF_SENSOR_ABSENT: no reference signal at all, from power-on — the
// open wire of TEST_REF_SENSOR_LOSS, but present through cranking, so
// it shows whether the engine can sync and start on the speed sensor
// alone (ref_sensor_missing_at_start).
// REF_LOSS_T_MS defaults to 3000 ms for TEST_REF_SENSOR_LOSS, 3500 ms
// for REF_SENSOR_STUCK_LOW (test_opts.vh).
reg reference_sensor_lost = 1'b0;
always @(posedge clk)
    if ((`OPT_TEST_REF_SENSOR_LOSS || `OPT_REF_SENSOR_STUCK_LOW) && `DME_MS >= `VAL_REF_LOSS_T_MS)
        reference_sensor_lost <= 1'b1;
assign reference_sensor = `OPT_TEST_REF_SENSOR_LOSS  ? (reference_sensor_lost ? 1'b1 : reference_sensor_gen) :
                          `OPT_REF_SENSOR_ABSENT     ? 1'b1 :
                          `OPT_REF_SENSOR_STUCK_LOW  ? (reference_sensor_lost ? 1'b0 : reference_sensor_gen) :
                                                       reference_sensor_gen;

// TEST_SPEED_SENSOR_LOSS: same mechanism as TEST_REF_SENSOR_LOSS above,
// applied to the speed/tooth sensor (P3.3/INT1) instead — held high
// (no tooth) from SPEED_LOSS_T_MS onward, matching the idle-high
// convention documented above (`p3_in[3] — 1 = no tooth`).
// SPEED_SENSOR_STUCK_LOW: INT1 shorted to ground from SPEED_LOSS_T_MS
// onward (speed_sensor_stuck_low). SPEED_LOSS_T_MS defaults as above.
reg speed_sensor_lost = 1'b0;
always @(posedge clk)
    if ((`OPT_TEST_SPEED_SENSOR_LOSS || `OPT_SPEED_SENSOR_STUCK_LOW) && `DME_MS >= `VAL_SPEED_LOSS_T_MS)
        speed_sensor_lost <= 1'b1;
assign speed_sensor = `OPT_TEST_SPEED_SENSOR_LOSS ? (speed_sensor_lost ? 1'b1 : speed_sensor_gen) :
                      `OPT_SPEED_SENSOR_STUCK_LOW ? (speed_sensor_lost ? 1'b0 : speed_sensor_gen) :
                                                    speed_sensor_gen;

// ─── External RAM ────────────────────────────────────────────
always @(posedge xwr_n)
    begin 
     diag_data <= xdata; 
     diag_addr <= p2;
    end
// ─── Lambda warmup skip ───
//  Watches for the falling edge of iram[23h].4 (bit1Ch) then
//  seeds bit08h+09h+1Dh and wu=0x0001.
reg skip_lambda_done;
reg skip_lambda_intblock_prev;
initial begin
    skip_lambda_done          = 1'b0;
    skip_lambda_intblock_prev = 1'b0;
end

always @(posedge clk) if (`OPT_SKIP_LAMBDA_WARMUP) begin : lambda_warmup_skip
    skip_lambda_intblock_prev <= i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h23][4];

    if (rst && !skip_lambda_done &&
        skip_lambda_intblock_prev &&
        !i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h23][4]) begin
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h21][0] <= 1'b1; // bit08h = phase1 init done
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h21][1] <= 1'b1; // bit09h = phase2 init done
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h23][5] <= 1'b1; // bit1Dh = FuelOffCoast
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h58]    <= 8'h00; // WU_HB = 0 (warmup fully expired)
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h59]    <= 8'h00; // WU_LB = 0 (warmup fully expired)
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h7F]    <= 8'h14; // ISV step — warm idle baseline
        skip_lambda_done <= 1'b1;
        $display("DME: [SEED] t=%0d ms  SKIP_LAMBDA_WARMUP — bit08h+09h+1Dh set, wu=0x0001, ISV=0x14",
                 `DME_MS);
        $fflush();
    end
end // lambda_warmup_skip

// ============================================================
//  SIMULATION CONTROL  (identical to i8051_dashboard_tb.v)
// ============================================================
// Pre-initialise key iram registers to 0 at t=0 to prevent
// X-state propagation into monitors before the firmware runs.
// Only active when SKIP_LAMBDA_WARMUP is set — for cold-start
// tests the firmware must initialise from scratch.
initial if (`OPT_SKIP_LAMBDA_WARMUP) begin
    wait (rst === 1'b1);
    @(posedge clk);  // one cycle; vlt ignores #delays in initial blocks
    i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h7F] = 8'h00;  // ISV step
    i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h36] = 8'h00;  // ISV counter
end

initial begin
    rst   = 1'b0;
    p2_in = 8'hFF;
    #1000
    rst = 1'b1;
    #(`VAL_SIM_TIME)
    $display("time ", $time, "\nend of time\n");
    $writememh("rom_out.hex",  i8051_dashboard_tb.i8051_top.u_eprom.mem);
    $writememh("ram_out.hex",  i8051_dashboard_tb.i8051_top.u_cpu.iram);
    #10000
    $finish;
end

initial begin
    clk = 0;
    forever #DELAY clk <= ~clk;
end

// ============================================================
//  REFERENCE SENSOR RPM CALCULATOR
//  Measures osc clocks between consecutive falling edges of
//  reference_sensor (P3.2 / INT0 — one pulse per revolution).
//  RPM = 60 * 1000 * DME_FREQ / period_half_cycles
//  Held until the next revolution so every snapshot has a value.
// ============================================================
reg [63:0] ref_last_edge;
reg [63:0] ref_period;
reg [31:0] ref_rpm;
reg        ref_prev;

initial begin
    ref_last_edge = 64'd0;
    ref_period    = 64'd0;
    ref_rpm       = 32'd0;
    ref_prev      = 1'b1;
end

always @(posedge clk) begin : ref_rpm_calc
    if (!rst) begin
        ref_last_edge <= 64'd0;
        ref_period    <= 64'd0;
        ref_rpm       <= 32'd0;
        ref_prev      <= 1'b1;
    end else begin
        // Detect falling edge of reference_sensor
        if (ref_prev && !reference_sensor) begin
            if (ref_last_edge != 64'd0) begin
                ref_period = i8051_dashboard_tb.i8051_top.u_cpu.cycle_count - ref_last_edge;
                if (ref_period > 0)
                    ref_rpm <= (32'd60 * 32'd1000 * `DME_FREQ) / ref_period[31:0];
            end
            ref_last_edge <= i8051_dashboard_tb.i8051_top.u_cpu.cycle_count;
        end
        ref_prev <= reference_sensor;
    end
end

// ============================================================
//  DASHBOARD SNAPSHOT
//  Format: [DS] <ms>,<256hex_iram>,<p1><p2><p3>,<rpm>
// ============================================================
`define IRAM(a) i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h``a``]

// Snapshot-in-progress flag — phase monitor checks this before $display
// to prevent its output from interleaving into the DS hex stream.
reg snapshot_busy;
initial snapshot_busy = 1'b0;

task emit_snapshot;
    integer i;
    begin
        snapshot_busy = 1'b1;
        $write("DME: [DS] %0d,", `DME_MS);
        for (i = 0; i < 128; i = i + 1)
            $write("%02h", i8051_dashboard_tb.i8051_top.u_cpu.iram[i[6:0]]);
        // Ports snapshot: construct from defined pin signals, not raw CPU
        // latches.  Input-only pins (O2 on P1.7/P1.6, serial on P3.1/P3.0)
        // read back as X from the output latch, which corrupts the hex field
        // (e.g. "X77X") and makes the dashboard show '?'.  Source those bits
        // from the driven *_in signals instead.
        //   P1.7/P1.6 = O2 sensor inputs (p1_in[7:6] = ~{o2_7,o2_6}, inverted)
        //   P3.5/P3.4 = T1/T0 (t1/t0 wires); P3.2 = ref sensor; P3.1:0 serial
        $write(",%02h%02h%02h",
               {p1_in[7:6], p1[5:0]},                     // P1: O2 inputs + latch
               p2,                                        // P2: ADC/addr latch
               {p3[7:6], t1, t0, speed_sensor, reference_sensor, p3_in[1:0]});
        $write(",%0d", ref_rpm);
        // ADC channel inputs 0-7 (AFM, battery, air temp, coolant, altitude,
        // -, TPS, fuel quality) as fed to the ADC, not as stored in iram
        $write(",%02h%02h%02h%02h%02h%02h%02h%02h\n", adc_ch0, adc_ch1, adc_ch2, adc_ch3,
               adc_ch4, adc_ch5, adc_ch6, adc_ch7);
        snapshot_busy = 1'b0;
    end
endtask

`ifndef DME_KLR_COMBINED
// Snapshot scheduler — suppressed when dme_klr_dashboard_tb is top
// (that testbench has its own combined DME+KLR scheduler).
reg [63:0] next_snap;
initial    next_snap = (`VAL_DASH_INTERVAL_MS * `DME_FREQ);

always @(posedge clk) begin
    if (rst &&
        i8051_dashboard_tb.i8051_top.u_cpu.cycle_count >= next_snap) begin
        emit_snapshot;
        next_snap <= next_snap + (`VAL_DASH_INTERVAL_MS * `DME_FREQ);
    end
end
`endif // DME_KLR_COMBINED

// ============================================================
//  PHASE MONITOR
// ============================================================
// ── NTC linearised-value → degrees Celsius ──────────────────────
// The firmware runs both NTC ADC bytes through its linearisation map
// (maps 1/2, 0x12A6 in 28PIN_DME_PERFORMANCE) into iram[12h]/[13h],
// which span -40..+125 degC linearly: degC = lin * 165/255 - 40. This
// puts the ROM's own temperature thresholds where the disassembly notes
// have them (55h ~14.7 C cold-crank, 58h ~16.7 C lambda enable, 8Ch
// ~50 C, A2h ~65 C, 7-count hysteresis ~4.6 C). The previous
// 10 + (lin - 143) * 70/79 fit put 55h/58h at about -40 C.
function automatic integer ntc_celsius;
    input [7:0] lin;
    begin
        ntc_celsius = (lin * 165) / 255 - 40;
    end
endfunction

// Shadow registers — prevent ADC bleed in STATUS snapshots
integer cool_c_disp;
integer air_c_disp;

// ── phase_status named scope ──────────────────────────────────
// Everything below through the watchdog stall detector (shadow regs,
// phase-transition edge state, and the always blocks that drive them)
// lives in this named scope so it can get its own dedicated dumpvars
// call under DME_DEEP_DEBUG instead of always riding along with the
// broad $dumpvars(1,`TB) sweep — see vcd.v. This is purely a waveform-
// grouping/visibility change: the `if (1)` is permanently true, so all
// the $display("DME: [PHASE] ...") / $display("DME: [STATUS] ...")
// logic inside keeps running unconditionally in every build, debug or
// not — those lines feed the always-on dashboard/.dash.log pipeline,
// not just debug tracing.
generate
if (1) begin : phase_status
reg [7:0] isv_shadow;
reg [7:0] afm_raw_shadow;
reg [7:0] coolant_shadow;
reg [7:0] airtemp_shadow;
reg [63:0] ph_status_next_snap;

// ── Direct ADC input mirrors (for STATUS display) ────────────
// Mirrors the exact same `ifdef-gated source selection as the
// adc_mux ch2/ch3 case entries further below — always reflects
// whatever raw value is actually feeding the ADC for airtemp/
// coolant in the currently-compiled test, bypassing the firmware's
// own complement+linearize processing of iram[0x12]/iram[0x13]
// entirely (and the timing inconsistency that processing showed —
// iram[0x13] observed reading its own raw pre-processed input for
// one sample, then the correctly-processed value the next). This is
// the testbench's own known-good, monotonic source signal, not a
// read-back of anything the firmware computes.
`ifdef LIVE
wire [7:0] airtemp_adc_in = dme_klr_dashboard_tb.live_airtemp;
`else
wire [7:0] airtemp_adc_in = `OPT_TEST_AIRTEMP_FAIL         ? 8'h00 :
                            `OPT_CL_CONDITION_CYCLE_ACTIVE ? airtemp_dynamic_cycle :
                                                             `VAL__AIRTEMP_RAW;
`endif

`ifdef LIVE
wire [7:0] coolant_adc_in = dme_klr_dashboard_tb.live_coolant;
`else
wire [7:0] coolant_adc_in = coolant_warmup_on              ? coolant_dynamic :
                            `OPT_CL_CONDITION_CYCLE_ACTIVE ? coolant_dynamic_cycle :
                            `OPT_TEST_COOLANT_FAIL         ? 8'h00 :
                                                             `VAL__COOLANT_RAW;
`endif

always @(posedge clk) begin : isv_shadow_track
    if (!rst) isv_shadow <= 8'h00;
    else if (i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h7F] <= 8'h40)
        isv_shadow <= i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h7F];
end

always @(posedge clk) begin : afm_raw_track
    if (!rst) afm_raw_shadow <= 8'h00;
    else
        afm_raw_shadow <= i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h10];
end

always @(posedge clk) begin : ntc_shadow_track
    // Was `iram[0x13] >= 8'h80` — worked only by coincidence for tests
    // where the raw coolant_adc input itself starts below 0x80 (e.g.
    // TEST_ISV_COLD_IDLE's 0x68). For tests where it starts above 0x80
    // (e.g. TEST_COLD_START/TEST_CL_COLD_START's 0xC0), a transient
    // glitch showing that raw value ALSO clears the >=0x80 bar,
    // polluting the shadow with a spurious reading. Comparing against
    // the actual current raw input (coolant_adc_in/airtemp_adc_in)
    // instead correctly rejects the glitch either way: a genuinely-
    // processed (complement+linearized) value should never exactly
    // equal its own raw input.
    if (!rst) begin
        coolant_shadow <= 8'hFF;
        airtemp_shadow <= 8'hFF;
    end else begin
        if (i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h13] != coolant_adc_in)
            coolant_shadow <= i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h13];
        if (i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h12] != airtemp_adc_in)
            airtemp_shadow <= i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h12];
    end
end

reg ph_sync_prev, ph_fuelcut_prev, ph_lambdaok_prev;
reg ph_coldenrich_prev, ph_coldtiming_prev, ph_isvovf_prev;
reg ph_usemap_prev, ph_intblock_prev;
reg ph_intblock_set_seen;  // guards "cleared" until "set" has fired

initial begin
    ph_sync_prev       = 1'b0;
    ph_fuelcut_prev    = 1'b0;
    ph_lambdaok_prev   = 1'b0;
    ph_coldenrich_prev = 1'b0;
    ph_coldtiming_prev = 1'b0;
    ph_isvovf_prev     = 1'b0;
    ph_usemap_prev         = 1'b0;
    ph_intblock_set_seen   = 1'b0;
    // NOTE: vlt inits all regs to 0; iverilog inits to X.
    // The firmware sets iram[23h].4=1 at power-on (interrupt block).
    // Pre-arm prev=1 so we only need to detect the falling edge.
    ph_intblock_prev   = 1'b1;
    cool_c_disp         = 9999;
    air_c_disp          = 9999;
    isv_shadow          = 8'hFF;
    afm_raw_shadow      = 8'h00;
    coolant_shadow      = 8'hFF;
    airtemp_shadow      = 8'hFF;
    ph_status_next_snap = 64'd18000;
end

always @(posedge clk) begin  // phase_monitor

    if (!rst) begin
        ph_sync_prev       <= 1'b0;
        ph_fuelcut_prev    <= 1'b0;
        ph_lambdaok_prev   <= 1'b0;
        ph_coldenrich_prev <= 1'b0;
        ph_coldtiming_prev <= 1'b0;
        ph_isvovf_prev     <= 1'b0;
        ph_usemap_prev       <= 1'b0;
        ph_intblock_prev     <= 1'b1;  // firmware sets this bit at power-on
        ph_intblock_set_seen <= 1'b0;
    end else if (!snapshot_busy) begin

        // EngineSync  iram[21h].0
        if (`IRAM(21)[0] && !ph_sync_prev)
            $display("DME: [PHASE] t=%0d ms  ENGINE SYNC                  (bit08h set)", `DME_MS);
        ph_sync_prev <= `IRAM(21)[0];

        // IntBlock  iram[23h].4 — set at power-on, cleared when engine synced
        if (`IRAM(23)[4] && !ph_intblock_prev) begin
            $display("DME: [PHASE] t=%0d ms  INTERRUPT BLOCK set      (watchdog or power-on reset)",
                     `DME_MS);
            ph_intblock_set_seen <= 1'b1;
        end
        if (!`IRAM(23)[4] && ph_intblock_prev && ph_intblock_set_seen)
            $display("DME: [PHASE] t=%0d ms  INTERRUPT BLOCK cleared  (engine synced — fully running)",
                     `DME_MS);
        ph_intblock_prev <= `IRAM(23)[4];

        // UseMap1140 / After-start enrich  iram[21h].5  (bit 0Dh)
        if (`IRAM(21)[5] && !ph_usemap_prev)
            $display("DME: [PHASE] t=%0d ms  AFTER-START ENRICH begin (UseMap1140 set, iram[3Ch]=0x%02X)",
                     `DME_MS, `IRAM(3C));
        if (!`IRAM(21)[5] && ph_usemap_prev)
            $display("DME: [PHASE] t=%0d ms  AFTER-START ENRICH end   (UseMap1140 clr, iram[3Ch]=0x%02X)",
                     `DME_MS, `IRAM(3C));
        ph_usemap_prev <= `IRAM(21)[5];

        // FuelOffCoast  iram[23h].5
        if (`IRAM(23)[5] && !ph_fuelcut_prev)
            $display("DME: [PHASE] t=%0d ms  FUEL CUT begin               (FuelOffCoast set)", `DME_MS);
        if (!`IRAM(23)[5] && ph_fuelcut_prev)
            $display("DME: [PHASE] t=%0d ms  FUEL CUT end                 (FuelOffCoast clr)", `DME_MS);
        ph_fuelcut_prev <= `IRAM(23)[5];

        // LambdaOK  iram[24h].3
        if (`IRAM(24)[3] && !ph_lambdaok_prev)
            $display("DME: [PHASE] t=%0d ms  LAMBDA CONTROL begin         (LambdaOK set)", `DME_MS);
        if (!`IRAM(24)[3] && ph_lambdaok_prev)
            $display("DME: [PHASE] t=%0d ms  LAMBDA CONTROL end           (LambdaOK clr)", `DME_MS);
        ph_lambdaok_prev <= `IRAM(24)[3];

        // ColdStartEnrich  iram[25h].5
        if (`IRAM(25)[5] && !ph_coldenrich_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START ENRICH begin      (bit2Dh set)", `DME_MS);
        if (!`IRAM(25)[5] && ph_coldenrich_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START ENRICH end        (bit2Dh clr)", `DME_MS);
        ph_coldenrich_prev <= `IRAM(25)[5];

        // ColdStartTiming  iram[25h].4
        if (`IRAM(25)[4] && !ph_coldtiming_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START TIMING begin      (bit2Ch set)", `DME_MS);
        if (!`IRAM(25)[4] && ph_coldtiming_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START TIMING end        (bit2Ch clr)", `DME_MS);
        ph_coldtiming_prev <= `IRAM(25)[4];

        // ISVPWMOverflow  iram[20h].5
        if (`IRAM(20)[5] && !ph_isvovf_prev)
            $display("DME: [PHASE] t=%0d ms  ISV OVERFLOW begin           (isv_step=0x%02X)",
                     `DME_MS, `IRAM(7F));
        if (!`IRAM(20)[5] && ph_isvovf_prev)
            $display("DME: [PHASE] t=%0d ms  ISV OVERFLOW end             (isv_step=0x%02X)",
                     `DME_MS, `IRAM(7F));
        ph_isvovf_prev <= `IRAM(20)[5];

        // ── Periodic STATUS — every 100ms ─────────────────────────
        if (i8051_dashboard_tb.i8051_top.u_cpu.cycle_count >= ph_status_next_snap) begin
            cool_c_disp = (coolant_shadow == 8'hFF) ? 9999 : ntc_celsius(coolant_shadow);
            air_c_disp  = (airtemp_shadow == 8'hFF) ? 9999 : ntc_celsius(airtemp_shadow);
            $display("DME: [STATUS] t=%0d ms  prpm(37)=0x%02X (%0d RPM)  fuel_hb(4B)=0x%02X  fuel_lb(4A)=0x%02X  afm_raw(10)=0x%02X  afm_peak(3D)=0x%02X  load(46:47)=0x%02X%02X  load_idx(49)=0x%02X  coolant(13)=0x%02X (%0d degC)  airtemp(12)=0x%02X (%0d degC)  coolant_adc=0x%02X  airtemp_adc=0x%02X  dwell(2F)=0x%02X  timing_adv(31)=0x%02X  isv(7F)=0x%02X  wdog(2A)=0x%02X  B(F0)=0x%02X  wu(58:59)=0x%02X%02X  flags(21)=0x%02X (23)=0x%02X (25)=0x%02X",
                `DME_MS,
                `IRAM(37),
                `IRAM(37) * 40,
                `IRAM(4B),
                `IRAM(4A),
                afm_raw_shadow,
                `IRAM(3D),
                `IRAM(46), `IRAM(47),
                `IRAM(49),
                coolant_shadow, cool_c_disp,
                airtemp_shadow, air_c_disp,
                coolant_adc_in,
                airtemp_adc_in,
                `IRAM(2F),
                `IRAM(31),
                isv_shadow,
                `IRAM(2A),
                i8051_dashboard_tb.i8051_top.u_cpu.b_reg,
                `IRAM(58), `IRAM(59),
                `IRAM(21), `IRAM(23), `IRAM(25));
            ph_status_next_snap <= ph_status_next_snap + 64'd600_000;
            $fflush();
        end

    end
end

// ─── Watchdog stall detector ─────────────────────────────────
// Monitors iram[2Ah] continuously within each 500ms window.
// Sets ph_wdog_changed if the value changes at ANY clock edge
// during the window. Only fires warning if the value was completely
// static for the full window — ignores harmonic coincidences where
// the loop period divides evenly into the sample interval.
reg [7:0]  ph_wdog_last;
reg        ph_wdog_changed;
reg [63:0] ph_wdog_next_sample;
initial begin
    ph_wdog_last        = 8'hFF;
    ph_wdog_changed     = 1'b0;
    ph_wdog_next_sample = 64'd12_000_000;  // first check at 2000ms
end

always @(posedge clk) begin : wdog_stall_detect
    if (!rst) begin
        ph_wdog_last        <= 8'hFF;
        ph_wdog_changed     <= 1'b0;
        ph_wdog_next_sample <= 64'd12_000_000;
    end else begin
        // Detect any change within window
        if (`IRAM(2A) != ph_wdog_last) begin
            ph_wdog_changed <= 1'b1;
            ph_wdog_last    <= `IRAM(2A);
        end

        // At each window boundary, check and reset
        if (i8051_dashboard_tb.i8051_top.u_cpu.cycle_count >= ph_wdog_next_sample &&
            i8051_dashboard_tb.i8051_top.u_cpu.cycle_count > (1000 * `DME_FREQ)) begin
            if (!ph_wdog_changed)
                $display("DME: [PHASE] t=%0d ms  WARNING: WATCHDOG STALLED    (wdog=0x%02X)",
                         `DME_MS, `IRAM(2A));
            ph_wdog_changed     <= 1'b0;
            ph_wdog_next_sample <= ph_wdog_next_sample + 64'd12_000_000;
        end
    end
end
end // phase_status
endgenerate

// ----------------------------------------------------------------
//  Condition-cycle phase announcements (TEST_CL_CONDITION_CYCLE /
//  TEST_CL_CONDITION_CYCLE_IDLE) — announces each of the 6 segments
//  (air temp, coolant temp, altitude, cat, AC, battery) as it starts and ends,
//  so the log clearly marks what each upcoming window is testing.
//
//  Unlike the edge-detected phase messages above (which watch
//  firmware-internal signals via the cycle_count-derived clock), these
//  fire at fixed, known-in-advance simulation times matching the
//  #delay values in the dynamic signal / t0 / t1 sequencing above
//  exactly — plain #delay-based initial blocks are used here instead,
//  with `DME_MS for the displayed time (correct in both standalone
//  and DME_KLR_COMBINED configurations, unlike a raw $time/1_000_000
//  calculation, which would be wrong under DME_KLR_COMBINED's KLR
//  clock freq bleed).
//
//  Timing differs between the two variants (idle has no ~25-30s ramp
//  to wait through first) — selected internally below, matching the
//  TEST_CL_CONDITION_CYCLE_IDLE selection used for the actual signals.
initial if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
    if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
        #(64'd2_000_000_000);
    else
        #(64'd31_000_000_000);
        $display("DME: [PHASE] t=%0d ms  AIR TEMP test begin      (cold ~5C, airtemp_dynamic_cycle=0x68)", `DME_MS);
        #(64'd5_000_000_000);
        $display("DME: [PHASE] t=%0d ms  AIR TEMP test end        (back to nominal, airtemp_dynamic_cycle=0x50)", `DME_MS);
end

initial if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
    if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
        #(64'd9_000_000_000);
    else
        #(64'd38_000_000_000);
        $display("DME: [PHASE] t=%0d ms  COOLANT TEMP test begin  (cold ~5C, coolant_dynamic_cycle=0x68)", `DME_MS);
        #(64'd5_000_000_000);
        $display("DME: [PHASE] t=%0d ms  COOLANT TEMP test end    (back to nominal, coolant_dynamic_cycle=0x20)", `DME_MS);
end

initial if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
    if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
        #(64'd16_000_000_000);
    else
        #(64'd45_000_000_000);
        $display("DME: [PHASE] t=%0d ms  ALTITUDE test begin      (high altitude, altitude_dynamic_cycle=0x00)", `DME_MS);
        #(64'd5_000_000_000);
        $display("DME: [PHASE] t=%0d ms  ALTITUDE test end        (back to sea level, altitude_dynamic_cycle=0xF8)", `DME_MS);
end

initial if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
    if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
        #(64'd23_000_000_000);
    else
        #(64'd52_000_000_000);
        $display("DME: [PHASE] t=%0d ms  CAT test begin           (no cat fitted, T0=1)", `DME_MS);
        #(64'd5_000_000_000);
        $display("DME: [PHASE] t=%0d ms  CAT test end             (cat fitted, T0=0)", `DME_MS);
end

initial if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
    if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
        #(64'd30_000_000_000);
    else
        #(64'd59_000_000_000);
        $display("DME: [PHASE] t=%0d ms  AC test begin            (compressor on, T1=1)", `DME_MS);
        #(64'd5_000_000_000);
        $display("DME: [PHASE] t=%0d ms  AC test end              (compressor off, T1=0)", `DME_MS);
end

initial if (`OPT_CL_CONDITION_CYCLE_ACTIVE) begin
    if (`OPT_TEST_CL_CONDITION_CYCLE_IDLE)
        #(64'd37_000_000_000);
    else
        #(64'd66_000_000_000);
        $display("DME: [PHASE] t=%0d ms  BATTERY test begin       (reduced ~20%%, battery_dynamic_cycle=0xAD)", `DME_MS);
        #(64'd5_000_000_000);
        $display("DME: [PHASE] t=%0d ms  BATTERY test end         (back to nominal, battery_dynamic_cycle=0xD8)", `DME_MS);
end


// ─── Dead-code entry ────────────────────────────────────────
// Warns when the DME PC enters one of the dead-code ranges listed in
// dme_dead_code.vh (edit that file to change them). Checked at each
// instruction fetch; logs on entry (PC was outside that range on the
// previous instruction), naming the instruction it came from. After
// DEADCHK_MAX entries of one range, further entries there are not logged
// (the last logged one says so).
`define DEADCHK_MAX 5
reg  [15:0] deadchk_prev_pc  = 16'hFFFF;
integer     deadchk_prev_idx = 0;
integer     deadchk_n [0:63];
initial begin : deadchk_init
    integer i;
    for (i = 0; i < 64; i = i + 1) deadchk_n[i] = 0;
end
// ── Injector firings ──────────────────────────────────────────
// Every fire_inj passes ROM 01D2h (clr P1.0), both the normal path from
// 01BEh and the held-open reload from 0154h. The ext0 handler skips it
// (jc 01DEh at 016Eh) on a fuel cut (23h.5) or above the rev limit
// (ENGINE_RPM_RAW 37h > ROM 1171h, 6480 rpm) -- the rev limit sets no
// flag, so the engine and O2 models count firings instead of reading
// 23h.5. Same address in the 86, 89 and performance images.
integer     inj_fire_count = 0;
reg  [63:0] inj_fire_t  = 0;   // $time of the last firing
reg  [63:0] inj_fire_dt = 0;   // interval between the last two
reg         inj_at_fire = 1'b0;
always @(posedge i8051_top.u_cpu.clk) begin : inj_fire_counter
    if (i8051_top.u_cpu.res_n && i8051_top.u_cpu.osc_cnt == 4'd5 &&
        !i8051_top.u_cpu.cycle_2 && !i8051_top.u_cpu.irq_pending) begin
        if (i8051_top.u_cpu.pc == 16'h01D2 && !inj_at_fire) begin
            inj_fire_count <= inj_fire_count + 1;
            inj_fire_dt    <= (inj_fire_t != 0) ? $time - inj_fire_t : 0;
            inj_fire_t     <= $time;
        end
        inj_at_fire <= (i8051_top.u_cpu.pc == 16'h01D2);
    end
end
// Fuel not going in: a fuel cut (23h.5), or no firing for more than 2 of
// the usual firing intervals (the rev limiter). Feeds the KLR's turbo
// model in the combined build.
reg inj_skipping = 1'b0;
always #10_000 inj_skipping = i8051_top.u_cpu.iram[7'h23][5] === 1'b1 ||
                              (inj_fire_dt != 0 && $time - inj_fire_t > 2 * inj_fire_dt);
always @(posedge i8051_top.u_cpu.clk) begin : dead_code_check
    reg [15:0] pc;
    integer    idx, n;
    reg [15:0] lo, hi;
    reg [8*96-1:0] desc;
    if (i8051_top.u_cpu.res_n && i8051_top.u_cpu.osc_cnt == 4'd5 &&
        !i8051_top.u_cpu.cycle_2 && !i8051_top.u_cpu.irq_pending) begin
        pc = i8051_top.u_cpu.pc;
        idx = 0; n = 0; lo = 0; hi = 0; desc = "";
`define DEAD_CODE(l, h, d) n = n + 1; if (idx == 0 && pc >= l && pc <= h) begin idx = n; lo = l; hi = h; desc = d; end
`include "dme_dead_code.vh"
`undef DEAD_CODE
        if (idx != 0 && idx != deadchk_prev_idx) begin
            deadchk_n[idx] = deadchk_n[idx] + 1;
            if (deadchk_n[idx] <= `DEADCHK_MAX)
                $display("DME: [WARN] t=%0d ms  dme dead code entry at %04X (%04X-%04X %0s) from %04X%0s",
                         `DME_MS, pc, lo, hi, desc, deadchk_prev_pc,
                         deadchk_n[idx] == `DEADCHK_MAX ? "  [further entries to this range not logged]" : "");
        end
        deadchk_prev_idx = idx;
        deadchk_prev_pc  = pc;
    end
end

// ─── Injector pulse width vs crank revolution ───────────────
// fire_inj fires the injectors once per crank rev, loading Timer 0 with
// FUEL_PULSE (4A:4B) + 5 x INJ_DEADTIME (54h) counts at 2 us each. A
// command longer than one rev can't be delivered (fire_inj just extends
// T0 and the injector stays open), so warn. Checked once per rev on the
// reference-sensor edge, skipped during fuel cut; logs when the condition
// starts and again when it clears, not every rev.
time    injchk_prev_ref = 0;
reg     injchk_over     = 1'b0;
integer injchk_revs     = 0;
real    injchk_max_ms   = 0.0;
always @(negedge reference_sensor_gen) begin : inj_pw_check
    real rev_ms, pw_ms;
    if (injchk_prev_ref != 0 && !`IRAM(23)[5]) begin
        rev_ms = ($time - injchk_prev_ref) / 1.0e6;
        pw_ms  = ({`IRAM(4B), `IRAM(4A)} + 5 * `IRAM(54)) * 0.002;
        if (pw_ms > rev_ms) begin
            if (!injchk_over)
                $display("DME: [WARN] t=%0d ms  INJ PW %0.3f ms > one rev %0.3f ms (%0d rpm)  4A:4B=0x%02X%02X dead(54h)=0x%02X",
                         `DME_MS, pw_ms, rev_ms, $rtoi(60000.0 / rev_ms),
                         `IRAM(4B), `IRAM(4A), `IRAM(54));
            injchk_over   = 1'b1;
            injchk_revs   = injchk_revs + 1;
            if (pw_ms > injchk_max_ms) injchk_max_ms = pw_ms;
        end else if (injchk_over) begin
            $display("DME: [WARN] t=%0d ms  INJ PW back within one rev  (over for %0d revs, max %0.3f ms)",
                     `DME_MS, injchk_revs, injchk_max_ms);
            injchk_over   = 1'b0;
            injchk_revs   = 0;
            injchk_max_ms = 0.0;
        end
    end
    injchk_prev_ref = $time;
end

endmodule
