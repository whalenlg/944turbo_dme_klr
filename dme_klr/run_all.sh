#!/usr/bin/env bash
# =============================================================================
#  Runs: i8048 regression, i8051 regression, Verilator suite, iverilog suite,
#        iverilog/Verilator comparison, FQS analysis, macOS install test (VM)
#        iverilog/Verilator comparison, FQS analysis
#
#  Usage:
#    ./run_all.sh [--verilator | --iverilog] [--per-test-build]
#                 [--macos-test install|lite|both|none] [--no-pull]
#                 [--tests "NAME|GROUP ..."] [--DME_DEBUG] [--DME_DEEP_DEBUG]
#                 [--KLR_DEBUG] [--test-debug=TEST:FLAG[+FLAG] ...]
#                 [--no-plot] [--roms "89 86 carpokes"] [workers 1-8, default 8]
#    ./run_all.sh --help
#
#  --tests runs only those dashboard tests (names, or the group names
#  run_dashboard_parallel.sh knows) in steps 3-4; default all of them.
#  --no-pull skips the "git checkout main" and "git pull" at the start.
#  --DME_DEBUG / --DME_DEEP_DEBUG / --KLR_DEBUG go to the iverilog suite
#  (step 4) only: each test is built on its own with that debug output, and
#  every test stays on this machine (no regression hosts; large dumps).
#  --test-debug=TEST:DME_DEBUG+KLR_DEBUG does that for one test only
#  (repeatable; the dashboard panel's per-test switches).
#  Step 5 plots each test whose iverilog and Verilator logs differ
#  (compare_sim_logs.py --plot: <test>_DME_diff.jpg / <test>_KLR_diff.jpg
#  in the iverilog dash_logs); --no-plot skips the plots (the panel's
#  Plot Differences box off).
#  --roms runs steps 3-5 for each of those ROM pairs (89: the 1989 images,
#  86: run86.sh's, carpokes: run_carpokes.sh's), each in its own folder
#  ($DMEKLR_TMP/dme_klr/<rom>: its logs, per-test builds, hex dumps and this
#  script's step logs, run_all/), so nothing is shared while they run but
#  the one testbench build per simulator. With more than one, every suite's
#  lines start with [VL:<rom>] / [IV:<rom>], and every pair's suites run at
#  the same time, sharing the workers (below). Steps 1-2 and 6 run once.
#  Without --roms: the pair DME_ROM_FILE / KLR_ROM_FILE name (default 89).
#  The dashboard's RUN REGRESSIONS panel (live/runall.mjs) runs this script.
#
#  By default runs both the Verilator and iverilog dashboard suites (and the
#  comparison + FQS analysis step that depends on both). Pass --verilator or
#  --iverilog to run only that simulator's suite — the comparison/FQS step
#  is skipped in that case, since it needs both sides' logs.
#  When more than one suite runs (both simulators, or several ROM pairs),
#  they all run at the same time (step "3+4/6") and share the workers and
#  the regression hosts' threads: a thread that frees up starts the next
#  waiting test of any suite (run_dashboard_parallel.sh's DMEKLR_SLOT_POOL).
#  With both simulators, their lines start with [VL] / [IV].
#  Each suite builds the testbench once and runs every test on that build;
#  --per-test-build builds every test on its own instead.
#  Step 6 (macOS with Tart only) then tests the install in a clean macOS
#  VM (install/test_macos_vm.sh), when steps 1-5 had no FAIL and neither
#  dashboard suite had more than 5 WARN tests. --macos-test picks the
#  developer install, the lite package (built here), both (default), or
#  none.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Parse args: --verilator / --iverilog restrict which simulator suite(s)
#    run (steps 3-5); default (neither flag) runs both, as before.
_want_verilator=0
_want_iverilog=0
ARGS=()
usage() { sed -n '3,42s/^# \{0,2\}//p' "$0"; }
PT_OPT=()
MACOS_TEST=both
SUITE_TESTS=()
PULL=1
IV_DEBUG=()
PLOT=1
ROMS=()
_next=""
for arg in "$@"; do
    if [ "$_next" = macos ]; then MACOS_TEST="$arg"; _next=""; continue; fi
    if [ "$_next" = tests ]; then read -r -a SUITE_TESTS <<< "$arg"; _next=""; continue; fi
    if [ "$_next" = roms ]; then read -r -a ROMS <<< "$(echo "$arg" | tr ',' ' ')"; _next=""; continue; fi
    case "$arg" in
        --macos-test) _next=macos ;;
        --tests) _next=tests ;;
        --roms) _next=roms ;;
        --roms=*) read -r -a ROMS <<< "$(echo "${arg#*=}" | tr ',' ' ')" ;;
        --tests=*) read -r -a SUITE_TESTS <<< "${arg#*=}" ;;
        --no-pull) PULL=0 ;;
        --no-plot) PLOT=0 ;;
        --plot) PLOT=1 ;;
        --macos-test=*) MACOS_TEST="${arg#*=}" ;;
        --verilator) _want_verilator=1 ;;
        --iverilog)  _want_iverilog=1 ;;
        --per-test-build) PT_OPT=(--per-test-build) ;;
        --DME_DEBUG|--DME_DEEP_DEBUG|--KLR_DEBUG|--test-debug=*) IV_DEBUG+=("$arg") ;;
        -h|--help)   usage; exit 0 ;;
        -*)          echo "run_all.sh: unknown option '$arg'" >&2; usage >&2; exit 2 ;;
        *)           ARGS+=("$arg") ;;
    esac
