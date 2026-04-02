module dumpvcd();
integer clk_count,msg_count;
reg [15:0] read_addr,write_addr,msg_addr,last_pc;
reg [159:0] debug_msg [0:8191],asmlabel,last_msg;
reg [255:0] memory_byte_map [0:255],msg;
reg [7:0] memda,bytememdat,bitmemdat;
reg [255:0] memory_bit_map [0:255];
reg [159:0] opcode[0:8191],instr[0:8191],ops[0:8191],opsnums[0:8191],asmopcode,asminstr,asmoperands,asmoperandnums;

// ======================================
// Dump Waves to VCD File
// ======================================
`define VCD "1" 
`ifndef VCD_FILE
  `define VCD_FILE "claude_951dme.vcd"
`endif
wire [7:0] rb0_0,rb0_1,rb0_2,rb0_3,rb0_4,rb0_5,rb0_6,rb0_7;
wire [7:0] rb1_0,rb1_1,rb1_2,rb1_3,rb1_4,rb1_5,rb1_6,rb1_7;
wire [7:0] rb2_0,rb2_1,rb2_2,rb2_3,rb2_4,rb2_5,rb2_6,rb2_7;
wire [7:0] rb3_0,rb3_1,rb3_2,rb3_3,rb3_4,rb3_5,rb3_6,rb3_7;
wire [7:0] r22,r23,r2b,r2d,r2f,r34,r36,r37,r3d,r3f,r42,r43,r44,r45,r46,r47,r48,r49,r4a,r4b,r4c,r4d,r4e,r4f,r54,r58,r59,r7f;

wire [7:0] r00,r01,r02,r03,r04,r05,r06,r07;
wire [7:0] r08,r09,r0a,r0r,r0c,r0d,r0e,r0f;
wire [7:0] r10,r11,r12,r13,r14,r15,r16,r17;
wire [7:0] r18,r19,r1a,r1r,r1c,r1d,r1e,r1f;

wire b00,b01,b02,b03,b04,b05,b06,b07;
wire b08,b09,b0a,b0b,b0c,b0d,b0e,b0f;
wire b10,b11,b12,b13,b14,b15,b16,b17;
wire b18,b19,b1a,b1b,b1c,b1d,b1e,b1f;
wire b20,b21,b22,b23,b24,b25,b26,b27;
wire b28,b29,b2a,b2b,b2c,b2d,b2e,b2f;

