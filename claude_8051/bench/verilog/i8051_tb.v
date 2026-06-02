`include "timescale.v"

// ============================================================
//  89 DME 951 (Bosch Motronic 3.1) simulation testbench
//
//  Test selection — uncomment ONE test block below, or pass
//  -D flags on the iverilog command line.
//
//  Example:
//    iverilog -DTEST_WARM_IDLE -DSKIP_LAMBDA_WARMUP \
//             -DSIM_TIME=80000000000 ...
//
// ============================================================

// --------------------------------------------------------
//  TEST SELECTION — uncomment one group
//  (or pass via -D flag to iverilog)
// --------------------------------------------------------

// --- Idle tests ---
//`define TEST_WARM_IDLE               // 25s sim / 25m wall          // Warm idle 840 RPM, lambda active
//`define TEST_COLD_START              // 120s sim / 120m wall       // Cold start, coolant 20°C, lambda warmup
//`define TEST_HOT_IDLE                // 25s sim / 25m wall           // Idle after extended run, coolant 100°C
//`define TEST_IDLE_BATTERY_LOW        //  5s sim /  5m wall   // Idle with low battery 11V (injector deadtime)
//`define TEST_IDLE_HIGH_ALT           //  5s sim /  5m wall      // Idle at high altitude (ch4=0x00)
//`define TEST_IDLE_POOR_FUEL          //  5s sim /  5m wall     // Idle with poor fuel quality (ch7=0x00)

// --- Fuel transient tests ---
//`define TEST_TIPPY_IN           // Throttle snap open from idle (accel enrichment)
//`define TEST_OVERRUN_CUTOFF     // Throttle close at speed (fuel cut on overrun)
//`define TEST_WARMUP_ENRICHMENT  // Cold start enrichment decay over 60 sec
//`define TEST_AFM_OPEN_CIRCUIT        //  5s sim /  5m wall   // AFM failure (ch0=0xFF), limp-home

// --- RPM sweep tests ---
//`define TEST_RAMP_TO_3000            // 10s sim / 10m wall       // Idle → 3000 RPM ramp
//`define TEST_RAMP_TO_6000            // 10s sim / 10m wall       // Idle → 6000 RPM ramp
//`define TEST_RAMP_TO_REDLINE         // 10s sim / 10m wall    // Idle → 6500 RPM (rev limiter test)
//`define TEST_RAMP_6K_HOLD            // 15s sim / 15m wall       // Idle → 6000 RPM, hold 20 sec (lambda at high RPM)

// --- Sensor failure tests ---
//`define TEST_COOLANT_FAIL            //  5s sim /  5m wall       // Coolant NTC open circuit (ch3=0x00), max cold enrichment
//`define TEST_AIRTEMP_FAIL            //  5s sim /  5m wall       // Air temp NTC open circuit (ch2=0x00), default temp
//`define TEST_O2_DISCONNECTED         // 25s sim / 25m wall    // O2 sensor dead (pins float to 0V = logic 0 = rich), integrator leans out
//`define TEST_O2_RICH_STUCK           // 25s sim / 25m wall      // O2 sensor stuck rich
//`define TEST_O2_LEAN_STUCK           // 25s sim / 25m wall      // O2 sensor stuck lean
//`define TEST_TPS_FAIL                //  5s sim /  5m wall           // TPS failure (ch6=0x80), partial load fuel

// --- Ignition tests ---
//`define TEST_IGNITION_TIMING         // 15s sim / 15m wall    // Verify spark timing vs RPM/load table
//`define TEST_DWELL_SCALING           // 15s sim / 15m wall      // Dwell angle vs RPM (constant time check)

// --- ISV / idle speed control tests ---
//`define TEST_ISV_COLD_IDLE           // 60s sim / 60m wall      // ISV duty cycle at cold idle vs warm idle
//`define TEST_ISV_LOAD_DROOP          // 12s sim / 12m wall     // ISV response to simulated load (RPM drop at t=5s)

// --------------------------------------------------------
//  Common sim parameters — override per test below
// --------------------------------------------------------
`ifndef SIM_TIME
  `define SIM_TIME   80000000000   // 80 sec default
`endif
`ifndef RPMSTART
  `define RPMSTART   100
`endif
`ifndef RPMEND
  `define RPMEND     840
