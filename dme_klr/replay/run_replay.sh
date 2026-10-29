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
#    ./run_replay.sh --out-dir DIR ...       # results here instead (the dashboard
#                                            # suites use their own dash_logs)
#    ./run_replay.sh --map-offset 16         # raw counts off the MAP byte (default 0)
#    ./run_replay.sh --o2-from-log           # pin O2 from the log's NBO2 instead of
#                                            # the testbench's mixture-following sensor
#    ./run_replay.sh --iverilog --KLR_DEBUG ...  # debug build (also --DME_DEBUG,
#                                            # --DME_DEEP_DEBUG): more waveform, and
#                                            # a per-instruction trace in <name>.log
#    ./run_replay.sh --xlsx other.xlsx --name mylog ...
#    ./run_replay.sh --iverilog ...          # Icarus instead of Verilator (~5x slower)
#    ./run_replay.sh --iverilog --no-fst ... # skip the waveform (faster)
#    ./run_replay.sh --iverilog --vcd ...    # also keep the raw .vcd
#  Anything after -- goes to check_replay.py, e.g.
#    ./run_replay.sh -- --lag-rows 2 --tol ign_adv=2.8
#
#  Env:  WARMUP_MS (default 3000) — first log row held this long so the
#        firmware syncs and settles before the log plays
#        DME_ROM_DIR / DME_ROM_FILE / KLR_ROM_DIR / KLR_ROM_FILE
#        (same defaults as live/build_live.sh)
#        REBUILD=1 forces a rebuild
#
#  Output: ../../tmp/dme_klr/replay/dash_logs/ (iverilog) or
#          ../../tmp/dme_klr/replay/v_dash_logs/ (Verilator), relative to
#          dme_klr/, so the two can run in parallel:
#          <name>.{stim,expect}.csv
#          <name>.log        (full sim output)
#          <name>.dash.log   (DS lines plus the log's expected outputs as
#                             REPLAY: [EXPECT] lines, loadable in the dashboard)
#          <name>.report.txt / <name>.mismatches.csv
#          fst/<name>.fst    (--iverilog runs: waveform made the same way as
#                             run_dashboard_tests.sh's, with the signals
#                             vcd.v / klr_vcd.v choose)
#          vcd/<name>.vcd    (only with --vcd)
#  Verilator runs make no waveform: its tracing ignores $dumpvars scopes
#  and would dump the whole design for the whole run.
#
#  Speed: about 20 simulated ms per wall-clock second with Verilator on
#  a 4-core container (the default 14 s window takes roughly 15 minutes),
#  about 4 with iverilog (roughly 75 minutes).
# ============================================================
set -e

REPLAY_DIR="$(cd "$(dirname "$0")" && pwd)"
DMEKLR_DIR="$(cd "$REPLAY_DIR/.." && pwd)"
REPO_DIR="$(cd "$DMEKLR_DIR/.." && pwd)"

XLSX="$DMEKLR_DIR/bench/verilog/10_9_evening_WOT_Run.xlsx"
NAME=""
SIM=verilator
FST=1
KEEP_VCD=0
WINDOW=()
CHECK_ARGS=()
STIM_ARGS=()
EXTRA_DEFS=()
OUT_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --xlsx)          XLSX="$2"; shift 2 ;;
        --name)          NAME="$2"; shift 2 ;;
        --iverilog)      SIM=iverilog; shift ;;
        --verilator)     SIM=verilator; shift ;;
        --no-fst)        FST=0; shift ;;
        --vcd)           KEEP_VCD=1; shift ;;
        --segment)       WINDOW=(--segment "$2"); NAME="${NAME:-seg$2}"; shift 2 ;;
        --start-s|--end-s) WINDOW+=("$1" "$2"); shift 2 ;;
        --all)           WINDOW=(--start-s 0); NAME="${NAME:-all}"; shift ;;
        --map-offset)    STIM_ARGS+=(--map-offset "$2"); shift 2 ;;
        --o2-from-log)   STIM_ARGS+=(--o2-from-log); shift ;;
        --out-dir)       OUT_DIR="$2"; shift 2 ;;
        --KLR_DEBUG|--DME_DEBUG|--DME_DEEP_DEBUG) EXTRA_DEFS+=("-D${1#--}"); shift ;;
        --list-segments) python3 "$REPLAY_DIR/xlsx_to_stim.py" "$XLSX" --list-segments; exit 0 ;;
        --)              shift; CHECK_ARGS=("$@"); break ;;
        *)               echo "unknown option: $1"; exit 2 ;;
    esac
