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
//
//  Compile:
//    iverilog -o klr.vvp -s klr_tb \
//      timescale.v i8048_core.v adc_8090.v adc_delay.v \
//      var_timing_gen.v klr_top.v klr_vcd.v klr_tb.v
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
    input  wire ext_trigger,   // DME A_5_KLR_ign_out → KLR trigger_in (inverted)
    input  wire ext_ign,       // DME A_1_tach_pulse  → KLR ign_in     (inverted)
    output wire ign_out,       // KLR P2.7 → DME ign  (retard-gated spark)
    output wire full_load      // KLR P1.5 → DME full_load (WOT flag)
);

    // ── Clock ─────────────────────────────────────────────
    parameter DELAY = `FRQ_SCALE / `FREQ;  // half-period ≈ 45 ns → ~11.1 MHz

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
    //  Replace with knock_sensor_gen / boost_pressure_gen outputs
    //  once those modules are written.
    reg [7:0] adc_ch0 = 8'h81;  // conn 14  — knock sensor 1 amplified
    reg [7:0] adc_ch1 = 8'h82;  // conn 13  — knock sensor 2 amplified
    reg [7:0] adc_ch2 = 8'h83;  // conn 17
    reg [7:0] adc_ch3 = 8'h84;  // conn 15
    reg [7:0] adc_ch4 = 8'h85;  // conn 23
    reg [7:0] adc_ch5 = 8'h86;  // lm2902.14 — comparator output
    reg [7:0] adc_ch6 = 8'h87;  // conn 25
    reg [7:0] adc_ch7 = 8'h88;  // conn i16

    // ── Debug / monitoring wires ──────────────────────────
    wire [11:0] pc;
    wire [7:0]  ir, acc, p1_mon, p2_mon;
    wire [10:0] ext_addr;   // {P1[2:0], bus_addr} — full MOVX address

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
        klr_tb.top.i8048_core_1.ram[8'h16] = 8'h00;
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

    // ============================================================
    //  Optional: inject knock event on ADC ch0/ch1 at mid-sim
    //  Uncomment to exercise the knock detection loop.
    //  The comparator output (ch5) is raised simultaneously to
    //  simulate the LM2902 threshold being exceeded.
    // ============================================================
    // initial begin
    //     #(`SIM_TIME / 2);
    //     $display("[TB] Injecting knock event on CH0/CH1 at t=%0t", $time);
    //     adc_ch0 = 8'hF0;   // strong knock on sensor 1
    //     adc_ch1 = 8'hE8;   // strong knock on sensor 2
    //     adc_ch5 = 8'hFF;   // LM2902 comparator trips
    //     #200000;            // hold for 200 µs (~2 engine cycles at idle)
    //     adc_ch0 = 8'h81;   // return to quiescent
    //     adc_ch1 = 8'h82;
    //     adc_ch5 = 8'h86;
    // end

`include "klr_phase_monitor.v"

endmodule
