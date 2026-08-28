#!/bin/bash
# ============================================================
#  89 DME 951 simulation test suite  —  DASHBOARD EDITION
#
#  Uses Verilator (replaces iverilog/vvp) with i8051_tb (dashboard edition)
#  compact DME: [DS] snapshot lines for the React dashboard.
#  DME phase/status lines prefixed DME: by phase_monitor.v directly.
#
#  Usage:
#    ./run_dashboard_tests.sh                   # run all tests
#    ./run_dashboard_tests.sh warm_idle         # single test
#    ./run_dashboard_tests.sh warm_idle 50      # single test, 50ms interval
#
#  Output: ../../tmp/dme_klr/v_dash_logs/<test>.log       (full sim output)
#                                                 <test>.dash.log  (DS + PHASE — load this into dashboard)
#          ../../tmp/dme_klr/v_dash_logs/vcd/<test>.vcd
#          ../../tmp/dme_klr/v_dash_logs/hex/<test>/{rom,ram}_out.hex
#
#  DASH_INTERVAL_MS: snapshot interval in simulated ms (default 100).
#  Smaller = more dashboard resolution, larger log files.
#  Typical sizes at 100ms: 5s test ~25KB, 25s test ~120KB.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Mode: dashboard-only ─────────────────────────────────────────────────────
MODE="dash"
if [ "$1" = "--dash" ]; then shift; fi
VVP_DIR="$(cd "$SCRIPT_DIR" && cd ../../tmp/dme_klr 2>/dev/null || { mkdir -p ../../tmp/dme_klr && cd ../../tmp/dme_klr; } && pwd)"
# VVP_DIR is kept as the name for compatibility but now holds Verilator-compiled executables
LOGDIR="$VVP_DIR/v_dash_logs"
VCDDIR="$LOGDIR/vcd"
HEXDIR="$LOGDIR/hex"
# iverilog reference log dir (for compare_with_iv)
IV_LOGDIR="$VVP_DIR/dash_logs"
FILES=files
RTL=rtl/verilog
BENCH=bench/verilog
RTLd=../claude_8051/rtl/verilog
BENCHd=../claude_8051/bench/verilog
RTLk=../gemini8048/rtl/verilog
BENCHk=../gemini8048/bench/verilog

FILES_KLR_COMBINED=files_klr   # combined DME+KLR source list

# Default snapshot interval (ms of simulated time between [DS] lines)
DASH_INTERVAL_MS="${DASH_INTERVAL_MS:-100}"

# VCD: off by default — enable with VCD=1 env var or --vcd flag.
# Compile always includes --trace for deterministic scheduling;
# at runtime +vcd=/dev/null suppresses actual file writes.
VCD_ENABLE=0
if [ "$1" = "--vcd" ]; then VCD_ENABLE=1; shift; fi
VCD_ENABLE="${VCD:-$VCD_ENABLE}"

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

# Mode alias used by run_all and case block
run_test()  { compile_and_run_klr "$@"; }
ACTIVE_LOG="$LOGDIR/summary.log"
echo "  Mode: DASHBOARD (dme_klr_dashboard_tb, snapshot output)"

# --------------------------------------------------------
#  compare_with_iv <name> <vl_log> <iv_log>
#
#  Diffs Verilator output against the iverilog reference.
#  Skipped silently if the iverilog log does not exist.
# --------------------------------------------------------
compare_with_iv() {
    local name="$1"
    local vl_log="$2"
    local iv_log="$3"
    local cmp_dir="$LOGDIR"

    if [ ! -f "$iv_log" ]; then
        echo "  [CMP]    $name — no iverilog reference (skipping)"
        return 0
    fi
    if [ ! -f "$vl_log" ]; then
        echo "  [CMP]    $name — verilator log missing (skipping)"
        return 0
    fi

    local result verdict detail colour reset="[0m"
    result=$(python3 "$SCRIPT_DIR/compare_sim_logs.py" --dash "$iv_log" "$vl_log" "$name" 2>&1)
    verdict=$(echo "$result" | cut -f1)
    detail=$(echo "$result"  | cut -f3-)

    case "$verdict" in
        MATCH)      colour="[32m" ;;
        NEAR-MATCH) colour="[33m" ;;
        DIFF)       colour="[31m" ;;
        *)          colour="" ;;
    esac

    printf "  [CMP]    ${colour}%-10s${reset} %-22s %s
