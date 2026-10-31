#!/bin/bash
# ============================================================
#  build_live.sh — build the interactive DME+KLR simulator
#
#  Produces dme_klr/live/obj/dme_klr_live, a Verilator build of
#  dme_klr_dashboard_tb with -DLIVE: inputs come from sim_main.cpp
#  (driven by the web dashboard through bridge.mjs) instead of the
#  compile-time TEST_* scenarios. The engine uses the closed-loop
#  model (CL_MODE + AFM_CL_RAMP + BOOST): throttle is the input, and
#  AFM, RPM and boost are computed.
#
#  Builds once, lists the model's variables for snapshots from the
#  generated headers (gen_state.py -> obj/live_fields.cpp, see
#  snapshot.h), then rebuilds that one file and relinks. Verilator's
#  runtime is compiled with live_printf.h so the driver sees the
#  model's output (warnings trigger snapshots).
#
#  Usage:  ./build_live.sh [extra verilator -D flags]
#          ./build_live.sh --test <name> [--script <runner.sh>]
#            a regression test instead: its own -D flags (from
#            run_dashboard_tests.sh, or the runner named) with LIVE_DEBUG
#            in place of LIVE, so it keeps its scripted stimulus but has
#            the debugger's breakpoints, stepping and RAM views. Built in
#            obj/tests/<name>/; the bridge runs it to a test's warning
#            (see test_snap.py).
#  Env:    DME_ROM_DIR / DME_ROM_FILE / KLR_ROM_DIR / KLR_ROM_FILE
#          (default: this repo's bin_images, 28PIN_DME_PERFORMANCE.mem
#           and 87KLR_951.mem — same images as v_run_dashboard_tests.sh)
#          DASH_INTERVAL_MS (default 100)
# ============================================================
set -e

LIVE_DIR="$(cd "$(dirname "$0")" && pwd)"
DMEKLR_DIR="$(cd "$LIVE_DIR/.." && pwd)"
REPO_DIR="$(cd "$DMEKLR_DIR/.." && pwd)"

DME_ROM_DIR="${DME_ROM_DIR:-$REPO_DIR/bin_images/dme/}"
DME_ROM_FILE="${DME_ROM_FILE:-28PIN_DME_PERFORMANCE.mem}"
KLR_ROM_DIR="${KLR_ROM_DIR:-$REPO_DIR/bin_images/klr/}"
KLR_ROM_FILE="${KLR_ROM_FILE:-87KLR_951.mem}"
DASH_INTERVAL_MS="${DASH_INTERVAL_MS:-100}"

TEST=""
TEST_SCRIPT="$DMEKLR_DIR/run_dashboard_tests.sh"
if [ "$1" = "--test" ]; then
    TEST="$2"; shift 2
    if [ "$1" = "--script" ]; then TEST_SCRIPT="$2"; shift 2; fi
fi
if [ -n "$TEST" ]; then
    OBJ="$LIVE_DIR/obj/tests/$TEST"
    TEST_DEFS=()
    while IFS= read -r d; do TEST_DEFS+=("$d"); done \
        < <(python3 "$LIVE_DIR/test_snap.py" defines "$TEST" --script "$TEST_SCRIPT")
    [ ${#TEST_DEFS[@]} -gt 0 ] || { echo "build_live.sh: no -D flags for test $TEST" >&2; exit 1; }
    # STEP_CLOCKS and the file list as the runners work them out
    _sim_time=40000000000; _ramp_pct=25; FILES_LIST=files
    for d in "${TEST_DEFS[@]}"; do
        case "$d" in
            -DSIM_TIME=*)     _sim_time="${d#-DSIM_TIME=}" ;;
            -DRPM_RAMP_PCT=*) _ramp_pct="${d#-DRPM_RAMP_PCT=}" ;;
            -DCL_MODE)        FILES_LIST=files_cl ;;
        esac
    done
    MODE_DEFS=(-DLIVE_DEBUG -DSTEP_CLOCKS=$(( _sim_time / 1000000 * _ramp_pct / 100 * 6000 / 200 ))
               "${TEST_DEFS[@]}" -CFLAGS -DLIVE_SCRIPTED)
else
    OBJ="$LIVE_DIR/obj"
    FILES_LIST=files_cl
    MODE_DEFS=(-DLIVE \
        -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'h28 -DBOOST \
        -DSKIP_LAMBDA_WARMUP \
        -DSIM_TIME=3600000000000)
fi

# DME/KLR disassembly tables to match DME_ROM_FILE / KLR_ROM_FILE (see asm_select.sh)
source "$DMEKLR_DIR/asm_select.sh"
ASM_DEFS=()
dme_asm_select ASM_DEFS
klr_asm_select ASM_DEFS

cd "$DMEKLR_DIR"
mkdir -p "$OBJ"
# Empty stand-in for the first build; gen_state.py writes the real one
printf '#include "live_fields.h"\nvoid liveFields(Vdme_klr_dashboard_tb__Syms*, LiveFieldList&) {}\n' \
    > "$OBJ/live_fields.cpp"
verilator --cc --exe --build --timing -j 0 \
    -O3 --x-assign fast --x-initial fast --noassert \
    -CFLAGS -O2 -CFLAGS "-I$LIVE_DIR" \
    --Mdir "$OBJ" -o dme_klr_live \
    -f "$FILES_LIST" \
    --top-module dme_klr_dashboard_tb \
    -DVLT_SIM -DDASHBOARD_TB -DDME_KLR_COMBINED \
    "${MODE_DEFS[@]}" \
    -DDASH_INTERVAL_MS="$DASH_INTERVAL_MS" \
    -DDME_ROM_DIR="\"$DME_ROM_DIR\"" -DDME_ROM_FILE="\"$DME_ROM_FILE\"" \
    -DKLR_ROM_DIR="\"$KLR_ROM_DIR\"" -DKLR_ROM_FILE="\"$KLR_ROM_FILE\"" \
    "${ASM_DEFS[@]}" \
    -Wno-fatal -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
    -Wno-REDEFMACRO -Wno-DEFOVERRIDE -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-MULTIDRIVEN \
    "$@" \
    "$LIVE_DIR/sim_main.cpp" "$OBJ/live_fields.cpp"

# List the model's variables from the generated headers, then rebuild
# that file, and Verilator's runtime with live_printf.h (only the runtime
# prints: $display goes through its VL_PRINTF), and relink
python3 "$LIVE_DIR/gen_state.py" "$OBJ" Vdme_klr_dashboard_tb
# Delete the objects so make rebuilds them: the real live_fields.cpp can
# land in the same second its stand-in was compiled, and a make that
# compares whole seconds (macOS's /usr/bin/make 3.81) would then keep the
# empty one, and snapshots would hold no variables
rm -f "$OBJ/verilated.o" "$OBJ/live_fields.o"
make -s -C "$OBJ" -f Vdme_klr_dashboard_tb.mk \
    OPT_GLOBAL="-Os -include $LIVE_DIR/live_printf.h" dme_klr_live

echo "Built $OBJ/dme_klr_live"
