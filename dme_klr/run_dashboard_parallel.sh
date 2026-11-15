#!/bin/bash
# ============================================================
#  89 DME 951 — Parallel dashboard test launcher
#
#  Runs all tests from run_dashboard_tests.sh with up to N
#  workers, validates each .dash.log on completion, and
#  writes a PASS/WARN/FAIL summary. Tests start longest first
#  (by simulated time) so the run ends as soon as possible.
#
#  Usage:
#    ./run_dashboard_parallel.sh <workers> [test1 test2 ... | GROUP1 GROUP2 ...]
#
#  Examples:
#    ./run_dashboard_parallel.sh 4              # all tests, 4 at a time
#    ./run_dashboard_parallel.sh 2 warm_idle cold_start hot_idle
#    ./run_dashboard_parallel.sh 8              # maximum parallelism
#    ./run_dashboard_parallel.sh 2 warm_idle --KLR_DEBUG --DME_DEBUG
#                                                # debug flags apply to every
#                                                # test named on the command line
#    ./run_dashboard_parallel.sh --verilator 8 Ramp
#                                                # run the Ramp group under Verilator
#    ./run_dashboard_parallel.sh 4 Ramp Idle warm_idle
#                                                # group names and individual test
#                                                # names can be mixed freely
#
#  Groups: a named subset of ALL_TESTS (see group_members() below for the
#  exact membership of each). Run --help or pass no args to list them. A
#  positional argument that matches a group name expands to every test in
#  that group; anything else is treated as a literal test name.
#
#  Snapshot interval: set DASH_INTERVAL_MS env var before running.
#    DASH_INTERVAL_MS=50 ./run_dashboard_parallel.sh 4
#  Default is 100ms.
#
#  Debug flags (any position, applied to every test run this
#  invocation launches — forwarded to whichever runner is active):
#    --DME_DEBUG --DME_DEEP_DEBUG --KLR_DEBUG
#  or for single tests only (repeatable; the RUN REGRESSIONS panel's
#  per-test switches): --test-debug=<test>:DME_DEBUG+KLR_DEBUG
#  A test with debug flags builds on its own and never goes to a
#  regression host.
#  Under --verilator these are still accepted but have no effect —
#  v_run_dashboard_tests.sh always strips them before compiling.
#
#  One build for every test: the testbench is built once (build_runtime.sh,
#  two binaries or .vvp files: open loop and closed loop, into
#  $DMEKLR_TMP/dme_klr/runtime or runtime_iv) and each test runs on it
#  with its options as +X=<n>. --per-test-build builds every test on its
#  own instead, as before. Tests also build on their own under iverilog
#  with a debug flag, and under Verilator with VCD_ENABLE=1 (the shared
#  binary has no tracing).
# ============================================================

# -h / --help: print the header comment above and exit before anything runs.
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USE_VERILATOR=0
RUN_TESTS="$SCRIPT_DIR/run_dashboard_tests.sh"
VALIDATE="$SCRIPT_DIR/validate_dash_log.py"
source "$SCRIPT_DIR/../paths.sh"   # DMEKLR_REPO, DMEKLR_TMP
mkdir -p "$DMEKLR_TMP/dme_klr"
_BASE="$DMEKLR_TMP/dme_klr"
# LOGDIR is simulator-dependent — set after --verilator is parsed below

export DASH_INTERVAL_MS="${DASH_INTERVAL_MS:-100}"

