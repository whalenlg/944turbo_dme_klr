module dumpvcd();

// ======================================
// Dump Waves to VCD File
// ======================================
`ifdef DUMP_VCD
initial
    begin
    $display ("VCD Dump enabled");
    $dumpfile(`VCD_FILE);
    $dumpon;

$dumpvars(1,u_cpu.clk);
$dumpvars(1,u_cpu.rst);
$dumpvars(1,u_cpu.cpu_en);
$dumpvars(1,u_cpu.cpu_restart);
$dumpvars(1,u_cpu.rom_en);
$dumpvars(1,u_cpu.rom_addr);
$dumpvars(1,u_cpu.rom_byte);
$dumpvars(1,u_cpu.rom_vld);
$dumpvars(1,u_cpu.ram_rd_en_data);
$dumpvars(1,u_cpu.ram_rd_en_sfr);
$dumpvars(1,u_cpu.ram_rd_en_xdata);
$dumpvars(1,u_cpu.ram_rd_addr);
$dumpvars(1,u_cpu.ram_rd_byte);
$dumpvars(1,u_cpu.ram_wr_en_data);
$dumpvars(1,u_cpu.ram_wr_en_sfr);
$dumpvars(1,u_cpu.ram_wr_en_xdata);
$dumpvars(1,u_cpu.ram_wr_addr);
$dumpvars(1,u_cpu.ram_wr_byte);
//$dumpoff;    
end
    
//always @(posedge `U_DECOMPILE.i_clk)
//    begin
//    if ( `U_TB.clk_count == ( `AMBER_DUMP_START + 0 ) )
//        begin
//        $dumpon;
//        $display("\nDump on at  %d ticks", `U_TB.clk_count);
//        end
                                   
//    if ( `U_TB.clk_count == ( `AMBER_DUMP_START + `AMBER_DUMP_LENGTH ) )
//        begin
//        $dumpoff;
//        $display("\nDump off at %d ticks", `U_TB.clk_count);
//        end
        
//    `ifdef AMBER_TERMINATE
//    if ( `U_DECOMPILE.clk_count == ( `AMBER_DUMP_START + `AMBER_DUMP_LENGTH + 100) )
//        begin
//        $display("\nAutomatic test termination after dump has completed");
//        `TB_ERROR_MESSAGE
//        end
//    `endif
//    end
    
    
    
`endif


    
endmodule

