#!/bin/bash
# ======================================================================
#  validate_all.sh — runs validate_dash_log.py against every test's
#  dash log and prints a pass/warn/fail summary. Log-replay tests
#  (replay_wot_60s) are included: their verdict comes from the
#  <name>.report.txt that check_replay.py wrote beside the dash log.
#
#  Usage:
#      ./validate_all.sh                    # iverilog logs, every test
#      ./validate_all.sh test1 test2        # iverilog logs, named tests
#      ./validate_all.sh --verilator        # verilator logs, every test
#      ./validate_all.sh --verilator test1  # verilator logs, named tests
#
#  Exit code: 0 if no FAILs, 1 if any test FAILed (log missing counts
#  as FAIL, matching validate_dash_log.py's own exit behavior).
# ======================================================================

# -h / --help: print the header comment above and exit before anything runs.
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate_dash_log.py"

# --verilator switches the log dir from dash_logs (iverilog, default) to
# v_dash_logs (Verilator) — same naming convention v_run_dashboard_tests.sh
# uses. Must be parsed out before whatever's left is treated as test names.
LOGSUBDIR="dash_logs"
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--verilator" ]; then
        LOGSUBDIR="v_dash_logs"
    else
        ARGS+=("$arg")
    fi
done
if [ "${#ARGS[@]}" -gt 0 ]; then
    set -- "${ARGS[@]}"
else
    set --
fi

# Same log location convention as run_dashboard_tests.sh / v_run_dashboard_tests.sh
VVP_DIR="$(cd "$SCRIPT_DIR" && cd ../../tmp/dme_klr 2>/dev/null && pwd)"
LOGDIR="$VVP_DIR/$LOGSUBDIR"

if [ ! -f "$VALIDATOR" ]; then
    echo "validate_dash_log.py not found at $VALIDATOR" >&2
    exit 2
fi

if [ ! -d "$LOGDIR" ]; then
    echo "Log directory not found: $LOGDIR (run the tests first)" >&2
    exit 2
fi

# Test list: use args if given, otherwise take every key of
# validate_dash_log.py's TESTS dict so this script never drifts out of
# sync with it. Imports the module and reads TESTS itself rather than
# regex-scanning the source: a scan for "'name': {" also matched nested
# dict-valued fields inside a test entry (e.g. cl_idle_controlled_by_isv's
# 'expect_isv_recovery': {...}), which then showed up as a phantom test
# with "No expectations defined" WARN. Reading the dict also leaves out
# DME_FILE_OVERRIDES, which is keyed by the same test names.
if [ "$#" -gt 0 ]; then
    TEST_NAMES=("$@")
else
    TEST_NAMES=()
    while IFS= read -r line; do
        [ -n "$line" ] && TEST_NAMES+=("$line")
    done < <(cd "$SCRIPT_DIR" && python3 -c "
import validate_dash_log
print('\\n'.join(validate_dash_log.TESTS))
")
    # Log-replay tests (replay_wot_60s, ...) have no TESTS entry: their
    # verdict comes from check_replay.py's <name>.report.txt, which
    # validate_dash_log.py reads for any replay_* name. Take them from the
    # run_replay_test case entries of the runner that wrote these logs, so
    # a new replay test is picked up without editing this script.
    RUNNER="$SCRIPT_DIR/run_dashboard_tests.sh"
    [ "$LOGSUBDIR" = "v_dash_logs" ] && RUNNER="$SCRIPT_DIR/v_run_dashboard_tests.sh"
    while IFS= read -r line; do
        [ -n "$line" ] && TEST_NAMES+=("$line")
    done < <(awk '/^[[:space:]]+[A-Za-z0-9_]+\)[[:space:]]+run_replay_test / {
                      name = $1; sub(/\)$/, "", name); print name }' "$RUNNER" 2>/dev/null)
fi

if [ "${#TEST_NAMES[@]}" -eq 0 ]; then
    echo "No tests found to validate." >&2
    exit 2
fi

pass=0
warn=0
fail=0
missing=0

echo "======================================================"
echo "  VALIDATING ${#TEST_NAMES[@]} test(s)  [$LOGSUBDIR]"
echo "======================================================"

for name in "${TEST_NAMES[@]}"; do
    dashlog="$LOGDIR/${name}.dash.log"
    # Pass DME_ROM_FILE through if set, so validate_dash_log.py applies
    # the right firmware-variant overrides (see DME_FILE_OVERRIDES there)
    # instead of the default 28PIN-calibrated expected values. Using
    # ${...:-} rather than a bare $DME_ROM_FILE since this script runs
    # under `set -u` — an unset var would otherwise abort the script.
    out=$(python3 "$VALIDATOR" "$name" "$dashlog" "${DME_ROM_FILE:-}")
    status="${out%%$'\t'*}"

    echo "$out"

    case "$status" in
        PASS) pass=$((pass+1)) ;;
        WARN) warn=$((warn+1)) ;;
        FAIL)
            fail=$((fail+1))
            [ ! -f "$dashlog" ] && missing=$((missing+1))
            ;;
        *) fail=$((fail+1)) ;;
    esac
done

echo "======================================================"
echo "  SUMMARY: $pass PASS, $warn WARN, $fail FAIL (${#TEST_NAMES[@]} total)"
if [ "$missing" -gt 0 ]; then
    echo "  ($missing FAIL due to missing log files — run tests first)"
fi
echo "======================================================"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