ALL_TESTS=(
    ramp_to_3000 ramp_to_6000 ramp_to_6000_knock knock_sensor_defect knock_sensor_short_to_ground ramp_to_6000_FQS0 ramp_to_6000_FQS1 ramp_to_6000_FQS2 ramp_to_6000_FQS3 ramp_to_6000_FQS4 ramp_to_6000_FQS5 ramp_to_6000_FQS6 ramp_to_6000_FQS7 ramp_to_6300 cl_warm_idle cl_tippy_in cl_ramp_to_3000 cl_ramp_to_3000_KLR_BATT_LOW cl_ramp_to_3000_KLR_BATT_DISCONNECTED cl_ramp_to_3000_KLR_TPS_SUPPLY_LOW cl_ramp_to_3000_TPS0 cl_ramp_to_3000_KLR_TRIGGER_STUCK_HIGH cl_ramp_to_3000_KLR_TRIGGER_STUCK_LOW cl_ramp_to_3000_KLR_IGN_IN_STUCK_HIGH cl_ramp_to_3000_KLR_IGN_IN_STUCK_LOW cl_ramp_to_3000_KLR_KNOCK_BLOCKED cl_ramp_to_6000_KLR_ADC0_NOISE_HIGH cl_ramp_to_6000_KLR_ADC0_NOISE_LOW cl_ramp_to_6000_KLR_FULL_LOAD_STUCK_LOW cl_ramp_to_3000_KLR_FULL_LOAD_STUCK_HIGH cl_ramp_to_3000_KLR_TPS_SUPPLY_LOST cl_ramp_to_3000_BOOST_OPEN_CIRCUIT cl_ramp_to_3000_BOOST_STEP_OVERBOOST cl_ramp_to_3000_BOOST_STEP_DOWN cl_ramp_to_3000_BOOST cl_ramp_to_4500 cl_ramp_to_5000_BOOST_LOW cl_condition_cycle cl_condition_cycle_idle cl_ramp_to_6000 cl_ramp_to_6000_BOOST cl_wot_3000_BOOST_ZERO cl_ramp_to_6000_BOOST_LOW
    cl_ramp_to_6000_FQS0 cl_ramp_to_6000_FQS1 cl_ramp_to_6000_FQS2 cl_ramp_to_6000_FQS3
    cl_ramp_to_6000_FQS4 cl_ramp_to_6000_FQS5 cl_ramp_to_6000_FQS6 cl_ramp_to_6000_FQS7
    cl_ramp_to_redline cl_ac_halfway cl_idle_controlled_by_isv cl_cold_start
    warm_idle warm_idle_5s cold_start hot_idle idle_battery_low idle_high_alt idle_poor_fuel ac_on_idle tps_open_circuit altitude_disconnected fuel_qual_disconnected ref_sensor_loss speed_sensor_loss
    overrun_cutoff warmup_enrichment afm_open_circuit
    coolant_fail airtemp_fail o2_disconnected o2_rich_stuck o2_lean_stuck o2_baseline tps_fail
    afm_short_to_ground battery_disconnected airtemp_open_circuit coolant_open_circuit tps_ch6_short_to_ground tps_ch6_open_circuit ref_sensor_missing_at_start ref_sensor_stuck_low speed_sensor_stuck_low
    ramp_to_redline ramp_to_redline_KLR_TPS_HIGH ramp_6k_hold
    ignition_timing dwell_scaling
    isv_cold_idle isv_load_droop
    dme_klr_warm_idle
    replay_wot_60s
)