" "$verdict" "$name" "$detail"
    printf "%s	%-22s	%s
" "$verdict" "$name" "$detail" >> "${cmp_dir}/compare.log"
}

# --------------------------------------------------------
#  compile_and_run_klr <name> [defines...]
#
#  Compiles and runs the combined DME+KLR testbench
#  (dme_klr_dashboard_tb).  Emits DME: [DS], DME: [PHASE],
#  DME: [STATUS], [KLR], KLR: [PHASE], KLR: [STATUS] — load
#  with the single PARSE & LOAD button in the dashboard.
# --------------------------------------------------------
compile_and_run_klr() {
    local name="$1"; shift

    local interval="$DASH_INTERVAL_MS"
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        interval="$1"; shift
    fi

    local exe="${VVP_DIR}/dash_klr_${name}"
    local log="${LOGDIR}/${name}.log"
    local vcdfile="${VCDDIR}/${name}.vcd"
    local hexdir="${HEXDIR}/${name}"
    local fstfile="${FSTDIR}/${name}.fst"

    mkdir -p "$hexdir"

    # Clean old output files for this test
    rm -f "$log" "${LOGDIR}/${name}.dash.log" "$vcdfile" "$fstfile"
    rm -f "${vcdfile}.gz"

    local sim_ns=0
    for arg in "$@"; do
        case "$arg" in -DSIM_TIME=*) sim_ns="${arg#-DSIM_TIME=}" ;; esac
    done
    local sim_sec=$(( sim_ns / 1000000000 ))
    local n_snaps=$(( sim_sec * 1000 / interval ))

    echo ""
    echo "======================================================"
    echo "  TEST (KLR): $name  [${sim_sec}s sim / interval=${interval}ms / ~${n_snaps} snaps]"
    echo "======================================================"

    # Auto-select CL file list if needed
    local files_list="$FILES"
    for arg in "$@"; do
        [[ "$arg" == "-DCL_MODE" ]] && files_list="files_cl"
    done

    # Remove stale object dir to force clean recompile
    rm -rf "${VVP_DIR}/obj_${name}"
    local _sim_ms _ramp_ms _step_clocks _sim_time="" _ramp_pct=""
    for _a in "$@"; do
        case "$_a" in
            -DSIM_TIME=*)  _sim_time="${_a#-DSIM_TIME=}" ;;
            -DRPM_RAMP_PCT=*) _ramp_pct="${_a#-DRPM_RAMP_PCT=}" ;;
        esac
    done
    _sim_time="${_sim_time:-40000000000}"
    _ramp_pct="${_ramp_pct:-25}"
    _sim_ms=$(( _sim_time / 1000000 ))
    _ramp_ms=$(( _sim_ms * _ramp_pct / 100 ))
    _step_clocks=$(( _ramp_ms * 6000 / 200 ))
    local trace_flag=""; [ "$VCD_ENABLE" = "1" ] && trace_flag="--trace"
    # shellcheck disable=SC2086
    verilator --binary $trace_flag \
        -o "$exe" \
        --Mdir "${VVP_DIR}/obj_${name}" \
        -f "$files_list" \
        +incdir+"$RTL" \
        +incdir+"$BENCH" \
        +incdir+"$RTLd" \
        +incdir+"$BENCHd" \
        +incdir+"$RTLk" \
        +incdir+"$BENCHk" \
        --top-module dme_klr_dashboard_tb \
        -DVLT_SIM \
        -DSTEP_CLOCKS="$_step_clocks" \
        -DDASHBOARD_TB \
        -DDME_KLR_COMBINED \
        -DDASH_INTERVAL_MS="$interval" \
        -Wno-fatal \
        -Wno-PINMISSING \
        -Wno-IMPLICIT \
        -Wno-WIDTHTRUNC \
        -Wno-WIDTHEXPAND \
        -Wno-REDEFMACRO \
        -Wno-DEFOVERRIDE \
        -Wno-CASEINCOMPLETE \
        -Wno-LATCH \
        -Wno-MULTIDRIVEN \
        "$@"
    if [ $? -ne 0 ]; then
        echo "  COMPILE FAILED: $name" | tee -a "$LOGDIR/summary.log"
        return 1
    fi

    echo "  Running → $log"
    echo "  VCD     → $vcdfile"
    echo "  HEX     → $hexdir/{rom,ram,klr_rom,klr_ram}_out.hex"

    ( cd "$hexdir" && "$exe" +vcd="$( [ "$VCD_ENABLE" = "1" ] && echo "${vcdfile}" || echo /dev/null )" ) > "${log}" 2>&1
    local rc=$?

    if [ $rc -ne 0 ]; then
        echo "  SIM FAILED: $name (exit $rc)" | tee -a "$LOGDIR/summary.log"
        return 1
    fi

    # Move any stray VCD to the canonical location.
    # klr_vcd_combined.v may write sim.vcd or 951klr_combined.vcd to hexdir
    # instead of honouring +vcd= if an older version is deployed.
    for _stray in "$hexdir/sim.vcd" "$hexdir/951klr_combined.vcd" "$hexdir/klr_combined.vcd"; do
        [ -f "$_stray" ] && mv "$_stray" "$vcdfile" && break
    done
    if [ -f "$vcdfile" ]; then
        [ "$VCD_ENABLE" != "1" ] && rm -f "$vcdfile"
    fi

    # Extract all DME: and KLR: lines into dashboard log.
    # dme_klr_dashboard_tb emits DME: [DS]; phase_monitor.v emits DME: [PHASE/STATUS/SEED].
    # Also capture bare [DS] from u_dme's internal scheduler (runs in parallel).
    grep -E "^DME: \[DS\]|^\[DS\]|^KLR: \[DS\]|^DME: \[PHASE\]|^DME: \[STATUS\]|^KLR: \[STATUS\]|^KLR: \[PHASE\]|^DME: \[SEED\]" "$log" > "$LOGDIR/${name}.dash.log"
    local nds=$(grep -cE "^DME: \[DS\]|^\[DS\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local nphase=$(grep -c "^DME: \[PHASE\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local nstatus=$(grep -c "^DME: \[STATUS\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local nklr=$(grep -c "^KLR: \[DS\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local nklrstatus=$(grep -c "^KLR: \[STATUS\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local nklrphase=$(grep -c "^KLR: \[PHASE\]" "$LOGDIR/${name}.dash.log" || echo 0)
    local vcdsize=$(du -sh "$vcdfile" 2>/dev/null | cut -f1 || echo "?")
    echo "  DONE: $name — ${nds} DME:DS / ${nphase} DME:PHASE / ${nstatus} DME:STATUS / ${nklr} KLR:DS / ${nklrstatus} KLR:STATUS / ${nklrphase} KLR:PHASE / VCD ${vcdsize}" \
        | tee -a "$LOGDIR/summary.log"

    open_in_dashboard "$LOGDIR/${name}.dash.log"

    compare_with_iv "$name" \
        "$LOGDIR/${name}.dash.log" \
        "$IV_LOGDIR/${name}.dash.log"
}

# --------------------------------------------------------
#  Test definitions
# --------------------------------------------------------
run_all() {

# --- Idle tests ---
run_test warm_idle \
    -DTEST_WARM_IDLE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000

# --- Closed-loop tests ---
run_test cl_warm_idle \
    -DTEST_WARM_IDLE \
    -DRPMRAMP -DCL_MODE \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000

run_test cl_tippy_in \
    -DTEST_TIPPY_IN \
    -DRPMRAMP -DCL_MODE   \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000

run_test cl_ramp_to_3000 \
    -DTEST_CL_RAMP_TO_3000   \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'h72 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000

run_test cl_condition_cycle \
    -DTEST_CL_CONDITION_CYCLE \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'h72 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=66000000000

run_test cl_condition_cycle_idle \
    -DTEST_CL_CONDITION_CYCLE_IDLE \
    -DRPMRAMP -DCL_MODE \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000


# --- Fuel quality sweep (cl_ramp_to_6000 with _FUEL_QUAL sweep) ---
run_test cl_ramp_to_6000_FQS0 \
    -DTEST_CL_RAMP_TO_6000  \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'h00" \
    -DCL_FUEL_ENERGY_PCT=0 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000_FQS1 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'h3B" \
    -DCL_FUEL_ENERGY_PCT=3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000_FQS2 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'h5A" \
    -DCL_FUEL_ENERGY_PCT=-3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000_FQS3 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'h75" \
    -DCL_FUEL_ENERGY_PCT=6 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000_FQS4 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'h81" \
    -DCL_FUEL_ENERGY_PCT=0 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000_FQS5 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'h91" \
    -DCL_FUEL_ENERGY_PCT=3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000_FQS6 \
    -DTEST_CL_RAMP_TO_6000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'h9C" \
    -DCL_FUEL_ENERGY_PCT=-3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_6000_FQS7 \
    -DTEST_CL_RAMP_TO_6000  \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    "-D_FUEL_QUAL=8'hA7" \
    -DCL_FUEL_ENERGY_PCT=6 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000


# --- FQS ramp-to-3000 sweep ---
run_test cl_ramp_to_3000_FQS0 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'h00" \
    -DCL_FUEL_ENERGY_PCT=0 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_3000_FQS1 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'h3B" \
    -DCL_FUEL_ENERGY_PCT=3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_3000_FQS2 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'h5A" \
    -DCL_FUEL_ENERGY_PCT=-3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_3000_FQS3 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'h75" \
    -DCL_FUEL_ENERGY_PCT=6 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_3000_FQS4 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'h81" \
    -DCL_FUEL_ENERGY_PCT=0 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_3000_FQS5 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'h91" \
    -DCL_FUEL_ENERGY_PCT=3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_3000_FQS6 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'h9C" \
    -DCL_FUEL_ENERGY_PCT=-3 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_3000_FQS7 \
    -DTEST_CL_RAMP_TO_3000 \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hD8 \
    -DRPMEND=3000 \
    -DRPM_RAMP_PCT=20 \
    "-D_FUEL_QUAL=8'hA7" \
    -DCL_FUEL_ENERGY_PCT=6 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ramp_to_redline \
    -DTEST_CL_RAMP_TO_REDLINE \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'hEB \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test cl_ac_halfway \
    -DTEST_CL_AC_HALFWAY \
    -DRPMRAMP -DCL_MODE -DCL_AC_HALFWAY  \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000

run_test cl_cold_start \
    -DTEST_CL_COLD_START \
    -DRPMRAMP -DCL_MODE \
    -DSIM_TIME=60000000000

run_test cold_start \
    -DTEST_COLD_START \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSIM_TIME=60000000000

run_test hot_idle \
    -DTEST_HOT_IDLE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

run_test idle_battery_low \
    -DTEST_IDLE_BATTERY_LOW \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

run_test idle_high_alt \
    -DTEST_IDLE_HIGH_ALT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

run_test idle_poor_fuel \
    -DTEST_IDLE_POOR_FUEL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

run_test ac_on_idle \
    -DTEST_AC_ON_IDLE \
    -DAC_COMP_ON \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

# --- Fuel transient tests ---
run_test overrun_cutoff \
    -DTEST_OVERRUN_CUTOFF \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000

run_test warmup_enrichment \
    -DTEST_WARMUP_ENRICHMENT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSIM_TIME=60000000000

run_test afm_open_circuit \
    -DTEST_AFM_OPEN_CIRCUIT \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25  \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

# --- Sensor failure tests ---
run_test coolant_fail \
    -DTEST_COOLANT_FAIL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

run_test airtemp_fail \
    -DTEST_AIRTEMP_FAIL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

run_test o2_disconnected \
    -DTEST_O2_DISCONNECTED -DO2_FLAT_DISCONNECTED \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

run_test o2_rich_stuck \
    -DTEST_O2_RICH_STUCK -DO2_FLAT_RICH \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

run_test o2_lean_stuck \
    -DTEST_O2_LEAN_STUCK -DO2_FLAT_LEAN \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

run_test o2_baseline \
    -DTEST_O2_BASELINE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000

run_test tps_fail \
    -DTEST_TPS_FAIL \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000

# --- RPM sweep tests ---
run_test ramp_to_3000 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_6000 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

# --- Fuel quality sweep (ramp_to_3000 with _FUEL_QUAL sweep, non-CL/open-loop) ---
run_test ramp_to_3000_FQS0 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'h00" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_3000_FQS1 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'h3B" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_3000_FQS2 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'h5A" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_3000_FQS3 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'h75" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_3000_FQS4 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'h81" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_3000_FQS5 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'h91" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_3000_FQS6 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'h9C" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_to_3000_FQS7 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    "-D_FUEL_QUAL=8'hA7" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

# --- Fuel quality sweep (ramp_to_6000 with _FUEL_QUAL sweep, non-CL/open-loop) ---
run_test ramp_to_6000_FQS0 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'h00" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6000_FQS1 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'h3B" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6000_FQS2 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'h5A" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6000_FQS3 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'h75" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6000_FQS4 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'h81" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6000_FQS5 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'h91" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6000_FQS6 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'h9C" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6000_FQS7 \
    -DTEST_RAMP_TO_6000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    "-D_FUEL_QUAL=8'hA7" \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6100 \
    -DTEST_RAMP_TO_6100 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6100 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6200 \
    -DTEST_RAMP_TO_6200 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6200 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_6300 \
    -DTEST_RAMP_TO_6300 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6300 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000

run_test ramp_to_redline \
    -DTEST_RAMP_TO_REDLINE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6500 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

run_test ramp_6k_hold \
    -DTEST_RAMP_6K_HOLD \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000

# --- Ignition tests ---
run_test ignition_timing \
    -DTEST_IGNITION_TIMING \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=50 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000

run_test dwell_scaling \
    -DTEST_DWELL_SCALING \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=80 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000

# --- ISV tests ---
run_test isv_cold_idle \
    -DTEST_ISV_COLD_IDLE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSIM_TIME=60000000000

run_test isv_load_droop \
    -DTEST_ISV_LOAD_DROOP \
    -DISV_LOAD_DROOP \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=12000000000

# --- DME+KLR combined tests ---
run_test dme_klr_warm_idle \
    -DTEST_WARM_IDLE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000

run_test dme_klr_ramp_to_3000 \
    -DTEST_RAMP_TO_3000 \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 \
    -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000

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
    SINGLE_TEST=1   # enables open_in_dashboard after compile_and_run_klr
    case "$1" in
        warm_idle)        run_test warm_idle        $IARG -DTEST_WARM_IDLE        -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000   ;;
        cl_warm_idle)     run_test cl_warm_idle     $IARG -DTEST_WARM_IDLE        -DRPMRAMP -DCL_MODE       -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000   ;;
        cl_tippy_in)      run_test cl_tippy_in      $IARG -DTEST_TIPPY_IN   -DRPMRAMP  -DCL_MODE       -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000   ;;
        cl_ramp_to_3000) run_test cl_ramp_to_3000 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP  -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'h72" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=30000000000 ;;
        cl_condition_cycle) run_test cl_condition_cycle $IARG -DTEST_CL_CONDITION_CYCLE -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'h72" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=66000000000 ;;
        cl_condition_cycle_idle) run_test cl_condition_cycle_idle $IARG -DTEST_CL_CONDITION_CYCLE_IDLE -DRPMRAMP -DCL_MODE -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000)  run_test cl_ramp_to_6000  $IARG -DTEST_CL_RAMP_TO_6000  -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS0) run_test cl_ramp_to_6000_FQS0 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'h00" -DCL_FUEL_ENERGY_PCT=0 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS1) run_test cl_ramp_to_6000_FQS1 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'h3B" -DCL_FUEL_ENERGY_PCT=3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS2) run_test cl_ramp_to_6000_FQS2 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'h5A" -DCL_FUEL_ENERGY_PCT=-3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS3) run_test cl_ramp_to_6000_FQS3 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'h75" -DCL_FUEL_ENERGY_PCT=6 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS4) run_test cl_ramp_to_6000_FQS4 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'h81" -DCL_FUEL_ENERGY_PCT=0 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS5) run_test cl_ramp_to_6000_FQS5 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'h91" -DCL_FUEL_ENERGY_PCT=3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS6) run_test cl_ramp_to_6000_FQS6 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'h9C" -DCL_FUEL_ENERGY_PCT=-3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_6000_FQS7) run_test cl_ramp_to_6000_FQS7 $IARG -DTEST_CL_RAMP_TO_6000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hD8" "-D_FUEL_QUAL=8'hA7" -DCL_FUEL_ENERGY_PCT=6 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000  ;;
        cl_ramp_to_3000_FQS0) run_test cl_ramp_to_3000_FQS0 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'h00" -DCL_FUEL_ENERGY_PCT=0 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_3000_FQS1) run_test cl_ramp_to_3000_FQS1 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'h3B" -DCL_FUEL_ENERGY_PCT=3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_3000_FQS2) run_test cl_ramp_to_3000_FQS2 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'h5A" -DCL_FUEL_ENERGY_PCT=-3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_3000_FQS3) run_test cl_ramp_to_3000_FQS3 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'h75" -DCL_FUEL_ENERGY_PCT=6 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_3000_FQS4) run_test cl_ramp_to_3000_FQS4 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'h81" -DCL_FUEL_ENERGY_PCT=0 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_3000_FQS5) run_test cl_ramp_to_3000_FQS5 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'h91" -DCL_FUEL_ENERGY_PCT=3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_3000_FQS6) run_test cl_ramp_to_3000_FQS6 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'h9C" -DCL_FUEL_ENERGY_PCT=-3 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_3000_FQS7) run_test cl_ramp_to_3000_FQS7 $IARG -DTEST_CL_RAMP_TO_3000 -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DRPMEND=3000 "-D_FUEL_QUAL=8'hA7" -DCL_FUEL_ENERGY_PCT=6 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ramp_to_redline) run_test cl_ramp_to_redline $IARG -DTEST_CL_RAMP_TO_REDLINE -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP "-DAFM_CL_TARGET=8'hEB" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        cl_ac_halfway)    run_test cl_ac_halfway     $IARG -DTEST_CL_AC_HALFWAY    -DRPMRAMP -DCL_MODE -DCL_AC_HALFWAY -DSKIP_LAMBDA_WARMUP -DSIM_TIME=20000000000 ;;
        cl_cold_start)    run_test cl_cold_start     $IARG -DTEST_CL_COLD_START    -DRPMRAMP -DCL_MODE -DSIM_TIME=60000000000 ;;
        cold_start)       run_test cold_start       $IARG -DTEST_COLD_START       -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25                        -DSIM_TIME=120000000000  ;;
        hot_idle)         run_test hot_idle         $IARG -DTEST_HOT_IDLE         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000   ;;
        idle_battery_low) run_test idle_battery_low $IARG -DTEST_IDLE_BATTERY_LOW -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        idle_high_alt)    run_test idle_high_alt    $IARG -DTEST_IDLE_HIGH_ALT    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        idle_poor_fuel)   run_test idle_poor_fuel   $IARG -DTEST_IDLE_POOR_FUEL   -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        ac_on_idle)       run_test ac_on_idle       $IARG -DTEST_AC_ON_IDLE       -DAC_COMP_ON -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=10 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        overrun_cutoff)   run_test overrun_cutoff   $IARG -DTEST_OVERRUN_CUTOFF   -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000   ;;
        warmup_enrichment)run_test warmup_enrichment $IARG -DTEST_WARMUP_ENRICHMENT -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25                       -DSIM_TIME=60000000000   ;;
        afm_open_circuit) run_test afm_open_circuit $IARG -DTEST_AFM_OPEN_CIRCUIT -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        coolant_fail)     run_test coolant_fail     $IARG -DTEST_COOLANT_FAIL     -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        airtemp_fail)     run_test airtemp_fail     $IARG -DTEST_AIRTEMP_FAIL     -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        o2_disconnected)  run_test o2_disconnected  $IARG -DTEST_O2_DISCONNECTED  -DO2_FLAT_DISCONNECTED  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        o2_rich_stuck)    run_test o2_rich_stuck    $IARG -DTEST_O2_RICH_STUCK    -DO2_FLAT_RICH  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        o2_lean_stuck)    run_test o2_lean_stuck    $IARG -DTEST_O2_LEAN_STUCK    -DO2_FLAT_LEAN  -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        o2_baseline)      run_test o2_baseline      $IARG -DTEST_O2_BASELINE                              -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=25000000000 ;;
        tps_fail)         run_test tps_fail         $IARG -DTEST_TPS_FAIL         -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=5000000000    ;;
        ramp_to_3000)     run_test ramp_to_3000     $IARG -DTEST_RAMP_TO_3000     -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000   ;;
        ramp_to_6000)     run_test ramp_to_6000     $IARG -DTEST_RAMP_TO_6000      -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000   ;;
        ramp_to_3000_FQS0) run_test ramp_to_3000_FQS0 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'h00" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_3000_FQS1) run_test ramp_to_3000_FQS1 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'h3B" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_3000_FQS2) run_test ramp_to_3000_FQS2 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'h5A" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_3000_FQS3) run_test ramp_to_3000_FQS3 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'h75" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_3000_FQS4) run_test ramp_to_3000_FQS4 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'h81" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_3000_FQS5) run_test ramp_to_3000_FQS5 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'h91" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_3000_FQS6) run_test ramp_to_3000_FQS6 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'h9C" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_3000_FQS7) run_test ramp_to_3000_FQS7 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 "-D_FUEL_QUAL=8'hA7" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        ramp_to_6000_FQS0) run_test ramp_to_6000_FQS0 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'h00" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6000_FQS1) run_test ramp_to_6000_FQS1 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'h3B" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6000_FQS2) run_test ramp_to_6000_FQS2 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'h5A" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6000_FQS3) run_test ramp_to_6000_FQS3 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'h75" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6000_FQS4) run_test ramp_to_6000_FQS4 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'h81" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6000_FQS5) run_test ramp_to_6000_FQS5 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'h91" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6000_FQS6) run_test ramp_to_6000_FQS6 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'h9C" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6000_FQS7) run_test ramp_to_6000_FQS7 $IARG -DTEST_RAMP_TO_6000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25 "-D_FUEL_QUAL=8'hA7" -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000 ;;
        ramp_to_6100)     run_test ramp_to_6100     $IARG -DTEST_RAMP_TO_6100    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6100 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000   ;;
        ramp_to_6200)     run_test ramp_to_6200     $IARG -DTEST_RAMP_TO_6200      -DRPMRAMP -DRPMSTART=100 -DRPMEND=6200 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000   ;;
        ramp_to_6300)     run_test ramp_to_6300     $IARG -DTEST_RAMP_TO_6300      -DRPMRAMP -DRPMSTART=100 -DRPMEND=6300 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=40000000000   ;;
        ramp_to_redline)  run_test ramp_to_redline  $IARG -DTEST_RAMP_TO_REDLINE  -DRPMRAMP -DRPMSTART=100 -DRPMEND=6500 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000   ;;
        ramp_6k_hold)     run_test ramp_6k_hold     $IARG -DTEST_RAMP_6K_HOLD     -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=25  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000   ;;
        ignition_timing)  run_test ignition_timing  $IARG -DTEST_IGNITION_TIMING  -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=50  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000   ;;
        dwell_scaling)    run_test dwell_scaling    $IARG -DTEST_DWELL_SCALING    -DRPMRAMP -DRPMSTART=100 -DRPMEND=6000 -DRPM_RAMP_PCT=80  -DSKIP_LAMBDA_WARMUP -DSIM_TIME=15000000000   ;;
        isv_cold_idle)    run_test isv_cold_idle    $IARG -DTEST_ISV_COLD_IDLE    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=25                        -DSIM_TIME=60000000000   ;;
        isv_load_droop)   run_test isv_load_droop   $IARG -DTEST_ISV_LOAD_DROOP   -DISV_LOAD_DROOP -DRPMRAMP -DRPMSTART=100 -DRPMEND=840 -DRPM_RAMP_PCT=25 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=12000000000 ;;
        # ── DME+KLR combined tests ──────────────────────────
        dme_klr_warm_idle)    run_test dme_klr_warm_idle    $IARG -DTEST_WARM_IDLE    -DRPMRAMP -DRPMSTART=100 -DRPMEND=840  -DRPM_RAMP_PCT=10 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=60000000000 ;;
        dme_klr_ramp_to_3000) run_test dme_klr_ramp_to_3000 $IARG -DTEST_RAMP_TO_3000 -DRPMRAMP -DRPMSTART=100 -DRPMEND=3000 -DRPM_RAMP_PCT=50 -DSKIP_LAMBDA_WARMUP -DSIM_TIME=10000000000 ;;
        *)
            echo "Unknown test: $1"
            echo "Available tests:"
            echo "  Idle:        warm_idle cold_start hot_idle idle_battery_low idle_high_alt"
            echo "               idle_poor_fuel ac_on_idle"
            echo "  Accel/Ramp:  overrun_cutoff warmup_enrichment"
            echo "               ramp_to_3000 ramp_to_6000 ramp_to_6100 ramp_to_6200 ramp_to_6300 ramp_to_redline ramp_6k_hold"
            echo "               ramp_to_3000_FQS0-7 ramp_to_6000_FQS0-7 (non-CL fuel quality sweep)"
            echo "  Ignition:    ignition_timing dwell_scaling"
            echo "  Sensors:     afm_open_circuit coolant_fail airtemp_fail tps_fail"
            echo "               o2_disconnected o2_rich_stuck o2_lean_stuck o2_baseline"
            echo "  ISV:         isv_cold_idle isv_load_droop"
            echo "  Closed-loop: cl_warm_idle cl_tippy_in"
            echo "               cl_ramp_to_3000 cl_ramp_to_6000 cl_ramp_to_redline cl_condition_cycle cl_condition_cycle_idle"
            echo "  Fuel qual:   cl_ramp_to_6000_FQS0..7  (_FUEL_QUAL=00/3B/5A/75/81/91/9C/A7)"
            echo "               cl_ac_halfway cl_cold_start"
            echo "  DME+KLR:     cl_tippy_in dme_klr_warm_idle dme_klr_ramp_to_3000"
            echo ""
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
