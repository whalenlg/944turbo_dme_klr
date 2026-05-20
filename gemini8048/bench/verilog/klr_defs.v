// ============================================================
//  klr_defs.v  —  Global compile-time defines for the KLR build
//
//  Must be the FIRST file in the iverilog command line so that
//  `define macros are resolved before var_timing_gen.v and
//  any other file that uses them as localparam values.
//
//  iverilog compile order:
//    iverilog -o klr.vvp -s klr_tb \
//      klr_defs.v        ← always first
//      timescale.v       \
//      i8048_core.v      \
//      adc_8090.v        \
//      adc_delay.v       \
//      var_timing_gen.v  \
//      klr_top.v         \
//      klr_vcd.v         \
//      klr_tb.v
// ============================================================

// ── Oscillator ───────────────────────────────────────────
`define KLR_FREQ   11000    // KLR crystal frequency in kHz  (11 MHz)
`ifndef FRQ_SCALE
  `define FRQ_SCALE  500000   // half-period scale (ns × kHz); DELAY = FRQ_SCALE/FREQ
`endif

// ── RPM sweep (used by var_timing_generator localparams) ─
`ifndef RPMSTART
  `define RPMSTART   840      // KLR idle RPM — override with -DRPMSTART=<rpm>
`endif
`ifndef RPMEND
  `define RPMEND     6500     // KLR redline  — override with -DRPMEND=<rpm>
`endif
`define RPMCONST   2727272  // 6 MHz × 60 / 132 teeth

// ── Simulation run time ───────────────────────────────────
`ifndef SIM_TIME
  `define SIM_TIME   10000000000  // default 10s; override with -DSIM_TIME=<ns>
`endif
