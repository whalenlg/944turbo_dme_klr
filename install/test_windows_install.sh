#!/usr/bin/env bash
# ============================================================
#  test_windows_install.sh — check a Windows (MSYS2 UCRT64) install
#
#  Run in an MSYS2 UCRT64 shell after install/install_windows.ps1 (or
#  install_msys2.sh) has finished, with its smoke tests. Each step runs in
#  a new login shell, as a new terminal would:
#    1. source setup + install/check_toolchain.sh
#    2. iverilog smoke test:   checks the KLR regression's output
#    3. Verilator smoke test:  checks warm_idle_5s's dashboard log
#    4. live simulator build:  dme_klr/live/build_live.sh, then runs it
#                              to 200 ms on stdin commands
#    5. live bridge:           node bridge.mjs runs the sim, and a client
#                              on /events sees it pause at 200 ms after
#                              POST /cmd "until 200"
#    6. GTKWave: reads the KLR regression's .fst (fst2vcd) and opens it
#  then prints a PASS/FAIL line per step. Exits 0 only when all pass.
#  .github/workflows/windows-install.yml runs it on a clean
#  windows-latest runner after install_windows.ps1.
#
#  Usage:  install/test_windows_install.sh [--no-gtkwave] [--logdir DIR]
#  Logs go to <checkout>/../tmp/windows-install-test/ by default.
# ============================================================

for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -uo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$INSTALL_DIR/.." && pwd)"
GTKWAVE=1; LOGDIR="$REPO_DIR/../tmp/windows-install-test"
while [ $# -gt 0 ]; do
    case "$1" in
        --no-gtkwave) GTKWAVE=0 ;;
        --logdir)     LOGDIR="${2:?--logdir needs a folder}"; shift ;;
        *) echo "test_windows_install.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done
mkdir -p "$LOGDIR"; LOGDIR="$(cd "$LOGDIR" && pwd)"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Helpers the steps run (in their own login shells, so written to files)
cat > "$LOGDIR/live_smoke.sh" <<'SMOKE'
exe="$1"
coproc SIM { "$exe" +vcd=NUL +snapdir="$DMEKLR_TMP/win-test-snaps" 2>&1; }
echo "until 200" >&"${SIM[1]}"
ok=0
while IFS= read -t 180 -r line <&"${SIM[0]}"; do
    line="${line%$'\r'}"
    case "$line" in SIM:*) echo "$line" ;; esac
    case "$line" in *"[STATE] paused"*"reason=until"*) ok=1; break ;; esac
done
echo quit >&"${SIM[1]}" 2>/dev/null
sleep 1; kill "$SIM_PID" 2>/dev/null; wait "$SIM_PID" 2>/dev/null
[ "$ok" = 1 ] && echo "live sim ran to 200 ms" || { echo "live sim didn't reach 200 ms"; exit 1; }
SMOKE

cat > "$LOGDIR/bridge_smoke.sh" <<'SMOKE'
port=18951
events="$DMEKLR_TMP/win-test-bridge.events"
rm -f "$events"
node dme_klr/live/bridge.mjs --port $port --snapdir "$DMEKLR_TMP/win-test-bridge-snaps" &
bridge=$!
trap 'kill $bridge $curl 2>/dev/null; taskkill //F //IM dme_klr_live.exe >/dev/null 2>&1' EXIT
for _ in $(seq 60); do curl -s -o /dev/null "http://127.0.0.1:$port/events" -m 1; [ $? -ne 7 ] && break; sleep 1; done
curl -sN "http://127.0.0.1:$port/events" > "$events" &
curl=$!
# Wait for the sim to come up (it prints SIM: lines when it starts)
for _ in $(seq 120); do grep -q '^data: SIM:' "$events" 2>/dev/null && break; sleep 1; done
curl -s -X POST --data 'until 200' "http://127.0.0.1:$port/cmd" -w 'POST /cmd: %{http_code}\n'
ok=0
for _ in $(seq 180); do
    grep -q 'STATE\] paused.*reason=until' "$events" && { ok=1; break; }
    sleep 1
