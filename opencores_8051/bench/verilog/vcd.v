module dumpvcd();
integer clk_count,msg_count;
//integer last_pc;
//integer msg_addr,read_addr,write_addr;
reg [15:0] read_addr,write_addr,msg_addr,last_pc;
reg [159:0] debug_msg [0:8191],asmlabel,last_msg;
reg [255:0] memory_byte_map [0:255],msg;
reg [7:0] memda,bytememdat,bitmemdat;
reg [255:0] memory_bit_map [0:255];
reg [159:0] opcode[0:8191],instr[0:8191],ops[0:8191],opsnums[0:8191],asmopcode,asminstr,asmoperands,asmoperandnums;

// ======================================
// Dump Waves to VCD File
// ======================================
//`ifdef DUMP_VCD
`define VCD "1" 
`define VCD_FILE "951dme.vcd"
//`ifdef FST
initial
    begin
`ifdef VCD
//`define VCD_FILE "951dme.vcd" 
`endif
$display ("VCD Dump enabled");
$dumpfile(`VCD_FILE);
$dumpon;
$dumpvars(1,oc8051_tb);
$dumpvars(1,oc8051_tb.oc8051_top_1);
$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_ram_top1);
$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_memory_interface1);
//$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_wb_interface);
//$dumpvars(1,oc8051_tb.interrupt_generator_1);
`ifdef RAMPRPM $dumpvars(1,oc8051_tb.var_interrupt_generator_1);
`ifdef FLATRPM $dumpvars(1,oc8051_tb.interrupt_generator_1);
`endif
$dumpvars(1,oc8051_tb.oc8051_xrom1);
$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_ram_top1.oc8051_idata.oc8051_ram1);
$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_sfr1);
//$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_sfr1.oc8051_tc1);
//$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_sfr1.oc8051_int1);
$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_sfr1.oc8051_ports1);
$dumpvars(1,oc8051_tb.oc8051_top_1.oc8051_decoder1);

$dumpvars(1,oc8051_tb.oc8051_xram1);

`endif


//`ifdef FST
//`define VCD_FILE "951dme.fst" 
// $display("fstdumper!");
// $fstDumpfile("8051dme.fst");
// $fstDumpvars(1,oc8051_tb.oc8051_top_1);
// $fstDumpvars(1,oc8051_tb.oc8051_top_1.oc8051_sfr1);
//`endif
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

//    #SIM_TIME                                                        


//#    $finish; 
  end
  always @(negedge oc8051_tb.clk) begin
      clk_count <= clk_count + 1;
      msg_addr=oc8051_tb.oc8051_top_1.pc;
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
       if (oc8051_tb.oc8051_top_1.wr) //we have a write to the memory
         begin
           write_addr=oc8051_tb.oc8051_top_1.wr_addr;
           bytememdat = oc8051_tb.oc8051_top_1.wr_dat;
           bitmemdat = oc8051_tb.oc8051_top_1.oc8051_sfr1.bit_in;
           if (oc8051_tb.oc8051_top_1.oc8051_sfr1.wr_bit_r==1)  //valid write bit op
             begin
               msg = memory_bit_map[write_addr];
               $display("\tWrite1\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr,write_addr, bitmemdat,memory_bit_map[write_addr]);
             end 
           else //valid write byte op
             begin
               msg = memory_byte_map[write_addr];
//               if (msg[255:248] != 8'h20) //filter empty messages
//                 begin
               $display("\tWrite8\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr, write_addr, bytememdat,memory_byte_map[write_addr]);
//                 end:w

             end
         end
       if (oc8051_tb.oc8051_top_1.rd) //we have a read on the memory
         begin
           read_addr=oc8051_tb.oc8051_top_1.oc8051_ram_top1.rd_addr;
           bytememdat = oc8051_tb.oc8051_top_1.oc8051_ram_top1.rd_data;
           bitmemdat = oc8051_tb.oc8051_top_1.oc8051_ram_top1.bit_data_out;
           if (oc8051_tb.oc8051_top_1.oc8051_ram_top1.bit_addr) //not a write op
                   $display("\tRead1\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr,read_addr, bitmemdat,memory_bit_map[read_addr]);
             else
                   $display("\tRead8\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr,read_addr, bytememdat,memory_byte_map[read_addr]);
         end
  end


    
endmodule
