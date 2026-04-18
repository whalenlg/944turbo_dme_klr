#!/bin/bash
# ============================================================
#  89 DME 951 — Parallel test launcher
#
#  Runs all tests from run_tests.sh with up to N workers,
#  where N is supplied as the first argument (1–8).
#
#  Usage:
#    ./run_parallel.sh <workers> [test1 test2 ...]
#
#  Examples:
#    ./run_parallel.sh 4              # run all 24 tests, 4 at a time
#    ./run_parallel.sh 2 warm_idle cold_start hot_idle
#                                     # run 3 specific tests, 2 at a time
#    ./run_parallel.sh 8              # maximum parallelism
#
#  Each test runs as a separate ./run_tests.sh <name> subprocess,
#  so output directories and .vvp files are fully independent.
#  A combined summary is printed when all workers finish.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_TESTS="$SCRIPT_DIR/run_tests.sh"
LOGDIR=../../tmp/claude_8051/logs

ALL_TESTS=(
    warm_idle
    cold_start
    hot_idle
    idle_battery_low
    idle_high_alt
    idle_poor_fuel
    ac_on_idle
    overrun_cutoff
    tippy_in
    warmup_enrichment
    afm_open_circuit
    coolant_fail
    airtemp_fail
    o2_disconnected
    o2_rich_stuck
    o2_lean_stuck
    tps_fail
    ramp_to_3000
    ramp_to_6000
    ramp_to_redline
    ramp_6k_hold
    ignition_timing
    dwell_scaling
    isv_cold_idle
    isv_load_droop
)

# --------------------------------------------------------
#  Parse arguments
# --------------------------------------------------------
if [ -z "$1" ] || ! [[ "$1" =~ ^[1-8]$ ]]; then
    echo "Usage: $0 <workers 1-8> [test1 test2 ...]"
    echo "       workers: number of tests to run in parallel (1-8)"
    echo ""
    echo "Available tests:"
    echo "  ${ALL_TESTS[*]}"
    exit 1
fi

WORKERS="$1"
shift

# If test names supplied use those, otherwise run all
if [ $# -gt 0 ]; then
    TESTS=("$@")
else
    TESTS=("${ALL_TESTS[@]}")
fi

TOTAL=${#TESTS[@]}
START_TIME=$(date +%s)

echo ""
echo "============================================================"
echo "  DME 951 Parallel Test Runner"
echo "  Workers : $WORKERS"
echo "  Tests   : $TOTAL"
echo "  Started : $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

mkdir -p "$LOGDIR"
# Clear any previous parallel summary
> "$LOGDIR/parallel_summary.log"

# --------------------------------------------------------
#  Worker pool — simple semaphore via background jobs
# --------------------------------------------------------
RUNNING=0
declare -a PIDS=()
declare -a PID_NAMES=()

for test in "${TESTS[@]}"; do
    # Wait if at capacity
    while [ "$RUNNING" -ge "$WORKERS" ]; do
        # Check which jobs have finished
        NEW_PIDS=()
        NEW_NAMES=()
        for i in "${!PIDS[@]}"; do
            pid="${PIDS[$i]}"
            name="${PID_NAMES[$i]}"
            if ! kill -0 "$pid" 2>/dev/null; then
                # Job finished — collect exit status
                wait "$pid"
                status=$?
                if [ $status -eq 0 ]; then
                    echo "  [DONE]   $name (PID $pid)"
                else
                    echo "  [FAILED] $name (PID $pid, exit $status)"
                fi
            else
                NEW_PIDS+=("$pid")
                NEW_NAMES+=("$name")
            fi
        done
        PIDS=("${NEW_PIDS[@]}")
        PID_NAMES=("${NEW_NAMES[@]}")
        RUNNING=${#PIDS[@]}
        [ "$RUNNING" -ge "$WORKERS" ] && sleep 1
    done

    # Launch next test in background
    echo "  [START]  $test"
    (
        cd "$SCRIPT_DIR"
        bash "$RUN_TESTS" "$test" >> "$LOGDIR/${test}.log" 2>&1
    ) &
    pid=$!
    PIDS+=("$pid")
    PID_NAMES+=("$test")
    RUNNING=${#PIDS[@]}
done

# --------------------------------------------------------
#  Wait for remaining jobs
# --------------------------------------------------------
echo ""
echo "  Waiting for remaining tests to finish..."
for i in "${!PIDS[@]}"; do
    pid="${PIDS[$i]}"
    name="${PID_NAMES[$i]}"
    wait "$pid"
    status=$?
    if [ $status -eq 0 ]; then
        echo "  [DONE]   $name (PID $pid)"
    else
        echo "  [FAILED] $name (PID $pid, exit $status)"
    fi
done

# --------------------------------------------------------
#  Summary
# --------------------------------------------------------
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo "============================================================"
echo "  COMPLETE — wall time: ${MINS}m ${SECS}s"
echo "============================================================"
echo ""

if [ -f "$LOGDIR/summary.log" ]; then
    echo "Results from $LOGDIR/summary.log:"
    echo ""
    # Show DONE and FAILED lines, sorted
    grep -E "DONE|FAILED" "$LOGDIR/summary.log" | sort | while read line; do
        echo "  $line"
    done
fi

echo ""
echo "Logs : $LOGDIR/"
echo "VCDs : $LOGDIR/vcd/"
echo "HEX  : $LOGDIR/hex/"
echo ""
