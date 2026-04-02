// ============================================================
//  i8051_system.v  —  Top-level: Intel 8051 + Intel 2764 EPROM
//
//  The Intel 2764 is a 4 KB (4096 × 8) UV-erasable PROM.
//  It has a 12-bit address bus (A0–A11) and an 8-bit data bus.
//  Active-low outputs are enabled by both /CE and /OE being low.
//
//  Address mapping
//  ───────────────
//  The 8051 program counter is 16 bits (64 KB space).
//  The 2764 covers 0x0000–0x0FFF (4 KB).  A15–A12 of the PC
//  are decoded so that /CE is only asserted for that window;
//  accesses to 0x1000–0xFFFF will see 0xFF (undriven bus).
//
//  Port 0 / ALE / /PSEN demux
//  ──────────────────────────
//  The 8051 multiplexes the low address byte (A7–A0) onto P0
//  during the ALE pulse, then releases P0 for data.  A standard
//  74HC373 (or equivalent) latch captures A7–A0 on the falling
//  edge of ALE.  This file models that latch internally so the
//  simulation is self-contained; on real PCBs a discrete latch
//  IC would be used.
//
//  Pinout summary (as seen at the top-level boundary)
//  ───────────────────────────────────────────────────
//   clk        Oscillator input  (12× machine-cycle rate)
//   res_n      System reset (active-low)
//   int0_n     External interrupt 0
//   int1_n     External interrupt 1
//   t0         Timer 0 external clock / event
//   t1         Timer 1 external clock / event
//   rxd        UART serial receive
//   txd        UART serial transmit
//   p1[7:0]    Port 1 (general I/O)
//   p2[7:0]    Port 2 (high address byte during MOVX; general I/O)
//   p3[7:0]    Port 3 (/INT0, /INT1, T0, T1, /RD, /WR, RxD, TxD)
//   xrd_n      /RD  external data-memory read strobe
//   xwr_n      /WR  external data-memory write strobe
//   xdata[7:0] External data bus (bidirectional; split in/out here)
//   xaddr[15:0] External data address (from DPTR or @Ri)
// ============================================================

//`timescale 1ns/1ps

