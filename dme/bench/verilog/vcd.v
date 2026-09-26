module dumpvcd(
    input wire        clk,
    input wire [15:0] pc
);

// Top-level testbench path macro.
// -DDASHBOARD_TB : use i8051_dashboard_tb
// -DDME_KLR_TB   : use dme_klr_tb.u_dme (combined DME+KLR mode)
`ifdef DASHBOARD_TB
  `define TB i8051_dashboard_tb
`elsif DME_KLR_TB
  `define TB dme_klr_tb.u_dme
`endif
integer clk_count;
reg [15:0] read_addr,write_addr,last_pc;
reg [159:0] debug_msg [0:8191],last_msg;
reg [255:0] memory_byte_map [0:255],msg;
reg [7:0] memda,bytememdat,bitmemdat;
reg [255:0] memory_bit_map [0:255];
reg [159:0] opcode[0:8191],instr[0:8191],ops[0:8191],opsnums[0:8191];

// ======================================
// Dump Waves to FST File
// ======================================
`define FST "1"
`ifndef VCD_FILE
  // Named .vcd because that's what this actually is: $dumpfile/$dumpvars
  // always emit VCD-format data (no -m fst module is loaded), regardless
  // of the filename. run_dashboard_tests.sh converts this to real FST
  // with vcd2fst after the sim finishes.
  `define VCD_FILE "sim.vcd"
