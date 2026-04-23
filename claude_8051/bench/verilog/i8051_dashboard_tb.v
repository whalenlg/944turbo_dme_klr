`include "oc8051_timescale.v"

// ============================================================
//  i8051_dashboard_tb.v  —  89 DME 951 Dashboard Testbench
//
//  Drop-in companion to i8051_dashboard_tb.v that emits compact [DS]
//  snapshot lines covering ALL 128 iram bytes + P1/P2/P3,
//  readable by the React dashboard.  PHASE event lines are
//  identical to phase_monitor.v so the dashboard Phase tab
//  still works.  All test defines from i8051_dashboard_tb.v are
//  supported unchanged.
//
//  Compile (example — same flags as i8051_dashboard_tb.v):
//    iverilog -o dash.vvp \
//      -f files \
//      -I rtl/verilog -I bench/verilog \
//      -s i8051_dashboard_tb \
//      -DTEST_WARM_IDLE \
//      i8051_dashboard_tb.v
//
//    vvp dash.vvp > warm_idle.ds.log
//
//  Log format — one line per DASH_INTERVAL_MS:
//    [DS] <time_ms>,<256hex_iram>,<p1hex><p2hex><p3hex>
//
//  DASH_INTERVAL_MS default: 100  (override with -DDASH_INTERVAL_MS=50)
// ============================================================

// ============================================================
//  TEST SELECTION — uncomment one or pass via -DTEST_xxx
// ============================================================

// --- Idle tests ---
//`define TEST_WARM_IDLE
//`define TEST_COLD_START
//`define TEST_HOT_IDLE
//`define TEST_IDLE_BATTERY_LOW
//`define TEST_IDLE_HIGH_ALT
//`define TEST_IDLE_POOR_FUEL
//`define TEST_AC_ON_IDLE
//`define TEST_CL_RAMP_TO_3000
//`define TEST_CL_RAMP_TO_6000
//`define TEST_CL_RAMP_TO_REDLINE
//`define TEST_CL_AC_HALFWAY
//`define TEST_CL_COLD_START

// --- Fuel transient tests ---
//`define TEST_TIPPY_IN
//`define TEST_OVERRUN_CUTOFF
//`define TEST_WARMUP_ENRICHMENT
//`define TEST_AFM_OPEN_CIRCUIT

// --- RPM sweep tests ---
//`define TEST_RAMP_TO_3000
//`define TEST_RAMP_TO_6000
//`define TEST_RAMP_TO_REDLINE
//`define TEST_RAMP_6K_HOLD

// --- Sensor failure tests ---
//`define TEST_COOLANT_FAIL
//`define TEST_AIRTEMP_FAIL
//`define TEST_O2_DISCONNECTED
//`define TEST_O2_RICH_STUCK
//`define TEST_O2_LEAN_STUCK
//`define TEST_TPS_FAIL

// --- Ignition tests ---
//`define TEST_IGNITION_TIMING
//`define TEST_DWELL_SCALING

// --- ISV / idle speed control tests ---
//`define TEST_ISV_COLD_IDLE
//`define TEST_ISV_LOAD_DROOP

// ============================================================
//  Common sim parameters
// ============================================================
`ifndef SIM_TIME
  `define SIM_TIME     80000000000
`endif
`ifndef RPMSTART
  `define RPMSTART     100
`endif
`ifndef RPMEND
  `define RPMEND       840
`endif
`ifndef RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
`endif
`ifndef DASH_INTERVAL_MS
  `define DASH_INTERVAL_MS 100
`endif

// ============================================================
//  Per-test parameter overrides (identical to i8051_dashboard_tb.v)
// ============================================================

`ifdef TEST_WARM_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 10
  `undef  SIM_TIME
  `define SIM_TIME  60000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_COLD_START
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  120000000000
  `define _COOLANT_RAW  8'hC0
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_HOT_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  25000000000
  `define _COOLANT_RAW  8'h10
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_IDLE_BATTERY_LOW
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'h8C
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_IDLE_HIGH_ALT
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'h00
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_IDLE_POOR_FUEL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h00
`endif

