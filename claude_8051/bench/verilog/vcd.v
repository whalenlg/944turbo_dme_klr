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
`else
  `define TB i8051_tb
`endif
integer clk_count,msg_count;
reg [15:0] read_addr,write_addr,msg_addr,last_pc;
reg [159:0] debug_msg [0:8191],asmlabel,last_msg;
reg [255:0] memory_byte_map [0:255],msg;
reg [7:0] memda,bytememdat,bitmemdat;
reg [255:0] memory_bit_map [0:255];
reg [159:0] opcode[0:8191],instr[0:8191],ops[0:8191],opsnums[0:8191],asmopcode,asminstr,asmoperands,asmoperandnums;

// ======================================
// Dump Waves to FST File
// ======================================
`define FST "1"
`ifndef VCD_FILE
  `define VCD_FILE "sim.fst"
`endif
reg [1023:0] fst_path;
wire [7:0] rb0_0,rb0_1,rb0_2,rb0_3,rb0_4,rb0_5,rb0_6,rb0_7;
wire [7:0] rb1_0,rb1_1,rb1_2,rb1_3,rb1_4,rb1_5,rb1_6,rb1_7;
wire [7:0] rb2_0,rb2_1,rb2_2,rb2_3,rb2_4,rb2_5,rb2_6,rb2_7;
wire [7:0] rb3_0,rb3_1,rb3_2,rb3_3,rb3_4,rb3_5,rb3_6,rb3_7;
wire [7:0] r22,r23,r2b,r2d,r2f,r34,r36,r37,r3d,r3f,r42,r43,r44,r45,r46,r47,r48,r49,r4a,r4b,r4c,r4d,r4e,r4f,r53,r54,r58,r59,r7f;

wire [7:0] r00,r01,r02,r03,r04,r05,r06,r07;
wire [7:0] r08,r09,r0a,r0b,r0c,r0d,r0e,r0f;
wire [7:0] r10,r11,r12,r13,r14,r15,r16,r17;
wire [7:0] r18,r19,r1a,r1r,r1c,r1d,r1e,r1f;

wire b00,b01,b02,b03,b04,b05,b06,b07;
wire b08,b09,b0a,b0b,b0c,b0d,b0e,b0f;
wire b10,b11,b12,b13,b14,b15,b16,b17;
wire b18,b19,b1a,b1b,b1c,b1d,b1e,b1f;
wire b20,b21,b22,b23,b24,b25,b26,b27;
wire b28,b29,b2a,b2b,b2c,b2d,b2e,b2f;

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

// ── CL-mode diagnostic aliases (so individual iram bytes appear in the VCD;
//    $dumpvars does not capture array elements directly) ──
wire [7:0] cl_iram_21    = `TB.i8051_top.u_cpu.iram[8'h21];  // EngineSync byte
wire [7:0] cl_iram_23    = `TB.i8051_top.u_cpu.iram[8'h23];  // FuelOffCoast byte
wire       cl_enginesync = cl_iram_21[0];                    // iram[21h].0
wire       cl_fueloffcoast = cl_iram_23[5];                  // iram[23h].5

assign    rb0_0 = `TB.i8051_top.u_cpu.iram[0];
assign    rb0_1 = `TB.i8051_top.u_cpu.iram[1];
assign    rb0_2 = `TB.i8051_top.u_cpu.iram[2];
assign    rb0_3 = `TB.i8051_top.u_cpu.iram[3];
assign    rb0_4 = `TB.i8051_top.u_cpu.iram[4];
assign    rb0_5 = `TB.i8051_top.u_cpu.iram[5];
assign    rb0_6 = `TB.i8051_top.u_cpu.iram[6];
assign    rb0_7 = `TB.i8051_top.u_cpu.iram[7];

assign    rb1_0 = `TB.i8051_top.u_cpu.iram[8];
assign    rb1_1 = `TB.i8051_top.u_cpu.iram[9];
assign    rb1_2 = `TB.i8051_top.u_cpu.iram[10];
assign    rb1_3 = `TB.i8051_top.u_cpu.iram[11];
assign    rb1_4 = `TB.i8051_top.u_cpu.iram[12];
assign    rb1_5 = `TB.i8051_top.u_cpu.iram[13];
assign    rb1_6 = `TB.i8051_top.u_cpu.iram[14];
assign    rb1_7 = `TB.i8051_top.u_cpu.iram[15];

assign    rb2_0 = `TB.i8051_top.u_cpu.iram[16];
assign    rb2_1 = `TB.i8051_top.u_cpu.iram[17];
assign    rb2_2 = `TB.i8051_top.u_cpu.iram[18];
assign    rb2_3 = `TB.i8051_top.u_cpu.iram[19];
assign    rb2_4 = `TB.i8051_top.u_cpu.iram[20];
assign    rb2_5 = `TB.i8051_top.u_cpu.iram[21];
assign    rb2_6 = `TB.i8051_top.u_cpu.iram[22];
assign    rb2_7 = `TB.i8051_top.u_cpu.iram[23];

assign    rb3_0 = `TB.i8051_top.u_cpu.iram[24];
assign    rb3_1 = `TB.i8051_top.u_cpu.iram[25];
assign    rb3_2 = `TB.i8051_top.u_cpu.iram[26];
assign    rb3_3 = `TB.i8051_top.u_cpu.iram[27];
assign    rb3_4 = `TB.i8051_top.u_cpu.iram[28];
assign    rb3_5 = `TB.i8051_top.u_cpu.iram[29];
assign    rb3_6 = `TB.i8051_top.u_cpu.iram[30];
assign    rb3_7 = `TB.i8051_top.u_cpu.iram[31];

assign    r00 = `TB.i8051_top.u_cpu.iram[7'h00];
assign    r01 = `TB.i8051_top.u_cpu.iram[7'h01];
assign    r02 = `TB.i8051_top.u_cpu.iram[7'h02];
assign    r03 = `TB.i8051_top.u_cpu.iram[7'h03];
assign    r04 = `TB.i8051_top.u_cpu.iram[7'h04];
assign    r05 = `TB.i8051_top.u_cpu.iram[7'h05];
assign    r06 = `TB.i8051_top.u_cpu.iram[7'h06];
assign    r07 = `TB.i8051_top.u_cpu.iram[7'h07];
assign    r08 = `TB.i8051_top.u_cpu.iram[7'h08];
assign    r09 = `TB.i8051_top.u_cpu.iram[7'h09];
assign    r0a = `TB.i8051_top.u_cpu.iram[7'h0a];
assign    r0b = `TB.i8051_top.u_cpu.iram[7'h0b];
assign    r0c = `TB.i8051_top.u_cpu.iram[7'h0c];
assign    r0d = `TB.i8051_top.u_cpu.iram[7'h0d];
assign    r0e = `TB.i8051_top.u_cpu.iram[7'h0e];
assign    rf0 = `TB.i8051_top.u_cpu.iram[7'h0f];
assign    r10 = `TB.i8051_top.u_cpu.iram[7'h10];
assign    r11 = `TB.i8051_top.u_cpu.iram[7'h11];
assign    r12 = `TB.i8051_top.u_cpu.iram[7'h12];
assign    r13 = `TB.i8051_top.u_cpu.iram[7'h13];
assign    r14 = `TB.i8051_top.u_cpu.iram[7'h14];
assign    r15 = `TB.i8051_top.u_cpu.iram[7'h15];
assign    r16 = `TB.i8051_top.u_cpu.iram[7'h16];
assign    r17 = `TB.i8051_top.u_cpu.iram[7'h17];
assign    r18 = `TB.i8051_top.u_cpu.iram[7'h18];
assign    r19 = `TB.i8051_top.u_cpu.iram[7'h19];
assign    r1a = `TB.i8051_top.u_cpu.iram[7'h1a];
assign    r1b = `TB.i8051_top.u_cpu.iram[7'h1b];
assign    r1c = `TB.i8051_top.u_cpu.iram[7'h1c];
assign    r1d = `TB.i8051_top.u_cpu.iram[7'h1d];
assign    r1e = `TB.i8051_top.u_cpu.iram[7'h1e];
assign    r1f = `TB.i8051_top.u_cpu.iram[7'h1f];
assign    r22 = `TB.i8051_top.u_cpu.iram[34];
assign    r23 = `TB.i8051_top.u_cpu.iram[35];
assign    r2b = `TB.i8051_top.u_cpu.iram[43];
assign    r2d = `TB.i8051_top.u_cpu.iram[45];
assign    r2f = `TB.i8051_top.u_cpu.iram[47];

assign    r34 = `TB.i8051_top.u_cpu.iram[52];
assign    r36 = `TB.i8051_top.u_cpu.iram[54];
assign    r37 = `TB.i8051_top.u_cpu.iram[55];
assign    r3d = `TB.i8051_top.u_cpu.iram[7'h3D];
assign    r3f = `TB.i8051_top.u_cpu.iram[63];

assign    r42 = `TB.i8051_top.u_cpu.iram[66];
assign    r43 = `TB.i8051_top.u_cpu.iram[67];
assign    r44 = `TB.i8051_top.u_cpu.iram[68];
assign    r45 = `TB.i8051_top.u_cpu.iram[69];
assign    r46 = `TB.i8051_top.u_cpu.iram[70];
assign    r47 = `TB.i8051_top.u_cpu.iram[71];
assign    r48 = `TB.i8051_top.u_cpu.iram[72];
assign    r49 = `TB.i8051_top.u_cpu.iram[73];
assign    r4a = `TB.i8051_top.u_cpu.iram[74];
assign    r4b = `TB.i8051_top.u_cpu.iram[75];
assign    r4c = `TB.i8051_top.u_cpu.iram[76];
assign    r4d = `TB.i8051_top.u_cpu.iram[77];
assign    r4e = `TB.i8051_top.u_cpu.iram[78];
assign    r4f = `TB.i8051_top.u_cpu.iram[79];

assign    r53 = `TB.i8051_top.u_cpu.iram[83];
assign    r54 = `TB.i8051_top.u_cpu.iram[84];
assign    r58 = `TB.i8051_top.u_cpu.iram[88];
assign    r59 = `TB.i8051_top.u_cpu.iram[89];

assign    r7f = `TB.i8051_top.u_cpu.iram[127];

assign    b00 = `TB.i8051_top.u_cpu.iram[32][0];
assign    b01 = `TB.i8051_top.u_cpu.iram[32][1];
assign    b02 = `TB.i8051_top.u_cpu.iram[32][2];
assign    b03 = `TB.i8051_top.u_cpu.iram[32][3];
assign    b04 = `TB.i8051_top.u_cpu.iram[32][4];
assign    b05 = `TB.i8051_top.u_cpu.iram[32][5];
assign    b06 = `TB.i8051_top.u_cpu.iram[32][6];
assign    b07 = `TB.i8051_top.u_cpu.iram[32][7];

assign    b08 = `TB.i8051_top.u_cpu.iram[33][0];
assign    b09 = `TB.i8051_top.u_cpu.iram[33][1];
assign    b0a = `TB.i8051_top.u_cpu.iram[33][2];
assign    b0b = `TB.i8051_top.u_cpu.iram[33][3];
assign    b0c = `TB.i8051_top.u_cpu.iram[33][4];
assign    b0d = `TB.i8051_top.u_cpu.iram[33][5];
assign    b0e = `TB.i8051_top.u_cpu.iram[33][6];
assign    b0f = `TB.i8051_top.u_cpu.iram[33][7];

assign    b10 = `TB.i8051_top.u_cpu.iram[34][0];
assign    b11 = `TB.i8051_top.u_cpu.iram[34][1];
assign    b12 = `TB.i8051_top.u_cpu.iram[34][2];
assign    b13 = `TB.i8051_top.u_cpu.iram[34][3];
assign    b14 = `TB.i8051_top.u_cpu.iram[34][4];
assign    b15 = `TB.i8051_top.u_cpu.iram[34][5];
assign    b16 = `TB.i8051_top.u_cpu.iram[34][6];
assign    b17 = `TB.i8051_top.u_cpu.iram[34][7];

assign    b18 = `TB.i8051_top.u_cpu.iram[35][0];
assign    b19 = `TB.i8051_top.u_cpu.iram[35][1];
assign    b1a = `TB.i8051_top.u_cpu.iram[35][2];
assign    b1b = `TB.i8051_top.u_cpu.iram[35][3];
assign    b1c = `TB.i8051_top.u_cpu.iram[35][4];
assign    b1d = `TB.i8051_top.u_cpu.iram[35][5];
assign    b1e = `TB.i8051_top.u_cpu.iram[35][6];
assign    b1f = `TB.i8051_top.u_cpu.iram[35][7];

assign    b20 = `TB.i8051_top.u_cpu.iram[36][0];
assign    b21 = `TB.i8051_top.u_cpu.iram[36][1];
assign    b22 = `TB.i8051_top.u_cpu.iram[36][2];
assign    b23 = `TB.i8051_top.u_cpu.iram[36][3];
assign    b24 = `TB.i8051_top.u_cpu.iram[36][4];
assign    b25 = `TB.i8051_top.u_cpu.iram[36][5];
assign    b26 = `TB.i8051_top.u_cpu.iram[36][6];
assign    b27 = `TB.i8051_top.u_cpu.iram[36][7];

assign    b28 = `TB.i8051_top.u_cpu.iram[37][0];
assign    b29 = `TB.i8051_top.u_cpu.iram[37][1];
assign    b2a = `TB.i8051_top.u_cpu.iram[37][2];
assign    b2b = `TB.i8051_top.u_cpu.iram[37][3];
assign    b2c = `TB.i8051_top.u_cpu.iram[37][4];
assign    b2d = `TB.i8051_top.u_cpu.iram[37][5];
assign    b2e = `TB.i8051_top.u_cpu.iram[37][6];
assign    b2f = `TB.i8051_top.u_cpu.iram[37][7];



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
//$dumpvars(1,i8051_tb);
//$dumpvars(1,clk_count);
//$dumpvars(1,`TB.var_interrupt_generator_1);

`ifdef CPU_DEBUG
$dumpvars(1,`TB);
$dumpvars(1,`TB.i8051_top.u_cpu);
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
// CL diagnostics: EngineSync / FuelOffCoast bytes and bits
$dumpvars(0, cl_iram_21);
$dumpvars(0, cl_iram_23);
$dumpvars(0, cl_enginesync);
$dumpvars(0, cl_fueloffcoast);
`ifdef FLATRPM
$dumpvars(0,`TB.interrupt_generator_1);
`endif
`endif

$dumpvars(1,`TB.i8051_top.u_cpu.ir);
$dumpvars(1,pc);
$dumpvars(1,`TB.i8051_top.u_cpu.acc);
$dumpvars(1,`TB.i8051_top.u_cpu.t0);
$dumpvars(1,`TB.i8051_top.u_cpu.t1);

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
//$dumpvars(1,clk);


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

//DEBUG — ISV P1.4 deadlock detector
// Threshold scales with prpm (iram[37h]) so high-RPM tests don't false-positive.
// Guard: skip entirely when prpm=0 (engine not yet synced) to avoid thresh=0 false positives.
// At idle (prpm~0x15): threshold = 0x84 (original calibration).
// Formula: thresh = 0x84 * prpm / 0x15  (integer divide)
always @(posedge clk) begin : isv_deadlock_detect
    reg [15:0] dl_thresh;
    dl_thresh = (16'h0084 * {8'h00, `TB.i8051_top.u_cpu.iram[7'h37]}) / 16'h0015;
    if (`TB.rst &&
        `TB.i8051_top.u_cpu.iram[7'h37] > 8'h00 &&  // skip when prpm=0
        !`TB.i8051_top.u_cpu.p1[4] &&
        {8'h00, `TB.i8051_top.u_cpu.iram[7'h36]} > dl_thresh)
        $display("DME: [DEADLOCK] cycle=%0d P1.4=0, iram[36h]=0x%02X iram[7Fh]=0x%02X thresh=0x%02X",
                 `TB.i8051_top.u_cpu.cycle_count,
                 `TB.i8051_top.u_cpu.iram[7'h36],
                 `TB.i8051_top.u_cpu.iram[7'h7F],
                 dl_thresh[7:0]);
end

    
endmodule