wire [4:0] rb = {i8051_tb.i8051_top.u_cpu.psw[4],
                          i8051_tb.i8051_top.u_cpu.psw[3], 3'b000};

wire [7:0] r0 = i8051_tb.i8051_top.u_cpu.iram[rb+0];
wire [7:0] r1 = i8051_tb.i8051_top.u_cpu.iram[rb+1];
wire [7:0] r2 = i8051_tb.i8051_top.u_cpu.iram[rb+2];
wire [7:0] r3 = i8051_tb.i8051_top.u_cpu.iram[rb+3];
wire [7:0] r4 = i8051_tb.i8051_top.u_cpu.iram[rb+4];
wire [7:0] r5 = i8051_tb.i8051_top.u_cpu.iram[rb+5];
wire [7:0] r6 = i8051_tb.i8051_top.u_cpu.iram[rb+6];
wire [7:0] r7 = i8051_tb.i8051_top.u_cpu.iram[rb+7];

assign    rb0_0 = i8051_tb.i8051_top.u_cpu.iram[0];
assign    rb0_1 = i8051_tb.i8051_top.u_cpu.iram[1];
assign    rb0_2 = i8051_tb.i8051_top.u_cpu.iram[2];
assign    rb0_3 = i8051_tb.i8051_top.u_cpu.iram[3];
assign    rb0_4 = i8051_tb.i8051_top.u_cpu.iram[4];
assign    rb0_5 = i8051_tb.i8051_top.u_cpu.iram[5];
assign    rb0_6 = i8051_tb.i8051_top.u_cpu.iram[6];
assign    rb0_7 = i8051_tb.i8051_top.u_cpu.iram[7];

assign    rb1_0 = i8051_tb.i8051_top.u_cpu.iram[8];
assign    rb1_1 = i8051_tb.i8051_top.u_cpu.iram[9];
assign    rb1_2 = i8051_tb.i8051_top.u_cpu.iram[10];
assign    rb1_3 = i8051_tb.i8051_top.u_cpu.iram[11];
assign    rb1_4 = i8051_tb.i8051_top.u_cpu.iram[12];
assign    rb1_5 = i8051_tb.i8051_top.u_cpu.iram[13];
assign    rb1_6 = i8051_tb.i8051_top.u_cpu.iram[14];
assign    rb1_7 = i8051_tb.i8051_top.u_cpu.iram[15];

assign    rb2_0 = i8051_tb.i8051_top.u_cpu.iram[16];
assign    rb2_1 = i8051_tb.i8051_top.u_cpu.iram[17];
assign    rb2_2 = i8051_tb.i8051_top.u_cpu.iram[18];
assign    rb2_3 = i8051_tb.i8051_top.u_cpu.iram[19];
assign    rb2_4 = i8051_tb.i8051_top.u_cpu.iram[20];
assign    rb2_5 = i8051_tb.i8051_top.u_cpu.iram[21];
assign    rb2_6 = i8051_tb.i8051_top.u_cpu.iram[22];
assign    rb2_7 = i8051_tb.i8051_top.u_cpu.iram[23];

assign    rb3_0 = i8051_tb.i8051_top.u_cpu.iram[24];
assign    rb3_1 = i8051_tb.i8051_top.u_cpu.iram[25];
assign    rb3_2 = i8051_tb.i8051_top.u_cpu.iram[26];
assign    rb3_3 = i8051_tb.i8051_top.u_cpu.iram[27];
assign    rb3_4 = i8051_tb.i8051_top.u_cpu.iram[28];
assign    rb3_5 = i8051_tb.i8051_top.u_cpu.iram[29];
assign    rb3_6 = i8051_tb.i8051_top.u_cpu.iram[30];
assign    rb3_7 = i8051_tb.i8051_top.u_cpu.iram[31];

assign    r00 = i8051_tb.i8051_top.u_cpu.iram[7'h00];
assign    r01 = i8051_tb.i8051_top.u_cpu.iram[7'h01];
assign    r02 = i8051_tb.i8051_top.u_cpu.iram[7'h02];
assign    r03 = i8051_tb.i8051_top.u_cpu.iram[7'h03];
assign    r04 = i8051_tb.i8051_top.u_cpu.iram[7'h04];
assign    r05 = i8051_tb.i8051_top.u_cpu.iram[7'h05];
assign    r06 = i8051_tb.i8051_top.u_cpu.iram[7'h06];
assign    r07 = i8051_tb.i8051_top.u_cpu.iram[7'h07];
assign    r08 = i8051_tb.i8051_top.u_cpu.iram[7'h08];
assign    r09 = i8051_tb.i8051_top.u_cpu.iram[7'h09];
assign    r0a = i8051_tb.i8051_top.u_cpu.iram[7'h0a];
assign    r0b = i8051_tb.i8051_top.u_cpu.iram[7'h0b];
assign    r0c = i8051_tb.i8051_top.u_cpu.iram[7'h0c];
assign    r0d = i8051_tb.i8051_top.u_cpu.iram[7'h0d];
assign    r0e = i8051_tb.i8051_top.u_cpu.iram[7'h0e];
assign    rf0 = i8051_tb.i8051_top.u_cpu.iram[7'h0f];
assign    r10 = i8051_tb.i8051_top.u_cpu.iram[7'h10];
assign    r11 = i8051_tb.i8051_top.u_cpu.iram[7'h11];
assign    r12 = i8051_tb.i8051_top.u_cpu.iram[7'h12];
assign    r13 = i8051_tb.i8051_top.u_cpu.iram[7'h13];
assign    r14 = i8051_tb.i8051_top.u_cpu.iram[7'h14];
assign    r15 = i8051_tb.i8051_top.u_cpu.iram[7'h15];
assign    r16 = i8051_tb.i8051_top.u_cpu.iram[7'h16];
assign    r17 = i8051_tb.i8051_top.u_cpu.iram[7'h17];
assign    r18 = i8051_tb.i8051_top.u_cpu.iram[7'h18];
assign    r19 = i8051_tb.i8051_top.u_cpu.iram[7'h19];
assign    r1a = i8051_tb.i8051_top.u_cpu.iram[7'h1a];
assign    r1b = i8051_tb.i8051_top.u_cpu.iram[7'h1b];
assign    r1c = i8051_tb.i8051_top.u_cpu.iram[7'h1c];
assign    r1d = i8051_tb.i8051_top.u_cpu.iram[7'h1d];
assign    r1e = i8051_tb.i8051_top.u_cpu.iram[7'h1e];
assign    r1f = i8051_tb.i8051_top.u_cpu.iram[7'h1f];
assign    r22 = i8051_tb.i8051_top.u_cpu.iram[34];
assign    r23 = i8051_tb.i8051_top.u_cpu.iram[35];
assign    r2b = i8051_tb.i8051_top.u_cpu.iram[43];
assign    r2d = i8051_tb.i8051_top.u_cpu.iram[45];
assign    r2f = i8051_tb.i8051_top.u_cpu.iram[47];

assign    r34 = i8051_tb.i8051_top.u_cpu.iram[52];
assign    r36 = i8051_tb.i8051_top.u_cpu.iram[54];
assign    r37 = i8051_tb.i8051_top.u_cpu.iram[55];
assign    r3d = i8051_tb.i8051_top.u_cpu.iram[7'h3D];
assign    r3f = i8051_tb.i8051_top.u_cpu.iram[63];

assign    r42 = i8051_tb.i8051_top.u_cpu.iram[66];
assign    r43 = i8051_tb.i8051_top.u_cpu.iram[67];
assign    r44 = i8051_tb.i8051_top.u_cpu.iram[68];
assign    r45 = i8051_tb.i8051_top.u_cpu.iram[69];
assign    r46 = i8051_tb.i8051_top.u_cpu.iram[70];
assign    r47 = i8051_tb.i8051_top.u_cpu.iram[71];
assign    r48 = i8051_tb.i8051_top.u_cpu.iram[72];
assign    r49 = i8051_tb.i8051_top.u_cpu.iram[73];
assign    r4a = i8051_tb.i8051_top.u_cpu.iram[74];
assign    r4b = i8051_tb.i8051_top.u_cpu.iram[75];
assign    r4c = i8051_tb.i8051_top.u_cpu.iram[76];
assign    r4d = i8051_tb.i8051_top.u_cpu.iram[77];
assign    r4e = i8051_tb.i8051_top.u_cpu.iram[78];
assign    r4f = i8051_tb.i8051_top.u_cpu.iram[79];

assign    r54 = i8051_tb.i8051_top.u_cpu.iram[84];
assign    r58 = i8051_tb.i8051_top.u_cpu.iram[88];
assign    r59 = i8051_tb.i8051_top.u_cpu.iram[89];

assign    r7f = i8051_tb.i8051_top.u_cpu.iram[127];

assign    b00 = i8051_tb.i8051_top.u_cpu.iram[32][0];
assign    b01 = i8051_tb.i8051_top.u_cpu.iram[32][1];
assign    b02 = i8051_tb.i8051_top.u_cpu.iram[32][2];
assign    b03 = i8051_tb.i8051_top.u_cpu.iram[32][3];
assign    b04 = i8051_tb.i8051_top.u_cpu.iram[32][4];
assign    b05 = i8051_tb.i8051_top.u_cpu.iram[32][5];
assign    b06 = i8051_tb.i8051_top.u_cpu.iram[32][6];
assign    b07 = i8051_tb.i8051_top.u_cpu.iram[32][7];

assign    b08 = i8051_tb.i8051_top.u_cpu.iram[33][0];
assign    b09 = i8051_tb.i8051_top.u_cpu.iram[33][1];
assign    b0a = i8051_tb.i8051_top.u_cpu.iram[33][2];
assign    b0b = i8051_tb.i8051_top.u_cpu.iram[33][3];
assign    b0c = i8051_tb.i8051_top.u_cpu.iram[33][4];
assign    b0d = i8051_tb.i8051_top.u_cpu.iram[33][5];
assign    b0e = i8051_tb.i8051_top.u_cpu.iram[33][6];
assign    b0f = i8051_tb.i8051_top.u_cpu.iram[33][7];

assign    b10 = i8051_tb.i8051_top.u_cpu.iram[34][0];
assign    b11 = i8051_tb.i8051_top.u_cpu.iram[34][1];
assign    b12 = i8051_tb.i8051_top.u_cpu.iram[34][2];
assign    b13 = i8051_tb.i8051_top.u_cpu.iram[34][3];
assign    b14 = i8051_tb.i8051_top.u_cpu.iram[34][4];
assign    b15 = i8051_tb.i8051_top.u_cpu.iram[34][5];
assign    b16 = i8051_tb.i8051_top.u_cpu.iram[34][6];
assign    b17 = i8051_tb.i8051_top.u_cpu.iram[34][7];

assign    b18 = i8051_tb.i8051_top.u_cpu.iram[35][0];
assign    b19 = i8051_tb.i8051_top.u_cpu.iram[35][1];
assign    b1a = i8051_tb.i8051_top.u_cpu.iram[35][2];
assign    b1b = i8051_tb.i8051_top.u_cpu.iram[35][3];
assign    b1c = i8051_tb.i8051_top.u_cpu.iram[35][4];
assign    b1d = i8051_tb.i8051_top.u_cpu.iram[35][5];
assign    b1e = i8051_tb.i8051_top.u_cpu.iram[35][6];
assign    b1f = i8051_tb.i8051_top.u_cpu.iram[35][7];

assign    b20 = i8051_tb.i8051_top.u_cpu.iram[36][0];
assign    b21 = i8051_tb.i8051_top.u_cpu.iram[36][1];
assign    b22 = i8051_tb.i8051_top.u_cpu.iram[36][2];
assign    b23 = i8051_tb.i8051_top.u_cpu.iram[36][3];
assign    b24 = i8051_tb.i8051_top.u_cpu.iram[36][4];
assign    b25 = i8051_tb.i8051_top.u_cpu.iram[36][5];
assign    b26 = i8051_tb.i8051_top.u_cpu.iram[36][6];
assign    b27 = i8051_tb.i8051_top.u_cpu.iram[36][7];

assign    b28 = i8051_tb.i8051_top.u_cpu.iram[37][0];
assign    b29 = i8051_tb.i8051_top.u_cpu.iram[37][1];
assign    b2a = i8051_tb.i8051_top.u_cpu.iram[37][2];
assign    b2b = i8051_tb.i8051_top.u_cpu.iram[37][3];
assign    b2c = i8051_tb.i8051_top.u_cpu.iram[37][4];
assign    b2d = i8051_tb.i8051_top.u_cpu.iram[37][5];
assign    b2e = i8051_tb.i8051_top.u_cpu.iram[37][6];
assign    b2f = i8051_tb.i8051_top.u_cpu.iram[37][7];



initial
    begin

//mem traces

$display ("VCD Dump enabled");
$dumpfile("sim.vcd");
$dumpon;
//$dumpvars(1,i8051_tb);
//$dumpvars(1,clk_count);
$dumpvars(1,i8051_tb.u_dumpvcd.r7f);
//$dumpvars(1,i8051_tb.var_interrupt_generator_1);

`ifdef CPU_DEBUG
$dumpvars(1,i8051_tb);
$dumpvars(1,i8051_tb.i8051_top.u_cpu);
$dumpvars(0,i8051_tb.u_dumpvcd);
$dumpvars(0,i8051_tb.adc_delay_8_1);
`ifdef RAMPRPM $dumpvars(1,i8051_tb.var_interrupt_generator_1);
`endif
`ifdef FLATRPM $dumpvars(1,i8051_tb.interrupt_generator_1);
`endif
`endif

$dumpvars(1,i8051_tb.i8051_top.u_cpu.ir);
$dumpvars(1,i8051_tb.i8051_top.u_cpu.pc);
$dumpvars(1,i8051_tb.i8051_top.u_cpu.acc);

//$dumpvars(1,i8051_tb.xadc_data_out [7:0]);
//$dumpvars(1,i8051_tb.xdata [7:0]);
//$dumpvars(1,i8051_tb.xwr_n);
//$dumpvars(1,i8051_tb.xrd_n);
//$dumpvars(1,i8051_tb.xaddr [15:0]);
$dumpvars(1,i8051_tb.speed_sensor);
$dumpvars(1,i8051_tb.reference_sensor);
$dumpvars(1,i8051_tb.p3 [7:0]);
$dumpvars(1,i8051_tb.p2 [7:0]);
$dumpvars(1,i8051_tb.p1 [7:0]);
$dumpvars(1,i8051_tb.p0 [7:0]);
$dumpvars(1,i8051_tb.o2_7);
$dumpvars(1,i8051_tb.o2_6);
$dumpvars(1,i8051_tb.ale);
$dumpvars(1,i8051_tb.afm_wiper [7:0]);
$dumpvars(1,i8051_tb.A_5_KLR_ign_out);
`ifdef TEST_ISV_COLD_IDLE
$dumpvars(1,i8051_tb.coolant_dynamic);
`endif
$dumpvars(1,i8051_tb.A_4_idle_speed);
$dumpvars(1,i8051_tb.A_3_unused_p1_3);
$dumpvars(1,i8051_tb.A_2_dme_relay);
$dumpvars(1,i8051_tb.A_1_tach_pulse);
$dumpvars(1,i8051_tb.A_0_inj_driver);
//$dumpvars(1,i8051_tb.clk);


    clk_count=0;
    last_pc=16'hFFFF;
    last_msg="FFFF";
    msg_count=1;
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/test_sim.hex",debug_msg);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/memory_byte_map.hex",memory_byte_map);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/memory_bit_map.hex",memory_bit_map);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_opcode_ins.hex",opcode);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_instr.hex",instr);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_operands.hex",ops);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/disassemble/asm_operands_numeric.hex",opsnums);
    end
`ifdef CPU_DEBUG
  always @(negedge i8051_tb.clk) begin
      clk_count <= clk_count + 1;
      msg_addr    = i8051_tb.i8051_top.u_cpu.pc;
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
                 $display("%15s%8d PC: %4h %s %s\tOPCODE:%s\t %s\t count:%8d", asmlabel,clk_count,msg_addr,asminstr,asmoperands,asmopcode,asmoperandnums, msg_count);
              else
                 $display("\t\t%12d PC: %4h %s %s\tOPCODE:%s\t %s\t count:%8d", clk_count,msg_addr,asminstr,asmoperands,asmopcode,asmoperandnums, msg_count);
              last_msg=asmlabel;
           end
       last_pc=msg_addr;

  end
`endif

//DEBUG — ISV P1.4 deadlock detector
// Threshold scales with prpm (iram[37h]) so high-RPM tests don't false-positive.
// Guard: skip entirely when prpm=0 (engine not yet synced) to avoid thresh=0 false positives.
// At idle (prpm~0x15): threshold = 0x84 (original calibration).
// Formula: thresh = 0x84 * prpm / 0x15  (integer divide)
always @(posedge i8051_tb.clk) begin : isv_deadlock_detect
    reg [15:0] dl_thresh;
    dl_thresh = (16'h0084 * {8'h00, i8051_tb.i8051_top.u_cpu.iram[7'h37]}) / 16'h0015;
    if (i8051_tb.rst &&
        i8051_tb.i8051_top.u_cpu.iram[7'h37] > 8'h00 &&  // skip when prpm=0
        !i8051_tb.i8051_top.u_cpu.p1[4] &&
        {8'h00, i8051_tb.i8051_top.u_cpu.iram[7'h36]} > dl_thresh)
        $display("[DEADLOCK] cycle=%0d P1.4=0, iram[36h]=0x%02X iram[7Fh]=0x%02X thresh=0x%02X",
                 i8051_tb.i8051_top.u_cpu.cycle_count,
                 i8051_tb.i8051_top.u_cpu.iram[7'h36],
                 i8051_tb.i8051_top.u_cpu.iram[7'h7F],
                 dl_thresh[7:0]);
end

    
endmodule
