#!/bin/bash
# ============================================================
#  89 DME 951 — Parallel dashboard test launcher
#
#  Runs all tests from run_dashboard_tests.sh with up to N
#  workers, validates each .dash.log on completion, and
#  writes a PASS/WARN/FAIL summary.
#
#  Usage:
#    ./run_dashboard_parallel.sh <workers> [test1 test2 ...]
#
#  Examples:
#    ./run_dashboard_parallel.sh 4              # all tests, 4 at a time
#    ./run_dashboard_parallel.sh 2 warm_idle cold_start hot_idle
#    ./run_dashboard_parallel.sh 8              # maximum parallelism
#  Snapshot interval: set DASH_INTERVAL_MS env var before running.
#    DASH_INTERVAL_MS=50 ./run_dashboard_parallel.sh 4
#  Default is 100ms.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USE_VERILATOR=0
RUN_TESTS="$SCRIPT_DIR/run_dashboard_tests.sh"
VALIDATE="$SCRIPT_DIR/validate_dash_log.py"
_BASE="$(cd "$SCRIPT_DIR" && cd ../../tmp/dme_klr 2>/dev/null || \
         { mkdir -p ../../tmp/dme_klr && cd ../../tmp/dme_klr; } && pwd)"
# LOGDIR is simulator-dependent — set after --verilator is parsed below

export DASH_INTERVAL_MS="${DASH_INTERVAL_MS:-100}"

ALL_TESTS=(
    ramp_to_3000 ramp_to_6000 ramp_to_3000_FQS0 ramp_to_3000_FQS1 ramp_to_3000_FQS2 ramp_to_3000_FQS3 ramp_to_3000_FQS4 ramp_to_3000_FQS5 ramp_to_3000_FQS6 ramp_to_3000_FQS7 ramp_to_6000_FQS0 ramp_to_6000_FQS1 ramp_to_6000_FQS2 ramp_to_6000_FQS3 ramp_to_6000_FQS4 ramp_to_6000_FQS5 ramp_to_6000_FQS6 ramp_to_6000_FQS7 ramp_to_6100 ramp_to_6200 ramp_to_6300 cl_warm_idle cl_tippy_in cl_ramp_to_3000 cl_condition_cycle cl_condition_cycle_idle cl_ramp_to_6000
    cl_ramp_to_6000_FQS0 cl_ramp_to_6000_FQS1 cl_ramp_to_6000_FQS2 cl_ramp_to_6000_FQS3
    cl_ramp_to_6000_FQS4 cl_ramp_to_6000_FQS5 cl_ramp_to_6000_FQS6 cl_ramp_to_6000_FQS7 cl_ramp_to_3000_FQS0 cl_ramp_to_3000_FQS1 cl_ramp_to_3000_FQS2 cl_ramp_to_3000_FQS3 cl_ramp_to_3000_FQS4 cl_ramp_to_3000_FQS5 cl_ramp_to_3000_FQS6 cl_ramp_to_3000_FQS7
    cl_ramp_to_redline cl_ac_halfway cl_cold_start
    warm_idle cold_start hot_idle idle_battery_low idle_high_alt idle_poor_fuel ac_on_idle
    overrun_cutoff warmup_enrichment afm_open_circuit
    coolant_fail airtemp_fail o2_disconnected o2_rich_stuck o2_lean_stuck o2_baseline tps_fail
    ramp_to_redline ramp_6k_hold
    ignition_timing dwell_scaling
    isv_cold_idle isv_load_droop
    dme_klr_warm_idle dme_klr_ramp_to_3000
)

# ── Parse arguments ───────────────────────────────────────────────────────────
# --verilator may appear in any position among the mode flags
for _arg in "$@"; do
    [ "$_arg" = "--verilator" ] && USE_VERILATOR=1
