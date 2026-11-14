#!/usr/bin/env bash
# ============================================================
#  test_lite.sh — check a built lite package on this machine
#
#  Starts the package's run_lite.sh (its bridge and prebuilt simulator)
#  from a copy outside the checkout, then checks, as the dashboard would:
#    - the bridge serves the DME and KLR listings (/asm/dme, /asm/klr)
#    - the sim runs and pauses at 200 ms after POST /cmd "until 200"
#    - the listings follow the ROM in the EPROM (SIM: [ASM] lines)
#    - COMPARE IMAGES compares two packaged ROM images (rom_compare.py)
#    - the bridge serves the packaged dashboard (dashboard/) at its root,
#      every file the page loads is there, and nothing in it loads from the
#      internet; with a Chrome (or Edge) found, or named in CHROME, the
#      page renders in it with every host but 127.0.0.1 unreachable
#    - run_tests.py runs a regression test (cut to 300 ms) on the packaged
#      testbench and checks it
#    - TEST LOAD: a TEST row (test_snap.py add) loads on the packaged
#      shared test build and pauses at its time
#    - no Verilog, C++ or simulator build scripts are in the package
#    - with --clean: this machine has no Verilator or Icarus Verilog on the
#      PATH and no simulator source next to the package,
#      so nothing but the package can have made the checks pass (the CI's
#      clean-runner jobs, and install/test_macos_vm.sh --lite)
#
#  Needs bash, curl, Node.js and Python 3 (python3, python or py; or set
#  PYTHON). It only needs this one file, not the rest of the checkout.
#
#  Usage:  lite/test_lite.sh <package dir or .tar.gz/.zip> [--port N] [--clean]
#  Exit 0 when every check passes.
# ============================================================

for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -uo pipefail
SRC="${1:?usage: test_lite.sh <package dir or archive> [--port N] [--clean]}"
shift
PORT=18951; CLEAN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --port)  PORT="$2"; shift ;;
        --clean) CLEAN=1 ;;
        *) echo "test_lite.sh: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done
