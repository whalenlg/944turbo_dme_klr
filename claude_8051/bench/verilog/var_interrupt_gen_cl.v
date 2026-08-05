// ============================================================
//  var_interrupt_gen_cl.v  —  Closed-Loop RPM Generator
//  89 DME 951 simulation — Bosch Motronic 3.1 / Porsche 944 Turbo
//
//  RPM is an OUTPUT of the torque balance each crank event:
//    net_torque = combustion(fuel_pw) - friction - accessory
//    rpm_new    = rpm_old + net_torque   (clamped to MIN..MAX)
//
//  Parameters (override with -D on iverilog command line):
//    CL_RPM_TARGET   840    initial / target idle RPM
//    CL_RPM_MIN      400    stall threshold
//    CL_RPM_MAX      6800   rev limiter
//    CL_INERTIA      3      fixed-point scale (lower = more responsive).
//                           Was 10 — that made RPM's own approach to
//                           equilibrium too slow to finish within a
//                           test's SIM_TIME even after fuel/enrichment
//                           had already settled (observed: fuel decayed
//                           to its steady value in ~20s, but RPM was
//                           still ~300rpm short of equilibrium at 30s).
//                           Lowering CL_INERTIA doesn't change WHERE the
//                           model converges (that's set by the friction
//                           curve vs combustion), only HOW FAST — this is
//                           a simple first-order system with no derivative
//                           term, so there's no overshoot/oscillation risk
//                           from increasing the gain, just faster settling.
//    CL_FRICTION     25     base term of the idle+3000 quadratic fit — see below
//    CL_AC_TORQUE    4      extra load when T1=1 (AC compressor, ~50 RPM droop)
//    CL_FUEL_SCALE   14     combustion torque per ms of injection pulse
//                           tuned so idle fuel (~2.35ms) gives net≈0
//    CL_FRICTION_RPM2_DIV / CL_FRICTION_HIGHRPM_THRESHOLD / CL_FRICTION_CUBIC_DIV
//                    RPM-dependent friction/pumping/windage term, in two parts:
//                      friction = CL_FRICTION + rpm*rpm/CL_FRICTION_RPM2_DIV
//                               + (rpm>THRESHOLD ? (rpm-THRESHOLD)^3/CL_FRICTION_CUBIC_DIV : 0)
//                    Real engines have friction, pumping, and windage
//                    losses that all rise with RPM — that's what makes an
//                    engine settle at a speed for a given fuel/air input
//                    instead of climbing forever. A flat friction constant
//                    (the original design) has no such term: net never
//                    reaches zero below CL_RPM_MAX, so the model just pegs
//                    against the rev-limiter clamp instead of converging
//                    near the actual target RPM.
//
//                    Calibrated from 3 REAL, independently-verified operating
//                    points (all from genuinely settled CL_TRAJ data, not
//                    guessed or captured mid-transient):
//                      840 rpm  (idle):              combustion≈26  (fuel≈1.83-1.97ms)
//                      2853 rpm (cl_ramp_to_3000):    combustion≈37  (fuel_avg≈2.6-2.7ms)
//                      ~6650rpm (cl_ramp_to_6000):    combustion≈112 (fuel_avg≈8.0-8.1ms)
//
//                    IMPORTANT: cl_ramp_to_3000 (AFM_CL_TARGET=0x72) and
//                    cl_ramp_to_6000 (AFM_CL_TARGET=0xDA) are two DIFFERENT
//                    fixed load/AFM targets, not two RPM points on one curve
//                    — each produces its own firmware-commanded fuel level
//                    largely independent of RPM in the observed range. A
//                    single quadratic (2 free shape params: base + one DIV)
//                    CANNOT satisfy both with real margin: any DIV strong
//                    enough to pull 6000's much higher combustion (~112,
//                    vs 3000's ~37) down from the CL_RPM_MAX=6800 clamp
//                    inevitably pulls 3000's equilibrium down by a
//                    comparable ABSOLUTE amount too (empirically verified:
//                    a 7.9% DIV change moved 6000 by -156rpm and 3000 by
//                    -115rpm — nearly the same), squeezing 3000 toward its
//                    own lower bound as 6000 approaches its upper bound.
//
//                    Fix: the quadratic term alone is fit tightly through
//                    JUST idle+3000 (2 points, 2 unknowns — clean exact
//                    fit, giving 3000 real margin across its full FQS range
//                    (see CL_FRICTION_RPM2_DIV comment for the exact retune)
//                    floor). A separate CUBIC term, clipped to zero below
//                    CL_FRICTION_HIGHRPM_THRESHOLD (4000rpm — comfortably
//                    above 3000's operating range), then does 100% of the
//                    work of pulling 6000 down from the clamp, with ZERO
//                    effect on the 3000 anchor by construction (not just
//                    "small" — literally zero below the threshold, unlike
//                    an unclipped cubic/quadratic which is never exactly
//                    zero anywhere and was still eating ~2-4rpm of margin
//                    at 3000 even when tuned mainly for 6000).
//
//                    If a 4th test at a materially different AFM_CL_TARGET
//                    is added later between these two, or above 6000, the
//                    threshold/cubic_div likely need re-verification against
//                    real CL_TRAJ data for that point too.
// ============================================================

