// Default RPM_RAMP_PCT if not set by the including testbench.
// i8051_tb.v sets this via `undef/`define before each use.
`ifndef RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
`endif

module var_interrupt_generator (
    input  wire clk,        // Fast Master Clock
    input  wire rst,        // Active high reset
    output reg  int_0,int_1,// The slowing square wave
    output reg  [7:0] afm_wiper // AFM wiper value tracking RPM ramp
);
    integer period_current = `RPMCONST/`RPMSTART;  // initialised = no Z on afm_wiper at t=0
    integer tick_counter = 0;
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
        integer current_rpm;
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
    localparam SIM_TIME_MS  = `SIM_TIME / 1_000_000;   // ns → ms, stays in 32-bit range
    localparam ramp_ms      = SIM_TIME_MS * `RPM_RAMP_PCT / 100;
    localparam step_clocks  = ramp_ms * `DME_FREQ / rpm_steps;  // FREQ in kHz → clocks/ms

    integer current_rpm;
    integer master_clk_count = 0;
    localparam rpm_inc_val = (`RPMEND - `RPMSTART) / rpm_steps;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            int_1             <= 1;
            tick_counter      <= 0;
            master_clk_count  <= 0;
            current_rpm        = `RPMSTART;
            period_current     = period_start;

        end else begin
            // Count master clocks for RPM step timing
            master_clk_count <= master_clk_count + 1;
            if (master_clk_count >= step_clocks) begin
                master_clk_count <= 0;
                if (current_rpm < `RPMEND) begin
                    current_rpm = current_rpm + rpm_inc_val;
                    if (current_rpm > `RPMEND) current_rpm = `RPMEND;
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

            // Generate int_1 square wave at current period
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
    //    Single pulse per revolution, 50% duty cycle of one tooth period.
    //    Firmware triggers on falling edge (INT0 ISR).
    //
    //  Reference pulse timing:
    //    Falling edge: period/5 clocks before the speed sensor RISING edge,
    //      i.e. tick_counter == period/2 - 1 - period/5  during LOW phase of tooth 0.
    //      At ~909 RPM (0.5ms tooth): period/5 = 600 clocks = 0.1ms.
    //
    //    Rising edge: 50% duty cycle = period/2 clocks after the falling edge.
    //      The LOW phase only provides period/5 clocks remaining, so the
    //      rising edge spills into the HIGH phase of tooth 0:
    //        clocks remaining in LOW phase : period/5
    //        clocks needed in HIGH phase   : period/2 - period/5 = 3*period/10
    //      Rising edge fires at tick_counter == 3*period/10 - 1 in the HIGH phase.
    // --------------------------------------------------------
    reg [7:0] counter;

    // Tooth counter — increments on every rising edge of int_1
    always @(posedge int_1 or negedge rst) begin : tooth_counter
        if (!rst)
            counter <= 8'd0;
        else if (counter >= 8'd131)
            counter <= 8'd0;
        else
            counter <= counter + 1'b1;
    end

    // Reference sensor pulse — clock-accurate edge timing
    //
    //  The ref pulse is LOW for half a revolution (66 tooth periods),
    //  falling period/5 clocks before the speed sensor rising edge at
    //  tooth 0.  This gives a 50% duty cycle across the full 132-tooth
    //  revolution, matching the scope trace where the ref signal is low
    //  for roughly half the flywheel rotation.
    reg [20:0] ref_low_cnt;   // 21-bit: fits up to 66 * (2727272/100) = ~1.8M clocks
    reg        ref_low_active;
    reg        ref_fired_this_rev;  // latch: ref pulse already fired for tooth 0

    always @(posedge clk or negedge rst) begin : ref_sensor_gen
        if (!rst) begin
            int_0              <= 1'b1;
            ref_low_active     <= 1'b0;
            ref_low_cnt        <= 21'd0;
            ref_fired_this_rev <= 1'b0;
        end else begin
            // Clear the per-rev latch once we leave tooth 0 so it can re-arm.
            if (counter != 8'd0)
                ref_fired_this_rev <= 1'b0;

            // Falling edge: use a CROSSING (>=) test, not exact-match (==).
            // period_current steps every ~100ms during the RPM ramp; an exact
            // == target can be skipped when the threshold shifts mid-revolution,
            // causing a missed ref pulse → doubled measured period → half-RPM
            // sawtooth. A >= crossing plus a once-per-rev latch is robust.
            if (counter == 8'd0 && int_1 == 1'b0 && !ref_fired_this_rev &&
                tick_counter >= (period_current/2 - 1 - period_current/5)) begin
                // Falling edge: hold low for 66 tooth periods
                int_0              <= 1'b0;
                ref_low_active     <= 1'b1;
                ref_fired_this_rev <= 1'b1;
                ref_low_cnt        <= 66 * period_current - 1;
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