case "$SRC" in /*|[A-Za-z]:*) ;; *) SRC="$PWD/$SRC" ;; esac

# Python 3, as the bridge finds it (a python.org install on Windows has no python3)
PY="${PYTHON:-}"
if [ -z "$PY" ]; then
    for c in python3 python py; do
        [ "$("$c" -c 'import sys; print(sys.version_info[0])' 2>/dev/null | tr -d '\r')" = 3 ] && { PY="$c"; break; }
    done
fi
[ -n "$PY" ] || { echo "test_lite.sh: no Python 3 (python3, python or py) on the PATH" >&2; exit 2; }

WORK="$(mktemp -d)"
case "$SRC" in
    *.tar.gz) tar -xzf "$SRC" -C "$WORK" ;;
    *.zip)    "$PY" -m zipfile -e "$SRC" "$WORK"
              chmod +x "$WORK"/*/run_lite.sh "$WORK"/*/dme_klr/live/obj/dme_klr_live* 2>/dev/null ;;
    *)        cp -R "$SRC" "$WORK/" ;;
esac
PKG="$(find "$WORK" -mindepth 1 -maxdepth 1 -type d | head -1)"
echo "package: $PKG"

FAILS=0
check() { if [ "$1" = 0 ]; then echo "  PASS  $2"; else echo "  FAIL  $2"; FAILS=$((FAILS + 1)); fi; }

if [ "$CLEAN" = 1 ]; then
    tools="$(for t in verilator verilator_bin iverilog vvp; do command -v "$t" >/dev/null 2>&1 && printf '%s ' "$t"; done)"
    [ -z "$tools" ]; check $? "clean machine: no Verilator or Icarus Verilog on the PATH${tools:+ (found: $tools)}"
    near="$(find "$(dirname "$SRC")" -maxdepth 4 \( -name '*.v' -o -name '*.sv' -o -name 'build_live.sh' \) 2>/dev/null | head -3)"
    [ -z "$near" ]; check $? "clean machine: no simulator source next to the package${near:+: $near}"
fi

LOG="$WORK/bridge.log"; EVENTS="$WORK/events.txt"
"$PKG/run_lite.sh" --port "$PORT" > "$LOG" 2>&1 &
BRIDGE=$!
CURL=""
cleanup() {
    [ -n "$CURL" ] && kill "$CURL" 2>/dev/null
    kill "$BRIDGE" 2>/dev/null
    pkill -f "$PKG/dme_klr/live/obj/" 2>/dev/null
    taskkill //F //IM dme_klr_live.exe >/dev/null 2>&1
    true
}
trap cleanup EXIT
H=(-H "Origin: http://localhost")
for _ in $(seq 60); do curl -s -o /dev/null -m 1 "http://127.0.0.1:$PORT/events" "${H[@]}"; [ $? -ne 7 ] && break; sleep 1; done
curl -sN "${H[@]}" "http://127.0.0.1:$PORT/events" > "$EVENTS" &
CURL=$!

for _ in $(seq 120); do grep -q '^data: SIM: \[ASM\] klr' "$EVENTS" 2>/dev/null && break; sleep 1; done
for cpu in dme klr; do
    n="$(curl -s "${H[@]}" "http://127.0.0.1:$PORT/asm/$cpu" | grep -o '"a":' | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 1000 ]; check $? "/asm/$cpu listing ($n lines)"
    grep -q "^data: SIM: \[ASM\] $cpu .*match=content" "$EVENTS"; check $? "$cpu listing follows the loaded ROM"
done

# The dashboard, offline: index.html and every asset it names, from the bridge
idx="$(curl -s -m 10 "http://127.0.0.1:$PORT/")"
case "$idx" in *'<div id="root">'*) r=0 ;; *) r=1 ;; esac
check $r "the bridge serves the packaged dashboard at /"
bad=""; n=0
for a in $(printf '%s' "$idx" | grep -oE '(src|href)="/assets/[^"]+"' | sed -E 's/^[a-z]+="//; s/"$//'); do
    n=$((n + 1))
    c="$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://127.0.0.1:$PORT$a")"
    [ "$c" = 200 ] || bad="$bad $a($c)"
done
[ "$n" -gt 0 ] && [ -z "$bad" ]; check $? "its $n scripts and stylesheets load from the bridge${bad:+:$bad}"
ext="$(grep -rlE 'fonts\.googleapis|fonts\.gstatic|cdn\.jsdelivr|unpkg\.com|cdnjs' "$PKG/dashboard" 2>/dev/null | head -3)"
[ -d "$PKG/dashboard" ] && [ -z "$ext" ]; check $? "the dashboard loads nothing from the internet${ext:+: $ext}"
if [ -z "${CHROME:-}" ]; then
    for c in google-chrome google-chrome-stable chromium chromium-browser \
             "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
             "/c/Program Files/Google/Chrome/Application/chrome.exe" \
             "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
        command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }
    done
fi
if [ -n "${CHROME:-}" ]; then
    # No DNS for anything but 127.0.0.1: as on a machine with no connection
    DOM="$WORK/dom.html"
    "$CHROME" --headless=new --disable-gpu --no-first-run --no-default-browser-check \
        --user-data-dir="$(cygpath -w "$WORK/chrome-profile" 2>/dev/null || echo "$WORK/chrome-profile")" --host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1" \
        --timeout=8000 --dump-dom "http://127.0.0.1:$PORT/?live" > "$DOM" 2>/dev/null &
    cpid=$!
    for _ in $(seq 60); do kill -0 "$cpid" 2>/dev/null || break; sleep 1; done
    kill "$cpid" 2>/dev/null
    grep -q 'SIMULATION DEBUG CONSOLE' "$DOM"; check $? "the dashboard renders offline in $(basename "$CHROME")"
else
    echo "  (no Chrome or Edge found: skipped the browser check; set CHROME to run it)"
fi

# COMPARE IMAGES (rom_compare.py): the packaged KLR images, 86 against 87
cmp="$(curl -s -m 120 -w ' HTTP%{http_code}' "${H[@]}" "http://127.0.0.1:$PORT/compare/klr?a=86KLR_951.mem&b=87KLR_951.mem")"
case "$cmp" in "{"*' HTTP200') r=0 ;; *) r=1 ;; esac
check $r "COMPARE IMAGES: 86 vs 87 KLR (${cmp##* })"

curl -s -o /dev/null "${H[@]}" -X POST --data 'until 200' "http://127.0.0.1:$PORT/cmd"
ok=1
for _ in $(seq 180); do grep -q 'STATE\] paused.*reason=until' "$EVENTS" && { ok=0; break; }; sleep 1; done
check $ok "sim runs and pauses at 200 ms"
grep -q '^data: DME: ' "$EVENTS"; check $? "DME output reaches the dashboard"

# The regression runner, on the packaged testbench
RT_OUT="$WORK/run_tests.txt"
( cd "$PKG" && DMEKLR_TMP="$PKG/data" "$PY" run_tests.py -j 2 --sim-ms 300 warm_idle_5s cl_warm_idle ) > "$RT_OUT" 2>&1
cat "$RT_OUT" | sed 's/^/    /' | cut -c1-200
grep -qE '^Total: 2 ' "$RT_OUT" && ! grep -q 'simulator exited' "$RT_OUT"; check $? "run_tests.py runs and checks two tests"
for t in warm_idle_5s cl_warm_idle; do
    n="$(grep -cE '^(DME: )?\[DS\]' "$PKG/data/dme_klr/v_dash_logs/$t.dash.log" 2>/dev/null)"
    [ "${n:-0}" -ge 2 ]; check $? "$t.dash.log has DS snapshots (${n:-0})"
done

# TEST LOAD: a TEST row at 150 ms, run on the shared test build
( cd "$PKG" && DMEKLR_TMP="$PKG/data" "$PY" dme_klr/live/test_snap.py add cl_warm_idle 150 lite-check --script none ) > /dev/null 2>&1
SNAP_ID="$(ls "$PKG/data/dme_klr/snapshots" 2>/dev/null | grep 'cl_warm_idle-lite-check' | head -1)"
[ -n "$SNAP_ID" ]; check $? "test_snap.py add makes a TEST row (${SNAP_ID:-none})"
if [ -n "$SNAP_ID" ]; then
    code="$(curl -s -o /dev/null -w '%{http_code}' "${H[@]}" -X POST "http://127.0.0.1:$PORT/snapshots/$SNAP_ID/load")"
    [ "$code" = 204 ]; check $? "TEST LOAD starts at once on the packaged build (HTTP $code)"
    ok=1
    for _ in $(seq 180); do grep -q "SIM: \[SNAP\] loaded t_ns=1[45][0-9]* exact=1 dir=$SNAP_ID" "$EVENTS" && { ok=0; break; }; sleep 1; done
    check $ok "the test runs to 150 ms and pauses"
fi

src="$(find "$PKG" \( -name '*.v' -o -name '*.sv' -o -name '*.cpp' -o -name '*.h' -o -name 'build_live.sh' \) | head -3)"
[ -z "$src" ]; check $? "no simulator source in the package${src:+: $src}"

if [ "$FAILS" -ne 0 ]; then
    echo "--- bridge log"; tail -n 40 "$LOG"
    echo "--- events"; tail -n 20 "$EVENTS"
fi
echo "$([ "$FAILS" = 0 ] && echo ALL PASSED || echo "$FAILS FAILED")"
[ "$FAILS" = 0 ]
