#!/bin/bash
# ============================================================
#  build_live.sh — build the interactive DME+KLR simulator
#
#  Produces dme_klr/live/obj/dme_klr_live, a Verilator build of
#  dme_klr_dashboard_tb with -DLIVE: inputs come from sim_main.cpp
#  (driven by the web dashboard through bridge.mjs) instead of the
#  compile-time TEST_* scenarios.
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

cd "$DMEKLR_DIR"
verilator --cc --exe --build --timing -j 0 \
    -O3 --x-assign fast --x-initial fast --noassert \
    -CFLAGS -O2 \
    --Mdir "$LIVE_DIR/obj" -o dme_klr_live \
    -f files \
    --top-module dme_klr_dashboard_tb \
    -DVLT_SIM -DDASHBOARD_TB -DDME_KLR_COMBINED -DLIVE \
    -DRPMRAMP -DRPMSTART=100 -DRPMEND=7000 -DSTEP_CLOCKS=6000 \
    -DSKIP_LAMBDA_WARMUP \
    -DSIM_TIME=3600000000000 \
    -DDASH_INTERVAL_MS="$DASH_INTERVAL_MS" \
    -DDME_ROM_DIR="\"$DME_ROM_DIR\"" -DDME_ROM_FILE="\"$DME_ROM_FILE\"" \
    -DKLR_ROM_DIR="\"$KLR_ROM_DIR\"" -DKLR_ROM_FILE="\"$KLR_ROM_FILE\"" \
    -Wno-fatal -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
    -Wno-REDEFMACRO -Wno-DEFOVERRIDE -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-MULTIDRIVEN \
    "$@" \
    "$LIVE_DIR/sim_main.cpp"

echo "Built $LIVE_DIR/obj/dme_klr_live"
