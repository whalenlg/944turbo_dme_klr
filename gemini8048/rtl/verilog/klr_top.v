// ============================================================
//  klr_top.v  —  Top-level: Intel 8049 KLR (Klopfregelgerät)
//
//  The Porsche 944 Turbo KLR is a separate knock-control ECU
//  that monitors detonation via piezoelectric sensors and
//  signals the ignition coil driver directly (series in the
//  DME ignition path), retarding spark when knock is detected.
//
//  Hardware summary (951 KLR board)
//  ──────────────────────────────────
//  CPU  : Intel 8049  (8048 family, 2K internal ROM)  @ 11 MHz
//  ROM  : Intel 2716 / 2758 EPROM (2K or 1K × 8)
//  ADC  : ADC0809 (8-channel, 8-bit successive approximation)
//  Misc : LM2902 quad comparator — knock threshold detection
//  Clock: 11 MHz crystal oscillator
//
//  Signal interface to DME
//  ───────────────────────
//  trigger_in  Crank reference pulse from DME (80° before TDC).
//              Connected to CPU /RESET — see "Crank sync" below.
//  ign_in      Ignition timing signal from DME.
//              Drives T1 (pin 39) and can be used as INT source.
//  ign_out     Retard-adjusted ignition output → coil driver.
//              P2.7 — high = allow spark, low = suppress/retard.
//  ign_out_n   Complementary ignition output (P2.6).
//  full_load   P1.5 — full-load enrichment flag read by DME.
//
//  Port assignments (verified against i8048_tb.v)
//  ────────────────────────────────────────────────
//  P1[2:0]   ADC channel address select
//  P1[5]     full_load flag output to DME
//  P2[6]     ign_out_n (complementary ignition drive)
//  P2[7]     ign_out   (main retard-gated ignition output)
//  BUS[3]    ADC /START — bit 3 of the 8049 bus output register
//
//  ADC channel map (connector IDs from i8048_tb.v)
//  ──────────────────────────────────────────────────
//  CH0  conn 14  — knock sensor 1 amplified voltage
//  CH1  conn 13  — knock sensor 2 amplified voltage
//  CH2  conn 17  — (update when ROM map decoded)
//  CH3  conn 15  — (update when ROM map decoded)
//  CH4  conn 23  — (update when ROM map decoded)
//  CH5  lm2902.14 — LM2902 comparator output (knock threshold flag)
//  CH6  conn 25  — (update when ROM map decoded)
//  CH7  conn i16 — (update when ROM map decoded)
//
//  Crank synchronisation
//  ─────────────────────
//  The 8049 /RESET pin is driven by !trigger_in.  Each rising
//  edge of the crank reference pulse (80° bTDC per cylinder)
//  briefly resets the CPU, which then re-executes its knock-
//  detection loop for one engine cycle before the next reset.
//  This locks KLR timing windows precisely to TDC without
//  requiring the firmware to maintain a software RPM counter.
//
//    trigger_in rising  →  res_n = 0 (CPU held in reset)
//    trigger_in falling →  res_n = 1 (CPU running free)
//
//  ROM naming convention
//  ─────────────────────
//  The ROM sub-module instance is named `rom_1` with an internal
//  array `rom[]`.  This preserves compatibility with the existing
//  $readmemh / $writememh paths in i8048_tb.v:
//    $readmemh("87KLR_951.mem", top.rom_1.rom)
//    $writememh("rom_out.hex",  top.rom_1.rom)
//
//  Compile with the rest of the DME/KLR simulation:
//    iverilog -o klr.vvp               \
//      timescale.v                     \
//      i8048_core.v                    \
//      adc_8090.v                      \
//      klr_top.v                       \
//      klr_tb.v
// ============================================================

