#!/usr/bin/env bash
# ============================================================
#  smoke_test.sh — check an install by running two short simulations
#
#  Runs, after sourcing <repo>/setup (venv, DMEKLR_TMP):
#    klr           Icarus Verilog: klr/run_klr_regression, the KLR i8048
#                  CPU regression (also uses the Python packages)
#    warm_idle_5s  Verilator: dme_klr/v_run_dashboard_tests.sh warm_idle_5s,
#                  the full DME+KLR model compiled and run for 5 s
#  and prints a PASS/FAIL line for each. install_macos.sh and
#  install_arch.sh run it as their last step (--skip-tests skips it).
#  The Verilator compile takes a few minutes the first time.
#
#  Usage:  install/smoke_test.sh [klr] [warm_idle_5s]   (default: both)
#    -h, --help   this text
#
#  Each test's full output goes to $DMEKLR_TMP/install_smoke/<test>.log.
#  Exits 0 only when every test asked for passes.
# ============================================================

for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -o pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$INSTALL_DIR/.." && pwd)"

TESTS=()
for _arg in "$@"; do
    case "$_arg" in
        klr|warm_idle_5s) TESTS+=("$_arg") ;;
        *) echo "smoke_test.sh: unknown test '$_arg' (klr or warm_idle_5s; see --help)" >&2; exit 2 ;;
    esac
done
[ ${#TESTS[@]} -gt 0 ] || TESTS=(klr warm_idle_5s)

# What a new terminal gets from `source setup`: the venv's python3 and DMEKLR_TMP
# shellcheck source=../setup
source "$REPO_DIR/setup" || { echo "smoke_test.sh: can't source $REPO_DIR/setup" >&2; exit 1; }

LOGDIR="$DMEKLR_TMP/install_smoke"
mkdir -p "$LOGDIR" || exit 1

bold=$'\033[1m'; green=$'\033[0;32m'; red=$'\033[0;31m'; nc=$'\033[0m'
[ -t 1 ] || { bold=""; green=""; red=""; nc=""; }

declare -a RESULTS=()
FAILS=0
result() {   # result PASS|FAIL NAME DETAIL SECONDS
    local c="$green"; [ "$1" = PASS ] || c="$red"
    RESULTS+=("${c}$1${nc}  $2  ($3, $4s)")
    [ "$1" = PASS ] || FAILS=$((FAILS + 1))
}

for t in "${TESTS[@]}"; do
    log="$LOGDIR/$t.log"
    t0=$SECONDS
    case "$t" in
    klr)
        printf '\n%s==> Smoke test: KLR CPU regression (Icarus Verilog)%s\n' "$bold" "$nc"
        echo "+ klr/run_klr_regression   (log: $log)"
        "$REPO_DIR/klr/run_klr_regression" > "$log" 2>&1
        rc=$?
        # vvp exits 0 whatever the checks say, so count them in the output
        np=$(grep -c 'PASS \[' "$log"); nf=$(grep -c 'FAIL \[' "$log")
        if [ $rc -eq 0 ] && [ "$np" -gt 0 ] && [ "$nf" -eq 0 ] && ! grep -q Traceback "$log"; then
            result PASS "iverilog: KLR regression" "$np checks passed" $((SECONDS - t0))
        else
            tail -n 30 "$log"
            result FAIL "iverilog: KLR regression" "exit $rc, $np passed, $nf failed; log: $log" $((SECONDS - t0))
        fi
        ;;
    warm_idle_5s)
        printf '\n%s==> Smoke test: warm_idle_5s (Verilator compile + 5 s simulated; a few minutes)%s\n' "$bold" "$nc"
        echo "+ dme_klr/v_run_dashboard_tests.sh warm_idle_5s   (log: $log)"
        dash="$DMEKLR_TMP/dme_klr/v_dash_logs/warm_idle_5s.dash.log"
        rm -f "$dash"   # so an old run's log can't pass for this one
        (cd "$REPO_DIR/dme_klr" && ./v_run_dashboard_tests.sh warm_idle_5s) > "$log" 2>&1
        rc=$?
        ns=$(grep -c '\[DS\]' "$dash" 2>/dev/null); ns=${ns:-0}
        if [ $rc -eq 0 ] && [ "$ns" -gt 10 ] && ! grep -qE 'COMPILE FAILED|SIM FAILED' "$log"; then
            result PASS "verilator: warm_idle_5s" "$ns dashboard snapshots in $dash" $((SECONDS - t0))
        else
            tail -n 30 "$log"
            result FAIL "verilator: warm_idle_5s" "exit $rc, $ns snapshots; log: $log" $((SECONDS - t0))
        fi
        ;;
    esac
done

echo
echo "${bold}Smoke tests${nc}"
for r in "${RESULTS[@]}"; do echo "  $r"; done
[ "$FAILS" -eq 0 ]
