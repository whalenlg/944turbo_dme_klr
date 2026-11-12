// ============================================================
//  test_opts.vh  —  the regression tests' options
//
//  Each test is a set of -D flags (run_test <name> -DTEST_... in
//  run_dashboard_tests.sh / v_run_dashboard_tests.sh). The TEST_* blocks
//  below turn a test's flags into the options the testbench reads
//  (RPMRAMP, SIM_TIME, _COOLANT_RAW, ...); flags derived from other
//  flags (CL_ISV_AIR, CL_THROTTLE_CLOSED, ...) are worked out here too,
//  so every file sees each option the same way.
//
//  Included first (dme_klr/files, files_cl: test_opts.v right after
//  klr_defs.v) and again by i8051_dashboard_tb.v for a build without
//  those lists; the guard keeps it to once.
//
//  test_opts_gen.vh (written by dme_klr/test_opts.py gen) then gives each
//  option a form the code uses: `OPT_X for a flag, `VAL_X for a value.
//  In a normal build those are the -D flags; in a RUNTIME_OPTS build
//  (one binary for every test) they are read from +X=<n> at run time,
//  and dme_klr/test_opts.py plusargs <test> prints a test's.
// ============================================================
`ifndef TEST_OPTS_VH
`define TEST_OPTS_VH
// ============================================================
//  TEST SELECTION — uncomment one or pass via -DTEST_xxx
// ============================================================

// --- Idle tests ---
//`define TEST_WARM_IDLE
//`define TEST_WARM_IDLE_5S
//`define TEST_COLD_START
//`define TEST_HOT_IDLE
//`define TEST_IDLE_BATTERY_LOW
//`define TEST_IDLE_HIGH_ALT
//`define TEST_IDLE_POOR_FUEL
//`define TEST_AC_ON_IDLE
//`define TEST_CL_RAMP_TO_3000
//`define TEST_CL_RAMP_TO_6000
//`define TEST_CL_RAMP_TO_REDLINE
//`define TEST_CL_AC_HALFWAY
//`define TEST_CL_COLD_START

// --- Fuel transient tests ---
//`define TEST_TIPPY_IN
//`define TEST_OVERRUN_CUTOFF
//`define TEST_WARMUP_ENRICHMENT
//`define TEST_AFM_OPEN_CIRCUIT

// --- RPM sweep tests ---
//`define TEST_RAMP_TO_3000
//`define TEST_RAMP_TO_6000
//`define TEST_RAMP_TO_REDLINE
//`define TEST_RAMP_6K_HOLD

// --- Sensor failure tests ---
//`define TEST_COOLANT_FAIL
//`define TEST_AIRTEMP_FAIL
//`define TEST_O2_DISCONNECTED
//`define TEST_O2_RICH_STUCK
//`define TEST_O2_LEAN_STUCK
//`define TEST_TPS_FAIL
//`define TEST_ALTITUDE_DISCONNECTED
//`define TEST_FUEL_QUAL_DISCONNECTED
//`define TEST_REF_SENSOR_LOSS
//`define TEST_SPEED_SENSOR_LOSS

// --- Ignition tests ---
//`define TEST_IGNITION_TIMING
//`define TEST_DWELL_SCALING

// --- ISV / idle speed control tests ---
//`define TEST_ISV_COLD_IDLE
//`define TEST_ISV_LOAD_DROOP

// ============================================================
//  Common sim parameters
// ============================================================
`ifndef SIM_TIME
  `define SIM_TIME     80000000000
`endif
`ifndef RPMSTART
  `define RPMSTART     100
`endif
`ifndef RPMEND
  `define RPMEND       840
`endif
`ifndef RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
`endif
`ifndef DASH_INTERVAL_MS
  `define DASH_INTERVAL_MS 100
`endif

// ============================================================
//  Per-test parameter overrides (identical to i8051_dashboard_tb.v)
// ============================================================