# ── Named test groups ────────────────────────────────────────────────────────
# Portable case-statement lookup rather than `declare -A` — associative
# arrays need bash 4+, and macOS's system /bin/bash is stuck on 3.2, so an
# associative array here would silently break for anyone running this
# without a newer bash explicitly on PATH.
#
#   group_members <name>   echoes that group's test names (space-separated)
#                           to stdout and returns 0; returns 1 for an
#                           unknown name with nothing printed.
GROUP_NAMES=(Ramp KLR_fail Fuel Idle DME_fail Replay)
group_members() {
    case "$1" in
        Ramp)
            echo "ramp_to_3000 ramp_to_6000 ramp_to_6000_knock ramp_to_6300 cl_ramp_to_3000 cl_ramp_to_6000_BOOST cl_ramp_to_6000 cl_ramp_to_redline cl_ramp_to_3000_BOOST cl_ramp_to_4500 ramp_to_redline ramp_6k_hold ignition_timing dwell_scaling"
            ;;
        KLR_fail)
            echo "knock_sensor_defect knock_sensor_short_to_ground cl_ramp_to_3000_KLR_BATT_LOW cl_ramp_to_3000_KLR_BATT_DISCONNECTED cl_ramp_to_3000_KLR_TPS_SUPPLY_LOW cl_ramp_to_3000_TPS0 cl_ramp_to_3000_KLR_TRIGGER_STUCK_HIGH cl_ramp_to_3000_KLR_TRIGGER_STUCK_LOW cl_ramp_to_3000_KLR_IGN_IN_STUCK_HIGH cl_ramp_to_3000_KLR_IGN_IN_STUCK_LOW cl_ramp_to_3000_KLR_KNOCK_BLOCKED cl_ramp_to_6000_KLR_ADC0_NOISE_HIGH cl_ramp_to_6000_KLR_ADC0_NOISE_LOW cl_ramp_to_6000_KLR_FULL_LOAD_STUCK_LOW cl_ramp_to_5000_BOOST_LOW cl_wot_3000_BOOST_ZERO cl_ramp_to_6000_BOOST_LOW ramp_to_redline_KLR_TPS_HIGH tps_open_circuit cl_ramp_to_3000_KLR_FULL_LOAD_STUCK_HIGH cl_ramp_to_3000_KLR_TPS_SUPPLY_LOST cl_ramp_to_3000_BOOST_OPEN_CIRCUIT cl_ramp_to_3000_BOOST_STEP_OVERBOOST cl_ramp_to_3000_BOOST_STEP_DOWN"
            ;;
        Fuel)
            echo "ramp_to_6000_FQS0 ramp_to_6000_FQS1 ramp_to_6000_FQS2 ramp_to_6000_FQS3 ramp_to_6000_FQS4 ramp_to_6000_FQS5 ramp_to_6000_FQS6 ramp_to_6000_FQS7 cl_ramp_to_6000_FQS0 cl_ramp_to_6000_FQS1 cl_ramp_to_6000_FQS2 cl_ramp_to_6000_FQS3 cl_ramp_to_6000_FQS4 cl_ramp_to_6000_FQS5 cl_ramp_to_6000_FQS6 cl_ramp_to_6000_FQS7"
            ;;
        Idle)
            echo "cl_warm_idle cl_tippy_in warm_idle warm_idle_5s cold_start hot_idle idle_high_alt warmup_enrichment o2_baseline cl_condition_cycle cl_condition_cycle_idle cl_ac_halfway cl_idle_controlled_by_isv cl_cold_start isv_cold_idle isv_load_droop dme_klr_warm_idle ac_on_idle"
            ;;
        DME_fail)
            echo "idle_battery_low idle_poor_fuel overrun_cutoff afm_open_circuit coolant_fail airtemp_fail o2_disconnected o2_rich_stuck o2_lean_stuck tps_fail altitude_disconnected fuel_qual_disconnected ref_sensor_loss speed_sensor_loss afm_short_to_ground battery_disconnected airtemp_open_circuit coolant_open_circuit tps_ch6_short_to_ground tps_ch6_open_circuit ref_sensor_missing_at_start ref_sensor_stuck_low speed_sensor_stuck_low"
            ;;
        Replay)
            echo "replay_wot_60s"
            ;;
        *)
            return 1
            ;;
    esac
}

# expand_tests <arg1> <arg2> ... — prints the resolved, space-separated test
# list to stdout: each arg is expanded via group_members if it names a known
# group, otherwise passed through unchanged as a literal test name.
expand_tests() {
    local arg members
    for arg in "$@"; do
        if members=$(group_members "$arg"); then
            echo -n "$members "
        else
            echo -n "$arg "
        fi
    done
}

# ── Parse arguments ───────────────────────────────────────────────────────────
# --verilator and the debug flags may appear in any position among the
# mode flags. EXTRA_FLAGS collects the debug flags (as the long-form
# --NAME each runner's own CLI parses) so they can be forwarded
# verbatim to every test this invocation launches.
EXTRA_FLAGS=()
PER_TEST_BUILD=0
# --test-debug=<test>:<FLAG>[+<FLAG>...] (repeatable): debug flags for that
# test only (DME_DEBUG, DME_DEEP_DEBUG, KLR_DEBUG); it builds on its own
# and always runs here, never on a regression host (its dumps are large)
TEST_DEBUG=()
_has_td=0
# --count: print how many tests the arguments name and exit (run_all.sh
# uses it to decide whether both suites fit the workers at once)
COUNT_ONLY=0
for _arg in "$@"; do
    case "$_arg" in
        --count)           COUNT_ONLY=1; _has_td=1 ;;
        --verilator)       USE_VERILATOR=1 ;;
        --per-test-build)  PER_TEST_BUILD=1 ;;
        --DME_DEBUG|--DME_DEEP_DEBUG|--KLR_DEBUG) EXTRA_FLAGS+=("$_arg") ;;
        --test-debug=*)    TEST_DEBUG+=("${_arg#--test-debug=}"); _has_td=1 ;;
    esac
done
if [ "$_has_td" = 1 ]; then
    _NEW_ARGS=()
    for _arg in "$@"; do case "$_arg" in --test-debug=*|--count) ;; *) _NEW_ARGS+=("$_arg") ;; esac; done
    set -- ${_NEW_ARGS[@]+"${_NEW_ARGS[@]}"}
