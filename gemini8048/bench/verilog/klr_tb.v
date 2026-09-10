// ============================================================
//  klr_tb.v  —  Top-level testbench for the Porsche 944 Turbo
//               KLR (Klopfregelgerät) simulation
//
//  Companion files required to compile:
//    timescale.v            — shared `timescale 1ns/10ps
//    i8048_core.v           — Intel 8049 CPU core
//    adc_8090.v             — ADC0809 8-channel mux model
//    adc_delay.v            — ADC0809 start/stop/hold timing
//    var_timing_gen.v       — variable-RPM crank/ign generator
//    klr_top.v              — klr_system + klr_eprom
//    klr_vcd.v              — updated VCD/disassembly monitor
//    knock_gen.v            — knock_sum (ch5) = !knock_reset ? 0d :
//                              (fake_knock burst-stretched to >=2.4ms
//                              ? knock_sensor+145d : knock_sensor);
//                              knock_noise (ch0) = fake_knock (raw) ?
//                              knock_sensor+145d : knock_sensor
//                              (knock_sensor currently a fixed 110d
//                              placeholder — real model TBD)
//
//  Compile:
//    iverilog -o klr.vvp -s klr_tb \
//      timescale.v i8048_core.v adc_8090.v adc_delay.v \
//      var_timing_gen.v klr_top.v klr_vcd.v knock_gen.v klr_tb.v
//
//  Simulate:
//    vvp klr.vvp
//
//  Runtime files (read by $readmemh at simulation start):
//    87KLR_951.mem          — KLR EPROM image (loaded in klr_top)
//    op_ins8048.hex         — 8049 opcode table  (loaded in i8048_core)
//    test_sim.hex           — disassembly labels (loaded in klr_vcd)
//    memory_byte_map.hex    — RAM symbol map      (loaded in klr_vcd)
//    asm_opcode_ins.hex     — ASM opcodes         (loaded in klr_vcd)
//    asm_instr.hex          — ASM mnemonics       (loaded in klr_vcd)
//    asm_operands.hex       — ASM operands        (loaded in klr_vcd)
//    asm_operands_numeric.hex                     (loaded in klr_vcd)
//
//  Output files (written by $writememh at end of simulation):
//    rom_out.hex            — EPROM contents snapshot
//    ram_out.hex            — internal RAM snapshot
//
//  Instance naming convention
//  ──────────────────────────
//  The klr_system instance is deliberately named `top` (not u_klr)
//  so that the hierarchical references already in klr_vcd.v —
//  `top.clk`, `top.pc` — resolve correctly without any change to
//  the always block.  Only the four $dumpvars paths were updated
//  from i8048_tb.* to klr_tb.* (see klr_vcd.v).
// ============================================================

`include "timescale.v"

// ── Simulation parameters ─────────────────────────────────
//  All `define macros are in klr_defs.v (compiled first).
//  They are not repeated here to avoid redefinition warnings.