`ifdef TEST_AC_ON_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AC_COMP_ON                 // T1=1: AC compressor active
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  10000000000      // 10s — enough to see ISV and fuel response to AC load
  `define _COOLANT_RAW  8'h20        // warm engine
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_CL_RAMP_TO_3000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'h72      // 3000 RPM → ADC≈0x72 (114)
  `undef  SIM_TIME
  `define SIM_TIME  30000000000     // 30s — RPM climbs ~670/13s, needs ~25s to reach 3000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_CL_RAMP_TO_6000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'hDA      // 6000 RPM → ADC≈0xDA (218)
  `undef  SIM_TIME
  `define SIM_TIME  40000000000     // 40s — higher RPM needs more time
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_CL_RAMP_TO_REDLINE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'hEB      // 6500 RPM → ADC=0xEB (235, max)
  `undef  SIM_TIME
  `define SIM_TIME  40000000000     // 40s
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_CL_AC_HALFWAY
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define CL_AC_HALFWAY              // T1 switches on at SIM_TIME/2 (~10s)
  `undef  SIM_TIME
  `define SIM_TIME  20000000000     // 20s — 10s pre-AC, 10s with AC
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_CL_COLD_START
  `define RPMRAMP
  `define CL_MODE                    // no SKIP_LAMBDA_WARMUP — genuine cold start
  `undef  SIM_TIME
  `define SIM_TIME  60000000000     // 60s — observe cold enrichment decay
  `define _COOLANT_RAW  8'hC0       // cold — above 0x8F threshold for cold-start enrich
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_TIPPY_IN
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AFM_TIPPY                  // enables step-change AFM override for accel enrichment
  `undef  RPMEND
  `define RPMEND    840              // hold at idle — AFM spike drives enrichment, not RPM
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 10
  `undef  SIM_TIME
  `define SIM_TIME  10000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_OVERRUN_CUTOFF
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 10
  `undef  SIM_TIME
  `define SIM_TIME  30000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_WARMUP_ENRICHMENT
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  60000000000
  `define _COOLANT_RAW  8'hC0
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_AFM_OPEN_CIRCUIT
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AFM_FAULT
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_COOLANT_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h00   // shorted NTC: 0V → ADC 0x00 → firmware linearises to 0xFB=104°C hot
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_AIRTEMP_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h00   // shorted NTC: 0V → ADC 0x00 → firmware linearises to 0xFB=104°C hot air
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_O2_DISCONNECTED
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define O2_FLAT_RICH
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  25000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_O2_RICH_STUCK
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define O2_FLAT_RICH
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  25000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_O2_LEAN_STUCK
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define O2_FLAT_LEAN
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  25000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_TPS_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define TPS_FIXED 8'h80
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_RAMP_TO_3000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    3000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 50
  `undef  SIM_TIME
  `define SIM_TIME  10000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_RAMP_TO_6000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
  `undef  SIM_TIME
  `define SIM_TIME  10000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_RAMP_TO_REDLINE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6500
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
  `undef  SIM_TIME
  `define SIM_TIME  10000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_RAMP_6K_HOLD
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
  `undef  SIM_TIME
  `define SIM_TIME  15000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_IGNITION_TIMING
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 50
  `undef  SIM_TIME
  `define SIM_TIME  15000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_DWELL_SCALING
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    6000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 80
  `undef  SIM_TIME
  `define SIM_TIME  15000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_ISV_COLD_IDLE
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  60000000000
  `define _COOLANT_RAW  8'h60
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

`ifdef TEST_ISV_LOAD_DROOP
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define ISV_LOAD_DROOP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  12000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// ============================================================
//  ADC channel defaults
// ============================================================
`ifndef _COOLANT_RAW
  `define _COOLANT_RAW  8'h20
`endif
`ifndef _AIRTEMP_RAW
  `define _AIRTEMP_RAW  8'h50
`endif
`ifndef _BATTERY
  `define _BATTERY      8'hD8
`endif
`ifndef _ALTITUDE
  `define _ALTITUDE     8'hF8
`endif
`ifndef _FUEL_QUAL
  `define _FUEL_QUAL    8'h80
`endif

// ============================================================
//  Clock constants
// ============================================================
`ifndef RPMCONST
  `define RPMCONST 2727272
`endif
`ifndef FREQ
  `define FREQ     6000
`endif

module i8051_dashboard_tb;

`define FRQ_SCALE  500000
parameter DELAY = `FRQ_SCALE / `FREQ;

// ─── Clocks & reset ─────────────────────────────────────────
reg  rst, clk;

