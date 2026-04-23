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
//    CL_INERTIA      10     fixed-point scale (lower = more responsive)
//    CL_FRICTION     25     motoring friction (post-ASE idle ~1.83ms → combustion≈26 > friction=25)
//    CL_AC_TORQUE    4      extra load when T1=1 (AC compressor, ~50 RPM droop)
//    CL_FUEL_SCALE   14     combustion torque per ms of injection pulse
//                           tuned so idle fuel (~2.35ms) gives net≈0
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
  `define CL_INERTIA     10    // low = visible RPM changes at 100ms snapshots
`endif
`ifndef CL_FRICTION
  `define CL_FRICTION    25   // tuned: post-ASE idle ~1.83ms → combustion≈26 > friction=25
`endif
`ifndef CL_AC_TORQUE
  `define CL_AC_TORQUE   4    // AC compressor load — tuned for ~50 RPM droop at idle
`endif
`ifndef CL_FUEL_SCALE
  `define CL_FUEL_SCALE  14   // idle ~1.97ms → combustion≈27 > friction=26 → net≈+1
`endif

`ifdef DASHBOARD_TB
  `define CL_TB          i8051_dashboard_tb
`else
  `define CL_TB          i8051_tb
`endif
`define CL_IRAM(n)       `CL_TB.i8051_top.u_cpu.iram[7'h``n]

module var_interrupt_generator (
    input  wire clk,
    input  wire rst,
    output reg  int_0,
    output reg  int_1,
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
    always @(posedge clk or negedge rst) begin : speed_sensor_gen
        if (!rst) begin
            tick_counter <= 0;
            int_1        <= 1'b1;
        end else begin
            if (tick_counter >= (period_current / 2) - 1) begin
                tick_counter <= 0;
                int_1        <= ~int_1;
            end else begin
                tick_counter <= tick_counter + 1;
            end
        end
    end

    // ── Tooth counter ────────────────────────────────────────────
    reg [7:0] counter;
    always @(posedge int_1 or negedge rst) begin : tooth_counter
        if (!rst)          counter <= 8'd0;
        else if (counter >= 8'd131) counter <= 8'd0;
        else               counter <= counter + 1'b1;
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

    always @(posedge clk or negedge rst) begin : ref_and_dynamics
        integer fuel_sample;
        integer combustion;
        integer friction;
        integer net;
        integer new_rpm_fp;
        integer crpm;

        if (!rst) begin
            int_0          <= 1'b1;
            ref_low_active <= 1'b0;
            ref_low_cnt    <= 21'd0;
            rpm_fp         <= `CL_RPM_TARGET * `CL_INERTIA;
            period_current <= `RPMCONST / `CL_RPM_TARGET;
            synced_once    <= 1'b0;
        end else begin

            // Latch EngineSync permanently once seen — don't read live
            if (`CL_IRAM(21) & 8'h01)
                synced_once <= 1'b1;

            // ── Reference pulse falling edge ──────────────────────
            if (counter == 8'd0 && int_1 == 1'b0 &&
                tick_counter == (period_current/2 - 1 - period_current/5)) begin

                int_0          <= 1'b0;
                ref_low_active <= 1'b1;
                ref_low_cnt    <= 66 * period_current - 1;

                // ── Torque update ─────────────────────────────────
                fuel_sample = {`CL_IRAM(4B), `CL_IRAM(4A)};
                fuel_pulse_prev <= fuel_sample;
                fuel_ms_x100    <= fuel_sample / 5;

                // Gate: hold RPM at target before first engine sync, or
                // during FuelOffCoast (iram[23h].5) to prevent stall.
                if (!synced_once || (`CL_IRAM(23) & 8'h20)) begin
                    // Pre-sync or fuel cut — clamp to target, no dynamics
                    rpm_fp         <= `CL_RPM_TARGET * `CL_INERTIA;
                    period_current <= `RPMCONST / `CL_RPM_TARGET;
                end else begin
                    combustion = (fuel_sample / 5 * `CL_FUEL_SCALE) / 100;

                    friction = `CL_FRICTION;
                    if (`CL_TB.t1 == 1'b1)
                        friction = friction + `CL_AC_TORQUE;

                    net = combustion - friction;

                    new_rpm_fp = rpm_fp + net;
                    if      (new_rpm_fp > rpm_fp_max) new_rpm_fp = rpm_fp_max;
                    else if (new_rpm_fp < rpm_fp_min) new_rpm_fp = rpm_fp_min;

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
