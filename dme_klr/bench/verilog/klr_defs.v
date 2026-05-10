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
`define FREQ       11000    // KLR crystal frequency in kHz  (11 MHz)
`define FRQ_SCALE  500000   // half-period scale (ns × kHz); DELAY = FRQ_SCALE/FREQ

// ── RPM sweep (used by var_timing_generator localparams) ─
`define RPMSTART   840      // idle RPM  (sweep start)
`define RPMEND     6500     // redline   (sweep end)
`define RPMCONST   2727272  // 6 MHz × 60 / 132 teeth

// ── Simulation run time ───────────────────────────────────
`define SIM_TIME   3000000000  // 10000 ms (10 s) in ns — 10× the previous 1 s

// ── VCD hierarchy paths ───────────────────────────────────
//  Used by klr_vcd.v to resolve hierarchical references.
//  Override these in the top-level TB for combined DME+KLR mode.
//  Standalone KLR:  klr_tb.top  (klr_system instance named `top`)
//  Combined mode:   dme_klr_tb.u_klr.top  (defined in dme_klr_tb.v)
`ifndef KLR_TB_PATH
  `define KLR_TB_PATH     klr_tb.top
`endif
`ifndef KLR_TOP_TB
  `define KLR_TOP_TB      klr_tb
`endif
`ifndef KLR_DUMPVCD_PATH
  `define KLR_DUMPVCD_PATH klr_tb.u_dumpvcd
`endif

// ── DME VCD hierarchy paths ───────────────────────────────
`ifndef DME_TB_PATH
  `define DME_TB_PATH      i8051_tb.top
`endif
`ifndef DME_TOP_TB
  `define DME_TOP_TB       i8051_tb
`endif
`ifndef DME_DUMPVCD_PATH
  `define DME_DUMPVCD_PATH i8051_tb.u_dumpvcd
`endif
