// =============================================================================
//  i8048_core_tb.v  —  Self-checking testbench for i8048_core
//
//  STRATEGY
//  --------
//  Each test group writes a tiny ROM image into the `rom[]` array, resets
//  the CPU, clocks it until the instruction completes, then uses `check_*`
//  tasks to assert expected values.  A $display-based pass/fail log is
//  produced, and a final summary reports total PASS/FAIL counts.
//
//  The CPU executes from external ROM (rom_data driven by `rom[]`), so we
//  control every byte.  After each instruction we halt by leaving a NOP (0x00)
//  stream so the CPU idles cleanly while we inspect state.
//
//  COVERAGE
//  --------
//  Group  1  : NOP
//  Group  2  : MOV A,#data  / MOV Rn,A  / MOV A,Rn
//  Group  3  : MOV @Ri,A    / MOV A,@Ri
//  Group  4  : MOV Rn,#data / MOV @Ri,#data
//  Group  5  : INC A  / DEC A  / INC Rn  / DEC Rn
//  Group  6  : INC @Ri  (0x10/0x11 — newly added)
//  Group  7  : ADD A,#data  / ADD A,Rn  / ADD A,@Ri
//  Group  8  : ADDC A,#data / ADDC A,Rn / ADDC A,@Ri  (carry path)
//  Group  9  : ANL A,#data  / ANL A,Rn  / ANL A,@Ri
//  Group 10  : ORL A,#data  / ORL A,Rn  / ORL A,@Ri
//  Group 11  : XRL A,#data
//  Group 12  : CLR A  / CPL A  / SWAP A
//  Group 13  : RR A   / RL A   / RRC A  / RLC A
//  Group 14  : DA A
//  Group 15  : CLR C  / CPL C
//  Group 16  : CLR F0 / CPL F0 / CLR F1 / CPL F1
//  Group 17  : MOV A,T  / MOV T,A
//  Group 18  : STRT T / STOP TCNT / STRT CNT
//  Group 19  : XCH A,Rn  / XCH A,@Ri  / XCHD A,@Ri
//  Group 20  : JMP  (page 0)
//  Group 21  : CALL / RET
//                  - CALL jumps to target, SP increments
//                  - Return address stored at correct RAM slot (pre-increment SP)
//                  - RAM[0x08]=low byte, RAM[0x09]=high byte verified explicitly
//                  - RET restores correct PC, SP decrements
//                  - Nested CALL/RET: two-deep stack verifies SP tracks correctly
//                    throughout; inner/outer return addresses in adjacent slots
//  Group 22  : DJNZ Rn,addr
//  Group 23  : JZ / JNZ
//  Group 24  : JC / JNC
//  Group 25  : JB0..JB7
//  Group 26  : JTF
//  Group 27  : JT0 / JNT0 / JT1 / JNT1
//  Group 28  : MOVP A,@A  / MOVP3 A,@A
//  Group 29  : OUTL BUS,A / OUTL P1,A / OUTL P2,A
//  Group 30  : IN A,P1  / IN A,P2  (newly added)
//  Group 31  : INS A,BUS              (newly added)
//  Group 32  : SEL RB0 / SEL RB1  (register bank switch)
//  Group 33  : RETR (interrupt return)
//                  - RETR reads from correct RAM slot (pre-decrement SP)
//                  - PSW[7:4] (including CY) restored from stack high byte
//                  - SP decrements correctly after RETR
//                  - irq_in_progress cleared
//  Group 34  : Carry propagation through ADD chain
//  Group 35  : Auxiliary Carry (AC / PSW[6]) — all six ADD/ADDC variants
//                  AC=1 and AC=0 cases for each:
//                  ADD A,#data / ADD A,Rn / ADD A,@Ri
//                  ADDC A,#data / ADDC A,Rn / ADDC A,@Ri
//  Group 36  : SEL MB1 / CALL — memory bank select + cross-bank fetch
//                  - SEL MB1 sets mb_latch=1
//                  - CALL loads pc[11]=mb_latch → target in upper 2K bank
//                  - rom_addr_phys correctly uses pc[11:0] not {p2[3],pc[10:0]}
//                  - IR fetches real opcode from bank 1, not NOP (0xFF/0x00)
//                  - RET from bank 1 returns to bank 0 correctly
//                  - SEL MB0 / CALL confirms bank 0 still reachable
//  Group 37  : Timer interrupt re-fire after RETR (regression)
//                  - timer_flag cleared on acknowledge, not sticky after ISR
//                  - irq_in_progress stays 0 after RETR (no immediate re-entry)
//                  - 3-deep call stack + timer ISR + RETR full scenario
//
//  USAGE
//  -----
//  Simulate with any Verilog-2001 simulator, e.g.:
//    iverilog -o i8048_tb i8048_core_tb.v i8048_core.v && vvp i8048_tb
//
// =============================================================================