done
[ ${#WINDOW[@]} -eq 0 ] && WINDOW=(--end-s 14)   # first WOT pull
NAME="${NAME:-$(basename "$XLSX" .xlsx)}"

# iverilog and Verilator results go to separate folders, as with
# run_dashboard_tests.sh (dash_logs) and v_run_dashboard_tests.sh
# (v_dash_logs), so both can run at once
REPLAY_OUT="$(cd "$REPO_DIR/.." && pwd)/tmp/dme_klr/replay"
if [ -z "$OUT_DIR" ]; then
    if [ "$SIM" = "iverilog" ]; then OUT_DIR="$REPLAY_OUT/dash_logs"; else OUT_DIR="$REPLAY_OUT/v_dash_logs"; fi
fi
mkdir -p "$OUT_DIR"; OUT_DIR="$(cd "$OUT_DIR" && pwd)"
OUT="$OUT_DIR/$NAME"

# ── Build: dme_klr_dashboard_tb with -DLIVE like the live debugger, driven
#    by replay_main.cpp (Verilator) or the replay_driver.v top (iverilog) ──
DME_ROM_DIR="${DME_ROM_DIR:-$REPO_DIR/bin_images/dme/}"
DME_ROM_FILE="${DME_ROM_FILE:-28PIN_DME_PERFORMANCE.mem}"
KLR_ROM_DIR="${KLR_ROM_DIR:-$REPO_DIR/bin_images/klr/}"
KLR_ROM_FILE="${KLR_ROM_FILE:-87KLR_951.mem}"
# DME/KLR disassembly tables to match DME_ROM_FILE / KLR_ROM_FILE (see asm_select.sh)
source "$DMEKLR_DIR/asm_select.sh"
ASM_DEFS=()
dme_asm_select ASM_DEFS || exit 1
klr_asm_select ASM_DEFS || exit 1
# DASH_INTERVAL_MS is effectively never: the only snapshots are the
# per-row ones the replay driver requests.
DEFINES=(-DDASHBOARD_TB -DDME_KLR_COMBINED -DLIVE
         -DRPMRAMP -DCL_MODE -DAFM_CL_RAMP -DAFM_CL_TARGET=8\'h28 -DBOOST
         -DSKIP_LAMBDA_WARMUP
         -DSIM_TIME=3600000000000
         -DDASH_INTERVAL_MS=100000000
         -DDME_ROM_DIR="\"$DME_ROM_DIR\"" -DDME_ROM_FILE="\"$DME_ROM_FILE\""
         -DKLR_ROM_DIR="\"$KLR_ROM_DIR\"" -DKLR_ROM_FILE="\"$KLR_ROM_FILE\""
         "${ASM_DEFS[@]}"
         "${EXTRA_DEFS[@]}")
DBG_TAG=$(printf '%s' "${EXTRA_DEFS[@]}" | sed 's/-D/_/g; s/^_//' | tr 'A-Z' 'a-z')
if [ "$SIM" = "iverilog" ]; then
    BIN="$REPLAY_DIR/obj/dme_klr_replay${DBG_TAG:+_$DBG_TAG}.vvp"
    DRIVER="$REPLAY_DIR/replay_driver.v"
else
    [ ${#EXTRA_DEFS[@]} -gt 0 ] && { echo "  ${EXTRA_DEFS[*]} needs --iverilog (as in v_run_dashboard_tests.sh)"; exit 2; }
    BIN="$REPLAY_DIR/obj/dme_klr_replay"
    FST=0; KEEP_VCD=0     # see the Output note above
    DRIVER="$REPLAY_DIR/replay_main.cpp"
fi
# The ROM choice is baked in, so a different one forces a rebuild too
ROM_STAMP="$DME_ROM_DIR$DME_ROM_FILE $KLR_ROM_DIR$KLR_ROM_FILE ${DME_ASM_SEL:-} ${KLR_ASM_SEL:-}"
if [ "${REBUILD:-0}" = "1" ] || [ ! -e "$BIN" ] || \
   [ "$(cat "$BIN.rom" 2>/dev/null)" != "$ROM_STAMP" ] || \
   [ -n "$(find "$DRIVER" "$DMEKLR_DIR/bench" "$REPO_DIR/dme/bench" "$REPO_DIR/dme/rtl" \
            "$REPO_DIR/klr/bench" "$REPO_DIR/klr/rtl" -newer "$BIN" -name '*.[vc]*' 2>/dev/null | head -1)" ]; then
    echo "  Building $BIN ($SIM)"
    mkdir -p "$REPLAY_DIR/obj"
    cd "$DMEKLR_DIR"
    if [ "$SIM" = "iverilog" ]; then
        iverilog -g2012 -o "$BIN" -f files_cl \
            -s dme_klr_dashboard_tb -s replay_driver \
            "${DEFINES[@]}" "$DRIVER" > "$OUT_DIR/build.log" 2>&1 \
            || { tail -30 "$OUT_DIR/build.log"; echo "  BUILD FAILED (see $OUT_DIR/build.log)"; exit 1; }
    else
    verilator --cc --exe --build --timing -j 0 \
        -O3 --x-assign fast --x-initial fast --noassert \
        -CFLAGS -O2 \
        --Mdir "$REPLAY_DIR/obj" -o dme_klr_replay \
        -f files_cl \
        --top-module dme_klr_dashboard_tb \
        -DVLT_SIM "${DEFINES[@]}" \
        -Wno-fatal -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
        -Wno-REDEFMACRO -Wno-DEFOVERRIDE -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-MULTIDRIVEN \
        "$DRIVER" > "$OUT_DIR/build.log" 2>&1 \
        || { tail -30 "$OUT_DIR/build.log"; echo "  BUILD FAILED (see $OUT_DIR/build.log)"; exit 1; }
    fi
    echo "$ROM_STAMP" > "$BIN.rom"
fi

# ── Stimulus + expected outputs from the log ──
python3 "$REPLAY_DIR/xlsx_to_stim.py" "$XLSX" "$OUT" "${WINDOW[@]}" "${STIM_ARGS[@]}"

# ── Run (from a scratch dir: the tb drops its hex/vcd dumps in cwd) ──
RUN_DIR="$OUT_DIR/run_$NAME"
rm -rf "$RUN_DIR"; mkdir -p "$RUN_DIR"
WAVE=/dev/null
if [ "$FST" = "1" ] || [ "$KEEP_VCD" = "1" ]; then WAVE="$RUN_DIR/sim.vcd"; fi
echo "  Running → $OUT.log"
if [ "$SIM" = "iverilog" ]; then
    ( cd "$RUN_DIR" && vvp -n "$BIN" "+stim=$OUT.stim.csv" "+warmup_ms=${WARMUP_MS:-3000}" "+fst=$WAVE" ) > "$OUT.log"
else
    ( cd "$RUN_DIR" && "$BIN" "$OUT.stim.csv" "+warmup_ms=${WARMUP_MS:-3000}" "+fst=$WAVE" ) > "$OUT.log"
fi

# ── Waveform: the testbench dumps VCD; convert to FST as run_dashboard_tests.sh does ──
if [ -f "$RUN_DIR/sim.vcd" ]; then
    if [ "$FST" = "1" ]; then
        mkdir -p "$OUT_DIR/fst"
        if command -v vcd2fst >/dev/null; then
            vcd2fst "$RUN_DIR/sim.vcd" "$OUT_DIR/fst/$NAME.fst" >/dev/null 2>&1 \
                && echo "  FST     → $OUT_DIR/fst/$NAME.fst" \
                || echo "  vcd2fst failed; VCD left at $RUN_DIR/sim.vcd"
        else
            echo "  vcd2fst not found (it ships with GTKWave); VCD left at $RUN_DIR/sim.vcd"
            KEEP_VCD=2
        fi
    fi
    if [ "$KEEP_VCD" = "1" ]; then
        mkdir -p "$OUT_DIR/vcd"
        mv "$RUN_DIR/sim.vcd" "$OUT_DIR/vcd/$NAME.vcd" && echo "  VCD     → $OUT_DIR/vcd/$NAME.vcd"
    elif [ "$KEEP_VCD" = "0" ]; then
        rm -f "$RUN_DIR/sim.vcd"
    fi
fi
grep -E "^DME: \[DS\]|^KLR: \[DS\]|^DME: \[PHASE\]|^DME: \[STATUS\]|^KLR: \[STATUS\]|^KLR: \[PHASE\]|^DME: \[SEED\]|^DME: \[WARN\]" \
    "$OUT.log" > "$OUT.dash.log" || true
# The log's own outputs at each row's sim time, for the dashboard's chart overlays
python3 "$REPLAY_DIR/expect_to_dash.py" "$OUT.log" "$OUT.expect.csv" >> "$OUT.dash.log" \
    || echo "  expect_to_dash.py failed; the dash.log has no expected-data overlay"

# ── Compare ──
set +e
python3 "$REPLAY_DIR/check_replay.py" "$OUT.log" "$OUT.expect.csv" \
    --mismatches "$OUT.mismatches.csv" "${CHECK_ARGS[@]}" | tee "$OUT.report.txt"
exit "${PIPESTATUS[0]}"