fi
# test_debug <test>: its --test-debug flags, as --FLAG words
test_debug() {
    local e f
    for e in ${TEST_DEBUG[@]+"${TEST_DEBUG[@]}"}; do
        [ "${e%%:*}" = "$1" ] || continue
        for f in $(echo "${e#*:}" | tr '+,' '  '); do
            case "$f" in DME_DEBUG|DME_DEEP_DEBUG|KLR_DEBUG) printf -- '--%s ' "$f" ;; esac
        done
    done
}
if [ "$USE_VERILATOR" = "1" ] || [ ${#EXTRA_FLAGS[@]} -gt 0 ] || [ "$PER_TEST_BUILD" = "1" ]; then
    RUN_TESTS="$SCRIPT_DIR/run_dashboard_tests.sh"
    [ "$USE_VERILATOR" = "1" ] && RUN_TESTS="$SCRIPT_DIR/v_run_dashboard_tests.sh"
    _NEW_ARGS=()
    for _arg in "$@"; do
        case "$_arg" in
            --verilator|--per-test-build|--DME_DEBUG|--DME_DEEP_DEBUG|--KLR_DEBUG) ;;
            *) _NEW_ARGS+=("$_arg") ;;
        esac
    done
    set -- "${_NEW_ARGS[@]}"
fi

if [ "$1" = "--dash" ]; then shift; fi

if [ -z "$1" ] || ! [[ "$1" =~ ^[1-8]$ ]]; then
    echo "Usage: $0 [--verilator] [--per-test-build] [--DME_DEBUG] [--DME_DEEP_DEBUG] [--KLR_DEBUG]"
    echo "          [--test-debug=<test>:<FLAG>[+<FLAG>]...] <workers 1-8> [test1 test2 ... | GROUP1 GROUP2 ...]"
    echo ""
    echo "Environment:"
    echo "  DASH_INTERVAL_MS  snapshot interval in simulated ms (default 100)"
    echo ""
    echo "Groups (pass a name in place of individual tests — mixing with"
    echo "literal test names is fine too):"
    for _g in "${GROUP_NAMES[@]}"; do
        printf "  %-10s %s\n" "$_g" "$(group_members "$_g")"
    done
    echo ""
    echo "Available tests:"
    printf "  %s\n" "${ALL_TESTS[@]}"
    exit 1
fi

# Set LOGDIR based on simulator
LOGDIR="$DMEKLR_LOGS/$( [ "$USE_VERILATOR" = "1" ] && echo v_dash_logs || echo dash_logs )"   # this ROM pair's folder

WORKERS="$1"; shift
if [ $# -gt 0 ]; then
    TESTS=($(expand_tests "$@"))
else
    TESTS=("${ALL_TESTS[@]}")
fi
if [ "$COUNT_ONLY" = 1 ]; then echo "${#TESTS[@]}"; exit 0; fi

# ── Longest first ────────────────────────────────────────────────────────────
# Start the tests in order of simulated length, longest first, so a long
# test can't be the last one to start while the other workers sit idle at
# the end of the run. Each test's length comes from its single-test case
# entry in $RUN_TESTS (the same entry the workers below run): SIM_TIME in
# ns for run_test, --start-s/--end-s for run_replay_test. A test with no
# SIM_TIME gets the testbench default of 40 s. Ties keep their order.
sim_seconds_table() {
    awk '
        /^[[:space:]]+[A-Za-z0-9_]+\)[[:space:]]+run_(replay_)?test / {
            name = $1; sub(/\)$/, "", name)
            secs = 40
            if (match($0, /-DSIM_TIME=[0-9]+/))
                secs = substr($0, RSTART + 11, RLENGTH - 11) / 1e9
            if (match($0, /--end-s [0-9.]+/)) {
                secs = substr($0, RSTART + 8, RLENGTH - 8)
                if (match($0, /--start-s [0-9.]+/))
                    secs -= substr($0, RSTART + 10, RLENGTH - 10)
            }
            print name, secs
        }' "$RUN_TESTS"
}
TESTS=($(
    sim_seconds_table | awk '
        NR == FNR { secs[$1] = $2; next }
        { print ($1 in secs ? secs[$1] : 40), FNR, $1 }' - <(printf "%s\n" "${TESTS[@]}") |
    sort -k1,1nr -k2,2n | awk '{ print $3 }'
))

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
    result=$(python3 "$VALIDATE" "$name" "$dashlog" "$DME_ROM_FILE" 2>&1)
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
    # A WARN or FAIL verdict with no warning line in the run: still note
    # it for the live dashboard (at the end of the run; live/test_snap.py)
    if { [ "$verdict" = "FAIL" ] || [ "$verdict" = "WARN" ]; } && [ -f "$LOGDIR/${name}.log.gz" ]; then
        python3 "$SCRIPT_DIR/live/test_snap.py" scan "$name" "$LOGDIR/${name}.log.gz" \
            "--$(echo "$verdict" | tr A-Z a-z)" "$detail" --script "$RUN_TESTS" >/dev/null || true
    fi
    return $rc
}