done
if [ "$_want_verilator" = "0" ] && [ "$_want_iverilog" = "0" ]; then
    RUN_VERILATOR=1; RUN_IVERILOG=1   # default: run both
else
    RUN_VERILATOR="$_want_verilator"
    RUN_IVERILOG="$_want_iverilog"
fi
case "$MACOS_TEST" in install|lite|both|none) ;; *)
    echo "run_all.sh: --macos-test wants install, lite, both or none (got '$MACOS_TEST')" >&2; exit 2 ;;
esac
for _r in ${ROMS[@]+"${ROMS[@]}"}; do
    case "$_r" in 89|86|carpokes) ;; *)
        echo "run_all.sh: --roms takes 89, 86 and carpokes (got '$_r')" >&2; exit 2 ;;
    esac
done
WORKERS="${ARGS[0]:-8}"
if ! [[ "$WORKERS" =~ ^[1-8]$ ]] || [ "${#ARGS[@]}" -gt 1 ]; then
    echo "run_all.sh: workers must be a single number 1-8 (got '${ARGS[*]}')" >&2
    usage >&2
    exit 2
fi

if [ "$PULL" = 1 ]; then
    echo "== git checkout main =="
    (cd "$ROOT" && git checkout main)
    echo "== git pull origin main =="
    (cd "$ROOT" && git pull origin main)
else
    echo "== --no-pull: running the checkout as it is =="
fi

DME_KLR="$ROOT/dme_klr"
source "$ROOT/paths.sh"          # DMEKLR_TMP: where the suites write
RUNLOG="$DMEKLR_TMP/run_all"      # this script's own logs of steps 1, 2 and 6
mkdir -p "$RUNLOG"