done
if [ "$USE_VERILATOR" = "1" ]; then
    RUN_TESTS="$SCRIPT_DIR/v_run_dashboard_tests.sh"
    _NEW_ARGS=()
    for _arg in "$@"; do
        [ "$_arg" = "--verilator" ] || _NEW_ARGS+=("$_arg")
    done
    set -- "${_NEW_ARGS[@]}"
fi

if [ "$1" = "--dash" ]; then shift; fi

if [ -z "$1" ] || ! [[ "$1" =~ ^[1-8]$ ]]; then
    echo "Usage: $0 [--verilator] <workers 1-8> [test1 test2 ...]"
    echo ""
    echo "Environment:"
    echo "  DASH_INTERVAL_MS  snapshot interval in simulated ms (default 100)"
    echo ""
    echo "Available tests:"
    printf "  %s\n" "${ALL_TESTS[@]}"
    exit 1
fi

# Set LOGDIR based on simulator
LOGDIR="$_BASE/$( [ "$USE_VERILATOR" = "1" ] && echo v_dash_logs || echo dash_logs )"

WORKERS="$1"; shift
if [ $# -gt 0 ]; then
    TESTS=("$@")
else
    TESTS=("${ALL_TESTS[@]}")
fi
TOTAL=${#TESTS[@]}
START_TIME=$(date +%s)

mkdir -p "$LOGDIR"
SUMMARY_LOG="$LOGDIR/parallel_summary.log"
VALIDATION_LOG="$LOGDIR/validation.log"
> "$SUMMARY_LOG"
> "$VALIDATION_LOG"

echo ""
echo "============================================================"
echo "  DME 951 + KLR Parallel Test Runner"
printf "  Simulator        : %s\n" "$( [ "$USE_VERILATOR" = "1" ] && echo verilator || echo iverilog )"
printf "  Workers          : %s\n" "$WORKERS"
printf "  Tests            : %s\n" "$TOTAL"
printf "  Snapshot interval: %sms\n" "$DASH_INTERVAL_MS"
printf "  Started          : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# ── validate_one <test_name> ──────────────────────────────────────────────────
validate_one() {
    local name="$1"

    local dashlog="$LOGDIR/${name}.dash.log"

    if [ ! -f "$dashlog" ]; then
        printf "  [FAIL]   %-22s dash.log missing\n" "$name"
        printf "FAIL\t%-22s\tdash.log not found — simulation may have crashed\n" \
               "$name" >> "$VALIDATION_LOG"
        return 1
    fi

    if ! command -v python3 &>/dev/null; then
        printf "  [SKIP]   %-22s python3 not found\n" "$name"
        return 0
    fi

    local result
    result=$(python3 "$VALIDATE" "$name" "$dashlog" 2>&1)
    local rc=$?
    local verdict detail
    verdict=$(echo "$result" | awk -F'\t' '{print $1}')
    detail=$(echo "$result"  | awk -F'\t' '{print $3}')

    local colour reset=""
    case "$verdict" in
        PASS) colour="\033[32m" ;;
        WARN) colour="\033[33m" ;;
        FAIL) colour="\033[31m" ;;
        *)    colour="" ;;
    esac
    reset="\033[0m"

    printf "  [${colour}%s${reset}]   %-22s %s\n" "$verdict" "$name" "$detail"
    printf "%s\t%-22s\t%s\n" "$verdict" "$name" "$detail" >> "$VALIDATION_LOG"
    return $rc
}

# ── Worker pool ───────────────────────────────────────────────────────────────
RUNNING=0
COMPLETED=0
declare -a PIDS=()
declare -a PID_NAMES=()
declare -a SIM_FAILED=()