# ── Worker pool ───────────────────────────────────────────────────────────────
# Slots: WORKERS here, plus the threads of each regression host in
# $DMEKLR_REGRESS_HOSTS (a JSON list [{name, url, token, threads}], which the
# dashboard's RUN REGRESSIONS panel writes; see live/regress_host.mjs). A
# host's test runs through live/remote_test.mjs, which brings its logs back
# here for validate_one; if the host drops (exit 75) the test goes back in
# the queue and the host gets no more tests this run.
COMPLETED=0
declare -a SIM_FAILED=()
declare -a SLOT_HOST=() SLOT_PID=() SLOT_TEST=()
declare -a H_NAME=() H_URL=() H_TOKEN=() H_OFF=()
for ((i = 0; i < WORKERS; i++)); do SLOT_HOST+=(""); SLOT_PID+=(""); SLOT_TEST+=(""); done
if [ -n "${DMEKLR_REGRESS_HOSTS:-}" ] && [ -f "$DMEKLR_REGRESS_HOSTS" ]; then
    if [ ${#EXTRA_FLAGS[@]} -gt 0 ] || [ "${VCD_ENABLE:-}" = "1" ]; then
        echo "Regression hosts not used: debug flags / VCD_ENABLE run every test here"
    else
        while IFS=$'\t' read -r _n _u _t _k; do
            [ -n "$_u" ] || continue
            _h=${#H_NAME[@]}
            H_NAME+=("$_n"); H_URL+=("$_u"); H_TOKEN+=("$_t"); H_OFF+=(0)
            for ((i = 0; i < _k; i++)); do SLOT_HOST+=("$_h"); SLOT_PID+=(""); SLOT_TEST+=(""); done
            echo "Regression host: $_n, $_k thread(s)"
        done < <(python3 -c 'import json,sys
for h in json.load(open(sys.argv[1])):
    print("%s\t%s\t%s\t%d" % (h["name"], h["url"], h["token"], int(h["threads"])))' "$DMEKLR_REGRESS_HOSTS")
    fi
fi
QUEUE=("${TESTS[@]}")

# Ctrl-C / kill: stop the running tests too. Background jobs in a script
# ignore SIGINT, so without this they keep running after the runner is
# gone, and a later run of the same test shares (and deletes) their log.
# (A remote test's remote_test.mjs stops its job on the host.)
kill_tree() {
    local c
    for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done
    kill -TERM "$1" 2>/dev/null
}
running_count() {
    local n=0 i
    for i in "${!SLOT_PID[@]}"; do [ -n "${SLOT_PID[$i]}" ] && n=$((n + 1)); done
    echo "$n"
}
on_interrupt() {
    trap - INT TERM
    echo ""
    echo "  Interrupted — stopping $(running_count) running test(s): ${SLOT_TEST[*]}"
    for i in "${!SLOT_PID[@]}"; do [ -n "${SLOT_PID[$i]}" ] && kill_tree "${SLOT_PID[$i]}"; done
    exit 130
}
trap on_interrupt INT TERM

reap_finished() {
    local i pid name status h
    for i in "${!SLOT_PID[@]}"; do
        pid="${SLOT_PID[$i]}"
        [ -n "$pid" ] || continue
        kill -0 "$pid" 2>/dev/null && continue
        wait "$pid"
        status=$?
        name="${SLOT_TEST[$i]}"
        h="${SLOT_HOST[$i]}"
        SLOT_PID[$i]=""; SLOT_TEST[$i]=""
        if [ -n "$h" ] && [ "$status" -eq 75 ]; then
            # the host couldn't take it or dropped: back in the queue
            H_OFF[$h]=1
            QUEUE=("$name" ${QUEUE[@]+"${QUEUE[@]}"})
            printf "  [REQUEUE] %-22s %s dropped out (see %s)\n" "$name" "${H_NAME[$h]}" "$LOGDIR/${name}.runner.log"
            continue
        fi
        if [ $status -ne 0 ]; then
            printf "  [SIM ERR] %-22s exit=%d\n" "$name" "$status"
            SIM_FAILED+=("$name")
        fi
        validate_one "$name"
        COMPLETED=$(( COMPLETED + 1 ))
        printf "  [%d of %d completed]\n" "$COMPLETED" "$TOTAL"
    done
}

# ── One build for every test (build_runtime.sh) ─────────────────────────────
unset DMEKLR_RUNTIME_DIR
if [ "$PER_TEST_BUILD" = "1" ]; then
    echo "Building each test on its own (--per-test-build)"
elif [ "$USE_VERILATOR" = "1" ] && [ "$VCD_ENABLE" = "1" ]; then
    echo "Building each test on its own (VCD_ENABLE=1: the shared binary has no tracing)"
elif [ "$USE_VERILATOR" != "1" ] && [ ${#EXTRA_FLAGS[@]} -gt 0 ]; then
    echo "Building each test on its own (debug flags: ${EXTRA_FLAGS[*]})"
else
    _rt_dir="$_BASE/runtime"; _rt_opt=()
    [ "$USE_VERILATOR" = "1" ] || { _rt_dir="$_BASE/runtime_iv"; _rt_opt=(--iverilog); }
    echo "Building the shared testbench once → $_rt_dir (log: $LOGDIR/runtime_build.log)"
    mkdir -p "$LOGDIR"
    _t0=$SECONDS
    if ! bash "$SCRIPT_DIR/build_runtime.sh" --out "$_rt_dir" "${_rt_opt[@]}" > "$LOGDIR/runtime_build.log" 2>&1; then
        tail -20 "$LOGDIR/runtime_build.log"
        echo "Shared build FAILED (log above). Run again with --per-test-build to build each test on its own."
        exit 1
    fi
    echo "  built in $(( SECONDS - _t0 )) s"
    export DMEKLR_RUNTIME_DIR="$_rt_dir"
fi

echo ""
_sim=iverilog; [ "$USE_VERILATOR" = "1" ] && _sim=verilator
_pt=(); [ "$PER_TEST_BUILD" = "1" ] && _pt=(--per-test-build)
while [ ${#QUEUE[@]} -gt 0 ] || [ "$(running_count)" -gt 0 ]; do
    reap_finished
    for i in "${!SLOT_PID[@]}"; do
        [ ${#QUEUE[@]} -gt 0 ] || break
        [ -z "${SLOT_PID[$i]}" ] || continue
        h="${SLOT_HOST[$i]}"
        [ -z "$h" ] || [ "${H_OFF[$h]}" = 0 ] || continue
        # a host takes the first queued test without debug flags (those stay here)
        _qi=0
        if [ -n "$h" ]; then
            while [ $_qi -lt ${#QUEUE[@]} ] && [ -n "$(test_debug "${QUEUE[$_qi]}")" ]; do _qi=$((_qi + 1)); done
            [ $_qi -lt ${#QUEUE[@]} ] || continue
        fi
        test="${QUEUE[$_qi]}"
        QUEUE=(${QUEUE[@]+"${QUEUE[@]:0:$_qi}"} ${QUEUE[@]+"${QUEUE[@]:$((_qi + 1))}"})
        if [ -z "$h" ]; then
            _td=($(test_debug "$test"))
            [ ${#_td[@]} -gt 0 ] && echo "  (debug: $test ${_td[*]}, built on its own)"
            (
                cd "$SCRIPT_DIR"
                exec bash "$RUN_TESTS" "$test" ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} ${_td[@]+"${_td[@]}"} >> "$LOGDIR/${test}.runner.log" 2>&1
            ) &
            # (the dashboard's RUN REGRESSIONS panel marks the test running from this line)
            printf "  [START]  %s\n" "$test"
        else
            DMEKLR_REGRESS_TOKEN="${H_TOKEN[$h]}" node "$SCRIPT_DIR/live/remote_test.mjs" --host "${H_URL[$h]}" \
                --test "$test" --sim "$_sim" --out "$LOGDIR" --interval "$DASH_INTERVAL_MS" ${_pt[@]+"${_pt[@]}"} \
                >> "$LOGDIR/${test}.runner.log" 2>&1 &
            printf "  [START]  %s  @%s\n" "$test" "${H_NAME[$h]}"
        fi
        SLOT_PID[$i]=$!
        SLOT_TEST[$i]="$test"
    done
    [ ${#QUEUE[@]} -gt 0 ] || [ "$(running_count)" -gt 0 ] && sleep 1
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
