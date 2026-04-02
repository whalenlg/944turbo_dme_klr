`include "oc8051_timescale.v"

//`include "oc8051_defines.v"

`define VCD_FILE "claude_951dme.vcd" 
`define DUMP_VCD
//short `define SIM_TIME  800000000
//long `define SIM_TIME   8000000000
//super long `define SIM_TIME   80000000000
//medium `define SIM_TIME 4000000000
//MOVX test `define SIM_TIME  380000
//`define SIM_TIME   20000000000
//`define SIM_TIME   8000000000

//`define CPU_DEBUG
//`define RPMSTART 100 
//`define RPMEND   840 
`define RPMCONST 2728000
//`define RPMRAMP
//`define RPM_RAMP_PCT 25    // RPM reaches RPMEND at 25% of SIM_TIME, holds steady after
//`define FLATRPM
//`define NOINT
`define FREQ   6000 // frequency in kHz

module i8051_tb;

`define FRQ_SCALE  500000
parameter DELAY = `FRQ_SCALE/`FREQ;

reg  rst, clk;
reg  [7:0] p0_in, p1_in, p2_in,p3_in;
wire  [7:0] p0, p1, p2, p3;
wire [15:0] ext_addr;
wire write, write_xram, write_uart, rxd, int_uart, reference_sensor, speed_sensor, t0, t1, bit_out, stb_o, ack_i;
wire dumreference_sensor,dumspeed_sensor;
wire ack_xram, ack_uart, cyc_o, iack_i, istb_o, icyc_o, t2, t2ex;
wire [7:0] data_in, data_out, data_out_uart; //MW FIX make data_out_xram a reg
wire  [7:0] data_out_xram;
wire o2_6,o2_7; 
reg [7:0] xram [0:65535];   // external data RAM (MOVX target)
wire [15:0] addr_bus;    // 16-bit program address driven by core
reg  [7:0]  rom_data;    // byte returned to core this cycle

// ---------------------------------------------------------------------------
// External data memory (MOVX bus)
// ---------------------------------------------------------------------------
wire        xrd_n;       // /RD strobe from core
wire        xwr_n;       // /WR strobe from core
wire [15:0] xaddr;   // address from core (DPTR or {P2,Ri})
wire [7:0]  xdata;   // data written by core
reg [7:0] xdata_in;
wire [7:0] adc_data;
wire [7:0] xadc_data_out,adc_data_out;
wire ale, txd;
wire [15:0] pc_mon;     // PC monitoring output
wire [7:0]  ir_mon;     // IR monitoring output



///
/// buffer for test vectors
///
//
// buffer
reg [23:0] buff [0:255];
reg ea [0:1];

integer num;

dumpvcd u_dumpvcd();


i8051_system  i8051_top(.res_n(rst), .clk(clk),
         .int0_n(reference_sensor), .int1_n(speed_sensor),


	 .p0(p0),
	 .p0_in(p0_in),

	 .p1(p1),
	 .p1_in(p1_in),

	 .p2(p2),
	 .p2_in(p2_in),

	 .p3(p3),
	 .p3_in(p3_in),


	 .rxd(rxd), .txd(txd),

	 .t0(t0), .t1(t1),

    // Bus control
    .ale        ( ale       ),
            
    // External data memory
    .xdata   ( xdata  ), 
    .xaddr  ( xaddr ),
    .xrd_n      ( xrd_n     ), 
    .xwr_n      ( xwr_n     )



	 );

adc_delay_8 adc_delay_8_1(.clk(ale),.rst(rst),.data_in(adc_data),.start(~xrd_n),.data_out(adc_data_out));

//
// external data ram
//
oc8051_xram oc8051_xram1 (.clk(clk), .rst(rst), .wr(write_xram), .addr(ext_addr), .data_in(data_out), .ack(ack_xram), .stb(stb_o)); //MW fix - remove output


defparam oc8051_xram1.DELAY = 2;

//oc8051_serial oc8051_serial1(.clk(clk), .rst(rst), .rxd(txd), .txd(rxd));

//defparam oc8051_serial1.FREQ  = `FREQ;
//defparam oc8051_serial1.BRATE = 9.6;
//defparam oc8051_serial1.BRATE = 4.8;


//
// external uart
//
//oc8051_uart_test oc8051_uart_test1(.clk(clk), .rst(rst), .addr(ext_addr[7:0]), .wr(write_uart),
//                  .wr_bit(p3_out[0]), .data_in(data_out), .data_out(data_out_uart), .bit_out(bit_out), .rxd(txd),
//		  .txd(rxd), .ow(p3_out[1]), .intr(int_uart), .stb(stb_o), .ack(ack_uart));