module i8051_system (
    // ── Clock & Reset ──────────────────────────────────────
    input  wire        clk,        // Oscillator
    input  wire        res_n,      // Active-low reset

    // ── Interrupt / Timer inputs ───────────────────────────
    input  wire        int0_n,
    input  wire        int1_n,
    input  wire        t0,
    input  wire        t1,

    // ── Serial ─────────────────────────────────────────────
    input  wire        rxd,
    output wire        txd,

    // ── I/O Ports (exposed at system boundary) ─────────────
    output wire [7:0]  p0,
    output wire [7:0]  p1,
    output wire [7:0]  p2,
    output wire [7:0]  p3,

    // ── I/O Ports (exposed at system boundary) ─────────────
    input wire [7:0]  p0_in,
    input wire [7:0]  p1_in,
    input wire [7:0]  p2_in,
    input wire [7:0]  p3_in,

    // ── External Data Memory bus ───────────────────────────
    output wire        xrd_n,
    output wire        xwr_n,
    output wire        ale,
    inout  wire [7:0]  xdata,      // Bidirectional external data
    output wire [15:0] xaddr       // External data address
);

    // ============================================================
    //  Internal wires
    // ============================================================

    // Program memory bus (CPU → EPROM)
    wire [15:0] addr_bus;      // Full 16-bit program address from core
    wire [7:0]  rom_data;      // Byte returned by the 2764

    // Bus control
    wire        psen_n;



    // Latched low address byte (captured on ALE falling edge)
    reg  [7:0]  addr_latch;    // Models the 74HC373 on real hardware

    // Full 13-bit EPROM address
    wire [12:0] eprom_addr;

    // EPROM chip-enable: only assert when PC[15:12] == 4'b0000 (0x0000–0x0FFF)
    wire        eprom_ce_n;

    // CPU misc outputs
    wire [15:0] xaddr_bus_w;
    wire [7:0]  xdata_out_w;
    wire        xrd_n_w;
    wire        xwr_n_w;

    // ============================================================
    //  ALE falling-edge detector → address latch (74HC373 model)
    //
    //  On real hardware the 74HC373 is transparent while LE (ALE)
    //  is high and latches on the falling edge.  We replicate that
    //  here: capture P0 (which carries A7–A0) on the negedge of ALE.
    // ============================================================
    reg ale_prev;
    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            addr_latch <= 8'h00;
            ale_prev   <= 1'b0;
        end else begin
            ale_prev <= ale;
            // Falling edge of ALE: latch the current P0 value
            if (ale_prev && !ale)
                addr_latch <= p0;
        end
    end

    // ============================================================
    //  EPROM address assembly
    //
    //  addr_bus[15:0] comes from the CPU's addr_bus port, which the
    //  core drives directly from the PC (and during MOVC from the
    //  computed table address).  On the physical 8051 bus:
    //    A15–A8  → P2 (high byte, always stable)
    //    A7–A0   → addr_latch (low byte, captured from P0 via ALE)
    //
    //  We use addr_bus from the core directly for the simulation
    //  model; a real board implementation would use:
    //    {p2, addr_latch}
    // ============================================================
    assign eprom_addr  = addr_bus[12:0];          // 2764 is 8 KB → 13-bit address
    assign eprom_ce_n  = (addr_bus[15:13] != 3'h0); // enabled for 0x0000–0x0FFF only

    // ============================================================
    //  Intel 2764 EPROM model
    // ============================================================
    i2764_eprom u_eprom (
        .addr   ( eprom_addr ),
        .ce_n   ( eprom_ce_n ),
        .oe_n   ( psen_n     ),   // /OE driven by CPU /PSEN
        .data   ( rom_data   )
    );

    // ============================================================
    //  External data bus tri-state driver
    //  xdata is bidirectional: driven by the CPU during MOVX writes,
    //  read by the CPU during MOVX reads.
    // ============================================================
    assign xdata = (!xrd_n_w) ? 8'hZZ : xdata_out_w;  // hi-Z during reads
    assign xaddr = xaddr_bus_w;
    assign xrd_n = xrd_n_w;
    assign xwr_n = xwr_n_w;

    // ============================================================
    //  Intel 8051 Core instantiation
    // ============================================================
    i8051_core u_cpu (
        // Clock & reset
        .clk        ( clk         ),
        .res_n      ( res_n       ),

        // Interrupt / timer inputs
        .int0_n     ( int0_n      ),
        .int1_n     ( int1_n      ),
        .t0         ( t0          ),
        .t1         ( t1          ),

        // Serial
        .rxd        ( rxd         ),
        .txd        ( txd         ),

        // Program memory bus
        .rom_data   ( rom_data    ),
        .addr_bus   ( addr_bus    ),

        // Bus control
        .ale        ( ale         ),
        .psen_n     ( psen_n      ),

        // External data memory
        .xdata_in   ( xdata       ),   // reads come from xdata bus
        .xdata_out  ( xdata_out_w ),
        .xaddr_bus  ( xaddr_bus_w ),
        .xrd_n      ( xrd_n_w     ),
        .xwr_n      ( xwr_n_w     ),

        // I/O ports
        .p0         ( p0      ),
        .p1         ( p1          ),
        .p2         ( p2          ),
        .p3         ( p3          ),

        // I/O ports
        .p0_in         ( p0_in      ),
        .p1_in         ( p1_in          ),
        .p2_in         ( p2_in          ),
        .p3_in         ( p3_in          ),

        // Debug / monitoring outputs (not connected externally)
        .pc         (             ),
        .ir         (             )
    );

endmodule


// ================================================================
//  Intel 2764 EPROM  —  8192 × 8-bit
//
//  The real 2764 has the following DC characteristics relevant
//  to this model:
//    tACC (address access time) : 200–450 ns depending on speed grade
//    tCE  (/CE access time)     : 200–450 ns
//    tOE  (/OE access time)     :  75–120 ns
//    tDF  (output disable time) :   0–100 ns
//
//  In this RTL model the memory array responds combinatorially
//  (zero-cycle latency) when both /CE and /OE are asserted.
//  Add a `#tACC` delay after the data assignment if you need
//  timing-accurate gate-level simulation.
//
//  The EPROM contents are loaded at simulation start from a hex
//  file via $readmemh.  Change the path to point at your binary.
// ================================================================
module i2764_eprom (
    input  wire [12:0] addr,    // A0–A12  (4096 locations)
    input  wire        ce_n,    // /CE  chip enable  (active-low)
    input  wire        oe_n,    // /OE  output enable (active-low, driven by /PSEN)
    output wire [7:0]  data     // D0–D7  (tri-state when disabled)
);

    // 4 KB storage array — initialised to 0xFF (erased EPROM state)
    reg [7:0] mem [0:8191];

    // Load program image at simulation start.
    // The file must be in Verilog hex format (one byte per line or
    // space-separated).  Adjust the path to your compiled binary.
    integer i;
    initial begin
        // Pre-fill with 0xFF to mimic a blank erased device
        for (i = 0; i < 8192; i = i + 1)
            mem[i] = 8'hFF;
        // Then overlay the actual program image
        $readmemh("/Users/Mike/coding_projects/944/DME_sim/bin/28PIN_DME_PERFORMANCE.mem", mem);
    end

    // Output: valid only when both /CE and /OE are low
    assign data = (!ce_n && !oe_n) ? mem[addr] : 8'hZZ;

endmodule