`endif
reg [1023:0] fst_path;

// ============================================================
//  FST hierarchy grouping (DME_DEBUG/DME_DEEP_DEBUG waveform
//  organization)
//  ────────────────────────────────────────────────────────
//  Named-scope signal groups so the debug waveform view organizes
//  related signals under readable sub-scopes instead of one flat
//  list under u_dumpvcd:
//    registers   — r0-r7 (currently-selected bank, per psw[4:3]), sp,
//                  acc, b, and call_depth (nested ACALL/LCALL/interrupt
//                  frames currently active — see the tracker below)
//    reg_bank_0  — rb0_0-rb0_7 (iram[0]-iram[7], bank 0, static)
//    reg_bank_1  — rb1_0-rb1_7 (iram[8]-iram[15], bank 1, static)
//    reg_bank_2  — rb2_0-rb2_7 (iram[16]-iram[23], bank 2, static)
//    reg_bank_3  — rb3_0-rb3_7 (iram[24]-iram[31], bank 3, static)
//    memory      — r00-r7f (all 128 iram bytes)
//    bit_memory  — b00-b2f (bit-addressable iram[20h]-[25h], exploded)
//    asm_debug   — asmlabel, asmopcode, asminstr, asmoperands,
//                  asmoperandnums, msg_addr, msg_count (plus the
//                  per-instruction disassembly always block that
//                  drives them — see below)
//    closed_loop — cl_iram_21, cl_iram_23, cl_enginesync,
//                  cl_fueloffcoast (CL-mode diagnostic aliases)
//    processor_flags — one 1-bit wire per bit of each interrupt/
//                  control SFR (PSW, TCON, PCON, SCON, IE, IP),
//                  named after its conventional 8051 flag mnemonic,
//                  so individual flags can be dragged into the
//                  waveform view without hand bit-slicing the byte
//                  registers.
//  These are the only declarations of these signals — no separate
//  flat copies exist elsewhere in this module. The DME_DEBUG dump
//  below uses $dumpvars(0, `TB.u_dumpvcd) (level 0 = full
//  recursive sweep), so these named groups are automatically swept
//  along with everything else in this module — no extra dumpvars
//  calls needed per group.
// ============================================================
generate
    if (1) begin : registers
        wire [4:0] rb = {`TB.i8051_top.u_cpu.psw[4],
                          `TB.i8051_top.u_cpu.psw[3], 3'b000};
        wire [7:0] r0 = `TB.i8051_top.u_cpu.iram[rb+0];
        wire [7:0] r1 = `TB.i8051_top.u_cpu.iram[rb+1];
        wire [7:0] r2 = `TB.i8051_top.u_cpu.iram[rb+2];
        wire [7:0] r3 = `TB.i8051_top.u_cpu.iram[rb+3];
        wire [7:0] r4 = `TB.i8051_top.u_cpu.iram[rb+4];
        wire [7:0] r5 = `TB.i8051_top.u_cpu.iram[rb+5];
        wire [7:0] r6 = `TB.i8051_top.u_cpu.iram[rb+6];
        wire [7:0] r7 = `TB.i8051_top.u_cpu.iram[rb+7];
        wire [7:0] sp  = `TB.i8051_top.u_cpu.sp;
        wire [7:0] acc = `TB.i8051_top.u_cpu.acc;
        wire [7:0] b   = `TB.i8051_top.u_cpu.b_reg;

        // ------------------------------------------------------------
        // call_depth: counts nested ACALL/LCALL/interrupt frames
        // currently active (decremented on RET/RETI). Two independent
        // trackers on opposite clock edges, so they can't race:
        //   - opcode watcher (negedge clk): fires once per instruction
        //     boundary (cycle_2==0 and pc just changed) and inspects
        //     the freshly-fetched opcode byte read directly from the
        //     EPROM model.
        //   - interrupt-entry watcher (posedge clk): the core's
        //     hardware interrupt dispatch pushes PC directly
        //     (i8051_core.v ~line 418) — no opcode visible in the
        //     normal fetch stream — so entry needs a dedicated watch
        //     on irq_in_progress/irq_hi_active. The 8051 supports at
        //     most two nested levels (one low-priority ISR preempted
        //     by one high-priority ISR). RETI is opcode-visible, so
        //     exit is handled by the same opcode watcher as RET — no
        //     separate exit tracking needed.
        // ------------------------------------------------------------
        integer    call_depth;
        reg [15:0] call_depth_last_pc;
        reg        call_depth_irq_prev, call_depth_hi_prev;

        always @(negedge clk) begin : call_depth_opcode_tracker
            reg [7:0] curr_op;
            if (!`TB.i8051_top.u_cpu.cycle_2 &&
                call_depth_last_pc !== `TB.i8051_top.u_cpu.pc) begin
                curr_op = `TB.i8051_top.u_eprom.mem[`TB.i8051_top.u_cpu.pc[12:0]];
                // ACALL addr11 [opcodes x1: 11h,31h,51h,71h,91h,B1h,D1h,F1h]
                if ((curr_op & 8'h1F) == 8'h11)
                    call_depth = call_depth + 1;
                // LCALL addr16 [12h]
                else if (curr_op == 8'h12)
                    call_depth = call_depth + 1;
                // RET [22h] / RETI [32h]
                else if ((curr_op == 8'h22 || curr_op == 8'h32) && call_depth > 0)
                    call_depth = call_depth - 1;
            end
            call_depth_last_pc = `TB.i8051_top.u_cpu.pc;
        end

        always @(posedge clk) begin : call_depth_irq_tracker
            if (`TB.i8051_top.u_cpu.irq_in_progress && !call_depth_irq_prev)
                call_depth = call_depth + 1;   // outer ISR entry
            else if (`TB.i8051_top.u_cpu.irq_hi_active && !call_depth_hi_prev)
                call_depth = call_depth + 1;   // hi-pri preempts an active lo-pri ISR
            call_depth_irq_prev = `TB.i8051_top.u_cpu.irq_in_progress;
            call_depth_hi_prev  = `TB.i8051_top.u_cpu.irq_hi_active;
        end
    end
endgenerate

generate
    if (1) begin : reg_bank_0
        wire [7:0] rb0_0 = `TB.i8051_top.u_cpu.iram[0];
        wire [7:0] rb0_1 = `TB.i8051_top.u_cpu.iram[1];
        wire [7:0] rb0_2 = `TB.i8051_top.u_cpu.iram[2];
        wire [7:0] rb0_3 = `TB.i8051_top.u_cpu.iram[3];
        wire [7:0] rb0_4 = `TB.i8051_top.u_cpu.iram[4];
        wire [7:0] rb0_5 = `TB.i8051_top.u_cpu.iram[5];
        wire [7:0] rb0_6 = `TB.i8051_top.u_cpu.iram[6];
        wire [7:0] rb0_7 = `TB.i8051_top.u_cpu.iram[7];
    end
endgenerate

generate
    if (1) begin : reg_bank_1
        wire [7:0] rb1_0 = `TB.i8051_top.u_cpu.iram[8];
        wire [7:0] rb1_1 = `TB.i8051_top.u_cpu.iram[9];
        wire [7:0] rb1_2 = `TB.i8051_top.u_cpu.iram[10];
        wire [7:0] rb1_3 = `TB.i8051_top.u_cpu.iram[11];
        wire [7:0] rb1_4 = `TB.i8051_top.u_cpu.iram[12];
        wire [7:0] rb1_5 = `TB.i8051_top.u_cpu.iram[13];
        wire [7:0] rb1_6 = `TB.i8051_top.u_cpu.iram[14];
        wire [7:0] rb1_7 = `TB.i8051_top.u_cpu.iram[15];
    end
endgenerate

generate
    if (1) begin : reg_bank_2
        wire [7:0] rb2_0 = `TB.i8051_top.u_cpu.iram[16];
        wire [7:0] rb2_1 = `TB.i8051_top.u_cpu.iram[17];
        wire [7:0] rb2_2 = `TB.i8051_top.u_cpu.iram[18];
        wire [7:0] rb2_3 = `TB.i8051_top.u_cpu.iram[19];
        wire [7:0] rb2_4 = `TB.i8051_top.u_cpu.iram[20];
        wire [7:0] rb2_5 = `TB.i8051_top.u_cpu.iram[21];
        wire [7:0] rb2_6 = `TB.i8051_top.u_cpu.iram[22];
        wire [7:0] rb2_7 = `TB.i8051_top.u_cpu.iram[23];
    end
endgenerate

generate
    if (1) begin : reg_bank_3
        wire [7:0] rb3_0 = `TB.i8051_top.u_cpu.iram[24];
        wire [7:0] rb3_1 = `TB.i8051_top.u_cpu.iram[25];
        wire [7:0] rb3_2 = `TB.i8051_top.u_cpu.iram[26];
        wire [7:0] rb3_3 = `TB.i8051_top.u_cpu.iram[27];
        wire [7:0] rb3_4 = `TB.i8051_top.u_cpu.iram[28];
        wire [7:0] rb3_5 = `TB.i8051_top.u_cpu.iram[29];
        wire [7:0] rb3_6 = `TB.i8051_top.u_cpu.iram[30];
        wire [7:0] rb3_7 = `TB.i8051_top.u_cpu.iram[31];
    end
endgenerate

generate
    if (1) begin : memory
        wire [7:0] r00 = `TB.i8051_top.u_cpu.iram[7'h00];
        wire [7:0] r01 = `TB.i8051_top.u_cpu.iram[7'h01];
        wire [7:0] r02 = `TB.i8051_top.u_cpu.iram[7'h02];
        wire [7:0] r03 = `TB.i8051_top.u_cpu.iram[7'h03];
        wire [7:0] r04 = `TB.i8051_top.u_cpu.iram[7'h04];
        wire [7:0] r05 = `TB.i8051_top.u_cpu.iram[7'h05];
        wire [7:0] r06 = `TB.i8051_top.u_cpu.iram[7'h06];
        wire [7:0] r07 = `TB.i8051_top.u_cpu.iram[7'h07];
        wire [7:0] r08 = `TB.i8051_top.u_cpu.iram[7'h08];
        wire [7:0] r09 = `TB.i8051_top.u_cpu.iram[7'h09];
        wire [7:0] r0a = `TB.i8051_top.u_cpu.iram[7'h0a];
        wire [7:0] r0b = `TB.i8051_top.u_cpu.iram[7'h0b];
        wire [7:0] r0c = `TB.i8051_top.u_cpu.iram[7'h0c];
        wire [7:0] r0d = `TB.i8051_top.u_cpu.iram[7'h0d];
        wire [7:0] r0e = `TB.i8051_top.u_cpu.iram[7'h0e];
        wire [7:0] r0f = `TB.i8051_top.u_cpu.iram[7'h0f];
        wire [7:0] r10 = `TB.i8051_top.u_cpu.iram[7'h10];
        wire [7:0] r11 = `TB.i8051_top.u_cpu.iram[7'h11];
        wire [7:0] r12 = `TB.i8051_top.u_cpu.iram[7'h12];
        wire [7:0] r13 = `TB.i8051_top.u_cpu.iram[7'h13];
        wire [7:0] r14 = `TB.i8051_top.u_cpu.iram[7'h14];
        wire [7:0] r15 = `TB.i8051_top.u_cpu.iram[7'h15];
        wire [7:0] r16 = `TB.i8051_top.u_cpu.iram[7'h16];
        wire [7:0] r17 = `TB.i8051_top.u_cpu.iram[7'h17];
        wire [7:0] r18 = `TB.i8051_top.u_cpu.iram[7'h18];
        wire [7:0] r19 = `TB.i8051_top.u_cpu.iram[7'h19];
        wire [7:0] r1a = `TB.i8051_top.u_cpu.iram[7'h1a];
        wire [7:0] r1b = `TB.i8051_top.u_cpu.iram[7'h1b];
        wire [7:0] r1c = `TB.i8051_top.u_cpu.iram[7'h1c];
        wire [7:0] r1d = `TB.i8051_top.u_cpu.iram[7'h1d];
        wire [7:0] r1e = `TB.i8051_top.u_cpu.iram[7'h1e];
        wire [7:0] r1f = `TB.i8051_top.u_cpu.iram[7'h1f];
        wire [7:0] r20 = `TB.i8051_top.u_cpu.iram[32];
        wire [7:0] r21 = `TB.i8051_top.u_cpu.iram[33];
        wire [7:0] r22 = `TB.i8051_top.u_cpu.iram[34];
        wire [7:0] r23 = `TB.i8051_top.u_cpu.iram[35];
        wire [7:0] r24 = `TB.i8051_top.u_cpu.iram[36];
        wire [7:0] r25 = `TB.i8051_top.u_cpu.iram[37];
        wire [7:0] r26 = `TB.i8051_top.u_cpu.iram[38];
        wire [7:0] r27 = `TB.i8051_top.u_cpu.iram[39];
        wire [7:0] r28 = `TB.i8051_top.u_cpu.iram[40];
        wire [7:0] r29 = `TB.i8051_top.u_cpu.iram[41];
        wire [7:0] r2a = `TB.i8051_top.u_cpu.iram[42];
        wire [7:0] r2b = `TB.i8051_top.u_cpu.iram[43];
        wire [7:0] r2c = `TB.i8051_top.u_cpu.iram[44];
        wire [7:0] r2d = `TB.i8051_top.u_cpu.iram[45];
        wire [7:0] r2e = `TB.i8051_top.u_cpu.iram[46];
        wire [7:0] r2f = `TB.i8051_top.u_cpu.iram[47];
        wire [7:0] r30 = `TB.i8051_top.u_cpu.iram[48];
        wire [7:0] r31 = `TB.i8051_top.u_cpu.iram[49];
        wire [7:0] r32 = `TB.i8051_top.u_cpu.iram[50];
        wire [7:0] r33 = `TB.i8051_top.u_cpu.iram[51];
        wire [7:0] r34 = `TB.i8051_top.u_cpu.iram[52];
        wire [7:0] r35 = `TB.i8051_top.u_cpu.iram[53];
        wire [7:0] r36 = `TB.i8051_top.u_cpu.iram[54];
        wire [7:0] r37 = `TB.i8051_top.u_cpu.iram[55];
        wire [7:0] r38 = `TB.i8051_top.u_cpu.iram[56];
        wire [7:0] r39 = `TB.i8051_top.u_cpu.iram[57];
        wire [7:0] r3a = `TB.i8051_top.u_cpu.iram[58];
        wire [7:0] r3b = `TB.i8051_top.u_cpu.iram[59];
        wire [7:0] r3c = `TB.i8051_top.u_cpu.iram[7'h3C];
        wire [7:0] r3d = `TB.i8051_top.u_cpu.iram[7'h3D];
        wire [7:0] r3e = `TB.i8051_top.u_cpu.iram[7'h3e];
        wire [7:0] r3f = `TB.i8051_top.u_cpu.iram[63];
        wire [7:0] r40 = `TB.i8051_top.u_cpu.iram[64];
        wire [7:0] r41 = `TB.i8051_top.u_cpu.iram[65];
        wire [7:0] r42 = `TB.i8051_top.u_cpu.iram[66];
        wire [7:0] r43 = `TB.i8051_top.u_cpu.iram[67];
        wire [7:0] r44 = `TB.i8051_top.u_cpu.iram[68];
        wire [7:0] r45 = `TB.i8051_top.u_cpu.iram[69];
        wire [7:0] r46 = `TB.i8051_top.u_cpu.iram[70];
        wire [7:0] r47 = `TB.i8051_top.u_cpu.iram[71];
        wire [7:0] r48 = `TB.i8051_top.u_cpu.iram[72];
        wire [7:0] r49 = `TB.i8051_top.u_cpu.iram[73];
        wire [7:0] r4a = `TB.i8051_top.u_cpu.iram[74];
        wire [7:0] r4b = `TB.i8051_top.u_cpu.iram[75];
        wire [7:0] r4c = `TB.i8051_top.u_cpu.iram[76];
        wire [7:0] r4d = `TB.i8051_top.u_cpu.iram[77];
        wire [7:0] r4e = `TB.i8051_top.u_cpu.iram[78];
        wire [7:0] r4f = `TB.i8051_top.u_cpu.iram[79];
        wire [7:0] r50 = `TB.i8051_top.u_cpu.iram[80];
        wire [7:0] r51 = `TB.i8051_top.u_cpu.iram[81];
        wire [7:0] r52 = `TB.i8051_top.u_cpu.iram[82];
        wire [7:0] r53 = `TB.i8051_top.u_cpu.iram[83];
        wire [7:0] r54 = `TB.i8051_top.u_cpu.iram[84];
        wire [7:0] r55 = `TB.i8051_top.u_cpu.iram[85];
        wire [7:0] r56 = `TB.i8051_top.u_cpu.iram[86];
        wire [7:0] r57 = `TB.i8051_top.u_cpu.iram[87];
        wire [7:0] r58 = `TB.i8051_top.u_cpu.iram[88];
        wire [7:0] r59 = `TB.i8051_top.u_cpu.iram[89];
        wire [7:0] r5a = `TB.i8051_top.u_cpu.iram[90];
        wire [7:0] r5b = `TB.i8051_top.u_cpu.iram[91];
        wire [7:0] r5c = `TB.i8051_top.u_cpu.iram[92];
        wire [7:0] r5d = `TB.i8051_top.u_cpu.iram[93];
        wire [7:0] r5e = `TB.i8051_top.u_cpu.iram[94];
        wire [7:0] r5f = `TB.i8051_top.u_cpu.iram[95];
        wire [7:0] r60 = `TB.i8051_top.u_cpu.iram[96];
        wire [7:0] r61 = `TB.i8051_top.u_cpu.iram[97];
        wire [7:0] r62 = `TB.i8051_top.u_cpu.iram[98];
        wire [7:0] r63 = `TB.i8051_top.u_cpu.iram[99];
        wire [7:0] r64 = `TB.i8051_top.u_cpu.iram[100];
        wire [7:0] r65 = `TB.i8051_top.u_cpu.iram[101];
        wire [7:0] r66 = `TB.i8051_top.u_cpu.iram[102];
        wire [7:0] r67 = `TB.i8051_top.u_cpu.iram[103];
        wire [7:0] r68 = `TB.i8051_top.u_cpu.iram[104];
        wire [7:0] r69 = `TB.i8051_top.u_cpu.iram[105];
        wire [7:0] r6a = `TB.i8051_top.u_cpu.iram[106];
        wire [7:0] r6b = `TB.i8051_top.u_cpu.iram[107];
        wire [7:0] r6c = `TB.i8051_top.u_cpu.iram[108];
        wire [7:0] r6d = `TB.i8051_top.u_cpu.iram[109];
        wire [7:0] r6e = `TB.i8051_top.u_cpu.iram[110];
        wire [7:0] r6f = `TB.i8051_top.u_cpu.iram[111];
        wire [7:0] r70 = `TB.i8051_top.u_cpu.iram[112];
        wire [7:0] r71 = `TB.i8051_top.u_cpu.iram[113];
        wire [7:0] r72 = `TB.i8051_top.u_cpu.iram[114];
        wire [7:0] r73 = `TB.i8051_top.u_cpu.iram[115];
        wire [7:0] r74 = `TB.i8051_top.u_cpu.iram[116];
        wire [7:0] r75 = `TB.i8051_top.u_cpu.iram[117];
        wire [7:0] r76 = `TB.i8051_top.u_cpu.iram[118];
        wire [7:0] r77 = `TB.i8051_top.u_cpu.iram[119];
        wire [7:0] r78 = `TB.i8051_top.u_cpu.iram[120];
        wire [7:0] r79 = `TB.i8051_top.u_cpu.iram[121];
        wire [7:0] r7a = `TB.i8051_top.u_cpu.iram[122];
        wire [7:0] r7b = `TB.i8051_top.u_cpu.iram[123];
        wire [7:0] r7c = `TB.i8051_top.u_cpu.iram[124];
        wire [7:0] r7d = `TB.i8051_top.u_cpu.iram[125];
        wire [7:0] r7e = `TB.i8051_top.u_cpu.iram[126];
        wire [7:0] r7f = `TB.i8051_top.u_cpu.iram[127];
    end
endgenerate

generate
    if (1) begin : bit_memory
        wire b00 = `TB.i8051_top.u_cpu.iram[32][0];
        wire b01 = `TB.i8051_top.u_cpu.iram[32][1];
        wire b02 = `TB.i8051_top.u_cpu.iram[32][2];
        wire b03 = `TB.i8051_top.u_cpu.iram[32][3];
        wire b04 = `TB.i8051_top.u_cpu.iram[32][4];
        wire b05 = `TB.i8051_top.u_cpu.iram[32][5];
        wire b06 = `TB.i8051_top.u_cpu.iram[32][6];
        wire b07 = `TB.i8051_top.u_cpu.iram[32][7];
        wire b08 = `TB.i8051_top.u_cpu.iram[33][0];
        wire b09 = `TB.i8051_top.u_cpu.iram[33][1];
        wire b0a = `TB.i8051_top.u_cpu.iram[33][2];
        wire b0b = `TB.i8051_top.u_cpu.iram[33][3];
        wire b0c = `TB.i8051_top.u_cpu.iram[33][4];
        wire b0d = `TB.i8051_top.u_cpu.iram[33][5];
        wire b0e = `TB.i8051_top.u_cpu.iram[33][6];
        wire b0f = `TB.i8051_top.u_cpu.iram[33][7];
        wire b10 = `TB.i8051_top.u_cpu.iram[34][0];
        wire b11 = `TB.i8051_top.u_cpu.iram[34][1];
        wire b12 = `TB.i8051_top.u_cpu.iram[34][2];
        wire b13 = `TB.i8051_top.u_cpu.iram[34][3];
        wire b14 = `TB.i8051_top.u_cpu.iram[34][4];
        wire b15 = `TB.i8051_top.u_cpu.iram[34][5];
        wire b16 = `TB.i8051_top.u_cpu.iram[34][6];
        wire b17 = `TB.i8051_top.u_cpu.iram[34][7];
        wire b18 = `TB.i8051_top.u_cpu.iram[35][0];
        wire b19 = `TB.i8051_top.u_cpu.iram[35][1];
        wire b1a = `TB.i8051_top.u_cpu.iram[35][2];
        wire b1b = `TB.i8051_top.u_cpu.iram[35][3];
        wire b1c = `TB.i8051_top.u_cpu.iram[35][4];
        wire b1d = `TB.i8051_top.u_cpu.iram[35][5];
        wire b1e = `TB.i8051_top.u_cpu.iram[35][6];
        wire b1f = `TB.i8051_top.u_cpu.iram[35][7];
        wire b20 = `TB.i8051_top.u_cpu.iram[36][0];
        wire b21 = `TB.i8051_top.u_cpu.iram[36][1];
        wire b22 = `TB.i8051_top.u_cpu.iram[36][2];
        wire b23 = `TB.i8051_top.u_cpu.iram[36][3];
        wire b24 = `TB.i8051_top.u_cpu.iram[36][4];
        wire b25 = `TB.i8051_top.u_cpu.iram[36][5];
        wire b26 = `TB.i8051_top.u_cpu.iram[36][6];
        wire b27 = `TB.i8051_top.u_cpu.iram[36][7];
        wire b28 = `TB.i8051_top.u_cpu.iram[37][0];
        wire b29 = `TB.i8051_top.u_cpu.iram[37][1];
        wire b2a = `TB.i8051_top.u_cpu.iram[37][2];
        wire b2b = `TB.i8051_top.u_cpu.iram[37][3];
        wire b2c = `TB.i8051_top.u_cpu.iram[37][4];
        wire b2d = `TB.i8051_top.u_cpu.iram[37][5];
        wire b2e = `TB.i8051_top.u_cpu.iram[37][6];
        wire b2f = `TB.i8051_top.u_cpu.iram[37][7];
    end
endgenerate

generate
    if (1) begin : closed_loop
        // CL-mode diagnostic aliases (so individual iram bytes appear in
        // the VCD; $dumpvars does not capture array elements directly)
        wire [7:0] cl_iram_21    = `TB.i8051_top.u_cpu.iram[8'h21];  // EngineSync byte
        wire [7:0] cl_iram_23    = `TB.i8051_top.u_cpu.iram[8'h23];  // FuelOffCoast byte
        wire       cl_enginesync = cl_iram_21[0];                    // iram[21h].0
        wire       cl_fueloffcoast = cl_iram_23[5];                  // iram[23h].5
    end
endgenerate

generate
    if (1) begin : processor_flags
        // One 1-bit wire per bit of each interrupt/control SFR, named
        // after its conventional 8051 flag mnemonic. "rsvd_bN" marks a
        // bit with no defined function in this core (still exposed for
        // completeness — e.g. software may stash scratch state there).
        //
        // PSW (D0h): CY AC F0 RS1 RS0 OV rsvd_b1 P
        wire psw_cy      = `TB.i8051_top.u_cpu.psw[7];
        wire psw_ac      = `TB.i8051_top.u_cpu.psw[6];
        wire psw_f0      = `TB.i8051_top.u_cpu.psw[5];
        wire psw_rs1     = `TB.i8051_top.u_cpu.psw[4];
        wire psw_rs0     = `TB.i8051_top.u_cpu.psw[3];
        wire psw_ov      = `TB.i8051_top.u_cpu.psw[2];
        wire psw_rsvd_b1 = `TB.i8051_top.u_cpu.psw[1];
        wire psw_p       = `TB.i8051_top.u_cpu.psw[0];

        // TCON (88h): TF1 TR1 TF0 TR0 IE1 IT1 IE0 IT0
        wire tcon_tf1 = `TB.i8051_top.u_cpu.tcon[7];
        wire tcon_tr1 = `TB.i8051_top.u_cpu.tcon[6];
        wire tcon_tf0 = `TB.i8051_top.u_cpu.tcon[5];
        wire tcon_tr0 = `TB.i8051_top.u_cpu.tcon[4];
        wire tcon_ie1 = `TB.i8051_top.u_cpu.tcon[3];
        wire tcon_it1 = `TB.i8051_top.u_cpu.tcon[2];
        wire tcon_ie0 = `TB.i8051_top.u_cpu.tcon[1];
        wire tcon_it0 = `TB.i8051_top.u_cpu.tcon[0];

        // PCON (87h): SMOD rsvd_b6 rsvd_b5 rsvd_b4 GF1 GF0 PD IDL
        wire pcon_smod    = `TB.i8051_top.u_cpu.pcon[7];
        wire pcon_rsvd_b6 = `TB.i8051_top.u_cpu.pcon[6];
        wire pcon_rsvd_b5 = `TB.i8051_top.u_cpu.pcon[5];
        wire pcon_rsvd_b4 = `TB.i8051_top.u_cpu.pcon[4];
        wire pcon_gf1     = `TB.i8051_top.u_cpu.pcon[3];
        wire pcon_gf0     = `TB.i8051_top.u_cpu.pcon[2];
        wire pcon_pd      = `TB.i8051_top.u_cpu.pcon[1];
        wire pcon_idl     = `TB.i8051_top.u_cpu.pcon[0];

        // SCON (98h): SM0 SM1 SM2 REN TB8 RB8 TI RI
        wire scon_sm0 = `TB.i8051_top.u_cpu.scon[7];
        wire scon_sm1 = `TB.i8051_top.u_cpu.scon[6];
        wire scon_sm2 = `TB.i8051_top.u_cpu.scon[5];
        wire scon_ren = `TB.i8051_top.u_cpu.scon[4];
        wire scon_tb8 = `TB.i8051_top.u_cpu.scon[3];
        wire scon_rb8 = `TB.i8051_top.u_cpu.scon[2];
        wire scon_ti  = `TB.i8051_top.u_cpu.scon[1];
        wire scon_ri  = `TB.i8051_top.u_cpu.scon[0];

        // IE (A8h): EA rsvd_b6 rsvd_b5 ES ET1 EX1 ET0 EX0
        wire ie_ea      = `TB.i8051_top.u_cpu.ie[7];
        wire ie_rsvd_b6 = `TB.i8051_top.u_cpu.ie[6];
        wire ie_rsvd_b5 = `TB.i8051_top.u_cpu.ie[5];
        wire ie_es      = `TB.i8051_top.u_cpu.ie[4];
        wire ie_et1     = `TB.i8051_top.u_cpu.ie[3];
        wire ie_ex1     = `TB.i8051_top.u_cpu.ie[2];
        wire ie_et0     = `TB.i8051_top.u_cpu.ie[1];
        wire ie_ex0     = `TB.i8051_top.u_cpu.ie[0];

        // IP (B8h): rsvd_b7 rsvd_b6 rsvd_b5 PS PT1 PX1 PT0 PX0
        wire ip_rsvd_b7 = `TB.i8051_top.u_cpu.ip[7];
        wire ip_rsvd_b6 = `TB.i8051_top.u_cpu.ip[6];
        wire ip_rsvd_b5 = `TB.i8051_top.u_cpu.ip[5];
        wire ip_ps      = `TB.i8051_top.u_cpu.ip[4];
        wire ip_pt1     = `TB.i8051_top.u_cpu.ip[3];
        wire ip_px1     = `TB.i8051_top.u_cpu.ip[2];
        wire ip_pt0     = `TB.i8051_top.u_cpu.ip[1];
        wire ip_px0     = `TB.i8051_top.u_cpu.ip[0];
    end
endgenerate

generate
    if (1) begin : asm_debug
        reg [159:0] asmlabel, asmopcode, asminstr, asmoperands, asmoperandnums;
        reg [15:0]  msg_addr;
        integer     msg_count;

`ifdef DME_DEBUG
        always @(negedge clk) begin
            clk_count <= clk_count + 1;
            msg_addr    = pc;
            asmlabel    = debug_msg[msg_addr];
            asmopcode   = opcode[msg_addr];
            asminstr    = instr[msg_addr][159:120];
            asmoperands = ops[msg_addr];
            asmoperandnums=opsnums[msg_addr];
            if (last_pc !== msg_addr)
                 begin
                    if (last_msg !== asmlabel)
                      begin
                       msg_count=1;
                      end
                    else
                      begin
                       msg_count=msg_count+1;
                      end
                    if ((asmlabel[159:152] != 8'h20))
                       $display("DME: %15s%8d PC: %4h %s %s\tOPCODE:%s\t %s\t count:%8d", asmlabel,clk_count,msg_addr,asminstr,asmoperands,asmopcode,asmoperandnums, msg_count);
                    else
                       $display("DME: \t\t%12d PC: %4h %s %s\tOPCODE:%s\t %s\t count:%8d", clk_count,msg_addr,asminstr,asmoperands,asmopcode,asmoperandnums, msg_count);
                    last_msg=asmlabel;
                 end
             last_pc=msg_addr;

        end
`endif
    end
endgenerate

// data_from_rom: 0 if the instruction-fetch address (pc) equals the
// external bus address (`TB.i8051_top.u_cpu.addr_bus); addr_bus itself
// otherwise. During a normal instruction fetch the bus address tracks
// pc, so this reads 0; during a MOVX-style data fetch from EPROM,
// addr_bus diverges from the current pc and this reads the actual
// data-fetch address directly — a quick way to spot data-fetch
// addresses in the waveform separately from instruction fetches.
// 16-bit, matching both pc and addr_bus's own width. Module-level
// continuous assignment — must NOT be inside the initial block below
// (which is a procedural context; a wire declaration with continuous
// assignment isn't legal there — this caused the original "syntax
// error... l-value" compile failure when it was placed inline with
// the $dumpvars calls).
`ifdef DME_DEEP_DEBUG
wire [15:0] data_from_rom = (pc == `TB.i8051_top.u_cpu.addr_bus)
                             ? 16'h0000
                             : `TB.i8051_top.u_cpu.addr_bus;
`endif


initial
    begin

//mem traces

// ── Simulator identification ────────────────────────────────
`ifdef VERILATOR
$display("DME: [SIM] Verilator");
`else
$display("DME: [SIM] iverilog");
`endif
if (!$value$plusargs("fst=%s", fst_path))
    fst_path = `VCD_FILE;
if (fst_path != "/dev/null") begin
    $display("DME: FST Dump enabled -> %0s", fst_path);
    $dumpfile(fst_path);
    $dumpon;
end else begin
    $display("DME: FST Dump suppressed (/dev/null)");
end
//$dumpvars(1,clk_count);
//$dumpvars(1,`TB.var_interrupt_generator_1);
`ifdef DME_DEBUG
`define DO_DME_DEBUG_DUMP
`endif
`ifdef DME_DEEP_DEBUG
`define DO_DME_DEBUG_DUMP
`endif

`ifdef DO_DME_DEBUG_DUMP
$dumpvars(1,`TB);
$dumpvars(0,`TB.u_dumpvcd);
$dumpvars(0,`TB.adc_delay_8_1);
// Dump the full RPM-ramp stimulus generator (level 0 = all internal regs:
// current_rpm, period_current, tick_counter, counter, ref_low_cnt,
// ref_low_active, ref_fired_this_rev, int_0/int_1).  Gate matches the
// -DRPMRAMP flag passed by the run scripts (was misspelled RAMPRPM, so it
// never fired before).
`ifdef RPMRAMP
$dumpvars(0,`TB.var_interrupt_generator_1);
`endif
`ifdef FLATRPM
$dumpvars(0,`TB.interrupt_generator_1);
`endif
`endif

// CPU_Core: the full CPU-core sweep is DME_DEEP_DEBUG-only, not plain
// DME_DEBUG — it's a lot of signal volume (every SFR, timer, interrupt,
// and internal temp reg) for a level most debugging doesn't need. Plain
// DME_DEBUG still gets the handful of individual CPU-core signals below
// (ir/pc/acc/t0/t1/irq_in_progress), same as a no-debug build.
`ifdef DME_DEEP_DEBUG
$dumpvars(1,`TB.i8051_top.u_cpu);
`endif

// phase_status: the STATUS-display shadow regs (isv_shadow,
// afm_raw_shadow, coolant_shadow, airtemp_shadow) and the ph_*
// phase-transition/watchdog edge state, moved out of $dumpvars(1,`TB)'s
// direct reach into their own named scope (see i8051_dashboard_tb.v) —
// same DME_DEEP_DEBUG-only treatment as CPU_Core above. The underlying
// $display logic that drives DME: [PHASE]/[STATUS] log lines is
// unaffected and keeps running in every build; this only controls
// whether these regs also land in the FST.
`ifdef DME_DEEP_DEBUG
$dumpvars(1,`TB.phase_status);
`endif

// CPU-core defaults: traced except when DME_DEEP_DEBUG's broader CPU_Core
// sweep above already covers them.
`ifndef DME_DEEP_DEBUG
$dumpvars(1,`TB.i8051_top.u_cpu.ir);
$dumpvars(1,`TB.i8051_top.u_cpu.pc);
$dumpvars(1,`TB.i8051_top.u_cpu.acc);
$dumpvars(1,`TB.i8051_top.u_cpu.t0);
$dumpvars(1,`TB.i8051_top.u_cpu.t1);
$dumpvars(1,`TB.i8051_top.u_cpu.irq_in_progress);
`endif // !DME_DEEP_DEBUG

// Testbench-level defaults: always traced except when the broader
// $dumpvars(1,`TB) sweep above (DME_DEBUG or DME_DEEP_DEBUG) already
// covers them — re-listing them in that case would just produce a
// "skipping signal ... it was previously included" VCD warning per
// signal.
`ifndef DO_DME_DEBUG_DUMP
//$dumpvars(1,`TB.xadc_data_out [7:0]);
//$dumpvars(1,`TB.xdata [7:0]);
//$dumpvars(1,`TB.xwr_n);
//$dumpvars(1,`TB.xrd_n);
//$dumpvars(1,`TB.xaddr [15:0]);
$dumpvars(1,`TB.speed_sensor);
$dumpvars(1,`TB.reference_sensor);
$dumpvars(1,`TB.p3_in [7:0]);
$dumpvars(1,`TB.p3 [7:0]);
$dumpvars(1,`TB.p2 [7:0]);
$dumpvars(1,`TB.p1 [7:0]);
$dumpvars(1,`TB.p0 [7:0]);
$dumpvars(1,`TB.o2_7);
$dumpvars(1,`TB.o2_6);
$dumpvars(1,`TB.ale);
$dumpvars(1,`TB.afm_wiper [7:0]);
$dumpvars(1,`TB.A_5_KLR_ign_out);
`ifdef TEST_ISV_COLD_IDLE
$dumpvars(1,`TB.coolant_dynamic);
`endif
$dumpvars(1,`TB.A_4_idle_speed);
$dumpvars(1,`TB.A_3_unused_p1_3);
$dumpvars(1,`TB.A_2_dme_relay);
$dumpvars(1,`TB.A_1_tach_pulse);
$dumpvars(1,`TB.A_0_inj_driver);
$dumpvars(1,`TB.tdc);
`endif // !DO_DME_DEBUG_DUMP
//$dumpvars(1,clk);




    clk_count=0;
    last_pc=16'hFFFF;
    last_msg="FFFF";
    asm_debug.msg_count=1;
    registers.call_depth=0;
    registers.call_depth_last_pc=16'hFFFF;
    registers.call_depth_irq_prev=1'b0;
    registers.call_depth_hi_prev=1'b0;
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/test_sim.hex",debug_msg);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/memory_byte_map.hex",memory_byte_map);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/memory_bit_map.hex",memory_bit_map);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_opcode_ins.hex",opcode);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_instr.hex",instr);
 //   $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_operands.hex",ops);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_operand_mapped.hex",ops);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_operands_numeric.hex",opsnums);
    end

//DEBUG — ISV P1.4 deadlock detector
// Threshold scales with prpm (iram[37h]) so high-RPM tests don't false-positive.
// Guard: skip entirely when prpm<=0x10 (cranking/just-synced, engine not
// yet turning fast enough for the idle/ISV loop's heartbeat cadence to be
// meaningful) to avoid false positives at very low RPM.
// At idle (prpm~0x15): threshold = 0x84 (original calibration).
// Formula: thresh = 0x84 * prpm / 0x15  (integer divide)
// Disabled under Verilator (see `ifndef VERILATOR below) — this watchdog
// is iverilog-only. validate_dash_log.py filters out any remaining
// X-valued (uninitialized-state) DEADLOCK line and WARNs on whatever's
// left, on the iverilog runs that still produce it.
`ifndef VERILATOR
always @(posedge clk) begin : isv_deadlock_detect
    reg [15:0] dl_thresh;
    dl_thresh = (16'h0084 * {8'h00, `TB.i8051_top.u_cpu.iram[7'h37]}) / 16'h0015;
    if (`TB.rst &&
        `TB.i8051_top.u_cpu.iram[7'h37] > 8'h10 &&  // skip when prpm<=10h
        !`TB.i8051_top.u_cpu.p1[4] &&
        {8'h00, `TB.i8051_top.u_cpu.iram[7'h36]} > dl_thresh)
        $display("DME: [DEADLOCK] cycle=%0d P1.4=0, iram[36h]=0x%02X iram[7Fh]=0x%02X thresh=0x%02X",
                 `TB.i8051_top.u_cpu.cycle_count,
                 `TB.i8051_top.u_cpu.iram[7'h36],
                 `TB.i8051_top.u_cpu.iram[7'h7F],
                 dl_thresh[7:0]);
end
`endif


endmodule
