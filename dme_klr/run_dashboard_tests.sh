#!/bin/bash
# ============================================================
#  89 DME 951 simulation test suite  —  DASHBOARD EDITION
#
#  Uses i8051_tb (dashboard edition) instead of the standard i8051_tb,
#  compact [DS] snapshot lines for the React dashboard.
#
#  Usage:
#    ./run_dashboard_tests.sh                   # run all tests
#    ./run_dashboard_tests.sh warm_idle         # single test
#    ./run_dashboard_tests.sh warm_idle 50      # single test, 50ms interval
#
#  Output: ../../tmp/claude_8051/dash_logs/<test>.log       (full sim output)
#                                               <test>.dash.log  (DS + PHASE — load this into dashboard)
#          ../../tmp/claude_8051/dash_logs/vcd/<test>.vcd
#          ../../tmp/claude_8051/dash_logs/hex/<test>/{rom,ram,xram}_out.hex
#
#  DASH_INTERVAL_MS: snapshot interval in simulated ms (default 100).
#  Smaller = more dashboard resolution, larger log files.
#  Typical sizes at 100ms: 5s test ~25KB, 25s test ~120KB.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VVP_DIR="$(cd "$SCRIPT_DIR" && cd ../../tmp/claude_8051 2>/dev/null || { mkdir -p ../../tmp/claude_8051 && cd ../../tmp/claude_8051; } && pwd)"
LOGDIR="$VVP_DIR/dash_logs"
VCDDIR="$LOGDIR/vcd"
HEXDIR="$LOGDIR/hex"
FILES=files
RTL=rtl/verilog
BENCH=bench/verilog
RTLd=../claude_8051/rtl/verilog
BENCHd=../claude_8051/bench/verilog
RTLk=../gemini8048/rtl/verilog
BENCHk=../gemini8048/bench/verilog

TB_FILE="bench/verilog/i8051_dashboard_tb.v"

# Default snapshot interval (ms of simulated time between [DS] lines)
DASH_INTERVAL_MS="${DASH_INTERVAL_MS:-100}"

# Dashboard URL — set DASHBOARD_URL env var to override
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:5173}"

# Vite project public directory — a symlink is created here pointing
# at the log directory so Vite serves logs as static files.
# Set DASHBOARD_PUBLIC env var to your Vite project's public/ folder.
# e.g. export DASHBOARD_PUBLIC=~/projects/dme951-dash/public
DASHBOARD_PUBLIC="${DASHBOARD_PUBLIC:-}"

# Symlink name inside public/ that points to the log directory
DASH_LOGS_LINK="dash_logs"

# --------------------------------------------------------
#  ensure_symlink
#
#  Creates public/dash_logs -> LOGDIR if it doesn't exist.
# --------------------------------------------------------
ensure_symlink() {
    [ -z "$DASHBOARD_PUBLIC" ] && return 1
    [ -d "$DASHBOARD_PUBLIC" ] || { echo "  [DASHBOARD] DASHBOARD_PUBLIC not found: $DASHBOARD_PUBLIC"; return 1; }
    local link="$DASHBOARD_PUBLIC/$DASH_LOGS_LINK"
    if [ -L "$link" ]; then
        return 0   # already exists
    fi
    ln -s "$LOGDIR" "$link"
    echo "  [DASHBOARD] Created symlink: $link → $LOGDIR"
}