`endif
`ifndef RPM_RAMP_PCT
  `define RPM_RAMP_PCT 25
`endif

// --------------------------------------------------------
//  Per-test parameter overrides
// --------------------------------------------------------

// --- TEST_WARM_IDLE ---
`ifdef TEST_WARM_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 10
  `undef  SIM_TIME
  `define SIM_TIME  60000000000   // 60 sec
  `define _COOLANT_RAW  8'h20    // ~80°C
  `define _AIRTEMP_RAW  8'h50    // ~20°C
  `define _BATTERY      8'hD8    // 13.5V
  `define _ALTITUDE     8'hF8    // sea level
  `define _FUEL_QUAL    8'h80    // standard
`endif

// --- TEST_COLD_START ---
`ifdef TEST_COLD_START
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  120000000000  // 120 sec
  `define _COOLANT_RAW  8'hC0    // cold — linearises to >= 0x8F threshold for cold-start enrich
  `define _AIRTEMP_RAW  8'h70    // ~5°C (cold intake air)
  `define _BATTERY      8'hD8    // 13.5V
  `define _ALTITUDE     8'hF8    // sea level
  `define _FUEL_QUAL    8'h80    // standard
`endif

// --- TEST_HOT_IDLE ---
`ifdef TEST_HOT_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  25000000000   // 25 sec
  `define _COOLANT_RAW  8'h10    // ~100°C (hot)
  `define _AIRTEMP_RAW  8'h50    // ~20°C intake
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_IDLE_BATTERY_LOW ---
`ifdef TEST_IDLE_BATTERY_LOW
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'h8C    // 11.0V (low battery)
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_IDLE_HIGH_ALT ---
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
  `define _ALTITUDE     8'h00    // above 1000m
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_IDLE_POOR_FUEL ---
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
  `define _FUEL_QUAL    8'h00    // poor/low octane fuel
`endif

// --- TEST_AC_ON_IDLE ---
`ifdef TEST_AC_ON_IDLE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AC_COMP_ON                 // T1=1: AC compressor active
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  10000000000      // 10s — observe ISV and fuel response to AC load
  `define _COOLANT_RAW  8'h20        // warm engine
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_CL_RAMP_TO_3000 ---
`ifdef TEST_CL_RAMP_TO_3000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'h72      // 3000 RPM → ADC≈0x72
  `undef  SIM_TIME
  `define SIM_TIME  30000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_CL_RAMP_TO_6000 ---
`ifdef TEST_CL_RAMP_TO_6000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'hDA      // 6000 RPM → ADC≈0xDA
  `undef  SIM_TIME
  `define SIM_TIME  40000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_CL_RAMP_TO_REDLINE ---
`ifdef TEST_CL_RAMP_TO_REDLINE
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define AFM_CL_RAMP
  `define AFM_CL_TARGET  8'hEB      // 6500 RPM → ADC=0xEB (max)
  `undef  SIM_TIME
  `define SIM_TIME  40000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_CL_AC_HALFWAY ---
`ifdef TEST_CL_AC_HALFWAY
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define CL_MODE
  `define CL_AC_HALFWAY              // T1 switches on at SIM_TIME/2
  `undef  SIM_TIME
  `define SIM_TIME  20000000000     // 20s — 10s pre-AC, 10s with AC
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_CL_COLD_START ---
`ifdef TEST_CL_COLD_START
  `define RPMRAMP
  `define CL_MODE                    // no SKIP_LAMBDA_WARMUP — genuine cold start
  `undef  SIM_TIME
  `define SIM_TIME  60000000000
  `define _COOLANT_RAW  8'hC0       // cold — above 0x8F threshold for cold-start enrich
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_TIPPY_IN ---
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
`ifdef TEST_AFM_OPEN_CIRCUIT
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define AFM_FAULT             // overrides ch0 to 0xFF in ADC mux
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

