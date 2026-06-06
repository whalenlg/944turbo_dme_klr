// ============================================================
//  dme_klr_tb.v  —  Porsche 944 Turbo DME + KLR combined TB
//
//  Instantiates both self-contained testbench modules and
//  connects the four inter-ECU wires between them.
//
//  Signal connections:
//    DME A_5_KLR_ign_out → ~KLR trigger_in  (crank ref → /RESET)
//    DME A_1_tach_pulse  → ~KLR ign_in      (tach → T1+/INT)
//    KLR ign_out         →  DME ign          (retard-gated spark)
//    KLR full_load       →  DME full_load    (WOT flag)
//
//  Compile:
//    iverilog -o dme_klr.vvp -s dme_klr_tb        \
//      -I ../claude_8051/bench/verilog              \
//      -I ../gemini8048/bench/verilog               \
//      klr_defs.v                                   \
//      timescale.v                                  \
//      i8051_core.v  i8051_top.v                    \
//      i8048_core.v                                 \
//      adc_8090.v    adc_delay.v                    \
//      var_timing_gen.v  interrupt_gen.v  o2_gen.v  \
//      klr_top.v  klr_vcd_combined.v                \
//      i8051_tb.v  klr_tb.v                         \
//      dme_klr_tb.v
// ============================================================

`include "timescale.v"

// Override KLR hierarchy macros for combined DME+KLR mode.
// klr_tb is instantiated as u_klr; its klr_system instance is still `top`.
`define KLR_TB_PATH      dme_klr_tb.u_klr.top
`define KLR_TOP_TB       dme_klr_tb.u_klr
`define KLR_DUMPVCD_PATH dme_klr_tb.u_klr.u_dumpvcd

module dme_klr_tb;

    // ── Inter-ECU wires ───────────────────────────────────
    wire  klr_trigger;    // DME A_5_KLR_ign_out → KLR trigger_in
    wire  klr_ign_in;     // DME A_1_tach_pulse  → KLR ign_in
    wire  klr_ign_out;    // KLR P2.7            → DME ign
    wire  full_load;      // KLR P1.5            → DME full_load

    // ── DME ───────────────────────────────────────────────
    i8051_tb u_dme (
        .ign             ( klr_ign_out  ),  // KLR spark output → DME
        .A_1_tach_pulse  ( klr_ign_in   ),  // DME tach → KLR T1
        .A_5_KLR_ign_out ( klr_trigger  ),  // DME crank ref → KLR /RESET
        .full_load       ( full_load    )   // KLR WOT flag → DME
    );

    // ── KLR ───────────────────────────────────────────────
    // EXT_STIM=1: use ext_trigger/ext_ign ports instead of
    // internal var_timing_generator.  Signals are inverted
    // here since DME outputs are active-low.
    // DME AFM wiper → KLR TPS angle (ch7).  afm_wiper is generated inside u_dme.
    wire [7:0] tps_wiper_sig;
    assign tps_wiper_sig = u_dme.afm_wiper;

    klr_tb #(.EXT_STIM(1)) u_klr (
        .ext_trigger ( ~klr_trigger  ),  // invert: DME active-low → KLR active-high
        .ext_ign     ( ~klr_ign_in   ),  // invert: DME active-low → KLR active-high
        .ign_out     ( klr_ign_out   ),  // KLR spark → DME
        .full_load   ( full_load     ),  // KLR WOT flag → DME
        .tps_wiper   ( tps_wiper_sig )   // AFM → KLR TPS angle ch7
    );


endmodule
