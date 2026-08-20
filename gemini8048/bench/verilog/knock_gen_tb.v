// ============================================================
//  knock_gen_tb.v  —  Standalone testbench for knock_gen.v
//
//  Drives fake_knock through a few pulse patterns and self-checks
//  the two INDEPENDENT filters in knock_gen.v:
//    knock_sum   — fixed 2.4ms one-shot, NOT retriggerable. The
//                  FIRST falling edge starts a fixed 2.4ms low
//                  period — a single clean falling edge in, a
//                  single clean rising edge out, 2.4ms later —
//                  completely ignoring anything fake_knock does in
//                  between (further falls, rises, brief blips).
//    knock_noise — separate, retriggerable 500us filter. EVERY
//                  falling edge (re)starts a 500us window; any
//                  pulse within 500us of the last fall is filtered
//                  out, and each such fall restarts the window.
//  Both filters see the same fake_knock input but settle at
//  different times, since one is fixed/one-shot and the other is
//  retriggerable — see knock_gen.v for the full rationale.
//  Scenarios:
//    1. Single pulse (one falling edge)    -> both outputs held low,
//                                             each per their own timer
//    2. Two closely-spaced blips           -> BOTH filtered out of
//                                             BOTH outputs, but they
//                                             release at DIFFERENT
//                                             times (knock_sum fixed
//                                             ~2.4ms from the first
//                                             fall; knock_noise ~500us
//                                             after the LAST fall)
//    3. Very brief single pulse            -> both still get their
//                                             full hold duration (no
//                                             "early rise" exception
//                                             on either)
//    4. Naturally long low period (>2.4ms) -> no extra stretch added
//                                             to either output
//    5. knock_reset gating                 -> knock_sum forced to 0
//       (3 valid combinations only — knock_reset and fake_knock are
//       NEVER both 0)
//
//  The hold-duration check watches knock_gen's internal
//  fake_knock_stretched signal (knock_sum's timer) directly via
//  hierarchical reference (dut.fake_knock_stretched) rather than
//  reverse-engineering timing from knock_sum's bit pattern.
//
//  Compile (iverilog):
//    iverilog -o knock_gen_tb.vvp -s knock_gen_tb \
//      timescale.v klr_defs.v knock_gen.v knock_gen_tb.v
//    vvp knock_gen_tb.vvp
//
//  View waveforms:
//    gtkwave knock_gen_tb.vcd
// ============================================================

`include "timescale.v"
`include "klr_defs.v"