// --- TEST_OVERRUN_CUTOFF ---
`ifdef TEST_OVERRUN_CUTOFF
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 10
  `undef  SIM_TIME
  `define SIM_TIME  30000000000   // 30 sec — short ramp, ~25s steady state
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_WARMUP_ENRICHMENT ---
`ifdef TEST_WARMUP_ENRICHMENT
  `define RPMRAMP
  // Note: use CPU_DEBUG only when compiling with i8051_tb (normal TB).
  // Passing -DCPU_DEBUG via the run script for normal TB runs only.
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  60000000000   // 60 sec — observe enrichment decay over time
  `define _COOLANT_RAW  8'hC0    // cold — linearises to >= 0x8F threshold for cold-start enrich
  `define _AIRTEMP_RAW  8'h70    // ~5°C cold intake air
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_COOLANT_FAIL ---
`ifdef TEST_COOLANT_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h00   // shorted NTC: 0V → ADC 0x00 → firmware linearises to 104°C hot
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_AIRTEMP_FAIL ---
`ifdef TEST_AIRTEMP_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  5000000000
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h00   // shorted NTC: 0V → ADC 0x00 → firmware linearises to 104°C hot air
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_O2_DISCONNECTED ---
`ifdef TEST_O2_DISCONNECTED
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  // O2_FLAT_RICH passed via -DO2_FLAT_RICH: disconnected pins float to 0.07V = logic 0
  // P1.6=0 → jnb 96h taken → rich path → integrator leans mixture out
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

// --- TEST_O2_RICH_STUCK ---
`ifdef TEST_O2_RICH_STUCK
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  // O2_FLAT_RICH is passed directly via -DO2_FLAT_RICH on the compile command line
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

// --- TEST_O2_LEAN_STUCK ---
`ifdef TEST_O2_LEAN_STUCK
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  // O2_FLAT_LEAN is passed directly via -DO2_FLAT_LEAN on the compile command line
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

// --- TEST_TPS_FAIL ---
`ifdef TEST_TPS_FAIL
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define TPS_FIXED 8'h80       // mid-range — neither idle nor WOT
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

// --- TEST_RAMP_TO_3000 ---
`ifdef TEST_RAMP_TO_3000
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `undef  RPMEND
  `define RPMEND    3000
  `undef  RPM_RAMP_PCT
  `define RPM_RAMP_PCT 50
  `undef  SIM_TIME
  `define SIM_TIME  10000000000  // 10 sec
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_RAMP_TO_6000 ---
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

// --- TEST_RAMP_TO_REDLINE ---
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

// --- TEST_RAMP_6K_HOLD ---
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

// --- TEST_IGNITION_TIMING ---
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

// --- TEST_DWELL_SCALING ---
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

// --- TEST_ISV_COLD_IDLE ---
`ifdef TEST_ISV_COLD_IDLE
  `define RPMRAMP
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  60000000000  // 60 sec — watch ISV drop as engine warms
  `define _COOLANT_RAW  8'h60    // cold start
  `define _AIRTEMP_RAW  8'h70
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --- TEST_ISV_LOAD_DROOP ---
`ifdef TEST_ISV_LOAD_DROOP
  `define RPMRAMP
  `define SKIP_LAMBDA_WARMUP
  `define ISV_LOAD_DROOP        // phase_monitor seeds a brief RPM drop
  `undef  RPMEND
  `define RPMEND    840
  `undef  SIM_TIME
  `define SIM_TIME  12000000000  // 12 sec — droop at 5s, recover by 5.5s, observe ISV
  `define _COOLANT_RAW  8'h20
  `define _AIRTEMP_RAW  8'h50
  `define _BATTERY      8'hD8
  `define _ALTITUDE     8'hF8
  `define _FUEL_QUAL    8'h80
`endif

// --------------------------------------------------------
//  Default values for optional ADC channel overrides
// --------------------------------------------------------
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

`define RPMCONST 2727272  // 6MHz * 60 / 132 teeth = exact
`define DME_FREQ  6000    // DME 8051 clock half-periods per ms (6 MHz)

module i8051_tb (
    // External I/O signals
    input  wire ign,              // Ignition switch input
    output wire A_1_tach_pulse,   // Tachometer output (P1.1)
    output wire A_5_KLR_ign_out,  // KLR / ignition coil primary (P1.5)
    input  wire full_load         // Full-load (WOT) switch → ADC ch6 / TPS
);

`ifndef FRQ_SCALE
  `define FRQ_SCALE  500000   // half-period scale (ns × kHz); DELAY = FRQ_SCALE/FREQ