# --------------------------------------------------------
#  open_in_dashboard <log_path>
#
#  Ensures the public/dash_logs symlink exists, then opens
#  the dashboard with ?log=/dash_logs/<filename> so the app
#  fetches it directly from Vite's static file server.
#  Set AUTO_OPEN=0 to disable browser opening entirely.
# --------------------------------------------------------
open_in_dashboard() {
    local logpath="$1"
    local logfile
    logfile="$(basename "$logpath")"

    [ "${AUTO_OPEN:-1}" = "0" ] && return 0

    # Detect browser open command
    local open_cmd=""
    if command -v open &>/dev/null; then
        open_cmd="open"
    elif command -v xdg-open &>/dev/null; then
        open_cmd="xdg-open"
    else
        echo "  [DASHBOARD] No browser open command found"
        echo "  [DASHBOARD] Load manually: $logpath"
        return 0
    fi

    if [ -z "$DASHBOARD_PUBLIC" ]; then
        echo "  [DASHBOARD] DASHBOARD_PUBLIC not set"
        echo "  [DASHBOARD] e.g. export DASHBOARD_PUBLIC=~/projects/dme951-dash/public"
        echo "              Load manually: $logpath"
        return 0
    fi

    ensure_symlink || return 0

    if ! curl -sf --max-time 2 "$DASHBOARD_URL" > /dev/null 2>&1; then
        echo "  [DASHBOARD] Server not reachable at $DASHBOARD_URL — start your dev server"
        echo "              Then open: ${DASHBOARD_URL}?log=/${DASH_LOGS_LINK}/${logfile}"
        return 0
    fi

    local url="${DASHBOARD_URL}?log=/${DASH_LOGS_LINK}/${logfile}"
    $open_cmd "$url" 2>/dev/null
    echo "  [DASHBOARD] Opened: $url"
}

mkdir -p "$VVP_DIR" "$LOGDIR" "$VCDDIR" "$HEXDIR"