// Warm idle: the live dashboard's defaults (LivePanel hints), so the
// scripted tests and a live session run the same engine. Raw ADC values;
// the firmware linearises them in place into 13h/12h.
//   coolant 0x31 ~ 85 C (185 F)    air temp 0x9E ~ 20 C (68 F)
// (Until 2026-10 the tests used coolant 0x20 ~ 103 C and air 0x50 ~ 62 C.)
`define WARM_COOLANT_RAW 8'h31
`define WARM_AIRTEMP_RAW 8'h9E

`ifdef TEST_WARM_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 10
  `ifndef SIM_TIME
  `define SIM_TIME  60000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_WARM_IDLE_5S: same idle target as TEST_WARM_IDLE, but with the
// RPM_RAMP_PCT=25 / SIM_TIME=5s the sensor-fault idle tests (coolant_fail,
// airtemp_fail, afm_open_circuit, tps_fail) all use — a plain -D override
// of warm_idle's own RPM_RAMP_PCT doesn't work since that block sets it
// unconditionally (not `ifndef`-guarded), so it needs its own macro to
// give a directly comparable baseline log for those 4 tests.
`ifdef TEST_WARM_IDLE_5S
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_COLD_START
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  120000000000
  `endif
  `define _COOLANT_RAW  8'hC0
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_HOT_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  25000000000
  `endif
  `define _COOLANT_RAW  8'h10
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_IDLE_BATTERY_LOW
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'h8C
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_IDLE_HIGH_ALT
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'h00
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_ALTITUDE_DISCONNECTED: altitude sensor wire open/pulled to the
// 5V rail (0xFF), rather than a plausible reading anywhere in the real
// sensor's range (0x00=high altitude .. 0xF8=sea level nominal per
// TEST_IDLE_HIGH_ALT/baseline above — 0xFF is past the sea-level end,
// an implausible "below sea level" reading a real barometric sensor
// could never produce). No KLR involvement — altitude is DME-only,
// unlike TPS/battery, so no DTC is expected here.
`ifdef TEST_ALTITUDE_DISCONNECTED
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hFF
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_IDLE_POOR_FUEL previously had no distinguishing config at all —
// identical to TEST_WARM_IDLE's baseline, so the test could never fail
// regardless of whether any fuel-quality handling actually worked.
// _FUEL_QUAL now defaults to 0xA7, the same worst-quality value already
// calibrated and validated by the ramp_to_*_FQS7 / cl_ramp_to_*_FQS7
// family (see run_dashboard_tests.sh) — reusing a real, exercised value
// rather than guessing a new one.
`ifdef TEST_IDLE_POOR_FUEL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'hA7
  `endif
`endif

// TEST_FUEL_QUAL_DISCONNECTED: fuel quality ADC pegged at 0xFF (open
// circuit / pulled to the 5V rail) — past the FQS7 ceiling (0xA7, the
// worst real fuel-quality value the FQS0-7 sweep calibrates), a
// reading no real fuel-quality sensor could produce. Distinct from
// idle_poor_fuel's plausible-but-worst-case 0xA7. No KLR involvement
// (fuel quality is DME-only), so no DTC is expected here.
`ifdef TEST_FUEL_QUAL_DISCONNECTED
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'hFF
  `endif
`endif

// TEST_REF_SENSOR_LOSS: reference (crank position) sensor wire breaks
// partway through the test — see the reference_sensor override near
// the RPM/crank generator instantiation below for the actual
// mechanism (P3.2/INT0 stops seeing pulses from REF_LOSS_T_MS onward,
// while the underlying engine model keeps running normally). Longer
// SIM_TIME than the other idle sensor-fault tests (8s vs 5s) to leave
// a real post-fault observation window after the loss kicks in at
// REF_LOSS_T_MS=3500 (well after ASE end, ~1.5-2.7s in the sibling
// tests).
`ifdef TEST_REF_SENSOR_LOSS
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  8000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
  `define REF_LOSS_T_MS 3500
`endif