// ─── I/O ports ──────────────────────────────────────────────
reg  [7:0] p0_in, p1_in, p2_in, p3_in;
wire [7:0] p0, p1, p2, p3;

// Initialise all port inputs to safe defaults at t=0 so the firmware
// never sees X on any pin — especially T0 (P3.4) and T1 (P3.5) which
// are 8051 timer/counter inputs.  Open-collector 8051 port pins idle
// high, so unused inputs are driven 1'b1.
initial begin
    p0_in = 8'hFF;
    p1_in = 8'hFF;
    p2_in = 8'hFF;
    // P3 specific safe state:
    //   [7:6] unused            — 1
    //   [5]   T1 (timer input)  — 1 (idle/inactive)
    //   [4]   T0 (timer input)  — 1 (idle/inactive)
    //   [3]   speed_sensor      — 1 (no tooth)
    //   [2]   reference_sensor  — 1 (no ref pulse)
    //   [1]   TXD/int_uart      — 1
    //   [0]   RXD/bit_out       — 1
    p3_in = 8'hFF;
end

// ─── Misc wires (match i8051_dashboard_tb.v declarations) ─────────────
wire [15:0] ext_addr;
wire        write, write_xram, write_uart;
wire        rxd, int_uart, bit_out;
wire        reference_sensor, speed_sensor;
// T0 (P3.4) and T1 (P3.5) are separate top-level ports on i8051_top —
// not derived from p3_in. Must be driven explicitly or the timer module
// sees X and MOV C,bitaddr reads of port-derived bits are corrupted.
// T0: firmware uses as has-cat flag (0 = cat fitted). Drive low.
// T1: AC compressor status input. 0=off (default), 1=on.
//     Override with -DAC_COMP_ON for always-on, or -DCL_AC_HALFWAY
//     for mid-simulation switch (fires at SIM_TIME/2).
`ifdef CL_AC_HALFWAY
reg t1;
initial begin
    t1 = 1'b0;
    #(`SIM_TIME / 2);   // switch AC on halfway through simulation
    t1 = 1'b1;
end
`elsif AC_COMP_ON
wire t1;
assign t1 = 1'b1;   // T1 = AC compressor active
`else
wire t1;
assign t1 = 1'b0;   // T1 = AC compressor off (default)
`endif

wire        t0;
assign t0 = 1'b0;   // T0 = has catalytic converter (0 = fitted)
wire        stb_o, ack_i, ack_xram, ack_uart;
wire        cyc_o, iack_i, istb_o, icyc_o;
wire [7:0]  data_in, data_out, data_out_uart, data_out_xram;
wire        o2_6, o2_7;
reg  [7:0]  xram [0:65535];
wire [15:0] addr_bus;
wire [15:0] xaddr;
wire [7:0]  xdata;
reg  [7:0]  xdata_in;
wire [7:0]  adc_data, xadc_data_out, adc_data_out;
wire        ale, txd;
wire        xrd_n, xwr_n;
wire        dumreference_sensor, dumspeed_sensor;

// ─── P1 signal aliases (for dumpvcd compatibility) ──────────
wire A_0_inj_driver;
wire A_1_tach_pulse;
wire A_2_dme_relay;
wire A_3_unused_p1_3;
wire A_4_idle_speed;
wire A_5_KLR_ign_out;

assign A_0_inj_driver  = p1[0];
assign A_1_tach_pulse  = p1[1];
assign A_2_dme_relay   = p1[2];
assign A_3_unused_p1_3 = p1[3];
assign A_4_idle_speed  = p1[4];
assign A_5_KLR_ign_out = p1[5];

// ─── VCD dump ───────────────────────────────────────────────
dumpvcd u_dumpvcd();

// ─── DUT ────────────────────────────────────────────────────
i8051_system  i8051_top (
    .res_n   ( rst              ),
    .clk     ( clk              ),
    .int0_n  ( reference_sensor ),
    .int1_n  ( speed_sensor     ),
    .p0      ( p0               ),
    .p0_in   ( p0_in            ),
    .p1      ( p1               ),
    .p1_in   ( p1_in            ),
    .p2      ( p2               ),
    .p2_in   ( p2_in            ),
    .p3      ( p3               ),
    .p3_in   ( p3_in            ),
    .rxd     ( rxd              ),
    .txd     ( txd              ),
    .t0      ( t0               ),
    .t1      ( t1               ),
    .ale     ( ale              ),
    .xdata   ( xdata            ),
    .xaddr   ( xaddr            ),
    .xrd_n   ( xrd_n            ),
    .xwr_n   ( xwr_n            )
);

// ─── Dynamic coolant warmup (TEST_ISV_COLD_IDLE only) ────────
`ifdef TEST_ISV_COLD_IDLE
reg [7:0]  coolant_dynamic;
reg [31:0] coolant_tick;
initial begin
    coolant_dynamic = 8'hC0;
    coolant_tick    = 32'd0;