//
// exteranl program rom
//
//
// rom 0
//
wire [11:0] adr0, adr1;
wire [15:0] dat0, dat1;

// P3 pin functions (89 DME 951):
//   P3.0 (RXD  / bit B0h) - Serial RXD
//   P3.1 (TXD  / bit B1h) - Serial TXD / lambda diagnostic output
//   P3.2 (INT0 / bit B2h) - Crank reference sensor    INPUT  falling edge
//   P3.3 (INT1 / bit B3h) - Crank speed sensor        INPUT  falling edge
//   P3.4 (T0   / bit B4h) - Codes plug                INPUT  variant select
//   P3.5 (T1   / bit B5h) - A/C compressor clutch     INPUT
//   P3.6 (WRBAR/ bit B6h) - External RAM write strobe OUTPUT
//   P3.7 (RDBAR/ bit B7h) - External RAM read strobe  OUTPUT

assign write_xram = p3[7] & write;
assign write_uart = !p3[7] & write;
assign data_in = p3[7] ? data_out_xram : data_out_uart;
assign ack_i = p3[7] ? ack_xram : ack_uart;
assign t0 = p3[5];
assign t1 = p3[6];
assign t2 = p3[5];
assign t2ex = p3[2];


// P1 pin functions (89 DME 951):
//   P1.0 (bit 90h) - Injectors        OUTPUT active-low
//   P1.1 (bit 91h) - Tachometer       OUTPUT pulsed at ignition rate
//   P1.2 (bit 92h) - DME relay/fuel pump OUTPUT active-low
//   P1.3 (bit 93h) - unused
//   P1.4 (bit 94h) - Idle speed positioner + watchdog OUTPUT
//   P1.5 (bit 95h) - KLROut / ignition coil primary OUTPUT
//   P1.6 (bit 96h) - Lambda <0.5V     INPUT  low=rich
//   P1.7 (bit 97h) - Lambda <4.5V     INPUT  high=lean


assign A_0_inj_driver   = p1[0];//error on DME schematic
assign A_1_tach_pulse   = p1[1];
assign A_2_dme_relay    = p1[2];
assign A_3_unused_p1_3   = p1[3];
assign A_4_idle_speed   = p1[4];
assign A_5_KLR_ign_out  = p1[5];
assign xadc_data_out = adc_data_out;  // registered — stable between reads
assign xdata = (!xrd_n) ? xadc_data_out : 8'bz;
wire [7:0] afm_wiper;

`define AFM_IDLE_THR 8'h1A  // AFM threshold: at/above = closed throttle (idle)

// ----------------------------------------------------------------
//  8-channel ADC mux — P2[2:0] selects the channel
//
//  Each channel is sampled once per ADC scan cycle.  The result is
//  stored by the firmware into iram[10h+ch] (bank 2 register space).
//  The adc_delay_8 module delays the output by 8 ALE cycles to
//  model the real ADC chip's conversion time.
//
//  Physical signals on the 89 DME 951 (Bosch Motronic 3.1):
//
//  ch0 (p2=000) → iram[10h]  AFM wiper voltage
//                              Bosch vane-type air flow meter.
//                              Voltage ∝ airflow ∝ RPM at idle.
//                              0x0D=250mV at 840 RPM warm idle.
//                              Driven by var_interrupt_gen.afm_wiper.
//
//  ch1 (p2=001) → iram[11h]  Battery voltage
//                              Used to compute injector dead-time
//                              correction (lower voltage = longer
//                              dead time).  0xD8=13.5V nominal.
//
//  ch2 (p2=010) → iram[12h]  Intake air temperature NTC
//                              NTC thermistor (resistance ↓ with
//                              temperature ↑).  Raw value passed to
//                              linearisation map → iram[12h].
//                              0x76 ≈ 20°C intake air.
//
//  ch3 (p2=011) → iram[13h]  Coolant temperature NTC
//                              NTC thermistor.  Raw value linearised
//                              → iram[13h].  0x3C ≈ 80°C coolant.
//                              NTC keepalive in phase_monitor.v
//                              clamps linearised value to 0xE0 warm.
//
//  ch4 (p2=100) → iram[14h]  Altitude / barometric pressure switch
//                              Compensates fuelling for high-altitude
//                              operation where air density is lower.
//                              0xF8 = below 1000m (sea level / normal)
//                              0x00 = above 1000m (high altitude)
//
//  ch5 (p2=101) → iram[15h]  Unused / spare channel
//                              Not referenced by firmware for any
//                              control function.  0xFF = floating.
//
//  ch6 (p2=110) → iram[16h]  Throttle position sensor (TPS)
//                              Potentiometer on throttle butterfly.
//                              944 Turbo polarity: high voltage =
//                              closed throttle / idle.
//                              Threshold table at ROM[0x1124]:
//                                0xD1..0xE6 → IdleClosed=1, WOT=1
//                                  (closed throttle idle condition)
//                                0x77..0xD0 → WOT=1, IdleClosed=0
//                                  (true wide-open throttle)
//                                0x00..0x76 → both=0 (partial load)
//                              Driven from afm_wiper threshold:
//                                ≥ AFM_IDLE_THR → 0xDB (idle/closed)
//                                <  AFM_IDLE_THR → 0x40 (ramp/open)
//
//  ch7 (p2=111) → iram[17h]  Fuel quality switch
//                              Selects between fuel octane maps.
//                              Allows the DME to retard timing or
//                              reduce boost for lower-octane fuel.
//                              0x80 = standard fuel (nominal).
// ----------------------------------------------------------------
// Combinatorial mux — selects value for current channel
reg [7:0] adc_mux;
always @(p2[2:0] or afm_wiper)
begin
  case (p2[2:0])
    3'b000:  adc_mux=afm_wiper;  // ch0: AFM wiper (from var_interrupt_gen)
    3'b001:  adc_mux=8'hd8;      // ch1: Battery voltage  13.5V
    3'b010:  adc_mux=8'h50;      // ch2: Intake air NTC   ~20°C raw (CPL=0xAF → ~0xA0 linearised)
    3'b011:  adc_mux=8'h20;      // ch3: Coolant NTC      ~80°C raw (CPL=0xDF → ~0xE0 linearised)
    3'b100:  adc_mux=8'hF8;      // ch4: Altitude switch   below 1000m (0x00 = above 1000m)
    3'b101:  adc_mux=8'hFF;      // ch5: Unused           floating
    // ch6: TPS — 0xDB=idle/closed (IdleClosed=1), 0x40=ramp/open (partial)
    3'b110:  adc_mux=(afm_wiper >= `AFM_IDLE_THR) ? 8'hDB : 8'h40;
    3'b111:  adc_mux=8'h80;      // ch7: Fuel quality switch  standard fuel
    default: adc_mux=8'hF0;
  endcase