module klr_tb #(parameter EXT_STIM = 0) (
    // Inter-ECU ports — only used when EXT_STIM=1 (combined DME+KLR mode).
    // In standalone mode (EXT_STIM=0) these are left unconnected and the
    // internal var_timing_generator drives trigger/ign instead.
    input  wire ext_trigger,        // DME A_5_KLR_ign_out → KLR trigger_in (inverted)
    input  wire ext_ign,            // DME A_1_tach_pulse  → KLR ign_in     (inverted)
    output wire ign_out,            // KLR P2.7 → DME ign  (retard-gated spark)
    output wire full_load,          // KLR P1.5 → DME full_load (WOT flag)
    // TPS angle input from DME side — only meaningful when EXT_STIM=1
    // TPS supply is fixed (5V regulated on KLR board, independent of 12V battery)
    input  wire [7:0] tps_wiper,   // DME AFM wiper ADC value → KLR TPS angle ch7
    // RPM from the DME physics model — u_dme.ref_rpm is reg [31:0] in
    // i8051_dashboard_tb.v (a direct tick-count-based RPM calc, not the
    // 16-bit-range var_interrupt_gen_cl.v crpm value), so this port must
    // match that width exactly to avoid silently truncating. Only
    // meaningful when EXT_STIM=1. Used by the -DBOOST turbo-boost ADC
    // model below (ch4). Harmless if left unconnected/unused when
    // -DBOOST isn't defined.
    input  wire [31:0] rpm_in,
    // Knock sensor input — only meaningful when EXT_STIM=1. Driven from
    // dme_klr_dashboard_tb.v (crank-position-synchronized pulse logic
    // lives there now, alongside tdc/speed_sensor from the DME side —
    // see that file for TEST_KNOCK_PULSE). No default value on the
    // port itself — that's SystemVerilog-only syntax iverilog rejects
    // in default (non-SV) mode. Standalone klr_tb (top-level,
    // unconnected, EXT_STIM=0) substitutes nominal 110 via
    // knock_sensor_i below instead, so standalone behaves exactly as
    // before this port existed — see that wire's own comment for why
    // this isn't a 'z'-detection idiom (Verilator rejects that as
    // unsupported tristate I/O).
    input  wire [7:0] knock_sensor
);

    // ── Clock ─────────────────────────────────────────────
    parameter DELAY = `FRQ_SCALE / `KLR_FREQ;  // half-period ≈ 45 ns → ~11.1 MHz

    reg clk = 0;
    always #DELAY clk <= ~clk;

    // ── Simulation master reset ───────────────────────────────
    //  sim_rst feeds var_timing_generator (active-high).
    //  The CPU /RESET is now driven internally by ~trigger_in.
    reg sim_rst = 0;

    // ── Crank / ignition stimulus from var_timing_generator ──
    wire trigger;   // crank reference pulse from internal generator
    wire ign;       // ignition signal from internal generator

    // When EXT_STIM=1, use port inputs; otherwise use internal generator.
    wire trigger_in_mux = (EXT_STIM) ? ext_trigger : trigger;
    wire ign_in_mux     = (EXT_STIM) ? ext_ign     : ign;

    // ── KLR outputs ──────────────────────────────────────
    // ign_out and full_load are module output ports when EXT_STIM=1,
    // or internal wires in standalone mode.
    wire ign_out_n;     // P2.6 — complementary (internal only)

    // ── ADC channel stimulus ──────────────────────────────
    //  Initial values match i8048_tb.v: static signed constants so
    //  the firmware can run its conversion loop immediately.
    reg [7:0] adc_ch1 = 8'hd8;  // battery
    reg [7:0] adc_ch2 = 8'h00;  // ground
`ifndef BOOST
    reg [7:0] adc_ch4 = 8'h85;  // conn 23 MAP sensor — fixed value; see -DBOOST for the modeled version
`endif
    reg [7:0] adc_ch6 = 8'h87;  // conn 25

