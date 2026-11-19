//////////////////////////////////////////////////////////////////////
////                                                              ////
////  i8051_regression_tb.v                                      ////
////                                                              ////
////  Compatible with: iverilog / vvp                            ////
////  Usage:                                                      ////
////    iverilog -o sim i8051_regression_tb.v i8051_core.v       ////
////    vvp sim                                                   ////
////                                                              ////
////  Waveform output: i8051_regression.fst                      ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "timescale.v"
`define MAX_OSC 1000
module i8051_regression_tb;

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
// 50 MHz oscillator → 20 ns period → 10 ns half-period.
// With 12 oscillator clocks per machine cycle the effective instruction
// rate is ~4.17 MIPS at 50 MHz.
parameter CLK_HALF = 10;

// ---------------------------------------------------------------------------
// Clock and Reset
// ---------------------------------------------------------------------------
reg clk;
reg res_n;          // active-LOW (inverted from original wb_rst_i)

initial clk = 1'b0;
always #(CLK_HALF) clk = ~clk;

// ---------------------------------------------------------------------------
// Program memory bus (combinatorial byte-wide ROM)
// ---------------------------------------------------------------------------
wire [15:0] addr_bus;    // 16-bit program address driven by core
reg  [7:0]  rom_data;    // byte returned to core this cycle

// ---------------------------------------------------------------------------
// External data memory (MOVX bus)
// ---------------------------------------------------------------------------
wire        xrd_n;       // /RD strobe from core
wire        xwr_n;       // /WR strobe from core
wire [15:0] xaddr_bus;   // address from core (DPTR or {P2,Ri})
wire [7:0]  xdata_out;   // data written by core
reg  [7:0]  xdata_in;    // data read back by core

// ---------------------------------------------------------------------------
// Port I/O outputs (monitored but not driven in most tests)
// ---------------------------------------------------------------------------
wire [7:0]  p0, p1, p2, p3;

// ---------------------------------------------------------------------------
// Misc outputs (ALE, /PSEN, TXD) – not used for pass/fail decisions
// ---------------------------------------------------------------------------
wire ale, psen_n, txd;
wire [15:0] pc_mon;     // PC monitoring output
wire [7:0]  ir_mon;     // IR monitoring output

// ---------------------------------------------------------------------------
// Storage arrays
// ---------------------------------------------------------------------------
reg [7:0] rom  [0:65535];   // program memory (full 64 KB; tests use 0x0000-0x01FF)
reg [7:0] xram [0:65535];   // external data RAM (MOVX target)

// ---------------------------------------------------------------------------
// Combinatorial ROM model
//   rom_data is updated whenever addr_bus changes; the core samples it at
//   S3P1 (osc_cnt==4) and S6P1 (osc_cnt==10) – well within the access window
//   for any reasonable memory speed.
// ---------------------------------------------------------------------------
always @(*) begin
    rom_data = rom[addr_bus];
end

// ---------------------------------------------------------------------------
// External RAM read model
//   Provide data to xdata_in whenever /RD is asserted.
// ---------------------------------------------------------------------------
always @(*) begin
    if (!xrd_n)
        xdata_in = xram[xaddr_bus];
    else
        xdata_in = 8'hFF;
end

// ---------------------------------------------------------------------------
// External RAM write model
//   Capture the write on the rising edge of /WR (end of write strobe).
// ---------------------------------------------------------------------------
always @(posedge xwr_n) begin
    xram[xaddr_bus] <= xdata_out;
end

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------
reg        test_done;
reg [7:0]  test_result;
integer    pass_count;
integer    fail_count;
integer    rp;          // ROM byte write pointer

// ---------------------------------------------------------------------------
// Test-completion monitor
//   The test program writes its result byte to external address 0x0010 via
//   MOVX @DPTR,A (opcode 0xF0).  We detect this as a falling edge on xwr_n
//   while xaddr_bus == 0x0010.
//
//   Note: xwr_n asserts at S6P1 (osc_cnt==10) and deasserts at S6P2 (==11).
//   We detect on the negedge of xwr_n so the address and data are stable.
// ---------------------------------------------------------------------------
always @(negedge xwr_n or negedge res_n) begin
    if (!res_n) begin
        test_done   <= 1'b0;
        test_result <= 8'hFF;
    end else if (xaddr_bus == 16'h0010) begin
        test_done   <= 1'b1;
        test_result <= xdata_out;
    end
end

// ---------------------------------------------------------------------------
// DUT: i8051_core  (native bus interface)
// ---------------------------------------------------------------------------
i8051_core dut (
    // Clock and reset
    .clk        ( clk       ),
    .res_n      ( res_n     ),      // active-LOW (was wb_rst_i active-high)

    // External interrupts: tied inactive (active-low → tie high)
    .int0_n     ( 1'b1      ),
    .int1_n     ( 1'b1      ),

    // Timer/counter external inputs: no external events
    .t0         ( 1'b0      ),
    .t1         ( 1'b0      ),

    // UART: driven by the UART tests (uart_send); idle high otherwise
    .rxd        ( rxd_tb    ),
    .txd        ( txd       ),

    // Program memory (combinatorial byte-wide ROM)
    .rom_data   ( rom_data  ),
    .addr_bus   ( addr_bus  ),

    // Bus control
    .ale        ( ale       ),
    .psen_n     ( psen_n    ),

    // External data memory
    .xdata_in   ( xdata_in  ),
    .xdata_out  ( xdata_out ),
    .xaddr_bus  ( xaddr_bus ),
    .xrd_n      ( xrd_n     ),
    .xwr_n      ( xwr_n     ),

    // I/O ports (inputs pulled high; outputs monitored)
    .p0         ( p0        ),
    .p1         ( p1        ),
    .p2         ( p2        ),
    .p3         ( p3        ),

    // Debug outputs
    .pc         ( pc_mon    ),
    .ir         ( ir_mon    )
);

// ---------------------------------------------------------------------------
// UART line models (tests 37-46)
//   cyc counts oscillator clocks. The TX monitor, armed by a test with the
//   bit time it expects (mon_p, in oscillator clocks), decodes one frame
//   off TXD: it samples the middle of each of mon_nbits bits after the start
//   bit's falling edge, and times the first rising edge after it. uart_send
//   drives one frame onto RXD with a given bit time.
// ---------------------------------------------------------------------------
reg        rxd_tb = 1'b1;
integer    cyc = 0;
always @(posedge clk) cyc = cyc + 1;

reg        mon_arm  = 1'b0;
reg        mon_busy = 1'b0;
reg        mon_done = 1'b0;
integer    mon_p     = 64;   // expected bit time, oscillator clocks
integer    mon_nbits = 11;   // start + 8 data + [9th] + stop
integer    mon_rise  = -1;   // clocks from the start edge to the next rising edge
reg [10:0] mon_bits  = 11'd0;

always @(negedge txd) begin : uart_mon
    integer k, t0;
    if (mon_arm && !mon_busy && res_n) begin
        mon_busy = 1'b1;
        t0 = cyc;
        mon_rise = -1;
        fork
            begin @(posedge txd); mon_rise = cyc - t0; end
            begin
                repeat (mon_p / 2) @(posedge clk);
                for (k = 0; k < mon_nbits; k = k + 1) begin
                    mon_bits[k] = txd;
                    if (k < mon_nbits - 1) repeat (mon_p) @(posedge clk);
                end
            end
        join
        mon_done = 1'b1;
        mon_arm  = 1'b0;
        mon_busy = 1'b0;
    end
end

// Send one frame on RXD: start, D0..D7, [9th bit if nine], stop
task uart_send;
    input [7:0] data;
    input       b9;
    input       nine;
    input integer p;
    integer k;
    begin
        rxd_tb = 1'b0;                              // start
        repeat (p) @(posedge clk);
        for (k = 0; k < 8; k = k + 1) begin
            rxd_tb = data[k];
            repeat (p) @(posedge clk);
        end
        if (nine) begin
            rxd_tb = b9;
            repeat (p) @(posedge clk);
        end
        rxd_tb = 1'b1;                              // stop
        repeat (p) @(posedge clk);
    end
endtask

// Arm the TX monitor for the next frame
task mon_start;
    input integer p;
    input integer nbits;
    begin
        mon_p = p; mon_nbits = nbits;
        mon_done = 1'b0; mon_arm = 1'b1; mon_bits = 11'd0; mon_rise = -1;
    end
endtask

// After run_test: check what the TX monitor saw. exp_bits are the frame's
// bits LSB first (start bit 0 at [0]); exp_rise is where the first rising
// edge after the start edge should be (the bit time times the number of
// leading zero bits).
task mon_check;
    input [255:0] tname;
    input [10:0]  exp_bits;
    input integer exp_rise;
    reg   [10:0]  mask;
    integer       w;
    begin
        // TI comes at the start of the stop bit, so the program can report
        // before the monitor has sampled the stop bit: give it two bit times
        w = 0;
        while (!mon_done && w < 2 * mon_p) begin @(posedge clk); w = w + 1; end
        mask = (11'd1 << mon_nbits) - 11'd1;
        if (!mon_done) begin
            $display("FAIL     [%0s]  no frame seen on TXD", tname);
            fail_count = fail_count + 1;
        end else if ((mon_bits & mask) !== (exp_bits & mask) || mon_rise != exp_rise) begin
            $display("FAIL     [%0s]  frame bits=%b (want %b), first rise after %0d clocks (want %0d)",
                     tname, mon_bits & mask, exp_bits & mask, mon_rise, exp_rise);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS     [%0s]", tname);
            pass_count = pass_count + 1;
        end
        mon_arm = 1'b0;
    end
endtask

// ===========================================================================
// TASK LIBRARY
// ===========================================================================

// ---------------------------------------------------------------------------
// clear_rom
//   Fill entire ROM with NOPs (0x00) and install the standard tail routine
//   at 0x0100.  Every test jumps to 0x0100 via LJMP to report its result.
//
//   Tail:
//     0x0100: 90 00 10   MOV DPTR,#0x0010
//     0x0103: F0         MOVX @DPTR,A       ← result written to xram[0x0010]
//     0x0104: 80 FE      SJMP $             ← spin forever
//
//   A = 0x7F → PASS; any other value → FAIL (value is the error code).
// ---------------------------------------------------------------------------
task clear_rom;
    integer i;
    begin
        for (i = 0; i < 512; i = i + 1)  // tests use 0x0000-0x01FF only
            rom[i] = 8'h00;         // 0x00 = NOP on 8051
        rp = 0;

        // Tail routine at 0x0100
        rom[16'h0100] = 8'h90;     // MOV DPTR,#imm16
        rom[16'h0101] = 8'h00;     //   high byte: 0x00
        rom[16'h0102] = 8'h10;     //   low  byte: 0x10  → DPTR=0x0010
        rom[16'h0103] = 8'hF0;     // MOVX @DPTR,A
        rom[16'h0104] = 8'h80;     // SJMP
        rom[16'h0105] = 8'hFE;     //   offset -2  → spin
    end
endtask

// ---------------------------------------------------------------------------
// wb: write one byte into ROM at the current write pointer, then advance
// ---------------------------------------------------------------------------
task wb;
    input [7:0] b;
    begin
        rom[rp] = b;
        rp = rp + 1;
    end
endtask

// ---------------------------------------------------------------------------
// check: append inline pass/fail dispatch to ROM
//
//   B4 expected 05   CJNE A,#expected,+5  → branch to fail path if A≠expected
//   74 7F            MOV  A,#0x7F         ← PASS path
//   02 01 00         LJMP 0x0100
//   74 errcode       MOV  A,#errcode      ← FAIL path
//   02 01 00         LJMP 0x0100
//
//   CJNE offset: instruction is 3 bytes, fail path is 5 bytes later → +5 ✓
// ---------------------------------------------------------------------------
task check;
    input [7:0] expected;
    input [7:0] errcode;
    begin
        wb(8'hB4); wb(expected); wb(8'h05);  // CJNE A,#expected,+5
        wb(8'h74); wb(8'h7F);                // MOV A,#0x7F  (PASS)
        wb(8'h02); wb(8'h01); wb(8'h00);     // LJMP 0x0100
        wb(8'h74); wb(errcode);              // MOV A,#errcode  (FAIL)
        wb(8'h02); wb(8'h01); wb(8'h00);     // LJMP 0x0100
    end
endtask

// ---------------------------------------------------------------------------
// run_test
//   Apply active-low reset, then poll for test_done or timeout.
//   Timeouts are in oscillator clock edges (12 clocks = 1 machine cycle).
// ---------------------------------------------------------------------------
task run_test;
    input [255:0] tname;
    input integer max_osc_clocks;
    integer timeout;
    begin
        // Assert active-LOW reset for at least 4 clock edges
        res_n = 1'b0;
        repeat(4) @(posedge clk);
        @(negedge clk);
        res_n = 1'b1;

        // Poll for completion or timeout
        timeout = 0;
        while (!test_done && timeout < max_osc_clocks) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        // Evaluate result
        if (!test_done) begin
            $display("TIMEOUT  [%0s]  (%0d osc clocks)", tname, max_osc_clocks);
            fail_count = fail_count + 1;
        end else if (test_result === 8'h7F) begin
            $display("PASS     [%0s]", tname);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL     [%0s]  error_code=0x%02X", tname, test_result);
            fail_count = fail_count + 1;
        end
    end
endtask

// ===========================================================================
// MAIN TEST SEQUENCE
// ===========================================================================
initial begin
    $dumpfile("i8051_regression.fst");
    $dumpvars(0, i8051_regression_tb);

    // Initialise counters and hold reset
    pass_count = 0;
    fail_count = 0;
    res_n = 1'b0;
    repeat(4) @(posedge clk);

    $display("\n=== i8051_core Regression Testbench ===\n");

    // =========================================================================
    // TEST 01: MOV immediate + ADD register
    //   MOV A,#0x34        74 34
    //   MOV R0,#0x12       78 12
    //   ADD A,R0           28
    //   Expected A = 0x34 + 0x12 = 0x46
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h34);           // MOV A,#0x34
    wb(8'h78); wb(8'h12);           // MOV R0,#0x12
    wb(8'h28);                       // ADD A,R0
    check(8'h46, 8'h01);
    run_test("01_MOV_IMM_ADD_R", `MAX_OSC);

    // =========================================================================
    // TEST 02: ADDC (add with carry)
    //   SETB C             D3
    //   MOV A,#0x0F        74 0F
    //   ADDC A,#0x01       34 01    → 0x0F + 0x01 + 1(carry) = 0x11
    // =========================================================================
    clear_rom;
    wb(8'hD3);                       // SETB C
    wb(8'h74); wb(8'h0F);           // MOV A,#0x0F
    wb(8'h34); wb(8'h01);           // ADDC A,#0x01
    check(8'h11, 8'h02);
    run_test("02_ADDC_IMM", `MAX_OSC);

    // =========================================================================
    // TEST 03: SUBB (subtract with borrow)
    //   CLR C              C3
    //   MOV A,#0x50        74 50
    //   SUBB A,#0x30       94 30    → 0x50 - 0x30 - 0 = 0x20
    // =========================================================================
    clear_rom;
    wb(8'hC3);                       // CLR C
    wb(8'h74); wb(8'h50);           // MOV A,#0x50
    wb(8'h94); wb(8'h30);           // SUBB A,#0x30
    check(8'h20, 8'h03);
    run_test("03_SUBB_IMM", `MAX_OSC);

    // =========================================================================
    // TEST 04: MUL AB
    //   MOV A,#0x0A        74 0A
    //   MOV B,#0x07        75 F0 07   (MOV direct 0xF0,#imm; 0xF0=B SFR)
    //   MUL AB             A4
    //   Expected A = 0x46 (low byte of 10*7=70), B = 0x00 (high byte)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h0A);           // MOV A,#10
    wb(8'h75); wb(8'hF0); wb(8'h07);// MOV B,#7
    wb(8'hA4);                       // MUL AB
    check(8'h46, 8'h04);
    run_test("04_MUL_AB", 12000);

    // =========================================================================
    // TEST 05: DIV AB
    //   MOV A,#0x63  (99)   74 63
    //   MOV B,#0x0A  (10)   75 F0 0A
    //   DIV AB              84
    //   Expected A = 9 (quotient), B = 9 (remainder)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h63);           // MOV A,#99
    wb(8'h75); wb(8'hF0); wb(8'h0A);// MOV B,#10
    wb(8'h84);                       // DIV AB
    check(8'h09, 8'h05);
    run_test("05_DIV_AB", 12000);

    // =========================================================================
    // TEST 06: INC A / DEC A
    //   MOV A,#0xFF        74 FF
    //   INC A              04    → 0x00
    //   INC A              04    → 0x01
    //   DEC A              14    → 0x00
    //   Expected A = 0x00
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hFF);           // MOV A,#0xFF
    wb(8'h04);                       // INC A → 0x00
    wb(8'h04);                       // INC A → 0x01
    wb(8'h14);                       // DEC A → 0x00
    check(8'h00, 8'h06);
    run_test("06_INC_DEC_A", `MAX_OSC);

    // =========================================================================
    // TEST 07: ANL A,#imm
    //   MOV A,#0xAA        74 AA
    //   ANL A,#0x0F        54 0F    → 0xAA & 0x0F = 0x0A
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAA);           // MOV A,#0xAA
    wb(8'h54); wb(8'h0F);           // ANL A,#0x0F
    check(8'h0A, 8'h07);
    run_test("07_ANL_IMM", `MAX_OSC);

    // =========================================================================
    // TEST 08: ORL A,#imm
    //   MOV A,#0xA0        74 A0
    //   ORL A,#0x0B        44 0B    → 0xA0 | 0x0B = 0xAB
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hA0);           // MOV A,#0xA0
    wb(8'h44); wb(8'h0B);           // ORL A,#0x0B
    check(8'hAB, 8'h08);
    run_test("08_ORL_IMM", `MAX_OSC);

    // =========================================================================
    // TEST 09: XRL A,#imm
    //   MOV A,#0xFF        74 FF
    //   XRL A,#0x0F        64 0F    → 0xFF ^ 0x0F = 0xF0
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hFF);           // MOV A,#0xFF
    wb(8'h64); wb(8'h0F);           // XRL A,#0x0F
    check(8'hF0, 8'h09);
    run_test("09_XRL_IMM", `MAX_OSC);

    // =========================================================================
    // TEST 10: CPL A
    //   MOV A,#0xAA        74 AA
    //   CPL A              F4       → ~0xAA = 0x55
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAA);           // MOV A,#0xAA
    wb(8'hF4);                       // CPL A
    check(8'h55, 8'h0A);
    run_test("10_CPL_A", `MAX_OSC);

    // =========================================================================
    // TEST 11: RL A (rotate left, no carry)
    //   MOV A,#0x81        74 81    binary: 1000_0001
    //   RL  A              23       → 0000_0011 = 0x03
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h81);           // MOV A,#0x81
    wb(8'h23);                       // RL A
    check(8'h03, 8'h0B);
    run_test("11_RL_A", `MAX_OSC);

    // =========================================================================
    // TEST 12: RR A (rotate right, no carry)
    //   MOV A,#0x81        74 81    binary: 1000_0001
    //   RR  A              03       → 1100_0000 = 0xC0
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h81);           // MOV A,#0x81
    wb(8'h03);                       // RR A
    check(8'hC0, 8'h0C);
    run_test("12_RR_A", `MAX_OSC);

    // =========================================================================
    // TEST 13: RLC A (rotate left through carry)
    //   CLR C              C3
    //   MOV A,#0x01        74 01    binary: 0000_0001
    //   RLC A              33       → A=0x02, C=0  (bit7 was 0, old C=0 enters bit0)
    //
    //   Using input 0x01 (result 0x02) avoids the CJNE-kills-carry problem that
    //   occurs when checking A==0x00: CJNE sets C=0 before JC can test it.
    //   The standard check() macro (CJNE A,#expected) is safe here because
    //   the carry we care about (C=0) is the same value CJNE would leave anyway.
    // =========================================================================
    clear_rom;
    wb(8'hC3);                       // CLR C
    wb(8'h74); wb(8'h01);           // MOV A,#0x01
    wb(8'h33);                       // RLC A  → A=0x02, C=0
    check(8'h02, 8'h0D);            // Expected A = 0x02
    run_test("13_RLC_A", `MAX_OSC);

    // =========================================================================
    // TEST 14: SWAP A
    //   MOV A,#0xAB        74 AB
    //   SWAP A             C4       → 0xBA
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAB);           // MOV A,#0xAB
    wb(8'hC4);                       // SWAP A
    check(8'hBA, 8'h0E);
    run_test("14_SWAP_A", `MAX_OSC);

    // =========================================================================
    // TEST 15: DA A (decimal adjust after BCD addition)
    //   MOV A,#0x48        74 48      (BCD 48)
    //   ADD A,#0x28        24 28      → A=0x70, AC=1
    //   DA  A              D4         → 0x70 + 0x06 = 0x76  (BCD 76)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h48);           // MOV A,#0x48
    wb(8'h24); wb(8'h28);           // ADD A,#0x28
    wb(8'hD4);                       // DA A
    check(8'h76, 8'h0F);
    run_test("15_DA_A", `MAX_OSC);

    // =========================================================================
    // TEST 16: SJMP forward
    //   MOV A,#0x05        74 05
    //   SJMP +2            80 02     → skip next 2 bytes
    //   MOV A,#0x00        74 00     ← SKIPPED
    //   check A == 0x05
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h05);           // MOV A,#0x05
    wb(8'h80); wb(8'h02);           // SJMP +2 (skips next 2 bytes)
    wb(8'h74); wb(8'h00);           // MOV A,#0x00  ← SKIPPED
    check(8'h05, 8'h10);
    run_test("16_SJMP_FWD", `MAX_OSC);

    // =========================================================================
    // TEST 17: LJMP (long jump)
    //   0x0000: 74 0A   MOV A,#0x0A
    //   0x0002: 02 00 09 LJMP 0x0009
    //   0x0005–0x0008:  skipped bytes
    //   0x0009: check(0x0A, 0x11)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h0A);           // 0x0000: MOV A,#0x0A
    wb(8'h02); wb(8'h00); wb(8'h09);// 0x0002: LJMP 0x0009
    wb(8'h74); wb(8'h00);           // 0x0005: skipped
    wb(8'h00);                       // 0x0007: skipped
    wb(8'h00);                       // 0x0008: skipped
    // 0x0009:
    check(8'h0A, 8'h11);
    run_test("17_LJMP", `MAX_OSC);

    // =========================================================================
    // TEST 18: JC / JNC (carry branch)
    //   0x0000: D3       SETB C
    //   0x0001: 40 05    JC +5   → 0x0008
    //   0x0003: 74 12    fail
    //   0x0005: 02 01 00 LJMP 0x0100
    //   0x0008: C3       CLR C
    //   0x0009: 50 05    JNC +5  → 0x0010
    //   0x000B: 74 12    fail
    //   0x000D: 02 01 00 LJMP 0x0100
    //   0x0010: 74 7F    pass
    //   0x0012: 02 01 00 LJMP 0x0100
    // =========================================================================
    clear_rom;
    wb(8'hD3);                       // 0x0000: SETB C
    wb(8'h40); wb(8'h05);           // 0x0001: JC +5 → 0x0008
    wb(8'h74); wb(8'h12);           // 0x0003: fail
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x0005: LJMP 0x0100
    wb(8'hC3);                       // 0x0008: CLR C
    wb(8'h50); wb(8'h05);           // 0x0009: JNC +5 → 0x0010
    wb(8'h74); wb(8'h12);           // 0x000B: fail
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x000D: LJMP 0x0100
    wb(8'h74); wb(8'h7F);           // 0x0010: pass
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x0012: LJMP 0x0100
    run_test("18_JC_JNC", `MAX_OSC);

    // =========================================================================
    // TEST 19: JZ / JNZ
    //   0x0000: 74 00    MOV A,#0x00
    //   0x0002: 60 05    JZ +5   → 0x0009
    //   0x0004: 74 13    fail
    //   0x0006: 02 01 00 LJMP 0x0100
    //   0x0009: 04       INC A → 0x01
    //   0x000A: 70 05    JNZ +5  → 0x0011
    //   0x000C: 74 13    fail
    //   0x000E: 02 01 00 LJMP 0x0100
    //   0x0011: 74 7F    pass
    //   0x0013: 02 01 00 LJMP 0x0100
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h00);           // 0x0000: MOV A,#0x00
    wb(8'h60); wb(8'h05);           // 0x0002: JZ +5 → 0x0009
    wb(8'h74); wb(8'h13);           // 0x0004: fail
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x0006: LJMP 0x0100
    wb(8'h04);                       // 0x0009: INC A → 0x01
    wb(8'h70); wb(8'h05);           // 0x000A: JNZ +5 → 0x0011
    wb(8'h74); wb(8'h13);           // 0x000C: fail
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x000E: LJMP 0x0100
    wb(8'h74); wb(8'h7F);           // 0x0011: pass
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x0013: LJMP 0x0100
    run_test("19_JZ_JNZ", `MAX_OSC);

    // =========================================================================
    // TEST 20: JB / JNB (bit-test branches)
    //   ACC SFR is at 0xE0; ACC.7 bit-address = 0xE0 | 7 = 0xE7.
    //   JB  reads SFR bit → uses sfr_read path in i8051_core's bit_read().
    //
    //   0x0000: 74 80    MOV A,#0x80         (ACC.7=1)
    //   0x0002: 20 E7 05 JB  ACC.7,+5  → 0x000A
    //   0x0005: 74 14    fail
    //   0x0007: 02 01 00 LJMP 0x0100
    //   0x000A: 74 7F    MOV A,#0x7F         (ACC.7=0)
    //   0x000C: 30 E7 05 JNB ACC.7,+5  → 0x0014
    //   0x000F: 74 14    fail
    //   0x0011: 02 01 00 LJMP 0x0100
    //   0x0014: 74 7F    pass
    //   0x0016: 02 01 00 LJMP 0x0100
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h80);           // 0x0000: MOV A,#0x80  (ACC.7=1)
    wb(8'h20); wb(8'hE7); wb(8'h05);// 0x0002: JB ACC.7,+5 → 0x000A
    wb(8'h74); wb(8'h14);           // 0x0005: fail
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x0007: LJMP 0x0100
    wb(8'h74); wb(8'h7F);           // 0x000A: MOV A,#0x7F  (ACC.7=0)
    wb(8'h30); wb(8'hE7); wb(8'h05);// 0x000C: JNB ACC.7,+5 → 0x0014
    wb(8'h74); wb(8'h14);           // 0x000F: fail
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x0011: LJMP 0x0100
    wb(8'h74); wb(8'h7F);           // 0x0014: pass
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x0016: LJMP 0x0100
    run_test("20_JB_JNB", `MAX_OSC);

    // =========================================================================
    // TEST 21: DJNZ R0 (decrement & jump if not zero loop)
    //   MOV R0,#5    78 05
    //   MOV A,#0     74 00
    //   loop (0x0004):
    //     INC A      04
    //     DJNZ R0,-3 D8 FD    PC_after=0x0007; 0x0007+0xFD=0x0004 ✓
    //   0x0007: check(5, 0x15)
    // =========================================================================
    clear_rom;
    wb(8'h78); wb(8'h05);           // 0x0000: MOV R0,#5
    wb(8'h74); wb(8'h00);           // 0x0002: MOV A,#0
    wb(8'h04);                       // 0x0004: INC A   ← loop
    wb(8'hD8); wb(8'hFD);           // 0x0005: DJNZ R0,-3 → 0x0004
    check(8'h05, 8'h15);            // 0x0007
    run_test("21_DJNZ_R0", 12000);

    // =========================================================================
    // TEST 22: PUSH ACC / POP ACC (stack)
    //   MOV A,#0xAB    74 AB
    //   PUSH ACC       C0 E0   (direct address 0xE0 = ACC SFR)
    //   MOV A,#0x00    74 00
    //   POP  ACC       D0 E0
    //   Expected A = 0xAB
    //   SP resets to 0x07; PUSH increments SP to 0x08 then stores.
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAB);           // MOV A,#0xAB
    wb(8'hC0); wb(8'hE0);           // PUSH ACC (direct 0xE0)
    wb(8'h74); wb(8'h00);           // MOV A,#0x00
    wb(8'hD0); wb(8'hE0);           // POP  ACC
    check(8'hAB, 8'h16);
    run_test("22_PUSH_POP_ACC", `MAX_OSC);

    // =========================================================================
    // TEST 23: MOVX @DPTR,A / MOVX A,@DPTR (external RAM via DPTR)
    //   MOV DPTR,#0x0020   90 00 20
    //   MOV A,#0xA5        74 A5
    //   MOVX @DPTR,A       F0          → write 0xA5 to xram[0x0020]
    //   MOV A,#0x00        74 00       → clear A
    //   MOVX A,@DPTR       E0          → read back from xram[0x0020]
    //   Expected A = 0xA5
    // =========================================================================
    clear_rom;
    wb(8'h90); wb(8'h00); wb(8'h20);// MOV DPTR,#0x0020
    wb(8'h74); wb(8'hA5);           // MOV A,#0xA5
    wb(8'hF0);                       // MOVX @DPTR,A  (write)
    wb(8'h74); wb(8'h00);           // MOV A,#0x00
    wb(8'hE0);                       // MOVX A,@DPTR  (read)
    check(8'hA5, 8'h17);
    run_test("23_MOVX_DPTR", 12000);

    // =========================================================================
    // TEST 24: LCALL / RET (subroutine call and return)
    //   Main:
    //     0x0000: 74 00      MOV A,#0x00
    //     0x0002: 12 00 50   LCALL 0x0050
    //     0x0005: check(0x37, 0x18)
    //   Subroutine at 0x0050:
    //     0x0050: 74 37      MOV A,#0x37
    //     0x0052: 22         RET
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h00);           // 0x0000: MOV A,#0x00
    wb(8'h12); wb(8'h00); wb(8'h50);// 0x0002: LCALL 0x0050
    check(8'h37, 8'h18);            // 0x0005
    rp = 16'h0050;
    wb(8'h74); wb(8'h37);           // 0x0050: MOV A,#0x37
    wb(8'h22);                       // 0x0052: RET
    run_test("24_LCALL_RET", 12000);

    // =========================================================================
    // TEST 25: MOV direct (direct addressing mode)
    //   MOV iram[0x30],#0xCD   75 30 CD
    //   MOV A,iram[0x30]       E5 30
    //   Expected A = 0xCD
    // =========================================================================
    clear_rom;
    wb(8'h75); wb(8'h30); wb(8'hCD);// MOV iram[0x30],#0xCD
    wb(8'hE5); wb(8'h30);           // MOV A,iram[0x30]
    check(8'hCD, 8'h19);
    run_test("25_MOV_DIRECT", `MAX_OSC);

    // =========================================================================
    // TEST 26: MOV @R0 (indirect addressing)
    //   MOV R0,#0x40      78 40    (point R0 at iram[0x40])
    //   MOV @R0,#0x55     76 55
    //   MOV A,@R0         E6
    //   Expected A = 0x55
    // =========================================================================
    clear_rom;
    wb(8'h78); wb(8'h40);           // MOV R0,#0x40
    wb(8'h76); wb(8'h55);           // MOV @R0,#0x55
    wb(8'hE6);                       // MOV A,@R0
    check(8'h55, 8'h1A);
    run_test("26_MOV_INDIRECT", `MAX_OSC);

    // =========================================================================
    // TEST 27: INC DPTR
    //   MOV DPTR,#0xABCD    90 AB CD
    //   INC DPTR            A3
    //   MOV A,DPL           E5 82    (DPL SFR = 0x82)
    //   Expected A (DPL) = 0xCE
    // =========================================================================
    clear_rom;
    wb(8'h90); wb(8'hAB); wb(8'hCD);// MOV DPTR,#0xABCD
    wb(8'hA3);                       // INC DPTR
    wb(8'hE5); wb(8'h82);           // MOV A,DPL  (SFR 0x82)
    check(8'hCE, 8'h1B);
    run_test("27_INC_DPTR", `MAX_OSC);

    // =========================================================================
    // TEST 28: MOVC A,@A+DPTR (read from program memory)
    //   Place sentinel 0x5A at rom[0x0040].
    //   MOV DPTR,#0x0038    90 00 38
    //   MOV A,#0x08         74 08
    //   MOVC A,@A+DPTR      93       → reads rom[0x0038+0x08]=rom[0x0040]=0x5A
    //   Expected A = 0x5A
    //
    //   On i8051_core: addr_bus mux drives (DPTR+A) during cycle_2 of 0x93.
    //   The combinatorial ROM model returns rom[addr_bus] immediately so
    //   the core reads rom_data = 0x5A at S6P1.
    // =========================================================================
    clear_rom;
    rom[16'h0040] = 8'h5A;          // sentinel data byte
    wb(8'h90); wb(8'h00); wb(8'h38);// MOV DPTR,#0x0038
    wb(8'h74); wb(8'h08);           // MOV A,#0x08
    wb(8'h93);                       // MOVC A,@A+DPTR
    check(8'h5A, 8'h1C);
    run_test("28_MOVC_DPTR", 12000);

    // =========================================================================
    // TEST 29: CJNE A,direct (compare and jump if not equal)
    //   0x0000: 75 30 AA  MOV iram[0x30],#0xAA
    //   0x0003: 74 BB     MOV A,#0xBB         (A ≠ (0x30))
    //   0x0005: B5 30 05  CJNE A,0x30,+5  PC_after=0x0008 → target=0x000D
    //   0x0008: 74 1D     fall-through (equal, shouldn't happen → fail)
    //   0x000A: 02 01 00  LJMP 0x0100
    //   0x000D: 74 7F     pass (not-equal branch taken)
    //   0x000F: 02 01 00  LJMP 0x0100
    // =========================================================================
    clear_rom;
    wb(8'h75); wb(8'h30); wb(8'hAA);// 0x0000: MOV iram[0x30],#0xAA
    wb(8'h74); wb(8'hBB);           // 0x0003: MOV A,#0xBB
    wb(8'hB5); wb(8'h30); wb(8'h05);// 0x0005: CJNE A,0x30,+5 → 0x000D
    wb(8'h74); wb(8'h1D);           // 0x0008: fail
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x000A: LJMP 0x0100
    wb(8'h74); wb(8'h7F);           // 0x000D: pass
    wb(8'h02); wb(8'h01); wb(8'h00);// 0x000F: LJMP 0x0100
    run_test("29_CJNE_DIRECT", `MAX_OSC);

    // =========================================================================
    // TEST 30: MOV register ↔ direct address
    //   MOV R1,#0x42       79 42    (0x79 = MOV R1,#imm)
    //   MOV iram[0x31],R1  89 31    (0x89 = MOV direct,R1)
    //   MOV A,iram[0x31]   E5 31
    //   Expected A = 0x42
    // =========================================================================
    clear_rom;
    wb(8'h79); wb(8'h42);           // MOV R1,#0x42
    wb(8'h89); wb(8'h31);           // MOV iram[0x31],R1
    wb(8'hE5); wb(8'h31);           // MOV A,iram[0x31]
    check(8'h42, 8'h1E);
    run_test("30_MOV_REG_DIRECT", `MAX_OSC);

    // =========================================================================
    // TEST 31: Interrupt return address correctness (INT during 3-byte insn)
    //
    //  Scenario: Timer 1 interrupt fires while the CPU is about to fetch and
    //  execute a JNB instruction at 0x0055.  After RETI the CPU must return
    //  to 0x0055 (start of JNB), not 0x0056 (its bit-addr operand byte).
    //
    //  Memory layout:
    //    0x0000: LJMP 0x0050          ; skip over interrupt vector area
    //    0x001B: MOV A,#0x7F ; RETI  ; Timer 1 ISR – sets A to pass value
    //    0x0050: MOV IE,#0x88         ; EA=1, ET1=1
    //    0x0053: SETB TF1             ; D2 8F – arm TF1 directly (no timer running)
    //    0x0055: JNB PSW.7,+0         ; 30 D7 00 – CY=0 so branches to 0x0058
    //    0x0058: check(0x7F, 0x1F)    ; A must still be 0x7F from ISR
    //
    //  Correct return (0x0055): JNB executes, CY=0 → branches to 0x0058.
    //    A = 0x7F (unchanged from ISR) → PASS.
    //
    //  Wrong return (0x0056) [old bug – PC pre-incremented before interrupt]:
    //    0x0056 = 0xD7 = CPL A → A = ~0x7F = 0x80
    //    0x0057 = 0x00 = NOP
    //    falls into 0x0058: check(0x7F) → A=0x80 → FAIL (errcode 0x1F).
    // =========================================================================
    clear_rom;
    // Entry: jump over vector table to main code
    wb(8'h02); wb(8'h00); wb(8'h50);    // 0x0000: LJMP 0x0050
    // Timer 1 ISR at vector 0x001B
    rom[16'h001B] = 8'h74;               // MOV A,#imm
    rom[16'h001C] = 8'h7F;               //   #0x7F  (pass sentinel)
    rom[16'h001D] = 8'h32;               // RETI
    // Main code at 0x0050
    rp = 16'h0050;
    wb(8'h75); wb(8'hA8); wb(8'h88);    // 0x0050: MOV IE,#0x88  (EA=1, ET1=1)
    wb(8'hD2); wb(8'h8F);               // 0x0053: SETB TF1  (TCON.7, bit addr 0x8F)
    wb(8'h30); wb(8'hD7); wb(8'h00);    // 0x0055: JNB PSW.7,+0  (CY=0 → branch to 0x0058)
    // 0x0058: result check – A must be 0x7F (set by ISR, untouched by correct return)
    check(8'h7F, 8'h1F);
    run_test("31_INT_RETURN_ADDR", 4000);

    // =========================================================================
    // TEST 32: High-priority interrupt preempts low-priority ISR
    //
    //  This is the DME injection-timer scenario: Timer 0 (high priority via IP)
    //  must preempt a currently-executing INT1 (low-priority) ISR.
    //
    //  Setup:
    //    IP = 0x02  → PT0=1 (Timer 0 high priority), all others low
    //    IE = 0x87  → EA=1, EX0=1, ET0=1, EX1=1
    //
    //  Sequence:
    //    1. Main sets IP and IE, then SETB IE1 only (TF0 not yet armed).
    //       CPU vectors to INT1 ISR (low-priority).  irq_in_progress=1,
    //       irq_hi_active=0.
    //    2. INT1 ISR writes 0xAA to iram[0x40], then does SETB TF0 to arm
    //       the high-priority Timer 0 interrupt from inside the ISR.
    //    3. On the very next instruction boundary the arbiter sees:
    //         TF0 pending, ET0 enabled, PT0=1 (high priority),
    //         irq_hi_active=0 (current ISR is low-priority)
    //       → dispatch fires, T0 ISR preempts INT1 ISR.
    //    4. T0 ISR (0x000B): writes 0x5A to iram[0x41], CLR TF0, RETI
    //       → resumes INT1 ISR.
    //    5. INT1 ISR: CLR IE1, RETI → returns to main at 0x0058.
    //    6. Main reads iram[0x41] into A and checks for 0x5A.
    //
    //  PASS (A=0x5A): T0 ISR ran inside INT1 ISR and wrote the sentinel.
    //  FAIL (0x20):   iram[0x41] ≠ 0x5A — preemption did not occur.
    //
    //  Memory layout:
    //    0x0000: LJMP 0x0050
    //    0x000B: T0 ISR  — MOV iram[41h],#5A ; CLR TF0 ; RETI
    //    0x0013: INT1 ISR — MOV iram[40h],#AA ; SETB TF0 ; 6×NOP ;
    //                        CLR IE1 ; RETI
    //    0x0050: Main — MOV IP,#02 ; MOV IE,#87 ; SETB IE1
    //    0x0058: (after both RETIs) — MOV A,iram[41h] ; check(0x5A,0x20)
    // =========================================================================
    clear_rom;
    // 0x0000: LJMP 0x0050
    wb(8'h02); wb(8'h00); wb(8'h50);

    // --- T0 ISR at 0x000B ---
    rom[16'h000B] = 8'h75;   // MOV iram[0x41],#0x5A
    rom[16'h000C] = 8'h41;
    rom[16'h000D] = 8'h5A;
    rom[16'h000E] = 8'hC2;   // CLR TF0  (bit 0x8D = TCON.5)
    rom[16'h000F] = 8'h8D;
    rom[16'h0010] = 8'h32;   // RETI

    // --- INT1 ISR at 0x0013 ---
    //  Writes contamination, then ARMS TF0 to trigger T0 preemption.
    //  Six NOPs follow so the arbiter has instruction boundaries at which
    //  to fire the preemption before the ISR finishes.
    rom[16'h0013] = 8'h75;   // MOV iram[0x40],#0xAA  (contamination)
    rom[16'h0014] = 8'h40;
    rom[16'h0015] = 8'hAA;
    rom[16'h0016] = 8'hD2;   // SETB TF0  (bit 0x8D) — arm hi-pri preemption
    rom[16'h0017] = 8'h8D;
    rom[16'h0018] = 8'h00;   // NOP  ← T0 preempts here (first boundary)
    rom[16'h0019] = 8'h00;   // NOP
    rom[16'h001A] = 8'h00;   // NOP
    // 0x001B is the Timer1 vector — ET1 is disabled so it won't fire,
    // but the byte here is executed as a NOP if T0 preemption is delayed.
    rom[16'h001B] = 8'h00;   // NOP
    rom[16'h001C] = 8'h00;   // NOP
    rom[16'h001D] = 8'h00;   // NOP
    rom[16'h001E] = 8'hC2;   // CLR IE1  (bit 0x8B = TCON.3)
    rom[16'h001F] = 8'h8B;
    rom[16'h0020] = 8'h32;   // RETI → back to main at 0x0058

    // --- Main code at 0x0050 ---
    //  After both RETIs, execution resumes at 0x0058.
    rp = 16'h0050;
    wb(8'h75); wb(8'hB8); wb(8'h02);   // 0x0050: MOV IP,#0x02  (PT0=1 hi-pri)
    wb(8'h75); wb(8'hA8); wb(8'h87);   // 0x0053: MOV IE,#0x87  (EA,EX1,ET0,EX0)
    wb(8'hD2); wb(8'h8B);               // 0x0056: SETB IE1 (bit 0x8B) → INT1 fires
    //
    // 0x0058: INT1 RETI lands here.  iram[0x41] should be 0x5A if T0 preempted.
    wb(8'hE5); wb(8'h41);               // 0x0058: MOV A,iram[0x41]
    check(8'h5A, 8'h20);                // 0x005A: PASS if 0x5A, FAIL(0x20) otherwise
    run_test("32_HI_PRI_PREEMPT_LO_PRI", 8000);

    // =========================================================================
    // Test 33 — Register bank base address (rb_base) correctness
    //
    //  PSW[4:3] = RS1:RS0 must map to iram base addresses 0x00/0x08/0x10/0x18.
    //  The bug: {3'b000,psw[4],psw[3],2'b00} maps to 0x00/0x04/0x08/0x0C.
    //
    //  Strategy: for each of the four banks, write a unique sentinel via
    //  MOV Rn,#imm (which uses rb_base internally), then read the sentinel
    //  back via MOV A,direct (absolute iram address).  If rb_base is wrong,
    //  the write lands at the wrong address and the direct read returns 0.
    //
    //  Memory layout:
    //    0x0000: LJMP 0x0050
    //    0x0050: Main body — four bank exercises, then compare and report
    //
    //  Bank base addresses under test:
    //    Bank 0 (RS=00): iram[0x00] = R0 → write 0x11, read iram[0x00]
    //    Bank 1 (RS=01): iram[0x08] = R0 → write 0x22, read iram[0x08]
    //    Bank 2 (RS=10): iram[0x10] = R0 → write 0x33, read iram[0x10]
    //    Bank 3 (RS=11): iram[0x18] = R0 → write 0x44, read iram[0x18]
    // =========================================================================
    clear_rom;
    // 0x0000: LJMP 0x0050
    wb(8'h02); wb(8'h00); wb(8'h50);

    rp = 16'h0050;

    // ---- Bank 0 (PSW = 0x00, RS1:RS0 = 00) ----
    wb(8'h75); wb(8'hD0); wb(8'h00);   // MOV PSW,#0x00  → bank 0
    wb(8'h78); wb(8'h11);               // MOV R0,#0x11
    // ---- Bank 1 (PSW = 0x08, RS1:RS0 = 01) ----
    wb(8'h75); wb(8'hD0); wb(8'h08);   // MOV PSW,#0x08  → bank 1
    wb(8'h78); wb(8'h22);               // MOV R0,#0x22
    // ---- Bank 2 (PSW = 0x10, RS1:RS0 = 10) ----
    wb(8'h75); wb(8'hD0); wb(8'h10);   // MOV PSW,#0x10  → bank 2
    wb(8'h78); wb(8'h33);               // MOV R0,#0x33
    // ---- Bank 3 (PSW = 0x18, RS1:RS0 = 11) ----
    wb(8'h75); wb(8'hD0); wb(8'h18);   // MOV PSW,#0x18  → bank 3
    wb(8'h78); wb(8'h44);               // MOV R0,#0x44

    // ---- Verify all four writes landed at correct absolute addresses ----
    // Switch back to bank 0 first so PSW doesn't interfere
    wb(8'h75); wb(8'hD0); wb(8'h00);   // MOV PSW,#0x00

    // Check bank 0: iram[0x00] should be 0x11
    wb(8'hE5); wb(8'h00);               // MOV A,iram[0x00]
    check(8'h11, 8'h33);                // PASS=0x7F, FAIL=0x33

    // Check bank 1: iram[0x08] should be 0x22
    wb(8'hE5); wb(8'h08);               // MOV A,iram[0x08]
    check(8'h22, 8'h34);                // PASS=0x7F, FAIL=0x34

    // Check bank 2: iram[0x10] should be 0x33
    wb(8'hE5); wb(8'h10);               // MOV A,iram[0x10]
    check(8'h33, 8'h35);                // PASS=0x7F, FAIL=0x35

    // Check bank 3: iram[0x18] should be 0x44
    wb(8'hE5); wb(8'h18);               // MOV A,iram[0x18]
    check(8'h44, 8'h36);                // PASS=0x7F, FAIL=0x36 (was 0x0C with bug)

    run_test("33_REGBANK_BASE_ADDRESS", 2000);

    // =========================================================================
    // Test 34 — TF1 ISR fires after EA=0 window with continuous TCON RMW
    //
    //  Bug: CLR bit89h (CLR TCON.1) is an RMW on TCON.  sfr_read_latch reads
    //  registered 'tcon' which is stale by one cycle (timer uses NBA <=).
    //  If T1 overflows on the same clock edge, TF1 is not yet in the register,
    //  so the RMW writes it back as 0 — TF1 is permanently lost.
    //
    //  The DME firmware does exactly this: CLR bitAFh (EA=0) at 0x0422, CLR
    //  bit89h (RMW TCON) at 0x0428, SETB bitAFh (EA=1) at 0x042A.
    //
    //  Fix: combinatorial wires t0_overflow_now / t1_overflow_now computed from
    //  registered timer state are OR'd into sfr_read_latch for TCON so any
    //  same-cycle RMW preserves TF0/TF1.  These wires are race-free because
    //  they derive only from registered signals visible to all always blocks.
    //
    //  NOTE ON ICARUS VERILOG SCHEDULING: Icarus always executes always blocks
    //  in source order.  Since the timer block precedes the execute block, any
    //  blocking-shadow approach (tcon_tf0/1_written) appears to work in Icarus
    //  but fails in real simulation where block ordering is non-deterministic.
    //  This test therefore cannot distinguish the broken shadow approach from
    //  the correct combinatorial wire fix — it serves as a basic sanity check
    //  that T1 ISR fires at all after a sustained EA=0 + TCON RMW sequence.
    //  The DME simulation is the definitive test for the race-free fix.
    //
    //  Strategy:
    //    - ET1=1, EA=0 (enabled at source, globally masked)
    //    - T1 overflows after 16 ticks (192 osc clocks)
    //    - Loop 32× CLR bit89h (RMW TCON) = 384 clocks, T1 overflows during loop
    //    - SETB bitAFh (EA=1): ISR fires if TF1 survived
    //    - 8 NOPs for ISR to execute
    //    - PASS if iram[0x50]==0xA5, FAIL=0x37
    //
    //  Memory layout:
    //    0x0000: LJMP 0x0050
    //    0x001B: T1 ISR — MOV iram[0x50],#0xA5 ; RETI
    //    0x0050: Main body
    // =========================================================================
    clear_rom;
    // 0x0000: LJMP 0x0050
    wb(8'h02); wb(8'h00); wb(8'h50);

    // --- T1 ISR at 0x001B ---
    rom[16'h001B] = 8'h75;   // MOV iram[0x50],#0xA5  (sentinel)
    rom[16'h001C] = 8'h50;
    rom[16'h001D] = 8'hA5;
    rom[16'h001E] = 8'h32;   // RETI

    // --- Main at 0x0050 ---
    rp = 16'h0050;
    wb(8'h75); wb(8'h89); wb(8'h11);   // 0x0050: MOV TMOD,#0x11  T1 mode 1 (16-bit)
    wb(8'h75); wb(8'h8D); wb(8'hFF);   // 0x0053: MOV TH1,#0xFF
    wb(8'h75); wb(8'h8B); wb(8'hF0);   // 0x0056: MOV TL1,#0xF0  → 16 ticks to overflow
    wb(8'h75); wb(8'h50); wb(8'h00);   // 0x0059: MOV iram[0x50],#0x00  clear sentinel
    wb(8'h75); wb(8'hA8); wb(8'h08);   // 0x005C: MOV IE,#0x08  ET1=1, EA=0
    wb(8'hD2); wb(8'h8E);               // 0x005F: SETB TR1  start T1
    wb(8'h78); wb(8'h20);               // 0x0061: MOV R0,#32  retry counter
    // loop at 0x0063 — hammers CLR bit89h (RMW on TCON) while T1 counts to overflow
    // With 32 iters × 2 cycles × 12 clocks = 768 clocks >> 192 clocks to overflow
    wb(8'hC2); wb(8'h89);               // 0x0063: CLR bit89h  (RMW — collision point)
    wb(8'hD8); wb(8'hFC);               // 0x0065: DJNZ R0,-4 → 0x0063
    // EA=0 window ends — if TF1 survived all the RMWs, ISR fires when EA=1
    wb(8'hD2); wb(8'hAF);               // 0x0068: SETB bitAFh  EA=1
    // 8 NOPs — time for ISR to push PC, execute, RETI
    wb(8'h00); wb(8'h00); wb(8'h00); wb(8'h00);
    wb(8'h00); wb(8'h00); wb(8'h00); wb(8'h00);
    // Check sentinel
    wb(8'hE5); wb(8'h50);               // 0x0072: MOV A,iram[0x50]
    check(8'hA5, 8'h37);                // PASS if 0xA5, FAIL=0x37 (TF1 wiped by RMW)

    run_test("34_TF1_SURVIVES_TCON_RMW", 5000);

    // =========================================================================
    // Test 35: TF1 survives full-byte MOV TCON,#val racing with T1 overflow
    //
    //  The DME firmware at 0x1F43 executes MOV TCON,#0x05 which writes the
    //  whole TCON register.  If T1 overflows on the same clock cycle, the
    //  hardware-set TF1 must be preserved in the written value.
    //
    //  Unlike test 34 (CLR bit RMW), this is a direct full-register write.
    //  The fix ORs t1_overflow_now into the value written to TCON.
    //
    //  Strategy:
    //    - ET1=1, EA=0, T1 running, close to overflow
    //    - Loop hammering MOV TCON,#0x55 (TR1=1, keeps timer running,
    //      but TF1 bit written as 0) until T1 overflows during a write
    //    - SETB EA: ISR fires if TF1 was preserved despite the write
    //    - PASS if iram[0x51]==0xA5, FAIL=0x38
    //
    //  Memory layout:
    //    0x0000: LJMP 0x0050
    //    0x001B: T1 ISR — MOV iram[0x51],#0xA5 ; RETI
    //    0x0050: Main body
    // =========================================================================
    clear_rom;
    // 0x0000: LJMP 0x0050
    wb(8'h02); wb(8'h00); wb(8'h50);

    // --- T1 ISR at 0x001B ---
    rom[16'h001B] = 8'h75;   // MOV iram[0x51],#0xA5
    rom[16'h001C] = 8'h51;
    rom[16'h001D] = 8'hA5;
    rom[16'h001E] = 8'h32;   // RETI

    // --- Main at 0x0050 ---
    rp = 16'h0050;
    wb(8'h75); wb(8'h89); wb(8'h11);   // MOV TMOD,#0x11  T1 mode 1 (16-bit)
    wb(8'h75); wb(8'h8D); wb(8'hFF);   // MOV TH1,#0xFF
    wb(8'h75); wb(8'h8B); wb(8'hF0);   // MOV TL1,#0xF0  → 16 ticks to overflow
    wb(8'h75); wb(8'h51); wb(8'h00);   // MOV iram[0x51],#0x00  clear sentinel
    wb(8'h75); wb(8'hA8); wb(8'h08);   // MOV IE,#0x08  ET1=1, EA=0
    // Start T1 via TCON write with TR1=1 (0x55 = IT1=1,TR1=1,IT0=1)
    wb(8'h75); wb(8'h88); wb(8'h55);   // MOV TCON,#0x55  start T1
    wb(8'h78); wb(8'h20);               // MOV R0,#32  loop counter
    // Loop: hammer MOV TCON,#0x55 — TR1=1 kept running, TF1 written as 0
    // each iteration: 2 cycles = 24 osc clocks; 32× = 768 >> 192 to overflow
    wb(8'h75); wb(8'h88); wb(8'h55);   // MOV TCON,#0x55  (collision point)
    wb(8'hD8); wb(8'hFC);               // DJNZ R0,-4
    // Re-enable EA — TF1 should have survived one of the TCON writes
    wb(8'hD2); wb(8'hAF);               // SETB EA
    wb(8'h00); wb(8'h00); wb(8'h00); wb(8'h00);
    wb(8'h00); wb(8'h00); wb(8'h00); wb(8'h00);
    wb(8'hE5); wb(8'h51);               // MOV A,iram[0x51]
    check(8'hA5, 8'h38);                // PASS=0xA5, FAIL=0x38

    run_test("35_TF1_SURVIVES_TCON_FULL_WRITE", 5000);

    // =========================================================================
    // Test 36: TF1 survives ORL TCON,#imm racing with T1 overflow
    //
    //  This is the exact DME firmware scenario that caused the P1.4/ISV
    //  watchdog deadlock: ORL TCON,#0x05 at ROM address 0x1F43. Unlike test 35
    //  (a single-cycle full-byte MOV TCON write), ORL/ANL/XRL direct,#imm are
    //  TWO-cycle read-modify-write instructions — cycle 1 latches the current
    //  byte into tmp1, cycle 2 writes back tmp1 | imm one machine cycle later.
    //  If T1 overflows in that one-cycle gap, the write-back's tmp1 snapshot
    //  predates the hardware-set TF1, so the write-back silently discards it
    //  before the interrupt arbiter (checked only at instruction boundaries)
    //  ever sees it — even though ORL never intends to touch bit 7.
    //
    //  Fix: for ORL/ANL/XRL direct,#imm, the write-back re-reads TCON live
    //  (via direct_read(), which OR's in a same-cycle overflow) instead of the
    //  stale tmp1 snapshot, whenever the target address is TCON (0x88).
    //
    //  Strategy: 32 loop iterations hammering ORL TCON,#0x05, each iteration
    //  2-cycle RMW + 2-cycle DJNZ = 4 machine cycles (comfortably longer than
    //  the whole test needs to run). The timer reload is chosen so the
    //  overflow's machine-cycle phase actually lands inside an ORL's own
    //  read→write-back gap: a reload that is a multiple of the 4-machine-
    //  cycle loop period (e.g. 16 ticks, as in test 35) keeps the SAME phase
    //  on every pass through the loop and can systematically miss the gap
    //  entirely — this was verified empirically (16 ticks never reproduces
    //  the race here; 19 ticks reliably does, confirmed to FAIL on the
    //  pre-fix core and PASS on the fixed core).
    //
    //  PASS if iram[0x52]==0xA5, FAIL=0x39.
    //
    //  Memory layout:
    //    0x0000: LJMP 0x0050
    //    0x001B: T1 ISR — MOV iram[0x52],#0xA5 ; RETI
    //    0x0050: Main body
    // =========================================================================
    clear_rom;
    // 0x0000: LJMP 0x0050
    wb(8'h02); wb(8'h00); wb(8'h50);

    // --- T1 ISR at 0x001B ---
    rom[16'h001B] = 8'h75;   // MOV iram[0x52],#0xA5
    rom[16'h001C] = 8'h52;
    rom[16'h001D] = 8'hA5;
    rom[16'h001E] = 8'h32;   // RETI

    // --- Main at 0x0050 ---
    rp = 16'h0050;
    wb(8'h75); wb(8'h89); wb(8'h11);   // MOV TMOD,#0x11  T1 mode 1 (16-bit)
    wb(8'h75); wb(8'h8D); wb(8'hFF);   // MOV TH1,#0xFF
    wb(8'h75); wb(8'h8B); wb(8'hED);   // MOV TL1,#0xED  → 19 ticks to overflow
    wb(8'h75); wb(8'h52); wb(8'h00);   // MOV iram[0x52],#0x00  clear sentinel
    wb(8'h75); wb(8'hA8); wb(8'h08);   // MOV IE,#0x08  ET1=1, EA=0
    wb(8'hD2); wb(8'h8E);               // SETB TR1  start T1
    wb(8'h78); wb(8'h20);               // MOV R0,#32  loop counter
    // Loop: hammer ORL TCON,#0x05 — the exact DME instruction (0x1F43).
    // TR1 is preserved via the OR against tmp1's bit6 (imm doesn't set it),
    // so T1 keeps counting; each iteration: ORL(2-cyc)+DJNZ(2-cyc) = 4
    // machine cycles = 48 osc clocks; 32× = 1536, comfortably more than
    // needed to reach the 19-tick (228-osc-clock) overflow point.
    // Loop body is 5 bytes (3-byte ORL + 2-byte DJNZ); DJNZ's relative
    // offset is taken from the PC immediately after its own 2 bytes, so
    // the branch-back offset is -5, not -3 (that would land mid-opcode).
    wb(8'h43); wb(8'h88); wb(8'h05);   // ORL TCON,#0x05  (collision point)
    wb(8'hD8); wb(8'hFB);               // DJNZ R0,-5
    // Re-enable EA — TF1 should have survived one of the ORL write-backs
    wb(8'hD2); wb(8'hAF);               // SETB EA
    wb(8'h00); wb(8'h00); wb(8'h00); wb(8'h00);
    wb(8'h00); wb(8'h00); wb(8'h00); wb(8'h00);
    wb(8'hE5); wb(8'h52);               // MOV A,iram[0x52]
    check(8'hA5, 8'h39);                // PASS=0xA5, FAIL=0x39

    run_test("36_TF1_SURVIVES_TCON_ORL_RMW", 5000);

    // =========================================================================
    // UART TESTS (37-46)
    //   SCON 98h: SM0 SM1 SM2 REN TB8 RB8 TI RI; SBUF 99h; PCON 87h (SMOD=bit7)
    //   Mode 2: 9-bit, bit time 64 oscillator clocks (32 with SMOD).
    //   Mode 1 / 3: 8-bit / 9-bit, bit time 32 (16 with SMOD) Timer-1
    //   overflows. The DME runs mode 2 (SCON=90h, then B0h).
    //   Each program reports PASS through A as usual; the TX tests also
    //   check the frame the monitor decoded off TXD (a second PASS/FAIL line).
    // =========================================================================

    // TEST 37: mode 2 TX, TB8=1: frame A5 + 9th bit 1, 64-clock bits
    //   A5 = 1010_0101, LSB first: D0=1, so TXD rises one bit after the start
    clear_rom;
    wb(8'h75); wb(8'h98); wb(8'h88);   // MOV SCON,#88h  mode 2, TB8=1
    wb(8'h75); wb(8'h99); wb(8'hA5);   // MOV SBUF,#A5h
    wb(8'h30); wb(8'h99); wb(8'hFD);   // JNB TI,$
    wb(8'h74); wb(8'h00);              // MOV A,#0
    check(8'h00, 8'h37);
    mon_start(64, 11);
    run_test("37_UART_M2_TX", 3000);
    mon_check("37_UART_M2_TX_FRAME_64CLK", {1'b1, 1'b1, 8'hA5, 1'b0}, 64);

    // TEST 38: mode 2 TX with SMOD=1, TB8=0: frame 3C + 9th bit 0, 32-clock bits
    //   3C = 0011_1100: D0=D1=0, so TXD rises three bits after the start
    clear_rom;
    wb(8'h75); wb(8'h87); wb(8'h80);   // MOV PCON,#80h  SMOD=1
    wb(8'h75); wb(8'h98); wb(8'h80);   // MOV SCON,#80h  mode 2, TB8=0
    wb(8'h75); wb(8'h99); wb(8'h3C);   // MOV SBUF,#3Ch
    wb(8'h30); wb(8'h99); wb(8'hFD);   // JNB TI,$
    wb(8'h74); wb(8'h00);              // MOV A,#0
    check(8'h00, 8'h38);
    mon_start(32, 11);
    run_test("38_UART_M2_TX_SMOD", 3000);
    mon_check("38_UART_M2_TX_SMOD_FRAME_32CLK", {1'b1, 1'b0, 8'h3C, 1'b0}, 96);

    // TEST 39: mode 2 RX: 5A with 9th bit 1 → RI=1, RB8=1, SBUF=5A
    //   (A is checked against SCON & 05h first, then SBUF)
    clear_rom;
    wb(8'h75); wb(8'h98); wb(8'h90);   // MOV SCON,#90h  mode 2, REN=1
    wb(8'h30); wb(8'h98); wb(8'hFD);   // JNB RI,$
    wb(8'hE5); wb(8'h98);              // MOV A,SCON
    wb(8'h54); wb(8'h05);              // ANL A,#05h  RB8 | RI
    wb(8'hB4); wb(8'h05); wb(8'h0F);   // CJNE A,#05h,fail (past MOV A,SBUF + check)
    wb(8'hE5); wb(8'h99);              // MOV A,SBUF
    check(8'h5A, 8'h39);
    wb(8'h74); wb(8'h3A);              // fail: MOV A,#3Ah  (RI/RB8 wrong)
    wb(8'h02); wb(8'h01); wb(8'h00);   // LJMP tail
    fork
        run_test("39_UART_M2_RX_RB8", 4000);
        begin repeat (300) @(posedge clk); uart_send(8'h5A, 1'b1, 1'b1, 64); end
    join

    // TEST 40: mode 2 RX with SMOD=1: 96 at 32-clock bits
    clear_rom;
    wb(8'h75); wb(8'h87); wb(8'h80);   // MOV PCON,#80h  SMOD=1
    wb(8'h75); wb(8'h98); wb(8'h90);   // MOV SCON,#90h
    wb(8'h30); wb(8'h98); wb(8'hFD);   // JNB RI,$
    wb(8'hE5); wb(8'h99);              // MOV A,SBUF
    check(8'h96, 8'h40);
    fork
        run_test("40_UART_M2_RX_SMOD", 3000);
        begin repeat (300) @(posedge clk); uart_send(8'h96, 1'b0, 1'b1, 32); end
    join

    // TEST 41: mode 2 RX, SM2=1 (multiprocessor, the DME's SCON=B0h):
    //   a frame with 9th bit 0 sets no RI; the next, with 9th bit 1, does
    clear_rom;
    wb(8'h75); wb(8'h98); wb(8'hB0);   // MOV SCON,#B0h  mode 2, SM2=1, REN=1
    wb(8'h30); wb(8'h98); wb(8'hFD);   // JNB RI,$
    wb(8'hE5); wb(8'h99);              // MOV A,SBUF
    check(8'h22, 8'h41);
    fork
        run_test("41_UART_M2_RX_SM2_FILTER", 6000);
        begin
            repeat (300) @(posedge clk); uart_send(8'h11, 1'b0, 1'b1, 64);
            repeat (100) @(posedge clk); uart_send(8'h22, 1'b1, 1'b1, 64);
        end
    join

    // TEST 42: REN=0: a frame on RXD sets no RI
    //   (waits ~1900 clocks, longer than the frame, then reads SCON.RI)
    clear_rom;
    wb(8'h75); wb(8'h98); wb(8'h80);   // MOV SCON,#80h  mode 2, REN=0
    wb(8'h7F); wb(8'h50);              // MOV R7,#80
    wb(8'hDF); wb(8'hFE);              // DJNZ R7,$   (80 x 24 clocks)
    wb(8'hE5); wb(8'h98);              // MOV A,SCON
    wb(8'h54); wb(8'h01);              // ANL A,#01h  RI
    check(8'h00, 8'h42);
    fork
        run_test("42_UART_RX_REN_OFF", 4000);
        begin repeat (100) @(posedge clk); uart_send(8'hC3, 1'b1, 1'b1, 64); end
    join

    // TEST 43: RI stays set until software clears it: a second frame while
    //   RI=1 is not loaded (SBUF keeps the first byte)
    clear_rom;
    wb(8'h75); wb(8'h98); wb(8'h90);   // MOV SCON,#90h
    wb(8'h30); wb(8'h98); wb(8'hFD);   // JNB RI,$
    wb(8'h7F); wb(8'h40);              // MOV R7,#64
    wb(8'hDF); wb(8'hFE);              // DJNZ R7,$   (wait out the 2nd frame)
    wb(8'hE5); wb(8'h99);              // MOV A,SBUF
    check(8'h81, 8'h43);
    fork
        run_test("43_UART_RX_OVERRUN_KEEPS_SBUF", 6000);
        begin
            repeat (300) @(posedge clk); uart_send(8'h81, 1'b0, 1'b1, 64);
            uart_send(8'h7E, 1'b0, 1'b1, 64);
        end
    join

    // TEST 44: mode 1 TX, Timer 1 mode 2 (auto-reload TH1=FEh: an overflow
    //   every 2 machine cycles = 24 clocks), SMOD=0: 32 overflows per bit
    //   = 768 clocks. 10-bit frame: start, 4D, stop. 4D = 0100_1101: D0=1.
    clear_rom;
    wb(8'h75); wb(8'h89); wb(8'h20);   // MOV TMOD,#20h  T1 mode 2
    wb(8'h75); wb(8'h8D); wb(8'hFE);   // MOV TH1,#FEh
    wb(8'h75); wb(8'h8B); wb(8'hFE);   // MOV TL1,#FEh
    wb(8'hD2); wb(8'h8E);              // SETB TR1
    wb(8'h75); wb(8'h98); wb(8'h40);   // MOV SCON,#40h  mode 1
    wb(8'h75); wb(8'h99); wb(8'h4D);   // MOV SBUF,#4Dh
    wb(8'h30); wb(8'h99); wb(8'hFD);   // JNB TI,$
    wb(8'h74); wb(8'h00);              // MOV A,#0
    check(8'h00, 8'h44);
    mon_start(768, 10);
    run_test("44_UART_M1_TX_T1", 12000);
    mon_check("44_UART_M1_TX_T1_FRAME_768CLK", {1'b0, 1'b1, 8'h4D, 1'b0}, 768);

    // TEST 45: mode 1 RX, same Timer 1 setup with SMOD=1: 16 overflows per
    //   bit = 384 clocks
    clear_rom;
    wb(8'h75); wb(8'h89); wb(8'h20);   // MOV TMOD,#20h
    wb(8'h75); wb(8'h8D); wb(8'hFE);   // MOV TH1,#FEh
    wb(8'h75); wb(8'h8B); wb(8'hFE);   // MOV TL1,#FEh
    wb(8'h75); wb(8'h87); wb(8'h80);   // MOV PCON,#80h  SMOD=1
    wb(8'hD2); wb(8'h8E);              // SETB TR1
    wb(8'h75); wb(8'h98); wb(8'h50);   // MOV SCON,#50h  mode 1, REN=1
    wb(8'h30); wb(8'h98); wb(8'hFD);   // JNB RI,$
    wb(8'hE5); wb(8'h99);              // MOV A,SBUF
    check(8'hB2, 8'h45);
    fork
        run_test("45_UART_M1_RX_T1_SMOD", 8000);
        begin repeat (400) @(posedge clk); uart_send(8'hB2, 1'b0, 1'b0, 384); end
    join

    // TEST 46: mode 3 TX (9-bit, Timer 1), TB8=1, SMOD=1, TH1=FFh: an
    //   overflow every machine cycle = 12 clocks, 16 per bit = 192 clocks
    //   E1 = 1110_0001: D0=1
    clear_rom;
    wb(8'h75); wb(8'h89); wb(8'h20);   // MOV TMOD,#20h
    wb(8'h75); wb(8'h8D); wb(8'hFF);   // MOV TH1,#FFh
    wb(8'h75); wb(8'h8B); wb(8'hFF);   // MOV TL1,#FFh
    wb(8'h75); wb(8'h87); wb(8'h80);   // MOV PCON,#80h
    wb(8'hD2); wb(8'h8E);              // SETB TR1
    wb(8'h75); wb(8'h98); wb(8'hC8);   // MOV SCON,#C8h  mode 3, TB8=1
    wb(8'h75); wb(8'h99); wb(8'hE1);   // MOV SBUF,#E1h
    wb(8'h30); wb(8'h99); wb(8'hFD);   // JNB TI,$
    wb(8'h74); wb(8'h00);              // MOV A,#0
    check(8'h00, 8'h46);
    mon_start(192, 11);
    run_test("46_UART_M3_TX_T1", 5000);
    mon_check("46_UART_M3_TX_T1_FRAME_192CLK", {1'b1, 1'b1, 8'hE1, 1'b0}, 192);

    // =========================================================================
    // Final summary
    // =========================================================================
    #200;
    $display("");
    $display("======================================");
    $display(" Regression complete: %0d PASSED, %0d FAILED",
             pass_count, fail_count);
    $display("======================================");
    if (fail_count == 0)
        $display(" ALL TESTS PASSED");
    else
        $display(" *** %0d TEST(S) FAILED ***", fail_count);
    $display("======================================\n");

    $finish;
end

endmodule