end
always @(posedge clk) begin : coolant_warmup
    if (!rst) begin
        coolant_dynamic <= 8'hC0;
        coolant_tick    <= 32'd0;
    end else if (coolant_dynamic > 8'h20) begin
        if (coolant_tick >= 32'd4_687_500) begin
            coolant_dynamic <= coolant_dynamic - 8'h01;
            coolant_tick    <= 32'd0;
        end else
            coolant_tick <= coolant_tick + 32'd1;
    end
end
`endif

// ─── Tippy-in AFM step override ─────────────────────────────// iram[53h] is updated by the ADC scan every crank cycle — so a
// free-running step always finds delta=0 by the time airflow_calc runs.
// Fix: spike AFM ON the reference sensor rising edge. The ADC scan
// has just finished (iram[53h] = 0x28). The spike makes iram[10h]=0x78
// BEFORE airflow_calc reads it, creating delta=0x50 within the same
// crank event. Spike held for 2 seconds (~28 crank cycles at 840 RPM)
// to simulate a realistic sustained throttle opening.
`ifdef AFM_TIPPY
reg [7:0]  afm_tippy;
reg [7:0]  tippy_crank_count;
reg        tippy_fired;

initial begin
    afm_tippy         = 8'h28;
    tippy_crank_count = 8'd0;
    tippy_fired       = 1'b0;
end

always @(posedge reference_sensor) begin
    if (!tippy_fired) begin
        tippy_crank_count <= tippy_crank_count + 8'd1;
        // Fire at crank #25 — well past fuel cut end (~15 cranks at 840 RPM)
        if (tippy_crank_count == 8'd25) begin
            afm_tippy   <= 8'h78;   // large step: +80 counts over idle
            tippy_fired <= 1'b1;
        end
    end else begin
        // Hold for ~28 more crank pulses (~2 seconds at 840 RPM), then return
        tippy_crank_count <= tippy_crank_count + 8'd1;
        if (tippy_crank_count >= 8'd53)   // 25 + 28 = 53
            afm_tippy <= 8'h28;
    end
end
`endif

// ─── CL ramp AFM override ────────────────────────────────────
// Steps AFM to AFM_CL_TARGET at t=2000ms, driving firmware load
// calc to compute high fuel — CL dynamics then accelerates RPM.
// TPS also follows the AFM override for correct throttle sensing.
`ifdef AFM_CL_RAMP
reg [7:0] afm_cl;
initial begin
    afm_cl = 8'h28;   // idle until engine settled
    #2_000_000_000;   // 2000ms — past fuel cut and ASE
    afm_cl = `AFM_CL_TARGET;
end
`endif

// ─── ADC mux ────────────────────────────────────────────────
// AFM idle threshold: below = TPS closed (0x40), above = TPS open (0xDB)
// At 840 RPM afm_wiper=0x28; threshold must be > 0x28 so idle reads closed.
// At spike afm_tippy=0x78 >> threshold so TPS correctly reads open.
`define AFM_IDLE_THR 8'h30

wire [7:0] afm_wiper;
reg  [7:0] adc_mux;

always @(p2[2:0] or afm_wiper) begin
    case (p2[2:0])
`ifdef AFM_FAULT
        3'b000: adc_mux = 8'hFF;
`elsif AFM_CL_RAMP
        3'b000: adc_mux = afm_cl;
`elsif AFM_TIPPY
        3'b000: adc_mux = afm_tippy;
`else
        3'b000: adc_mux = afm_wiper;
`endif
        3'b001: adc_mux = `_BATTERY;
`ifdef TEST_AIRTEMP_FAIL
        3'b010: adc_mux = 8'h00;  // shorted sensor: 0V → ADC 0x00 → matches normal TB
`else
        3'b010: adc_mux = `_AIRTEMP_RAW;
`endif
`ifdef TEST_ISV_COLD_IDLE
        3'b011: adc_mux = coolant_dynamic;
`elsif TEST_COOLANT_FAIL
        3'b011: adc_mux = 8'h00;  // shorted sensor: matches normal TB
`else
        3'b011: adc_mux = `_COOLANT_RAW;
`endif
        3'b100: adc_mux = `_ALTITUDE;
        3'b101: adc_mux = 8'hFF;
`ifdef TPS_FIXED
        3'b110: adc_mux = `TPS_FIXED;
`elsif AFM_CL_RAMP
        3'b110: adc_mux = (afm_cl    >= `AFM_IDLE_THR) ? 8'hDB : 8'h40;
`elsif AFM_TIPPY
        3'b110: adc_mux = (afm_tippy >= `AFM_IDLE_THR) ? 8'hDB : 8'h40;
`else
        3'b110: adc_mux = (afm_wiper >= `AFM_IDLE_THR) ? 8'hDB : 8'h40;
`endif
        3'b111: adc_mux = `_FUEL_QUAL;
        default: adc_mux = 8'hF0;
    endcase
end

assign adc_data      = adc_mux;
assign xadc_data_out = adc_data_out;
assign xdata         = (!xrd_n) ? xadc_data_out : 8'bz;

adc_delay_8 adc_delay_8_1 (
    .clk     ( ale          ),
    .rst     ( rst          ),
    .data_in ( adc_data     ),
    .start   ( ~xrd_n       ),
    .data_out( adc_data_out )
);

// ─── O2 sensor ──────────────────────────────────────────────
`ifdef O2_FLAT_LEAN
    assign o2_6 = 1'b1;
    assign o2_7 = 1'b0;
`elsif O2_FLAT_RICH
    assign o2_6 = 1'b0;
    assign o2_7 = 1'b0;
`else
    wire _o2_6, _o2_7;
    o2_generator o2_generator_1 (
        .clk       ( clk   ),
        .rst       ( rst   ),
        .o2_top    ( _o2_7 ),
        .o2_bottom ( _o2_6 )
    );
    assign o2_6 = _o2_6;
    assign o2_7 = _o2_7;
`endif

// ─── P1 / P3 input assignments ──────────────────────────────
always @(clk) begin
    p1_in[0] = 1'b1;
    p1_in[1] = 1'b1;
    p1_in[2] = 1'b1;
    p1_in[3] = 1'b1;
    p1_in[4] = 1'b1;
    p1_in[5] = 1'b1;
    p1_in[6] = o2_6;
    p1_in[7] = o2_7;

    p3_in[7:6] = 2'b11;           // unused, idle high
    p3_in[5]   = t1;              // T1 (P3.5) — AC compressor status (driven via t1 assign)
    p3_in[4]   = 1'b0;            // T0 (P3.4) — has-cat flag (0 = catalytic converter fitted)
    p3_in[1:0] = {bit_out, int_uart};
    p3_in[2]   = reference_sensor;
    p3_in[3]   = speed_sensor;
    p3_in[4]   = 1'b0;
end

// ─── RPM / crank generator ──────────────────────────────────
`ifdef RPMRAMP
`ifdef CL_MODE
// Closed-loop engine dynamics — RPM driven by fuel pulse feedback
var_interrupt_generator var_interrupt_generator_1 (
    .clk       ( clk              ),
    .rst       ( rst              ),
    .int_0     ( reference_sensor ),
    .int_1     ( speed_sensor     ),
    .afm_wiper ( afm_wiper        )
);
`else
// Open-loop RPM ramp — default
var_interrupt_generator var_interrupt_generator_1 (
    .clk       ( clk              ),
    .rst       ( rst              ),
    .int_0     ( reference_sensor ),
    .int_1     ( speed_sensor     ),
    .afm_wiper ( afm_wiper        )
);
`endif
`else
  `ifdef NOINT
    assign reference_sensor = 1'b1;
    assign speed_sensor     = 1'b1;
  `else
interrupt_generator interrupt_generator_1 (
    .clk   ( clk              ),
    .rst   ( rst              ),
    .int_0 ( reference_sensor ),
    .int_1 ( speed_sensor     )
);
  `endif
`endif

// ─── External RAM ────────────────────────────────────────────
always @(posedge xwr_n)
    xram[xaddr] <= xdata;

// ─── Lambda warmup skip (matches phase_monitor.v exactly) ───
//  Watches for the falling edge of iram[23h].4 (bit1Ch) then
//  seeds bit08h+09h+1Dh and wu=0x0001 — identical to the original
//  TB which implements this in the included phase_monitor.v.
`ifdef SKIP_LAMBDA_WARMUP
reg skip_lambda_done;
reg skip_lambda_intblock_prev;
initial begin
    skip_lambda_done          = 1'b0;
    skip_lambda_intblock_prev = 1'b0;
end

always @(posedge clk) begin : lambda_warmup_skip
    skip_lambda_intblock_prev <= i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h23][4];

    if (rst && !skip_lambda_done &&
        skip_lambda_intblock_prev &&
        !i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h23][4]) begin
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h21][0] <= 1'b1; // bit08h = phase1 init done
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h21][1] <= 1'b1; // bit09h = phase2 init done
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h23][5] <= 1'b1; // bit1Dh = FuelOffCoast
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h58]    <= 8'h00; // warmup counter hi = 0
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h59]    <= 8'h01; // warmup counter lo = 1
        i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h7F]    <= 8'h14; // ISV step — warm idle baseline
        skip_lambda_done <= 1'b1;
        $display("[SEED] t=%0d ms  SKIP_LAMBDA_WARMUP — bit08h+09h+1Dh set, wu=0x0001, ISV=0x14",
                 i8051_dashboard_tb.i8051_top.u_cpu.cycle_count / 6000);
    end
