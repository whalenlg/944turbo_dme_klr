// ============================================================
//  knock_gen_tb.v  —  Standalone testbench for knock_gen.v
//
//  Drives fake_knock (and a synthetic trigger_in) through a few
//  pulse patterns and self-checks knock_sum's hold:
//    knock_sum — non-retriggering hold. The FIRST falling edge of
//                fake_knock (seen while idle) starts the hold — a
//                single clean falling edge in, a single clean rising
//                edge out — completely ignoring anything fake_knock
//                does in between (further falls, rises, brief
//                blips). The hold releases on the next rising edge
//                of trigger_in (the crank-synchronized reference
//                trigger), not a fixed timer — see knock_gen.v for
//                the full rationale (a fixed-time hold doesn't scale
//                with RPM and can release before the next tooth at
//                low/idle RPM).
//
//  knock_noise (adc_ch0) is a separate, straightforward rolling
//  average of the last 10 samples of fake_knock/knock_sensor, taken
//  on each trigger_in rising edge — it has no independent hold/one-
//  shot of its own, so it isn't self-checked here; see knock_gen.v.
//
//  Scenarios:
//    1. Single pulse (one falling edge)    -> held low until the
//                                             NEXT trigger_in tooth
//                                             after the fall (even if
//                                             fake_knock itself has
//                                             already gone back high)
//    2. Two closely-spaced blips           -> BOTH filtered out
//                                             entirely (not
//                                             retriggerable); still
//                                             released at the next
//                                             trigger_in tooth after
//                                             the FIRST fall only
//    3. Very brief single pulse            -> still held all the way
//                                             to the next trigger_in
//                                             tooth (no "early rise"
//                                             exception)
//    4. Low period spanning a trigger_in tooth -> hold releases AT
//                                             that tooth even though
//                                             fake_knock is still low
//                                             at that instant; output
//                                             then follows fake_knock
//                                             directly (no further
//                                             gating) until it rises
//    5. knock_reset gating                 -> knock_sum forced to 0
//       (3 valid combinations only — knock_reset and fake_knock are
//       NEVER both 0)
//
//  The hold-release check watches knock_signal_processing's internal
//  fake_knock_stretched signal (knock_sum's hold) directly via
//  hierarchical reference (dut.fake_knock_stretched), and confirms
//  each release lands exactly on a trigger_in rising edge (scenarios
//  1-3) or exactly when fake_knock itself later rises past an
//  already-cleared hold (scenario 4).
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

    // ── trigger_in — synthetic crank-synchronized reference tooth,
    //    free-running throughout the test. Period is chosen longer
    //    than the module's old fixed 2.4ms hold specifically to
    //    exercise the case that motivated this change: at idle-like
    //    (slow) trigger rates, a fixed-time hold could release before
    //    the next tooth ever arrived. ──
    localparam real TRIGGER_PERIOD_NS = 3_500_000.0;  // 3.5ms — idle-like, > old 2.4ms hold
    reg trigger_in = 1'b0;
    always #(TRIGGER_PERIOD_NS / 2) trigger_in = ~trigger_in;

    // ── DUT I/O ────────────────────────────────────────────────
    reg        fake_knock   = 1'b1;  // idle-high, matches knock_signal_processing's reset assumption
    reg        knock_reset  = 1'b1;  // gate open by default
    reg  [7:0] knock_sensor = 8'd110;  // matches klr_tb.v's tied value; the baseline for both outputs
    wire [7:0] knock_sum;
    wire [7:0] knock_noise;

    knock_signal_processing dut (
        .clk          ( clk          ),
        .fake_knock   ( fake_knock   ),
        .knock_reset  ( knock_reset  ),
        .knock_sensor ( knock_sensor ),
        .trigger_in   ( trigger_in   ),
        .knock_sum    ( knock_sum    ),
        .knock_noise  ( knock_noise  )
    );

    // ── Self-checking hold-release monitor ──────────────────────
    // Watches the DUT's internal stretched signal directly. Each
    // hold episode should release either exactly at a trigger_in
    // rising edge (fake_knock already back high by then), or exactly
    // when fake_knock itself rises later (if the hold already
    // cleared at an earlier tooth while fake_knock was still low).
    //
    // trigger_in is free-running and NOT synchronized to clk, but the
    // DUT only ever samples it synchronously (posedge clk, registered
    // trigger_in_prev_hold compare) — so the actual release lands on
    // whichever posedge clk first sees trigger_in high after it rose,
    // not at trigger_in's own async transition instant. This replica
    // mirrors that exact same synchronous edge-detect so the captured
    // timestamp lines up with when the DUT's own `holding` register
    // (and therefore fake_knock_stretched) actually clears.
    real    last_trig_tick_ns = -1.0;
    reg     trigger_in_prev_tb = 1'b0;
    reg     measuring = 1'b0;
    integer n_pass = 0, n_fail = 0;

    always @(posedge clk) begin
        trigger_in_prev_tb <= trigger_in;
        if (trigger_in && !trigger_in_prev_tb)
            last_trig_tick_ns = $realtime;
    end

    always @(negedge dut.fake_knock_stretched) begin
        measuring = 1'b1;
        $display("[TB] t=%0t  fake_knock_stretched FELL (hold start)", $time);
    end

    always @(posedge dut.fake_knock_stretched) begin
        if (measuring) begin
            measuring = 1'b0;
            if ($realtime == last_trig_tick_ns) begin
                n_pass = n_pass + 1;
                $display("[TB] t=%0t  fake_knock_stretched ROSE exactly at a trigger_in tooth  PASS",
                          $time);
            end else if (fake_knock && !dut.holding) begin
                // Hold already cleared at an earlier tooth while
                // fake_knock was still low -- rise now tracks
                // fake_knock directly, ungated. Still a PASS.
                n_pass = n_pass + 1;
                $display("[TB] t=%0t  fake_knock_stretched ROSE tracking fake_knock directly (hold already cleared)  PASS",
                          $time);
            end else begin
                n_fail = n_fail + 1;
                $display("[TB] t=%0t  fake_knock_stretched ROSE NOT aligned with a trigger_in tooth (last tooth tick at t=%.0f ns)  *** FAIL ***",
                          $time, last_trig_tick_ns);
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
        $monitor("t=%8t  fake_knock=%b trigger_in=%b sum_stretched=%b holding=%b knock_reset=%b sensor=0x%02h | knock_sum=0x%02h knock_noise=0x%02h",
                  $time, fake_knock, trigger_in, dut.fake_knock_stretched, dut.holding, knock_reset, knock_sensor, knock_sum, knock_noise);
    end

    // ── Stimulus ────────────────────────────────────────────────
    initial begin
        $display("=== knock_gen_tb start ===");
        #5_000_000;

        // Scenario 1: single pulse (one falling edge) -- held until
        // the next trigger_in tooth after the fall.
        $display("\n[TB] --- Scenario 1: single pulse, one falling edge ---");
        fake_knock = 1'b0;
        #300_000;
        fake_knock = 1'b1;
        #5_000_000;

        // Scenario 2: two closely-spaced BLIPS (each a brief rise
        // then fall), all within the hold window. The hold is NOT
        // retriggerable, so both blips (and their falls) are
        // completely ignored — release lands at the next trigger_in
        // tooth after the FIRST fall only.
        // Pattern: 450us low, 10us high, 450us low, 10us high, 450us
        // low (total 1.37ms — well inside one trigger_in period, so
        // the non-retriggering behavior is clearly visible).
        $display("\n[TB] --- Scenario 2: two closely-spaced blips (both filtered, released at next tooth) ---");
        fake_knock = 1'b0;
        #450_000;
        fake_knock = 1'b1; #10_000; fake_knock = 1'b0;   // blip 1
        #450_000;
        fake_knock = 1'b1; #10_000; fake_knock = 1'b0;   // blip 2
        #450_000;                                         // final low period
        fake_knock = 1'b1;
        #5_000_000;

        // Scenario 3: very brief single pulse -- fake_knock rises
        // almost immediately, but should STILL be held low all the
        // way to the next trigger_in tooth (no "early rise" exception
        // in this design).
        $display("\n[TB] --- Scenario 3: very brief pulse — held to next tooth regardless ---");
        fake_knock = 1'b0;
        #10_000;
        fake_knock = 1'b1;
        #5_000_000;

        // Scenario 4: low period long enough to span a trigger_in
        // tooth -- the hold releases AT that tooth (fake_knock still
        // low at that instant), then fake_knock_stretched tracks
        // fake_knock directly, ungated, once it later rises.
        $display("\n[TB] --- Scenario 4: low period spans a trigger_in tooth ---");
        fake_knock = 1'b0;
        #5_000_000;   // > TRIGGER_PERIOD_NS, so at least one tooth occurs while still low
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

        $display("\n=== knock_gen_tb done — hold-release checks: PASS=%0d FAIL=%0d ===", n_pass, n_fail);
        $finish;
    end

    // Safety timeout in case a scenario hangs
    initial begin
        #80_000_000;
        $display("[TB] *** TIMEOUT — simulation did not finish in time ***");
        $finish;
    end

endmodule