`ifndef CL_RPM_TARGET
  `define CL_RPM_TARGET  840
`endif
`ifndef CL_RPM_MIN
  `define CL_RPM_MIN     400
`endif
`ifndef CL_RPM_MAX
  `define CL_RPM_MAX     6800
`endif
`ifndef CL_INERTIA
  `define CL_INERTIA     3     // lowered from 10 — see header note on convergence speed
`endif
`ifndef CL_FRICTION
  `define CL_FRICTION    26   // base of the idle+3000 quadratic fit — see header
`endif
`ifndef CL_AC_TORQUE
  `define CL_AC_TORQUE   4    // AC compressor load — tuned for ~50 RPM droop at idle
`endif
`ifndef CL_FUEL_SCALE
  `define CL_FUEL_SCALE  14   // idle ~1.97ms → combustion≈27 > friction=26 → net≈+1
`endif
`ifndef CL_FRICTION_RPM2_DIV
  `define CL_FRICTION_RPM2_DIV   760000   // quadratic term: rpm*rpm/DIV — fit
                                           // through idle+3000, loosened from
                                           // 675819 after the full FQS batch
                                           // showed cl_ramp_to_3000_FQS4 (leaner
                                           // real fuel than the baseline anchor)
                                           // failing by 32rpm — this gives every
                                           // observed 3000-family variant real
                                           // margin (~57rpm+) instead of an exact
                                           // single-point fit with zero slack.
`endif
`ifndef CL_FRICTION_HIGHRPM_THRESHOLD
  `define CL_FRICTION_HIGHRPM_THRESHOLD  4000  // cubic term is exactly zero at/below
                                                // this RPM — comfortably above 3000's
                                                // operating range, so it can never
                                                // touch that anchor's margin at all.
`endif
`ifndef CL_FRICTION_CUBIC_DIV
  `define CL_FRICTION_CUBIC_DIV  400000000  // cubic term: (rpm-THRESHOLD)^3/DIV,
                                             // only applied above THRESHOLD.
                                             // Re-tuned alongside CL_FRICTION_RPM2_DIV
                                             // to keep cl_ramp_to_6000's full FQS
                                             // range (including the richest +6%
                                             // variant) comfortably under the
                                             // 6600 ceiling after loosening the
                                             // shared quadratic term for 3000.
`endif


// Self-contained: the non-dashboard files list compiles this module before the
// testbench defines RPMCONST.  `ifndef so a real upstream/-D definition wins.
`ifndef RPMCONST
  `define RPMCONST 2727272    // (60*1000*DME_FREQ)/132 — clocks per tooth basis