// TEST_SPEED_SENSOR_LOSS: same idea as TEST_REF_SENSOR_LOSS, but for
// the speed/tooth sensor (P3.3/INT1) instead — see the speed_sensor
// override near the RPM/crank generator instantiation below.
`ifdef TEST_SPEED_SENSOR_LOSS
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  8000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
  `define SPEED_LOSS_T_MS 3500
`endif

`ifdef TEST_AC_ON_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AC_COMP_ON                 // T1=1: AC compressor active
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  10000000000      // 10s — enough to see ISV and fuel response to AC load
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW        // warm engine
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_CL_RAMP_TO_2100: same structure as TEST_CL_RAMP_TO_3000, for a
// lower operating point below it. (Originally targeted 2000rpm as
// TEST_CL_RAMP_TO_2000 — renamed to 2100 when the target itself moved,
// keeping the macro name matching its actual target like every other
// test in this family.)
//
// CALIBRATION HISTORY:
//   0x53 (1st attempt, target was 2000rpm) — linearly interpolated
//   between the two nearest real anchors then available: idle (840rpm,
//   AFM=0x28/40) and the 3000-family's own real settling point
//   (2853rpm, AFM=0x72/114). Actual result: ~1794rpm — undershot by
//   ~206rpm (~10%), confirming real local nonlinearity in this region
//   (same pattern the TEST_CL_RAMP_TO_4500 calibration history hit and
//   warns about).
//   0x59 (2nd attempt, target was still 2000rpm) — refined by directly
//   bracketing between the 1st attempt's own real result (1794rpm,
//   AFM=0x53/83) and the 3000-family anchor (2853rpm, AFM=0x72/114):
//   local slope ~0.0293 AFM-counts/rpm. Actual result: ~1944rpm — much
//   closer, confirming the bracketing-refinement approach.
//   0x5F (FINAL, target moved to 2100rpm) — extrapolated using the two
//   most recent real points, now bracketing more tightly and locally
//   than the distant 3000-family anchor: (1794rpm, AFM=0x53/83) and
//   (1944rpm, AFM=0x59/89), local slope ~0.04 AFM-counts/rpm. This is
//   an EXTRAPOLATION (2100 is above both real anchors, not between
//   them), so somewhat less reliable than the earlier interpolations —
//   still unverified against a real run; refine again the same way
//   (bracket the two nearest real points) if it's meaningfully off.
`ifdef TEST_CL_RAMP_TO_2100
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'h5F      // ~2100 RPM (REFINED — see calibration history above)
  `ifndef SIM_TIME
  `define SIM_TIME  30000000000     // 30s — matches the 3000-family's duration
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_CL_RAMP_TO_3000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `ifndef AFM_CL_TARGET               // a -DAFM_CL_TARGET on the command line wins
  `define AFM_CL_TARGET  8'h72      // 3000 RPM → ADC≈0x72 (114)
  `endif
  `ifndef SIM_TIME
  `define SIM_TIME  30000000000     // 30s — RPM climbs ~670/13s, needs ~25s to reach 3000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_CL_RAMP_TO_4500: same structure as TEST_CL_RAMP_TO_3000/_6000, for
