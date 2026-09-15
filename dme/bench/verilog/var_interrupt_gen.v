// Self-contained macro defaults.  In the dashboard build these come from
// i8051_dashboard_tb.v / klr_defs.v upstream, but the non-dashboard files
// list compiles this module before those defines exist — so guard them all
// here.  Each is `ifndef so a real upstream/-D definition always wins.
`ifndef RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
`endif
`ifndef DME_FREQ
  `define DME_FREQ 6000        // DME master clock: half-cycles per ms (6 MHz)
`endif
`ifndef SIM_TIME
  `define SIM_TIME 40000000000 // default 40 s (ns)
`endif
`ifndef RPMSTART
  `define RPMSTART 840
`endif
`ifndef RPMEND
  `define RPMEND 6500
`endif
`ifndef RPMCONST
  `define RPMCONST 2727272     // (60*1000*DME_FREQ)/132 — clocks per tooth basis
`endif

module var_interrupt_generator (
    input  wire clk,        // Fast Master Clock
    input  wire rst,        // Active high reset
    output reg  int_0 /* verilator public */,int_1 /* verilator public */,// The slowing square wave
    output reg  tdc  /* verilator public */,  // Top Dead Center marker —
                                               // 21.5 speed-sensor cycles
                                               // after int_0 falling edge,
                                               // held for 1 cycle
    output reg  [7:0] afm_wiper // AFM wiper value tracking RPM ramp
);
    integer period_current = `RPMCONST/`RPMSTART;  // initialised = no Z on afm_wiper at t=0
    integer tick_counter = 0;

    // Define outputs and edge-state from t=0. rst is applied as a 0->1 pulse
    // at sim start (posedge), so negedge-rst reset branches never fire then;
    // without these initials int_0/int_1 would propagate X into the DME.
    initial begin
        int_0 = 1'b1;
        int_1 = 1'b1;
        tdc   = 1'b0;
    end
    localparam period_start = `RPMCONST/`RPMSTART;
    localparam period_end =   `RPMCONST/`RPMEND;
    // RPM_RAMP_PCT: percentage of total simulation time over which RPM ramps
    // from RPMSTART to RPMEND.  After this point RPM holds at RPMEND.
    // Example: `define RPM_RAMP_PCT 25  → ramp completes at 25% of SIM_TIME
    // The original formula assumed the ramp filled the whole run; we scale it
    // by RPM_RAMP_PCT/100 so the same number of period_inc steps now happen
    // within the requested fraction of SIM_TIME.
    localparam period_change = (`SIM_TIME*`DME_FREQ/(period_start+period_end)/22500000)
                               * `RPM_RAMP_PCT / 100;

    // AFM wiper — two-point linear interpolation
    //   Known calibration points:
    //     840 RPM  → 0.25V → ADC = 255*(0.25/5) = 13  = 0x0D
    //     6500 RPM → 4.60V → ADC = 255*(4.60/5) = 235 = 0xEB
    //
    //   ADC(RPM) = 13 + 222*(RPM - 840) / 5660
    //
    localparam afm_rpm_lo  = 840;   // low cal RPM (idle)
    localparam afm_adc_lo  = 40;    // 0x28 = 0.78V at 840 RPM running idle
    localparam afm_rpm_hi  = 6500;  // high cal RPM (redline)
    localparam afm_adc_hi  = 235;   // 0xEB = 4.60V at 6500 RPM

    always @(*) begin : afm_calc
        reg [31:0] current_rpm;
        if (period_current <= period_end)
            current_rpm = `RPMEND;
        else
            current_rpm = (`RPMCONST / period_current);

        if (current_rpm <= afm_rpm_lo)
            afm_wiper = afm_adc_lo;
        else if (current_rpm >= afm_rpm_hi)
            afm_wiper = afm_adc_hi;
        else
            afm_wiper = afm_adc_lo +
                        ((afm_adc_hi - afm_adc_lo) * (current_rpm - afm_rpm_lo))
                        / (afm_rpm_hi - afm_rpm_lo);
    end

    // RPM ramp — linear in RPM, not period.
    // step_clocks: master clock cycles between each RPM step.
    // = SIM_TIME_MS * RPM_RAMP_PCT * FREQ / (100 * rpm_steps * 1000)
    // where SIM_TIME_MS = SIM_TIME/1000000 to avoid 64-bit overflow
    // At 6MHz: 1ms = 6000 clocks
    // step_clocks = ramp_ms * 6000 / rpm_steps
    // ramp_ms = SIM_TIME_NS/1e6 * RPM_RAMP_PCT/100
    localparam rpm_steps    = 200;
    // STEP_CLOCKS passed via -DSTEP_CLOCKS=N from the run script (computed
    // in bash to avoid Verilator localparam overflow with large SIM_TIME).
`ifndef STEP_CLOCKS
  `define STEP_CLOCKS 150000
`endif
    localparam step_clocks = `STEP_CLOCKS;

    reg [31:0] current_rpm;
    reg [63:0] master_clk_count = 0;
    localparam rpm_inc_val = (`RPMEND - `RPMSTART) / rpm_steps;

`ifdef RPM_RAMP_DOWN
`ifndef RPM_DOWN_START_MS
  `define RPM_DOWN_START_MS 30000
`endif
`ifndef RPM_DOWN_END_MS
  `define RPM_DOWN_END_MS 40000
`endif
`ifndef RPM_DOWN_TARGET
  `define RPM_DOWN_TARGET 840
`endif
    // Independent step counter/timing from the ramp-up's own
    // master_clk_count/step_clocks — see the RPM_RAMP_DOWN block below
    // for why. rpm_down_step_clocks divides the window duration into
    // rpm_steps (same step count as the ramp-up, for a comparably
    // smooth ramp) discrete steps.
    reg [63:0] rpm_down_clk_count = 0;
    localparam [63:0] rpm_down_window_clocks =
        (`RPM_DOWN_END_MS - `RPM_DOWN_START_MS) * `DME_FREQ;
    localparam [63:0] rpm_down_step_clocks = rpm_down_window_clocks / rpm_steps;
    // Rounds UP (not down) — with plain integer division, 200 steps of
    // a truncated dec_val can undershoot the target (e.g. (6000-840)/200
    // = 25.8 -> 25, and 200*25 = 5000 < 5160 needed, stopping at 1000
    // rather than 840). Rounding up means the ramp reaches the target
    // at or before the last step, where the explicit clamp below then
    // holds it there exactly.
    localparam rpm_down_dec_val = ((`RPMEND - `RPM_DOWN_TARGET) + rpm_steps - 1) / rpm_steps;
`endif

    // Latches once the ramp-up first reaches RPMEND, so the ramp-up
    // increment below can never re-fire — without this, if anything
    // later decreases current_rpm below RPMEND (e.g. RPM_RAMP_DOWN),
    // the original "if (current_rpm < RPMEND)" condition would see
    // that and start incrementing current_rpm back up again, fighting
    // whatever is trying to decrease it.
    reg ramp_up_done = 1'b0;

    always @(posedge clk) begin
        if (!rst) begin
            int_1             <= 1;  // active-low INT1 — start deasserted
            tick_counter      <= 0;
            master_clk_count  <= 0;
            current_rpm        = `RPMSTART;
            period_current     = period_start;
            ramp_up_done        = 1'b0;

        end else begin
            // Count master clocks for RPM step timing
            master_clk_count <= master_clk_count + 1;
            if (master_clk_count >= step_clocks) begin
                master_clk_count <= 0;
                if (!ramp_up_done && current_rpm < `RPMEND) begin
                    current_rpm = current_rpm + rpm_inc_val;
                    if (current_rpm >= `RPMEND) begin
                        current_rpm = `RPMEND;
                        ramp_up_done = 1'b1;
                    end
                    period_current <= `RPMCONST / current_rpm;
                end
            end

`ifdef DASHBOARD_TB
  `define CYCLE_COUNT i8051_dashboard_tb.i8051_top.u_cpu.cycle_count
`else
  `define CYCLE_COUNT i8051_tb.i8051_top.u_cpu.cycle_count
`endif

`ifdef ISV_LOAD_DROOP
            // --------------------------------------------------------
            //  ISV load droop stimulus:
            //  At t=5s (30,000,000 clocks) drop RPM to 650 for 500ms,
            //  then recover to RPMEND.  Fires after engine is fully
            //  settled at idle (ramp complete ~t=3s, enrichment done ~t=4s).
            //  t=5s      : 30,000,000 clocks
            //  t=5.5s    : 33,000,000 clocks (end of droop)
            // --------------------------------------------------------
            if (`CYCLE_COUNT >= 30_000_000 &&
                `CYCLE_COUNT <  33_000_000) begin
                period_current <= `RPMCONST / 650;   // 650 RPM droop
            end else if (`CYCLE_COUNT >= 33_000_000 &&
                         current_rpm >= `RPMEND) begin
                period_current <= period_end;         // restore
            end
`endif

`ifdef RPM_RAMP_DOWN
            // --------------------------------------------------------
            //  Second, timed ramp-down phase — mirrors the RPMSTART->
            //  RPMEND ramp-up above (same step-based approach), but
            //  windowed to a specific time range rather than a
            //  percentage of SIM_TIME, and running in the opposite
            //  direction (down, not up). Independent step counter/
            //  timing from the ramp-up's own master_clk_count/
            //  step_clocks, since this phase's window duration is
            //  unrelated to RPM_RAMP_PCT.
            //  Defaults (30s->40s, down to 840 RPM) match the
            //  ramp_to_6000_knock test's post-knock-pulse RPM decay;
            //  override via -DRPM_DOWN_START_MS/-DRPM_DOWN_END_MS/
            //  -DRPM_DOWN_TARGET for other tests.
`ifndef RPM_DOWN_START_MS
  `define RPM_DOWN_START_MS 30000
`endif
`ifndef RPM_DOWN_END_MS
  `define RPM_DOWN_END_MS 40000
`endif
`ifndef RPM_DOWN_TARGET
  `define RPM_DOWN_TARGET 840
`endif
            if (`CYCLE_COUNT >= (`RPM_DOWN_START_MS * `DME_FREQ) &&
                `CYCLE_COUNT <  (`RPM_DOWN_END_MS   * `DME_FREQ)) begin
                rpm_down_clk_count <= rpm_down_clk_count + 1;
                if (rpm_down_clk_count >= rpm_down_step_clocks) begin
                    rpm_down_clk_count <= 0;
                    if (current_rpm > `RPM_DOWN_TARGET) begin
                        current_rpm = (current_rpm > rpm_down_dec_val) ?
                                      (current_rpm - rpm_down_dec_val) : `RPM_DOWN_TARGET;
                        if (current_rpm < `RPM_DOWN_TARGET) current_rpm = `RPM_DOWN_TARGET;
                        period_current <= `RPMCONST / current_rpm;
                    end
                end
            end
`endif

            // Generate int_1 square wave at current period
            tick_counter_prev <= tick_counter;
            if (tick_counter >= (period_current / 2) - 1) begin
                tick_counter <= 0;
                int_1 <= ~int_1;
            end else begin
                tick_counter <= tick_counter + 1;
            end
        end
    end //always

    // --------------------------------------------------------
    //  132-tooth flywheel — dual sensor architecture
    //
    //  int_1 (speed_sensor / INT1):
    //    Square wave toggling every period_current/2 clocks.
    //    Firmware counts falling edges (INT1 ISR on falling edge).
    //
    //  int_0 (reference_sensor / INT0):
    //    Single pulse per revolution. HIGH for 45 tooth periods, LOW for
    //    the remaining 87 tooth periods of the 132-tooth wheel (real DME
    //    scope measurement — not the 50%/66-tooth figure originally
    //    assumed here, and not an exact 3/8 fraction either).
    //    Firmware triggers on falling edge (INT0 ISR).
    //
    //  Reference pulse timing:
    //    Falling edge: period/5 clocks before the speed sensor RISING edge,
    //      i.e. tick_counter == period/2 - 1 - period/5  during LOW phase of tooth 0.
    //      At ~909 RPM (0.5ms tooth): period/5 = 600 clocks = 0.1ms.
    //      (Falling-edge phase/alignment is unchanged — only the LOW
    //      duration below was adjusted to match the 45-tooth HIGH period.)
    // --------------------------------------------------------
    reg [7:0] counter = 8'd0;   // init: avoids X until first negedge rst

    // Tooth counter — increments on every rising edge of int_1.
    // NOTE: also self-initialised above because rst is applied as a 0->1 pulse
    // at sim start (a posedge); the negedge-rst branch would otherwise never
    // fire, leaving counter at X and stalling the reference-sensor edge logic.
    reg int_1_prev = 1'b0;  // edge detector for tooth counter
    integer tick_counter_prev = 0;  // one-cycle delayed — valid when int_1 just went low
    always @(posedge clk) begin : tooth_counter
        if (!rst) begin
            counter   <= 8'd0;
            int_1_prev <= 1'b0;
        end else begin
            int_1_prev <= int_1;
            if (int_1 && !int_1_prev) begin  // posedge int_1
                if (counter >= 8'd131)
                    counter <= 8'd0;
                else
                    counter <= counter + 1'b1;
            end
        end
    end

    // Reference sensor pulse — clock-accurate edge timing
    //
    //  The ref pulse is LOW for 87 tooth periods (HIGH for the remaining
    //  45), falling period/5 clocks before the speed sensor rising edge
    //  at tooth 0. Matches a real DME scope measurement (45-tooth HIGH
    //  period), not the 50%/66-tooth figure originally used here.
    reg [21:0] ref_low_cnt = 22'd0;   // 22-bit: fits up to 87*(2727272/100) —
                                       // widened from 21-bit since 87 > the
                                       // old 66-tooth multiplier would have
                                       // overflowed 21 bits at RPMSTART=100
    reg        ref_low_active = 1'b0;
    reg        ref_fired_this_rev = 1'b0;  // latch: ref pulse fired for tooth 0
    // (all initialised — the 0->1 rst pulse at sim start is a posedge, so the
    //  negedge-rst reset branch below does not fire at t=0)

    always @(posedge clk) begin : ref_sensor_gen
        if (!rst) begin
            int_0                <= 1'b1;
            ref_low_active       <= 1'b0;
            ref_low_cnt          <= 22'd0;
            ref_fired_this_rev   <= 1'b0;
        end else begin
            // Clear the per-rev latch once we leave tooth 0 so it can re-arm.
            if (counter != 8'd0)
                ref_fired_this_rev <= 1'b0;
            // Falling edge: use a CROSSING (>=) test, not exact-match (==).
            // period_current steps every ~100ms during the RPM ramp; an exact
            // == target can be skipped when the threshold shifts mid-revolution,
            // causing a missed ref pulse → doubled measured period → half-RPM
            // sawtooth. A >= crossing plus a once-per-rev latch is robust.
            // Use tick_counter_prev (sampled before reset) so the condition
            // is true at the genuine int_1 negedge in both iverilog and Verilator.
            // tick_counter resets to 0 on the same edge int_1 goes low, so
            // tick_counter_prev holds the pre-reset max value.
            if (counter == 8'd0 && int_1 == 1'b0 &&
                int_1_prev == 1'b1 &&
                !ref_fired_this_rev &&
                tick_counter_prev >= (period_current/2 - 1 - period_current/5)) begin
                // Falling edge: hold low for 87 tooth periods (45-tooth
                // HIGH period, per real DME scope measurement)
                int_0              <= 1'b0;
                ref_low_active     <= 1'b1;
                ref_fired_this_rev <= 1'b1;
                ref_low_cnt        <= 87 * period_current - 1;
            end else if (ref_low_active) begin
                int_0 <= 1'b0;
                if (ref_low_cnt == 22'd0) begin
                    int_0          <= 1'b1;
                    ref_low_active <= 1'b0;
                end else begin
                    ref_low_cnt <= ref_low_cnt - 1'b1;
                end
            end else begin
                int_0 <= 1'b1;
            end
        end
    end

    // ------------------------------------------------------------
    //  TDC (Top Dead Center) marker
    //  Asserted on the 22nd FALLING edge of int_1 (speed sensor) after
    //  the reference sensor (int_0) falling edge, held for 1 more full
    //  speed-sensor cycle (deasserted on the 23rd falling edge).
    //
    //  Counts int_1 FALLING edges only — same convention int_0 itself
    //  uses to transition (see ref_sensor_gen: triggers on int_1's
    //  falling edge) — so tdc's assert/deassert points land on exactly
    //  the same class of edge as the reference pulse, not an arbitrary
    //  half-tooth point. Counting actual edges (not a clock-length
    //  countdown) is also immune to period_current changing between
    //  pulses, which a fixed-clock-count approach is not.
    //
    //  Armed directly off int_0's own falling edge (not off the internal
    //  ref_sensor_gen state machine), so this block is fully independent
    //  and can't interact with or destabilize the ref-pulse logic above.
    //  22+1 = 23 tooth periods total span is well inside one 132-tooth
    //  revolution, so there's no risk of overlapping into the next rev.
    // ------------------------------------------------------------
    localparam TDC_DELAY_PULSES  = 22;  // falling edges of int_1 before assert
    localparam TDC_ACTIVE_PULSES = 1;   // falling edges of int_1 held asserted

    reg       int_0_prev_tdc = 1'b1;
    reg       int_1_prev_tdc = 1'b1;
    reg       tdc_pending    = 1'b0;
    reg       tdc_active     = 1'b0;
    reg [7:0] tdc_pulse_cnt  = 8'd0;   // falling edges counted since arming/asserting

    always @(posedge clk) begin : tdc_gen
        if (!rst) begin
            tdc            <= 1'b0;
            int_0_prev_tdc <= 1'b1;
            int_1_prev_tdc <= 1'b1;
            tdc_pending    <= 1'b0;
            tdc_active     <= 1'b0;
            tdc_pulse_cnt  <= 8'd0;
        end else begin
            int_0_prev_tdc <= int_0;
            int_1_prev_tdc <= int_1;

            if (int_0 == 1'b0 && int_0_prev_tdc == 1'b1) begin
                // int_0 falling edge — arm the TDC pulse-count
                tdc_pending   <= 1'b1;
                tdc_pulse_cnt <= 8'd0;
            end else if (tdc_pending && int_1 == 1'b0 && int_1_prev_tdc == 1'b1) begin
                // int_1 falling edge, counted while pending
                if (tdc_pulse_cnt == TDC_DELAY_PULSES - 1) begin
                    tdc           <= 1'b1;
                    tdc_pending   <= 1'b0;
                    tdc_active    <= 1'b1;
                    tdc_pulse_cnt <= 8'd0;
                end else begin
                    tdc_pulse_cnt <= tdc_pulse_cnt + 1'b1;
                end
            end else if (tdc_active && int_1 == 1'b0 && int_1_prev_tdc == 1'b1) begin
                // int_1 falling edge, counted while asserted
                if (tdc_pulse_cnt == TDC_ACTIVE_PULSES - 1) begin
                    tdc           <= 1'b0;
                    tdc_active    <= 1'b0;
                    tdc_pulse_cnt <= 8'd0;
                end else begin
                    tdc_pulse_cnt <= tdc_pulse_cnt + 1'b1;
                end
            end
        end
    end

endmodule
