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
    //  Replace with boost_pressure_gen output once that module is written.
    reg [7:0] adc_ch1 = 8'hd8;  // battery
    reg [7:0] adc_ch2 = 8'h00;  // ground
    reg [7:0] adc_ch4 = 8'h85;  // conn 23 MAP sensor
    reg [7:0] adc_ch6 = 8'h87;  // conn 25

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