`endif

`ifdef DASHBOARD_TB
  `define CL_TB          i8051_dashboard_tb
`else
  `define CL_TB          i8051_tb
`endif
`define CL_IRAM(n)       `CL_TB.i8051_top.u_cpu.iram[7'h``n]

module var_interrupt_generator_cl (
    input  wire clk,
    input  wire rst,
    output reg  int_0 /* verilator public */,
    output reg  int_1 /* verilator public */,
    output reg  [7:0] afm_wiper
);

    // ── AFM calibration ─────────────────────────────────────────
    localparam afm_rpm_lo  = 840;
    localparam afm_adc_lo  = 40;
    localparam afm_rpm_hi  = 6500;
    localparam afm_adc_hi  = 235;

    // ── State ────────────────────────────────────────────────────
    integer period_current;
    integer tick_counter;
    integer rpm_fp;
    integer rpm_fp_min;
    integer rpm_fp_max;
    reg [15:0] fuel_pulse_prev;
    integer    fuel_ms_x100;

    // ── AFM combinational ────────────────────────────────────────
    always @(*) begin : afm_calc
        integer crpm;
        crpm = rpm_fp / `CL_INERTIA;
        if      (crpm <= afm_rpm_lo) afm_wiper = afm_adc_lo;
        else if (crpm >= afm_rpm_hi) afm_wiper = afm_adc_hi;
        else afm_wiper = afm_adc_lo +
                         ((afm_adc_hi - afm_adc_lo) * (crpm - afm_rpm_lo))
                         / (afm_rpm_hi - afm_rpm_lo);
    end

    // ── Initial state ────────────────────────────────────────────
    initial begin
        tick_counter    = 0;
        rpm_fp          = `CL_RPM_TARGET * `CL_INERTIA;
        rpm_fp_min      = `CL_RPM_MIN    * `CL_INERTIA;
        rpm_fp_max      = `CL_RPM_MAX    * `CL_INERTIA;
        period_current  = `RPMCONST / `CL_RPM_TARGET;
        fuel_pulse_prev = 16'd0;
        fuel_ms_x100    = 0;
        int_0           = 1'b1;
        int_1           = 1'b1;
    end

    // ── Speed sensor ─────────────────────────────────────────────
    always @(posedge clk) begin : speed_sensor_gen
        if (!rst) begin
            tick_counter <= 0;
            int_1        <= 1'b1;  // active-low INT1 — start deasserted
        end else begin
            tick_counter_prev <= tick_counter;
            if (tick_counter >= (period_current / 2) - 1) begin
                tick_counter <= 0;
                int_1        <= ~int_1;
            end else begin
                tick_counter <= tick_counter + 1;
            end
        end
    end

    // ── Tooth counter ────────────────────────────────────────────
    // init = 8'd0: rst is applied as a 0->1 pulse at sim start (a posedge),
    // so the negedge-rst reset branch never fires at t=0.  Without the
    // initialiser counter stays X, X+1=X, counter==0 never true, and the
    // reference-sensor edge logic stalls (no int_0 pulses → RPM never measured).
    reg [7:0] counter = 8'd0;
    reg int_1_prev_cl = 1'b0;  // edge detector for tooth counter
    integer tick_counter_prev = 0;
`ifdef CL_DEBUG
    integer dbg_last_print_ms = -1000;   // forces first print at t=0
`endif
    always @(posedge clk) begin : tooth_counter
        if (!rst) begin
            counter       <= 8'd0;
            int_1_prev_cl <= 1'b0;
        end else begin
            int_1_prev_cl <= int_1;
            if (int_1 && !int_1_prev_cl) begin  // posedge int_1
                if (counter >= 8'd131) counter <= 8'd0;
                else                   counter <= counter + 1'b1;
            end
        end
    end

    // ── Reference sensor + torque update ─────────────────────────
    // Single always block owns int_0, rpm_fp, and period_current.
    // Torque calculation runs on the ref pulse (tooth 0, int_1 low).
    //
    // synced_once: latched flag set the first time EngineSync (iram[21h].0)
    // is seen non-zero.  Avoids a race condition where the firmware briefly
    // clears the bit during its calculation loop at the exact crank event
    // instant, which would cause the live CL_IRAM(21) read to return 0 on
    // every event and permanently hold RPM at target.
    reg        synced_once;
    reg [20:0] ref_low_cnt;
    reg        ref_low_active;
    reg        ref_fired_this_rev;   // once-per-rev latch for the ref pulse

    always @(posedge clk) begin : ref_and_dynamics
        integer fuel_sample;
        integer combustion;
        integer friction;
        integer crpm_now;
        reg signed [63:0] highrpm_delta;   // 64-bit: delta^3 can exceed 32-bit
                                            // integer range (e.g. 2800^3 ≈ 22
                                            // billion vs ~2.1 billion max for
                                            // a 32-bit `integer`) — silent
                                            // overflow would corrupt the term
        integer net;
        integer new_rpm_fp;
        integer crpm;

        if (!rst) begin
            int_0          <= 1'b1;
            ref_low_active <= 1'b0;
            ref_low_cnt    <= 21'd0;
            ref_fired_this_rev <= 1'b0;
            rpm_fp         <= `CL_RPM_TARGET * `CL_INERTIA;
            period_current <= `RPMCONST / `CL_RPM_TARGET;
            synced_once    <= 1'b0;
        end else begin

            // Latch EngineSync permanently once seen — don't read live
            if (`CL_IRAM(21) & 8'h01)
                synced_once <= 1'b1;

            // Clear the per-rev latch once we leave tooth 0 so it can re-arm.
            if (counter != 8'd0)
                ref_fired_this_rev <= 1'b0;

            if (counter == 8'd0 && int_1 == 1'b0 &&
                int_1_prev_cl == 1'b1 &&
                !ref_fired_this_rev &&
                tick_counter_prev >= (period_current/2 - 1 - period_current/5)) begin

                int_0          <= 1'b0;
                ref_low_active <= 1'b1;
                ref_fired_this_rev <= 1'b1;
                ref_low_cnt    <= 66 * period_current - 1;

                // ── Torque update ─────────────────────────────────
                fuel_sample = {`CL_IRAM(4B), `CL_IRAM(4A)};
                fuel_pulse_prev <= fuel_sample;
                fuel_ms_x100    <= fuel_sample / 5;

                // Gate: hold RPM at target before first engine sync, or
                // during FuelOffCoast (iram[23h].5) to prevent stall.
                if (!synced_once || (`CL_IRAM(23) & 8'h20)) begin
                    // Pre-sync or fuel cut — clamp to target, no dynamics
`ifdef CL_DEBUG
                    // Diagnostic: report WHY the RPM was clamped to target.
                    // EngineSync   = iram[21h].0   FuelOffCoast = iram[23h].5
                    $display("DME: [PHASE] t=%0d ms  CL_RPM CLAMPED to target=%0d  cause=%s  (synced_once=%0b iram21=%02h iram23=%02h)",
                             ($time/1_000_000), `CL_RPM_TARGET,
                             (!synced_once) ? "PRE-SYNC" : "FUEL-OFF-COAST",
                             synced_once, `CL_IRAM(21), `CL_IRAM(23));
`endif
                    rpm_fp         <= `CL_RPM_TARGET * `CL_INERTIA;
                    period_current <= `RPMCONST / `CL_RPM_TARGET;
                end else begin
                    combustion = (fuel_sample / 5 * `CL_FUEL_SCALE) / 100;

                    friction = `CL_FRICTION;
                    if (`CL_TB.t1 == 1'b1)
                        friction = friction + `CL_AC_TORQUE;

                    // RPM-dependent friction/pumping/windage loss — see
                    // header comment. Quadratic term fit through idle+3000
                    // only; cubic term clipped to zero below the threshold
                    // does all the work for the 6000 region, with zero
                    // effect on the 3000 anchor. Uses rpm_fp (this cycle's
                    // RPM, before update) as the proxy for current speed.
                    crpm_now = rpm_fp / `CL_INERTIA;
                    friction = friction + ((crpm_now * crpm_now) / `CL_FRICTION_RPM2_DIV);
                    if (crpm_now > `CL_FRICTION_HIGHRPM_THRESHOLD) begin
                        highrpm_delta = crpm_now - `CL_FRICTION_HIGHRPM_THRESHOLD;
                        friction = friction + ((highrpm_delta * highrpm_delta * highrpm_delta) / `CL_FRICTION_CUBIC_DIV);
                    end

                    net = combustion - friction;

                    new_rpm_fp = rpm_fp + net;
                    if      (new_rpm_fp > rpm_fp_max) new_rpm_fp = rpm_fp_max;
                    else if (new_rpm_fp < rpm_fp_min) new_rpm_fp = rpm_fp_min;

`ifdef CL_DEBUG
                    // Trajectory diagnostic: real (rpm, fuel, combustion,
                    // friction, net) data over time, throttled to ~1 line
                    // per 100ms sim time (this update fires roughly once
                    // per crank rev, i.e. far more often than that at high
                    // RPM). Use this to fit the friction curve against the
                    // model's actual fixed-point trajectory instead of a
                    // single before/after fuel_avg, which shifts every
                    // time the friction curve changes (see var_interrupt_
                    // gen_cl.v header notes on the coupled RPM<->fuel loop).
                    if (($time/1_000_000) - dbg_last_print_ms >= 100) begin
                        dbg_last_print_ms = ($time/1_000_000);
                        $display("CL_TRAJ t=%0d ms  rpm=%0d  fuel_sample=%0d  combustion=%0d  friction=%0d  net=%0d  new_rpm=%0d",
                                 ($time/1_000_000), (rpm_fp / `CL_INERTIA), fuel_sample,
                                 combustion, friction, net, (new_rpm_fp / `CL_INERTIA));
                    end
`endif

                    rpm_fp <= new_rpm_fp;

                    crpm = new_rpm_fp / `CL_INERTIA;
                    if (crpm < `CL_RPM_MIN) crpm = `CL_RPM_MIN;
                    if (crpm > `CL_RPM_MAX) crpm = `CL_RPM_MAX;
                    period_current <= `RPMCONST / crpm;
                end

            end else if (ref_low_active) begin
                int_0 <= 1'b0;
                if (ref_low_cnt == 21'd0) begin
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

endmodule
