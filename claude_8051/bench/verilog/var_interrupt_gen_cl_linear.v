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
`ifndef CL_FUEL_ENERGY_PCT
  `define CL_FUEL_ENERGY_PCT 0  // FQS: manual fuel-quality switch the driver
                                 // sets when fuel is off-spec. Positive = weak
                                 // fuel (firmware widens the injector pulse to
                                 // compensate) => LOWER energy density per unit
                                 // of pulse width. Negative = potent fuel =>
                                 // HIGHER energy density. Defaults to 0 (normal
                                 // fuel, FQS position 0) if not overridden.
`endif
`ifndef CL_FRICTION_RPM2_DIV
  `define CL_FRICTION_RPM2_DIV   890000   // quadratic term: rpm*rpm/DIV — fit
                                           // through idle+3000. Re-tuned again:
                                           // the previous 760000 was margin-
                                           // checked with base=25 in the search
                                           // script, but base=26 was what actually
                                           // shipped (needed for exact idle
                                           // match) — that mismatch was never
                                           // re-verified, silently costing the
                                           // 3000 family ~140rpm of margin
                                           // uniformly. Real CL_TRAJ data on
                                           // cl_ramp_to_3000_FQS2 confirmed a
                                           // genuine, stable equilibrium at
                                           // ~2610rpm (not a coupling/drift
                                           // issue — net dithers tightly around
                                           // 0, friction matched the formula
                                           // exactly). This value was margin-
                                           // checked with the ACTUAL base=26.
`endif
`ifndef CL_FRICTION_HIGHRPM_THRESHOLD
  `define CL_FRICTION_HIGHRPM_THRESHOLD  4000  // cubic term is exactly zero at/below
                                                // this RPM — comfortably above 3000's
                                                // operating range, so it can never
                                                // touch that anchor's margin at all.
