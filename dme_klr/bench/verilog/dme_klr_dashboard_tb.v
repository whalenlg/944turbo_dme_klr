// ============================================================
//  dme_klr_dashboard_tb.v  —  DME 951 + KLR combined testbench
//                             (dashboard TB — emits [DS] snapshots)
//
//  Instantiates:
//    u_dme : i8051_dashboard_tb — Bosch Motronic DME (8051 core)
//    u_klr : i8048_tb           — KLR knock control unit (8048 core)
//
//  Interconnect:
//    DME A_5_KLR_ign_out → KLR ign      (DME coil primary → KLR T1)
//    DME reference_sensor → KLR trigger  (crank reference → KLR reset)
//    KLR ign_out         → DME ign       (KLR coil output → DME ign input)
//    KLR full_load       → DME full_load (WOT flag → DME TPS ch6)
// ============================================================

`timescale 1ns/1ps

module dme_klr_dashboard_tb;

    // ── Internal interconnect wires ──────────────────────────
    wire tach_dme_to_klr;    // DME A_1_tach_pulse  → KLR ign  (T1)
    wire ign_out_dme_to_klr; // DME A_5_KLR_ign_out → KLR trigger
    wire ign_klr_to_dme;     // KLR ign_out         → DME ign
    wire full_load;           // KLR full_load       → DME full_load (TPS ch6)

    // ── DME — i8051_dashboard_tb ─────────────────────────────
    i8051_dashboard_tb u_dme (
        .ign            ( ign_klr_to_dme   ),  // KLR ign_out → DME ign input
        .A_1_tach_pulse ( tach_dme_to_klr  ),  // DME tach → KLR ign (T1)
        .A_5_KLR_ign_out( ign_out_dme_to_klr), // DME ign out → KLR trigger
        .full_load      ( full_load        )   // WOT flag from KLR → DME TPS ch6
    );

    // ── KLR — i8048_tb ───────────────────────────────────────
    i8048_tb u_klr (
        .ign        ( tach_dme_to_klr   ),  // DME tach pulse → KLR T1
        .trigger    ( ign_out_dme_to_klr),  // DME A_5_KLR_ign_out → KLR trigger
        .ign_out    ( ign_klr_to_dme    ),  // KLR ignition output → DME ign
        .full_load  ( full_load         )   // WOT flag → DME TPS ch6
    );

endmodule
