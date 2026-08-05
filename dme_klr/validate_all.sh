#!/bin/bash
# ======================================================================
#  validate_all.sh — runs validate_dash_log.py against every test's
#  dash log and prints a pass/warn/fail summary.
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

# Test list: use args if given, otherwise pull every key out of
# validate_dash_log.py's TESTS dict so this script never drifts out
# of sync with it.
if [ "$#" -gt 0 ]; then
    TEST_NAMES=("$@")
else
    TEST_NAMES=()
    while IFS= read -r line; do
        [ -n "$line" ] && TEST_NAMES+=("$line")
    done < <(python3 -c "
import re
with open('$VALIDATOR') as f:
    src = f.read()
print('\n'.join(re.findall(r\"^\s*'([A-Za-z0-9_]+)':\s*\{\", src, re.MULTILINE)))
")
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
    out=$(python3 "$VALIDATOR" "$name" "$dashlog")
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
