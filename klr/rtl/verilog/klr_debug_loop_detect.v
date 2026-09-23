// ============================================================
//  klr_debug_loop_detect.v — KLR_DEBUG tight-loop suppression
//
//  KLR_DEBUG prints two lines per instruction: i8048_core.v's own
//  display_read_status SFR-trace line, and klr_vcd.v's disassembly
//  line. A tight polling loop (e.g. the KLR firmware's wait_ign_1 /
//  wait_ign_2 / ANL P2,#7F spin, waiting on T1) can execute for
//  hundreds of thousands of iterations while idling, flooding the
//  log with near-identical repeats.
//
//  This module watches the CPU's own pc/cycle_2 for a repeating
//  instruction-boundary PC cycle (period 1..PERIOD_MAX instructions).
//  Once the same period has been seen to repeat (matched twice —
//  i.e. the cycle has run 3 times total), it asserts `suppress` for
//  every further repeat of that cycle, so callers can skip printing
//  the flood — while the first two full passes still print normally.
//  `loop_just_exited` pulses for exactly one cycle (with loop_reps/
//  loop_lo/loop_hi valid at that same edge) when the PC finally
//  leaves the detected cycle, so a caller can print a one-line
//  summary instead of silently going quiet forever.
//
//  Self-contained: only needs clk/res_n and the CPU's own pc/cycle_2
//  as inputs, so it drops into any testbench (including the bare
//  i8048_core_tb.v regression suite, which never sets KLR_DEBUG at
//  all) with zero dependency on klr_vcd.v or any other monitor.
//
//  Boundary detection mirrors klr_vcd.v's own proven approach
//  (last_pc !== pc && !cycle_2, sampled on negedge clk — i.e. after
//  the CPU's own posedge-clk register updates have settled).
// ============================================================
`include "timescale.v"

module klr_debug_loop_detect #(
    parameter PERIOD_MAX = 7,      // longest loop period detected (instructions)
    parameter HIST_DEPTH = 8       // must be a power of 2, > PERIOD_MAX
) (
    input  wire        clk,
    input  wire        res_n,
    input  wire [11:0] pc,
    input  wire        cycle_2,
    output reg          suppress          /* verilator public */,
    output reg  [31:0]  loop_reps         /* verilator public */,
    output reg  [11:0]  loop_lo           /* verilator public */,
    output reg  [11:0]  loop_hi           /* verilator public */,
    output reg           loop_just_exited /* verilator public */
);
    localparam WPBITS  = 3;   // log2(HIST_DEPTH) — HIST_DEPTH fixed at 8 by WPBITS width below
    localparam PBITS   = 3;   // bits needed for PERIOD_MAX (up to 7)

    reg [11:0] hist [0:HIST_DEPTH-1];
    reg [WPBITS-1:0] wp;
    reg [PBITS-1:0]  pending_period, loop_period;
    reg              pending_confirmed;
    reg [11:0]       last_pc;
    integer          i;

    initial begin
        wp                = {WPBITS{1'b0}};
        pending_period    = {PBITS{1'b0}};
        pending_confirmed = 1'b0;
        loop_period       = {PBITS{1'b0}};
        loop_reps         = 32'd0;
        loop_lo           = 12'hFFF;
        loop_hi           = 12'h000;
        suppress          = 1'b0;
        loop_just_exited  = 1'b0;
        last_pc           = 12'hFFF;
        for (i = 0; i < HIST_DEPTH; i = i + 1) hist[i] = 12'hFFF;
    end

    always @(negedge clk or negedge res_n) begin : detect
        reg [PBITS-1:0] found;
        integer k;
        if (!res_n) begin
            wp                <= {WPBITS{1'b0}};
            pending_period    <= {PBITS{1'b0}};
            pending_confirmed <= 1'b0;
            loop_period       <= {PBITS{1'b0}};
            loop_reps         <= 32'd0;
            loop_lo           <= 12'hFFF;
            loop_hi           <= 12'h000;
            suppress          <= 1'b0;
            loop_just_exited  <= 1'b0;
            last_pc           <= 12'hFFF;
        end else begin
            loop_just_exited <= 1'b0;   // default: single-cycle pulse

            if (last_pc !== pc && !cycle_2) begin
                last_pc <= pc;

                if (loop_period != {PBITS{1'b0}}) begin
                    // Currently suppressing a confirmed loop — is this still it?
                    if (hist[wp - loop_period] === pc) begin
                        loop_reps <= loop_reps + 1'b1;
                        if (pc < loop_lo) loop_lo <= pc;
                        if (pc > loop_hi) loop_hi <= pc;
                        suppress <= 1'b1;
                    end else begin
                        loop_period       <= {PBITS{1'b0}};
                        pending_period    <= {PBITS{1'b0}};
                        pending_confirmed <= 1'b0;
                        suppress          <= 1'b0;
                        loop_just_exited  <= 1'b1;
                    end
                end else begin
                    suppress <= 1'b0;

                    if (pending_period != {PBITS{1'b0}} && hist[wp - pending_period] === pc) begin
                        if (pending_confirmed) begin
                            // Same period matched twice (cycle ran 3x total) — confirm.
                            loop_period <= pending_period;
                            loop_reps   <= 32'd0;
                            loop_lo     <= (pc < hist[wp - pending_period]) ? pc : hist[wp - pending_period];
                            loop_hi     <= (pc > hist[wp - pending_period]) ? pc : hist[wp - pending_period];
                            pending_period    <= {PBITS{1'b0}};
                            pending_confirmed <= 1'b0;
                        end else begin
                            pending_confirmed <= 1'b1;
                        end
                    end else begin
                        // No active/matching candidate — search history for the
                        // shortest period that explains the current pc (blocking
                        // assignment to a local scratch reg so the smallest k wins).
                        found = {PBITS{1'b0}};
                        for (k = 1; k <= PERIOD_MAX; k = k + 1)
                            if (found == {PBITS{1'b0}} && hist[wp - k[PBITS-1:0]] === pc)
                                found = k[PBITS-1:0];
                        pending_period    <= found;
                        pending_confirmed <= 1'b0;
                    end
                end

                hist[wp] <= pc;
                wp <= wp + 1'b1;
            end
        end
    end
endmodule
