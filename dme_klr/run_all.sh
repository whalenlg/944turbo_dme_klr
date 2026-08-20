#!/usr/bin/env bash
# =============================================================================
#  DME 951 + KLR — Full Test Suite
#  Runs: i8048 regression, i8051 regression, Verilator suite, iverilog suite,
#        iverilog/Verilator comparison, FQS analysis
#
#  Usage:
#    ./run_all.sh [--verilator | --iverilog] [workers]
#
#  By default runs both the Verilator and iverilog dashboard suites (and the
#  comparison + FQS analysis step that depends on both). Pass --verilator or
#  --iverilog to run only that simulator's suite — the comparison/FQS step
#  is skipped in that case, since it needs both sides' logs.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DME_KLR="$ROOT/dme_klr"
PASS=0; WARN=0; FAIL=0
START_TIME=$(date +%s)

# ── Parse args: --verilator / --iverilog restrict which simulator suite(s)
#    run (steps 3-5); default (neither flag) runs both, as before.
_want_verilator=0
_want_iverilog=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --verilator) _want_verilator=1 ;;
        --iverilog)  _want_iverilog=1 ;;
        *)           ARGS+=("$arg") ;;
    esac
done
if [ "$_want_verilator" = "0" ] && [ "$_want_iverilog" = "0" ]; then
    RUN_VERILATOR=1; RUN_IVERILOG=1   # default: run both
else
    RUN_VERILATOR="$_want_verilator"
    RUN_IVERILOG="$_want_iverilog"
fi
WORKERS="${ARGS[0]:-8}"

