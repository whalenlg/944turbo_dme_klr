//////////////////////////////////////////////////////////////////////
////                                                              ////
////  oc8051_regression_tb.v                                      ////
////                                                              ////
////  Self-checking regression testbench for OpenCores oc8051    ////
////  Exercises the 8051 instruction set independently of any    ////
////  application ROM.  Pass/fail signaled by writing 0x7F       ////
////  (pass) or an error code (fail) to external data address    ////
////  0x0010, matching the convention of the DME testbench.      ////
////                                                              ////
////  Compatible with: iverilog / vvp                            ////
////  Usage:                                                      ////
////    iverilog -o sim oc8051_regression_tb.v \                  ////
////             oc8051_top.v [all other oc8051 source files]     ////
////    vvp sim                                                   ////
////                                                              ////
////  Waveform output: oc8051_regression.vcd                     ////
////                                                              ////
////  Tests included (30 total):                                  ////
////   01  MOV_IMM_ADD_R    MOV immediate + ADD register          ////
////   02  ADDC_IMM         Add with carry                        ////
////   03  SUBB_IMM         Subtract with borrow                  ////
////   04  MUL_AB           Multiply A*B                          ////
////   05  DIV_AB           Divide A/B                            ////
////   06  INC_DEC_A        Increment / Decrement accumulator     ////
////   07  ANL_IMM          AND immediate                         ////
////   08  ORL_IMM          OR immediate                          ////
////   09  XRL_IMM          XOR immediate                         ////
////   10  CPL_A            Complement accumulator                ////
////   11  RL_A             Rotate left                           ////
////   12  RR_A             Rotate right                          ////
////   13  RLC_A            Rotate left through carry             ////
////   14  SWAP_A           Swap nibbles                          ////
////   15  DA_A             Decimal adjust                        ////
////   16  SJMP_FWD         Short jump forward                    ////
////   17  LJMP             Long jump                             ////
////   18  JC_JNC           Carry branch instructions             ////
////   19  JZ_JNZ           Zero branch instructions              ////
////   20  JB_JNB           Bit branch instructions               ////
////   21  DJNZ_R0          Decrement & jump loop                 ////
////   22  PUSH_POP_ACC     Stack push/pop                        ////
////   23  MOVX_DPTR        External RAM read/write via DPTR      ////
////   24  LCALL_RET        Subroutine call and return            ////
////   25  MOV_DIRECT       Direct address MOV                    ////
////   26  MOV_INDIRECT     Indirect address MOV (@R0)            ////
////   27  INC_DPTR         Increment data pointer                ////
////   28  MOVC_DPTR        Code memory read (MOVC @A+DPTR)       ////
////   29  CJNE_DIRECT      Compare & jump, direct operand        ////
////   30  MOV_REG_DIRECT   MOV register to/from direct address   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
`include "oc8051_defines.v"

module oc8051_regression_tb;

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
parameter CLK_HALF = 10;          // 10 ns half-period = 50 MHz

// ---------------------------------------------------------------------------
// Clock and Reset
// ---------------------------------------------------------------------------
reg wb_clk_i;
reg wb_rst_i;

initial  wb_clk_i = 1'b0;
always #(CLK_HALF) wb_clk_i = ~wb_clk_i;

// ---------------------------------------------------------------------------
// Instruction Wishbone bus (CPU → ROM)
// ---------------------------------------------------------------------------
wire [15:0] wbi_adr_o;   // instruction address from CPU
reg  [31:0] wbi_dat_i;   // 32-bit instruction word to CPU
wire        wbi_stb_o;
wire        wbi_cyc_o;
reg         wbi_ack_i;
wire        wbi_err_i;

assign wbi_err_i = 1'b0;

// ---------------------------------------------------------------------------
// Data Wishbone bus (CPU ↔ XRAM)
// ---------------------------------------------------------------------------
wire [15:0] wbd_adr_o;
wire [7:0]  wbd_dat_o;   // CPU writes this to XRAM
reg  [7:0]  wbd_dat_i;   // XRAM returns this to CPU
wire        wbd_we_o;
wire        wbd_stb_o;
wire        wbd_cyc_o;
reg         wbd_ack_i;
wire        wbd_err_i;

assign wbd_err_i = 1'b0;

// ---------------------------------------------------------------------------
// Port I/O, UART, timers (tie-offs)
// ---------------------------------------------------------------------------
wire [7:0] p0_o, p1_o, p2_o, p3_o;
wire       txd_o;

// ---------------------------------------------------------------------------
// ROM and XRAM storage
// ---------------------------------------------------------------------------
reg [7:0] rom  [0:65535];   // instruction ROM
reg [7:0] xram [0:65535];   // external data RAM

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------
reg         test_done;
reg  [7:0]  test_result;
integer     pass_count;
integer     fail_count;
integer     rp;             // ROM write pointer

// ---------------------------------------------------------------------------
// Instruction Wishbone ROM model
//   Registered, 1-cycle ACK.  Packs bytes little-endian to match oc8051_xrom:
//   wbi_dat_i[7:0]   = rom[addr+0]  (byte at wbi_adr_o+0)
//   wbi_dat_i[15:8]  = rom[addr+1]
//   wbi_dat_i[23:16] = rom[addr+2]
//   wbi_dat_i[31:24] = rom[addr+3]
// ---------------------------------------------------------------------------
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wbi_dat_i <= 32'h0000_0000;
        wbi_ack_i <= 1'b0;
    end else if (wbi_stb_o && wbi_cyc_o) begin
        wbi_dat_i <= { rom[wbi_adr_o + 16'd3],
                       rom[wbi_adr_o + 16'd2],
                       rom[wbi_adr_o + 16'd1],
                       rom[wbi_adr_o         ] };
        wbi_ack_i <= 1'b1;
    end else begin
        wbi_ack_i <= 1'b0;
    end
end

// ---------------------------------------------------------------------------
// Data Wishbone XRAM model
//   Registered, 1-cycle ACK.  Handles both reads and writes.
// ---------------------------------------------------------------------------
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wbd_dat_i <= 8'h00;
        wbd_ack_i <= 1'b0;
    end else if (wbd_stb_o && wbd_cyc_o) begin
        if (wbd_we_o)
            xram[wbd_adr_o] <= wbd_dat_o;
        else
            wbd_dat_i <= xram[wbd_adr_o];
        wbd_ack_i <= 1'b1;
    end else begin
        wbd_ack_i <= 1'b0;
    end
end

// ---------------------------------------------------------------------------
// Test completion monitor
//   A write to external address 0x0010 signals test completion.
//   The written value is the result (0x7F = PASS, anything else = FAIL).
//   Resets to idle on wb_rst_i so each test starts fresh.
// ---------------------------------------------------------------------------
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        test_done   <= 1'b0;
        test_result <= 8'hFF;
    end else if (wbd_stb_o && wbd_cyc_o && wbd_we_o &&
                 (wbd_adr_o == 16'h0010)) begin
        test_done   <= 1'b1;
        test_result <= wbd_dat_o;
    end
end

// ---------------------------------------------------------------------------
// DUT: oc8051_top
// ---------------------------------------------------------------------------
oc8051_top dut (
    // Clock and reset
    .wb_rst_i   (wb_rst_i),
    .wb_clk_i   (wb_clk_i),

    // Instruction bus
    .wbi_adr_o  (wbi_adr_o),
    .wbi_dat_i  (wbi_dat_i),
    .wbi_stb_o  (wbi_stb_o),
    .wbi_cyc_o  (wbi_cyc_o),
    .wbi_ack_i  (wbi_ack_i),
    .wbi_err_i  (wbi_err_i),

    // Data bus
    .wbd_dat_i  (wbd_dat_i),
    .wbd_dat_o  (wbd_dat_o),
    .wbd_adr_o  (wbd_adr_o),
    .wbd_we_o   (wbd_we_o),
    .wbd_stb_o  (wbd_stb_o),
    .wbd_cyc_o  (wbd_cyc_o),
    .wbd_ack_i  (wbd_ack_i),
    .wbd_err_i  (wbd_err_i),

    // External interrupts (active-low, tied inactive)
    .int0_i     (1'b1),
    .int1_i     (1'b1),

    // Port I/O (open-drain default: all inputs high)
    .p0_i       (8'hFF),   .p0_o (p0_o),
    .p1_i       (8'hFF),   .p1_o (p1_o),
    .p2_i       (8'hFF),   .p2_o (p2_o),
    .p3_i       (8'hFF),   .p3_o (p3_o),

    // UART (loopback idle)
    .rxd_i      (1'b1),
    .txd_o      (txd_o),

    // Timer/counter external inputs (no external events)
    .t0_i       (1'b0),
    .t1_i       (1'b0),
    .t2_i       (1'b0),
    .t2ex_i     (1'b0),

    // ea_in = 0 → force all fetches to external (Wishbone) ROM
    .ea_in      (1'b0)
);

// ===========================================================================
// TASK LIBRARY
// ===========================================================================

// ---------------------------------------------------------------------------
// clear_rom: fill ROM with NOPs (0x00) and install the standard tail routine
//
// Tail at 0x0100:
//   0x0100: 90 00 10   MOV DPTR, #0x0010
//   0x0103: F0         MOVX @DPTR, A        ← writes A to monitor address
//   0x0104: 80 FE      SJMP $               ← spin (SJMP -2)
//
// Every test program jumps here (via LJMP 0x0100 = 02 01 00) to report its
// result.  A=0x7F means PASS; any other value is a per-test error code.
// ---------------------------------------------------------------------------
task clear_rom;
    integer i;
    begin
        for (i = 0; i < 65536; i = i+1)
            rom[i] = 8'h00;   // 0x00 = NOP on 8051
        rp = 0;

        // Tail routine
        rom[16'h0100] = 8'h90;   // MOV DPTR, #imm16 opcode
        rom[16'h0101] = 8'h00;   //   high byte of 0x0010
        rom[16'h0102] = 8'h10;   //   low  byte of 0x0010
        rom[16'h0103] = 8'hF0;   // MOVX @DPTR, A
        rom[16'h0104] = 8'h80;   // SJMP opcode
        rom[16'h0105] = 8'hFE;   //   offset -2 → infinite spin
    end
endtask

// ---------------------------------------------------------------------------
// wb: write one byte to ROM at the current write pointer, then advance it
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
// Encoding (13 bytes total):
//   B4 expected 05   CJNE A,#expected,+5   → fall-through if equal (PASS)
//   74 7F            MOV  A, #0x7F         ← PASS path
//   02 01 00         LJMP 0x0100
//   74 errcode       MOV  A, #errcode      ← FAIL path (jumped from CJNE)
//   02 01 00         LJMP 0x0100
//
// CJNE offset calculation:
//   Instruction at X, 3 bytes → PC after = X+3
//   Fail path starts at X+8
//   Offset = (X+8) - (X+3) = 5   ✓
// ---------------------------------------------------------------------------
task check;
    input [7:0] expected;
    input [7:0] errcode;
    begin
        wb(8'hB4); wb(expected); wb(8'h05); // CJNE A,#expected,+5
        wb(8'h74); wb(8'h7F);               // MOV A,#0x7F  (PASS)
        wb(8'h02); wb(8'h01); wb(8'h00);    // LJMP 0x0100
        wb(8'h74); wb(errcode);             // MOV A,#errcode  (FAIL)
        wb(8'h02); wb(8'h01); wb(8'h00);    // LJMP 0x0100
    end
endtask

// ---------------------------------------------------------------------------
// run_test: reset the DUT, execute until the monitor fires or timeout
// ---------------------------------------------------------------------------
task run_test;
    input [255:0] tname;       // test name (up to 32 ASCII chars)
    input integer max_cycles;
    integer timeout;
    begin
        // Assert reset (at least 4 clock edges)
        wb_rst_i = 1'b1;
        repeat(4) @(posedge wb_clk_i);
        @(negedge wb_clk_i);
        wb_rst_i = 1'b0;

        // Poll for completion or timeout
        timeout = 0;
        while (!test_done && timeout < max_cycles) begin
            @(posedge wb_clk_i);
            timeout = timeout + 1;
        end

        // Evaluate result
        if (!test_done) begin
            $display("TIMEOUT  [%0s]  (%0d cycles)", tname, max_cycles);
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
    $dumpfile("oc8051_regression.vcd");
    $dumpvars(0, oc8051_regression_tb);

    // Initialise counters
    pass_count = 0;
    fail_count = 0;

    // Hold reset while initialization completes
    wb_rst_i = 1'b1;
    repeat(4) @(posedge wb_clk_i);

    $display("\n=== oc8051 Regression Testbench ===\n");

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
    run_test("01_MOV_IMM_ADD_R", 500);

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
    run_test("02_ADDC_IMM", 500);

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
    run_test("03_SUBB_IMM", 500);

    // =========================================================================
    // TEST 04: MUL AB
    //   MOV A,#0x0A        74 0A
    //   MOV B,#0x07        75 F0 07  (MOV direct,#imm; B=0xF0)
    //   MUL AB             A4
    //   Result: A = 0x46 (low byte of 70), B = 0x00 (high byte)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h0A);           // MOV A,#10
    wb(8'h75); wb(8'hF0); wb(8'h07);// MOV B,#7   (B sfr = 0xF0)
    wb(8'hA4);                       // MUL AB
    check(8'h46, 8'h04);            // 10*7 = 70 = 0x46
    run_test("04_MUL_AB", 1000);

    // =========================================================================
    // TEST 05: DIV AB
    //   MOV A,#0x63  (99)   74 63
    //   MOV B,#0x0A  (10)   75 F0 0A
    //   DIV AB              84
    //   Result: A = 9 (0x09 quotient), B = 9 (0x09 remainder)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h63);           // MOV A,#99
    wb(8'h75); wb(8'hF0); wb(8'h0A);// MOV B,#10
    wb(8'h84);                       // DIV AB
    check(8'h09, 8'h05);            // 99/10 = 9 remainder 9; check quotient
    run_test("05_DIV_AB", 1000);

    // =========================================================================
    // TEST 06: INC A / DEC A
    //   MOV A,#0xFF        74 FF
    //   INC A              04    → 0x00 (wraps)
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
    run_test("06_INC_DEC_A", 500);

    // =========================================================================
    // TEST 07: ANL A,#imm
    //   MOV A,#0xAA        74 AA
    //   ANL A,#0x0F        54 0F    → 0xAA & 0x0F = 0x0A
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAA);           // MOV A,#0xAA
    wb(8'h54); wb(8'h0F);           // ANL A,#0x0F
    check(8'h0A, 8'h07);
    run_test("07_ANL_IMM", 500);

    // =========================================================================
    // TEST 08: ORL A,#imm
    //   MOV A,#0xA0        74 A0
    //   ORL A,#0x0B        44 0B    → 0xA0 | 0x0B = 0xAB
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hA0);           // MOV A,#0xA0
    wb(8'h44); wb(8'h0B);           // ORL A,#0x0B
    check(8'hAB, 8'h08);
    run_test("08_ORL_IMM", 500);

    // =========================================================================
    // TEST 09: XRL A,#imm
    //   MOV A,#0xFF        74 FF
    //   XRL A,#0x0F        64 0F    → 0xFF ^ 0x0F = 0xF0
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hFF);           // MOV A,#0xFF
    wb(8'h64); wb(8'h0F);           // XRL A,#0x0F
    check(8'hF0, 8'h09);
    run_test("09_XRL_IMM", 500);

    // =========================================================================
    // TEST 10: CPL A (complement accumulator)
    //   MOV A,#0xAA        74 AA
    //   CPL A              F4       → ~0xAA = 0x55
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAA);           // MOV A,#0xAA
    wb(8'hF4);                       // CPL A
    check(8'h55, 8'h0A);
    run_test("10_CPL_A", 500);

    // =========================================================================
    // TEST 11: RL A (rotate left, no carry)
    //   MOV A,#0x81        74 81    binary: 1000_0001
    //   RL  A              23       → 0000_0011 = 0x03
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h81);           // MOV A,#0x81
    wb(8'h23);                       // RL A
    check(8'h03, 8'h0B);
    run_test("11_RL_A", 500);

    // =========================================================================
    // TEST 12: RR A (rotate right, no carry)
    //   MOV A,#0x81        74 81    binary: 1000_0001
    //   RR  A              03       → 1100_0000 = 0xC0  (bit0 wraps to bit7)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h81);           // MOV A,#0x81
    wb(8'h03);                       // RR A
    check(8'hC0, 8'h0C);
    run_test("12_RR_A", 500);

    // =========================================================================
    // TEST 13: RLC A (rotate left through carry)
    //   CLR C              C3
    //   MOV A,#0x80        74 80    binary: 1000_0000
    //   RLC A              33       → A = 0x00 (bit7 → carry), C = 1
    //
    //   Verification:
    //     Check A == 0x00, then JC to confirm carry was set.
    //
    //   Layout (X = current rp after preceding instructions):
    //     X+0:  B4 00 0C  CJNE A,#0x00,+12  → fail_a at X+15
    //     X+3:  40 05     JC   +5           → pass at X+10
    //     X+5:  74 0D     MOV A,#0x0D       (fail: carry not set)
    //     X+7:  02 01 00  LJMP 0x0100
    //     X+10: 74 7F     MOV A,#0x7F       (pass)
    //     X+12: 02 01 00  LJMP 0x0100
    //     X+15: 74 0D     MOV A,#0x0D       (fail: A wrong)
    //     X+17: 02 01 00  LJMP 0x0100
    // =========================================================================
    clear_rom;
    wb(8'hC3);                       // CLR C
    wb(8'h74); wb(8'h80);           // MOV A,#0x80
    wb(8'h33);                       // RLC A  → A=0x00, C=1
    // Check A
    wb(8'hB4); wb(8'h00); wb(8'h0C);// CJNE A,#0x00,+12 (→ fail_a)
    // Check carry
    wb(8'h40); wb(8'h05);           // JC +5 (→ pass)
    wb(8'h74); wb(8'h0D);           // MOV A,#0x0D (fail: carry wrong)
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // pass:
    wb(8'h74); wb(8'h7F);           // MOV A,#0x7F
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // fail_a:
    wb(8'h74); wb(8'h0D);           // MOV A,#0x0D
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    run_test("13_RLC_A", 500);

    // =========================================================================
    // TEST 14: SWAP A (swap accumulator nibbles)
    //   MOV A,#0xAB        74 AB
    //   SWAP A             C4       → 0xBA
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAB);           // MOV A,#0xAB
    wb(8'hC4);                       // SWAP A
    check(8'hBA, 8'h0E);
    run_test("14_SWAP_A", 500);

    // =========================================================================
    // TEST 15: DA A (decimal adjust after BCD addition)
    //   MOV A,#0x48        74 48      (BCD 48)
    //   ADD A,#0x28        24 28      → A=0x70, AC=1 (low nibble 8+8=16)
    //   DA  A              D4         → 0x70 + 0x06 = 0x76  (BCD 76)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h48);           // MOV A,#0x48
    wb(8'h24); wb(8'h28);           // ADD A,#0x28
    wb(8'hD4);                       // DA A
    check(8'h76, 8'h0F);
    run_test("15_DA_A", 500);

    // =========================================================================
    // TEST 16: SJMP forward (skips over poisoned MOV)
    //   MOV A,#0x05        74 05
    //   SJMP +2            80 02     → skip next 2 bytes
    //   MOV A,#0x00        74 00     ← SKIPPED (would corrupt A)
    //   check A == 0x05
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h05);           // MOV A,#0x05
    wb(8'h80); wb(8'h02);           // SJMP +2  (PC after = rp; target = rp+2)
    wb(8'h74); wb(8'h00);           // MOV A,#0x00  ← SKIPPED
    check(8'h05, 8'h10);
    run_test("16_SJMP_FWD", 500);

    // =========================================================================
    // TEST 17: LJMP (long jump, skips over 3-byte poison block)
    //   Layout:
    //     0x0000: 74 0A   MOV A,#0x0A
    //     0x0002: 02 00 09 LJMP 0x0009
    //     0x0005: 74 00   MOV A,#0x00  ← SKIPPED
    //     0x0007: 00      NOP          ← SKIPPED
    //     0x0008: 00      NOP          ← SKIPPED
    //     0x0009: check(0x0A, 0x11)
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'h0A);           // 0x0000: MOV A,#0x0A
    wb(8'h02); wb(8'h00); wb(8'h09);// 0x0002: LJMP 0x0009
    wb(8'h74); wb(8'h00);           // 0x0005: MOV A,#0x00  (skipped)
    wb(8'h00);                       // 0x0007: NOP          (skipped)
    wb(8'h00);                       // 0x0008: NOP          (skipped)
    // 0x0009:
    check(8'h0A, 8'h11);
    run_test("17_LJMP", 500);

    // =========================================================================
    // TEST 18: JC / JNC (carry branch instructions)
    //   Sequence:
    //     SETB C  → JC jumps over fail block → CLR C → JNC jumps to pass
    //
    //   Layout:
    //     0x0000: D3       SETB C
    //     0x0001: 40 05    JC +5   PC_after=0x0003 → target=0x0008
    //     0x0003: 74 12    MOV A,#0x12   (fail: JC did not branch)
    //     0x0005: 02 01 00 LJMP 0x0100
    //     0x0008: C3       CLR C
    //     0x0009: 50 05    JNC +5  PC_after=0x000B → target=0x0010
    //     0x000B: 74 12    MOV A,#0x12   (fail: JNC did not branch)
    //     0x000D: 02 01 00 LJMP 0x0100
    //     0x0010: 74 7F    MOV A,#0x7F   (pass)
    //     0x0012: 02 01 00 LJMP 0x0100
    // =========================================================================
    clear_rom;
    // 0x0000
    wb(8'hD3);                       // SETB C
    // 0x0001
    wb(8'h40); wb(8'h05);           // JC +5  → 0x0008
    // 0x0003
    wb(8'h74); wb(8'h12);           // fail
    // 0x0005
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // 0x0008
    wb(8'hC3);                       // CLR C
    // 0x0009
    wb(8'h50); wb(8'h05);           // JNC +5 → 0x0010
    // 0x000B
    wb(8'h74); wb(8'h12);           // fail
    // 0x000D
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // 0x0010
    wb(8'h74); wb(8'h7F);           // pass
    // 0x0012
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    run_test("18_JC_JNC", 500);

    // =========================================================================
    // TEST 19: JZ / JNZ (zero-flag branch instructions)
    //   Layout:
    //     0x0000: 74 00    MOV A,#0x00
    //     0x0002: 60 05    JZ +5    PC_after=0x0004 → target=0x0009
    //     0x0004: 74 13    MOV A,#0x13  (fail)
    //     0x0006: 02 01 00 LJMP 0x0100
    //     0x0009: 04       INC A    → 0x01
    //     0x000A: 70 05    JNZ +5   PC_after=0x000C → target=0x0011
    //     0x000C: 74 13    MOV A,#0x13  (fail)
    //     0x000E: 02 01 00 LJMP 0x0100
    //     0x0011: 74 7F    pass
    //     0x0013: 02 01 00 LJMP 0x0100
    // =========================================================================
    clear_rom;
    // 0x0000
    wb(8'h74); wb(8'h00);           // MOV A,#0x00
    // 0x0002
    wb(8'h60); wb(8'h05);           // JZ +5  → 0x0009
    // 0x0004
    wb(8'h74); wb(8'h13);           // fail
    // 0x0006
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // 0x0009
    wb(8'h04);                       // INC A → 0x01
    // 0x000A
    wb(8'h70); wb(8'h05);           // JNZ +5 → 0x0011
    // 0x000C
    wb(8'h74); wb(8'h13);           // fail
    // 0x000E
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // 0x0011
    wb(8'h74); wb(8'h7F);           // pass
    // 0x0013
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    run_test("19_JZ_JNZ", 500);

    // =========================================================================
    // TEST 20: JB / JNB (bit-test branch instructions)
    //   ACC bit-address: ACC SFR = 0xE0; bit 7 address = 0xE0+7 = 0xE7
    //
    //   Layout:
    //     0x0000: 74 80    MOV A,#0x80        (ACC.7 = 1)
    //     0x0002: 20 E7 05 JB  ACC.7,+5  PC_after=0x0005 → target=0x000A
    //     0x0005: 74 14    MOV A,#0x14  (fail: JB not taken)
    //     0x0007: 02 01 00 LJMP 0x0100
    //     0x000A: 74 7F    MOV A,#0x7F        (ACC.7 = 0)
    //     0x000C: 30 E7 05 JNB ACC.7,+5  PC_after=0x000F → target=0x0014
    //     0x000F: 74 14    MOV A,#0x14  (fail: JNB not taken)
    //     0x0011: 02 01 00 LJMP 0x0100
    //     0x0014: 74 7F    pass
    //     0x0016: 02 01 00 LJMP 0x0100
    // =========================================================================
    clear_rom;
    // 0x0000
    wb(8'h74); wb(8'h80);           // MOV A,#0x80  (ACC.7=1)
    // 0x0002
    wb(8'h20); wb(8'hE7); wb(8'h05);// JB ACC.7,+5 → 0x000A
    // 0x0005
    wb(8'h74); wb(8'h14);           // fail
    // 0x0007
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // 0x000A
    wb(8'h74); wb(8'h7F);           // MOV A,#0x7F  (ACC.7=0)
    // 0x000C
    wb(8'h30); wb(8'hE7); wb(8'h05);// JNB ACC.7,+5 → 0x0014
    // 0x000F
    wb(8'h74); wb(8'h14);           // fail
    // 0x0011
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    // 0x0014
    wb(8'h74); wb(8'h7F);           // pass
    // 0x0016
    wb(8'h02); wb(8'h01); wb(8'h00);// LJMP 0x0100
    run_test("20_JB_JNB", 500);

    // =========================================================================
    // TEST 21: DJNZ R0 (decrement and jump if not zero)
    //   MOV R0,#5    78 05
    //   MOV A,#0     74 00
    //   loop:
    //     INC A      04
    //     DJNZ R0,-3 D8 FD   (offset -3: PC_after=loop+3, target=loop → loop)
    //
    //   After 5 iterations A = 5.
    //
    //   Layout:
    //     0x0000: 78 05   MOV R0,#5
    //     0x0002: 74 00   MOV A,#0
    //     0x0004: 04      INC A          ← loop start
    //     0x0005: D8 FD   DJNZ R0,-3    PC_after=0x0007; target=0x0007+0xFD=0x0004 ✓
    //     0x0007: check(5, 0x15)
    // =========================================================================
    clear_rom;
    // 0x0000
    wb(8'h78); wb(8'h05);           // MOV R0,#5
    // 0x0002
    wb(8'h74); wb(8'h00);           // MOV A,#0
    // 0x0004  (loop start)
    wb(8'h04);                       // INC A
    // 0x0005
    wb(8'hD8); wb(8'hFD);           // DJNZ R0,-3  → back to 0x0004
    // 0x0007
    check(8'h05, 8'h15);
    run_test("21_DJNZ_R0", 1000);

    // =========================================================================
    // TEST 22: PUSH ACC / POP ACC (stack operations)
    //   MOV A,#0xAB    74 AB
    //   PUSH ACC       C0 E0   (PUSH using direct address 0xE0 of ACC)
    //   MOV A,#0x00    74 00
    //   POP ACC        D0 E0
    //   Expected A = 0xAB
    //
    //   SP resets to 0x07; PUSH increments to 0x08 and stores byte.
    //   POP reads from SP and decrements.
    // =========================================================================
    clear_rom;
    wb(8'h74); wb(8'hAB);           // MOV A,#0xAB
    wb(8'hC0); wb(8'hE0);           // PUSH ACC  (direct addr 0xE0)
    wb(8'h74); wb(8'h00);           // MOV A,#0x00
    wb(8'hD0); wb(8'hE0);           // POP  ACC
    check(8'hAB, 8'h16);
    run_test("22_PUSH_POP_ACC", 500);

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
    wb(8'hF0);                       // MOVX @DPTR,A   (write)
    wb(8'h74); wb(8'h00);           // MOV A,#0x00
    wb(8'hE0);                       // MOVX A,@DPTR   (read)
    check(8'hA5, 8'h17);
    run_test("23_MOVX_DPTR", 1000);

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
    // Main
    wb(8'h74); wb(8'h00);            // 0x0000: MOV A,#0x00
    wb(8'h12); wb(8'h00); wb(8'h50); // 0x0002: LCALL 0x0050
    check(8'h37, 8'h18);             // 0x0005: pass/fail dispatch
    // Subroutine
    rp = 16'h0050;
    wb(8'h74); wb(8'h37);            // 0x0050: MOV A,#0x37
    wb(8'h22);                        // 0x0052: RET
    run_test("24_LCALL_RET", 1000);

    // =========================================================================
    // TEST 25: MOV direct (direct addressing mode)
    //   MOV 0x30,#0xCD    75 30 CD    (MOV iram[0x30],#imm)
    //   MOV A,0x30        E5 30       (MOV A,(direct))
    //   Expected A = 0xCD
    // =========================================================================
    clear_rom;
    wb(8'h75); wb(8'h30); wb(8'hCD); // MOV iram[0x30],#0xCD
    wb(8'hE5); wb(8'h30);            // MOV A,iram[0x30]
    check(8'hCD, 8'h19);
    run_test("25_MOV_DIRECT", 500);

    // =========================================================================
    // TEST 26: MOV @R0 (indirect addressing mode)
    //   MOV R0,#0x40      78 40    (point R0 at iram address 0x40)
    //   MOV @R0,#0x55     76 55    (store 0x55 at iram[R0])
    //   MOV A,@R0         E6       (load A from iram[R0])
    //   Expected A = 0x55
    //
    //   Opcodes:
    //     MOV R0,#imm    = 0x78  (0111_1000)
    //     MOV @R0,#imm   = 0x76  (0111_0110)
    //     MOV A,@R0      = 0xE6  (1110_0110)
    // =========================================================================
    clear_rom;
    wb(8'h78); wb(8'h40);           // MOV R0,#0x40
    wb(8'h76); wb(8'h55);           // MOV @R0,#0x55
    wb(8'hE6);                       // MOV A,@R0
    check(8'h55, 8'h1A);
    run_test("26_MOV_INDIRECT", 500);

    // =========================================================================
    // TEST 27: INC DPTR
    //   MOV DPTR,#0xABCD    90 AB CD
    //   INC DPTR            A3
    //   MOV A,DPL           E5 82    (DPL SFR = 0x82)
    //   Expected A (DPL) = 0xCE
    // =========================================================================
    clear_rom;
    wb(8'h90); wb(8'hAB); wb(8'hCD);// MOV DPTR,#0xABCD
    wb(8'hA3);                        // INC DPTR
    wb(8'hE5); wb(8'h82);            // MOV A,DPL  (SFR 0x82)
    check(8'hCE, 8'h1B);
    run_test("27_INC_DPTR", 500);

    // =========================================================================
    // TEST 28: MOVC A,@A+DPTR (read from code/program memory)
    //   Place sentinel byte 0x5A at rom[0x0040].
    //   MOV DPTR,#0x0038    90 00 38
    //   MOV A,#0x08         74 08
    //   MOVC A,@A+DPTR      93          → reads rom[0x0038+0x08] = rom[0x0040] = 0x5A
    //   Expected A = 0x5A
    //
    //   MOVC uses the instruction Wishbone bus.  The CPU sends address
    //   (DPTR+A)=0x0040 on wbi_adr_o; our ROM model returns the packed word
    //   and the CPU extracts byte [7:0] (0x0040 is word-aligned, adr[1:0]=00).
    // =========================================================================
    clear_rom;
    rom[16'h0040] = 8'h5A;           // sentinel data byte
    wb(8'h90); wb(8'h00); wb(8'h38);// MOV DPTR,#0x0038
    wb(8'h74); wb(8'h08);           // MOV A,#0x08
    wb(8'h93);                       // MOVC A,@A+DPTR
    check(8'h5A, 8'h1C);
    run_test("28_MOVC_DPTR", 1000);

    // =========================================================================
    // TEST 29: CJNE A,direct (compare A with direct address, branch if not equal)
    //   MOV iram[0x30],#0xAA   75 30 AA
    //   MOV A,#0xBB            74 BB      (A ≠ (0x30), so CJNE branches)
    //   CJNE A,0x30,+5         B5 30 05   PC_after=0x0008; target=0x000D
    //   MOV A,#0x1D            74 1D      (fall-through: equal, shouldn't happen → fail)
    //   LJMP 0x0100            02 01 00
    //   MOV A,#0x7F            74 7F      ← target of CJNE (pass)
    //   LJMP 0x0100            02 01 00
    //
    //   Layout:
    //     0x0000: 75 30 AA
    //     0x0003: 74 BB
    //     0x0005: B5 30 05   CJNE A,0x30,+5  PC_after=0x0008 → 0x000D
    //     0x0008: 74 1D      fail
    //     0x000A: 02 01 00   LJMP
    //     0x000D: 74 7F      pass
    //     0x000F: 02 01 00   LJMP
    // =========================================================================
    clear_rom;
    // 0x0000
    wb(8'h75); wb(8'h30); wb(8'hAA); // MOV iram[0x30],#0xAA
    // 0x0003
    wb(8'h74); wb(8'hBB);            // MOV A,#0xBB
    // 0x0005
    wb(8'hB5); wb(8'h30); wb(8'h05); // CJNE A,0x30,+5  → 0x000D
    // 0x0008
    wb(8'h74); wb(8'h1D);            // fail (equal path)
    // 0x000A
    wb(8'h02); wb(8'h01); wb(8'h00); // LJMP 0x0100
    // 0x000D
    wb(8'h74); wb(8'h7F);            // pass (not-equal path)
    // 0x000F
    wb(8'h02); wb(8'h01); wb(8'h00); // LJMP 0x0100
    run_test("29_CJNE_DIRECT", 500);

    // =========================================================================
    // TEST 30: MOV register ↔ direct address
    //   MOV R1,#0x42       79 42    (0x79 = MOV R1,#imm)
    //   MOV iram[0x31],R1  89 31    (0x89 = MOV direct,R1)
    //   MOV A,iram[0x31]   E5 31    (MOV A,direct)
    //   Expected A = 0x42
    // =========================================================================
    clear_rom;
    wb(8'h79); wb(8'h42);           // MOV R1,#0x42
    wb(8'h89); wb(8'h31);           // MOV iram[0x31],R1
    wb(8'hE5); wb(8'h31);           // MOV A,iram[0x31]
    check(8'h42, 8'h1E);
    run_test("30_MOV_REG_DIRECT", 500);

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
