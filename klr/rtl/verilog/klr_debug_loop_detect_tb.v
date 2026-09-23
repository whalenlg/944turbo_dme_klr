// ============================================================
//  klr_debug_loop_detect_tb.v — standalone testbench for
//  klr_debug_loop_detect.v
//
//  Drives a synthetic pc/cycle_2 sequence mimicking the real
//  wait_ign_1/wait_ign_2/ANL P2,#7F 3-instruction polling loop (all
//  three of which are 2-cycle instructions on real hardware) and
//  self-checks:
//    1. The first two full passes through the loop are NOT
//       suppressed (matches the "confirm after period repeats twice"
//       design).
//    2. From the third pass onward, every instruction is suppressed.
//    3. loop_reps counts exactly the suppressed repeats.
//    4. Exiting the loop (a PC outside the pattern) pulses
//       loop_just_exited for exactly one cycle, with the correct
//       final loop_reps/loop_lo/loop_hi.
//    5. A short, non-repeating instruction sequence (e.g. normal
//       straight-line code) is never suppressed at all.
//
//  Compile (iverilog):
//    iverilog -o loop_tb.vvp -s klr_debug_loop_detect_tb \
//      timescale.v klr_debug_loop_detect.v klr_debug_loop_detect_tb.v
//    vvp loop_tb.vvp
// ============================================================

`include "timescale.v"

module klr_debug_loop_detect_tb;

    reg clk = 0;
    always #5 clk = ~clk;

    reg        res_n   = 0;
    reg [11:0] pc      = 12'h000;
    reg        cycle_2 = 1'b0;

    wire        suppress;
    wire [31:0] loop_reps;
    wire [11:0] loop_lo, loop_hi;
    wire        loop_just_exited;

    klr_debug_loop_detect dut (
        .clk (clk), .res_n (res_n), .pc (pc), .cycle_2 (cycle_2),
        .suppress (suppress), .loop_reps (loop_reps),
        .loop_lo (loop_lo), .loop_hi (loop_hi),
        .loop_just_exited (loop_just_exited)
    );

    integer n_pass = 0, n_fail = 0;

    task check(input cond, input [511:0] label);
        begin
            if (cond) begin
                n_pass = n_pass + 1;
                $display("[TB] t=%0t  PASS: %0s", $time, label);
            end else begin
                n_fail = n_fail + 1;
                $display("[TB] t=%0t  *** FAIL ***: %0s", $time, label);
            end
        end
    endtask

    // Advance one instruction boundary. two_cycle=1 pulses cycle_2 high
    // for one clk (mimicking a real 2-cycle 8048 instruction) before the
    // low-cycle_2 boundary edge the detector actually triggers on.
    //
    // The trailing #1 after each @(negedge clk) is required, not
    // decorative: the DUT's own always block is ALSO sensitive to
    // negedge clk and updates its outputs via nonblocking assignment,
    // so a check() called in the very same time step as that edge can
    // race the DUT's NBA update and read stale (pre-edge) values. #1
    // moves past that update before any check() runs.
    task instr(input [11:0] new_pc, input two_cycle);
        begin
            pc <= new_pc;
            if (two_cycle) begin
                cycle_2 <= 1'b1;
                @(negedge clk); #1;
            end
            cycle_2 <= 1'b0;
            @(negedge clk); #1;
        end
    endtask

    initial begin
        $display("=== klr_debug_loop_detect_tb start ===");
        @(negedge clk); @(negedge clk);
        res_n <= 1'b1;
        @(negedge clk);

        // ── Scenario 1: straight-line code, never repeats — should
        //    never suppress. ─────────────────────────────────────
        $display("\n[TB] --- Scenario 1: straight-line code (no loop) ---");
        instr(12'h100, 1); instr(12'h101, 0); instr(12'h102, 1);
        instr(12'h103, 0); instr(12'h104, 1); instr(12'h105, 0);
        check(!suppress, "straight-line code never suppressed");
        check(!loop_just_exited, "no loop to exit yet");

        // ── Scenario 2: the real wait_ign_1/wait_ign_2/ANL loop,
        //    period 3, all three instructions 2-cycle. ────────────
        $display("\n[TB] --- Scenario 2: wait_ign_1/wait_ign_2/ANL loop (period 3) ---");
        // Pass 1
        instr(12'h1a5, 1); instr(12'h1a7, 1); instr(12'h1a9, 1);
        check(!suppress, "pass 1, instr 1 (1a5) not suppressed");
        // Pass 2
        instr(12'h1a5, 1);
        check(!suppress, "pass 2, instr 1 (1a5) not suppressed (still confirming)");
        instr(12'h1a7, 1);
        check(!suppress, "pass 2, instr 2 (1a7) not suppressed (still confirming)");
        instr(12'h1a9, 1);
        check(!suppress, "pass 2, instr 3 (1a9) not suppressed — this is where confirmation lands");
        // Pass 3 onward — should now be suppressed from the very first instruction.
        instr(12'h1a5, 1);
        check(suppress, "pass 3, instr 1 (1a5) suppressed");
        check(loop_reps == 32'd1, "loop_reps == 1 after first suppressed instruction");
        instr(12'h1a7, 1);
        check(suppress, "pass 3, instr 2 (1a7) suppressed");
        instr(12'h1a9, 1);
        check(suppress, "pass 3, instr 3 (1a9) suppressed");
        check(loop_reps == 32'd3, "loop_reps == 3 after pass 3 complete");

        // Run several more passes.
        repeat (20) begin
            instr(12'h1a5, 1); instr(12'h1a7, 1); instr(12'h1a9, 1);
        end
        check(suppress, "still suppressed after many more passes");
        check(loop_reps == 32'd63, "loop_reps == 3 + 3*20 == 63 after 23 total passes");
        check(loop_lo == 12'h1a5, "loop_lo == 0x1a5");
        check(loop_hi == 12'h1a9, "loop_hi == 0x1a9");

        // ── Exit the loop: T1 finally goes high, firmware moves on. ──
        $display("\n[TB] --- Scenario 3: loop exit ---");
        instr(12'h1ab, 0);
        check(loop_just_exited, "loop_just_exited pulses on the exit instruction");
        check(!suppress, "exit instruction itself is not suppressed");
        check(loop_reps == 32'd63, "loop_reps holds the final count at the exit pulse");
        @(negedge clk); #1;
        check(!loop_just_exited, "loop_just_exited is a single-cycle pulse (deasserted next cycle)");

        // A further unrelated instruction should not be flagged as still exiting.
        instr(12'h1ac, 0);
        check(!loop_just_exited, "no further exit pulse for unrelated code");
        check(!suppress, "unrelated code after loop exit is not suppressed");

        $display("\n=== klr_debug_loop_detect_tb done — PASS=%0d FAIL=%0d ===", n_pass, n_fail);
        $finish;
    end

    initial begin
        #10000;
        $display("[TB] *** TIMEOUT ***");
        $finish;
    end

endmodule