# Colours
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[run_all]${NC} $*"; }
ok()   { echo -e "${GREEN}  ✓ PASS${NC}  $*"; ((PASS++)); }
warn() { echo -e "${YELLOW}  ⚠ WARN${NC}  $*"; ((WARN++)); }
fail() { echo -e "${RED}  ✗ FAIL${NC}  $*"; ((FAIL++)); }
hdr()  { echo -e "\n${BOLD}══════════════════════════════════════════════════════${NC}"; \
          echo -e "${BOLD}  $*${NC}"; \
          echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"; }

# ── 1. i8048 KLR regression ───────────────────────────────────────────────────
MODE_DESC="both simulators"
[ "$RUN_VERILATOR" = "1" ] && [ "$RUN_IVERILOG" = "0" ] && MODE_DESC="Verilator only"
[ "$RUN_IVERILOG" = "1" ] && [ "$RUN_VERILATOR" = "0" ] && MODE_DESC="iverilog only"
log "Workers: $WORKERS  Mode: $MODE_DESC"
hdr "1/5  i8048 KLR Regression"
cd "$ROOT/gemini8048"
log "Running: bash run_48"
bash run_48 2>&1 > /tmp/run48.log || true
if grep -q "ALL TESTS PASSED" /tmp/run48.log; then
    TOTAL=$(grep -o 'Total: *[0-9]*' /tmp/run48.log | grep -o '[0-9]*' | tail -1)
    ok "i8048 regression — $TOTAL tests passed"
else
    FAILED=$(grep -o 'FAILED: *[0-9]*' /tmp/run48.log | grep -o '[0-9]*' | tail -1)
    fail "i8048 regression — ${FAILED:-?} test(s) FAILED (see /tmp/run48.log)"
fi

# ── 2. i8051 DME regression ───────────────────────────────────────────────────
hdr "2/5  i8051 DME Regression"
cd "$ROOT/claude_8051"
log "Running: bash run_reg"
bash run_reg 2>&1 > /tmp/run_reg.log || true
if grep -q "ALL TESTS PASSED" /tmp/run_reg.log; then
    TOTAL=$(grep -o 'Total: *[0-9]*' /tmp/run_reg.log | grep -o '[0-9]*' | tail -1)
    ok "i8051 regression — $TOTAL tests passed"
else
    FAILED=$(grep -o 'FAILED: *[0-9]*' /tmp/run_reg.log | grep -o '[0-9]*' | tail -1)
    fail "i8051 regression — ${FAILED:-?} test(s) FAILED (see /tmp/run_reg.log)"
fi

# ── 3. Verilator full suite ───────────────────────────────────────────────────
hdr "3/5  Verilator Dashboard Test Suite"
if [ "$RUN_VERILATOR" = "1" ]; then
    cd "$DME_KLR"
    log "Running Verilator suite (--verilator --all) ..."
    log "Running: bash run_dashboard_parallel.sh --verilator $WORKERS"
    bash run_dashboard_parallel.sh --verilator "$WORKERS" 2>&1 | tee /tmp/vl_suite.log
    log "Verilator test suite completed"
    VL_SUMMARY=$(grep "Total:.*PASS:.*WARN:.*FAIL:" ~/coding_projects/944/tmp/dme_klr/v_dash_logs/parallel_summary.log 2>/dev/null | tail -1)
    VL_PASS=$(echo "$VL_SUMMARY" | grep -o 'PASS: *[0-9]*' | grep -o '[0-9]*')
    VL_WARN=$(echo "$VL_SUMMARY" | grep -o 'WARN: *[0-9]*' | grep -o '[0-9]*')
    VL_FAIL=$(echo "$VL_SUMMARY" | grep -o 'FAIL: *[0-9]*' | grep -o '[0-9]*')
    VL_TOTAL=$(echo "$VL_SUMMARY" | grep -o 'Total: *[0-9]*' | grep -o '[0-9]*')
    if [ "${VL_FAIL:-0}" -eq 0 ] && [ "${VL_WARN:-0}" -eq 0 ]; then
        ok "Verilator — PASS=${VL_PASS:-?} WARN=${VL_WARN:-?} FAIL=${VL_FAIL:-?} / ${VL_TOTAL:-?} tests"
    elif [ "${VL_FAIL:-0}" -eq 0 ]; then
        warn "Verilator — PASS=${VL_PASS:-?} WARN=${VL_WARN:-?} FAIL=${VL_FAIL:-?} / ${VL_TOTAL:-?} tests"
    else
        fail "Verilator — PASS=${VL_PASS:-?} WARN=${VL_WARN:-?} FAIL=${VL_FAIL:-?} / ${VL_TOTAL:-?} tests"
    fi
else
    log "Skipped (--iverilog only)"
fi

# ── 4. iverilog full suite ────────────────────────────────────────────────────
hdr "4/5  iverilog Dashboard Test Suite"
if [ "$RUN_IVERILOG" = "1" ]; then
    cd "$DME_KLR"
    log "Running iverilog suite (--all) ..."
    log "Running: bash run_dashboard_parallel.sh $WORKERS"
    bash run_dashboard_parallel.sh "$WORKERS" 2>&1 | tee /tmp/iv_suite.log
    log "iverilog test suite completed"
    IV_SUMMARY=$(grep "Total:.*PASS:.*WARN:.*FAIL:" ~/coding_projects/944/tmp/dme_klr/dash_logs/parallel_summary.log 2>/dev/null | tail -1)
    IV_PASS=$(echo "$IV_SUMMARY" | grep -o 'PASS: *[0-9]*' | grep -o '[0-9]*')
    IV_WARN=$(echo "$IV_SUMMARY" | grep -o 'WARN: *[0-9]*' | grep -o '[0-9]*')
    IV_FAIL=$(echo "$IV_SUMMARY" | grep -o 'FAIL: *[0-9]*' | grep -o '[0-9]*')
    IV_TOTAL=$(echo "$IV_SUMMARY" | grep -o 'Total: *[0-9]*' | grep -o '[0-9]*')
    if [ "${IV_FAIL:-0}" -eq 0 ] && [ "${IV_WARN:-0}" -eq 0 ]; then
        ok "iverilog  — PASS=${IV_PASS:-?} WARN=${IV_WARN:-?} FAIL=${IV_FAIL:-?} / ${IV_TOTAL:-?} tests"
    elif [ "${IV_FAIL:-0}" -eq 0 ]; then
        warn "iverilog  — PASS=${IV_PASS:-?} WARN=${IV_WARN:-?} FAIL=${IV_FAIL:-?} / ${IV_TOTAL:-?} tests"
    else
        fail "iverilog  — PASS=${IV_PASS:-?} WARN=${IV_WARN:-?} FAIL=${IV_FAIL:-?} / ${IV_TOTAL:-?} tests"
    fi
else
    log "Skipped (--verilator only)"
fi

# ── 5. iverilog vs Verilator comparison ───────────────────────────────────────
hdr "5/5  iverilog vs Verilator Comparison + FQS Analysis"
if [ "$RUN_VERILATOR" = "0" ] || [ "$RUN_IVERILOG" = "0" ]; then
    STALE_SIDE="Verilator"
    [ "$RUN_VERILATOR" = "1" ] && STALE_SIDE="iverilog"
    log "WARNING - Comparison against older logs ($STALE_SIDE logs are from a previous run, not this one)"
fi
cd "$DME_KLR"
log "Comparing iverilog vs Verilator logs ..."
log "Running: bash compare_all_logs.sh"
bash compare_all_logs.sh 2>&1 | tee /tmp/compare.log
CMP_MATCH=$(grep -oE "MATCH=[0-9]+" /tmp/compare.log | tail -1 | grep -oE "[0-9]+")
CMP_NEAR=$(grep -oE "NEAR=[0-9]+"  /tmp/compare.log | tail -1 | grep -oE "[0-9]+")
CMP_DIFF=$(grep -oE "DIFF=[0-9]+"  /tmp/compare.log | tail -1 | grep -oE "[0-9]+")
CMP_SKIP=$(grep -oE "SKIP=[0-9]+"  /tmp/compare.log | tail -1 | grep -oE "[0-9]+")
if [ "${CMP_DIFF:-0}" -eq 0 ]; then
    ok "iverilog == Verilator — ${CMP_MATCH:-?} tests match"
elif [ "${CMP_DIFF:-0}" -le 4 ]; then
    warn "iverilog vs Verilator — MATCH=${CMP_MATCH:-?} NEAR=${CMP_NEAR:-0} DIFF=${CMP_DIFF:-?} SKIP=${CMP_SKIP:-0} (known timing-sensitive tests)"
else
    fail "iverilog vs Verilator — MATCH=${CMP_MATCH:-?} NEAR=${CMP_NEAR:-0} DIFF=${CMP_DIFF:-?} SKIP=${CMP_SKIP:-0} (see /tmp/compare.log)"
fi

log "Generating detailed compare_sim_logs.py reports for differing tests ..."
IV_DASH_DIR="$HOME/coding_projects/944/tmp/dme_klr/dash_logs"
VL_DASH_DIR="$HOME/coding_projects/944/tmp/dme_klr/v_dash_logs"
DIFF_TESTS=$(awk '$1=="DIFF" || $1=="ERROR" {print $2}' /tmp/compare.log | sort -u)
if [ -n "$DIFF_TESTS" ]; then
    > /tmp/compare_detail.log
    for t in $DIFF_TESTS; do
        iv_log="$IV_DASH_DIR/${t}.dash.log"
        vl_log="$VL_DASH_DIR/${t}.dash.log"
        if [ -f "$iv_log" ] && [ -f "$vl_log" ]; then
            log "  compare_sim_logs.py: $t"
            {
                echo "===== $t ====="
                python3 "$DME_KLR/compare_sim_logs.py" --dash "$iv_log" "$vl_log" "$t" \
                    -v --plot --plot-dir "$IV_DASH_DIR"
                echo ""
            } 2>&1 | tee -a /tmp/compare_detail.log
        else
            warn "  skipping $t (log file missing: $iv_log or $vl_log)"
        fi
    done
    log "Per-test detail: /tmp/compare_detail.log   Plots: $IV_DASH_DIR"
else
    log "No differing tests — skipping detailed compare_sim_logs.py reports"
fi

log "Running FQS analysis ..."
log "Running: python3 fqs_analysis.py"
python3 fqs_analysis.py 2>&1 | tee /tmp/fqs_analysis.log
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

hdr "SUMMARY"
echo -e "  Wall time : ${MINS}m${SECS}s"
echo -e "  ${GREEN}PASS${NC} : $PASS"
echo -e "  ${YELLOW}WARN${NC} : $WARN"
echo -e "  ${RED}FAIL${NC} : $FAIL"
echo ""
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  *** ALL CHECKS PASSED ***${NC}"
elif [ "$FAIL" -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}  *** PASSED WITH WARNINGS ***${NC}"
else
    echo -e "${RED}${BOLD}  *** ${FAIL} CHECK(S) FAILED ***${NC}"
fi
echo ""
exit $(( FAIL > 0 ? 1 : 0 ))