`endif
parameter DELAY = `FRQ_SCALE / `DME_FREQ;

reg  rst, clk;
reg  [7:0] p0_in, p1_in, p2_in,p3_in;

// Initialise all port inputs to safe defaults at t=0 so the firmware
// never sees X on any pin — especially T0 (P3.4) and T1 (P3.5).
initial begin
    p0_in = 8'hFF;
    p1_in = 8'hFF;
    p2_in = 8'hFF;
    p3_in = 8'hFF;   // all idle-high; always block overrides at first clock edge
end
wire  [7:0] p0, p1, p2, p3;
wire [15:0] ext_addr;
wire write, write_uart, rxd, int_uart, reference_sensor, speed_sensor, bit_out, stb_o, ack_i;
// T0/T1 are separate top-level ports — not derived from p3_in.
// Drive explicitly to prevent X propagation into the timer module.
// T1 = AC compressor status input: 0=off (default), 1=on.
//      Override with -DAC_COMP_ON (always on) or -DCL_AC_HALFWAY (on at SIM_TIME/2).
`ifdef CL_AC_HALFWAY
reg t1;
initial begin
    t1 = 1'b0;
    #(`SIM_TIME / 2);
    t1 = 1'b1;
end
`elsif AC_COMP_ON
wire t1; assign t1 = 1'b1;   // AC compressor active
`else
wire t1; assign t1 = 1'b0;   // AC compressor off (default)
`endif
wire t0;  assign t0 = 1'b0;   // T0 = has catalytic converter (0 = fitted)
wire ack_uart, cyc_o, iack_i, istb_o, icyc_o, t2, t2ex;
wire [7:0] data_in, data_out, data_out_uart;
reg [7:0] diag_data, diag_addr;
wire o2_6, o2_7;
wire [15:0] addr_bus;
reg  [7:0]  rom_data;
wire        xrd_n, xwr_n;
wire [15:0] xaddr;
wire [7:0]  xdata;
reg  [7:0]  xdata_in;
wire [7:0]  adc_data;
wire [7:0]  xadc_data_out, adc_data_out;
wire ale, txd;
wire dumreference_sensor, dumspeed_sensor;

// P1 output signal aliases — A_1_tach_pulse and A_5_KLR_ign_out are module ports
wire A_0_inj_driver;
wire A_2_dme_relay;
wire A_3_unused_p1_3;
wire A_4_idle_speed;

assign A_0_inj_driver  = p1[0];  // Injectors         active-low
assign A_1_tach_pulse  = p1[1];  // Tachometer        pulse     (module output)
assign A_2_dme_relay   = p1[2];  // DME relay/fuel pump active-low
assign A_3_unused_p1_3 = p1[3];  // unused
assign A_4_idle_speed  = p1[4];  // Idle speed positioner + watchdog
assign A_5_KLR_ign_out = p1[5];  // KLROut / ignition coil primary (module output)

// --------------------------------------------------------
//  VCD dump
// --------------------------------------------------------
dumpvcd u_dumpvcd(.clk(clk), .pc(i8051_top.u_cpu.pc));

// --------------------------------------------------------
//  CPU core instantiation
// --------------------------------------------------------
i8051_system  i8051_top (
    .res_n   ( rst    ),
    .clk     ( clk    ),
    .int0_n  ( reference_sensor ),
    .int1_n  ( speed_sensor     ),
    .p0      ( p0     ),
    .p0_in   ( p0_in  ),
    .p1      ( p1     ),
    .p1_in   ( p1_in  ),
    .p2      ( p2     ),
    .p2_in   ( p2_in  ),
    .p3      ( p3     ),
    .p3_in   ( p3_in  ),
    .rxd     ( rxd    ),
    .txd     ( txd    ),
    .t0      ( t0     ),
    .t1      ( t1     ),
    .ale     ( ale    ),
    .xdata   ( xdata  ),
    .xaddr   ( xaddr  ),
    .xrd_n   ( xrd_n  ),
    .xwr_n   ( xwr_n  )
);

// --------------------------------------------------------
//  Dynamic coolant warmup  (TEST_ISV_COLD_IDLE and TEST_COLD_START)
//
//  Simulates coolant rising from cold to warm.
//  NTC is inverse: lower raw = hotter temperature.
//
//  ISV_COLD_IDLE: 0x68 (~5°C) → 0x20 (~80°C) over 50s
//    Rate: 72 steps / 50s = 4,166,667 clocks/step
//
//  COLD_START: 0xC0 (~52°C ADC) → 0x20 (~80°C) over 100s
//    Rate: 160 steps / 100s = 3,750,000 clocks/step
// --------------------------------------------------------
`ifdef TEST_ISV_COLD_IDLE
reg [7:0]  coolant_dynamic;
reg [31:0] coolant_tick;
initial begin
    coolant_dynamic = 8'h68;
    coolant_tick    = 32'd0;
