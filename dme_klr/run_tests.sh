#!/bin/bash
# ============================================================
#  89 DME 951 simulation test suite
#
#  Usage:
#    ./run_tests.sh              # run all tests
#    ./run_tests.sh warm_idle    # run single test by short name
#
#  Output: ../../tmp/dme_klr/logs/<test_name>.log
#                                     <test_name>_status.log
#                                     <test_name>_phase.log
#          ../../tmp/dme_klr/logs/vcd/<test_name>.vcd
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VVP_DIR="$(cd "$SCRIPT_DIR" && cd ../../tmp/dme_klr 2>/dev/null || { mkdir -p ../../tmp/dme_klr && cd ../../tmp/dme_klr; } && pwd)"
LOGDIR="$VVP_DIR/logs"
VCDDIR="$VVP_DIR/logs/vcd"
HEXDIR="$VVP_DIR/logs/hex"
FILES=files
RTL=rtl/verilog
BENCH=bench/verilog
RTLd=../claude_8051/rtl/verilog
BENCHd=../claude_8051/bench/verilog
RTLk=../gemini8048/rtl/verilog
BENCHk=../gemini8048/bench/verilog

mkdir -p "$VVP_DIR"
mkdir -p "$LOGDIR"
mkdir -p "$VCDDIR"
mkdir -p "$HEXDIR"

# --------------------------------------------------------
#  compile_and_run <short_name> <iverilog -D flags...>
#  VCD_FILE is written to VCDDIR/<short_name>.vcd
# --------------------------------------------------------
compile_and_run() {
    local name="$1"; shift
    local vvp="${VVP_DIR}/vvp_${name}.vvp"
    local log="${LOGDIR}/${name}.log"
    local vcdfile="${VCDDIR}/${name}.vcd"
    local hexdir="${HEXDIR}/${name}"
    local vcd_define=""  # VCD written as sim.vcd in hexdir, moved after

    mkdir -p "$hexdir"

    # Extract SIM_TIME from the defines to show simulated duration
    local sim_ns=0
    for arg in "$@"; do
        case "$arg" in
            -DSIM_TIME=*) sim_ns="${arg#-DSIM_TIME=}" ;;
        esac
    done
    local sim_sec=$(( sim_ns / 1000000000 ))

    echo ""
    echo "======================================================"
    echo "  TEST: $name  [${sim_sec}s simulated / ~${sim_sec}m wall]"
    echo "======================================================"

    # Compile — swap files list when -DCL_MODE is present
    local files_list="$FILES"
    for arg in "$@"; do
        [[ "$arg" == "-DCL_MODE" ]] && files_list="files_cl"
    done

    iverilog -o "$vvp" \
        -f "$files_list" \
        -I "$RTL" \
        -I "$BENCH" \
        -I "$RTLd" \
        -I "$BENCHd" \
        -I "$RTLk" \
        -I "$BENCHk" \
        -s dme_klr_tb \
        "$@"
    if [ $? -ne 0 ]; then
        echo "  COMPILE FAILED: $name" | tee -a "$LOGDIR/summary.log"
        return 1
    fi

    echo "  Running → $log"
    echo "  VCD     → $vcdfile"
    echo "  HEX     → $hexdir/{rom,ram,xram}_out.hex"
    # vvp runs from hexdir: sim.vcd and hex files land there, no parallel conflicts
    ( cd "$hexdir" && vvp "$vvp" ) > "$log" 2>&1
    if [ $? -ne 0 ]; then
        echo "  SIM FAILED: $name" | tee -a "$LOGDIR/summary.log"
        return 1
    fi

    # Move sim.vcd to its proper named location in logs/vcd/ then compress
    if [ -f "$hexdir/sim.vcd" ]; then
        mv "$hexdir/sim.vcd" "$vcdfile"
        gzip -f "$vcdfile"
        vcdfile="${vcdfile}.gz"
    fi

    grep "^\[STATUS\]" "$log" > "$LOGDIR/${name}_status.log"
    grep "^\[PHASE\]"  "$log" > "$LOGDIR/${name}_phase.log"

    local nlines=$(wc -l < "$log")
    local nstatus=$(wc -l < "$LOGDIR/${name}_status.log")
    local nphase=$(wc -l < "$LOGDIR/${name}_phase.log")
    local vcdsize=$(du -sh "$vcdfile" 2>/dev/null | cut -f1 || echo "?")
    echo "  DONE: $name  ($nlines lines, $nstatus STATUS, $nphase PHASE, VCD ${vcdsize})" \
        | tee -a "$LOGDIR/summary.log"
}