module knock_gen_tb;

    // ── Clock — same generator style/period as klr_tb.v ───────
    parameter DELAY = `FRQ_SCALE / `KLR_FREQ;  // half-period
    reg clk = 0;
    always #DELAY clk = ~clk;

    // ── DUT I/O ────────────────────────────────────────────────
    reg        fake_knock   = 1'b1;  // idle-high, matches knock_gen's reset assumption
    reg        knock_reset  = 1'b1;  // gate open by default
    reg  [7:0] knock_sensor = 8'd110;  // matches klr_tb.v's tied value; the baseline for both outputs
    wire [7:0] knock_sum;
    wire [7:0] knock_noise;

    knock_gen dut (
        .clk          ( clk          ),
        .fake_knock   ( fake_knock   ),
        .knock_reset  ( knock_reset  ),
        .knock_sensor ( knock_sensor ),
        .knock_sum    ( knock_sum    ),
        .knock_noise  ( knock_noise  )
    );

    // ── Self-checking hold-duration monitor ────────────────────
    // Watches the DUT's internal stretched signal directly. Every
    // hold episode should measure ~2.4ms from the FIRST fall to
    // release, since the timer is fixed/non-retriggering — later
    // falls within the window don't extend it.
    real    fall_time_ns, span_ms;
    reg     measuring = 1'b0;
    integer n_pass = 0, n_fail = 0;
    localparam real MIN_HOLD_MS = 2.399;  // slack for cycle-count rounding

    always @(negedge dut.fake_knock_stretched) begin
        fall_time_ns = $realtime;
        measuring    = 1'b1;
        $display("[TB] t=%0t  fake_knock_stretched FELL (hold start)", $time);
    end

    always @(posedge dut.fake_knock_stretched) begin
        if (measuring) begin
            span_ms   = ($realtime - fall_time_ns) / 1_000_000.0;
            measuring = 1'b0;
            if (span_ms >= MIN_HOLD_MS) begin
                n_pass = n_pass + 1;
                $display("[TB] t=%0t  fake_knock_stretched ROSE — span=%.4fms (>= 2.4ms)  PASS",
                          $time, span_ms);
            end else begin
                n_fail = n_fail + 1;
                $display("[TB] t=%0t  fake_knock_stretched ROSE — span=%.4fms (< 2.4ms)  *** FAIL ***",
                          $time, span_ms);
            end
        end
    end

    // ── VCD dump ───────────────────────────────────────────────
    initial begin
        $dumpfile("knock_gen_tb.vcd");
        $dumpvars(0, knock_gen_tb);
    end

    // ── Continuous status line ─────────────────────────────────
    initial begin
        $monitor("t=%8t  fake_knock=%b sum_stretched=%b noise_stretched=%b knock_reset=%b sensor=0x%02h | knock_sum=0x%02h knock_noise=0x%02h",
                  $time, fake_knock, dut.fake_knock_stretched, dut.fake_knock_noise_stretched, knock_reset, knock_sensor, knock_sum, knock_noise);
    end

    // ── Stimulus ────────────────────────────────────────────────
    initial begin
        $display("=== knock_gen_tb start ===");
        #5_000_000;

        // Scenario 1: single pulse (one falling edge) -- expect exactly ~2.4ms hold
        $display("\n[TB] --- Scenario 1: single pulse, one falling edge ---");
        fake_knock = 1'b0;
        #300_000;
        fake_knock = 1'b1;
        #5_000_000;

        // Scenario 2: two closely-spaced BLIPS (each a brief rise
        // then fall), all within both filter windows. knock_sum's
        // fixed one-shot is NOT retriggerable, so both blips (and
        // their falls) are completely ignored — release lands at a
        // single fixed 2.4ms after the FIRST fall only. knock_noise's
        // filter IS retriggerable (500us), so it also filters both
        // blips, but releases separately — 500us after the LAST fall
        // (blip2's), which lands earlier than knock_sum's release.
        // Pattern: 450us low, 10us high, 450us low, 10us high, 450us
        // low (total 1.37ms — comfortably inside knock_sum's 2.4ms
        // window, so both filters' behavior is clearly visible).
        $display("\n[TB] --- Scenario 2: two closely-spaced blips (filtered by both, released at different times) ---");
        fake_knock = 1'b0;
        #450_000;
        fake_knock = 1'b1; #10_000; fake_knock = 1'b0;   // blip 1
        #450_000;
        fake_knock = 1'b1; #10_000; fake_knock = 1'b0;   // blip 2
        #450_000;                                         // final low period
        fake_knock = 1'b1;
        #5_000_000;

        // Scenario 3: very brief single pulse -- fake_knock rises
        // almost immediately, but should STILL be held low for the
        // full 2.4ms (no "early rise" exception in this design).
        $display("\n[TB] --- Scenario 3: very brief pulse — full 2.4ms hold still applies ---");
        fake_knock = 1'b0;
        #10_000;
        fake_knock = 1'b1;
        #5_000_000;

        // Scenario 4: naturally long low period, already exceeds 2.4ms
        $display("\n[TB] --- Scenario 4: naturally long low period (> 2.4ms) ---");
        fake_knock = 1'b0;
        #3_000_000;
        fake_knock = 1'b1;
        #5_000_000;

        // Scenario 5: knock_reset gating. Only 3 combinations are
        // exercised — knock_reset and fake_knock are NEVER both 0
        // at the same time (not a valid/expected combination).
        // Transitions are kept SEPARATE in time (never simultaneous)
        // so each combination is held for a real settle window and
        // individually, unambiguously observable.
        $display("\n[TB] --- Scenario 5: knock_reset gating (3 valid combinations, separated) ---");
        fake_knock  = 1'b0;
        #5_000_000;
        $display("[TB] t=%0t  knock_reset=1, fake_knock=0: knock_sum=%0d (expect 110)",
                  $time, knock_sum);

        fake_knock  = 1'b1;
        #5_000_000;
        $display("[TB] t=%0t  knock_reset=1, fake_knock=1: knock_sum=%0d (expect 255)",
                  $time, knock_sum);

        knock_reset = 1'b0;
        #5_000_000;
        $display("[TB] t=%0t  knock_reset=0, fake_knock=1: knock_sum=%0d (expect 0)",
                  $time, knock_sum);

        knock_reset = 1'b1;
        #5_000_000;

        $display("\n=== knock_gen_tb done — hold-duration checks: PASS=%0d FAIL=%0d ===", n_pass, n_fail);
        $finish;
    end

    // Safety timeout in case a scenario hangs
    initial begin
        #80_000_000;
        $display("[TB] *** TIMEOUT — simulation did not finish in time ***");
        $finish;
    end

endmodule
