// ============================================================
//  klr_vcd.v  —  VCD / disassembly monitor for KLR simulation
//
//  Derived from vcd.v — only the $dumpvars hierarchy paths and
//  module name differ from the original DME version.
//
//  RAM visibility strategy
//  ────────────────────────
//  128 continuous-assign wires (ram_00–ram_7f) mirror every byte
//  of the 8049 internal RAM.  Because they live in this module and
//  this module is swept by $dumpvars(1,dme_klr_tb.u_klr_vcd), every
//  RAM location is visible in the VCD waveform viewer at every
//  simulation timestep — no sampling gaps.
//
//  Per-instruction $display
//  ─────────────────────────
//  On every PC change the always block prints:
//    • the disassembly line (existing)
//    • R0–R7 both banks (existing)
//    • a labelled one-liner for each address of interest
// ============================================================

module klr_dumpvcd_combined();

`define MEMMAX 4095
integer clk_count, msg_count;
reg [15:0]  read_addr, write_addr, msg_addr, last_pc;

// ── Call depth tracking ───────────────────────────────────────
// Mirrors SP (psw[2:0]) with one cycle of lookahead so we can
// print the full stack frame BEFORE the return destroys it.
integer call_depth;
reg [11:0] call_stack [0:7];   // shadow return addresses for display
reg [159:0] debug_msg [0:`MEMMAX], asmlabel, last_msg;
reg [255:0] memory_byte_map [0:255], msg;
reg [7:0]   memda, bytememdat, bitmemdat;
reg [255:0] memory_bit_map [0:255];
reg [159:0] opcode[0:`MEMMAX], instr[0:`MEMMAX],
            ops[0:`MEMMAX], opsnums[0:`MEMMAX],
            asmopcode, asminstr, asmoperands, asmoperandnums;