`endif
`ifndef CL_FRICTION_CUBIC_DIV
  `define CL_FRICTION_CUBIC_DIV  320000000  // cubic term: (rpm-THRESHOLD)^3/DIV,
                                             // only applied above THRESHOLD.
                                             // Re-tuned alongside CL_FRICTION_RPM2_DIV
                                             // (see that comment) with base=26
                                             // held fixed throughout the search
                                             // this time.
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
    output reg  tdc   /* verilator public */,  // Top Dead Center marker —
                                                // 21.5 speed-sensor cycles
                                                // after int_0 falling edge,
                                                // held for 1 cycle
    output reg  [7:0] afm_wiper
);

    // ── AFM calibration ─────────────────────────────────────────
    //  Real settled operating points (per closed-loop test type):
    //    cl_ramp_to_6000 (+ FQS family, AFM_CL_TARGET=0xDA) settle
    //      at ~6432rpm in practice — capped at afm_adc_mid (0xD8)
    //      here, since the KLR flags a TPS error above that.
    //    cl_ramp_to_redline (AFM_CL_TARGET=0xEB) settles at
    //      ~6818rpm — allowed to reach the higher afm_adc_hi (0xEB)
    //      ceiling; it's the one CL test that legitimately needs to
    //      push higher.
    //  Non-CL tests (ramp_to_6100/6200/6300, plain ramp_to_redline,
    //  etc.) do NOT go through this file — they use the separate
    //  non-CL interrupt generator — so this change doesn't affect
    //  them.
    //
    //  Shape: idle -> rise (ORIGINAL slope, see below) -> capped at
    //  0xD8 (covers the 6000-family's ~6432rpm settle point with
    //  margin either side for normal closed-loop fluctuation) ->
    //  short final rise -> 0xEB ceiling (reached by redline's
    //  ~6818rpm settle point).
    //
    //  IMPORTANT: the rising segment below uses the ORIGINAL
    //  single-segment slope (the (840,40)->(6500,235) two-point
    //  line this module used before the 0xD8 cap was added), not a
    //  new shallower slope aimed directly at (6432,216). An earlier
    //  version of this fix redefined the slope itself to hit
    //  (afm_rpm_mid, afm_adc_mid) exactly, which quietly shifted
    //  afm_wiper ~6 counts LOWER across the entire 3000-family's
    //  operating range (e.g. 107->101 at 2800rpm) as a side effect —
    //  confirmed via git bisect to be what broke cl_ramp_to_3000's
    //  FQS timing-retard differentiation and RPM convergence
    //  (afm_wiper feeds TPS, and the KLR's full_load latch depends
    //  on a transient overshoot crossing a threshold during ramp-up;
    //  the shallower slope's uniformly-lower values apparently no
    //  longer crossed it). This version keeps the ORIGINAL slope
    //  and just clamps/caps its output at afm_adc_mid once it would
    //  naturally exceed that — so the 3000-family sees EXACTLY the
    //  same values as before the 0xD8 cap was ever introduced, while
    //  the 6000-family still gets capped correctly (the cap only
    //  actually engages once crpm is high enough that the original
    //  line would exceed 216 anyway, i.e. above ~5948rpm — nowhere
    //  near the 3000-family's range).
    //
    //  IMPORTANT (2nd note): this exact fix was applied once before
    //  but never committed to git — a later `git bisect`/`git bisect
    //  reset` cycle silently discarded it, so every test run between
    //  then and whenever this comment was re-added was still running
    //  the buggy shallower-slope version despite appearing to have
    //  the fix. Commit this change before doing anything with git
    //  bisect/checkout again.
    //  The plateau bounds (afm_rpm_plateau_end) are a
    //  reasonable-margin choice, not exact data — adjust if you
    //  have tighter bounds on the 6000-family's real fluctuation
    //  band around 6432rpm.
    localparam afm_rpm_lo          = 840;
    localparam afm_adc_lo          = 40;
    localparam afm_rpm_orig_hi     = 6500;  // ORIGINAL slope's own reference endpoint
    localparam afm_adc_orig_hi     = 235;   // (used only to compute the line's slope —
                                             // NOT a plateau boundary; the cap below
                                             // kicks in well before crpm reaches this)
    localparam afm_adc_mid         = 216;   // 0xD8 — max TPS for CL 6000-target tests
    localparam afm_rpm_plateau_end = 6700;  // margin before climbing toward redline's ceiling
    localparam afm_rpm_hi          = 6818;  // cl_ramp_to_redline settle point
    localparam afm_adc_hi          = 235;   // 0xEB — redline's own (unchanged) ceiling

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
        integer uncapped;
        crpm     = rpm_fp / `CL_INERTIA;
        // ORIGINAL two-point line — matches this module's behavior
        // before the 0xD8 cap existed. Only meaningful/used once
        // crpm > afm_rpm_lo (see below); harmless if computed
        // (unused) otherwise.
        uncapped = afm_adc_lo +
                   ((afm_adc_orig_hi - afm_adc_lo) * (crpm - afm_rpm_lo))
                   / (afm_rpm_orig_hi - afm_rpm_lo);

        if (crpm <= afm_rpm_lo) begin
            afm_wiper = afm_adc_lo;
        end else if (crpm <= afm_rpm_plateau_end) begin
            // ORIGINAL slope, capped at the 6000-family's D8 ceiling.
            // Below ~5948rpm the uncapped line is already under 216
            // anyway, so the cap only actually engages above that —
            // the 3000-family's entire range sits well under it,
            // seeing exactly the original (uncapped) values.
            afm_wiper = (uncapped > afm_adc_mid) ? afm_adc_mid : uncapped;
        end else if (crpm >= afm_rpm_hi) begin
            afm_wiper = afm_adc_hi;
        end else begin
            // Rising segment: plateau end -> redline's ceiling
            afm_wiper = afm_adc_mid +
                        ((afm_adc_hi - afm_adc_mid) * (crpm - afm_rpm_plateau_end))
                        / (afm_rpm_hi - afm_rpm_plateau_end);
        end
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
        tdc             = 1'b0;
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
    reg [21:0] ref_low_cnt;   // 22-bit: fits up to 87*(2727272/100) —
                               // widened from 21-bit since 87 > the old
                               // 66-tooth multiplier would have overflowed
                               // 21 bits at RPMSTART=100
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
            ref_low_cnt    <= 22'd0;
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

                // Falling edge: hold low for 87 tooth periods (45-tooth
                // HIGH period, per real DME scope measurement — not the
                // 50%/66-tooth figure this was originally based on).
                int_0          <= 1'b0;
                ref_low_active <= 1'b1;
                ref_fired_this_rev <= 1'b1;
                ref_low_cnt    <= 87 * period_current - 1;

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
                    // Fuel-quality compensation (FQS driver switch): firmware
                    // widens/narrows the injector pulse to compensate for
                    // off-spec fuel, so a working compensation system should
                    // deliver roughly the SAME combustion energy regardless
                    // of fuel quality — not more energy just because the
                    // pulse got wider. Scale by the inverse of the pulse-
                    // width compensation (CL_FUEL_ENERGY_PCT) so richer
                    // pulse width (weak fuel, +pct) and leaner pulse width
                    // (potent fuel, -pct) roughly cancel, leaving combustion
                    // close to the FQS0/normal-fuel baseline. Deliberately
                    // imperfect — real compensation isn't exact either.
                    combustion = (fuel_sample / 5 * `CL_FUEL_SCALE * 100) / (100 + `CL_FUEL_ENERGY_PCT) / 100;

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
    //  uses to transition (see the ref-pulse logic above: triggers on
    //  int_1's falling edge) — so tdc's assert/deassert points land on
    //  exactly the same class of edge as the reference pulse, not an
    //  arbitrary half-tooth point. Counting actual edges (not a clock-
    //  length countdown) is also immune to period_current changing
    //  between pulses — which happens essentially every cycle here,
    //  since RPM is a live physics output, not just during a scripted
    //  ramp — whereas a fixed-clock-count approach is not immune to it.
    //
    //  Armed directly off int_0's own falling edge (not off the internal
    //  ref-pulse state machine above), so this block is fully independent
    //  and can't interact with or destabilize the CL dynamics/ref logic.
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