end // lambda_warmup_skip
`endif // SKIP_LAMBDA_WARMUP

// ============================================================
//  SIMULATION CONTROL  (identical to i8051_dashboard_tb.v)
// ============================================================
// Pre-initialise key iram registers to 0 at t=0 to prevent
// X-state propagation into monitors before the firmware runs.
// Without this, iram[7Fh] (ISV) is X until the firmware writes
// it at ~14ms, triggering the ISV DEADLOCK monitor spuriously.
initial begin
    wait (rst === 1'b1);            // after reset deasserts
    #1;                             // one delta cycle
    i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h7F] = 8'h00;  // ISV step
    i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h36] = 8'h00;  // ISV counter
end

initial begin
    rst   = 1'b0;
    p2_in = 8'hFF;
    #1000
    rst = 1'b1;
    #`SIM_TIME
    $display("time ", $time, "\nend of time\n");
    $writememh("rom_out.hex",  i8051_dashboard_tb.i8051_top.u_eprom.mem);
    $writememh("ram_out.hex",  i8051_dashboard_tb.i8051_top.u_cpu.iram);
    $writememh("xram_out.hex", i8051_dashboard_tb.xram);
    #10000
    $finish;
end

initial begin
    clk = 0;
    forever #DELAY clk <= ~clk;