`include "timescale.v"

module i8048_core_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         clk, res_n, t0, t1, int_n;
    reg  [7:0]  bus_in;
    wire [11:0] pc;
    wire [7:0]  ir, p1, p2, acc, bus_addr, bus_out;
    wire        ale, psen_n, rd_n, wr_n, prog, cycle_2;

    // -------------------------------------------------------------------------
    // ROM model — 4K bytes, loaded per test
    // -------------------------------------------------------------------------
    reg [7:0] rom [0:4095];
    reg  [11:0] rom_addr;
    wire [7:0]  rom_data = rom[rom_addr];
    always @(*) begin
        if (cycle_2) begin
            case (ir)
                8'hA3: rom_addr = {pc[11:8], acc}; // MOVP:  current page + acc
                8'hE3: rom_addr = {4'b0011, acc};  // MOVP3: page 3 + acc
                default: rom_addr = pc;             // standard 2-byte operand fetch
            endcase
        end else begin
            rom_addr = pc;                          // standard opcode fetch
        end
    end

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    i8048_core dut (
        .clk(clk), .res_n(res_n),
        .t0(t0), .t1(t1), .int_n(int_n),
        .rom_data(rom_data), .bus_in(bus_in),
        .pc(pc), .ir(ir),
        .p1(p1), .p2(p2),
        .acc(acc), .bus_addr(bus_addr), .bus_out(bus_out),
        .ale(ale), .psen_n(psen_n), .rd_n(rd_n),
        .wr_n(wr_n), .prog(prog), .cycle_2(cycle_2)
    );

    // -------------------------------------------------------------------------
    // Clock: 50MHz (20ns period) — fast for simulation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test counters
    // -------------------------------------------------------------------------
    integer pass_count, fail_count, test_num;

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    // Fill ROM with NOPs from address 0 to 4095
    task fill_nop;
        integer i;
        begin
            for (i = 0; i < 4096; i = i+1)
                rom[i] = 8'h00; // NOP
        end
    endtask

    // Hard reset: hold res_n low for 3 clocks then release
    task hard_reset;
        begin
            res_n = 0;
            repeat(3) @(posedge clk);
            @(negedge clk);
            res_n = 1;
        end
    endtask

    // Clock N full CPU machine cycles (each = 5 clocks in the state machine)
    task clock_cycles;
        input integer n;
        begin
            repeat(n * 5) @(posedge clk);
            #1; // settle
        end
    endtask

    // Check accumulator value
    task check_acc;
        input [7:0] expected;
        input [63:0] label; // up to 8 chars as packed string — use $sformat workaround
        begin
            test_num = test_num + 1;
            if (acc === expected) begin
                $display("  PASS [%0d] ACC=%02h (%0s)", test_num, acc, label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] ACC: expected %02h, got %02h (%0s)",
                         test_num, expected, acc, label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check a RAM cell (access via hierarchical reference)
    task check_ram;
        input [6:0]  addr;
        input [7:0]  expected;
        input [127:0] label;
        begin
            test_num = test_num + 1;
            if (dut.ram[addr] === expected) begin
                $display("  PASS [%0d] RAM[%02h]=%02h (%0s)", test_num, addr, dut.ram[addr], label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] RAM[%02h]: expected %02h, got %02h (%0s)",
                         test_num, addr, expected, dut.ram[addr], label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check PSW carry bit (psw[7])
    task check_carry;
        input expected;
        input [127:0] label;
        begin
            test_num = test_num + 1;
            if (dut.psw[7] === expected) begin
                $display("  PASS [%0d] CY=%0b (%0s)", test_num, dut.psw[7], label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] CY: expected %0b, got %0b (%0s)",
                         test_num, expected, dut.psw[7], label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check PC value
    task check_pc;
        input [11:0] expected;
        input [127:0] label;
        begin
            test_num = test_num + 1;
            if (pc === expected) begin
                $display("  PASS [%0d] PC=%03h (%0s)", test_num, pc, label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] PC: expected %03h, got %03h (%0s)",
                         test_num, expected, pc, label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check stack pointer (PSW[2:0])
    task check_sp;
        input [2:0] expected;
        input [127:0] label;
        begin
            test_num = test_num + 1;
            if (dut.psw[2:0] === expected) begin
                $display("  PASS [%0d] SP=%0d (%0s)", test_num, dut.psw[2:0], label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] SP: expected %0d, got %0d (%0s)",
                         test_num, expected, dut.psw[2:0], label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check PSW upper nibble (PSW[7:4] = {CY, AC, F0, BS})
    task check_psw_hi;
        input [3:0] expected;
        input [127:0] label;
        begin
            test_num = test_num + 1;
            if (dut.psw[7:4] === expected) begin
                $display("  PASS [%0d] PSW[7:4]=%1h (%0s)", test_num, dut.psw[7:4], label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] PSW[7:4]: expected %1h, got %1h (%0s)",
                         test_num, expected, dut.psw[7:4], label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check auxiliary carry (PSW[6])
    task check_ac;
        input expected;
        input [127:0] label;
        begin
            test_num = test_num + 1;
            if (dut.psw[6] === expected) begin
                $display("  PASS [%0d] AC=%0b (%0s)", test_num, dut.psw[6], label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] AC: expected %0b, got %0b (%0s)",
                         test_num, expected, dut.psw[6], label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check port output
    task check_port;
        input [1:0]  port_sel; // 0=p1, 1=p2
        input [7:0]  expected;
        input [127:0] label;
        reg [7:0] actual;
        begin
            test_num = test_num + 1;
            actual = (port_sel == 0) ? p1 : p2;
            if (actual === expected) begin
                $display("  PASS [%0d] P%0d=%02h (%0s)", test_num, port_sel+1, actual, label);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] P%0d: expected %02h, got %02h (%0s)",
                         test_num, port_sel+1, expected, actual, label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // MAIN TEST SEQUENCE
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("i8048_regression_tb.vcd");
        $dumpvars(0, i8048_core_tb);

        pass_count = 0; fail_count = 0; test_num = 0;
        t0 = 0; t1 = 0; int_n = 1; bus_in = 8'hAB;
        fill_nop();
        hard_reset();

        // =====================================================================
        $display("\n--- Group 1: NOP ---");
        // NOP at 0x00 — PC should advance to 0x001 after 1 cycle
        clock_cycles(1);
        check_pc(12'h001, "NOP advances PC");

        // =====================================================================
        $display("\n--- Group 2: MOV A,#data / MOV Rn,A / MOV A,Rn ---");
        fill_nop(); hard_reset();
        // MOV A,#0x5A -> MOV R0,A -> MOV R1,#0x3C -> MOV A,R1
        // R1 explicitly written before read -- no assumption about reset/init state
        rom[0] = 8'h23; rom[1] = 8'h5A;  // MOV A,#0x5A
        rom[2] = 8'hA8;                   // MOV R0,A     (R0=0x5A)
        rom[3] = 8'hB9; rom[4] = 8'h3C;  // MOV R1,#0x3C (write R1 first)
        rom[5] = 8'hF9;                   // MOV A,R1     -> ACC=0x3C
        clock_cycles(2); check_acc(8'h5A, "MOV A,#0x5A");
        clock_cycles(1); check_ram(7'h00, 8'h5A, "MOV R0,A -> RAM[0]=0x5A");
        clock_cycles(2); // MOV R1,#0x3C
        clock_cycles(1); check_acc(8'h3C, "MOV A,R1 (R1 written to 0x3C first)");

        // =====================================================================
        $display("\n--- Group 3: MOV @Ri,A / MOV A,@Ri ---");
        fill_nop(); hard_reset();
        // Set R0=0x10, put 0xBB in acc, MOV @R0,A, then MOV A,@R0
        rom[0] = 8'h23; rom[1] = 8'h10;  // MOV A,#0x10
        rom[2] = 8'hA8;                   // MOV R0,A  (R0=0x10)
        rom[3] = 8'h23; rom[4] = 8'hBB;  // MOV A,#0xBB
        rom[5] = 8'hA0;                   // MOV @R0,A -> RAM[0x10]=0xBB
        rom[6] = 8'h23; rom[7] = 8'h00;  // MOV A,#0x00 (clear acc)
        rom[8] = 8'hF0;                   // MOV A,@R0  -> ACC=0xBB
        clock_cycles(2); // MOV A,#0x10
        clock_cycles(1); // MOV R0,A
        clock_cycles(2); // MOV A,#0xBB
        // No pre-check of RAM[0x10]: uninitialised RAM value is undefined
        clock_cycles(1); check_ram(7'h10, 8'hBB, "MOV @R0,A -> RAM[0x10]=0xBB");
        clock_cycles(2); // MOV A,#0
        clock_cycles(1); check_acc(8'hBB, "MOV A,@R0 -> ACC=0xBB");

        // =====================================================================
        $display("\n--- Group 4: MOV Rn,#data / MOV @Ri,#data ---");
        fill_nop(); hard_reset();
        rom[0] = 8'hB8; rom[1] = 8'hC3;  // MOV R0,#0xC3
        rom[2] = 8'hF8;                   // MOV A,R0 -> ACC=0xC3
        // Set R1=0x20, then MOV @R1,#0xDE
        rom[3] = 8'hB9; rom[4] = 8'h20;  // MOV R1,#0x20
        rom[5] = 8'hB1; rom[6] = 8'hDE;  // MOV @R1,#0xDE -> RAM[0x20]=0xDE
        clock_cycles(2);
        clock_cycles(1); check_acc(8'hC3, "MOV Rn,#data then MOV A,Rn");
        clock_cycles(2); // MOV R1,#0x20
        clock_cycles(2); check_ram(7'h20, 8'hDE, "MOV @R1,#0xDE");

        // =====================================================================
        $display("\n--- Group 5: INC A / DEC A / INC Rn / DEC Rn ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'h0F;  // MOV A,#0x0F
        rom[2] = 8'h17;                   // INC A  -> 0x10
        rom[3] = 8'h07;                   // DEC A  -> 0x0F
        rom[4] = 8'hB8; rom[5] = 8'h07;  // MOV R0,#7
        rom[6] = 8'h18;                   // INC R0 -> 8
        rom[7] = 8'h08;                   // DEC R0... wait 0x08=INS A,BUS
        // Use R1 for DEC to avoid opcode conflict
        rom[7] = 8'hB9; rom[8] = 8'h05;  // MOV R1,#5
        rom[9] = 8'hC9;                   // DEC R1 -> 4
        clock_cycles(2);
        clock_cycles(1); check_acc(8'h10, "INC A: 0x0F->0x10");
        clock_cycles(1); check_acc(8'h0F, "DEC A: 0x10->0x0F");
        clock_cycles(2); // MOV R0,#7
        clock_cycles(1); check_ram(7'h00, 8'h08, "INC R0: 7->8");
        clock_cycles(2); // MOV R1,#5
        clock_cycles(1); check_ram(7'h01, 8'h04, "DEC R1: 5->4");

        // =====================================================================
        $display("\n--- Group 6: INC @Ri (0x10/0x11) ---");
        fill_nop(); hard_reset();
        // Set R0=0x30, put 0x44 at RAM[0x30], then INC @R0
        rom[0] = 8'hB8; rom[1] = 8'h30;  // MOV R0,#0x30
        rom[2] = 8'hB0; rom[3] = 8'h44;  // MOV @R0,#0x44 -> RAM[0x30]=0x44
        rom[4] = 8'h10;                   // INC @R0 -> RAM[0x30]=0x45
        // Set R1=0x31, put 0xFF at RAM[0x31], INC @R1 -> wrap to 0x00
        rom[5] = 8'hB9; rom[6] = 8'h31;  // MOV R1,#0x31
        rom[7] = 8'hB1; rom[8] = 8'hFF;  // MOV @R1,#0xFF
        rom[9] = 8'h11;                   // INC @R1 -> RAM[0x31]=0x00 (wrap)
        clock_cycles(2); // MOV R0,#0x30
        clock_cycles(2); // MOV @R0,#0x44
        clock_cycles(1); check_ram(7'h30, 8'h45, "INC @R0: 0x44->0x45");
        clock_cycles(2); // MOV R1,#0x31
        clock_cycles(2); // MOV @R1,#0xFF
        clock_cycles(1); check_ram(7'h31, 8'h00, "INC @R1: 0xFF->0x00 wrap");

        // =====================================================================
        $display("\n--- Group 7: ADD A,#data / ADD A,Rn / ADD A,@Ri ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'h10;  // MOV A,#0x10
        rom[2] = 8'h03; rom[3] = 8'h05;  // ADD A,#0x05 -> 0x15
        // ADD A,Rn: set R2=0x20, ADD A,R2
        rom[4] = 8'hBA; rom[5] = 8'h20;  // MOV R2,#0x20
        rom[6] = 8'h6A;                   // ADD A,R2  -> 0x35
        // ADD A,@Ri: set R0=0x40, RAM[0x40]=0x0A, ADD A,@R0
        rom[7] = 8'hB8; rom[8] = 8'h40;  // MOV R0,#0x40
        rom[9] = 8'hB0; rom[10] = 8'h0A; // MOV @R0,#0x0A
        rom[11] = 8'h60;                  // ADD A,@R0 -> 0x3F
        clock_cycles(2); // MOV A,#0x10
        clock_cycles(2); check_acc(8'h15, "ADD A,#5: 0x10+0x05=0x15");
        clock_cycles(2); // MOV R2,#0x20
        clock_cycles(1); check_acc(8'h35, "ADD A,R2: 0x15+0x20=0x35");
        clock_cycles(2); clock_cycles(2); // setup @R0
        clock_cycles(1); check_acc(8'h3F, "ADD A,@R0: 0x35+0x0A=0x3F");

        // =====================================================================
        $display("\n--- Group 8: ADDC A,#data / ADDC A,Rn / ADDC A,@Ri ---");
        fill_nop(); hard_reset();
        // First set carry: ADD 0xFF+0x01 -> carry=1, acc=0x00
        rom[0] = 8'h23; rom[1] = 8'hFF;  // MOV A,#0xFF
        rom[2] = 8'h03; rom[3] = 8'h01;  // ADD A,#1 -> acc=0x00, CY=1
        // ADDC A,#data with carry in
        rom[4] = 8'h13; rom[5] = 8'h05;  // ADDC A,#5 -> 0x00+0x05+1=0x06, CY=0
        clock_cycles(2); clock_cycles(2);
        check_carry(1'b1, "CY=1 after 0xFF+0x01");
        clock_cycles(2);
        check_acc(8'h06, "ADDC A,#5 with CY=1: 0x00+5+1=0x06");
        check_carry(1'b0, "CY=0 after ADDC no overflow");
        // ADDC A,Rn: generate carry again, use ADDC A,R3
        rom[6]  = 8'h23; rom[7]  = 8'hFE; // MOV A,#0xFE
        rom[8]  = 8'hBB; rom[9]  = 8'h02; // MOV R3,#0x02
        rom[10] = 8'h03; rom[11] = 8'h01; // ADD A,#1 -> 0xFF, CY=0
        rom[12] = 8'h7B;                   // ADDC A,R3 -> 0xFF+0x02+0=0x01, CY=1
        clock_cycles(2); clock_cycles(2); clock_cycles(2);
        clock_cycles(1); check_acc(8'h01, "ADDC A,R3: 0xFF+2=0x01 with CY=1");
        check_carry(1'b1, "CY=1 after ADDC overflow");
        // ADDC A,@Ri corrected (0x70)
        rom[13] = 8'hB8; rom[14] = 8'h50; // MOV R0,#0x50
        rom[15] = 8'hB0; rom[16] = 8'h03; // MOV @R0,#3
        rom[17] = 8'h70;                   // ADDC A,@R0 -> 0x01+3+1=0x05, CY=0
        clock_cycles(2); clock_cycles(2);
        clock_cycles(1); check_acc(8'h05, "ADDC A,@R0 (0x70): 0x01+3+CY=0x05");
        check_carry(1'b0, "CY=0 after ADDC A,@R0");

        // =====================================================================
        $display("\n--- Group 9: ANL A,#data / ANL A,Rn / ANL A,@Ri ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'hFF;  // MOV A,#0xFF
        rom[2] = 8'h53; rom[3] = 8'hAA;  // ANL A,#0xAA -> 0xAA
        rom[4] = 8'hBB; rom[5] = 8'h0F;  // MOV R3,#0x0F
        rom[6] = 8'h5B;                   // ANL A,R3 -> 0xAA&0x0F=0x0A
        rom[7] = 8'hB8; rom[8] = 8'h60;  // MOV R0,#0x60
        rom[9] = 8'hB0; rom[10] = 8'hF0; // MOV @R0,#0xF0
        rom[11] = 8'h50;                  // ANL A,@R0 -> 0x0A&0xF0=0x00
        clock_cycles(2); clock_cycles(2); check_acc(8'hAA, "ANL A,#0xAA");
        clock_cycles(2); clock_cycles(1); check_acc(8'h0A, "ANL A,R3");
        clock_cycles(2); clock_cycles(2); clock_cycles(1);
        check_acc(8'h00, "ANL A,@R0");

        // =====================================================================
        $display("\n--- Group 10: ORL A,#data / ORL A,Rn / ORL A,@Ri ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h27;                   // CLR A
        rom[1] = 8'h43; rom[2] = 8'h55;  // ORL A,#0x55 -> 0x55
        rom[3] = 8'hBA; rom[4] = 8'hAA;  // MOV R2,#0xAA
        rom[5] = 8'h4A;                   // ORL A,R2 -> 0xFF
        rom[6] = 8'hB8; rom[7] = 8'h70;  // MOV R0,#0x70
        rom[8] = 8'hB0; rom[9] = 8'h01;  // MOV @R0,#0x01
        rom[10] = 8'h27;                  // CLR A
        rom[11] = 8'h40;                  // ORL A,@R0 -> 0x01
        clock_cycles(1); clock_cycles(2); check_acc(8'h55, "ORL A,#0x55");
        clock_cycles(2); clock_cycles(1); check_acc(8'hFF, "ORL A,R2");
        clock_cycles(2); clock_cycles(2); clock_cycles(1); clock_cycles(1);
        check_acc(8'h01, "ORL A,@R0");

        // =====================================================================
        $display("\n--- Group 11: XRL A,#data ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'hA5;  // MOV A,#0xA5
        rom[2] = 8'hD3; rom[3] = 8'hFF;  // XRL A,#0xFF -> 0x5A
        rom[4] = 8'hD3; rom[5] = 8'hFF;  // XRL A,#0xFF -> 0xA5 (inverse)
        clock_cycles(2); clock_cycles(2); check_acc(8'h5A, "XRL A,#0xFF: 0xA5->0x5A");
        clock_cycles(2); check_acc(8'hA5, "XRL A,#0xFF again: 0x5A->0xA5");

        // =====================================================================
        $display("\n--- Group 12: CLR A / CPL A / SWAP A ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'hAB;  // MOV A,#0xAB
        rom[2] = 8'h37;                   // CPL A  -> 0x54
        rom[3] = 8'h47;                   // SWAP A -> 0x45
        rom[4] = 8'h27;                   // CLR A  -> 0x00
        clock_cycles(2); clock_cycles(1); check_acc(8'h54, "CPL A: 0xAB->0x54");
        clock_cycles(1); check_acc(8'h45, "SWAP A: 0x54->0x45");
        clock_cycles(1); check_acc(8'h00, "CLR A -> 0x00");

        // =====================================================================
        $display("\n--- Group 13: RR A / RL A / RRC A / RLC A ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'h81;  // MOV A,#0x81  (1000_0001)
        rom[2] = 8'h77;                   // RR A  -> 1100_0000 = 0xC0
        rom[3] = 8'hE7;                   // RL A  -> 1000_0001 = 0x81 (back)
        // RRC: CY=0, acc=0x81 -> CY=1, acc=0x40
        rom[4] = 8'h97;                   // CLR C
        rom[5] = 8'h67;                   // RRC A -> acc=0x40, CY=1
        // RLC: acc=0x40 (0100_0000), CY=1 -> acc=0x81, CY=0
        rom[6] = 8'hF7;                   // RLC A -> acc=0x81, CY=0
        clock_cycles(2);
        clock_cycles(1); check_acc(8'hC0, "RR A: 0x81->0xC0");
        clock_cycles(1); check_acc(8'h81, "RL A: 0xC0->0x81");
        clock_cycles(1); // CLR C
        clock_cycles(1); check_acc(8'h40, "RRC A: 0x81->0x40");
        check_carry(1'b1, "RRC CY=1 (shifted out bit0=1)");
        clock_cycles(1); check_acc(8'h81, "RLC A: 0x40+CY1->0x81");
        check_carry(1'b0, "RLC CY=0 (shifted out bit7=0)");

        // =====================================================================
        $display("\n--- Group 14: DA A ---");
        fill_nop(); hard_reset();
        // BCD add: 0x19 + 0x01 = 0x20 in BCD
        rom[0] = 8'h23; rom[1] = 8'h19;  // MOV A,#0x19
        rom[2] = 8'h03; rom[3] = 8'h01;  // ADD A,#1  -> 0x1A (not BCD)
        rom[4] = 8'h57;                   // DA A      -> 0x20 (BCD correct)
        clock_cycles(2); clock_cycles(2); clock_cycles(1);
        check_acc(8'h20, "DA A: 0x19+1=0x1A -> BCD 0x20");

        // =====================================================================
        $display("\n--- Group 15: CLR C / CPL C ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'hFF;  // MOV A,#0xFF
        rom[2] = 8'h03; rom[3] = 8'h01;  // ADD A,#1 -> CY=1
        rom[4] = 8'h97;                   // CLR C -> CY=0
        rom[5] = 8'hA7;                   // CPL C -> CY=1
        clock_cycles(2); clock_cycles(2);
        check_carry(1'b1, "CY=1 after overflow");
        clock_cycles(1); check_carry(1'b0, "CLR C -> CY=0");
        clock_cycles(1); check_carry(1'b1, "CPL C -> CY=1");

        // =====================================================================
        $display("\n--- Group 16: CLR F0/F1 / CPL F0/F1 ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h95;  // CPL F0 (was 0, now 1)
        rom[1] = 8'h85;  // CLR F0 -> 0
        rom[2] = 8'hB5;  // CPL F1 (was 0, now 1)
        rom[3] = 8'hA5;  // CLR F1 -> 0
        clock_cycles(1);
        clock_cycles(1); // CPL then CLR F0
        begin : f0_check
            test_num = test_num + 1;
            if (dut.psw[5] === 1'b0) begin
                $display("  PASS [%0d] F0=0 after CLR F0", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] F0: expected 0, got %0b", test_num, dut.psw[5]);
                fail_count = fail_count + 1;
            end
        end
        clock_cycles(1); clock_cycles(1);
        begin : f1_check
            test_num = test_num + 1;
            if (dut.f1 === 1'b0) begin
                $display("  PASS [%0d] F1=0 after CLR F1", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] F1: expected 0, got %0b", test_num, dut.f1);
                fail_count = fail_count + 1;
            end
        end

        // =====================================================================
        $display("\n--- Group 17: MOV A,T / MOV T,A ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'h7E;  // MOV A,#0x7E
        rom[2] = 8'h62;                   // MOV T,A
        rom[3] = 8'h27;                   // CLR A
        rom[4] = 8'h42;                   // MOV A,T -> 0x7E
        clock_cycles(2); clock_cycles(1); clock_cycles(1);
        clock_cycles(1); check_acc(8'h7E, "MOV T,A then MOV A,T roundtrip");

        // =====================================================================
        $display("\n--- Group 18: STRT T / STOP TCNT ---");
        fill_nop(); hard_reset();
        // ROM layout: setup, STRT T, then enough NOPs for timer to increment,
        // then STOP TCNT — all written before the CPU starts executing
        // Timer needs 32 prescaler ticks per increment so 40 machine cycles
        // gives at least 1 increment. NOPs at 0x04..0x2B (40 NOPs), then STOP TCNT.
        rom[0] = 8'h23; rom[1] = 8'h00;  // MOV A,#0
        rom[2] = 8'h62;                   // MOV T,A (timer=0)
        rom[3] = 8'h55;                   // STRT T
        // rom[4..0x2B] = NOPs (fill_nop already did this)
        rom[12'h2C] = 8'h65;              // STOP TCNT at address 0x2C
        // Execute setup instructions
        clock_cycles(2); // MOV A,#0
        clock_cycles(1); // MOV T,A
        clock_cycles(1); // STRT T
        // Run through the 40 NOPs (40 machine cycles)
        clock_cycles(40);
        begin : timer_check
            test_num = test_num + 1;
            if (dut.timer_val > 8'h00) begin
                $display("  PASS [%0d] Timer incremented: val=%02h", test_num, dut.timer_val);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] Timer did not increment", test_num);
                fail_count = fail_count + 1;
            end
        end
        // Execute STOP TCNT
        clock_cycles(1);
        begin : timer_stop_check
            reg [7:0] saved_val;
            saved_val = dut.timer_val;
            repeat(20*5) @(posedge clk); #1;
            test_num = test_num + 1;
            if (dut.timer_val === saved_val) begin
                $display("  PASS [%0d] Timer stopped at %02h", test_num, saved_val);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] Timer continued after STOP TCNT", test_num);
                fail_count = fail_count + 1;
            end
        end

        // =====================================================================
        $display("\n--- Group 19: XCH A,Rn / XCH A,@Ri / XCHD A,@Ri ---");
        fill_nop(); hard_reset();
        // XCH A,R0: A=0xAA, R0=0x55 -> A=0x55, R0=0xAA
        rom[0] = 8'h23; rom[1] = 8'hAA;  // MOV A,#0xAA
        rom[2] = 8'hA8;                   // MOV R0,A  (R0=0xAA)
        rom[3] = 8'h23; rom[4] = 8'h55;  // MOV A,#0x55
        rom[5] = 8'h28;                   // XCH A,R0  -> A=0xAA, R0=0x55
        // XCHD A,@Ri: A=0xAB, RAM[ptr]=0xCD -> A=0xAD, RAM[ptr]=0xCB
        rom[6] = 8'hB8; rom[7] = 8'h40;  // MOV R0,#0x40
        rom[8] = 8'hB0; rom[9] = 8'hCD;  // MOV @R0,#0xCD
        rom[10] = 8'h23; rom[11] = 8'hAB;// MOV A,#0xAB
        rom[12] = 8'h30;                  // XCHD A,@R0 -> A=0xAD, RAM[0x40]=0xCB
        clock_cycles(2); clock_cycles(1); clock_cycles(2);
        clock_cycles(1); check_acc(8'hAA, "XCH A,R0: A=0x55 swapped to 0xAA");
        check_ram(7'h00, 8'h55, "XCH A,R0: R0 becomes 0x55");
        clock_cycles(2); clock_cycles(2); clock_cycles(2);
        clock_cycles(1); check_acc(8'hAD, "XCHD A,@R0: A low nibble exchanged");
        check_ram(7'h40, 8'hCB, "XCHD A,@R0: RAM low nibble exchanged");

        // =====================================================================
        $display("\n--- Group 20: JMP page 0 ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h04; rom[1] = 8'h10;  // JMP 0x010
        clock_cycles(2);
        check_pc(12'h010, "JMP 0x010");

        // =====================================================================
        $display("\n--- Group 21: CALL / RET ---");
        // ── Sub-test A: stack slot address verification ──────────────────────
        // The previous test only checked the final PC, which masked the bug
        // because old CALL+old RET were consistently off by one frame (errors
        // cancelled).  We now explicitly check the RAM addresses used.
        //
        // After reset: SP=0 (psw[2:0]=0), PSW[7:4]=0x0, page=0
        // CALL 0x020 from 0x000: next_pc=0x002
        //   Correct:  writes to {SP,   1'b0}+8 = {0,0}+8 = 0x08  (low byte)
        //                        {SP,   1'b1}+8 = {0,1}+8 = 0x09  (high byte)
        //   Buggy:    writes to {SP+1, 1'b0}+8 = {1,0}+8 = 0x0A  (wrong!)
        fill_nop(); hard_reset();
        rom[0]       = 8'h14; rom[1]      = 8'h20;  // CALL 0x020
        rom[12'h20]  = 8'h83;                         // RET
        clock_cycles(2);
        check_pc(12'h020, "CALL: PC jumps to target 0x020");
        check_sp(3'h1,    "CALL: SP incremented from 0 to 1");
        check_ram(7'h08, 8'h02, "CALL: low  byte of return addr at RAM[0x08]");
        check_ram(7'h09, 8'h00, "CALL: high byte of return addr at RAM[0x09]");
        clock_cycles(2);
        check_pc(12'h002, "RET: returns to correct address 0x002");
        check_sp(3'h0,    "RET: SP decremented back to 0");

        // ── Sub-test B: nested CALL / RET ────────────────────────────────────
        // Two-deep call stack exercises both SP increment slots.
        // ROM layout:
        //   0x000: CALL 0x040  → return addr = 0x002, slot 0: RAM[0x08/0x09]
        //   0x040: CALL 0x060  → return addr = 0x042, slot 1: RAM[0x0A/0x0B]
        //   0x060: RET         → should return to 0x042 (reads slot 1)
        //   0x042: RET         → should return to 0x002 (reads slot 0)
        fill_nop(); hard_reset();
        rom[0]       = 8'h14; rom[1]      = 8'h40;  // CALL 0x040
        rom[12'h40]  = 8'h14; rom[12'h41] = 8'h60;  // CALL 0x060
        rom[12'h60]  = 8'h83;                         // RET  (inner)
        rom[12'h42]  = 8'h83;                         // RET  (outer)
        clock_cycles(2);
        check_pc(12'h040, "Nested: outer CALL jumps to 0x040");
        check_sp(3'h1,    "Nested: SP=1 after outer CALL");
        check_ram(7'h08, 8'h02, "Nested: outer return addr low  at RAM[0x08]");
        check_ram(7'h09, 8'h00, "Nested: outer return addr high at RAM[0x09]");
        clock_cycles(2);
        check_pc(12'h060, "Nested: inner CALL jumps to 0x060");
        check_sp(3'h2,    "Nested: SP=2 after inner CALL");
        check_ram(7'h0A, 8'h42, "Nested: inner return addr low  at RAM[0x0A]");
        check_ram(7'h0B, 8'h00, "Nested: inner return addr high at RAM[0x0B]");
        clock_cycles(2);
        check_pc(12'h042, "Nested: inner RET returns to 0x042");
        check_sp(3'h1,    "Nested: SP=1 after inner RET");
        clock_cycles(2);
        check_pc(12'h002, "Nested: outer RET returns to 0x002");
        check_sp(3'h0,    "Nested: SP=0 after outer RET");

        // =====================================================================
        $display("\n--- Group 22: DJNZ Rn,addr ---");
        fill_nop(); hard_reset();
        rom[0] = 8'hB8; rom[1] = 8'h03;  // MOV R0,#3
        // DJNZ R0,loop at 0x002: loop back to 0x002 while R0!=0
        rom[2] = 8'hE8; rom[3] = 8'h02;  // DJNZ R0,0x002
        // Falls through to 0x004 when R0=0
        clock_cycles(2); // MOV R0,#3
        // 3 iterations of DJNZ (each 2 cycles)
        clock_cycles(2); clock_cycles(2); clock_cycles(2);
        // After 3rd DJNZ R0=0 so no branch, PC=0x004
        check_pc(12'h004, "DJNZ falls through after R0 reaches 0");
        check_ram(7'h00, 8'h00, "DJNZ: R0=0 after 3 decrements");

        // =====================================================================
        $display("\n--- Group 23: JZ / JNZ ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h27;                   // CLR A
        rom[1] = 8'hC6; rom[2] = 8'h10;  // JZ 0x010  -> taken (A=0)
        rom[12'h10] = 8'h23; rom[12'h11] = 8'h01; // MOV A,#1
        rom[12'h12] = 8'h96; rom[12'h13] = 8'h20; // JNZ 0x020 -> taken (A!=0)
        clock_cycles(1); clock_cycles(2); check_pc(12'h010, "JZ taken: A=0");
        clock_cycles(2); clock_cycles(2); check_pc(12'h020, "JNZ taken: A=1");

        // =====================================================================
        $display("\n--- Group 24: JC / JNC ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h97;                   // CLR C
        rom[1] = 8'hE6; rom[2] = 8'h30;  // JNC 0x030 -> taken (CY=0)
        rom[12'h30] = 8'h23; rom[12'h31] = 8'hFF; // MOV A,#0xFF
        rom[12'h32] = 8'h03; rom[12'h33] = 8'h01; // ADD A,#1 -> CY=1
        rom[12'h34] = 8'hF6; rom[12'h35] = 8'h40; // JC 0x040 -> taken
        clock_cycles(1); clock_cycles(2); check_pc(12'h030, "JNC taken: CY=0");
        clock_cycles(2); clock_cycles(2); clock_cycles(2);
        check_pc(12'h040, "JC taken: CY=1");

        // =====================================================================
        $display("\n--- Group 25: JB0..JB7 ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'h01;  // MOV A,#0x01 (bit0=1)
        rom[2] = 8'h12; rom[3] = 8'h50;  // JB0 0x050 -> taken
        rom[12'h50] = 8'h23; rom[12'h51] = 8'h80; // MOV A,#0x80 (bit7=1)
        rom[12'h52] = 8'hF2; rom[12'h53] = 8'h60; // JB7 0x060 -> taken
        clock_cycles(2); clock_cycles(2); check_pc(12'h050, "JB0 taken: bit0=1");
        clock_cycles(2); clock_cycles(2); check_pc(12'h060, "JB7 taken: bit7=1");

        // =====================================================================
        $display("\n--- Group 26: JTF ---");
        fill_nop(); hard_reset();
        // Force timer_flag via task — run STRT T and wait for overflow
        rom[0] = 8'h23; rom[1] = 8'hFE;  // MOV A,#0xFE
        rom[2] = 8'h62;                   // MOV T,A (timer=0xFE)
        rom[3] = 8'h55;                   // STRT T
        rom[4] = 8'h16; rom[5] = 8'h70;  // JTF 0x070 (poll until flag)
        rom[6] = 8'h04; rom[7] = 8'h04;  // JMP 0x004 (loop back to JTF)
        clock_cycles(2); clock_cycles(1); clock_cycles(1);
        // Poll timer_flag directly — stop as soon as it sets, with a timeout
        // Timer starts at 0xFE, needs 2 increments * 32 prescaler ticks to overflow
        // That is ~320 clocks minimum; poll every clock with a 600-clock timeout
        begin : wait_jtf
            integer timeout;
            timeout = 0;
            while (!dut.timer_flag && timeout < 600) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
            end
        end
        // timer_flag just set: CPU is in cycle_1 of JTF, needs one more cycle for cycle_2 to load PC
        clock_cycles(3);
        check_pc(12'h070, "JTF taken after timer overflow");

        // =====================================================================
        $display("\n--- Group 27: JT0/JNT0/JT1/JNT1 ---");
        fill_nop(); hard_reset();
        t0 = 0; t1 = 1;
        rom[0] = 8'h26; rom[1] = 8'h80;  // JNT0 0x080 -> taken (T0=0)
        rom[12'h80] = 8'h36; rom[12'h81] = 8'h90; // JT0 0x090 -> not taken, PC=0x82
        rom[12'h82] = 8'h56; rom[12'h83] = 8'hA0; // JT1 0x0A0 -> taken (T1=1)
        clock_cycles(2); check_pc(12'h080, "JNT0 taken: T0=0");
        clock_cycles(2); check_pc(12'h082, "JT0 not taken: T0=0");
        clock_cycles(2); check_pc(12'h0A0, "JT1 taken: T1=1");

        // =====================================================================
        $display("\n--- Group 28: MOVP A,@A / MOVP3 A,@A ---");
        fill_nop(); hard_reset();
        // MOVP A,@A: ACC=0x20, fetches ROM[{page0, 0x20}] = ROM[0x020] = 0x55
        // Data byte placed at 0x020 — well outside the instruction stream (0x00-0x07)
        // so it is never fetched as an opcode
        rom[0] = 8'h23; rom[1] = 8'h20;  // MOV A,#0x20
        rom[2] = 8'hA3;                   // MOVP A,@A -> fetch ROM[0x020] -> acc=0x55
        rom[12'h20] = 8'h55;              // data target for MOVP
        // MOVP3 A,@A: ACC=0x03, fetches ROM[{page3, 0x03}] = ROM[0x303] = 0xDD
        rom[3] = 8'h23; rom[4] = 8'h03;  // MOV A,#0x03
        rom[5] = 8'hE3;                   // MOVP3 A,@A -> fetch ROM[0x303] -> acc=0xDD
        rom[12'h303] = 8'hDD;             // data target for MOVP3
        clock_cycles(2); // MOV A,#0x20
        clock_cycles(2); check_acc(8'h55, "MOVP A,@A: ROM[0x020]=0x55");
        clock_cycles(2); // MOV A,#0x03
        clock_cycles(2); check_acc(8'hDD, "MOVP3 A,@A: ROM[0x303]=0xDD");
        clock_cycles(1);

        // =====================================================================
        $display("\n--- Group 29: OUTL BUS,A / OUTL P1,A / OUTL P2,A ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'hCA;  // MOV A,#0xCA
        rom[2] = 8'h02;                   // OUTL BUS,A
        rom[3] = 8'h23; rom[4] = 8'h12;  // MOV A,#0x12
        rom[5] = 8'h3A;                   // OUTL P1,A
        rom[6] = 8'h23; rom[7] = 8'h34;  // MOV A,#0x34
        rom[8] = 8'h3B;                   // OUTL P2,A
        //clock_cycles(2); clock_cycles(1); // OUTL BUS
        clock_cycles(2); clock_cycles(1); // OUTL BUS
        // bus_out checked via module output
        test_num = test_num + 1;
        if (bus_out === 8'hCA) begin
            $display("  PASS [%0d] OUTL BUS,A: bus_out=0xCA", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%0d] OUTL BUS,A: expected 0xCA, got %02h", test_num, bus_out);
            fail_count = fail_count + 1;
        end
        clock_cycles(2); clock_cycles(1); check_port(0, 8'h12, "OUTL P1,A");
        clock_cycles(2); clock_cycles(1); check_port(1, 8'h34, "OUTL P2,A");
        clock_cycles(1);
        // =====================================================================
        $display("\n--- Group 30: IN A,P1 / IN A,P2 ---");
        fill_nop(); hard_reset();
        // Pre-load ports by first writing them
        rom[0] = 8'h23; rom[1] = 8'hBB;  // MOV A,#0xBB
        rom[2] = 8'h3A;                   // OUTL P1,A  (P1=0xBB)
        rom[3] = 8'h23; rom[4] = 8'hCC;  // MOV A,#0xCC
        rom[5] = 8'h3B;                   // OUTL P2,A  (P2=0xCC)
        rom[6] = 8'h27;                   // CLR A
        rom[7] = 8'h09;                   // IN A,P1 -> 0xBB
        rom[8] = 8'h27;                   // CLR A
        rom[9] = 8'h0A;                   // IN A,P2 -> 0xCC
        clock_cycles(2); clock_cycles(1);
        clock_cycles(2); clock_cycles(1);
        clock_cycles(1); clock_cycles(1); check_acc(8'hBB, "IN A,P1 -> 0xBB");
        clock_cycles(1); clock_cycles(1); check_acc(8'hCC, "IN A,P2 -> 0xCC");

        // =====================================================================
        $display("\n--- Group 31: INS A,BUS ---");
        fill_nop(); hard_reset();
        bus_in = 8'hF7;
        rom[0] = 8'h27;                   // CLR A
        rom[1] = 8'h08;                   // INS A,BUS -> 0xF7
        clock_cycles(1); clock_cycles(1);
        check_acc(8'hF7, "INS A,BUS: acc=bus_in=0xF7");

        // =====================================================================
        $display("\n--- Group 32: SEL RB0 / SEL RB1 ---");
        fill_nop(); hard_reset();
        // Write 0xAA into R0 in bank 0 (addr 0x00)
        // Switch to bank 1, write 0x55 into R0 (addr 0x18)
        // Switch back, verify R0 in bank 0 is still 0xAA
        rom[0] = 8'hB8; rom[1] = 8'hAA;  // MOV R0,#0xAA (bank0, addr 0x00)
        rom[2] = 8'hD5;                   // SEL RB1
        rom[3] = 8'hB8; rom[4] = 8'h55;  // MOV R0,#0x55 (bank1, addr 0x18)
        rom[5] = 8'hC5;                   // SEL RB0
        // Now R0 in bank0 should still be 0xAA
        clock_cycles(2); // MOV R0,#0xAA bank0
        clock_cycles(1); // SEL RB1
        clock_cycles(2); // MOV R0,#0x55 bank1
        clock_cycles(1); // SEL RB0
        check_ram(7'h00, 8'hAA, "SEL RB0: bank0 R0 preserved as 0xAA");
        check_ram(7'h18, 8'h55, "SEL RB1: bank1 R0 set to 0x55");

        // =====================================================================
        $display("\n--- Group 33: RETR ---");
        // ── Sub-test A: stack slot, PSW restoration, SP tracking ─────────────
        // Like Group 21, the old test only checked the final PC.  The stack
        // address bug in RETR (reading from SP instead of SP-1) also cancelled
        // with the CALL bug, so it went undetected.
        //
        // We now:
        //   1. Establish a known PSW[7:4] before the CALL (CY=1 via ADD overflow)
        //   2. Check the RAM slot written by CALL
        //   3. Modify PSW inside the subroutine (CLR C → CY=0)
        //   4. Execute RETR and verify:
        //      - PC restored to correct return address
        //      - SP decremented back to 0
        //      - CY restored to 1 (PSW[7:4] read from correct stack slot)
        //      - irq_in_progress cleared
        //
        // ROM layout:
        //   0x000: MOV A,#0xFF
        //   0x002: ADD A,#0x01  → CY=1, AC=1  (PSW[7:4] = 4'hC = {CY=1,AC=1,F0=0,BS=0})
        //   0x004: CALL 0x030   → return addr = 0x006
        //            CALL stores {psw[7:4]=0xC, page=0x0} → RAM[0x09]=0xC0
        //            low byte 0x06 → RAM[0x08]=0x06,  SP: 0→1
        //   0x030: CLR C        → CY=0 (verifies RETR must restore it from stack)
        //   0x031: RETR         → restores PC=0x006, PSW[7:4]=0xC (CY=1), SP→0
        fill_nop(); hard_reset();
        rom[0]       = 8'h23; rom[1]      = 8'hFF;  // MOV A,#0xFF
        rom[2]       = 8'h03; rom[3]      = 8'h01;  // ADD A,#0x01 → CY=1, AC=1
        rom[4]       = 8'h14; rom[5]      = 8'h30;  // CALL 0x030  (return=0x006)
        rom[12'h30]  = 8'h97;                         // CLR C  (CY→0 in subroutine)
        rom[12'h31]  = 8'h93;                         // RETR
        clock_cycles(2);                              // MOV A,#0xFF
        clock_cycles(2);                              // ADD A,#0x01
        check_carry(1'b1, "RETR setup: CY=1 before CALL");
        clock_cycles(2);                              // CALL 0x030
        check_pc(12'h030, "RETR: CALL reaches subroutine 0x030");
        check_sp(3'h1,    "RETR: SP=1 after CALL");
        check_ram(7'h08, 8'h06, "RETR: low  byte of return addr at RAM[0x08]");
        check_ram(7'h09, 8'hC0, "RETR: high byte {PSW[7:4]=0xC,page=0} at RAM[0x09]");
        clock_cycles(1);                              // CLR C
        check_carry(1'b0, "RETR: CY=0 after CLR C inside subroutine");
        clock_cycles(2);                              // RETR
        check_pc(12'h006, "RETR: PC restored to return address 0x006");
        check_sp(3'h0,    "RETR: SP decremented back to 0");
        check_carry(1'b1, "RETR: CY restored to 1 from stack (PSW[7:4] roundtrip)");
        check_psw_hi(4'hC, "RETR: full PSW[7:4] = 0xC {CY=1,AC=1,F0=0,BS=0} restored");
        // irq_in_progress must be cleared by RETR regardless of how it was entered
        begin : retr_irq_check
            test_num = test_num + 1;
            if (dut.irq_in_progress === 1'b0) begin
                $display("  PASS [%0d] irq_in_progress=0 after RETR", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] irq_in_progress: expected 0, got %0b",
                         test_num, dut.irq_in_progress);
                fail_count = fail_count + 1;
            end
        end

        // =====================================================================
        $display("\n--- Group 34: Carry chain (multi-byte add) ---");
        fill_nop(); hard_reset();
        // Simulate 16-bit add: (0x00FF + 0x0001) = 0x0100
        // Low byte: 0xFF + 0x01 = 0x00, CY=1
        // High byte: 0x00 + 0x00 + CY = 0x01
        rom[0]  = 8'h23; rom[1]  = 8'hFF; // MOV A,#0xFF
        rom[2]  = 8'h03; rom[3]  = 8'h01; // ADD A,#0x01 -> A=0x00, CY=1
        rom[4]  = 8'hA8;                   // MOV R0,A  (save low byte=0x00)
        rom[5]  = 8'h23; rom[6]  = 8'h00; // MOV A,#0x00 (high byte)
        rom[7]  = 8'h13; rom[8]  = 8'h00; // ADDC A,#0x00 -> A=0+0+CY=0x01
        clock_cycles(2); clock_cycles(2);
        check_carry(1'b1, "Low byte overflow CY=1");
        clock_cycles(1); clock_cycles(2); clock_cycles(2);
        check_acc(8'h01, "16-bit add high byte: 0x00+CY=0x01");
        check_carry(1'b0, "No carry out of high byte");

        // =====================================================================
        $display("\n--- Group 35: Auxiliary Carry (AC) — all ADD/ADDC variants ---");
        // AC (PSW[6]) was broken in all 6 variants: the 4-bit nibble sum was
        // compared against 4'hF, which a 4-bit value can NEVER exceed, so AC
        // was permanently 0.  These tests catch that regression explicitly.
        //
        // Strategy: for each variant test BOTH cases —
        //   AC=1: lower nibble sum > 0xF  (carry out of bit 3)
        //   AC=0: lower nibble sum ≤ 0xF  (no carry)
        //
        // All 6 variants run sequentially in one ROM layout; no reset needed
        // between sub-tests since AC is overwritten by each new ADD/ADDC.
        //
        // ROM byte layout (compact, no gaps — NOP fill means CPU streams through):
        //
        //  0x000  MOV A,#0x0F          2B  ─┐ ADD A,#data AC=1: 0xF+1=0x10
        //  0x002  ADD A,#0x01          2B  ─┘
        //  0x004  MOV A,#0x10          2B  ─┐ ADD A,#data AC=0: 0x0+1=0x01
        //  0x006  ADD A,#0x01          2B  ─┘
        //  0x008  MOV A,#0x09          2B  ─┐
        //  0x00A  MOV R0,#0x09         2B   │ ADD A,Rn AC=1: 9+9=18
        //  0x00C  ADD A,R0             1B  ─┘
        //  0x00D  MOV A,#0x10          2B  ─┐
        //  0x00F  MOV R0,#0x10         2B   │ ADD A,Rn AC=0: 0+0=0
        //  0x011  ADD A,R0             1B  ─┘
        //  0x012  MOV R0,#0x20         2B  ─┐
        //  0x014  MOV @R0,#0x08        2B   │ ADD A,@Ri AC=1: 9+8=17
        //  0x016  MOV A,#0x09          2B   │
        //  0x018  ADD A,@R0            1B  ─┘
        //  0x019  MOV @R0,#0x01        2B  ─┐ ADD A,@Ri AC=0: 2+1=3
        //  0x01B  MOV A,#0x02          2B   │
        //  0x01D  ADD A,@R0            1B  ─┘
        //  0x01E  MOV A,#0xFF          2B  ─┐ set CY=1 for ADDC tests
        //  0x020  ADD A,#0x01          2B  ─┘ CY=1, A=0x00
        //  0x022  MOV A,#0x0F          2B  ─┐ ADDC A,#data AC=1: F+0+1=0x10
        //  0x024  ADDC A,#0x00         2B  ─┘
        //  0x026  CLR C                1B    clear CY
        //  0x027  MOV A,#0x01          2B  ─┐ ADDC A,#data AC=0: 1+1+0=2
        //  0x029  ADDC A,#0x01         2B  ─┘
        //  0x02B  MOV A,#0xFF          2B  ─┐ set CY=1
        //  0x02D  ADD A,#0x01          2B  ─┘
        //  0x02F  MOV A,#0x09          2B  ─┐
        //  0x031  MOV R2,#0x07         2B   │ ADDC A,Rn AC=1: 9+7+1=17
        //  0x033  ADDC A,R2            1B  ─┘
        //  0x034  CLR C                1B
        //  0x035  MOV A,#0x01          2B  ─┐ ADDC A,Rn AC=0: 1+2+0=3
        //  0x037  MOV R2,#0x02         2B   │
        //  0x039  ADDC A,R2            1B  ─┘
        //  0x03A  MOV A,#0xFF          2B  ─┐ set CY=1
        //  0x03C  ADD A,#0x01          2B  ─┘
        //  0x03E  MOV R0,#0x30         2B  ─┐
        //  0x040  MOV @R0,#0x07        2B   │ ADDC A,@Ri AC=1: 9+7+1=17
        //  0x042  MOV A,#0x09          2B   │
        //  0x044  ADDC A,@R0           1B  ─┘
        //  0x045  CLR C                1B
        //  0x046  MOV @R0,#0x01        2B  ─┐ ADDC A,@Ri AC=0: 2+1+0=3
        //  0x048  MOV A,#0x02          2B   │
        //  0x04A  ADDC A,@R0           1B  ─┘
        fill_nop(); hard_reset();
        // ADD A,#data
        rom[12'h000]=8'h23; rom[12'h001]=8'h0F;  // MOV A,#0x0F
        rom[12'h002]=8'h03; rom[12'h003]=8'h01;  // ADD A,#0x01 → AC=1
        rom[12'h004]=8'h23; rom[12'h005]=8'h10;  // MOV A,#0x10
        rom[12'h006]=8'h03; rom[12'h007]=8'h01;  // ADD A,#0x01 → AC=0
        // ADD A,Rn
        rom[12'h008]=8'h23; rom[12'h009]=8'h09;  // MOV A,#0x09
        rom[12'h00A]=8'hB8; rom[12'h00B]=8'h09;  // MOV R0,#0x09
        rom[12'h00C]=8'h68;                        // ADD A,R0   → AC=1
        rom[12'h00D]=8'h23; rom[12'h00E]=8'h10;  // MOV A,#0x10
        rom[12'h00F]=8'hB8; rom[12'h010]=8'h10;  // MOV R0,#0x10
        rom[12'h011]=8'h68;                        // ADD A,R0   → AC=0
        // ADD A,@Ri
        rom[12'h012]=8'hB8; rom[12'h013]=8'h20;  // MOV R0,#0x20
        rom[12'h014]=8'hB0; rom[12'h015]=8'h08;  // MOV @R0,#0x08
        rom[12'h016]=8'h23; rom[12'h017]=8'h09;  // MOV A,#0x09
        rom[12'h018]=8'h60;                        // ADD A,@R0  → AC=1
        rom[12'h019]=8'hB0; rom[12'h01A]=8'h01;  // MOV @R0,#0x01
        rom[12'h01B]=8'h23; rom[12'h01C]=8'h02;  // MOV A,#0x02
        rom[12'h01D]=8'h60;                        // ADD A,@R0  → AC=0
        // ADDC A,#data  (CY=1 set by ADD 0xFF+0x01)
        rom[12'h01E]=8'h23; rom[12'h01F]=8'hFF;  // MOV A,#0xFF
        rom[12'h020]=8'h03; rom[12'h021]=8'h01;  // ADD A,#0x01 → CY=1
        rom[12'h022]=8'h23; rom[12'h023]=8'h0F;  // MOV A,#0x0F
        rom[12'h024]=8'h13; rom[12'h025]=8'h00;  // ADDC A,#0x00 → AC=1
        rom[12'h026]=8'h97;                        // CLR C
        rom[12'h027]=8'h23; rom[12'h028]=8'h01;  // MOV A,#0x01
        rom[12'h029]=8'h13; rom[12'h02A]=8'h01;  // ADDC A,#0x01 → AC=0
        // ADDC A,Rn
        rom[12'h02B]=8'h23; rom[12'h02C]=8'hFF;  // MOV A,#0xFF
        rom[12'h02D]=8'h03; rom[12'h02E]=8'h01;  // ADD A,#0x01 → CY=1
        rom[12'h02F]=8'h23; rom[12'h030]=8'h09;  // MOV A,#0x09
        rom[12'h031]=8'hBA; rom[12'h032]=8'h07;  // MOV R2,#0x07
        rom[12'h033]=8'h7A;                        // ADDC A,R2  → AC=1
        rom[12'h034]=8'h97;                        // CLR C
        rom[12'h035]=8'h23; rom[12'h036]=8'h01;  // MOV A,#0x01
        rom[12'h037]=8'hBA; rom[12'h038]=8'h02;  // MOV R2,#0x02
        rom[12'h039]=8'h7A;                        // ADDC A,R2  → AC=0
        // ADDC A,@Ri
        rom[12'h03A]=8'h23; rom[12'h03B]=8'hFF;  // MOV A,#0xFF
        rom[12'h03C]=8'h03; rom[12'h03D]=8'h01;  // ADD A,#0x01 → CY=1
        rom[12'h03E]=8'hB8; rom[12'h03F]=8'h30;  // MOV R0,#0x30
        rom[12'h040]=8'hB0; rom[12'h041]=8'h07;  // MOV @R0,#0x07
        rom[12'h042]=8'h23; rom[12'h043]=8'h09;  // MOV A,#0x09
        rom[12'h044]=8'h70;                        // ADDC A,@R0 → AC=1
        rom[12'h045]=8'h97;                        // CLR C
        rom[12'h046]=8'hB0; rom[12'h047]=8'h01;  // MOV @R0,#0x01
        rom[12'h048]=8'h23; rom[12'h049]=8'h02;  // MOV A,#0x02
        rom[12'h04A]=8'h70;                        // ADDC A,@R0 → AC=0

        // ── ADD A,#data ──────────────────────────────────────────
        clock_cycles(2);                  // MOV A,#0x0F
        clock_cycles(2); check_ac(1'b1, "ADD A,#data: 0x0F+0x01 lower=0x10 → AC=1");
        clock_cycles(2);                  // MOV A,#0x10
        clock_cycles(2); check_ac(1'b0, "ADD A,#data: 0x10+0x01 lower=0x01 → AC=0");
        // ── ADD A,Rn ─────────────────────────────────────────────
        clock_cycles(2);                  // MOV A,#0x09
        clock_cycles(2);                  // MOV R0,#0x09
        clock_cycles(1); check_ac(1'b1, "ADD A,Rn: 0x09+0x09 lower=0x12 → AC=1");
        clock_cycles(2);                  // MOV A,#0x10
        clock_cycles(2);                  // MOV R0,#0x10
        clock_cycles(1); check_ac(1'b0, "ADD A,Rn: 0x10+0x10 lower=0x00 → AC=0");
        // ── ADD A,@Ri ────────────────────────────────────────────
        clock_cycles(2);                  // MOV R0,#0x20
        clock_cycles(2);                  // MOV @R0,#0x08
        clock_cycles(2);                  // MOV A,#0x09
        clock_cycles(1); check_ac(1'b1, "ADD A,@Ri: 0x09+0x08 lower=0x11 → AC=1");
        clock_cycles(2);                  // MOV @R0,#0x01
        clock_cycles(2);                  // MOV A,#0x02
        clock_cycles(1); check_ac(1'b0, "ADD A,@Ri: 0x02+0x01 lower=0x03 → AC=0");
        // ── ADDC A,#data ─────────────────────────────────────────
        clock_cycles(2);                  // MOV A,#0xFF
        clock_cycles(2);                  // ADD A,#0x01 → CY=1
        clock_cycles(2);                  // MOV A,#0x0F
        clock_cycles(2); check_ac(1'b1, "ADDC A,#data: 0x0F+0x00+CY1 lower=0x10 → AC=1");
        clock_cycles(1);                  // CLR C
        clock_cycles(2);                  // MOV A,#0x01
        clock_cycles(2); check_ac(1'b0, "ADDC A,#data: 0x01+0x01+CY0 lower=0x02 → AC=0");
        // ── ADDC A,Rn ────────────────────────────────────────────
        clock_cycles(2);                  // MOV A,#0xFF
        clock_cycles(2);                  // ADD A,#0x01 → CY=1
        clock_cycles(2);                  // MOV A,#0x09
        clock_cycles(2);                  // MOV R2,#0x07
        clock_cycles(1); check_ac(1'b1, "ADDC A,Rn: 0x09+0x07+CY1 lower=0x11 → AC=1");
        clock_cycles(1);                  // CLR C
        clock_cycles(2);                  // MOV A,#0x01
        clock_cycles(2);                  // MOV R2,#0x02
        clock_cycles(1); check_ac(1'b0, "ADDC A,Rn: 0x01+0x02+CY0 lower=0x03 → AC=0");
        // ── ADDC A,@Ri ───────────────────────────────────────────
        clock_cycles(2);                  // MOV A,#0xFF
        clock_cycles(2);                  // ADD A,#0x01 → CY=1
        clock_cycles(2);                  // MOV R0,#0x30
        clock_cycles(2);                  // MOV @R0,#0x07
        clock_cycles(2);                  // MOV A,#0x09
        clock_cycles(1); check_ac(1'b1, "ADDC A,@Ri: 0x09+0x07+CY1 lower=0x11 → AC=1");
        clock_cycles(1);                  // CLR C
        clock_cycles(2);                  // MOV @R0,#0x01
        clock_cycles(2);                  // MOV A,#0x02
        clock_cycles(1); check_ac(1'b0, "ADDC A,@Ri: 0x02+0x01+CY0 lower=0x03 → AC=0");

        // =====================================================================
        $display("\n--- Group 36: SEL MB1 / CALL — cross-bank fetch ---");
        // This tests the bug where rom_addr_phys used {p2[3], pc[10:0]}
        // instead of pc[11:0].  After SEL MB1 + CALL, pc[11]=1 but p2[3]=0,
        // so the old code addressed bank 0 and fetched 0xFF (NOP) instead of
        // the real opcode in bank 1.
        //
        // ROM layout:
        //   Bank 0 (0x000–0x7FF):
        //     0x000: MOV A,#0x55        load known sentinel into A
        //     0x002: SEL MB1            mb_latch → 1
        //     0x003: CALL 0x010         → pc = {1, 0, 0x10} = 0x810  (bank 1)
        //     0x005: MOV A,#0xAA        return lands here (check A=0xBB from bank1)
        //
        //   Bank 1 (0x800–0xFFF):
        //     0x810: MOV A,#0xBB        proof we fetched from bank 1 (not NOP)
        //     0x812: SEL MB0            switch back to bank 0 before RET
        //     0x813: RET                return to 0x005 in bank 0
        //
        // If the old bug is present: pc jumps to 0x810 but rom_addr_phys
        // addresses 0x010 (bank 0), fetches NOP, A stays 0x55.
        // With fix: A becomes 0xBB, confirming bank 1 was reached.
        fill_nop(); hard_reset();
        // Bank 0
        rom[12'h000] = 8'h23; rom[12'h001] = 8'h55;  // MOV A,#0x55
        rom[12'h002] = 8'hF5;                          // SEL MB1
        rom[12'h003] = 8'h14; rom[12'h004] = 8'h10;  // CALL 0x010 (→ 0x810)
        rom[12'h005] = 8'h23; rom[12'h006] = 8'hAA;  // MOV A,#0xAA (should not run)
        // Bank 1
        rom[12'h810] = 8'h23; rom[12'h811] = 8'hBB;  // MOV A,#0xBB
        rom[12'h812] = 8'hE5;                          // SEL MB0
        rom[12'h813] = 8'h83;                          // RET → back to 0x005

        clock_cycles(2);                               // MOV A,#0x55
        check_acc(8'h55, "MB1/CALL setup: A=0x55 before SEL MB1");
        clock_cycles(1);                               // SEL MB1
        clock_cycles(2);                               // CALL 0x010 → 0x810
        check_pc(12'h810, "MB1/CALL: PC=0x810 (bank 1 target)");
        clock_cycles(2);                               // MOV A,#0xBB  in bank 1
        check_acc(8'hBB, "MB1/CALL: A=0xBB — real bank-1 opcode fetched (not NOP)");
        clock_cycles(1);                               // SEL MB0
        clock_cycles(2);                               // RET → 0x005
        check_pc(12'h005, "MB1/CALL: RET returns to bank-0 address 0x005");

        // ── SEL MB0 / CALL confirms bank 0 still reachable ──────────────────
        // After the RET above we are at 0x005 in bank 0.
        // Re-run with SEL MB0 explicitly to confirm mb_latch=0 keeps us in bank 0.
        fill_nop(); hard_reset();
        rom[12'h000] = 8'hE5;                          // SEL MB0  (mb_latch → 0)
        rom[12'h001] = 8'h14; rom[12'h002] = 8'h20;  // CALL 0x020 → 0x020 (bank 0)
        rom[12'h020] = 8'h23; rom[12'h021] = 8'hCC;  // MOV A,#0xCC
        rom[12'h022] = 8'h83;                          // RET → 0x003

        clock_cycles(1);                               // SEL MB0
        clock_cycles(2);                               // CALL 0x020
        check_pc(12'h020, "MB0/CALL: PC=0x020 (stays in bank 0)");
        clock_cycles(2);                               // MOV A,#0xCC
        check_acc(8'hCC, "MB0/CALL: A=0xCC — bank-0 fetch correct");
        clock_cycles(2);                               // RET → 0x003
        check_pc(12'h003, "MB0/CALL: RET returns to 0x003 in bank 0");

        // =====================================================================
        $display("\n--- Group 37: Timer interrupt re-fire after RETR (regression) ---");
        // Regression for: timer_flag not cleared on acknowledge.
        // Symptom: after RETR, irq_in_progress=0 and timer_flag still=1,
        // so the ISR fires again immediately on every subsequent instruction.
        //
        // Scenario: 3 nested CALLs on the stack, timer interrupt fires,
        // ISR executes RETR.  After RETR the interrupted code resumes and
        // executes a RET — this RET must complete normally.  irq_in_progress
        // must stay 0 and the ISR must NOT re-enter.
        //
        // ROM layout:
        //   0x000: EN TCNTI          enable timer interrupts
        //   0x001: MOV A,#0xFD       load timer near overflow
        //   0x003: MOV T,A
        //   0x004: STRT T            start timer
        //   0x005: CALL 0x040        call1 → SP:0→1, return=0x007
        //   0x007: NOP (never reached during test)
        //
        //   0x040: CALL 0x060        call2 → SP:1→2, return=0x042
        //   0x042: RET               returns to 0x007 — the "interrupted code RET"
        //
        //   0x060: CALL 0x080        call3 → SP:2→3, return=0x062
        //   0x062: RET               (not reached in this test path)
        //
        //   0x080: NOP loop          spin here — interrupt fires during this NOP
        //   0x081: JMP 0x080
        //
        //   ISR vector 0x007: (timer ISR)
        //   0x007: MOV A,#0xEE       sentinel — proves ISR ran
        //   0x009: RETR              return from ISR
        //
        // Expected sequence:
        //   1. timer overflows while CPU spins at 0x080 (SP=3)
        //   2. service_interrupt: push 0x080 at slot 3, SP→4, pc→0x007
        //      timer_flag CLEARED on acknowledge (the fix)
        //   3. ISR: MOV A,#0xEE, then RETR
        //   4. RETR: SP→3, pc→0x080, irq_in_progress→0
        //   5. CPU resumes at 0x080, executes NOP, JMP back — no re-interrupt
        //   6. After a few cycles, force test exit by checking irq_in_progress
        //      stays 0 and timer_flag stays 0
        //
        // Old (buggy) behaviour: timer_flag still=1 after RETR, ISR re-fires
        // at step 5, irq_in_progress goes back to 1.
        fill_nop(); hard_reset();
        // Main code
        rom[12'h000] = 8'h25;                          // EN TCNTI
        rom[12'h001] = 8'h23; rom[12'h002] = 8'hFD;  // MOV A,#0xFD (3 ticks to overflow)
        rom[12'h003] = 8'h62;                          // MOV T,A
        rom[12'h004] = 8'h55;                          // STRT T
        rom[12'h005] = 8'h14; rom[12'h006] = 8'h40;  // CALL 0x040 → SP:0→1
        rom[12'h007] = 8'h00;                          // NOP (return landing pad)
        // call chain
        rom[12'h040] = 8'h14; rom[12'h041] = 8'h60;  // CALL 0x060 → SP:1→2
        rom[12'h042] = 8'h83;                          // RET → back to 0x007
        rom[12'h060] = 8'h14; rom[12'h061] = 8'h80;  // CALL 0x080 → SP:2→3
        rom[12'h062] = 8'h83;                          // RET (not reached in this path)
        // spin loop — interrupt fires here
        rom[12'h080] = 8'h00;                          // NOP
        rom[12'h081] = 8'h04; rom[12'h082] = 8'h80;  // JMP 0x080
        // Timer ISR at vector 0x007 — NOTE: overlaps with main NOP at 0x007.
        // For this test we point the ISR at 0x100 and patch the vector indirectly
        // by placing the ISR at 0x007 (timer vector IS 0x007 on 8049).
        // Reuse 0x007 as ISR: MOV A,#0xEE, RETR
        rom[12'h007] = 8'h23; rom[12'h008] = 8'hEE;  // MOV A,#0xEE (ISR sentinel)
        rom[12'h009] = 8'h93;                          // RETR

        // Run EN TCNTI + MOV A + MOV T + STRT T + CALL 0x040 + CALL 0x060 + CALL 0x080
        clock_cycles(1);  // EN TCNTI
        clock_cycles(2);  // MOV A,#0xFD
        clock_cycles(1);  // MOV T,A
        clock_cycles(1);  // STRT T
        clock_cycles(2);  // CALL 0x040 → SP=1
        clock_cycles(2);  // CALL 0x060 → SP=2
        clock_cycles(2);  // CALL 0x080 → SP=3
        // Note: check SP=3 rather than exact PC since the CPU may be at
        // 0x080 (NOP) or 0x081 (JMP) depending on where in the spin loop
        // we sample — SP=3 is the invariant that confirms call depth.
        check_sp(3'h3,    "TIMER-REFIRE: SP=3 (3 calls deep) before interrupt");

        // Wait for timer overflow → ISR entry
        begin : wait_timer_irq
            integer t;
            t = 0;
            while (!dut.irq_in_progress && t < 500) begin
                @(posedge clk); #1;
                t = t + 1;
            end
        end
        check_sp(3'h4,    "TIMER-REFIRE: SP=4 after interrupt push");

        // Verify timer_flag was cleared on acknowledge (the fix)
        begin : check_tflag
            test_num = test_num + 1;
            if (dut.timer_flag === 1'b0) begin
                $display("  PASS [%0d] timer_flag=0 after acknowledge (not re-fired)", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] timer_flag=1 after acknowledge — will re-fire after RETR", test_num);
                fail_count = fail_count + 1;
            end
        end

        // Run ISR: MOV A,#0xEE
        clock_cycles(2);
        check_acc(8'hEE,  "TIMER-REFIRE: ISR ran — A=0xEE sentinel");

        // RETR
        clock_cycles(2);
        check_sp(3'h3,    "TIMER-REFIRE: SP=3 after RETR");
        check_pc(12'h080, "TIMER-REFIRE: RETR returned to 0x080 (interrupted instruction per 8049 spec)");

        // Run the NOP at 0x080 that was interrupted — now executes after RETR
        clock_cycles(1);  // NOP at 0x080
        begin : check_no_refire
            test_num = test_num + 1;
            if (dut.irq_in_progress === 1'b0) begin
                $display("  PASS [%0d] irq_in_progress=0 after RETR — ISR did not re-fire", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] irq_in_progress=1 after RETR — ISR re-fired (timer_flag not cleared)", test_num);
                fail_count = fail_count + 1;
            end
        end
        // =====================================================================
        $display("\n--- Group 38: Multiple interrupt scenarios ---");
        // Three sub-tests:
        // A: timer_flag sticky — old carry-out bug cleared flag after 1 ALE cycle.
        // B: Timer pending during external ISR (DIS I) — must fire after RETR.
        // C: ext IRQ -> timer IRQ -> ext IRQ sequence.
        //
        // ROM layout (avoids ISR vector address conflicts):
        //   0x000: JMP 0x009      skip vectors
        //   0x003: JMP 0x040      ext ISR vector
        //   0x007: JMP 0x060      timer ISR vector
        //   0x009: EN I/TCNTI/setup/spin at 0x00F
        //   0x040: MOV A,#0xAA / DIS I / RETR
        //   0x060: MOV A,#0x55 / RETR

        // Sub-test A: timer_flag sticky
        $display("\n  Sub-test A: timer_flag held across multiple ALE cycles");
        fill_nop(); hard_reset();
        rom[12'h000] = 8'h23; rom[12'h001] = 8'hFF;
        rom[12'h002] = 8'h62;
        rom[12'h003] = 8'h55;
        clock_cycles(2); clock_cycles(1); clock_cycles(1);
        begin : wait_ovf_a
            // Timer at 0xFF: 1 tick × 32 ALE × 5 clks/ALE = 160 clks min; use 300
            integer w; for (w = 0; w < 300; w = w+1) @(posedge clk);
        end
        begin : chk_sticky1
            test_num = test_num + 1;
            if (dut.timer_flag === 1'b1) begin
                $display("  PASS [%0d] timer_flag=1 after overflow (sticky)", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] timer_flag=0 — cleared prematurely", test_num);
                fail_count = fail_count + 1;
            end
        end
        begin : wait_64
            integer w; for (w = 0; w < 64; w = w+1) @(posedge clk);
        end
        begin : chk_sticky2
            test_num = test_num + 1;
            if (dut.timer_flag === 1'b1) begin
                $display("  PASS [%0d] timer_flag still=1 after 64 more cycles (not a pulse)", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] timer_flag=0 — was only a 1-cycle pulse", test_num);
                fail_count = fail_count + 1;
            end
        end

        // Sub-test B: timer pending during external ISR with DIS I
        //
        // Key insight: can't mix free-running @(posedge clk) waits with
        // clock_cycles() instruction steps — the wait lets the DUT freely
        // execute instructions we then try to re-step.
        //
        // Strategy: overflow the timer FIRST (no interrupts enabled), verify
        // timer_flag is sticky, THEN enable interrupts and force ext IRQ,
        // THEN step through ext ISR instruction-by-instruction, THEN check
        // timer fires after RETR.
        $display("\n  Sub-test B: timer fires after external ISR (DIS I inside ISR)");
        fill_nop(); hard_reset();
        // Vectors
        rom[12'h003] = 8'h04; rom[12'h004] = 8'h40;  // ext vector JMP 0x040
        rom[12'h007] = 8'h04; rom[12'h008] = 8'h60;  // timer vector JMP 0x060
        // Ext ISR body: MOV A,#0xAA / DIS I / RETR
        rom[12'h040] = 8'h23; rom[12'h041] = 8'hAA;
        rom[12'h042] = 8'h15;
        rom[12'h043] = 8'h93;
        // Timer ISR body: MOV A,#0x55 / RETR
        rom[12'h060] = 8'h23; rom[12'h061] = 8'h55;
        rom[12'h062] = 8'h93;
        // Main at 0x000: load timer to 0xFF (1 tick to overflow), start it,
        // then spin — NO EN I / EN TCNTI yet so ISR can't fire during overflow
        rom[12'h000] = 8'h23; rom[12'h001] = 8'hFF;  // MOV A,#0xFF (1 tick)
        rom[12'h002] = 8'h62;                          // MOV T,A
        // 0x003 = ext vector — JMP 0x040. Main continues past it:
        // Actually 0x003 is now a JMP opcode. Main falls into it, but that's
        // fine — main jumps to 0x040 which is the ext ISR body (NOP-filled
        // initially but we set it). We need main to NOT hit 0x003.
        // Restructure: put timer setup at 0x000, JMP to spin past vectors.
        fill_nop(); hard_reset();
        // Vectors
        rom[12'h003] = 8'h04; rom[12'h004] = 8'h40;  // ext vector
        rom[12'h007] = 8'h04; rom[12'h008] = 8'h60;  // timer vector
        // ISR bodies
        rom[12'h040] = 8'h23; rom[12'h041] = 8'hAA;
        rom[12'h042] = 8'h15;
        rom[12'h043] = 8'h93;
        rom[12'h060] = 8'h23; rom[12'h061] = 8'h55;
        rom[12'h062] = 8'h93;
        // Main: JMP past vectors to 0x009, then setup
        rom[12'h000] = 8'h04; rom[12'h001] = 8'h09;  // JMP 0x009
        rom[12'h009] = 8'h23; rom[12'h00A] = 8'hFF;  // MOV A,#0xFF (1 tick to overflow)
        rom[12'h00B] = 8'h62;                          // MOV T,A
        rom[12'h00C] = 8'h55;                          // STRT T
        // Spin — interrupts NOT yet enabled
        rom[12'h00D] = 8'h00;                          // NOP spin
        rom[12'h00E] = 8'h04; rom[12'h00F] = 8'h0D;  // JMP 0x00D

        // Step through setup
        clock_cycles(2); check_pc(12'h009, "MultiIRQ-B: at setup 0x009");
        clock_cycles(2);  // MOV A,#0xFF
        clock_cycles(1);  // MOV T,A
        clock_cycles(1);  // STRT T

        // Wait for timer to overflow — poll timer_flag in a tight loop
        // No ISR can fire (EN TCNTI not called yet)
        begin : wait_tmr_ovf_b
            integer t; t = 0;
            while (dut.timer_flag !== 1'b1 && t < 1000) begin @(posedge clk); #1; t=t+1; end
        end
        begin : chk_tmr_pend
            test_num = test_num + 1;
            if (dut.timer_flag === 1'b1) begin
                $display("  PASS [%0d] timer_flag=1 after overflow (sticky, no ISR yet)", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] timer_flag=0 — not sticky", test_num);
                fail_count = fail_count + 1;
            end
        end

        // Now enable interrupts and force external IRQ
        // timer_flag is already set and will stay set while ext ISR runs
        force dut.irq_en_ext   = 1'b1;
        force dut.irq_en_timer = 1'b1;
        @(posedge clk); #1;
        release dut.irq_en_ext;
        release dut.irq_en_timer;
        force dut.int_n = 1'b0;

        // Wait for ext interrupt entry
        begin : wait_ext_b
            integer t; t = 0;
            while (!dut.irq_in_progress && t < 200) begin @(posedge clk); #1; t=t+1; end
        end
        clock_cycles(2);  // JMP at 0x003 → 0x040
        check_pc(12'h040, "MultiIRQ-B: ext ISR entered 0x040");
        release dut.int_n;

        // Verify timer_flag still set while ext ISR is running
        begin : chk_flag_in_isr
            test_num = test_num + 1;
            if (dut.timer_flag === 1'b1) begin
                $display("  PASS [%0d] timer_flag=1 while ext ISR running (sticky)", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] timer_flag=0 in ext ISR — flag cleared prematurely", test_num);
                fail_count = fail_count + 1;
            end
        end

        // Step through ext ISR instruction by instruction
        clock_cycles(2); check_acc(8'hAA, "MultiIRQ-B: ext ISR A=0xAA");
        clock_cycles(1);  // DIS I
        clock_cycles(2);  // RETR

        // After ext RETR: irq_en_ext=0 (DIS I), irq_en_timer=1, timer_flag=1
        // → timer ISR must fire
        begin : wait_tmr_fires_b
            integer t; t = 0;
            while (!dut.irq_in_progress && t < 100) begin @(posedge clk); #1; t=t+1; end
        end
        // Wait for JMP dispatch at 0x007 → 0x060 to complete using PC poll
        // (event-based, avoids fixed clock count that may be too short)
        begin : wait_pc_060
            integer t; t = 0;
            while (dut.pc !== 12'h060 && t < 100) begin @(posedge clk); #1; t=t+1; end
        end
        check_pc(12'h060, "MultiIRQ-B: timer ISR entered 0x060 after ext RETR");
        clock_cycles(2); check_acc(8'h55, "MultiIRQ-B: timer ISR A=0x55");
        clock_cycles(1);  // STOP T
        clock_cycles(2);  // RETR
        begin : chk_clean_b
            test_num = test_num + 1;
            if (dut.irq_in_progress === 1'b0) begin
                $display("  PASS [%0d] irq_in_progress=0 after timer RETR", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] irq_in_progress set after timer RETR", test_num);
                fail_count = fail_count + 1;
            end
        end

        // Sub-test C: ext -> timer -> ext — fresh ROM with DIS TCNTI in ext ISR
        // Sub-test B verified timer fires after a DIS-I-only ext ISR.
        // Sub-test C verifies the full 3-interrupt sequence exits cleanly
        // when the ext ISR disables BOTH external and timer before returning.
        $display("\n  Sub-test C: ext, timer, ext again — full sequence");
        fill_nop(); hard_reset();
        rom[12'h000] = 8'h04; rom[12'h001] = 8'h09;  // JMP 0x009 (skip vectors)
        rom[12'h003] = 8'h04; rom[12'h004] = 8'h40;  // ext vector JMP 0x040
        rom[12'h007] = 8'h04; rom[12'h008] = 8'h60;  // timer vector JMP 0x060
        rom[12'h009] = 8'h05;                          // EN I
        rom[12'h00A] = 8'h25;                          // EN TCNTI
        rom[12'h00B] = 8'h23; rom[12'h00C] = 8'hFD;  // MOV A,#0xFD (3 ticks)
        rom[12'h00D] = 8'h62;                          // MOV T,A
        rom[12'h00E] = 8'h55;                          // STRT T
        rom[12'h00F] = 8'h00;                          // NOP spin
        rom[12'h010] = 8'h04; rom[12'h011] = 8'h0F;  // JMP 0x00F
        // Ext ISR with DIS TCNTI — clean exit, no timer re-fire
        rom[12'h040] = 8'h23; rom[12'h041] = 8'hAA;  // MOV A,#0xAA
        rom[12'h042] = 8'h15;                          // DIS I
        rom[12'h043] = 8'h35;                          // DIS TCNTI
        rom[12'h044] = 8'h93;                          // RETR
        // Timer ISR
        rom[12'h060] = 8'h23; rom[12'h061] = 8'h55;  // MOV A,#0x55
        rom[12'h062] = 8'h93;                          // RETR
        clock_cycles(2);  // JMP 0x009
        clock_cycles(1); clock_cycles(1);                // EN I, EN TCNTI
        clock_cycles(2); clock_cycles(1); clock_cycles(1); // MOV/MOV T/STRT T
        force dut.int_n = 1'b0;
        begin : wait_ext_c
            integer t; t = 0;
            while (!dut.irq_in_progress && t < 200) begin @(posedge clk); #1; t=t+1; end
        end
        clock_cycles(2);  // JMP at 0x003 executes → PC arrives at 0x040
        check_pc(12'h040, "MultiIRQ-C: ext ISR at 0x040");
        release dut.int_n;
        clock_cycles(2); check_acc(8'hAA, "MultiIRQ-C: ext ISR A=0xAA");
        clock_cycles(1);  // DIS I
        clock_cycles(1);  // DIS TCNTI
        clock_cycles(2);  // RETR
        // Settle: DIS TCNTI means irq_en_timer=0 and DIS I means irq_en_ext=0.
        // Neither interrupt can fire. Wait a few cycles for state to propagate.
        begin : settle_c
            integer w; for (w = 0; w < 20; w = w+1) @(posedge clk);
        end
        begin : chk_final_c
            test_num = test_num + 1;
            if (dut.irq_in_progress === 1'b0) begin
                $display("  PASS [%0d] irq_in_progress=0 — ext+DIS_TCNTI sequence clean", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] irq_in_progress set after final RETR", test_num);
                fail_count = fail_count + 1;
            end
        end

        // =====================================================================
        $display("\n--- Group 39: Reset during cycle_2 (mid-instruction) ---");
        // Regression for: ROM latch block was @(posedge clk) without negedge res_n.
        // When reset fired mid-instruction (cycle_2=1), ir and cycle_2 were NOT
        // cleared until the next clock edge. CPU restarted with cycle_2=1, skipping
        // the fetch phase and executing the second half of the interrupted instruction.
        //
        // Also tests: mb_latch cleared to 0 on reset (MB resets to bank 0).
        //
        // Scenario A — reset during 2-cycle instruction (CALL):
        //   1. Execute SEL MB1 (sets mb_latch=1)
        //   2. Start CALL (cycle_2 goes 1 during operand fetch)
        //   3. Assert res_n=0 while cycle_2=1
        //   4. Release res_n=1
        //   5. Verify: mb_latch=0, cycle_2=0, ir=0, pc=0x000
        //
        // Scenario B — mb_latch cleared on reset:
        //   1. Execute SEL MB1 (mb_latch=1)
        //   2. Hard reset
        //   3. Verify mb_latch=0 after reset

        // ── Scenario A: reset during CALL cycle_2 ─────────────────────────
        $display("\n  Scenario A: reset fires during CALL cycle_2");
        fill_nop(); hard_reset();
        rom[12'h000] = 8'hF5;                          // SEL MB1 → mb_latch=1
        rom[12'h001] = 8'h14; rom[12'h002] = 8'h20;   // CALL 0x020 (2-cycle)

        clock_cycles(1);  // SEL MB1 — mb_latch now 1
        begin : check_mb1_set
            test_num = test_num + 1;
            if (dut.mb_latch === 1'b1) begin
                $display("  PASS [%0d] mb_latch=1 after SEL MB1", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] mb_latch not 1 after SEL MB1", test_num);
                fail_count = fail_count + 1;
            end
        end

        // Start CALL — wait for cycle_2=1 (operand fetch in progress)
        @(posedge clk); #1;
        begin : wait_cycle2_a
            integer t; t = 0;
            while (dut.cycle_2 !== 1'b1 && t < 20) begin @(posedge clk); #1; t=t+1; end
        end

        // Assert reset while cycle_2=1
        res_n = 0;
        #1;  // one delta after res_n goes low
        begin : check_async_reset_a
            test_num = test_num + 1;
            if (dut.cycle_2 === 1'b0 && dut.mb_latch === 1'b0) begin
                $display("  PASS [%0d] cycle_2=0 and mb_latch=0 immediately on negedge res_n", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] cycle_2=%0b mb_latch=%0b — not cleared async on res_n low",
                    test_num, dut.cycle_2, dut.mb_latch);
                fail_count = fail_count + 1;
            end
        end

        // Release reset and verify clean restart
        @(posedge clk); #1;
        res_n = 1;

        // Check mb_latch=0 immediately after reset release — BEFORE any
        // instruction executes. rom[0x000]=SEL MB1 would set it back to 1
        // if we wait for clock_cycles(1) first.
        begin : check_mb0_after_reset
            test_num = test_num + 1;
            if (dut.mb_latch === 1'b0) begin
                $display("  PASS [%0d] mb_latch=0 immediately after reset release (MB0 selected)", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] mb_latch=1 after reset — MB not cleared to 0", test_num);
                fail_count = fail_count + 1;
            end
        end

        clock_cycles(1);  // first fetch from 0x000 (SEL MB1 — will set mb_latch=1 again)
        begin : check_restart_a
            test_num = test_num + 1;
            if (dut.pc === 12'h001) begin
                $display("  PASS [%0d] PC=0x001 — CPU fetched first instruction from 0x000", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] PC=0x%03h — expected 0x001 after first fetch", test_num, dut.pc);
                fail_count = fail_count + 1;
            end
        end

        // ── Scenario B: mb_latch cleared by hard_reset ────────────────────
        $display("\n  Scenario B: mb_latch=0 after hard reset from MB1");
        fill_nop(); hard_reset();
        rom[12'h000] = 8'hF5;  // SEL MB1
        clock_cycles(1);        // SEL MB1 executes
        hard_reset();           // reset while mb_latch=1
        begin : check_mb_hard_reset
            test_num = test_num + 1;
            if (dut.mb_latch === 1'b0) begin
                $display("  PASS [%0d] mb_latch=0 after hard_reset from MB1", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] mb_latch=1 after hard_reset — not cleared", test_num);
                fail_count = fail_count + 1;
            end
        end

        // =====================================================================
        $display("\n=============================================================");
        $display("  TEST SUMMARY");
        $display("  Total : %0d", pass_count + fail_count);
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("=============================================================\n");

        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***\n");
        else
            $display("  *** %0d TEST(S) FAILED — see above for details ***\n", fail_count);

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog — prevent infinite loops in simulation
    // -------------------------------------------------------------------------
    initial begin
        #2_000_000; // 2ms sim time limit
        $display("TIMEOUT: simulation exceeded time limit");
        $finish;
    end

endmodule

