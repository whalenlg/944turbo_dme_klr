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

# DME/KLR disassembly tables to match DME_ROM_FILE / KLR_ROM_FILE (see asm_select.sh)
source "$DMEKLR_DIR/asm_select.sh"
ASM_DEFS=()
dme_asm_select ASM_DEFS
klr_asm_select ASM_DEFS

cd "$DMEKLR_DIR"
mkdir -p "$LIVE_DIR/obj"
# Empty stand-in for the first build; gen_state.py writes the real one
printf '#include "live_fields.h"\nvoid liveFields(Vdme_klr_dashboard_tb__Syms*, LiveFieldList&) {}\n' \
    > "$LIVE_DIR/obj/live_fields.cpp"
verilator --cc --exe --build --timing -j 0 \
    -O3 --x-assign fast --x-initial fast --noassert \
    -CFLAGS -O2 -CFLAGS "-I$LIVE_DIR" \
    --Mdir "$LIVE_DIR/obj" -o dme_klr_live \
    -f files_cl \
    --top-module dme_klr_dashboard_tb \
    -DVLT_SIM -DDASHBOARD_TB -DDME_KLR_COMBINED -DLIVE \
    -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'h28 -DBOOST \
    -DSKIP_LAMBDA_WARMUP \
    -DSIM_TIME=3600000000000 \
    -DDASH_INTERVAL_MS="$DASH_INTERVAL_MS" \
    -DDME_ROM_DIR="\"$DME_ROM_DIR\"" -DDME_ROM_FILE="\"$DME_ROM_FILE\"" \
    -DKLR_ROM_DIR="\"$KLR_ROM_DIR\"" -DKLR_ROM_FILE="\"$KLR_ROM_FILE\"" \
    "${ASM_DEFS[@]}" \
    -Wno-fatal -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
    -Wno-REDEFMACRO -Wno-DEFOVERRIDE -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-MULTIDRIVEN \
    "$@" \
    "$LIVE_DIR/sim_main.cpp" "$LIVE_DIR/obj/live_fields.cpp"

# List the model's variables from the generated headers, then rebuild
# that file, and Verilator's runtime with live_printf.h (only the runtime
# prints: $display goes through its VL_PRINTF), and relink
python3 "$LIVE_DIR/gen_state.py" "$LIVE_DIR/obj" Vdme_klr_dashboard_tb
rm -f "$LIVE_DIR/obj/verilated.o"
make -s -C "$LIVE_DIR/obj" -f Vdme_klr_dashboard_tb.mk \
    OPT_GLOBAL="-Os -include $LIVE_DIR/live_printf.h" dme_klr_live

echo "Built $LIVE_DIR/obj/dme_klr_live"
