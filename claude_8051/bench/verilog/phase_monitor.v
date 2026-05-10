// ============================================================
//  DME 951 Phase Monitor  —  paste into testbench module body
//
//  Requires: clk, rst
//
//  Time display: DME-equivalent milliseconds
//    1 machine cycle = 12 osc clocks = 2µs at 6MHz
//    ms = cycle_count / 6000
// ============================================================

// ----------------------------------------------------------------
//  NTC linearised-value → degrees Celsius
//
//  Two-point linear fit: 0x8F (143) = 10°C, 0xDE (222) = 80°C
//  Slope = 70/79 ≈ 0.886°C per count.
//  Returns integer; negative values work because diff is signed.
// ----------------------------------------------------------------
function automatic integer ntc_celsius;
    input [7:0] lin;
    integer diff;
    begin
        diff = $signed(9'd0 + lin) - 143;  // force signed subtraction
        ntc_celsius = 10 + (diff * 70) / 79;
    end
endfunction

// Pre-computed temperature display values — updated each STATUS snapshot
// 9999 = sentinel (shadow not yet valid, shown as obviously wrong value)
integer cool_c_disp;
integer air_c_disp;
reg        ph_intblock_prev;
reg        ph_usemap_prev;
reg        ph_coldenrich_prev;
reg        ph_coldtiming_prev;
reg        ph_o2_prev;
reg        ph_fuelcut_prev;
reg        ph_isvovf_prev;
reg [7:0]  ph_wdog_prev;
reg [63:0] ph_next_snap;

initial begin
    ph_intblock_prev   = 1'b1;
    ph_usemap_prev     = 1'b0;
    ph_coldenrich_prev = 1'b0;
    ph_coldtiming_prev = 1'b0;
    ph_o2_prev         = 1'b0;
    ph_fuelcut_prev    = 1'b0;
    ph_isvovf_prev     = 1'b0;
    ph_wdog_prev       = 8'hFF;
    ph_next_snap       = 64'd18000;   // first snapshot at 3ms DME time
end

// ----------------------------------------------------------------
//  Unified monitor — single always block avoids NBA ordering issues
// ----------------------------------------------------------------
always @(posedge clk) begin : dme_phase_monitor

    if (!rst) begin
        ph_intblock_prev   <= 1'b1;
        ph_usemap_prev     <= 1'b0;
        ph_coldenrich_prev <= 1'b0;
        ph_coldtiming_prev <= 1'b0;
        ph_o2_prev         <= 1'b0;
        ph_fuelcut_prev    <= 1'b0;
        ph_isvovf_prev     <= 1'b0;
        ph_wdog_prev       <= 8'hFF;
        ph_next_snap       <= 64'd18000;
    end else begin

        // ---- InterruptBlock  iram[23h].4  (bit 1Ch) ----
        if ( i8051_tb.i8051_top.u_cpu.iram[7'h23][4] && !ph_intblock_prev)
            $display("DME: [PHASE] t=%0d ms  INTERRUPT BLOCK set      (watchdog or power-on reset)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        if (!i8051_tb.i8051_top.u_cpu.iram[7'h23][4] &&  ph_intblock_prev)
            $display("DME: [PHASE] t=%0d ms  INTERRUPT BLOCK cleared  (engine synced — fully running)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        ph_intblock_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h23][4];

        // ---- UseMap1140  iram[21h].5  (bit 0Dh) ----
        if ( i8051_tb.i8051_top.u_cpu.iram[7'h21][5] && !ph_usemap_prev)
            $display("DME: [PHASE] t=%0d ms  AFTER-START ENRICH begin (UseMap1140 set, iram[3Ch]=0x%02X)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000,
                     i8051_tb.i8051_top.u_cpu.iram[7'h3C]);
        if (!i8051_tb.i8051_top.u_cpu.iram[7'h21][5] &&  ph_usemap_prev)
            $display("DME: [PHASE] t=%0d ms  AFTER-START ENRICH end   (UseMap1140 clr, iram[3Ch]=0x%02X)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000,
                     i8051_tb.i8051_top.u_cpu.iram[7'h3C]);
        ph_usemap_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h21][5];

        // ---- UseColdStartEnrichMap  iram[25h].5  (bit 2Dh) ----
        if ( i8051_tb.i8051_top.u_cpu.iram[7'h25][5] && !ph_coldenrich_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START ENRICH begin     (bit2Dh set)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        if (!i8051_tb.i8051_top.u_cpu.iram[7'h25][5] &&  ph_coldenrich_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START ENRICH end       (bit2Dh clr)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        ph_coldenrich_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h25][5];

        // ---- UseColdStartTimingMaps  iram[25h].4  (bit 2Ch) ----
        if ( i8051_tb.i8051_top.u_cpu.iram[7'h25][4] && !ph_coldtiming_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START TIMING begin     (bit2Ch set)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        if (!i8051_tb.i8051_top.u_cpu.iram[7'h25][4] &&  ph_coldtiming_prev)
            $display("DME: [PHASE] t=%0d ms  COLD-START TIMING end       (bit2Ch clr)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        ph_coldtiming_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h25][4];

        // ---- O2 lean/rich  iram[24h].3  (bit 23h) ----
        // SETB at 0x0B07 when P1.7=1 (lean), CLR at 0x0B1D when P1.7=0 (rich)
        if ( i8051_tb.i8051_top.u_cpu.iram[7'h24][3] && !ph_o2_prev)
            $display("DME: [PHASE] t=%0d ms  LAMBDA O2 lean               (bit23h set)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        if (!i8051_tb.i8051_top.u_cpu.iram[7'h24][3] &&  ph_o2_prev)
            $display("DME: [PHASE] t=%0d ms  LAMBDA O2 rich               (bit23h clr)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        ph_o2_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h24][3];

        // ---- FuelOffCoast  iram[23h].5  (bit 1Dh) ----
        if ( i8051_tb.i8051_top.u_cpu.iram[7'h23][5] && !ph_fuelcut_prev)
            $display("DME: [PHASE] t=%0d ms  FUEL CUT begin               (FuelOffCoast set)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        if (!i8051_tb.i8051_top.u_cpu.iram[7'h23][5] &&  ph_fuelcut_prev)
            $display("DME: [PHASE] t=%0d ms  FUEL CUT end                 (FuelOffCoast clr)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        ph_fuelcut_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h23][5];

        // ---- ISVPWMOverflow  iram[20h].5  (bit 05h) ----
        if ( i8051_tb.i8051_top.u_cpu.iram[7'h20][5] && !ph_isvovf_prev)
            $display("DME: [PHASE] t=%0d ms  ISV OVERFLOW begin           (isv=0x%02X)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000,
                     i8051_tb.i8051_top.u_cpu.iram[7'h7F]);
        if (!i8051_tb.i8051_top.u_cpu.iram[7'h20][5] &&  ph_isvovf_prev)
            $display("DME: [PHASE] t=%0d ms  ISV OVERFLOW end             (isv=0x%02X)",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000,
                     i8051_tb.i8051_top.u_cpu.iram[7'h7F]);
        ph_isvovf_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h20][5];

        // ---- Watchdog expiry ----
        if (i8051_tb.i8051_top.u_cpu.iram[7'h2A] == 8'h00 && ph_wdog_prev != 8'h00)
            $display("DME: [PHASE] t=%0d ms  WATCHDOG EXPIRED",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
        ph_wdog_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h2A];

        // ---- Periodic STATUS: every 100ms DME time ----
        if (i8051_tb.i8051_top.u_cpu.cycle_count >= ph_next_snap) begin
            cool_c_disp = (coolant_shadow == 8'hFF) ? 9999 : ntc_celsius(coolant_shadow);
            air_c_disp  = (airtemp_shadow == 8'hFF) ? 9999 : ntc_celsius(airtemp_shadow);
            $display("DME: [STATUS] t=%0d ms  prpm(37)=0x%02X (%0d RPM)  fuel_hb(4B)=0x%02X  fuel_lb(4A)=0x%02X  afm_raw(10)=0x%02X  afm_peak(3D)=0x%02X  load(46:47)=0x%02X%02X  load_idx(49)=0x%02X  coolant(13)=0x%02X (%0d degC)  airtemp(12)=0x%02X (%0d degC)  dwell(2F)=0x%02X  isv(7F)=0x%02X  wdog(2A)=0x%02X  B(F0)=0x%02X  wu(58:59)=0x%02X%02X  flags(21)=0x%02X (23)=0x%02X (25)=0x%02X",
                     i8051_tb.i8051_top.u_cpu.cycle_count / 6000,
                     i8051_tb.i8051_top.u_cpu.iram[7'h37],              // prpm hex
                     i8051_tb.i8051_top.u_cpu.iram[7'h37] * 40,         // RPM
                     i8051_tb.i8051_top.u_cpu.iram[7'h4B],              // fuel_hb
                     i8051_tb.i8051_top.u_cpu.iram[7'h4A],              // fuel_lb
                     afm_raw_shadow,                                      // afm_raw ADC (shadowed)
                     i8051_tb.i8051_top.u_cpu.iram[7'h3D],              // afm_peak
                     i8051_tb.i8051_top.u_cpu.iram[7'h46],              // load hi
                     i8051_tb.i8051_top.u_cpu.iram[7'h47],              // load lo
                     i8051_tb.i8051_top.u_cpu.iram[7'h49],              // load_idx
                     coolant_shadow,                                      // coolant hex
                     cool_c_disp,                                         // coolant degC (9999=N/A)
                     airtemp_shadow,                                      // airtemp hex
                     air_c_disp,                                          // airtemp degC (9999=N/A)
                     i8051_tb.i8051_top.u_cpu.iram[7'h2F],              // dwell_angle
                     isv_shadow,                                          // isv_step (0xFF=N/A)
                     i8051_tb.i8051_top.u_cpu.iram[7'h2A],              // watchdog
                     i8051_tb.i8051_top.u_cpu.b_reg,                    // B reg
                     i8051_tb.i8051_top.u_cpu.iram[7'h58],              // warmup hi
                     i8051_tb.i8051_top.u_cpu.iram[7'h59],              // warmup lo
                     i8051_tb.i8051_top.u_cpu.iram[7'h21],              // flags 21
                     i8051_tb.i8051_top.u_cpu.iram[7'h23],              // flags 23
                     i8051_tb.i8051_top.u_cpu.iram[7'h25]);             // flags 25
            ph_next_snap <= ph_next_snap + 64'd600_000;  // every 100ms at 6MHz
            $fflush();
        end

    end // rst

end // dme_phase_monitor



// ----------------------------------------------------------------
//  ISV shadow — filters early-startup garbage writes to iram[7Fh]
//
//  iram[7Fh] holds the ISV step position.  Valid range is 0x00–0x40.
//  During early startup the firmware briefly writes arbitrary values
//  before settling; the shadow only latches values in the valid range.
//  iram[7Fh] is stable at the current ISV position between firmware
//  updates — no dithering occurs during normal operation.
//  Held at 0xFF during reset (sentinel = not yet seen).
// ----------------------------------------------------------------
reg [7:0] isv_shadow;

always @(posedge clk) begin : isv_shadow_track
    if (!rst)
        isv_shadow <= 8'hFF;
    else if (i8051_tb.i8051_top.u_cpu.iram[7'h7F] <= 8'h40)
        isv_shadow <= i8051_tb.i8051_top.u_cpu.iram[7'h7F];
end // isv_shadow_track

// ----------------------------------------------------------------
//  AFM raw shadow — prevents battery-voltage bleed in STATUS
//
//  iram[10h] briefly holds ch1 (battery, 0xD8) during the ADC scan.
//  Shadow only updates when value is in the AFM range (<=0x64).
// ----------------------------------------------------------------
reg [7:0] afm_raw_shadow;

always @(posedge clk) begin : afm_raw_track
    if (!rst)
        afm_raw_shadow <= 8'h00;
    else if (i8051_tb.i8051_top.u_cpu.iram[7'h10] <= 8'h64)
        afm_raw_shadow <= i8051_tb.i8051_top.u_cpu.iram[7'h10];
end // afm_raw_track

// ----------------------------------------------------------------
//  Coolant and airtemp shadows — prevent raw ADC bleed in STATUS
//
//  The firmware writes the raw ADC value into iram[12h:13h] then
//  immediately linearises it in place. The STATUS snapshot can
//  fire between these two writes, showing the raw value instead
//  of the linearised result.
//
//  Raw ADC values: ch2(air)=0x50, ch3(coolant)=0x20 — both low.
//  Linearised warm values: airtemp~0x9E, coolant~0xDE — both high.
//  Shadow only updates when value >= 0x80 (safely above raw range).
//  Held at 0xFF during reset (sentinel = not yet seen).
// ----------------------------------------------------------------
reg [7:0] coolant_shadow;
reg [7:0] airtemp_shadow;

always @(posedge clk) begin : ntc_shadow_track
    if (!rst) begin
        coolant_shadow <= 8'hFF;
        airtemp_shadow <= 8'hFF;
    end else begin
        if (i8051_tb.i8051_top.u_cpu.iram[7'h13] >= 8'h80)
            coolant_shadow <= i8051_tb.i8051_top.u_cpu.iram[7'h13];
        if (i8051_tb.i8051_top.u_cpu.iram[7'h12] >= 8'h80)
            airtemp_shadow <= i8051_tb.i8051_top.u_cpu.iram[7'h12];
    end
end // ntc_shadow_track


// ----------------------------------------------------------------
//  Lambda warm-up skip  (enabled by `define SKIP_LAMBDA_WARMUP)
//
//  On a warm engine the warmup counter is bypassed but bit1Dh
//  (FuelOffCoast / lambda-integrator-enable) is never set.
//  This block seeds it at engine sync so closed-loop lambda
//  runs immediately.
//
//  bit08h: prevents phase1 counter from reloading
//  bit1Dh: enables lambda integrator path at 0x09CF
//  wu counter: seeded near zero so any residual warmup expires fast
// ----------------------------------------------------------------
`ifdef SKIP_LAMBDA_WARMUP
reg skip_lambda_done;
reg skip_lambda_intblock_prev;
initial begin
    skip_lambda_done          = 1'b0;
    skip_lambda_intblock_prev = 1'b1;
end

always @(posedge clk) begin : lambda_warmup_skip
    skip_lambda_intblock_prev <= i8051_tb.i8051_top.u_cpu.iram[7'h23][4];

    if (rst && !skip_lambda_done &&
        skip_lambda_intblock_prev &&
        !i8051_tb.i8051_top.u_cpu.iram[7'h23][4]) begin
        i8051_tb.i8051_top.u_cpu.iram[7'h21][0] <= 1'b1;  // bit08h = phase1 init done
        i8051_tb.i8051_top.u_cpu.iram[7'h21][1] <= 1'b1;  // bit09h = phase2 init done
        i8051_tb.i8051_top.u_cpu.iram[7'h23][5] <= 1'b1;  // bit1Dh = FuelOffCoast
        i8051_tb.i8051_top.u_cpu.iram[7'h58]    <= 8'h00; // warmup counter hi = 0
        i8051_tb.i8051_top.u_cpu.iram[7'h59]    <= 8'h01; // warmup counter lo = 1
        skip_lambda_done <= 1'b1;
        $display("DME: [SEED] t=%0d ms  SKIP_LAMBDA_WARMUP — bit08h+09h+1Dh set, wu=0x0001",
                 i8051_tb.i8051_top.u_cpu.cycle_count / 6000);
    end
end // lambda_warmup_skip
`endif // SKIP_LAMBDA_WARMUP