`include "timescale.v"

module klr_system (
    // ── Clock ────────────────────────────────────────────────
    input  wire        clk,         // 11 MHz oscillator

    // ── Crank / ignition interface (from DME) ─────────────────
    input  wire        trigger_in,  // Crank ref → /RESET + T0
    input  wire        ign_in,      // Ignition from DME → T1 + /INT

    // ── Ignition output (to coil driver) ─────────────────────
    output wire        ign_out,     // P2.7 — retard-gated spark
    output wire        ign_out_n,   // P2.6 — complementary

    // ── Auxiliary outputs ─────────────────────────────────────
    output wire        full_load,   // P1.5 — full-load flag
    output wire        CV_PWM,      // P1.4 — control valve PWM
    output wire        knock_out,   // P1.6 — knock detected output
    output wire        fake_knock,  // P1.7 — fake knock signal

    // ── ADC channel stimulus (driven by testbench) ────────────
    //  Wire these to knock_sensor_gen outputs in klr_tb.v
    input  wire [7:0]  adc_ch0,    // conn 14 — knock sensor 1 amp
    input  wire [7:0]  adc_ch1,    // conn 13 — knock sensor 2 amp
    input  wire [7:0]  adc_ch2,    // conn 17
    input  wire [7:0]  adc_ch3,    // conn 15
    input  wire [7:0]  adc_ch4,    // conn 23
    input  wire [7:0]  adc_ch5,    // lm2902.14 — comparator output
    input  wire [7:0]  adc_ch6,    // conn 25
    input  wire [7:0]  adc_ch7,    // conn i16

    // ── Debug / monitoring outputs ────────────────────────────
    output wire [11:0] pc,          // Program counter
    output wire [7:0]  ir,          // Instruction register
    output wire [7:0]  acc,         // Accumulator
    output wire [7:0]  p1_mon,      // Full P1 (for phase monitor)
    output wire [7:0]  p2_mon,      // Full P2 (for phase monitor)

    // ── External data bus address ─────────────────────────────
    //  On the KLR board P1[2:0] provides A8–A10 (upper 3 address
    //  bits) during MOVX cycles; bus_addr carries A0–A7 (Ri value
    //  latched on the BUS during ALE).  The combined 11-bit address
    //  gives a 2 KB external data RAM space.
    //  P1[2:0] also serves as ADC channel select — same pins,
    //  different role depending on which instruction is executing.
    output wire [10:0] ext_addr     // {P1[2:0], bus_addr} — full MOVX address
);

    // ============================================================
    //  Internal wires
    // ============================================================

    // Crank-synchronised reset — trigger_in high holds CPU in reset
    wire        res_n = ~trigger_in;

    // CPU ports
    wire [7:0]  p1, p2;
    wire [7:0]  bus_out, bus_addr;
    wire [7:0]  bus_in;            // CPU reads ADC result via bus_in
    wire        ale, psen_n, rd_n, wr_n, prog, cycle_2;
    wire [11:0] mem_addr;   // fetch address from core (acc-based during MOVP cycle_2)
    wire        movp_active; // high during MOVP/MOVP3 cycle_2

    // ROM interface
    wire [11:0] eprom_addr;   // Intel 2732 (4K×8): A11–A0 = latched pc[11:0]
    wire [7:0]  latched_addr; // LS373 Q outputs — low 8 address bits
    reg  [3:0]  latched_upper;// upper 4 PC bits latched on ALE — same strobe as LS373
    wire [7:0]  rom_data;
    wire        eprom_ce_n;

    // ADC
    wire        adc_eoc;           // end-of-conversion (not used by firmware)

    // ============================================================
    //  Output / port assignments
    // ============================================================
    assign ign_out   = p2[7];
    assign ign_out_n = p2[6];
    assign full_load = p1[5];
    assign CV_PWM    = p1[4];
    assign knock_out = p1[6];
    assign fake_knock= p1[7];
    assign p1_mon    = p1;
    assign p2_mon    = p2;
    assign ext_addr  = {p1[2:0], bus_addr};  // A10–A8 from P1, A7–A0 from Ri via BUS
    assign p1_mon    = p1;
    assign p2_mon    = p2;

    // ============================================================
    //  74LS373 address latch
    //
    //  On the real KLR board a 74LS373 octal transparent latch sits
    //  between the 8049 multiplexed bus and the EPROM address pins:
    //
    //    8049 bus (pc[7:0] while ALE high) → LS373 D[7:0]
    //    8049 ALE                          → LS373 LE
    //    LS373 Q[7:0]                      → EPROM A0–A7
    //
    //  Glitch fix — latch all 12 PC bits together:
    //    The original split ({pc[11:8], latched_addr[7:0]}) caused a
    //    glitch on eprom_addr because pc[11:8] is combinatorial and
    //    updates immediately when pc increments, while latched_addr
    //    only updates on the next ALE pulse.  Between fetches the two
    //    halves are temporarily from different PC values.
    //
    //    Fix: the LS373 now latches all 12 bits of pc simultaneously.
    //    Both halves are captured at the same ALE falling edge, so
    //    eprom_addr is always internally consistent.
    //
    //  EPROM /CE is asserted by /PSEN — active-low, every opcode fetch.
    // ============================================================
    ls373_latch u_ls373 (
        .d    ( pc[7:0]      ),   // low 8 bits of fetch address
        .le   ( ale          ),   // latch enable = ALE
        .q    ( latched_addr )    // held address → EPROM A0–A7
    );

    // Upper 4 bits latched separately on ALE — same strobe, same moment,
    // so both halves of eprom_addr are always from the same fetch cycle.
    always @(*) begin
        if (ale)
            latched_upper = pc[11:8];
    end

    // During MOVP/MOVP3 cycle_2 the core drives mem_addr with {page,acc} or {0011,acc}.
    // Override the ALE-latched eprom_addr so the EPROM sees the correct lookup address.
    // MOVP/MOVP3: core signals movp_active and drives mem_addr = {page,acc}.
    // Override the ALE-latched address so the EPROM reads from the correct table entry.
    assign eprom_addr = movp_active ? mem_addr : { latched_upper, latched_addr[7:0] };
    assign eprom_ce_n = psen_n;    // /CE = /PSEN (active-low)

    // ============================================================
    //  Intel 2716 EPROM model  (2K × 8)
    //
    //  Instance named rom_1 so that $readmemh / $writememh paths
    //  from i8048_tb.v continue to work unchanged:
    //    $readmemh("87KLR_951.mem", <tb>.u_klr.rom_1.rom);
    //    $writememh("rom_out.hex",  <tb>.u_klr.rom_1.rom);
    //
    //  If your ROM image is a 1K 2758, simply load it — the upper
    //  1K half of the array stays 0xFF (blank) and is never reached
    //  because the 8049 firmware wraps within its first 1K.
    // ============================================================
    klr_eprom rom_1 (
        .addr  ( eprom_addr ),
        .ce_n  ( eprom_ce_n ),
        .data  ( rom_data   )
    );

    // ============================================================
    //  Intel 8049 CPU core
    //
    //  Port notes:
    //    t0    — not connected on KLR hardware; tied to 0
    //    t1    — receives ign_in (DME ignition signal)
    //    int_n — active-low external interrupt; tied to 1 in
    //            simulation (matching i8048_tb.v which never drives
    //            it low).  On real hardware the ignition pulse may
    //            also feed /INT — update this line once the ROM
    //            disassembly confirms whether INT is used.
    // ============================================================
    i8048_core i8048_core_1 (
        .clk      ( clk       ),
        .res_n    ( res_n        ),    // crank ref pulse → /RESET (active-low)

        .t0       ( 1'b0      ),    // T0 unused on KLR
        .t1       ( ign_in    ),    // ignition from DME → T1
        .int_n    ( ign_in    ),    // ignition from DME → /INT (active-low)

        .rom_data ( rom_data  ),

        .bus_in   ( bus_in    ),
        .bus_out  ( bus_out   ),
        .bus_addr ( bus_addr  ),

        .p1       ( p1        ),
        .p2       ( p2        ),

        .ale      ( ale       ),
        .psen_n   ( psen_n    ),
        .rd_n     ( rd_n      ),
        .wr_n     ( wr_n      ),
        .prog     ( prog      ),

        .pc       ( pc        ),
        .ir       ( ir        ),
        .acc      ( acc       ),
        .cycle_2     ( cycle_2     ),
        .mem_addr    ( mem_addr    ),
        .movp_active ( movp_active )
    );

    // ============================================================
    //  ADC — single stage (adc_8090 only)
    //
    //  adc_8090 provides a free-running 8-stage ALE-clocked pipeline
    //  giving ~8 ALE cycle conversion delay.  adc_delay_8 is removed
    //  since chaining both stages produced 16 cycles total delay.
    //
    //  start=1'b0: keeps the pipeline free-running. START=1 flushes
    //  all stages to zero which is wrong when the CPU holds p1[3]=1.
    //  p1[3] remains available for firmware use.
    // ============================================================
    adc_8090 u_adc_mux (
        .clk      ( ale         ),   // ALE clocks the pipeline
        .oe       ( 1'b1        ),   // output always enabled
        .start    ( 1'b0        ),   // free-running
        .ale      ( ale         ),   // ALE latches channel address
        .addr     ( p1[2:0]     ),   // P1[2:0] = channel select
        .data_in0 ( adc_ch0     ),
        .data_in1 ( adc_ch1     ),
        .data_in2 ( adc_ch2     ),
        .data_in3 ( adc_ch3     ),
        .data_in4 ( adc_ch4     ),
        .data_in5 ( adc_ch5     ),
        .data_in6 ( adc_ch6     ),
        .data_in7 ( adc_ch7     ),
        .data_out ( bus_in      ),   // direct to CPU bus_in
        .eoc      ( adc_eoc     )
    );

endmodule


// ================================================================
//  ls373_latch  —  74LS373 octal transparent latch model
//
//  The 74LS373 is an 8-bit transparent latch with a common latch
//  enable (LE) and a common output enable (OE, active-low).
//  On the KLR board OE is tied to GND (outputs always enabled),
//  so it is not modelled as a port here.
//
//  Behaviour:
//    LE high  → transparent: Q follows D combinatorially
//    LE low   → latched:     Q holds the last value of D
//
//  This is the standard address demultiplexing circuit for the
//  Intel MCS-48 family (8048/8049).  ALE drives LE directly.
// ================================================================
module ls373_latch (
    input  wire [7:0] d,    // data inputs  (from 8049 bus_addr)
    input  wire       le,   // latch enable (from 8049 ALE)
    output reg  [7:0] q     // latched outputs (to EPROM A0–A7)
);
    always @(*) begin
        if (le)
            q = d;          // transparent while ALE high
        // else q holds — Verilog reg retains value automatically
    end
endmodule


// ================================================================
//  klr_eprom  —  Intel 2732 EPROM model  (4096 × 8-bit)
//
//  The Intel 2732 is a 4K×8 UV-erasable PROM with a 12-bit address
//  bus, covering 0x000–0xFFF.  This matches the 8049's full 12-bit
//  PC range, giving access to both memory banks (MB0: 0x000–0x7FF,
//  MB1: 0x800–0xFFF) via a single device.
//
//  Internal array is named `rom[]` for $readmemh / $writememh
//  compatibility with klr_tb.v:
//    $readmemh("87KLR_951.mem", <tb>.top.rom_1.rom)
//    $writememh("rom_out.hex",  <tb>.top.rom_1.rom)
// ================================================================
module klr_eprom (
    input  wire [11:0] addr,   // A0–A11 (4096 locations)
    input  wire        ce_n,   // /CE — active-low (driven by /PSEN)
    output wire [7:0]  data    // D0–D7
);
    reg [7:0] rom [0:4095];
    reg [7:0] data_latch;  // holds last valid byte when /CE deasserted

    integer i;
    initial begin
        // Pre-fill with 0xFF (blank erased EPROM state)
        for (i = 0; i < 4096; i = i + 1)
            rom[i] = 8'hFF;

        // Load KLR firmware image — uncomment the variant to simulate:
        $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/87KLR_951.mem", rom);
        //$readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/89KLR_951.mem", rom);
    end

    // Transparent latch on /CE — holds last valid byte between fetches
    // so the IR register never sees Z states between PSEN pulses.
    always @(*) begin
        if (!ce_n)
            data_latch = rom[addr];
    end

    assign data = data_latch;

endmodule