# rom_env <89|86|carpokes>: that ROM pair's images and log folder
# (DMEKLR_LOGS) for what runs next in this shell; PRUN: its step logs
rom_env() {
    case "$1" in
        89)       export DME_ROM_FILE=89DME_951pin.mem KLR_ROM_FILE=89KLR_951.mem ;;
        86)       export DME_ROM_FILE=28PIN_86DME.mem KLR_ROM_FILE=86KLR_951.mem ;;
        carpokes) export DME_ROM_FILE=28PIN_DME_PERFORMANCE.mem KLR_ROM_FILE=87KLR_951.mem ;;
    esac
    [ -n "$1" ] && unset DME_ROM_DIR KLR_ROM_DIR   # the repo's bin_images
    DMEKLR_LOGS="$DMEKLR_TMP/dme_klr/$(dmeklr_rom_variant)"
    export DMEKLR_LOGS
    PRUN="$DMEKLR_LOGS/run_all"
    mkdir -p "$PRUN"
}
# The pairs to run: --roms, or the one the environment names ("" = as it is)
MULTI=0
if [ ${#ROMS[@]} -eq 0 ]; then ROMS=(""); elif [ ${#ROMS[@]} -gt 1 ]; then MULTI=1; fi
rom_env "${ROMS[0]}"
if [ "$MULTI" = 1 ]; then
    echo "== dashboard test logs: one folder per ROM pair, $DMEKLR_TMP/dme_klr/{$(IFS=,; echo "${ROMS[*]}")} =="
else
    echo "== dashboard test logs: $DMEKLR_LOGS (this ROM pair's folder) =="
fi
PASS=0; WARN=0; FAIL=0
SUITE_WARN_MAX=0   # the most WARN tests of any dashboard suite (step 6 runs only up to 5)
START_TIME=$(date +%s)
# Summaries older than this marker are from a previous run and must not be
# reported as this run's result (e.g. a suite that exits without running).
RUN_MARKER=$(mktemp)
trap 'rm -f "$RUN_MARKER"' EXIT

# Colours
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PFX=""   # "[VL] " / "[IV] ": the suites' verdicts when they ran at the same time
log()  { echo -e "${CYAN}[run_all]${NC} $*"; }
ok()   { echo -e "${PFX}${GREEN}  ✓ PASS${NC}  $*"; ((PASS++)); }
warn() { echo -e "${PFX}${YELLOW}  ⚠ WARN${NC}  $*"; ((WARN++)); }
fail() { echo -e "${PFX}${RED}  ✗ FAIL${NC}  $*"; ((FAIL++)); }
hdr()  { echo -e "\n${BOLD}══════════════════════════════════════════════════════${NC}"; \
          echo -e "${BOLD}  $*${NC}"; \
          echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"; }

# ── 1. i8048 KLR regression ───────────────────────────────────────────────────
MODE_DESC="both simulators"
[ "$RUN_VERILATOR" = "1" ] && [ "$RUN_IVERILOG" = "0" ] && MODE_DESC="Verilator only"
[ "$RUN_IVERILOG" = "1" ] && [ "$RUN_VERILATOR" = "0" ] && MODE_DESC="iverilog only"
log "Workers: $WORKERS  Mode: $MODE_DESC  Tests: ${SUITE_TESTS[*]:-all}${ROMS[0]:+  ROM pairs: ${ROMS[*]}}"
hdr "1/6  i8048 KLR Regression"
cd "$ROOT/klr"
log "Running: bash run_klr_regression"
bash run_klr_regression 2>&1 > "$RUNLOG/run_klr_regression.log" || true
if grep -q "ALL TESTS PASSED" "$RUNLOG/run_klr_regression.log"; then
    TOTAL=$(grep -o 'Total: *[0-9]*' "$RUNLOG/run_klr_regression.log" | grep -o '[0-9]*' | tail -1)
    ok "i8048 regression — $TOTAL tests passed"
else
    FAILED=$(grep -o 'FAILED: *[0-9]*' "$RUNLOG/run_klr_regression.log" | grep -o '[0-9]*' | tail -1)
    fail "i8048 regression — ${FAILED:-?} test(s) FAILED (see $RUNLOG/run_klr_regression.log)"
fi

# ── 2. i8051 DME regression ───────────────────────────────────────────────────
hdr "2/6  i8051 DME Regression"
cd "$ROOT/dme"
log "Running: bash run_dme_regression"
bash run_dme_regression 2>&1 > "$RUNLOG/run_dme_regression.log" || true
if grep -q "ALL TESTS PASSED" "$RUNLOG/run_dme_regression.log"; then
    TOTAL=$(grep -o 'Total: *[0-9]*' "$RUNLOG/run_dme_regression.log" | grep -o '[0-9]*' | tail -1)
    ok "i8051 regression — $TOTAL tests passed"
else
    FAILED=$(grep -o 'FAILED: *[0-9]*' "$RUNLOG/run_dme_regression.log" | grep -o '[0-9]*' | tail -1)
    fail "i8051 regression — ${FAILED:-?} test(s) FAILED (see $RUNLOG/run_dme_regression.log)"
fi

# ── 3-4. The Verilator and iverilog dashboard suites ──────────────────────────
# Each suite's run and its verdict line. When more than one suite runs they
# run at the same time, sharing the workers (below); their output lines then
# start with [VL] / [IV], or [VL:<rom>] / [IV:<rom>] with several ROM pairs
# (live/runall.mjs reads them so), and the step header is "3+4/6".
vl_suite() {
    cd "$DME_KLR"
    log "Running Verilator suite (--verilator) ..."
    log "Running: bash run_dashboard_parallel.sh --verilator $1"
    bash run_dashboard_parallel.sh --verilator ${PT_OPT[@]+"${PT_OPT[@]}"} "$1" ${SUITE_TESTS[@]+"${SUITE_TESTS[@]}"} 2>&1 | tee "$PRUN/vl_suite.log"
    log "Verilator test suite completed"
}
vl_verdict() {
    local V="Verilator"; [ "$MULTI" = 1 ] && V="Verilator ($(dmeklr_rom_variant))"
    VL_SUMMARY_LOG="$DMEKLR_LOGS/v_dash_logs/parallel_summary.log"
    VL_SUMMARY=""
    [ "$VL_SUMMARY_LOG" -nt "$RUN_MARKER" ] && \
        VL_SUMMARY=$(grep "Total:.*PASS:.*WARN:.*FAIL:" "$VL_SUMMARY_LOG" 2>/dev/null | tail -1)
    VL_PASS=$(echo "$VL_SUMMARY" | grep -o 'PASS: *[0-9]*' | grep -o '[0-9]*')
    VL_WARN=$(echo "$VL_SUMMARY" | grep -o 'WARN: *[0-9]*' | grep -o '[0-9]*')
    VL_FAIL=$(echo "$VL_SUMMARY" | grep -o 'FAIL: *[0-9]*' | grep -o '[0-9]*')
    VL_TOTAL=$(echo "$VL_SUMMARY" | grep -o 'Total: *[0-9]*' | grep -o '[0-9]*')
    if [ -z "$VL_SUMMARY" ]; then
        fail "$V — no summary from this run (suite did not complete)"
    elif [ "${VL_FAIL:-0}" -eq 0 ] && [ "${VL_WARN:-0}" -eq 0 ]; then
        ok "$V — PASS=${VL_PASS:-?} WARN=${VL_WARN:-?} FAIL=${VL_FAIL:-?} / ${VL_TOTAL:-?} tests"
    elif [ "${VL_FAIL:-0}" -eq 0 ]; then
        warn "$V — PASS=${VL_PASS:-?} WARN=${VL_WARN:-?} FAIL=${VL_FAIL:-?} / ${VL_TOTAL:-?} tests"
    else
        fail "$V — PASS=${VL_PASS:-?} WARN=${VL_WARN:-?} FAIL=${VL_FAIL:-?} / ${VL_TOTAL:-?} tests"
    fi
    [ "${VL_WARN:-0}" -gt "$SUITE_WARN_MAX" ] && SUITE_WARN_MAX=${VL_WARN:-0}
}
iv_suite() {
    cd "$DME_KLR"
    log "Running iverilog suite ..."
    log "Running: bash run_dashboard_parallel.sh $1 ${IV_DEBUG[*]+${IV_DEBUG[*]}}"
    bash run_dashboard_parallel.sh ${PT_OPT[@]+"${PT_OPT[@]}"} ${IV_DEBUG[@]+"${IV_DEBUG[@]}"} "$1" ${SUITE_TESTS[@]+"${SUITE_TESTS[@]}"} 2>&1 | tee "$PRUN/iv_suite.log"
    log "iverilog test suite completed"
}
iv_verdict() {
    local V="iverilog "; [ "$MULTI" = 1 ] && V="iverilog ($(dmeklr_rom_variant))"
    IV_SUMMARY_LOG="$DMEKLR_LOGS/dash_logs/parallel_summary.log"
    IV_SUMMARY=""
    [ "$IV_SUMMARY_LOG" -nt "$RUN_MARKER" ] && \
        IV_SUMMARY=$(grep "Total:.*PASS:.*WARN:.*FAIL:" "$IV_SUMMARY_LOG" 2>/dev/null | tail -1)
    IV_PASS=$(echo "$IV_SUMMARY" | grep -o 'PASS: *[0-9]*' | grep -o '[0-9]*')
    IV_WARN=$(echo "$IV_SUMMARY" | grep -o 'WARN: *[0-9]*' | grep -o '[0-9]*')
    IV_FAIL=$(echo "$IV_SUMMARY" | grep -o 'FAIL: *[0-9]*' | grep -o '[0-9]*')
    IV_TOTAL=$(echo "$IV_SUMMARY" | grep -o 'Total: *[0-9]*' | grep -o '[0-9]*')
    if [ -z "$IV_SUMMARY" ]; then
        fail "$V — no summary from this run (suite did not complete)"
    elif [ "${IV_FAIL:-0}" -eq 0 ] && [ "${IV_WARN:-0}" -eq 0 ]; then
        ok "$V — PASS=${IV_PASS:-?} WARN=${IV_WARN:-?} FAIL=${IV_FAIL:-?} / ${IV_TOTAL:-?} tests"
    elif [ "${IV_FAIL:-0}" -eq 0 ]; then
        warn "$V — PASS=${IV_PASS:-?} WARN=${IV_WARN:-?} FAIL=${IV_FAIL:-?} / ${IV_TOTAL:-?} tests"
    else
        fail "$V — PASS=${IV_PASS:-?} WARN=${IV_WARN:-?} FAIL=${IV_FAIL:-?} / ${IV_TOTAL:-?} tests"
    fi
    [ "${IV_WARN:-0}" -gt "$SUITE_WARN_MAX" ] && SUITE_WARN_MAX=${IV_WARN:-0}
}
# prefix <tag>: each line with "[tag] " as it comes (a read loop: awk may
# read its input in blocks, holding the lines back until the suite ends)
prefix() { local l; while IFS= read -r l || [ -n "$l" ]; do printf '[%s] %s\n' "$1" "$l"; done; }

N_SIMS=$(( RUN_VERILATOR + RUN_IVERILOG ))

# one_pair_suites <workers>: steps 3-4 when only one suite runs (one
# simulator, one ROM pair); the other step says it was skipped
one_pair_suites() {
    local w=$1
    hdr "3/6  Verilator Dashboard Test Suite"
    if [ "$RUN_VERILATOR" = "1" ]; then
        vl_suite "$w"
        vl_verdict
    else
        log "Skipped (--iverilog only)"
    fi

    hdr "4/6  iverilog Dashboard Test Suite"
    if [ "$RUN_IVERILOG" = "1" ]; then
        iv_suite "$w"
        iv_verdict
    else
        log "Skipped (--verilator only)"
    fi
}

N_SUITES=$(( N_SIMS * ${#ROMS[@]} ))
if [ "$N_SUITES" -le 1 ]; then
    one_pair_suites "$WORKERS"
else
    # Several suites (both simulators, and/or several ROM pairs): all of
    # them at once, sharing the $WORKERS workers (and the regression hosts'
    # threads) through one pool of tokens (DMEKLR_SLOT_POOL, see
    # run_dashboard_parallel.sh), so a thread that frees up starts the next
    # waiting test of any suite, not only of its own
    if [ "$MULTI" = 1 ]; then hdr "3+4/6  Dashboard Test Suites for the ROM pairs ${ROMS[*]}"
    else hdr "3+4/6  Verilator and iverilog Dashboard Test Suites, at the same time"; fi
    log "$N_SUITES suites at once, sharing the $WORKERS workers: a test starts on whichever worker frees up first"
    # The shared testbench builds (one per simulator, every pair runs on
    # them), once, before the suites start: they would all build the same
    # files at once otherwise
    _shared_iv=1
    for _a in ${IV_DEBUG[@]+"${IV_DEBUG[@]}"}; do case "$_a" in --DME_DEBUG|--DME_DEEP_DEBUG|--KLR_DEBUG) _shared_iv=0 ;; esac; done
    if [ ${#PT_OPT[@]} -eq 0 ]; then
        _built=1
        if [ "$RUN_VERILATOR" = 1 ]; then
            log "Building the shared Verilator testbench once → $DMEKLR_TMP/dme_klr/runtime"
            bash "$DME_KLR/build_runtime.sh" --out "$DMEKLR_TMP/dme_klr/runtime" > "$RUNLOG/runtime_build.log" 2>&1 || _built=0
        fi
        if [ "$RUN_IVERILOG" = 1 ] && [ "$_shared_iv" = 1 ]; then
            log "Building the shared iverilog testbench once → $DMEKLR_TMP/dme_klr/runtime_iv"
            bash "$DME_KLR/build_runtime.sh" --out "$DMEKLR_TMP/dme_klr/runtime_iv" --iverilog > "$RUNLOG/runtime_iv_build.log" 2>&1 || _built=0
        fi
        if [ "$_built" = 1 ]; then
            export DMEKLR_RUNTIME_PREBUILT=1   # run_dashboard_parallel.sh uses them as they are
        else
            warn "A shared testbench build failed (see $RUNLOG/runtime_build.log, runtime_iv_build.log): each suite tries its own"
        fi
    fi
    DMEKLR_SLOT_POOL="$(mktemp -d "$RUNLOG/slots.XXXXXX")"
    export DMEKLR_SLOT_POOL DMEKLR_SLOT_POOL_N="$WORKERS"
    _pids=()
    for _r in "${ROMS[@]}"; do
        for _s in ${RUN_VERILATOR/1/VL} ${RUN_IVERILOG/1/IV}; do
            [ "$_s" = 0 ] && continue
            _tag="$_s"; [ "$MULTI" = 1 ] && _tag="$_s:$_r"
            if [ "$_s" = VL ]; then
                ( rom_env "$_r"; vl_suite "$WORKERS" 2>&1 | prefix "$_tag" ) &
            else
                ( rom_env "$_r"; iv_suite "$WORKERS" 2>&1 | prefix "$_tag" ) &
            fi
            _pids+=($!)
        done
    done
    wait "${_pids[@]}"
    rm -rf "$DMEKLR_SLOT_POOL"
    unset DMEKLR_RUNTIME_PREBUILT DMEKLR_SLOT_POOL DMEKLR_SLOT_POOL_N
    for _r in "${ROMS[@]}"; do
        rom_env "$_r"
        _t=""; [ "$MULTI" = 1 ] && _t=":$_r"
        [ "$RUN_VERILATOR" = 1 ] && { PFX="[VL$_t] "; vl_verdict; }
        [ "$RUN_IVERILOG" = 1 ] && { PFX="[IV$_t] "; iv_verdict; }
        PFX=""
    done
fi

# ── 5. iverilog vs Verilator comparison ───────────────────────────────────────
hdr "5/6  iverilog vs Verilator Comparison + FQS Analysis"
if [ "$RUN_VERILATOR" = "0" ] || [ "$RUN_IVERILOG" = "0" ]; then
    STALE_SIDE="Verilator"
    [ "$RUN_VERILATOR" = "1" ] && STALE_SIDE="iverilog"
    log "WARNING - Comparison against older logs ($STALE_SIDE logs are from a previous run, not this one)"
fi
# compare_pair: step 5 for the pair rom_env set
compare_pair() {
    local RP=""; [ "$MULTI" = 1 ] && RP="$(dmeklr_rom_variant): "
    cd "$DME_KLR"
    log "Comparing iverilog vs Verilator logs ..."
    log "Running: bash compare_all_logs.sh"
    bash compare_all_logs.sh 2>&1 | tee "$PRUN/compare.log"
    CMP_MATCH=$(grep -oE "[[:space:]]MATCH=[0-9]+" "$PRUN/compare.log" | tail -1 | grep -oE "[0-9]+")
    CMP_NEAR=$(grep -oE "NEAR=[0-9]+"  "$PRUN/compare.log" | tail -1 | grep -oE "[0-9]+")
    CMP_NOTE=$(grep -oE "NOTE=[0-9]+"  "$PRUN/compare.log" | tail -1 | grep -oE "[0-9]+")
    CMP_DIFF=$(grep -oE "DIFF=[0-9]+"  "$PRUN/compare.log" | tail -1 | grep -oE "[0-9]+")
    CMP_SKIP=$(grep -oE "SKIP=[0-9]+"  "$PRUN/compare.log" | tail -1 | grep -oE "[0-9]+")
    if [ "${CMP_DIFF:-0}" -eq 0 ]; then
        ok "${RP}iverilog == Verilator — ${CMP_MATCH:-?} tests match${CMP_NOTE:+, ${CMP_NOTE} NOTE (X-init differences, expected)}"
    elif [ "${CMP_DIFF:-0}" -le 4 ]; then
        warn "${RP}iverilog vs Verilator — MATCH=${CMP_MATCH:-?} NEAR=${CMP_NEAR:-0} NOTE=${CMP_NOTE:-0} DIFF=${CMP_DIFF:-?} SKIP=${CMP_SKIP:-0} (known timing-sensitive tests)"
    else
        fail "${RP}iverilog vs Verilator — MATCH=${CMP_MATCH:-?} NEAR=${CMP_NEAR:-0} NOTE=${CMP_NOTE:-0} DIFF=${CMP_DIFF:-?} SKIP=${CMP_SKIP:-0} (see $PRUN/compare.log)"
    fi

    log "Generating detailed compare_sim_logs.py reports for differing tests ..."
    IV_DASH_DIR="$DMEKLR_LOGS/dash_logs"
    VL_DASH_DIR="$DMEKLR_LOGS/v_dash_logs"
    DIFF_TESTS=$(awk '$1=="DIFF" || $1=="ERROR" {print $2}' "$PRUN/compare.log" | sort -u)
    PLOT_OPT=(--plot --plot-dir "$IV_DASH_DIR")
    [ "$PLOT" = 1 ] || { PLOT_OPT=(); log "No plots (--no-plot)"; }
    if [ -n "$DIFF_TESTS" ]; then
        > "$PRUN/compare_detail.log"
        for t in $DIFF_TESTS; do
            iv_log="$IV_DASH_DIR/${t}.dash.log"
            vl_log="$VL_DASH_DIR/${t}.dash.log"
            if [ -f "$iv_log" ] && [ -f "$vl_log" ]; then
                # an older run's plot of this test must not stand for this one
                [ "$PLOT" = 1 ] && rm -f "$IV_DASH_DIR/${t}_DME_diff.jpg" "$IV_DASH_DIR/${t}_KLR_diff.jpg"
                log "  compare_sim_logs.py: $t"
                {
                    echo "===== $t ====="
                    python3 "$DME_KLR/compare_sim_logs.py" --dash "$iv_log" "$vl_log" "$t" \
                        -v ${PLOT_OPT[@]+"${PLOT_OPT[@]}"}
                    echo ""
                } 2>&1 | tee -a "$PRUN/compare_detail.log"
            else
                warn "  ${RP}skipping $t (log file missing: $iv_log or $vl_log)"
            fi
        done
        log "Per-test detail: $PRUN/compare_detail.log${PLOT_OPT[0]+   Plots: $IV_DASH_DIR}"
    else
        log "No differing tests — skipping detailed compare_sim_logs.py reports"
    fi

    log "Running FQS analysis ..."
    log "Running: python3 fqs_analysis.py"
    python3 fqs_analysis.py 2>&1 | tee "$PRUN/fqs_analysis.log"
    echo ""
}
for _r in "${ROMS[@]}"; do
    rom_env "$_r"
    [ "$MULTI" = 1 ] && log "ROM pair $_r → $DMEKLR_LOGS"
    compare_pair
done

# ── 6. macOS install test in a clean VM ───────────────────────────────────────
hdr "6/6  macOS Install Test (clean VM)"
MAX_SUITE_WARN=5
SUITE_WARN=$SUITE_WARN_MAX
if [ "$MACOS_TEST" = none ]; then
    log "Skipped (--macos-test none)"
elif [ "$(uname -s)" != Darwin ] || ! command -v tart >/dev/null 2>&1; then
    log "Skipped (needs macOS with Tart: brew install cirruslabs/cli/tart)"
elif [ "$FAIL" -gt 0 ] || [ "$SUITE_WARN" -gt "$MAX_SUITE_WARN" ]; then
    log "Skipped: steps 1-5 had $FAIL FAIL and up to $SUITE_WARN WARN tests in a suite (runs only with no FAIL and <= $MAX_SUITE_WARN WARN)"
else
    MODES=("$MACOS_TEST"); [ "$MACOS_TEST" = both ] && MODES=(install lite)
    for m in "${MODES[@]}"; do
        VM_OUT="$RUNLOG/macos_vm_$m"
        VMARGS=(--name "dmeklr-runall-$m" --replace --out "$VM_OUT")
        [ "$m" = lite ] && VMARGS+=(--lite build)
        log "Running: install/test_macos_vm.sh ${VMARGS[*]}"
        bash "$ROOT/install/test_macos_vm.sh" "${VMARGS[@]}" 2>&1 | tee "$RUNLOG/macos_vm_$m.log"
        rc=${PIPESTATUS[0]}
        if [ "$rc" = 0 ]; then
            ok "macOS VM, $m — all steps passed"
        else
            fail "macOS VM, $m — exit $rc (see $VM_OUT/summary.txt and $RUNLOG/macos_vm_$m.log)"
        fi
    done
fi

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
