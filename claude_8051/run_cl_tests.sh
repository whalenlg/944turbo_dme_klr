#!/bin/bash
# ============================================================
#  89 DME 951 — Closed-Loop test runner
#
#  Runs all 7 CL tests across both TBs (14 jobs total)
#  with a configurable worker pool.
#
#  Usage:
#    ./run_cl_tests.sh <workers> [test1 test2 ...]
#
#  Examples:
#    ./run_cl_tests.sh 4              # all 14 jobs, 4 at a time
#    ./run_cl_tests.sh 8              # max parallelism
#    ./run_cl_tests.sh 2 cl_warm_idle cl_tippy_in
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_NORMAL="$SCRIPT_DIR/run_tests.sh"
RUN_DASH="$SCRIPT_DIR/run_dashboard_tests.sh"
VALIDATE="$SCRIPT_DIR/validate_dash_log.py"

BASE_DIR="$(cd "$SCRIPT_DIR" && cd ../../tmp/claude_8051 2>/dev/null || \
           { mkdir -p ../../tmp/claude_8051 && cd ../../tmp/claude_8051; } && pwd)"
LOGDIR="$BASE_DIR/logs"
DASH_LOGDIR="$BASE_DIR/dash_logs"

mkdir -p "$LOGDIR" "$DASH_LOGDIR"

ALL_CL_TESTS=(
    cl_warm_idle
    cl_tippy_in
    cl_ramp_to_3000
    cl_ramp_to_6000
    cl_ramp_to_redline
    cl_ac_halfway
    cl_cold_start
)

# Simulated duration in seconds for display
declare -A SIM_SECS=(
    [cl_warm_idle]=60
    [cl_tippy_in]=10
    [cl_ramp_to_3000]=30
    [cl_ramp_to_6000]=40
    [cl_ramp_to_redline]=40
    [cl_ac_halfway]=20
    [cl_cold_start]=60
)

# ── Parse arguments ──────────────────────────────────────────
if [ -z "$1" ] || ! [[ "$1" =~ ^[1-9][0-9]?$ ]]; then
    echo "Usage: $0 <workers 1-16> [test1 test2 ...]"
    echo ""
    echo "Available CL tests:"
    printf "  %s\n" "${ALL_CL_TESTS[@]}"
    echo ""
    echo "Each test runs on both normal TB and dashboard TB."
    echo "Total jobs = tests × 2.  Recommend workers=4 for 8-core machines."
    exit 1
fi

WORKERS="$1"; shift

if [ $# -gt 0 ]; then
    CL_TESTS=("$@")
else
    CL_TESTS=("${ALL_CL_TESTS[@]}")
fi

# Build full job list: each test → normal TB job + dashboard TB job
declare -a JOB_NAMES=()
declare -a JOB_SCRIPTS=()
declare -a JOB_LOGS=()

for name in "${CL_TESTS[@]}"; do
    JOB_NAMES+=("${name}_normal")
    JOB_SCRIPTS+=("$RUN_NORMAL")
    JOB_LOGS+=("$LOGDIR/${name}.log")

    JOB_NAMES+=("${name}_dash")
    JOB_SCRIPTS+=("$RUN_DASH")
    JOB_LOGS+=("$DASH_LOGDIR/${name}_runner.log")
done

TOTAL=${#JOB_NAMES[@]}
START_TIME=$(date +%s)

echo ""
echo "============================================================"
echo "  DME 951 Closed-Loop Test Runner"
echo "  Workers : $WORKERS"
echo "  Tests   : ${#CL_TESTS[@]} × 2 TBs = $TOTAL jobs"
echo "  Started : $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# ── Worker pool ──────────────────────────────────────────────
RUNNING=0
declare -a PIDS=()
declare -a PID_NAMES=()

reap_done() {
    local new_pids=() new_names=()
    for i in "${!PIDS[@]}"; do
        local pid="${PIDS[$i]}" jname="${PID_NAMES[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid"; local s=$?
            [ $s -eq 0 ] && echo "  [DONE]   $jname" \
                         || echo "  [FAILED] $jname (exit $s)"
        else
            new_pids+=("$pid")
            new_names+=("$jname")
        fi
    done
    PIDS=("${new_pids[@]}")
    PID_NAMES=("${new_names[@]}")
    RUNNING=${#PIDS[@]}
}

for i in "${!JOB_NAMES[@]}"; do
    jname="${JOB_NAMES[$i]}"
    script="${JOB_SCRIPTS[$i]}"
    log="${JOB_LOGS[$i]}"
    # Extract test name from job name (strip _normal/_dash suffix)
    tname="${jname%_normal}"; tname="${tname%_dash}"

    # Wait if at capacity
    while [ "$RUNNING" -ge "$WORKERS" ]; do
        reap_done
        [ "$RUNNING" -ge "$WORKERS" ] && sleep 1
    done

    echo "  [START]  $jname  (${SIM_SECS[$tname]:-?}s sim)"
    bash "$script" "$tname" >> "$log" 2>&1 &
    PIDS+=($!)
    PID_NAMES+=("$jname")
    RUNNING=${#PIDS[@]}
done

# ── Drain remaining ──────────────────────────────────────────
echo ""
echo "  Waiting for remaining jobs..."
while [ "${#PIDS[@]}" -gt 0 ]; do
    reap_done
    [ "${#PIDS[@]}" -gt 0 ] && sleep 1
done

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo "============================================================"
printf "  Complete — wall time: %dm%ds\n" "$MINS" "$SECS"
echo "============================================================"
echo ""

# ── Normal TB results ────────────────────────────────────────
echo "  Normal TB:"
for name in "${CL_TESTS[@]}"; do
    log="$LOGDIR/${name}.log"
    if [ -f "$log" ]; then
        result=$(grep "DONE:\|FAILED:" "$log" | tail -1)
        echo "    ${result:-$name: no result}"
    else
        echo "    $name: no log"
    fi
done

echo ""

# ── Dashboard TB validation ───────────────────────────────────
echo "  Dashboard TB:"
N_PASS=0; N_WARN=0; N_FAIL=0

for name in "${CL_TESTS[@]}"; do
    dash_log="$DASH_LOGDIR/${name}.log"
    if [ ! -f "$dash_log" ]; then
        echo "    [NO LOG]  $name"
        N_FAIL=$(( N_FAIL + 1 ))
        continue
    fi
    result=$(python3 "$VALIDATE" "$name" "$dash_log" 2>&1)
    verdict=$(echo "$result" | cut -f1)
    case "$verdict" in
        PASS) echo "    [PASS]  $result"; N_PASS=$(( N_PASS + 1 )) ;;
        WARN) echo "    [WARN]  $result"; N_WARN=$(( N_WARN + 1 )) ;;
        FAIL) echo "    [FAIL]  $result"; N_FAIL=$(( N_FAIL + 1 )) ;;
        *)    echo "    [ERR]   $name — $result"; N_FAIL=$(( N_FAIL + 1 )) ;;
    esac
done

echo ""
echo "------------------------------------------------------------"
printf "  Dashboard: PASS=%-3d  WARN=%-3d  FAIL=%-3d\n" "$N_PASS" "$N_WARN" "$N_FAIL"
echo "------------------------------------------------------------"
echo ""
echo "  Normal logs : $LOGDIR/cl_*.log"
echo "  Dash logs   : $DASH_LOGDIR/cl_*.log"
echo "  VCDs        : $DASH_LOGDIR/vcd/cl_*.vcd"
echo ""

[ "${N_FAIL:-0}" -gt 0 ] && exit 1 || exit 0