# --------------------------------------------------------
#  Test definitions
# --------------------------------------------------------
run_all() {

# --- Idle tests ---
compile_and_run warm_idle \
    -DTEST_WARM_IDLE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000

# --- Closed-loop tests ---
compile_and_run cl_warm_idle \
    -DTEST_WARM_IDLE \
    -DRPMRAMP -DCL_MODE  \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000

compile_and_run cl_tippy_in \
    -DTEST_TIPPY_IN \
    -DRPMRAMP -DCL_MODE  \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run cl_ramp_to_3000 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'h72" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000

compile_and_run cl_ramp_to_6000 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hDA" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

compile_and_run cl_ramp_to_redline \
    -DTEST_CL_RAMP_TO_REDLINE \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hEB" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

compile_and_run cl_ac_halfway \
    -DTEST_CL_AC_HALFWAY \
    -DRPMRAMP -DCL_MODE  -DCL_AC_HALFWAY \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000

compile_and_run cl_cold_start \
    -DTEST_CL_COLD_START \
    -DRPMRAMP -DCL_MODE  \
    -DSIM_TIME=60000000000

compile_and_run cold_start \
    -DTEST_COLD_START \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSIM_TIME=120000000000

compile_and_run hot_idle \
    -DTEST_HOT_IDLE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

compile_and_run idle_battery_low \
    -DTEST_IDLE_BATTERY_LOW \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

compile_and_run idle_high_alt \
    -DTEST_IDLE_HIGH_ALT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

compile_and_run idle_poor_fuel \
    -DTEST_IDLE_POOR_FUEL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

compile_and_run ac_on_idle \
    -DTEST_AC_ON_IDLE \
    -DAC_COMP_ON \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run overrun_cutoff \
    -DTEST_OVERRUN_CUTOFF \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000

compile_and_run tippy_in \
    -DTEST_TIPPY_IN \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run warmup_enrichment \
    -DTEST_WARMUP_ENRICHMENT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSIM_TIME=60000000000

# --- Sensor failure tests ---
compile_and_run afm_open_circuit \
    -DTEST_AFM_OPEN_CIRCUIT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

compile_and_run coolant_fail \
    -DTEST_COOLANT_FAIL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

compile_and_run airtemp_fail \
    -DTEST_AIRTEMP_FAIL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

compile_and_run o2_disconnected \
    -DTEST_O2_DISCONNECTED -DO2_FLAT_RICH \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

compile_and_run o2_rich_stuck \
    -DTEST_O2_RICH_STUCK -DO2_FLAT_RICH \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

compile_and_run o2_lean_stuck \
    -DTEST_O2_LEAN_STUCK -DO2_FLAT_LEAN \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

compile_and_run tps_fail \
    -DTEST_TPS_FAIL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

# --- RPM sweep tests ---
compile_and_run ramp_to_3000 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run ramp_to_6000 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run ramp_to_redline \
    -DTEST_RAMP_TO_REDLINE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6500 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run ramp_6k_hold \
    -DTEST_RAMP_6K_HOLD \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000

# --- Ignition tests ---
compile_and_run ignition_timing \
    -DTEST_IGNITION_TIMING \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=50 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000

compile_and_run dwell_scaling \
    -DTEST_DWELL_SCALING \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=80 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000

# --- ISV tests ---
compile_and_run isv_cold_idle \
    -DTEST_ISV_COLD_IDLE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSIM_TIME=60000000000

compile_and_run isv_load_droop \
    -DTEST_ISV_LOAD_DROOP \
    -DISV_LOAD_DROOP \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=12000000000

}