`ifdef BOOST
    // ── Turbo boost ADC input (ch4) — MAP-table based ──────────
    //  Modeled from the real KLR boost map (throttle% x RPM ->
    //  ADC "software units"), '89 table, from:
    //  https://jhnbyrn.github.io/951-KLR-PAGES/klr_memory_map.html
    //
    //  The firmware's ADC-read routine adds 10 units to the raw ADC
    //  reading before storing it to ram[52h] — the boost map values
    //  documented on that page are already in that POST-offset
    //  ("software units") scale, so the raw ch4 value driven here
    //  is (table_value - 10), reversing that offset.
    //
    //  Only meaningful in combined mode (EXT_STIM=1) — needs a real
    //  RPM (rpm_in, wired from u_dme.ref_rpm in dme_klr_dashboard_tb.v —
    //  a tick-count-based measurement of the actual generated reference-
    //  sensor edges, which tracks var_interrupt_gen_cl.v's crpm at
    //  steady state) and throttle% (derived from tps_wiper using the
    //  SAME AFM idle/WOT anchor points already used for the TPS-angle
    //  ch7 mapping above: AFM idle=40 -> 0%, AFM WOT=235 -> 100%).
    //  Falls back to the prior fixed 0x85 in standalone mode
    //  (EXT_STIM=0), where no real RPM/throttle% exists to drive this.
    //
    //  Bilinear interpolation over the table, clamped at the table's
    //  edges (RPM 0-6050, throttle 57.0-87.1%) rather than
    //  extrapolated — the 6000-family can genuinely exceed 6050rpm
    //  in transients, in which case this just holds the rightmost
    //  column's value (flat extrapolation, not a cliff).
    localparam BOOST_NUM_RPM_BP = 16;
    localparam BOOST_NUM_THR_BP = 8;

    real boost_rpm_bp [0:BOOST_NUM_RPM_BP-1];
    real boost_thr_bp [0:BOOST_NUM_THR_BP-1];
    // Flattened [throttle_row][rpm_col], index = row*BOOST_NUM_RPM_BP + col
    real boost_table  [0:(BOOST_NUM_THR_BP*BOOST_NUM_RPM_BP)-1];

    initial begin
        boost_rpm_bp[0]  = 0.0;    boost_rpm_bp[1]  = 1864.0; boost_rpm_bp[2]  = 2041.0; boost_rpm_bp[3]  = 2254.0;
        boost_rpm_bp[4]  = 2446.0; boost_rpm_bp[5]  = 2674.0; boost_rpm_bp[6]  = 2948.0; boost_rpm_bp[7]  = 3164.0;
        boost_rpm_bp[8]  = 3415.0; boost_rpm_bp[9]  = 3708.0; boost_rpm_bp[10] = 4057.0; boost_rpm_bp[11] = 4479.0;
        boost_rpm_bp[12] = 4724.0; boost_rpm_bp[13] = 4998.0; boost_rpm_bp[14] = 5653.0; boost_rpm_bp[15] = 6050.0;

        boost_thr_bp[0] = 57.0; boost_thr_bp[1] = 61.3; boost_thr_bp[2] = 65.6; boost_thr_bp[3] = 69.9;
        boost_thr_bp[4] = 74.2; boost_thr_bp[5] = 78.5; boost_thr_bp[6] = 82.8; boost_thr_bp[7] = 87.1;

        // Row 57.0%
        boost_table[0*16+0]=137.0; boost_table[0*16+1]=141.0; boost_table[0*16+2]=144.0; boost_table[0*16+3]=145.0;
        boost_table[0*16+4]=145.0; boost_table[0*16+5]=146.0; boost_table[0*16+6]=146.0; boost_table[0*16+7]=148.0;
        boost_table[0*16+8]=148.0; boost_table[0*16+9]=148.0; boost_table[0*16+10]=150.0; boost_table[0*16+11]=150.0;
        boost_table[0*16+12]=150.0; boost_table[0*16+13]=152.0; boost_table[0*16+14]=152.0; boost_table[0*16+15]=152.0;
        // Row 61.3%
        boost_table[1*16+0]=139.0; boost_table[1*16+1]=141.0; boost_table[1*16+2]=145.0; boost_table[1*16+3]=151.0;
        boost_table[1*16+4]=154.0; boost_table[1*16+5]=157.0; boost_table[1*16+6]=157.0; boost_table[1*16+7]=158.0;
        boost_table[1*16+8]=158.0; boost_table[1*16+9]=158.0; boost_table[1*16+10]=158.0; boost_table[1*16+11]=158.0;
        boost_table[1*16+12]=158.0; boost_table[1*16+13]=158.0; boost_table[1*16+14]=158.0; boost_table[1*16+15]=158.0;
        // Row 65.6%
        boost_table[2*16+0]=139.0; boost_table[2*16+1]=141.0; boost_table[2*16+2]=148.0; boost_table[2*16+3]=157.0;
        boost_table[2*16+4]=164.0; boost_table[2*16+5]=167.0; boost_table[2*16+6]=167.0; boost_table[2*16+7]=170.0;
        boost_table[2*16+8]=170.0; boost_table[2*16+9]=167.0; boost_table[2*16+10]=167.0; boost_table[2*16+11]=167.0;
        boost_table[2*16+12]=166.0; boost_table[2*16+13]=165.0; boost_table[2*16+14]=165.0; boost_table[2*16+15]=165.0;
        // Row 69.9%
        boost_table[3*16+0]=141.0; boost_table[3*16+1]=142.0; boost_table[3*16+2]=159.0; boost_table[3*16+3]=170.0;
        boost_table[3*16+4]=177.0; boost_table[3*16+5]=180.0; boost_table[3*16+6]=180.0; boost_table[3*16+7]=180.0;
        boost_table[3*16+8]=180.0; boost_table[3*16+9]=177.0; boost_table[3*16+10]=176.0; boost_table[3*16+11]=175.0;
        boost_table[3*16+12]=174.0; boost_table[3*16+13]=171.0; boost_table[3*16+14]=171.0; boost_table[3*16+15]=171.0;
        // Row 74.2%
        boost_table[4*16+0]=143.0; boost_table[4*16+1]=145.0; boost_table[4*16+2]=171.0; boost_table[4*16+3]=190.0;
        boost_table[4*16+4]=193.0; boost_table[4*16+5]=193.0; boost_table[4*16+6]=193.0; boost_table[4*16+7]=193.0;
        boost_table[4*16+8]=193.0; boost_table[4*16+9]=191.0; boost_table[4*16+10]=188.0; boost_table[4*16+11]=186.0;
        boost_table[4*16+12]=184.0; boost_table[4*16+13]=182.0; boost_table[4*16+14]=180.0; boost_table[4*16+15]=180.0;
        // Row 78.5% ('89 table — plateaus flat above here, see page notes)
        boost_table[5*16+0]=145.0; boost_table[5*16+1]=152.0; boost_table[5*16+2]=180.0; boost_table[5*16+3]=206.0;
        boost_table[5*16+4]=206.0; boost_table[5*16+5]=206.0; boost_table[5*16+6]=206.0; boost_table[5*16+7]=206.0;
        boost_table[5*16+8]=206.0; boost_table[5*16+9]=208.0; boost_table[5*16+10]=206.0; boost_table[5*16+11]=206.0;
        boost_table[5*16+12]=206.0; boost_table[5*16+13]=206.0; boost_table[5*16+14]=206.0; boost_table[5*16+15]=194.0;
        // Row 82.8% (identical to 78.5% in the '89 table)
        boost_table[6*16+0]=145.0; boost_table[6*16+1]=152.0; boost_table[6*16+2]=180.0; boost_table[6*16+3]=206.0;
        boost_table[6*16+4]=206.0; boost_table[6*16+5]=206.0; boost_table[6*16+6]=206.0; boost_table[6*16+7]=206.0;
        boost_table[6*16+8]=206.0; boost_table[6*16+9]=208.0; boost_table[6*16+10]=206.0; boost_table[6*16+11]=206.0;
        boost_table[6*16+12]=206.0; boost_table[6*16+13]=206.0; boost_table[6*16+14]=206.0; boost_table[6*16+15]=194.0;
        // Row 87.1% (identical to 78.5% in the '89 table)
        boost_table[7*16+0]=145.0; boost_table[7*16+1]=152.0; boost_table[7*16+2]=180.0; boost_table[7*16+3]=206.0;
        boost_table[7*16+4]=206.0; boost_table[7*16+5]=206.0; boost_table[7*16+6]=206.0; boost_table[7*16+7]=206.0;
        boost_table[7*16+8]=206.0; boost_table[7*16+9]=208.0; boost_table[7*16+10]=206.0; boost_table[7*16+11]=206.0;
        boost_table[7*16+12]=206.0; boost_table[7*16+13]=206.0; boost_table[7*16+14]=206.0; boost_table[7*16+15]=194.0;
    end

    // Throttle% from tps_wiper (DME AFM wiper), same anchors as the
    // TPS-angle ch7 mapping above.
    real boost_thr_pct;
    always @(*) begin
        if (tps_wiper <= 8'd40)
            boost_thr_pct = 0.0;
        else if (tps_wiper >= 8'd235)
            boost_thr_pct = 100.0;
        else
            boost_thr_pct = (tps_wiper - 40) * 100.0 / 195.0;
    end

    // Bilinear interpolation over the boost table, clamped at the edges.
    real    boost_rpm_real, boost_map_value;
    real    rpm_frac, thr_frac;
    real    v00, v01, v10, v11, v0, v1;
    integer bi, bj, rpm_lo, rpm_hi, thr_lo, thr_hi;
    always @(*) begin
        boost_rpm_real = rpm_in;
        if (boost_rpm_real < boost_rpm_bp[0])
            boost_rpm_real = boost_rpm_bp[0];
        if (boost_rpm_real > boost_rpm_bp[BOOST_NUM_RPM_BP-1])
            boost_rpm_real = boost_rpm_bp[BOOST_NUM_RPM_BP-1];

        // Find RPM bracket
        rpm_lo = 0;
        rpm_hi = BOOST_NUM_RPM_BP-1;
        for (bi = 0; bi < BOOST_NUM_RPM_BP-1; bi = bi + 1) begin
            if (boost_rpm_real >= boost_rpm_bp[bi] && boost_rpm_real <= boost_rpm_bp[bi+1]) begin
                rpm_lo = bi;
                rpm_hi = bi + 1;
            end
        end
        rpm_frac = (boost_rpm_bp[rpm_hi] != boost_rpm_bp[rpm_lo])
                  ? (boost_rpm_real - boost_rpm_bp[rpm_lo]) / (boost_rpm_bp[rpm_hi] - boost_rpm_bp[rpm_lo])
                  : 0.0;

        // Find throttle% bracket, clamped to table range (no
        // extrapolation below 57.0% or above 87.1% — hold nearest row)
        if (boost_thr_pct <= boost_thr_bp[0]) begin
            thr_lo = 0; thr_hi = 0; thr_frac = 0.0;
        end else if (boost_thr_pct >= boost_thr_bp[BOOST_NUM_THR_BP-1]) begin
            thr_lo = BOOST_NUM_THR_BP-1; thr_hi = BOOST_NUM_THR_BP-1; thr_frac = 0.0;
        end else begin
            thr_lo = 0;
            thr_hi = BOOST_NUM_THR_BP-1;
            for (bj = 0; bj < BOOST_NUM_THR_BP-1; bj = bj + 1) begin
                if (boost_thr_pct >= boost_thr_bp[bj] && boost_thr_pct <= boost_thr_bp[bj+1]) begin
                    thr_lo = bj;
                    thr_hi = bj + 1;
                end
            end
            thr_frac = (boost_thr_bp[thr_hi] != boost_thr_bp[thr_lo])
                      ? (boost_thr_pct - boost_thr_bp[thr_lo]) / (boost_thr_bp[thr_hi] - boost_thr_bp[thr_lo])
                      : 0.0;
        end

        // Bilinear interpolation across the 4 surrounding corner points
        v00 = boost_table[thr_lo*BOOST_NUM_RPM_BP + rpm_lo];
        v01 = boost_table[thr_lo*BOOST_NUM_RPM_BP + rpm_hi];
        v10 = boost_table[thr_hi*BOOST_NUM_RPM_BP + rpm_lo];
        v11 = boost_table[thr_hi*BOOST_NUM_RPM_BP + rpm_hi];
        v0  = v00 + (v01 - v00) * rpm_frac;
        v1  = v10 + (v11 - v10) * rpm_frac;
        boost_map_value = v0 + (v1 - v0) * thr_frac;
    end

    // Reverse the ADC-read routine's +10 offset (see header comment) —
    // we're driving the RAW ADC channel, not ram[52h] directly.
    wire [7:0] boost_adc4_raw = (boost_map_value - 10.0 < 0.0)   ? 8'd0   :
                                 (boost_map_value - 10.0 > 255.0) ? 8'd255 :
                                 $rtoi(boost_map_value - 10.0);

    // Test-only overrides on top of the normal MAP-table value:
    //  -DBOOST_ZERO    — force the ADC input to 0 (e.g. simulate a
    //                     disconnected/failed boost sensor)
    //  -DBOOST_LOW     — normal value minus 33, clamped at 0 (e.g.
    //                     simulate a boost leak / underboost condition)
    //  -DBOOST_HIGH    — normal value plus 65, saturating at 255 (e.g.
    //                     simulate an overboost condition or wastegate
    //                     failure)
    //  -DBOOST_150PCT  — scale the normal value to 150%, saturating at
    //                     255 (e.g. simulate an over-reading sensor or
    //                     genuine over-boost condition)
    // All are independent of -DBOOST itself and only take effect when
    // -DBOOST is also defined, since there's no MAP-table value to
    // offset/scale otherwise.
    wire [7:0]  boost_adc4_low        = (boost_adc4_raw < 8'd33) ? 8'd0 : (boost_adc4_raw - 8'd33);
    wire [8:0]  boost_adc4_high_wide  = boost_adc4_raw + 9'd65;
    wire [7:0]  boost_adc4_high       = (boost_adc4_high_wide > 9'd255) ? 8'd255 : boost_adc4_high_wide[7:0];
    wire [15:0] boost_adc4_150pct_wide = (boost_adc4_raw * 16'd3) / 16'd2;
    wire [7:0]  boost_adc4_150pct     = (boost_adc4_150pct_wide > 16'd255) ? 8'd255 : boost_adc4_150pct_wide[7:0];

`ifdef BOOST_ZERO
    wire [7:0] boost_adc4_final = 8'd0;