done
grep -m5 '^data: SIM:' "$events"
grep -m1 'STATE\] paused.*reason=until' "$events"
[ "$ok" = 1 ] && echo "bridge: sim paused at 200 ms" || { echo "bridge: no pause at 200 ms"; tail -n 20 "$events"; exit 1; }
SMOKE

declare -a RESULTS=()
FAILS=0
check() {   # check NAME COMMAND: run COMMAND in a new UCRT64 login shell
    local name="$1"; shift
    local log="$LOGDIR/$(echo "$name" | tr -cs 'A-Za-z0-9._-' '_').log"
    local t0=$SECONDS
    step "$name"
    echo "+ $*"
    MSYSTEM=UCRT64 CHERE_INVOKING=1 bash -lc "cd '$REPO_DIR' && $*" > "$log" 2>&1
    local rc=$?
    tail -n 40 "$log"
    # The compilers' warnings can push the error out of that tail
    [ $rc -eq 0 ] || { echo "--- error lines:"; grep -m 20 -E 'error|Error|undefined reference' "$log"; }
    local dt=$((SECONDS - t0))
    if [ $rc -eq 0 ]; then RESULTS+=("PASS  ${name}  (${dt}s)")
    else RESULTS+=("FAIL  ${name}  (exit $rc, ${dt}s; log: $log)"); FAILS=$((FAILS + 1)); fi
    return $rc
}

step "System: $(uname -a), MSYSTEM=${MSYSTEM:-}"
command -v curl >/dev/null 2>&1 || pacman -S --needed --noconfirm curl >/dev/null   # for the bridge step

check "source setup + check_toolchain" \
    'source ./setup && echo "DMEKLR_REPO=$DMEKLR_REPO DMEKLR_TMP=$DMEKLR_TMP" && which python3 && install/check_toolchain.sh'
check "iverilog: KLR regression" \
    'source ./setup && l="$DMEKLR_TMP/install_smoke/klr.log" && ls -l "$l" "$DMEKLR_TMP/klr/fst/" \
     && n=$(grep -c "PASS \[" "$l") && echo "$n checks passed" && [ "$n" -gt 0 ] \
     && ! grep -q "FAIL \[" "$l"'
check "verilator: warm_idle_5s" \
    'source ./setup && verilator --version && ls -l "$DMEKLR_TMP/install_smoke/warm_idle_5s.log" \
     && f="$DMEKLR_TMP/dme_klr/v_dash_logs/warm_idle_5s.dash.log" && ls -l "$f" \
     && n=$(grep -c "\[DS\]" "$f") && echo "$n [DS] snapshot lines" && [ "$n" -gt 10 ]'
if check "verilator: live build" \
    "source ./setup && cd dme_klr/live && ./build_live.sh && ls -l obj/dme_klr_live.exe \
     && bash '$LOGDIR/live_smoke.sh' obj/dme_klr_live"; then
    check "node: live bridge" "source ./setup && node --version && bash '$LOGDIR/bridge_smoke.sh'"
fi
if [ "$GTKWAVE" = 1 ]; then
    # Still running after 15 s (timeout's 124) means it loaded and stayed up
    check "gtkwave: open the KLR waveform" \
        'source ./setup && f="$DMEKLR_TMP/klr/fst/i8048_regression_tb.fst" && ls -l "$f" \
         && command -v gtkwave && fst2vcd "$f" | grep -m1 -q "enddefinitions" && echo "fst2vcd: reads OK" \
         && { timeout 15 gtkwave "$f"; rc=$?; taskkill //F //IM gtkwave.exe >/dev/null 2>&1; \
              echo "gtkwave exit $rc (124 = still running at 15 s)"; [ $rc -eq 124 ]; }'
fi

echo
echo "════════ Windows install test: $(date -u +%Y-%m-%dT%H:%MZ) ════════"
pacman -Q mingw-w64-ucrt-x86_64-{verilator,iverilog,gtkwave,nodejs,python,gcc} 2>/dev/null | sed 's/^/  /'
for r in "${RESULTS[@]}"; do echo "  $r"; done
if [ "$FAILS" -eq 0 ]; then echo "All steps passed."; exit 0; fi
echo "$FAILS step(s) failed."
exit 1