// an intermediate operating point between the two. AFM_CL_TARGET=0x9A has
// been empirically verified — settles at ~4530rpm (0.7% over the 4500
// nominal target), well within normal margin. var_interrupt_gen_cl.v's
// own header explicitly warns that the friction curve (quadratic below
// CL_FRICTION_HIGHRPM_THRESHOLD=4000rpm, cubic above) was only originally
// calibrated against 3 real points (idle, ~2853rpm/AFM=0x72, ~6650rpm/
// AFM=0xD8) and that a 4th test between those two "likely need[s]
// re-verification" — this is that re-verification, done empirically
// below rather than by retuning the curve itself.
//
// CALIBRATION HISTORY (kept for reference — the curve genuinely is
// nonlinear in this region, confirming the header's warning was correct):
//   0x83 (1st attempt) — derived by solving the documented friction
//   equations for the combustion value giving a 4500rpm equilibrium, then
//   interpolating AFM vs combustion between the two real anchors.
//   Actual result: ~3500rpm, ~56.9% throttle.
//   0xA1 (2nd attempt) — refined using the 0x83 result and the distant
//   6000-family anchor (~33.6 rpm/AFM-count slope).
//   Actual result: ~4800rpm, ~63% throttle — overshot, but also confirmed
//   ram[0x43]/throttle% genuinely tracks AFM (56.9%->63% between these
//   two runs) — the earlier plateau near 0x83 was just too small an AFM
//   delta to show separation, not a bug.
//   0x9A (FINAL) — refined by directly bracketing between the two real
//   points above, (AFM=131,~3500rpm) and (AFM=161,~4800rpm): local slope
//   ~43.3 rpm/AFM-count — steeper than the 2nd attempt's distant-anchor
//   slope, confirming real local nonlinearity, consistent with the
//   header's warning. VERIFIED result: ~4530rpm, ~59% throttle.
`ifdef TEST_CL_RAMP_TO_4500
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'h9A      // ~4500 RPM — VERIFIED, settles ~4530rpm (see note above)
  `ifndef SIM_TIME
  `define SIM_TIME  35000000000     // 35s — between the 30s/40s used for 3000/6000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_CL_RAMP_TO_5000: same structure as TEST_CL_RAMP_TO_3000/_4500/_6000.
// AFM_CL_TARGET=0xA6 is an ESTIMATE — interpolated from the two closest
// REAL, empirically-observed bracketing points from the 4500 calibration
// work: AFM=0x9A(154)->~4530rpm (verified) and AFM=0xA1(161)->~4800rpm
// (observed). Local slope ~38.57 rpm/AFM-count; both anchors agree
// exactly on 0xA6(166) for a 5000rpm target. Still unverified against a
// real run — check the actual settled RPM in the resulting log and
// refine the same way TEST_CL_RAMP_TO_4500 was (see its revision history
// above) if it's meaningfully off.
`ifdef TEST_CL_RAMP_TO_5000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'hA6      // ~5000 RPM (ESTIMATED — see note above)
  `ifndef SIM_TIME
  `define SIM_TIME  35000000000     // 35s — matching the 4500-family's duration
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_CL_CONDITION_CYCLE: closed-loop ramp to 3000rpm (same as
// TEST_CL_RAMP_TO_3000 above — same AFM_CL_TARGET, same ~25-30s ramp
// time), then six sequential 7-second condition-cycle phases, each
// 1s nominal / 5s test-condition-active / 1s nominal:
//   t=30-37s: air temp  -> 0x68 (~5C, same cold value as TEST_ISV_COLD_IDLE)
//   t=37-44s: coolant   -> 0x68 (~5C, same cold value as TEST_ISV_COLD_IDLE)
//   t=44-51s: altitude  -> 0x00 (high altitude, same as TEST_IDLE_HIGH_ALT)
//   t=51-58s: cat (T0)  -> 1 (no cat fitted)
//   t=58-65s: AC (T1)   -> 1 (AC compressor on)
//   t=65-72s: battery   -> 0xAD (~20% reduced from nominal 0xD8)
// Phases run sequentially, not simultaneously — only one condition is
// ever active at a time, bookended by nominal baseline on each side so
// the response to each individual change (and recovery back to
// nominal) is separately observable. See the dynamic signal
// declarations near coolant_dynamic/t0/t1 below for the actual timed
// sequencing, and the adc_mux section for how each dynamic signal
// gets wired to its ADC channel.
`ifdef TEST_CL_CONDITION_CYCLE
  `define CL_CONDITION_CYCLE_ACTIVE  // shared marker — see dynamic signal
                                      // declarations, t0/t1, and adc_mux
                                      // wiring below, which key off this
                                      // rather than either specific flag,
                                      // so TEST_CL_CONDITION_CYCLE and
                                      // TEST_CL_CONDITION_CYCLE_IDLE share
                                      // one set of signal declarations
                                      // (with different timing selected
                                      // internally by whichever flag is
                                      // actually active).
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'h72      // 3000 RPM target, same as TEST_CL_RAMP_TO_3000
  `ifndef SIM_TIME
  `define SIM_TIME  73000000000     // 73s — ~30s ramp/settle + 6x7s phases + 1s buffer
  `endif
  `define _COOLANT_RAW  8'h20       // nominal (warm) baseline — overridden dynamically
                                     // during the coolant-temp phase, see coolant_dynamic_cycle
  `define _AIRTEMP_RAW  8'h50       // nominal baseline — overridden dynamically during
                                     // the air-temp phase, see airtemp_dynamic_cycle
  `define _BATTERY      8'hD8       // nominal baseline — overridden dynamically during
                                     // the battery phase, see battery_dynamic_cycle
  `define _ALTITUDE     8'hF8       // nominal (sea-level) baseline — overridden dynamically
                                     // during the altitude phase, see altitude_dynamic_cycle
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_CL_CONDITION_CYCLE_IDLE: same 6-phase condition cycle as
// TEST_CL_CONDITION_CYCLE, but held at idle instead of ramped to
// 3000rpm — no AFM_CL_RAMP/AFM_CL_TARGET, matching how cl_warm_idle
// itself is built (RPMRAMP+CL_MODE, no ramp override — the closed
// loop just settles at idle on its own). No ~25-30s ramp to wait
// through, so the phases start much sooner (t=2s, past fuel
// cut/ASE, vs t=30s for the ramped version):
//   t=2-9s:   air temp  -> 0x68 (~5C)
//   t=9-16s:  coolant   -> 0x68 (~5C)
//   t=16-23s: altitude  -> 0x00 (high altitude)
//   t=23-30s: cat (T0)  -> 1 (no cat fitted)
//   t=30-37s: AC (T1)   -> 1 (AC compressor on)
//   t=37-44s: battery   -> 0xAD (~20% reduced from nominal 0xD8)
`ifdef TEST_CL_CONDITION_CYCLE_IDLE
  `define CL_CONDITION_CYCLE_ACTIVE  // see note on the marker above
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `ifndef SIM_TIME
  `define SIM_TIME  47000000000     // 47s — 2s settle + 6x7s phases + 3s buffer
  `endif
  `define _COOLANT_RAW  8'h20       // nominal (warm) baseline — overridden dynamically
  `define _AIRTEMP_RAW  8'h50       // nominal baseline — overridden dynamically
  `define _BATTERY      8'hD8       // nominal baseline — overridden dynamically during
                                     // the battery phase, see battery_dynamic_cycle
  `define _ALTITUDE     8'hF8       // nominal (sea-level) baseline — overridden dynamically
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif



`ifdef TEST_CL_RAMP_TO_6000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'hD8      // 6000 RPM → capped at 0xD8 (was 0xDA;
                                     // 0xDA let the closed loop converge
                                     // too high — see var_interrupt_gen_cl.v)
  `ifndef SIM_TIME
  `define SIM_TIME  40000000000     // 40s — higher RPM needs more time
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_CL_RAMP_TO_REDLINE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'hEB      // 6500 RPM → ADC=0xEB (235, max)
  `ifndef SIM_TIME
  `define SIM_TIME  40000000000     // 40s
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_CL_AC_HALFWAY
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define CL_AC_HALFWAY              // T1 switches on at SIM_TIME/2 (~10s)
  `ifndef SIM_TIME
  `define SIM_TIME  20000000000     // 20s — 10s pre-AC, 10s with AC
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_CL_IDLE_CONTROLLED_BY_ISV: cl_ac_halfway (warm closed-loop idle,
// AC on at SIM_TIME/2) with CL_ISV_AIR, so the ISV's bypass air reaches
// the AFM and the firmware's idle-speed control can pull RPM back after
// the AC load step instead of the engine just settling lower.
`ifdef TEST_CL_IDLE_CONTROLLED_BY_ISV
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define CL_ISV_AIR
  `define CL_AC_HALFWAY              // T1 switches on at SIM_TIME/2
  `ifndef SIM_TIME
  `define SIM_TIME  45000000000     // 45s — 22.5s settle, 22.5s with AC
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_CL_COLD_START
  `define RPMRAMP
  `define CL_MODE                    // no SKIP_LAMBDA_WARMUP — genuine cold start
  // Genuine cranking ramp (100->840 RPM over ~30s) instead of the CL
  // generator's default instant-idle start — auto-enabled by
  // var_interrupt_gen_cl.v itself from TEST_CL_COLD_START (see the
  // CL_RPM_CRANK_RAMP header comment there for why it's not defined
  // here directly — this file compiles too late in the file list for
  // an in-source `define here to reach that file's own `ifdef).
  `ifndef SIM_TIME
  `define SIM_TIME  60000000000     // 60s — observe cold enrichment decay
  `endif
  `define _COOLANT_RAW  8'hC0       // cold — above 0x8F threshold for cold-start enrich
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_TIPPY_IN
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AFM_TIPPY                  // enables step-change AFM override for accel enrichment
  `undef  RPMEND
  `define RPMEND    840              // hold at idle — AFM spike drives enrichment, not RPM
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 10
  `ifndef SIM_TIME
  `define SIM_TIME  20000000000      // 20s — DFCO decay after the AFM spike
                                      // needs more than 10s to fully return
                                      // to idle before steady-state is judged
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// TEST_OVERRUN_CUTOFF: real deceleration fuel cut-off. Driver holds the
// throttle open long enough to settle near 2100rpm (AFM_CL_TARGET=0x5F,
// same calibrated target as TEST_CL_RAMP_TO_2100 — comfortably above the
// real DME's ~1350-1600rpm cutoff-engage threshold), then lifts off
// completely at t=32s. That closes the idle switch while RPM is still
// well above the cutoff band, so the firmware should set FuelOffCoast
// (iram[23h].5) and cut injection; the CL physics model lets RPM coast
// down under friction alone while that bit is set (see var_interrupt_
// gen_cl.v), same as a real engine decelerating with no combustion
// torque. The firmware is expected to clear FuelOffCoast again near the
// real ~900-1200rpm reintroduction band and let RPM restabilize at idle.
`ifdef TEST_OVERRUN_CUTOFF
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'h5F      // ~2100 RPM — see header note above
  `ifndef SIM_TIME
  `define SIM_TIME  50000000000     // 2s idle + 30s ramp/hold open + throttle
                                     // closes at t=32s + ~18s coast-down/
                                     // fuel-reintroduction/re-settle at idle
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_WARMUP_ENRICHMENT
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  60000000000
  `endif
  `define _COOLANT_RAW  8'hC0
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_AFM_OPEN_CIRCUIT
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AFM_FAULT
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_COOLANT_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  8'h00   // shorted NTC: 0V → ADC 0x00 → firmware linearises to 0xFB=104°C hot
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_AIRTEMP_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  8'h00   // shorted NTC: 0V → ADC 0x00 → firmware linearises to 0xFB=104°C hot air
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_O2_DISCONNECTED
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define O2_FLAT_DISCONNECTED
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  25000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_O2_RICH_STUCK
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define O2_FLAT_RICH
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  25000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_O2_LEAN_STUCK
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define O2_FLAT_LEAN
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  25000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_TPS_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define TPS_FIXED 8'h80
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  5000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_RAMP_TO_3000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    3000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 50
  `ifndef SIM_TIME
  `define SIM_TIME  10000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_RAMP_TO_6000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
  `ifndef SIM_TIME
  `define SIM_TIME  10000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_RAMP_TO_REDLINE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6500
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
  `ifndef SIM_TIME
  `define SIM_TIME  10000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_RAMP_6K_HOLD
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
  `ifndef SIM_TIME
  `define SIM_TIME  15000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_IGNITION_TIMING
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 50
  `ifndef SIM_TIME
  `define SIM_TIME  15000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_DWELL_SCALING
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 80
  `ifndef SIM_TIME
  `define SIM_TIME  15000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_ISV_COLD_IDLE
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  60000000000
  `endif
  `define _COOLANT_RAW  8'h60
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

`ifdef TEST_ISV_LOAD_DROOP
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define ISV_LOAD_DROOP
  `undef  RPMEND
  `define RPMEND    840
  `ifndef SIM_TIME
  `define SIM_TIME  12000000000
  `endif
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
  `endif
`endif

// ============================================================
//  ADC channel defaults
// ============================================================
`ifndef _COOLANT_RAW
  `define _COOLANT_RAW  `WARM_COOLANT_RAW
`endif
`ifndef _AIRTEMP_RAW
  `define _AIRTEMP_RAW  `WARM_AIRTEMP_RAW
`endif
`ifndef _BATTERY
  `define _BATTERY      8'hD8
`endif
`ifndef _ALTITUDE
  `define _ALTITUDE     8'hF8
`endif
`ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h00
`endif

// ============================================================
//  Flags derived from the others
//  (worked out here, before any file that reads them, so every file
//  reads them the same way, as `OPT_X)
// ============================================================