// ============================================================
//  RAM mirror wires  (ram_00 – ram_7f)
//
//  Each wire is a continuous alias of the corresponding RAM cell
//  inside dme_klr_tb.top_klr.i8048_core_1.ram[].  Being signals in this
//  module they are captured by $dumpvars(1,dme_klr_tb.u_klr_vcd) at
//  every timestep, making all 128 bytes permanently visible in
//  the VCD waveform viewer without any sampling gaps.
//
//  The always block below references these wires by name
//  (e.g. ram_24) rather than hierarchical paths, for readability.
// ============================================================
`define RAM dme_klr_tb.top_klr.i8048_core_1.ram

// 0x00 – 0x0F  (Bank 0 R0–R7 = ram_00–ram_07; Stack = ram_08–ram_17)
wire [7:0] ram_00 = `RAM[8'h00]; wire [7:0] ram_01 = `RAM[8'h01];
wire [7:0] ram_02 = `RAM[8'h02]; wire [7:0] ram_03 = `RAM[8'h03];
wire [7:0] ram_04 = `RAM[8'h04]; wire [7:0] ram_05 = `RAM[8'h05];
wire [7:0] ram_06 = `RAM[8'h06]; wire [7:0] ram_07 = `RAM[8'h07];
wire [7:0] ram_08 = `RAM[8'h08]; wire [7:0] ram_09 = `RAM[8'h09];
wire [7:0] ram_0a = `RAM[8'h0a]; wire [7:0] ram_0b = `RAM[8'h0b];
wire [7:0] ram_0c = `RAM[8'h0c]; wire [7:0] ram_0d = `RAM[8'h0d];
wire [7:0] ram_0e = `RAM[8'h0e]; wire [7:0] ram_0f = `RAM[8'h0f];

// 0x10 – 0x1F  (Stack cont.; Bank 1 R0–R7 = ram_18–ram_1f)
wire [7:0] ram_10 = `RAM[8'h10]; wire [7:0] ram_11 = `RAM[8'h11];
wire [7:0] ram_12 = `RAM[8'h12]; wire [7:0] ram_13 = `RAM[8'h13];
wire [7:0] ram_14 = `RAM[8'h14]; wire [7:0] ram_15 = `RAM[8'h15];
wire [7:0] ram_16 = `RAM[8'h16]; wire [7:0] ram_17 = `RAM[8'h17];
wire [7:0] ram_18 = `RAM[8'h18]; wire [7:0] ram_19 = `RAM[8'h19];
wire [7:0] ram_1a = `RAM[8'h1a]; wire [7:0] ram_1b = `RAM[8'h1b];
wire [7:0] ram_1c = `RAM[8'h1c]; wire [7:0] ram_1d = `RAM[8'h1d];
wire [7:0] ram_1e = `RAM[8'h1e]; wire [7:0] ram_1f = `RAM[8'h1f];

// 0x20 – 0x2F
wire [7:0] ram_20 = `RAM[8'h20]; wire [7:0] ram_21 = `RAM[8'h21];
wire [7:0] ram_22 = `RAM[8'h22]; wire [7:0] ram_23 = `RAM[8'h23];
wire [7:0] ram_24 = `RAM[8'h24]; wire [7:0] ram_25 = `RAM[8'h25];
wire [7:0] ram_26 = `RAM[8'h26]; wire [7:0] ram_27 = `RAM[8'h27];
wire [7:0] ram_28 = `RAM[8'h28]; wire [7:0] ram_29 = `RAM[8'h29];
wire [7:0] ram_2a = `RAM[8'h2a]; wire [7:0] ram_2b = `RAM[8'h2b];
wire [7:0] ram_2c = `RAM[8'h2c]; wire [7:0] ram_2d = `RAM[8'h2d];
wire [7:0] ram_2e = `RAM[8'h2e]; wire [7:0] ram_2f = `RAM[8'h2f];

// 0x30 – 0x3F
wire [7:0] ram_30 = `RAM[8'h30]; wire [7:0] ram_31 = `RAM[8'h31];
wire [7:0] ram_32 = `RAM[8'h32]; wire [7:0] ram_33 = `RAM[8'h33];
wire [7:0] ram_34 = `RAM[8'h34]; wire [7:0] ram_35 = `RAM[8'h35];
wire [7:0] ram_36 = `RAM[8'h36]; wire [7:0] ram_37 = `RAM[8'h37];
wire [7:0] ram_38 = `RAM[8'h38]; wire [7:0] ram_39 = `RAM[8'h39];
wire [7:0] ram_3a = `RAM[8'h3a]; wire [7:0] ram_3b = `RAM[8'h3b];
wire [7:0] ram_3c = `RAM[8'h3c]; wire [7:0] ram_3d = `RAM[8'h3d];
wire [7:0] ram_3e = `RAM[8'h3e]; wire [7:0] ram_3f = `RAM[8'h3f];

// 0x40 – 0x4F
wire [7:0] ram_40 = `RAM[8'h40]; wire [7:0] ram_41 = `RAM[8'h41];
wire [7:0] ram_42 = `RAM[8'h42]; wire [7:0] ram_43 = `RAM[8'h43];
wire [7:0] ram_44 = `RAM[8'h44]; wire [7:0] ram_45 = `RAM[8'h45];
wire [7:0] ram_46 = `RAM[8'h46]; wire [7:0] ram_47 = `RAM[8'h47];
wire [7:0] ram_48 = `RAM[8'h48]; wire [7:0] ram_49 = `RAM[8'h49];
wire [7:0] ram_4a = `RAM[8'h4a]; wire [7:0] ram_4b = `RAM[8'h4b];
wire [7:0] ram_4c = `RAM[8'h4c]; wire [7:0] ram_4d = `RAM[8'h4d];
wire [7:0] ram_4e = `RAM[8'h4e]; wire [7:0] ram_4f = `RAM[8'h4f];

// 0x50 – 0x5F
wire [7:0] ram_50 = `RAM[8'h50]; wire [7:0] ram_51 = `RAM[8'h51];
wire [7:0] ram_52 = `RAM[8'h52]; wire [7:0] ram_53 = `RAM[8'h53];
wire [7:0] ram_54 = `RAM[8'h54]; wire [7:0] ram_55 = `RAM[8'h55];
wire [7:0] ram_56 = `RAM[8'h56]; wire [7:0] ram_57 = `RAM[8'h57];
wire [7:0] ram_58 = `RAM[8'h58]; wire [7:0] ram_59 = `RAM[8'h59];
wire [7:0] ram_5a = `RAM[8'h5a]; wire [7:0] ram_5b = `RAM[8'h5b];
wire [7:0] ram_5c = `RAM[8'h5c]; wire [7:0] ram_5d = `RAM[8'h5d];
wire [7:0] ram_5e = `RAM[8'h5e]; wire [7:0] ram_5f = `RAM[8'h5f];

// 0x60 – 0x6F
wire [7:0] ram_60 = `RAM[8'h60]; wire [7:0] ram_61 = `RAM[8'h61];
wire [7:0] ram_62 = `RAM[8'h62]; wire [7:0] ram_63 = `RAM[8'h63];
wire [7:0] ram_64 = `RAM[8'h64]; wire [7:0] ram_65 = `RAM[8'h65];
wire [7:0] ram_66 = `RAM[8'h66]; wire [7:0] ram_67 = `RAM[8'h67];
wire [7:0] ram_68 = `RAM[8'h68]; wire [7:0] ram_69 = `RAM[8'h69];
wire [7:0] ram_6a = `RAM[8'h6a]; wire [7:0] ram_6b = `RAM[8'h6b];
wire [7:0] ram_6c = `RAM[8'h6c]; wire [7:0] ram_6d = `RAM[8'h6d];
wire [7:0] ram_6e = `RAM[8'h6e]; wire [7:0] ram_6f = `RAM[8'h6f];

// 0x70 – 0x7F
wire [7:0] ram_70 = `RAM[8'h70]; wire [7:0] ram_71 = `RAM[8'h71];
wire [7:0] ram_72 = `RAM[8'h72]; wire [7:0] ram_73 = `RAM[8'h73];
wire [7:0] ram_74 = `RAM[8'h74]; wire [7:0] ram_75 = `RAM[8'h75];
wire [7:0] ram_76 = `RAM[8'h76]; wire [7:0] ram_77 = `RAM[8'h77];
wire [7:0] ram_78 = `RAM[8'h78]; wire [7:0] ram_79 = `RAM[8'h79];
wire [7:0] ram_7a = `RAM[8'h7a]; wire [7:0] ram_7b = `RAM[8'h7b];
wire [7:0] ram_7c = `RAM[8'h7c]; wire [7:0] ram_7d = `RAM[8'h7d];
wire [7:0] ram_7e = `RAM[8'h7e]; wire [7:0] ram_7f = `RAM[8'h7f];

// ============================================================
//  Interrupt entry tracker
//  service_interrupt() pushes to the stack and sets irq_in_progress.
//  The shadow call tracker only watches CALL opcodes, so it misses
//  interrupt-driven stack pushes.  This block synchronises depth
//  with SP on every interrupt entry and exit.
// ============================================================
always @(posedge dme_klr_tb.top_klr.i8048_core_1.irq_in_progress) begin
    call_depth = call_depth + 1;
    $display(">>> IRQ ENTRY: retaddr=ram[%02h/%02h]=%02h%02h  → ISR",
        ({dme_klr_tb.top_klr.i8048_core_1.psw[2:0] - 1'b1, 1'b0} + 6'h08),
        ({dme_klr_tb.top_klr.i8048_core_1.psw[2:0] - 1'b1, 1'b1} + 6'h08),
        `RAM[{dme_klr_tb.top_klr.i8048_core_1.psw[2:0] - 1'b1, 1'b1} + 6'h08],
        `RAM[{dme_klr_tb.top_klr.i8048_core_1.psw[2:0] - 1'b1, 1'b0} + 6'h08]);
end
//  Logs whenever the crank trigger fires (res_n goes low) so
//  we can see exactly what PC, SP, and IR state was interrupted.
// ============================================================
always @(negedge dme_klr_tb.top_klr.res_n) begin
    $display("\n>>> TRIGGER RESET fired at t=%0t", $time);
    $display("    PC=%03h  IR=%02h  irq_in_progress=%0b  cycle_2=%0b",
        dme_klr_tb.top_klr.i8048_core_1.pc,
        dme_klr_tb.top_klr.i8048_core_1.ir,
        dme_klr_tb.top_klr.i8048_core_1.irq_in_progress,
        dme_klr_tb.top_klr.i8048_core_1.cycle_2);
    $display("    Stack slots: [08]=%02h [09]=%02h [0A]=%02h [0B]=%02h [0C]=%02h [0D]=%02h [0E]=%02h [0F]=%02h",
        `RAM[8'h08], `RAM[8'h09], `RAM[8'h0a], `RAM[8'h0b],
        `RAM[8'h0c], `RAM[8'h0d], `RAM[8'h0e], `RAM[8'h0f]);
    if (dme_klr_tb.top_klr.i8048_core_1.psw[2:0] != 0)
        $display("    *** Reset with SP!=0 — stack frame(s) will be orphaned ***");
    if (dme_klr_tb.top_klr.i8048_core_1.cycle_2)
        $display("    *** Reset during 2-cycle instruction (cycle_2=1) — instruction was mid-execution ***");
end
`define VCD "1"
`define VCD_FILE "951klr_combined.vcd"

initial begin
`ifdef VCD
//`define VCD_FILE "951dme.vcd"
`endif
    $display("VCD Dump enabled");
    $dumpfile(`VCD_FILE);
    $dumpon;
    $dumpvars(1, dme_klr_tb);
    $dumpvars(1, dme_klr_tb.top_klr);
    $dumpvars(1, dme_klr_tb.u_klr_vcd);   // sweeps all 128 ram_XX wires
    $dumpvars(1, dme_klr_tb.top_klr.i8048_core_1);
    $dumpvars(1, dme_klr_tb.top_klr.u_adc_mux);   // ADC pipeline internals

`ifdef RAMPRPM $dumpvars(1, oc8048_tb.var_interrupt_generator_1);
`ifdef FLATRPM $dumpvars(1, oc8048_tb.interrupt_generator_1);
`endif
`endif

    clk_count = 0;
    last_pc   = 16'hFFFF;
    last_msg  = "FFFF";
    msg_count = 1;
    call_depth = 0;
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/test_sim.hex",             debug_msg);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/memory_byte_map.hex",      memory_byte_map);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_opcode_ins.hex",       opcode);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_instr.hex",            instr);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_operands.hex",         ops);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_operands_numeric.hex", opsnums);
end

// ============================================================
//  Per-instruction disassembly + register + key address display
// ============================================================
always @(negedge dme_klr_tb.top_klr.clk) begin
    clk_count      <= clk_count + 1;
    msg_addr        = dme_klr_tb.top_klr.i8048_core_1.pc;
    asmlabel        = debug_msg[msg_addr];
    asmopcode       = opcode[msg_addr];
    asminstr        = instr[msg_addr][159:120];
    asmoperands     = ops[msg_addr];
    asmoperandnums  = opsnums[msg_addr];

    if (last_pc !== msg_addr && !dme_klr_tb.top_klr.i8048_core_1.cycle_2) begin

        if (last_msg !== asmlabel)
            msg_count = 1;
        else
            msg_count = msg_count + 1;

        // ── Disassembly line ────────────────────────────────
        if (asmopcode[159:152] != 8'h20)
            if (asmlabel[159:152] != 8'h20)
                $display("%15s%8d PC: %4h %s %s\tOPCODE:%s",
                    asmlabel, clk_count, msg_addr,
                    asminstr, asmoperands, asmopcode);
            else
                $display("\t\t%12d PC: %4h %s %s\tOPCODE:%s",
                    clk_count, msg_addr,
                    asminstr, asmoperands, asmopcode);

        // ── R0–R7 register banks ────────────────────────────
        // ── Call depth tracker ──────────────────────────────
        // Guard: only fires when cycle_2=0 (start of a new instruction).
        // cycle_2=1 means we are in the middle of a 2-cycle instruction;
        // suppressing here prevents intermediate PC+1 steps from being
        // misidentified as new instructions (e.g. JC operand byte 0xB4
        // falsely matching the CALL opcode pattern).
        // Return address for CALL = msg_addr+2 — correct because we fire
        // at the CALL instruction address itself (cycle_2=0, not yet executed).
        begin : track_calls
            integer sp_now;
            reg [7:0] curr_op;
            sp_now  = dme_klr_tb.top_klr.i8048_core_1.psw[2:0];
            curr_op = dme_klr_tb.top_klr.rom_1.rom[msg_addr];

            // CALL family: opcodes x14,x34,x54,x74,x94,xB4,xD4,xF4
            if ((curr_op & 8'h1F) == 8'h14) begin
                begin : call_track
                    reg [11:0] call_target;
                    reg [11:0] ret_addr;
                    // Target: {mb_latch, ir[7:5], operand_byte}
                    // ir[7:5] = curr_op[7:5] (upper 3 target bits from opcode)
                    // operand byte = rom[msg_addr + 1]
                    call_target = {dme_klr_tb.top_klr.i8048_core_1.mb_latch,
                                   curr_op[7:5],
                                   dme_klr_tb.top_klr.rom_1.rom[msg_addr + 1]};
                    ret_addr = msg_addr[11:0] + 12'h002;
                    if (call_depth < 8) begin
                        call_stack[call_depth] = ret_addr;
                        call_depth = call_depth + 1;
                    end
                    $display("\t\tCALL  target=%03h  retaddr=%03h",
                        call_target, ret_addr);
                end
            end

            // RET / RETR
            else if (curr_op == 8'h83 || curr_op == 8'h93) begin
                if (sp_now == 0) begin
                    // 0x2b0 is an intentional computed jump via SP wrap:
                    // firmware sets ram[0x16/0x17] as a fake MB1 frame,
                    // SP=0→7, then RET jumps into MB1. Not a real underflow.
                    if (msg_addr != 12'h2b0) begin
                        $display("*** STACK UNDERFLOW at PC=%03h opcode=%02h — SP=0, PSW will wrap to 7 ***",
                            msg_addr, curr_op);
                        $display("    Shadow call stack:");
                        $display("    [0]=%03h [1]=%03h [2]=%03h [3]=%03h [4]=%03h [5]=%03h [6]=%03h [7]=%03h",
                            call_stack[0], call_stack[1], call_stack[2], call_stack[3],
                            call_stack[4], call_stack[5], call_stack[6], call_stack[7]);
                        $display("    RAM stack slots:");
                        $display("    [08]=%02h [09]=%02h [0A]=%02h [0B]=%02h [0C]=%02h [0D]=%02h [0E]=%02h [0F]=%02h",
                            `RAM[8'h08], `RAM[8'h09], `RAM[8'h0a], `RAM[8'h0b],
                            `RAM[8'h0c], `RAM[8'h0d], `RAM[8'h0e], `RAM[8'h0f]);
                        $display("    [10]=%02h [11]=%02h [12]=%02h [13]=%02h [14]=%02h [15]=%02h [16]=%02h [17]=%02h",
                            `RAM[8'h10], `RAM[8'h11], `RAM[8'h12], `RAM[8'h13],
                            `RAM[8'h14], `RAM[8'h15], `RAM[8'h16], `RAM[8'h17]);
                    end else begin
                        // Intentional computed jump to MB1 via SP wrap.
                        // SP: 0→7. MB1 entry code will then CALL further
                        // functions: SP 7→0→1... MB1 calls must be balanced
                        // so SP returns to 7 before the next trigger reset.
                        // Set call_depth=7 to mirror SP so subsequent CALL/RET
                        // tracking in MB1 stays accurate.
                        call_depth = 7;
                    end
                end else begin
                    call_depth = call_depth - 1;
                end
                $display("\t\t%s  retaddr=ram[%02h/%02h]=%02h%02h",
                    (curr_op == 8'h93) ? "RETR" : "RET ",
                    ({sp_now[2:0] - 1'b1, 1'b0} + 6'h08),
                    ({sp_now[2:0] - 1'b1, 1'b1} + 6'h08),
                    `RAM[{sp_now[2:0] - 1'b1, 1'b1} + 6'h08],
                    `RAM[{sp_now[2:0] - 1'b1, 1'b0} + 6'h08]);
            end

            else begin

            end
        end



        last_msg = asmlabel;
    end
    last_pc = msg_addr;
end

// ============================================================
//  Full internal RAM dump at end of simulation
//
//  The Intel 8049 has 128 bytes of internal RAM: 0x00–0x7F.
//  Register banks:
//    Bank 0  R0–R7  →  ram[0x00]–ram[0x07]
//    Bank 1  R0–R7  →  ram[0x18]–ram[0x1F]
//  Stack:           →  ram[0x08]–ram[0x17]  (8 × 2-byte frames)
// ============================================================
integer ram_idx;
initial begin
    #`SIM_TIME;
    $display("\n========== KLR Internal RAM Dump (end of simulation) ==========");
    $display("       00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F");
    for (ram_idx = 0; ram_idx < 128; ram_idx = ram_idx + 16) begin
        $display("%04h:  %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h",
            ram_idx,
            `RAM[ram_idx+ 0], `RAM[ram_idx+ 1],
            `RAM[ram_idx+ 2], `RAM[ram_idx+ 3],
            `RAM[ram_idx+ 4], `RAM[ram_idx+ 5],
            `RAM[ram_idx+ 6], `RAM[ram_idx+ 7],
            `RAM[ram_idx+ 8], `RAM[ram_idx+ 9],
            `RAM[ram_idx+10], `RAM[ram_idx+11],
            `RAM[ram_idx+12], `RAM[ram_idx+13],
            `RAM[ram_idx+14], `RAM[ram_idx+15]);
    end
    $display("===============================================================\n");
end

endmodule