end

// Feed adc_mux directly into the delay pipeline.
// The adc_delay_8 shift register (clocked by ale) captures the
// combinatorial mux value at each ALE edge — modelling the real
// ADC chip which latches the channel select at ALE and presents
// the converted result 8 ALE cycles later.
// Removing the intermediate latch eliminates the one-cycle offset
// that caused the wrong channel value to be captured.
assign adc_data = adc_mux;


initial begin
  rst= 1'b0;

    p2_in=8'hFF;     // P2 not used as input

 
#1000
  rst = 1'b1;

#`SIM_TIME
  $display("time ",$time, "\nend of time\n \n");
  $display("");

  $writememh("rom_out.hex", i8051_tb.i8051_top.u_eprom.mem);
  $writememh("ram_out.hex", i8051_tb.i8051_top.u_cpu.iram);
  $writememh("xram_out.hex",i8051_tb.xram);
#10000
  $finish;
end


initial
begin
  clk = 0;
  forever #DELAY clk <= ~clk;
end


// ---------------------------------------------------------------------------
// External RAM write model
//   Capture the write on the rising edge of /WR (end of write strobe).
// ---------------------------------------------------------------------------
always @(posedge xwr_n) begin
    xram[xaddr] <= xdata;
end 
    


always @(clk)
begin
  p1_in[0]=1'b1; //inj
  p1_in[1]=1'b1;
  p1_in[2]=1'b1;
  p1_in[3]=1'b1;
  p1_in[4]=1'b1;
  p1_in[5]=1'b1;
  p1_in[6]=o2_6; //7=0+6=0 Rich, 7=1+6=1 Lean, 7=0+6=1 Normal
  p1_in[7]=o2_7;

  p3_in[7:5] = 3'h0;
  p3_in[1:0] = {bit_out, int_uart};
  p3_in[2] = reference_sensor;
  p3_in[3]= speed_sensor;
  p3_in[4]= 0; //T0 Perf data - 0 => has cat

end


`ifdef RPMRAMP var_interrupt_generator var_interrupt_generator_1 (.clk(clk),.rst(rst),.int_0(reference_sensor),.int_1(speed_sensor),.afm_wiper(afm_wiper));
`else 
   `ifdef NOINT
      assign reference_sensor = 1;
      assign speed_sensor = 1;
    `else interrupt_generator interrupt_generator_1 (.clk(clk),.rst(rst),.int_0(reference_sensor),.int_1(speed_sensor));
    `endif
`endif

o2_generator o2_generator_1 (.clk(clk), .rst(rst), .o2_top(o2_7), .o2_bottom(o2_6));


`include "bench/verilog/phase_monitor.v"

endmodule