# --------------------------------------------------------
#  compile_and_run <short_name> [interval_ms] <iverilog -D flags...>
#
#  If second argument is a plain integer it overrides the
#  snapshot interval for this test only.
# --------------------------------------------------------
compile_and_run() {
    local name="$1"; shift

    # Optional per-test interval override as second positional arg
    local interval="$DASH_INTERVAL_MS"
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        interval="$1"; shift
    fi

    local vvp="${VVP_DIR}/dash_${name}.vvp"
    local log="${LOGDIR}/${name}.log"
    local vcdfile="${VCDDIR}/${name}.vcd"
    local hexdir="${HEXDIR}/${name}"

    mkdir -p "$hexdir"

    # Extract SIM_TIME for display
    local sim_ns=0
    for arg in "$@"; do
        case "$arg" in
            -DSIM_TIME=*) sim_ns="${arg#-DSIM_TIME=}" ;;
        esac
    done
    local sim_sec=$(( sim_ns / 1000000000 ))
    local n_snaps=$(( sim_sec * 1000 / interval ))

    echo ""
    echo "======================================================"
    echo "  TEST: $name  [${sim_sec}s sim / ~${sim_sec}m wall / interval=${interval}ms / ~${n_snaps} snapshots]"
    echo "======================================================"

    # Compile — dashboard tb is added explicitly; all other sources via -f files
    # When -DCL_MODE is present, swap var_interrupt_gen.v for var_interrupt_gen_cl.v
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
        -s i8051_dashboard_tb \
        -DDASHBOARD_TB \
        -DDASH_INTERVAL_MS="$interval" \
        "$@" \
        "$TB_FILE"
    if [ $? -ne 0 ]; then
        echo "  COMPILE FAILED: $name" | tee -a "$LOGDIR/summary.log"
        return 1
    fi

    echo "  Running → $log"
    echo "  VCD     → $vcdfile"
    echo "  HEX     → $hexdir/{rom,ram,xram}_out.hex"

    # Run from hexdir so VCD and hex dumps land there without conflicts
    ( cd "$hexdir" && vvp "$vvp" ) > "$log" 2>&1
    if [ $? -ne 0 ]; then
        echo "  SIM FAILED: $name" | tee -a "$LOGDIR/summary.log"
        return 1
    fi

    # Move sim.vcd to named location
    [ -f "$hexdir/sim.vcd" ] && mv "$hexdir/sim.vcd" "$vcdfile"

    # Extract [DS], [PHASE], and [SEED] lines into dash log
    grep -E "^\[DS\]|^\[PHASE\]|^\[SEED\]" "$log" > "$LOGDIR/${name}.dash.log"

    local nlines=$(wc -l < "$log")
    local nds=$(grep -c "^\[DS\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local nphase=$(grep -c "^\[PHASE\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local dashsize=$(du -sh "$LOGDIR/${name}.dash.log" 2>/dev/null | cut -f1 || echo "?")
    local vcdsize=$(du -sh "$vcdfile" 2>/dev/null | cut -f1 || echo "?")
    echo "  DONE: $name  ($nds DS snapshots / $nphase PHASE events / ${dashsize} / VCD ${vcdsize})" \
        | tee -a "$LOGDIR/summary.log"

    # Validate
    local val_result
    val_result=$(python3 "$SCRIPT_DIR/validate_dash_log.py" "$name" "$LOGDIR/${name}.dash.log" 2>&1)
    local verdict=$(echo "$val_result" | cut -f1)
    local val_detail=$(echo "$val_result" | cut -f3-)
    echo "  ${verdict}: $name — $val_detail" | tee -a "$LOGDIR/validation.log"

    # Open in dashboard browser if running a single test
    open_in_dashboard "$LOGDIR/${name}.dash.log"
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
    -DRPMRAMP -DCL_MODE \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000

compile_and_run cl_tippy_in \
    -DTEST_TIPPY_IN \
    -DRPMRAMP -DCL_MODE \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run cl_ramp_to_3000 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'h72 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000

compile_and_run cl_ramp_to_6000 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hDA \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

compile_and_run cl_ramp_to_redline \
    -DTEST_CL_RAMP_TO_REDLINE \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hEB \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

compile_and_run cl_ac_halfway \
    -DTEST_CL_AC_HALFWAY \
    -DRPMRAMP -DCL_MODE -DCL_AC_HALFWAY \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000

compile_and_run cl_cold_start \
    -DTEST_CL_COLD_START \
    -DRPMRAMP -DCL_MODE \
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

# --- Fuel transient tests ---
compile_and_run tippy_in \
    -DTEST_TIPPY_IN \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

compile_and_run overrun_cutoff \
    -DTEST_OVERRUN_CUTOFF \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000

compile_and_run warmup_enrichment \
    -DTEST_WARMUP_ENRICHMENT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSIM_TIME=60000000000

compile_and_run afm_open_circuit \
    -DTEST_AFM_OPEN_CIRCUIT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

# --- Sensor failure tests ---
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
#  Single test mode: ./run_dashboard_tests.sh <name> [interval_ms]
# --------------------------------------------------------
if [ -n "$1" ]; then
    # Allow optional interval override as second positional argument
    IARG=""
    if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
        IARG="$2"
    fi
    SINGLE_TEST=1   # enables open_in_dashboard after compile_and_run
    case "$1" in
        warm_idle)        compile_and_run warm_idle        $IARG -DTEST_WARM_IDLE        -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000   ;;
        cl_warm_idle)     compile_and_run cl_warm_idle     $IARG -DTEST_WARM_IDLE        -DRPMRAMP -DCL_MODE       -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000   ;;
        cl_tippy_in)      compile_and_run cl_tippy_in      $IARG -DTEST_TIPPY_IN         -DRPMRAMP -DCL_MODE       -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000   ;;
        cl_ramp_to_3000)  compile_and_run cl_ramp_to_3000  $IARG -DTEST_CL_RAMP_TO_3000  -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'h72" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000 ;;
        cl_ramp_to_6000)  compile_and_run cl_ramp_to_6000  $IARG -DTEST_CL_RAMP_TO_6000  -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hDA" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_redline) compile_and_run cl_ramp_to_redline $IARG -DTEST_CL_RAMP_TO_REDLINE -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hEB" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ac_halfway)    compile_and_run cl_ac_halfway     $IARG -DTEST_CL_AC_HALFWAY    -DRPMRAMP -DCL_MODE -DCL_AC_HALFWAY -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000 ;;
        cl_cold_start)    compile_and_run cl_cold_start     $IARG -DTEST_CL_COLD_START    -DRPMRAMP -DCL_MODE -DSIM_TIME=60000000000 ;;
        cold_start)       compile_and_run cold_start       $IARG -DTEST_COLD_START       -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25                        -DSIM_TIME=120000000000  ;;
        hot_idle)         compile_and_run hot_idle         $IARG -DTEST_HOT_IDLE         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000   ;;
        idle_battery_low) compile_and_run idle_battery_low $IARG -DTEST_IDLE_BATTERY_LOW -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        idle_high_alt)    compile_and_run idle_high_alt    $IARG -DTEST_IDLE_HIGH_ALT    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        idle_poor_fuel)   compile_and_run idle_poor_fuel   $IARG -DTEST_IDLE_POOR_FUEL   -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        ac_on_idle)       compile_and_run ac_on_idle       $IARG -DTEST_AC_ON_IDLE       -DAC_COMP_ON -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        tippy_in)         compile_and_run tippy_in         $IARG -DTEST_TIPPY_IN         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000   ;;
        overrun_cutoff)   compile_and_run overrun_cutoff   $IARG -DTEST_OVERRUN_CUTOFF   -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000   ;;
        warmup_enrichment)compile_and_run warmup_enrichment $IARG -DTEST_WARMUP_ENRICHMENT -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25                       -DSIM_TIME=60000000000   ;;
        afm_open_circuit) compile_and_run afm_open_circuit $IARG -DTEST_AFM_OPEN_CIRCUIT -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        coolant_fail)     compile_and_run coolant_fail     $IARG -DTEST_COOLANT_FAIL     -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        airtemp_fail)     compile_and_run airtemp_fail     $IARG -DTEST_AIRTEMP_FAIL     -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        o2_disconnected)  compile_and_run o2_disconnected  $IARG -DTEST_O2_DISCONNECTED  -DO2_FLAT_RICH  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        o2_rich_stuck)    compile_and_run o2_rich_stuck    $IARG -DTEST_O2_RICH_STUCK    -DO2_FLAT_RICH  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        o2_lean_stuck)    compile_and_run o2_lean_stuck    $IARG -DTEST_O2_LEAN_STUCK    -DO2_FLAT_LEAN  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        tps_fail)         compile_and_run tps_fail         $IARG -DTEST_TPS_FAIL         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        ramp_to_3000)     compile_and_run ramp_to_3000     $IARG -DTEST_RAMP_TO_3000     -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000   ;;
        ramp_to_6000)     compile_and_run ramp_to_6000     $IARG -DTEST_RAMP_TO_6000     -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000   ;;
        ramp_to_redline)  compile_and_run ramp_to_redline  $IARG -DTEST_RAMP_TO_REDLINE  -DRPMRAMP -DRPMSTART=100 -DRPMEND=6500 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000   ;;
        ramp_6k_hold)     compile_and_run ramp_6k_hold     $IARG -DTEST_RAMP_6K_HOLD     -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000   ;;
        ignition_timing)  compile_and_run ignition_timing  $IARG -DTEST_IGNITION_TIMING  -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=50  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000   ;;
        dwell_scaling)    compile_and_run dwell_scaling    $IARG -DTEST_DWELL_SCALING    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=80  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000   ;;
        isv_cold_idle)    compile_and_run isv_cold_idle    $IARG -DTEST_ISV_COLD_IDLE    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25                        -DSIM_TIME=60000000000   ;;
        isv_load_droop)   compile_and_run isv_load_droop   $IARG -DTEST_ISV_LOAD_DROOP   -DISV_LOAD_DROOP -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=12000000000 ;;
        *)
            echo "Unknown test: $1"
            echo "Available tests:"
            echo "  Idle:        warm_idle cold_start hot_idle idle_battery_low idle_high_alt"
            echo "               idle_poor_fuel ac_on_idle"
            echo "  Accel/Ramp:  tippy_in overrun_cutoff warmup_enrichment"
            echo "               ramp_to_3000 ramp_to_6000 ramp_to_redline ramp_6k_hold"
            echo "  Ignition:    ignition_timing dwell_scaling"
            echo "  Sensors:     afm_open_circuit coolant_fail airtemp_fail tps_fail"
            echo "               o2_disconnected o2_rich_stuck o2_lean_stuck"
            echo "  ISV:         isv_cold_idle isv_load_droop"
            echo "  Closed-loop: cl_warm_idle cl_tippy_in"
            echo "               cl_ramp_to_3000 cl_ramp_to_6000 cl_ramp_to_redline"
            echo "               cl_ac_halfway cl_cold_start"
            exit 1
            ;;
    esac
else
    echo "" > "$LOGDIR/summary.log"
    echo "89 DME 951 Dashboard Test Suite — $(date)" >> "$LOGDIR/summary.log"
    echo "Snapshot interval: ${DASH_INTERVAL_MS}ms" >> "$LOGDIR/summary.log"
    echo "======================================" >> "$LOGDIR/summary.log"
    run_all
    echo ""
    echo "======================================================"
    echo "  SUMMARY"
    echo "======================================================"
    cat "$LOGDIR/summary.log"
fi