// var_interrupt_gen_cl.v / i8051_dashboard_tb.v: every closed-loop build
// runs the ISV's bypass air. Not cl_cold_start: its RPM is the scripted
// crank ramp (CL_RPM_CRANK_RAMP), which ISV air can't raise, so the idle
// loop winds the ISV open during the 30 s crank and its air would triple
// the fuel at idle.
`ifdef CL_MODE
  `ifndef TEST_CL_COLD_START
    `ifndef CL_ISV_AIR
      `define CL_ISV_AIR
    `endif
  `endif
`endif

// CL_THROTTLE_CLOSED: closed-loop idle builds on the engine model
// (cl_warm_idle, cl_ac_halfway, cl_cold_start, cl_condition_cycle_idle,
// cl_idle_controlled_by_isv) have no driver throttle, so the throttle is
// closed. A closed throttle is choked: the air it passes barely changes
// with RPM, so the AFM sits at the idle base (plus the ISV's bypass air)
// instead of following var_interrupt_gen_cl.v's RPM curve, which is the
// air a ramp's opening throttle lets in. Following RPM there made extra
// fuel a runaway: more RPM -> more AFM -> more load per stroke -> more
// fuel. With the air fixed, more RPM means less load per stroke, which
// is the engine's own negative feedback. i8051_dashboard_tb.v also holds
// the throttle switch and the KLR's throttle angle closed in these
// builds. (Commanded-throttle builds: AFM_CL_RAMP ramps, tippy, live.)
`ifdef CL_MODE
`ifndef AFM_CL_RAMP
`ifndef LIVE
`ifndef TEST_TIPPY_IN
`ifndef AFM_FAULT
  `define CL_THROTTLE_CLOSED
`endif
`endif
`endif
`endif
`endif

// var_interrupt_gen_cl.v: cl_cold_start's crank ramp
`ifdef TEST_CL_COLD_START
  `ifndef CL_RPM_CRANK_RAMP
    `define CL_RPM_CRANK_RAMP
  `endif
`endif

// i8051_dashboard_tb.v: the AFM comes from the engine model (afm_wiper)
`ifndef LIVE
`ifndef AFM_FAULT
`ifndef AFM_CL_RAMP
`ifndef AFM_TIPPY
  `define AFM_FROM_ENGINE_MODEL
`endif
`endif
`endif
`endif

// Sensor-loss times (i8051_dashboard_tb.v): REF_SENSOR_STUCK_LOW and
// SPEED_SENSOR_STUCK_LOW default to 3.5 s, as TEST_REF_SENSOR_LOSS and
// TEST_SPEED_SENSOR_LOSS set above
`ifndef REF_LOSS_T_MS
  `define REF_LOSS_T_MS 3500
`endif
`ifndef SPEED_LOSS_T_MS
  `define SPEED_LOSS_T_MS 3500
`endif

`include "test_opts_gen.vh"

`endif // TEST_OPTS_VH