`elsif BOOST_LOW
    wire [7:0] boost_adc4_final = boost_adc4_low;
`elsif BOOST_HIGH
    wire [7:0] boost_adc4_final = boost_adc4_high;
`elsif BOOST_150PCT
    wire [7:0] boost_adc4_final = boost_adc4_150pct;
`else
    wire [7:0] boost_adc4_final = boost_adc4_raw;
`endif

    wire [7:0] adc_ch4 = (EXT_STIM) ? boost_adc4_final : 8'h85;
`endif

    // ── Knock signal generation (ch0 — noise-level indicator;
    //    ch5 — lm2902.14 comparator output) ──
    //  fake_knock: klr_system's own P1.7 self-test output (see
    //    klr_top.v) — the firmware sets this pin to inject a fake
    //    knock reading into its own adc_ch5. NOT testbench-driven;
    //    it's wired below from the klr_system instance's fake_knock
    //    output port. 1 bit (single I/O pin). Feeds knock_sum (ch5)
    //    ONLY (via a burst-stretcher — see knock_gen.v: guarantees a
    //    2.4ms minimum low-to-high burst duration on ch5, while any
    //    brief transient pulses within the first 1.3ms after the
    //    falling edge stay visible unmodified).
    //  knock_reset: klr_system's P2.5 output, broken out from the
    //    p2_mon bus (declared further below; forward reference is
    //    fine here — Verilog resolves wire connections at
    //    elaboration, not by textual order). 1 bit. Gates knock_sum
    //    only (see formulas below) — knock_noise is unaffected.
    //  knock_sensor: real knock sensor input, now an input port (see
    //    port list above) rather than a fixed/internal tie-off — the
    //    timed pulse logic (TEST_KNOCK_PULSE) moved to
    //    dme_klr_dashboard_tb.v, since real knock is crank-position-
    //    specific and needs tdc/speed_sensor from the DME side, which
    //    aren't visible from here (klr_tb and the DME sub-TB are
    //    sibling instances under that top-level testbench). This is
    //    the baseline value for both outputs below; 8'd145 is added
    //    on top only while fake_knock is asserted.
    //  knock_gen is clocked (needs .clk below) only for the
    //    fake_knock burst-stretcher; everything else is combinational:
    //    knock_sum   = !knock_reset ? 0 (highest priority — forces 0
    //                  regardless of fake_knock) : fake_knock_stretched
    //                  ? (knock_sensor + 145) : knock_sensor — drives
    //                  adc_ch5. With knock_sensor=110: 0 / 110 / 255.
    //    knock_noise = fake_knock ? (knock_sensor + 145) : knock_sensor —
    //                  drives adc_ch0. Note: uses the RAW fake_knock
    //                  here, not the stretched version knock_sum
    //                  uses — knock_noise is not affected by the
    //                  burst-stretcher, and not gated by knock_reset
    //                  at all.
    wire       fake_knock;
    wire       knock_reset = p2_mon[5];
    wire [7:0] knock_sum;
    wire [7:0] knock_noise;

    // Substitutes nominal 110 in standalone mode (EXT_STIM=0), where
    // this port is left unconnected — same EXT_STIM gating this file
    // already uses for ext_trigger/ext_ign (see port list comment
    // above). Passes the real value through unchanged in combined
    // mode (dme_klr_dashboard_tb.v always drives it, even to 110 when
    // TEST_KNOCK_PULSE isn't defined — see that file). Deliberately
    // NOT a 'z'-detection idiom here — Verilator rejects that as
    // unsupported tristate I/O at the top level; a plain parameter-
    // gated mux avoids tristate semantics entirely.
    wire [7:0] knock_sensor_i = EXT_STIM ? knock_sensor : 8'd110;

    knock_gen u_knock_gen (
        .clk          ( clk            ),
        .fake_knock   ( fake_knock     ),
        .knock_reset  ( knock_reset    ),
        .knock_sensor ( knock_sensor_i ),
        .knock_sum    ( knock_sum      ),
        .knock_noise  ( knock_noise    )
    );

    wire [7:0] adc_ch0 = knock_noise;  // knock sensor noise-level indicator
    wire [7:0] adc_ch5 = knock_sum;    // lm2902.14 — comparator output

    // ── TPS Supply (ch3) and TPS Angle (ch7) ─────────────────
    // TPS supply (ch3/ram[39h]): fixed 201 — KLR has an onboard 5V regulator
    //   so TPS supply is independent of the 12V battery.
    //   201 = nominal ADC value for the regulated 5V supply (≈3.9V at ADC input).
    //
    // TPS angle (ch7/ram[3Ch]): mapped from DME AFM wiper in EXT_STIM mode.
    //   AFM idle (0x28=40) → TPS 0x28 (40), AFM WOT (0xEB=235) → TPS 0xC8 (200)
    //   Linear: tps_angle = 40 + (afm - 40) * 160 / 195
    //   WOT threshold: 3C > 144 → 3A > 67 → KLR asserts full_load (P1.5 low)
    wire [7:0] adc_ch3 = 8'd255;   // conn 1  TPS 5V supply — fixed regulated value

    // TPS angle mapping: AFM idle (0x28=40) → TPS 0x1A (0.5V), AFM WOT (0xEB=235) → TPS 0xEF (4.7V)
    // 16-bit intermediate prevents overflow: max (195 * 213) = 41535 > 255
    // tps = 26 + (afm - 40) * (239 - 26) / (235 - 40) = 26 + (afm-40)*213/195
    wire [15:0] _tps_angle_full = (tps_wiper > 8'd40)
                               ? (16'd26 + ({8'd0, tps_wiper} - 16'd40) * 16'd213 / 16'd195)
                               : 16'd26;
    wire [7:0] adc_ch7 = (EXT_STIM) ? _tps_angle_full[7:0] : 8'd40;   // conn 16 TPS angle wiper

    // ── Debug / monitoring wires ──────────────────────────
    wire [11:0] pc;
    wire [7:0]  ir, acc, p1_mon, p2_mon;
    wire [10:0] ext_addr;   // {P1[2:0], bus_addr} — full MOVX address

    // Diagnostic LED output — P2.4, broken out from the p2_mon bus
    // (klr_system exposes full P2 via p2_mon; no new port needed).
    wire diag_led_out = p2_mon[4];

    // ============================================================
    //  VCD / disassembly monitor
    //  klr_vcd.v is a copy of vcd.v with $dumpvars paths updated:
    //    i8048_tb.*  →  klr_tb.*
    //  The always block references (top.clk, top.pc) are unchanged
    //  because the klr_system instance below is named `top`.
    // ============================================================
    klr_dumpvcd u_dumpvcd ();

    // ============================================================
    //  Variable-RPM crank + ignition generator
    //  Sweeps from `RPMSTART (840) to `RPMEND (6500) over `SIM_TIME.
    //  trigger → 100 ns pulse at 80° bTDC per cylinder → KLR /RESET
    //  ign     → square wave aligned to ignition timing → KLR T1
    // ============================================================
    var_timing_generator u_timing (
        .clk     ( clk      ),
        .rst     ( sim_rst  ),
        .trigger ( trigger  ),
        .ign     ( ign      )
    );

    // ============================================================
    //  KLR system under test
    //
    //  Named `top` — see "Instance naming convention" in the header.
    //  ROM is loaded inside klr_eprom's initial block ($readmemh).
    //  RAM dump path: klr_tb.top.i8048_core_1.ram
    // ============================================================
    klr_system top (
        .clk         ( clk           ),
        .trigger_in  ( trigger_in_mux ),
        .ign_in      ( ign_in_mux    ),
        .ign_out     ( ign_out  ),
        .ign_out_n   ( ign_out_n ),
        .full_load   ( full_load ),
        .fake_knock  ( fake_knock ),
        .adc_ch0     ( adc_ch0  ),
        .adc_ch1     ( adc_ch1  ),
        .adc_ch2     ( adc_ch2  ),
        .adc_ch3     ( adc_ch3  ),
        .adc_ch4     ( adc_ch4  ),
        .adc_ch5     ( adc_ch5  ),
        .adc_ch6     ( adc_ch6  ),
        .adc_ch7     ( adc_ch7  ),
        .pc          ( pc       ),
        .ir          ( ir       ),
        .acc         ( acc      ),
        .p1_mon      ( p1_mon   ),
        .p2_mon      ( p2_mon   ),
        .ext_addr    ( ext_addr )
    );

    // ============================================================
    //  Main simulation sequence
    // ============================================================
    initial begin
        // ── Release master reset after 500 ns ─────────────────
        //  ROM is already loaded by klr_eprom's own initial block.
        //  sim_rst = 0 holds var_timing_generator (and therefore the
        //  crank trigger) until the clock has stabilised.
        sim_rst = 0;
        // Debug: pre-initialize ram[0x16] = 0x00 so the computed MB1
        // jump at 0x2b0 lands at 0x800 instead of 0x8XX (uninitialized).
        // Remove once the firmware correctly initializes this location.
        klr_tb.top.i8048_core_1.ram[8'h16] = 8'h02;
        #5000;
        sim_rst = 1;

        // ── Run for SIM_TIME ──────────────────────────────────
        #`SIM_TIME;

        // ── Dump final memory state ───────────────────────────
        $writememh("rom_out.hex", top.rom_1.rom);  // 4096 locations (2732 4K×8)
        $writememh("ram_out.hex", top.i8048_core_1.ram);

        #1000;
        $finish;
    end

    // Zero ram[0x16] on every trigger posedge (reset event)
    // Ensures MB1 jump at 0x2B0 always lands at 0x800, not 0x8XX.
    //
    // The original used #1 to let the core see the posedge before the RAM
    // write.  Verilator ignores # delays in always blocks, so the write
    // landed in the same time-step as the edge and corrupted the firmware's
    // jump calculation, causing premature engine sync.
    //
    // Fix: pipeline the trigger through one master clock so the core sees
    // the edge on cycle N and the RAM is patched on cycle N+1.
    reg trigger_ram_patch_d  = 1'b0;
    reg trigger_ram_patch_done = 1'b0;  // fire once only
    always @(posedge clk) begin
        trigger_ram_patch_d <= trigger_in_mux;
    end
    always @(posedge clk) begin
        if (trigger_ram_patch_d && !trigger_ram_patch_done) begin
            klr_tb.top.i8048_core_1.ram[8'h16] = 8'h02;
            trigger_ram_patch_done <= 1'b1;
        end
    end

    // ============================================================
    //  knock_sensor is now an input port (see port list above),
    //  driven from dme_klr_dashboard_tb.v — real knock timing needs
    //  tdc/speed_sensor from the DME side, which this file can't see
    //  (klr_tb and the DME sub-TB are sibling instances under that
    //  top-level testbench). See TEST_KNOCK_PULSE there.
    // ============================================================

`include "klr_phase_monitor.v"

endmodule
