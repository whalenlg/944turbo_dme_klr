// ============================================================
//  dme_klr_dashboard_tb.v  —  DME 951 + KLR combined testbench
//
//  Signal interconnect:
//    DME A_1_tach_pulse  → KLR ext_ign     (DME tach → KLR, inverted)
//    DME A_5_KLR_ign_out → KLR ext_trigger (DME ign out → KLR, inverted)
//    KLR ign_out         → DME ign         (KLR output → DME)
//    KLR full_load       → DME full_load   (WOT flag → DME TPS ch6)
//
//  Snapshot format (every DASH_INTERVAL_MS, latched to DME clock):
//    [DS]  <ms>,<256hex_dme_iram>,<p1p2p3>,<rpm>
//    [KLR] <ms>,<128hex_klr_ram>,<p1p2>,<ign><ignout><fl>
// ============================================================

`timescale 1ns/1ps

`ifndef DASH_INTERVAL_MS
  `define DASH_INTERVAL_MS 100
`endif

`define DME_KLR_MS ($time / 1_000_000)

module dme_klr_dashboard_tb;

    // ── Interconnect ──────────────────────────────────────────
    wire tach_dme_to_klr;     // DME A_1_tach_pulse  (active-high)
    wire ign_out_dme_to_klr;  // DME A_5_KLR_ign_out (active-high)
    wire klr_ign_out;         // KLR ign_out → DME ign
    wire full_load;            // KLR full_load → DME TPS ch6

    // ── DME sub-TB ───────────────────────────────────────────
    i8051_dashboard_tb u_dme (
        .ign            ( klr_ign_out        ),
        .A_1_tach_pulse ( tach_dme_to_klr    ),
        .A_5_KLR_ign_out( ign_out_dme_to_klr ),
        .full_load      ( full_load          )
    );

    // ── KLR sub-TB ───────────────────────────────────────────
    // EXT_STIM=1: external trigger/ign signals (not internal generator)
    // Signals are inverted: DME active-high → KLR active-low inputs
    klr_tb #(.EXT_STIM(1)) u_klr (
        .ext_trigger ( ~ign_out_dme_to_klr ),  // DME A_5_KLR_ign_out → KLR trigger (inverted)
        .ext_ign     ( ~tach_dme_to_klr    ),  // DME tach → KLR ign (inverted)
        .ign_out     ( klr_ign_out         ),  // KLR spark output → DME ign
        .full_load   ( full_load           )   // KLR WOT flag → DME
    );

    // ── Snapshot-busy flag ───────────────────────────────────
    reg snapshot_busy;
    initial snapshot_busy = 1'b0;

    // ── Combined snapshot task ───────────────────────────────
    task emit_combined_snapshot;
        integer i;
        begin
            snapshot_busy = 1'b1;

            // ── [DS] — DME 8051 iram (128 bytes) ─────────────
            $write("[DS] %0d,", `DME_KLR_MS);
            for (i = 0; i < 128; i = i + 1)
                $write("%02h", u_dme.i8051_top.u_cpu.iram[i[6:0]]);
            $write(",%02h%02h%02h", u_dme.p1, u_dme.p2, u_dme.p3);
            $write(",%0d\n", u_dme.ref_rpm);

            // ── [KLR] — 8048 RAM (64 bytes) ──────────────────
            // TODO: confirm KLR RAM hierarchy path (u_klr.<path>.ram)
            $write("[KLR] %0d,", `DME_KLR_MS);
            for (i = 0; i < 64; i = i + 1)
                $write("%02h", u_klr.top.i8048_core_1.ram[i[5:0]]);
            // TODO: confirm KLR port hierarchy for p1/p2
            $write(",%02h%02h", u_klr.top.p1, u_klr.top.p2);
            $write(",%0b%0b%0b\n",
                tach_dme_to_klr,    // ign input to KLR (before invert)
                klr_ign_out,        // KLR ign output
                full_load);         // full load / WOT flag

            snapshot_busy = 1'b0;
        end
    endtask

    // ── Snapshot scheduler — latched to DME clock ────────────
    reg [63:0] next_snap_ns;
    initial    next_snap_ns = `DASH_INTERVAL_MS * 64'd1_000_000;

    wire dme_clk = u_dme.clk;
    wire dme_rst = u_dme.rst;

    always @(posedge dme_clk) begin
        if (dme_rst && ($time >= next_snap_ns)) begin
            emit_combined_snapshot;
            next_snap_ns <= next_snap_ns + (`DASH_INTERVAL_MS * 64'd1_000_000);
        end
    end

endmodule