# --------------------------------------------------------
#  Single test mode: ./run_tests.sh <n>
# --------------------------------------------------------
if [ -n "$1" ]; then
    case "$1" in
        warm_idle)        compile_and_run warm_idle        -DTEST_WARM_IDLE        -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000  ;;
        cl_warm_idle)     compile_and_run cl_warm_idle     -DTEST_WARM_IDLE        -DRPMRAMP -DCL_MODE -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000                        ;;
        cl_tippy_in)      compile_and_run cl_tippy_in      -DTEST_TIPPY_IN         -DRPMRAMP -DCL_MODE -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000                        ;;
        cl_ramp_to_3000)  compile_and_run cl_ramp_to_3000  -DCPU_DEBUG -DTEST_CL_RAMP_TO_3000  -DRPMRAMP -DCL_MODE  -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'h72" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000 ;;
        cl_ramp_to_6000)  compile_and_run cl_ramp_to_6000  -DTEST_CL_RAMP_TO_6000  -DRPMRAMP -DCL_MODE  -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hDA" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_redline) compile_and_run cl_ramp_to_redline -DTEST_CL_RAMP_TO_REDLINE -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hEB" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ac_halfway)    compile_and_run cl_ac_halfway     -DTEST_CL_AC_HALFWAY    -DRPMRAMP -DCL_MODE -DCL_AC_HALFWAY -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000 ;;
        cl_cold_start)    compile_and_run cl_cold_start     -DTEST_CL_COLD_START    -DRPMRAMP -DCL_MODE -DSIM_TIME=60000000000 ;;
        cold_start)       compile_and_run cold_start       -DTEST_COLD_START       -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25                       -DSIM_TIME=120000000000  ;;
        hot_idle)         compile_and_run hot_idle         -DTEST_HOT_IDLE         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        idle_battery_low) compile_and_run idle_battery_low -DTEST_IDLE_BATTERY_LOW -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000  ;;
        idle_high_alt)    compile_and_run idle_high_alt    -DTEST_IDLE_HIGH_ALT    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000  ;;
        idle_poor_fuel)   compile_and_run idle_poor_fuel   -DTEST_IDLE_POOR_FUEL   -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000  ;;
        ac_on_idle)       compile_and_run ac_on_idle       -DTEST_AC_ON_IDLE       -DAC_COMP_ON -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        afm_open_circuit) compile_and_run afm_open_circuit -DTEST_AFM_OPEN_CIRCUIT -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000  ;;
        coolant_fail)     compile_and_run coolant_fail     -DTEST_COOLANT_FAIL     -DCPU_DEBUG -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000  ;;
        airtemp_fail)     compile_and_run airtemp_fail     -DTEST_AIRTEMP_FAIL     -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000  ;;
        o2_disconnected)  compile_and_run o2_disconnected  -DTEST_O2_DISCONNECTED  -DO2_FLAT_RICH  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        o2_rich_stuck)    compile_and_run o2_rich_stuck    -DTEST_O2_RICH_STUCK    -DO2_FLAT_RICH  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        o2_lean_stuck)    compile_and_run o2_lean_stuck    -DTEST_O2_LEAN_STUCK    -DO2_FLAT_LEAN  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        tps_fail)         compile_and_run tps_fail         -DTEST_TPS_FAIL         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000  ;;
        ramp_to_3000)     compile_and_run ramp_to_3000     -DTEST_RAMP_TO_3000     -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_6000)     compile_and_run ramp_to_6000     -DTEST_RAMP_TO_6000     -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_redline)  compile_and_run ramp_to_redline  -DTEST_RAMP_TO_REDLINE  -DRPMRAMP -DRPMSTART=100 -DRPMEND=6500 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_6k_hold)     compile_and_run ramp_6k_hold     -DTEST_RAMP_6K_HOLD     -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000 ;;
        ignition_timing)  compile_and_run ignition_timing  -DTEST_IGNITION_TIMING  -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=50 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000 ;;
        dwell_scaling)    compile_and_run dwell_scaling    -DTEST_DWELL_SCALING    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=80 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000 ;;
        isv_cold_idle)    compile_and_run isv_cold_idle    -DTEST_ISV_COLD_IDLE    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25                       -DSIM_TIME=60000000000 ;;
        isv_load_droop)   compile_and_run isv_load_droop   -DTEST_ISV_LOAD_DROOP   -DISV_LOAD_DROOP -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=12000000000 ;;
        overrun_cutoff)   compile_and_run overrun_cutoff   -DTEST_OVERRUN_CUTOFF   -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000 ;;
        tippy_in)         compile_and_run tippy_in         -DTEST_TIPPY_IN         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        warmup_enrichment)compile_and_run warmup_enrichment -DTEST_WARMUP_ENRICHMENT -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSIM_TIME=60000000000 ;;
        *)
            echo "Unknown test: $1"
            echo "Available: warm_idle cold_start hot_idle idle_battery_low idle_high_alt"
            echo "           idle_poor_fuel overrun_cutoff tippy_in warmup_enrichment"
            echo "           afm_open_circuit coolant_fail airtemp_fail"
            echo "           o2_disconnected o2_rich_stuck o2_lean_stuck tps_fail"
            echo "           ramp_to_3000 ramp_to_6000 ramp_to_redline ramp_6k_hold"
            echo "           ignition_timing dwell_scaling isv_cold_idle isv_load_droop"
            echo "           cl_warm_idle cl_tippy_in cl_ramp_to_3000 cl_ramp_to_6000"
            echo "           cl_ramp_to_redline cl_ac_halfway cl_cold_start"
            exit 1
            ;;
    esac
else
    echo "" > "$LOGDIR/summary.log"
    echo "89 DME 951 Test Suite — $(date)" >> "$LOGDIR/summary.log"
    echo "======================================" >> "$LOGDIR/summary.log"
    run_all
    echo ""
    echo "======================================================"
    echo "  SUMMARY"
    echo "======================================================"
    cat "$LOGDIR/summary.log"
fi