end
always @(posedge clk) begin : coolant_warmup
    if (!rst) begin
        coolant_dynamic <= 8'h68;
        coolant_tick    <= 32'd0;
    end else if (coolant_dynamic > 8'h20) begin
        if (coolant_tick >= 32'd4_166_667) begin
            coolant_dynamic <= coolant_dynamic - 8'h01;
            coolant_tick    <= 32'd0;
        end else
            coolant_tick <= coolant_tick + 32'd1;
    end
end
`elsif TEST_COLD_START
reg [7:0]  coolant_dynamic;
reg [31:0] coolant_tick;
initial begin
    coolant_dynamic = 8'hC0;   // 52°C start — above cold-enrich threshold 0x8F
    coolant_tick    = 32'd0;
end
always @(posedge clk) begin : coolant_warmup
    if (!rst) begin
        coolant_dynamic <= 8'hC0;
        coolant_tick    <= 32'd0;
    end else if (coolant_dynamic > 8'h20) begin
        if (coolant_tick >= 32'd3_750_000) begin
            coolant_dynamic <= coolant_dynamic - 8'h01;
            coolant_tick    <= 32'd0;
        end else
            coolant_tick <= coolant_tick + 32'd1;
    end
end
`endif

// --------------------------------------------------------
//  ADC
// --------------------------------------------------------
`define AFM_IDLE_THR 8'h30

// ─── Tippy-in AFM step override ─────────────────────────────
// iram[53h] is updated by the ADC scan every crank cycle — so a
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
        if (tippy_crank_count == 8'd25) begin
            afm_tippy   <= 8'h78;
            tippy_fired <= 1'b1;
        end
    end else begin
        tippy_crank_count <= tippy_crank_count + 8'd1;
        if (tippy_crank_count >= 8'd53)   // 25 + 28 = 53
            afm_tippy <= 8'h28;
    end
end
`endif

// ─── CL ramp AFM override ────────────────────────────────────
// Steps AFM to AFM_CL_TARGET at t=2000ms and holds, driving the
// firmware load calc to compute elevated fuel.  CL dynamics then
// accelerates RPM naturally until a new equilibrium is reached.
`ifdef AFM_CL_RAMP
reg [7:0] afm_cl;
initial begin
    afm_cl = 8'h28;   // idle until engine settled
    #2_000_000_000;   // 2000ms — past fuel cut and ASE
    afm_cl = `AFM_CL_TARGET;
end
`endif

wire [7:0] afm_wiper;
reg  [7:0] adc_mux;

always @(p2[2:0] or afm_wiper) begin
  case (p2[2:0])
    // ch0: AFM wiper
`ifdef AFM_FAULT
    3'b000:  adc_mux = 8'hFF;            // open circuit fault
`elsif AFM_CL_RAMP
    3'b000:  adc_mux = afm_cl;           // CL ramp target
`elsif AFM_TIPPY
    3'b000:  adc_mux = afm_tippy;        // step-change for accel enrichment test
`else
    3'b000:  adc_mux = afm_wiper;
`endif
    3'b001:  adc_mux = `_BATTERY;        // ch1: battery voltage
    3'b010:  adc_mux = `_AIRTEMP_RAW;    // ch2: intake air NTC
`ifdef TEST_ISV_COLD_IDLE
    3'b011:  adc_mux = coolant_dynamic;   // ch3: coolant NTC (warms over time)
`elsif TEST_COLD_START
    3'b011:  adc_mux = coolant_dynamic;   // ch3: coolant NTC (warms over sim)
`else
    3'b011:  adc_mux = `_COOLANT_RAW;    // ch3: coolant NTC (static)
`endif
    3'b100:  adc_mux = `_ALTITUDE;       // ch4: altitude switch
    3'b101:  adc_mux = 8'hFF;            // ch5: unused
    // ch6: TPS
`ifdef TPS_FIXED
    3'b110:  adc_mux = `TPS_FIXED;
`elsif AFM_CL_RAMP
    3'b110:  adc_mux = full_load ? 8'hDB : 8'h40;  // KLR full_load: WOT=0xDB, else=0x40
`elsif AFM_TIPPY
    3'b110:  adc_mux = full_load ? 8'hDB : 8'h40;  // KLR full_load: WOT=0xDB, else=0x40
`else
    // full_load from KLR: 1=WOT (0xDB), 0=closed throttle (0x40)
    3'b110:  adc_mux = full_load ? 8'hDB : 8'h40;
`endif
    3'b111:  adc_mux = `_FUEL_QUAL;      // ch7: fuel quality
    default: adc_mux = 8'hF0;
  endcase
end

assign adc_data = adc_mux;
assign xadc_data_out = adc_data_out;
assign xdata = (!xrd_n) ? xadc_data_out : 8'bz;

adc_delay_8 adc_delay_8_1 (
    .clk     ( ale         ),
    .rst     ( rst         ),
    .data_in ( adc_data    ),
    .start   ( ~xrd_n      ),
    .data_out( adc_data_out)
);

// --------------------------------------------------------
//  O2 generator — can be overridden by test defines
// --------------------------------------------------------
`ifdef O2_FLAT_LEAN
  assign o2_6 = 1'b1;   // P1.6=1: jnb 96h fails → does NOT jump to rich
  assign o2_7 = 1'b0;   // P1.7=0: jb  97h fails → does NOT jump to rich → lean path
`elsif O2_FLAT_RICH
  assign o2_6 = 1'b0;   // P1.6=0: jnb 96h taken → jumps to rich path
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

// --------------------------------------------------------
//  P1 / P3 input assignments
// --------------------------------------------------------
always @(clk) begin
    p1_in[0] = 1'b1;      // injector feedback
    p1_in[1] = 1'b1;
    p1_in[2] = 1'b1;
    p1_in[3] = 1'b1;
    p1_in[4] = 1'b1;
    p1_in[5] = 1'b1;
    p1_in[6] = o2_6;      // O2 sensor bottom (lean threshold)
    p1_in[7] = o2_7;      // O2 sensor top    (lean only)

    p3_in[7:6] = 2'b11;           // unused, idle high
    p3_in[5]   = t1;              // T1 (P3.5) — AC compressor status (driven via t1 assign)
    p3_in[4]   = 1'b0;            // T0 (P3.4) — has-cat flag (0 = catalytic converter fitted)
    p3_in[1:0] = {bit_out, int_uart};
    p3_in[2]   = reference_sensor;
    p3_in[3]   = speed_sensor;
    p3_in[4]   = 1'b0;    // T0 perf data — 0 = has cat
end

// --------------------------------------------------------
//  RPM generator
// --------------------------------------------------------
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

// --------------------------------------------------------
//  External DIAG
// --------------------------------------------------------
always @(posedge xwr_n)
    begin
      diag_data <= xdata;
      diag_addr <=p2;
    end

// --------------------------------------------------------
//  Simulation control
// --------------------------------------------------------

// Pre-initialise key iram registers to 0 at t=0 to prevent
// X-state from triggering monitors before the firmware runs.
// Only when SKIP_LAMBDA_WARMUP — cold-start tests must let firmware init.
`ifdef SKIP_LAMBDA_WARMUP
initial begin
    wait (rst === 1'b1);
    #1;
    i8051_tb.i8051_top.u_cpu.iram[7'h7F] = 8'h00;  // ISV step
    i8051_tb.i8051_top.u_cpu.iram[7'h36] = 8'h00;  // ISV counter
end
`endif

initial begin
    rst   = 1'b0;
    p2_in = 8'hFF;
    #1000
    rst = 1'b1;
    #`SIM_TIME
    $display("time ", $time, "\nend of time\n");
    $writememh("rom_out.hex",  i8051_tb.i8051_top.u_eprom.mem);
    $writememh("ram_out.hex",  i8051_tb.i8051_top.u_cpu.iram);
    #10000
    $finish;
end

initial begin
    clk = 0;
    forever #DELAY clk <= ~clk;
end

// --------------------------------------------------------
//  Phase monitor and test helpers
// --------------------------------------------------------
`include "phase_monitor.v"

endmodule