end

// ============================================================
//  REFERENCE SENSOR RPM CALCULATOR
//  Measures osc clocks between consecutive falling edges of
//  reference_sensor (P3.2 / INT0 — one pulse per revolution).
//  RPM = 60 * 6_000_000 / period_clocks
//  Held until the next revolution so every snapshot has a value.
// ============================================================
reg [63:0] ref_last_edge;
reg [63:0] ref_period;
reg [31:0] ref_rpm;
reg        ref_prev;

initial begin
    ref_last_edge = 64'd0;
    ref_period    = 64'd0;
    ref_rpm       = 32'd0;
    ref_prev      = 1'b1;
end

always @(posedge clk) begin : ref_rpm_calc
    if (!rst) begin
        ref_last_edge <= 64'd0;
        ref_period    <= 64'd0;
        ref_rpm       <= 32'd0;
        ref_prev      <= 1'b1;
    end else begin
        // Detect falling edge of reference_sensor
        if (ref_prev && !reference_sensor) begin
            if (ref_last_edge != 64'd0) begin
                ref_period = i8051_dashboard_tb.i8051_top.u_cpu.cycle_count - ref_last_edge;
                if (ref_period > 0)
                    ref_rpm <= 32'd360_000_000 / ref_period[31:0];
            end
            ref_last_edge <= i8051_dashboard_tb.i8051_top.u_cpu.cycle_count;
        end
        ref_prev <= reference_sensor;
    end
end

// ============================================================
//  DASHBOARD SNAPSHOT
//  Format: [DS] <ms>,<256hex_iram>,<p1><p2><p3>,<rpm>
// ============================================================
`define IRAM(a) i8051_dashboard_tb.i8051_top.u_cpu.iram[7'h``a``]
`define DME_MS  (i8051_dashboard_tb.i8051_top.u_cpu.cycle_count / 6000)

// Snapshot-in-progress flag — phase monitor checks this before $display
// to prevent its output from interleaving into the DS hex stream.
reg snapshot_busy;
initial snapshot_busy = 1'b0;

task emit_snapshot;
    integer i;
    begin
        snapshot_busy = 1'b1;
        $write("[DS] %0d,", `DME_MS);
        for (i = 0; i < 128; i = i + 1)
            $write("%02h", i8051_dashboard_tb.i8051_top.u_cpu.iram[i[6:0]]);
        $write(",%02h%02h%02h", p1, p2, p3);
        $write(",%0d\n", ref_rpm);
        snapshot_busy = 1'b0;
    end
endtask

reg [63:0] next_snap;
initial    next_snap = (`DASH_INTERVAL_MS * 6000);

always @(posedge clk) begin
    if (rst &&
        i8051_dashboard_tb.i8051_top.u_cpu.cycle_count >= next_snap) begin
        emit_snapshot;
        next_snap <= next_snap + (`DASH_INTERVAL_MS * 6000);
    end
end

// ============================================================
//  PHASE MONITOR (inlined — same events as phase_monitor.v)
// ============================================================
reg ph_sync_prev, ph_fuelcut_prev, ph_lambdaok_prev;
reg ph_coldenrich_prev, ph_coldtiming_prev, ph_isvovf_prev;
reg ph_usemap_prev, ph_intblock_prev;

initial begin
    ph_sync_prev       = 1'b0;
    ph_fuelcut_prev    = 1'b0;
    ph_lambdaok_prev   = 1'b0;
    ph_coldenrich_prev = 1'b0;
    ph_coldtiming_prev = 1'b0;
    ph_isvovf_prev     = 1'b0;
    ph_usemap_prev     = 1'b0;
    ph_intblock_prev   = 1'b0;
end

always @(posedge clk) begin : phase_monitor

    if (!rst) begin
        ph_sync_prev       <= 1'b0;
        ph_fuelcut_prev    <= 1'b0;
        ph_lambdaok_prev   <= 1'b0;
        ph_coldenrich_prev <= 1'b0;
        ph_coldtiming_prev <= 1'b0;
        ph_isvovf_prev     <= 1'b0;
        ph_usemap_prev     <= 1'b0;
        ph_intblock_prev   <= 1'b0;
    end else if (!snapshot_busy) begin

        // EngineSync  iram[21h].0
        if (`IRAM(21)[0] && !ph_sync_prev)
            $display("[PHASE] t=%0d ms  ENGINE SYNC                  (bit08h set)", `DME_MS);
        ph_sync_prev <= `IRAM(21)[0];

        // IntBlock  iram[23h].4 — set at power-on, cleared when engine synced
        if (`IRAM(23)[4] && !ph_intblock_prev)
            $display("[PHASE] t=%0d ms  INTERRUPT BLOCK set      (watchdog or power-on reset)",
                     `DME_MS);
        if (!`IRAM(23)[4] && ph_intblock_prev)
            $display("[PHASE] t=%0d ms  INTERRUPT BLOCK cleared  (engine synced — fully running)",
                     `DME_MS);
        ph_intblock_prev <= `IRAM(23)[4];

        // UseMap1140 / After-start enrich  iram[21h].5  (bit 0Dh)
        if (`IRAM(21)[5] && !ph_usemap_prev)
            $display("[PHASE] t=%0d ms  AFTER-START ENRICH begin (UseMap1140 set, iram[3Ch]=0x%02X)",
                     `DME_MS, `IRAM(3C));
        if (!`IRAM(21)[5] && ph_usemap_prev)
            $display("[PHASE] t=%0d ms  AFTER-START ENRICH end   (UseMap1140 clr, iram[3Ch]=0x%02X)",
                     `DME_MS, `IRAM(3C));
        ph_usemap_prev <= `IRAM(21)[5];

        // FuelOffCoast  iram[23h].5
        if (`IRAM(23)[5] && !ph_fuelcut_prev)
            $display("[PHASE] t=%0d ms  FUEL CUT begin               (FuelOffCoast set)", `DME_MS);
        if (!`IRAM(23)[5] && ph_fuelcut_prev)
            $display("[PHASE] t=%0d ms  FUEL CUT end                 (FuelOffCoast clr)", `DME_MS);
        ph_fuelcut_prev <= `IRAM(23)[5];

        // LambdaOK  iram[24h].3
        if (`IRAM(24)[3] && !ph_lambdaok_prev)
            $display("[PHASE] t=%0d ms  LAMBDA CONTROL begin         (LambdaOK set)", `DME_MS);
        if (!`IRAM(24)[3] && ph_lambdaok_prev)
            $display("[PHASE] t=%0d ms  LAMBDA CONTROL end           (LambdaOK clr)", `DME_MS);
        ph_lambdaok_prev <= `IRAM(24)[3];

        // ColdStartEnrich  iram[25h].5
        if (`IRAM(25)[5] && !ph_coldenrich_prev)
            $display("[PHASE] t=%0d ms  COLD-START ENRICH begin      (bit2Dh set)", `DME_MS);
        if (!`IRAM(25)[5] && ph_coldenrich_prev)
            $display("[PHASE] t=%0d ms  COLD-START ENRICH end        (bit2Dh clr)", `DME_MS);
        ph_coldenrich_prev <= `IRAM(25)[5];

        // ColdStartTiming  iram[25h].4
        if (`IRAM(25)[4] && !ph_coldtiming_prev)
            $display("[PHASE] t=%0d ms  COLD-START TIMING begin      (bit2Ch set)", `DME_MS);
        if (!`IRAM(25)[4] && ph_coldtiming_prev)
            $display("[PHASE] t=%0d ms  COLD-START TIMING end        (bit2Ch clr)", `DME_MS);
        ph_coldtiming_prev <= `IRAM(25)[4];

        // ISVPWMOverflow  iram[20h].5
        if (`IRAM(20)[5] && !ph_isvovf_prev)
            $display("[PHASE] t=%0d ms  ISV OVERFLOW begin           (isv_step=0x%02X)",
                     `DME_MS, `IRAM(7F));
        if (!`IRAM(20)[5] && ph_isvovf_prev)
            $display("[PHASE] t=%0d ms  ISV OVERFLOW end             (isv_step=0x%02X)",
                     `DME_MS, `IRAM(7F));
        ph_isvovf_prev <= `IRAM(20)[5];

    end
end

// ─── Watchdog stall detector ─────────────────────────────────
// Monitors iram[2Ah] continuously within each 500ms window.
// Sets ph_wdog_changed if the value changes at ANY clock edge
// during the window. Only fires warning if the value was completely
// static for the full window — ignores harmonic coincidences where
// the loop period divides evenly into the sample interval.
reg [7:0]  ph_wdog_last;
reg        ph_wdog_changed;
reg [63:0] ph_wdog_next_sample;
initial begin
    ph_wdog_last        = 8'hFF;
    ph_wdog_changed     = 1'b0;
    ph_wdog_next_sample = 64'd12_000_000;  // first check at 2000ms
end

always @(posedge clk) begin : wdog_stall_detect
    if (!rst) begin
        ph_wdog_last        <= 8'hFF;
        ph_wdog_changed     <= 1'b0;
        ph_wdog_next_sample <= 64'd12_000_000;
    end else begin
        // Detect any change within window
        if (`IRAM(2A) != ph_wdog_last) begin
            ph_wdog_changed <= 1'b1;
            ph_wdog_last    <= `IRAM(2A);
        end

        // At each window boundary, check and reset
        if (i8051_dashboard_tb.i8051_top.u_cpu.cycle_count >= ph_wdog_next_sample &&
            i8051_dashboard_tb.i8051_top.u_cpu.cycle_count > 6_000_000) begin
            if (!ph_wdog_changed)
                $display("[PHASE] t=%0d ms  WARNING: WATCHDOG STALLED    (wdog=0x%02X)",
                         `DME_MS, `IRAM(2A));
            ph_wdog_changed     <= 1'b0;
            ph_wdog_next_sample <= ph_wdog_next_sample + 64'd12_000_000;
        end
    end
end

endmodule
