module dumpvcd();
`define MEMMAX 4095
integer clk_count,msg_count;
reg [15:0] read_addr,write_addr,msg_addr,last_pc;
reg [159:0] debug_msg [0:`MEMMAX],asmlabel,last_msg;
reg [255:0] memory_byte_map [0:255],msg;
reg [7:0] memda,bytememdat,bitmemdat;
reg [255:0] memory_bit_map [0:255];
reg [159:0] opcode[0:`MEMMAX],instr[0:`MEMMAX],ops[0:`MEMMAX],opsnums[0:`MEMMAX],asmopcode,asminstr,asmoperands,asmoperandnums;
//reg [255:0] opinstr[255:0];

// ======================================
// Dump Waves to VCD File
// ======================================
`define VCD "1" 
`define VCD_FILE "951klr.vcd"
initial
    begin
`ifdef VCD
//`define VCD_FILE "951dme.vcd" 
`endif
$display ("VCD Dump enabled");
$dumpfile(`VCD_FILE);
$dumpon;
$dumpvars(1,i8048_tb);
$dumpvars(1,i8048_tb.top);
$dumpvars(1,i8048_tb.u_dumpvcd);
$dumpvars(1,i8048_tb.timing);
$dumpvars(1,i8048_tb.top.i8048_core_1);

`ifdef RAMPRPM $dumpvars(1,oc8048_tb.var_interrupt_generator_1);
`ifdef FLATRPM $dumpvars(1,oc8048_tb.interrupt_generator_1);
`endif
`endif


    clk_count=0;
    last_pc=16'hFFFF;
    last_msg="FFFF";
    msg_count=1;
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/test_sim.hex",debug_msg);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/memory_byte_map.hex",memory_byte_map);
//    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/memory_bit_map.hex",memory_bit_map);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_opcode_ins.hex",opcode);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_instr.hex",instr);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_operands.hex",ops);
    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/asm_operands_numeric.hex",opsnums);
//    $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/op_ins8048.hex",opinstr);
//    #`SIM_TIME                                                        
//#10    $finish; 
  end

  always @(negedge top.clk) begin
      clk_count <= clk_count + 1;
      msg_addr=top.pc;
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
              if ((asmopcode[159:152] != 8'h20))
                if ((asmlabel[159:152] != 8'h20))
                begin
                   $display("%15s%8d PC: %4h %s %s\tOPCODE:%s", asmlabel,clk_count,msg_addr,asminstr,asmoperands,asmopcode);
                end
                else
                begin
                   $display("\t\t%12d PC: %4h %s %s\tOPCODE:%s", clk_count,msg_addr,asminstr,asmoperands,asmopcode);
                end
              last_msg=asmlabel;
           end
       last_pc=msg_addr;
//       if (top.wr_n) //we have a write to the memory
//         begin
//           write_addr=top.i8048_core_1.rn_addr;
//           bytememdat = top.i8048_core_1.wmem_dat;
//           bitmemdat = top.oc8048_sfr1.bit_in;
//           if (top.oc8048_sfr1.wr_bit_r==1)  //valid write bit op
//             begin
//               msg = memory_bit_map[write_addr];
//               $display("\tWrite1\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr,write_addr, bitmemdat,memory_bit_map[write_addr]);
//             end 
//           else //valid write byte op
//             begin
//               msg = memory_byte_map[write_addr];
//               if (msg[255:248] != 8'h20) //filter empty messages
//                 begin
//               $display("\tWrite8\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr, write_addr, bytememdat,memory_byte_map[write_addr]);
//                 end

//             end
//         end
//       if (top.rd_n) //we have a read on the memory
//         begin
//           read_addr=top.i8048_core_1.rn_addr;
//           bytememdat = top.i8048_core_1.rmem_dat;
//           bitmemdat = top.oc8048_ram_top1.bit_data_out;
//           if (top.oc8048_ram_top1.bit_addr) //not a write op
//                   $display("\tRead1\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr,read_addr, bitmemdat,memory_bit_map[read_addr]);
//             else
//                   $display("\tRead8\t%12d PC: %4h Addr:%4h Data:%2h   %s", clk_count, msg_addr,read_addr, bytememdat,memory_byte_map[read_addr]);
//         end
  end


    
endmodule
