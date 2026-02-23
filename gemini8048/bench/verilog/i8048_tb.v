`timescale 1ns/1ps
`define RPMSTART 840
`define RPMEND   6500
`define RPMCONST 2728000
`define RPMRAMP
`define FLATRPM
`define SIM_TIME   10000000000

module i8048_tb;
    `define FREQ   11000 // frequency in kHz
    `define FRQ_SCALE  500000
    parameter DELAY = `FRQ_SCALE/`FREQ;

    reg clk = 0;
    reg int_n = 1;
    reg t1 = 0;
    reg t0 = 0;
    reg res_n;
    wire [7:0] bus_in;
    wire [11:0] pc;
    wire [7:0] p1,p2,bus_out,bus_addr,data_out;
    wire ign_out = p2[7];
    wire ign_out_n = p2[6];
    wire ale,psen_n,rd_n, wr_n,prog,ae,eoc;
    wire trigger, ign;
    reg [7:0] adc_data7,adc_data6,adc_data5,adc_data4,adc_data3,adc_data2,adc_data1,adc_data0;
    dumpvcd u_dumpvcd();
    
    i8048_top top (.clk(clk), .res_n(!trigger), .bus_in(bus_in), .int_n(int_n), .t0(t0), .t1(ign), 
                      .p1(p1), .p2(p2), .bus_out(bus_out), .bus_addr(bus_addr), .ale(ale), .psen_n(psen_n), .rd_n(rd_n), .wr_n(wr_n), .prog(prog)); 

    adc_8090 adc (.clk(clk), .oe (ea), .start(bus_out[3]), .ale(ale),
                 .data_in7(adc_data7),
                 .data_in6(adc_data6),
                 .data_in5(adc_data5),
                 .data_in4(adc_data4),
                 .data_in3(adc_data3),
                 .data_in2(adc_data2),
                 .data_in1(adc_data1),
                 .data_in0(adc_data0),
                 .addr(p1[2:0]),.data_out(bus_in),.eoc(eoc));  

    var_timing_generator timing (.rst(res_n),.clk(clk), .trigger (trigger), .ign(ign));
 

    initial begin
        //$readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/89KLR_951.mem", top.rom_1.rom);
        $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/87KLR_951.mem", top.rom_1.rom);

        adc_data0 = 8'h81; //conn 14
        adc_data1 = 8'h82; //conn 13 
        adc_data2 = 8'h83; //conn 17 
        adc_data3 = 8'h84; //conn 15
        adc_data4 = 8'h85; //conn 23
        adc_data5 = 8'h86; //lm2902.14
        adc_data6 = 8'h87; //conn 25
        adc_data7 = 8'h88; //conn i16

        res_n = 0; #500 res_n = 1;
        #`SIM_TIME
        $writememh("rom_out.hex", top.rom_1.rom);
        $writememh("ram_out.hex", i8048_tb.top.i8048_core_1.ram);

        #1000
        $finish;
    end

initial
begin
  clk = 0;
  forever #DELAY clk <= ~clk;
end

endmodule