reap_finished() {
    local NEW_PIDS=() NEW_NAMES=()
    for i in "${!PIDS[@]}"; do
        local pid="${PIDS[$i]}"
        local name="${PID_NAMES[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid"
            local status=$?
            if [ $status -ne 0 ]; then
                printf "  [SIM ERR] %-22s exit=%d\n" "$name" "$status"
                SIM_FAILED+=("$name")
            fi
            validate_one "$name"
            COMPLETED=$(( COMPLETED + 1 ))
            printf "  [%d of %d completed]\n" "$COMPLETED" "$TOTAL"
        else
            NEW_PIDS+=("$pid")
            NEW_NAMES+=("$name")
        fi
    done
    PIDS=("${NEW_PIDS[@]}")
    PID_NAMES=("${NEW_NAMES[@]}")
    RUNNING=${#PIDS[@]}
}

echo ""
for test in "${TESTS[@]}"; do
    while [ "$RUNNING" -ge "$WORKERS" ]; do
        reap_finished
        [ "$RUNNING" -ge "$WORKERS" ] && sleep 1
    done

    (
        cd "$SCRIPT_DIR"
        bash "$RUN_TESTS" "$test" >> "$LOGDIR/${test}.runner.log" 2>&1
    ) &
    PIDS+=("$!")
    PID_NAMES+=("$test")
    RUNNING=${#PIDS[@]}
done

echo ""
echo "  Waiting for remaining tests..."
while [ "${#PIDS[@]}" -gt 0 ]; do
    reap_finished
    [ "${#PIDS[@]}" -gt 0 ] && sleep 1
done

# ── Tally verdicts ────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

N_PASS=$(grep -c "^PASS" "$VALIDATION_LOG" 2>/dev/null); N_PASS=$(echo "${N_PASS:-0}" | tr -d '[:space:]')
N_WARN=$(grep -c "^WARN" "$VALIDATION_LOG" 2>/dev/null); N_WARN=$(echo "${N_WARN:-0}" | tr -d '[:space:]')
N_FAIL=$(grep -c "^FAIL" "$VALIDATION_LOG" 2>/dev/null); N_FAIL=$(echo "${N_FAIL:-0}" | tr -d '[:space:]')

echo ""
echo "============================================================"
printf "  Complete — %dm %ds   PASS=%d  WARN=%d  FAIL=%d\n" \
       "$MINS" "$SECS" "$N_PASS" "$N_WARN" "$N_FAIL"
echo "============================================================"
echo ""
echo "  Validation detail (FAIL first, then WARN, then PASS):"
echo ""
if [ -f "$VALIDATION_LOG" ]; then
    grep "^FAIL" "$VALIDATION_LOG" | while IFS=$'\t' read -r v n d; do
        printf "  \033[31mFAIL\033[0m  %-22s %s\n" "$n" "$d"
    done
    grep "^WARN" "$VALIDATION_LOG" | while IFS=$'\t' read -r v n d; do
        printf "  \033[33mWARN\033[0m  %-22s %s\n" "$n" "$d"
    done
    grep "^PASS" "$VALIDATION_LOG" | while IFS=$'\t' read -r v n d; do
        printf "  \033[32mPASS\033[0m  %-22s %s\n" "$n" "$d"
    done
fi

# ── Plain-text parallel_summary.log (no ANSI codes) ──────────────────────────
{
    echo "89 DME 951 Parallel Test Run — $(date '+%Y-%m-%d %H:%M:%S')"
    printf "Wall time: %dm%ds   Total: %d   PASS: %d   WARN: %d   FAIL: %d\n" \
           "$MINS" "$SECS" "$TOTAL" "$N_PASS" "$N_WARN" "$N_FAIL"
    echo ""
    # FAIL first, WARN second, PASS third — all plain text
    for prefix in FAIL WARN PASS; do
        grep "^${prefix}" "$VALIDATION_LOG" 2>/dev/null | \
            awk -F'\t' -v p="$prefix" '{printf "  %-6s %-22s %s\n", p, $2, $3}'
    done
} > "$SUMMARY_LOG"

echo ""
echo "  Summary    : $SUMMARY_LOG"
echo "  Validation : $VALIDATION_LOG"
echo "  Logs       : $LOGDIR/"
echo ""

[ "${N_FAIL:-0}" -gt 0 ] && exit 1 || exit 0
