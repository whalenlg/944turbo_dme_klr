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
//  Group 34  : Carry propagation through ADD chain
//
//  USAGE
//  -----
//  Simulate with any Verilog-2001 simulator, e.g.:
//    iverilog -o i8048_tb i8048_core_tb.v i8048_core.v && vvp i8048_tb
//
// =============================================================================

`timescale 1ns/1ps

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
        fill_nop(); hard_reset();
        rom[0] = 8'h14; rom[1] = 8'h20;  // CALL 0x020
        rom[12'h20] = 8'h83;                // RET
        clock_cycles(2); check_pc(12'h020, "CALL jumps to 0x020");
        clock_cycles(2); check_pc(12'h002, "RET returns to 0x002");

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
        clock_cycles(1);
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

        // =====================================================================
        $display("\n--- Group 29: OUTL BUS,A / OUTL P1,A / OUTL P2,A ---");
        fill_nop(); hard_reset();
        rom[0] = 8'h23; rom[1] = 8'hCA;  // MOV A,#0xCA
        rom[2] = 8'h02;                   // OUTL BUS,A
        rom[3] = 8'h23; rom[4] = 8'h12;  // MOV A,#0x12
        rom[5] = 8'h39;                   // OUTL P1,A
        rom[6] = 8'h23; rom[7] = 8'h34;  // MOV A,#0x34
        rom[8] = 8'h3A;                   // OUTL P2,A
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

        // =====================================================================
        $display("\n--- Group 30: IN A,P1 / IN A,P2 ---");
        fill_nop(); hard_reset();
        // Pre-load ports by first writing them
        rom[0] = 8'h23; rom[1] = 8'hBB;  // MOV A,#0xBB
        rom[2] = 8'h39;                   // OUTL P1,A  (P1=0xBB)
        rom[3] = 8'h23; rom[4] = 8'hCC;  // MOV A,#0xCC
        rom[5] = 8'h3A;                   // OUTL P2,A  (P2=0xCC)
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
        rom[2] = 8'hF5;                   // SEL RB1
        rom[3] = 8'hB8; rom[4] = 8'h55;  // MOV R0,#0x55 (bank1, addr 0x18)
        rom[5] = 8'hE5;                   // SEL RB0
        // Now R0 in bank0 should still be 0xAA
        clock_cycles(2); // MOV R0,#0xAA bank0
        clock_cycles(1); // SEL RB1
        clock_cycles(2); // MOV R0,#0x55 bank1
        clock_cycles(1); // SEL RB0
        check_ram(7'h00, 8'hAA, "SEL RB0: bank0 R0 preserved as 0xAA");
        check_ram(7'h18, 8'h55, "SEL RB1: bank1 R0 set to 0x55");

        // =====================================================================
        $display("\n--- Group 33: RETR ---");
        fill_nop(); hard_reset();
        // Use CALL to simulate entering an ISR, then RETR to return
        rom[0] = 8'h14; rom[1] = 8'h30;  // CALL 0x030
        rom[12'h30] = 8'h93;                // RETR
        clock_cycles(2); check_pc(12'h030, "CALL before RETR test");
        clock_cycles(2); check_pc(12'h002, "RETR returns to 0x002");

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
        // FINAL SUMMARY
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

