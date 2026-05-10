// ============================================================
//  KLR 951 Phase Monitor  —  paste into klr_tb module body
//  via `include "klr_phase_monitor.v"
//
//  NOTE: do NOT list this file on the iverilog command line.
//  It is pulled in by `include inside klr_tb, so it compiles
//  within klr_tb's module scope.  Listing it separately causes
//  "Variable declarations must be contained within a module".
//
//  Requires: klr_tb.v wires: clk, ign_out, ign_out_n,
//            full_load, CV_PWM, knock_out, fake_knock
//
//  Uses `KLR_TB_PATH macro for hierarchical RAM/core access.
//  Works in both standalone and combined DME+KLR mode.
//
//  Time display: KLR milliseconds
//    KLR clock = 11 MHz, half-period = 45 ns
//    clk_count increments every negedge clk
//    1 ms ≈ 11111 half-cycles
// ============================================================

// ── KLR RAM convenience macro ─────────────────────────────
`define KLRRAM `KLR_TB_PATH.i8048_core_1.ram

// ── ms from clk_count ─────────────────────────────────────
`define KLR_MS(n) ((n) / 11111)

// ── Previous-value registers for edge detection ───────────
reg        ph_klr_ign_prev;
reg        ph_klr_knock_prev;
reg        ph_klr_fullload_prev;
reg        ph_klr_mb_prev;
reg        ph_klr_mb1_reached;   // latched once — MB1 first entry
reg [63:0] ph_klr_next_snap;

initial begin
    ph_klr_ign_prev       = 1'b0;
    ph_klr_knock_prev     = 1'b0;
    ph_klr_fullload_prev  = 1'b0;
    ph_klr_mb_prev        = 1'b0;
    ph_klr_mb1_reached    = 1'b0;
    ph_klr_next_snap      = 64'd111110;  // first snapshot at ~10ms KLR time
end

// ── Unified monitor ───────────────────────────────────────
always @(posedge clk) begin : klr_phase_monitor

    if (`KLR_TB_PATH.res_n === 1'b0) begin
        // Hold prevs during reset — avoids false edges on release
        ph_klr_ign_prev      <= 1'b0;
        ph_klr_knock_prev    <= 1'b0;
        ph_klr_fullload_prev <= 1'b0;
        ph_klr_mb_prev       <= 1'b0;
    end else begin

        // ── ign_out: spark fired ──────────────────────────
        if (ign_out && !ph_klr_ign_prev)
            $display("KLR: [PHASE] t=%0d ms  IGN_OUT asserted   (spark event — P2.7 high)",
                     `KLR_MS(clk_count));
        if (!ign_out && ph_klr_ign_prev)
            $display("KLR: [PHASE] t=%0d ms  IGN_OUT deasserted (coil recharging)",
                     `KLR_MS(clk_count));
        ph_klr_ign_prev <= ign_out;

        // ── knock_out: knock detected ─────────────────────
        if (knock_out && !ph_klr_knock_prev)
            $display("KLR: [PHASE] t=%0d ms  KNOCK_OUT asserted  (knock event detected — P1.6)",
                     `KLR_MS(clk_count));
        if (!knock_out && ph_klr_knock_prev)
            $display("KLR: [PHASE] t=%0d ms  KNOCK_OUT cleared   (knock window closed)",
                     `KLR_MS(clk_count));
        ph_klr_knock_prev <= knock_out;

        // ── full_load: WOT engaged ────────────────────────
        if (full_load && !ph_klr_fullload_prev)
            $display("KLR: [PHASE] t=%0d ms  FULL_LOAD set       (WOT — P1.5 high)",
                     `KLR_MS(clk_count));
        if (!full_load && ph_klr_fullload_prev)
            $display("KLR: [PHASE] t=%0d ms  FULL_LOAD cleared   (part-throttle)",
                     `KLR_MS(clk_count));
        ph_klr_fullload_prev <= full_load;

        // ── mb_latch: bank switch ─────────────────────────
        if (`KLR_TB_PATH.i8048_core_1.mb_latch && !ph_klr_mb_prev) begin
            $display("KLR: [PHASE] t=%0d ms  SEL MB1             (housekeeping bank selected)",
                     `KLR_MS(clk_count));
            if (!ph_klr_mb1_reached) begin
                ph_klr_mb1_reached <= 1'b1;
                $display("KLR: [PHASE] t=%0d ms  MB1 FIRST ENTRY     (housekeeping loop starting)",
                         `KLR_MS(clk_count));
            end
        end
        if (!`KLR_TB_PATH.i8048_core_1.mb_latch && ph_klr_mb_prev)
            $display("KLR: [PHASE] t=%0d ms  SEL MB0             (main loop bank selected)",
                     `KLR_MS(clk_count));
        ph_klr_mb_prev <= `KLR_TB_PATH.i8048_core_1.mb_latch;

        // ── Periodic STATUS snapshot ──────────────────────
        // Every ~100ms KLR time (≈1,111,100 half-cycles)
        if (clk_count >= ph_klr_next_snap) begin
            $display("KLR: [STATUS] t=%0d ms  pc=%03h  mb=%0b  SP=%0d  irq=%0b  ign_out=%0b  knock=%0b  full_load=%0b  CV_PWM=%0b  R0=%02h  R2=%02h  R4=%02h  R5=%02h  ram[16]=%02h  ram[17]=%02h  ram[26]=%02h  ram[38]=%02h  timer_val=%02h",
                `KLR_MS(clk_count),
                `KLR_TB_PATH.i8048_core_1.pc,
                `KLR_TB_PATH.i8048_core_1.mb_latch,
                `KLR_TB_PATH.i8048_core_1.psw[2:0],
                `KLR_TB_PATH.i8048_core_1.irq_in_progress,
                ign_out,
                knock_out,
                full_load,
                CV_PWM,
                `KLRRAM[8'h00],  // R0 bank0 — ISR context pointer
                `KLRRAM[8'h02],  // R2 bank0 — retard counter
                `KLRRAM[8'h04],  // R4 bank0 — slow tick / ADC dispatch
                `KLRRAM[8'h05],  // R5 bank0 — CV PWM reload
                `KLRRAM[8'h16],  // MB1 jump target low byte
                `KLRRAM[8'h17],  // MB1 jump target high byte (0x08=MB1)
                `KLRRAM[8'h26],  // retard accumulator
                `KLRRAM[8'h38],  // timer ISR A-save area
                `KLR_TB_PATH.i8048_core_1.timer_val
            );
            ph_klr_next_snap <= ph_klr_next_snap + 64'd1_111_100;  // +100ms
            $fflush();
        end

    end // res_n

end // klr_phase_monitor
