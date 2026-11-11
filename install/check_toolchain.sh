#!/usr/bin/env bash
# ============================================================
#  check_toolchain.sh — check that everything the repo needs is installed
#
#  Checks the C++ compiler (C++20, which Verilator --timing needs), make,
#  Verilator (>= 5.038), Icarus Verilog (iverilog + vvp), GTKWave,
#  Node.js (>= 18) and npm, Python 3 with the packages in
#  requirements.txt, and git. Run by install_macos.sh and install_arch.sh
#  when they finish; safe to run on its own at any time.
#
#  Python is checked with this repo's 944venv/bin/python when that venv
#  exists (the one install_macos.sh makes), otherwise with python3. When
#  the venv exists but isn't active in this shell, it says so: the repo's
#  scripts call python3, so they only see the venv's packages once it is
#  activated (source setup, or source 944venv/bin/activate).
#
#  Run it before installing, too: it changes nothing, and shows what is
#  already there and what the install scripts would add.
#
#  Usage:  install/check_toolchain.sh
#  Exit:   0 when every required tool is present (GTKWave is optional),
#          1 otherwise
# ============================================================

for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIN_VERILATOR=5.038
MIN_NODE=18

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi
MISSING=0
ok()   { printf "  ${GREEN}ok${NC}       %-12s %s\n" "$1" "$2"; }
bad()  { printf "  ${RED}MISSING${NC}  %-12s %s\n" "$1" "$2"; MISSING=$((MISSING + 1)); }
opt()  { printf "  ${YELLOW}optional${NC} %-12s %s\n" "$1" "$2"; }

# version_ge A B: true when dotted version A >= B (numeric fields, so
# Verilator's 5.040 vs 5.038 compares 40 against 38). Bash 3.2-safe.
version_ge() {
    local IFS=.
    local -a a b
    read -r -a a <<< "$1"; read -r -a b <<< "$2"
    local i x y
    for i in 0 1 2; do
        x="${a[$i]:-0}"; y="${b[$i]:-0}"
        x="${x//[^0-9]/}"; y="${y//[^0-9]/}"
        x=$((10#${x:-0})); y=$((10#${y:-0}))
        [ "$x" -gt "$y" ] && return 0
        [ "$x" -lt "$y" ] && return 1
    done
    return 0
}

echo "Toolchain check for $REPO_DIR"
echo

# ── C++ compiler, C++20 (Verilator --timing uses coroutines) ─────────────
CXX_BIN="${CXX:-c++}"
if command -v "$CXX_BIN" >/dev/null 2>&1; then
    _tmp="$(mktemp -d)"
    printf '#include <coroutine>\nint main() { return 0; }\n' > "$_tmp/t.cpp"
    if "$CXX_BIN" -std=c++20 -o "$_tmp/t" "$_tmp/t.cpp" >/dev/null 2>&1; then
        ok "c++" "$("$CXX_BIN" --version 2>/dev/null | head -1)"
    else
        bad "c++" "$CXX_BIN can't build C++20 coroutines (Verilator --timing needs them)"
    fi
    rm -rf "$_tmp"
else
    bad "c++" "no C++ compiler (macOS: xcode-select --install, Arch: base-devel)"
fi

if command -v make >/dev/null 2>&1; then
    ok "make" "$(make --version 2>/dev/null | head -1)"
else
    bad "make" "needed by Verilator's generated build"
fi

# ── Verilator ─────────────────────────────────────────────────────────────
if command -v verilator >/dev/null 2>&1; then
    _v="$(verilator --version 2>/dev/null | awk '{print $2}')"
    if version_ge "$_v" "$MIN_VERILATOR"; then
        ok "verilator" "$_v"
    else
        bad "verilator" "$_v is older than $MIN_VERILATOR"
    fi
else
    bad "verilator" ">= $MIN_VERILATOR"
fi

# ── Icarus Verilog ────────────────────────────────────────────────────────
if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
    ok "iverilog" "$(iverilog -V 2>&1 | head -1 | sed 's/Icarus Verilog version //')"
else
    bad "iverilog" "iverilog and vvp (Icarus Verilog >= 12)"
fi

# ── GTKWave (optional: only for looking at .vcd/.fst waveforms) ───────────
if command -v gtkwave >/dev/null 2>&1; then
    ok "gtkwave" "$(command -v gtkwave)"
elif [ -d /Applications/gtkwave.app ] || [ -d "$HOME/Applications/gtkwave.app" ]; then
    ok "gtkwave" "gtkwave.app"
else
    opt "gtkwave" "not found; only needed to view waveforms"
fi

# ── Node.js (live-sim bridge, dashboard) ──────────────────────────────────
if command -v node >/dev/null 2>&1; then
    _n="$(node --version 2>/dev/null | sed 's/^v//')"
    if version_ge "$_n" "$MIN_NODE"; then ok "node" "$_n"; else bad "node" "$_n is older than $MIN_NODE"; fi
else
    bad "node" ">= $MIN_NODE (dme_klr/live/bridge.mjs)"
fi
if command -v npm >/dev/null 2>&1; then
    ok "npm" "$(npm --version 2>/dev/null)"
else
    bad "npm" "needed to run the dashboard locally"
fi

# ── Python and its packages ───────────────────────────────────────────────
PY=python3
[ -x "$REPO_DIR/944venv/bin/python" ] && PY="$REPO_DIR/944venv/bin/python"
if command -v "$PY" >/dev/null 2>&1; then
    ok "python3" "$("$PY" --version 2>&1 | awk '{print $2}')  ($PY)"
    for _m in openpyxl pandas matplotlib numpy; do
        _ver="$("$PY" -c "import $_m; print($_m.__version__)" 2>/dev/null)"
        if [ -n "$_ver" ]; then ok "  $_m" "$_ver"; else bad "  $_m" "python package"; fi
    done
else
    bad "python3" "Python 3"
fi
VENV_INACTIVE=0
if [ "$PY" != python3 ] && [ "${VIRTUAL_ENV:-}" != "$REPO_DIR/944venv" ]; then
    VENV_INACTIVE=1
    printf "  ${YELLOW}note${NC}     %-12s %s\n" "944venv" "not active in this shell; run: source $REPO_DIR/setup"
fi

if command -v git >/dev/null 2>&1; then
    ok "git" "$(git --version | awk '{print $3}')"
else
    bad "git" ""
fi

echo
if [ "$MISSING" -eq 0 ]; then
    echo -e "${GREEN}Everything required is installed.${NC}"
    if [ "$VENV_INACTIVE" = 1 ]; then
        echo "Activate the venv before running the scripts (in every new terminal):"
        echo "    source $REPO_DIR/setup"
    fi
    exit 0
fi
echo -e "${RED}$MISSING required item(s) missing.${NC} See docs/USER_MANUAL.md, \"Install\"."
exit 1
