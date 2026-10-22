#!/bin/bash
# ============================================================
#  run_replay.sh — open-loop log replay testbench for the
#  combined DME+KLR model
#
#  Drives the model's inputs (RPM, AFM, MAP, IAT, coolant, battery,
#  altitude, throttle switch, O2) from a recorded car log instead of
#  the closed-loop engine model, then compares the model's ignition
#  advance, KLR retard, injector pulse, dwell and ISV duty with the
#  values the log recorded.
#
#  Usage:
#    ./run_replay.sh                         # first WOT pull (2nd+3rd gear, t=0-14s)
#    ./run_replay.sh --segment 1             # one fill-colour segment (see --list-segments)
#    ./run_replay.sh --start-s 120 --end-s 136
#    ./run_replay.sh --all                   # whole log (~152 s of engine time; slow)
#    ./run_replay.sh --list-segments
#    ./run_replay.sh --xlsx other.xlsx --name mylog ...
#  Anything after -- goes to check_replay.py, e.g.
#    ./run_replay.sh -- --lag-rows 2 --tol ign_adv=2.8
#
#  Env:  WARMUP_MS (default 3000) — first log row held this long so the
#        firmware syncs and settles before the log plays
#        DME_ROM_DIR / DME_ROM_FILE / KLR_ROM_DIR / KLR_ROM_FILE
#        (same defaults as live/build_live.sh)
#        REBUILD=1 forces a Verilator rebuild
#
#  Output: ../../tmp/dme_klr/replay/ (relative to dme_klr/, beside dash_logs)
#          <name>.{stim,expect}.csv
#          <name>.log        (full sim output)
#          <name>.dash.log   (DS lines, loadable in the dashboard)
#          <name>.report.txt / <name>.mismatches.csv
#
#  Speed: about 20 simulated ms per wall-clock second on a 4-core
#  container, so the default 14 s window takes roughly 15 minutes.
# ============================================================
set -e

REPLAY_DIR="$(cd "$(dirname "$0")" && pwd)"
DMEKLR_DIR="$(cd "$REPLAY_DIR/.." && pwd)"
REPO_DIR="$(cd "$DMEKLR_DIR/.." && pwd)"

XLSX="$DMEKLR_DIR/bench/verilog/10_9_evening_WOT_Run.xlsx"
NAME=""
WINDOW=()
CHECK_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --xlsx)          XLSX="$2"; shift 2 ;;
        --name)          NAME="$2"; shift 2 ;;
        --segment)       WINDOW=(--segment "$2"); NAME="${NAME:-seg$2}"; shift 2 ;;
        --start-s|--end-s) WINDOW+=("$1" "$2"); shift 2 ;;
        --all)           WINDOW=(--start-s 0); NAME="${NAME:-all}"; shift ;;
        --list-segments) python3 "$REPLAY_DIR/xlsx_to_stim.py" "$XLSX" --list-segments; exit 0 ;;
        --)              shift; CHECK_ARGS=("$@"); break ;;
        *)               echo "unknown option: $1"; exit 2 ;;
    esac
done
[ ${#WINDOW[@]} -eq 0 ] && WINDOW=(--end-s 14)   # first WOT pull
NAME="${NAME:-$(basename "$XLSX" .xlsx)}"

OUT_DIR="$(cd "$REPO_DIR/.." && pwd)/tmp/dme_klr/replay"   # beside dash_logs, as run_dashboard_tests.sh does
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$NAME"

# ── Build (Verilator, -DLIVE like the live debugger, own main) ──
DME_ROM_DIR="${DME_ROM_DIR:-$REPO_DIR/bin_images/dme/}"
DME_ROM_FILE="${DME_ROM_FILE:-28PIN_DME_PERFORMANCE.mem}"
KLR_ROM_DIR="${KLR_ROM_DIR:-$REPO_DIR/bin_images/klr/}"
KLR_ROM_FILE="${KLR_ROM_FILE:-87KLR_951.mem}"
BIN="$REPLAY_DIR/obj/dme_klr_replay"
if [ "${REBUILD:-0}" = "1" ] || [ ! -x "$BIN" ] || \
   [ -n "$(find "$REPLAY_DIR/replay_main.cpp" "$DMEKLR_DIR/bench" "$REPO_DIR/dme/bench" "$REPO_DIR/dme/rtl" \
            "$REPO_DIR/klr/bench" "$REPO_DIR/klr/rtl" -newer "$BIN" -name '*.[vc]*' 2>/dev/null | head -1)" ]; then
    echo "  Building $BIN"
    cd "$DMEKLR_DIR"
    # DASH_INTERVAL_MS is effectively never: the only snapshots are the
    # per-row ones replay_main requests.
    verilator --cc --exe --build --timing -j 0 \
        -O3 --x-assign fast --x-initial fast --noassert \
        -CFLAGS -O2 \
        --Mdir "$REPLAY_DIR/obj" -o dme_klr_replay \
        -f files_cl \
        --top-module dme_klr_dashboard_tb \
        -DVLT_SIM -DDASHBOARD_TB -DDME_KLR_COMBINED -DLIVE \
        -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'h28 -DBOOST \
        -DSKIP_LAMBDA_WARMUP \
        -DSIM_TIME=3600000000000 \
        -DDASH_INTERVAL_MS=100000000 \
        -DDME_ROM_DIR="\"$DME_ROM_DIR\"" -DDME_ROM_FILE="\"$DME_ROM_FILE\"" \
        -DKLR_ROM_DIR="\"$KLR_ROM_DIR\"" -DKLR_ROM_FILE="\"$KLR_ROM_FILE\"" \
        -Wno-fatal -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
        -Wno-REDEFMACRO -Wno-DEFOVERRIDE -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-MULTIDRIVEN \
        "$REPLAY_DIR/replay_main.cpp" > "$OUT_DIR/build.log" 2>&1 \
        || { tail -30 "$OUT_DIR/build.log"; echo "  BUILD FAILED (see $OUT_DIR/build.log)"; exit 1; }
fi

# ── Stimulus + expected outputs from the log ──
python3 "$REPLAY_DIR/xlsx_to_stim.py" "$XLSX" "$OUT" "${WINDOW[@]}"

# ── Run (from a scratch dir: the tb drops its hex/vcd dumps in cwd) ──
mkdir -p "$OUT_DIR/run_$NAME"
echo "  Running → $OUT.log"
( cd "$OUT_DIR/run_$NAME" && "$BIN" "$OUT.stim.csv" "+warmup_ms=${WARMUP_MS:-3000}" +vcd=/dev/null ) > "$OUT.log"
grep -E "^DME: \[DS\]|^KLR: \[DS\]|^DME: \[PHASE\]|^DME: \[STATUS\]|^KLR: \[STATUS\]|^KLR: \[PHASE\]|^DME: \[SEED\]|^DME: \[WARN\]" \
    "$OUT.log" > "$OUT.dash.log" || true

# ── Compare ──
set +e
python3 "$REPLAY_DIR/check_replay.py" "$OUT.log" "$OUT.expect.csv" \
    --mismatches "$OUT.mismatches.csv" "${CHECK_ARGS[@]}" | tee "$OUT.report.txt"
exit "${PIPESTATUS[0]}"
