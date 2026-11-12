#!/usr/bin/env bash
# ============================================================
#  install_msys2.sh — install the DME+KLR toolchain on Windows (MSYS2 UCRT64)
#
#  Run in an MSYS2 "UCRT64" terminal (install/install_windows.ps1 installs
#  MSYS2 and runs this for you). Installs, all from the MSYS2 repos:
#    - gcc/g++ (C++20), make, git, perl
#    - verilator, iverilog, gtkwave
#    - nodejs (with npm)
#    - python with numpy, pandas, matplotlib, openpyxl (the packages in
#      install/requirements.txt)
#  then runs install/check_toolchain.sh and install/smoke_test.sh (the
#  KLR regression on Icarus Verilog and warm_idle_5s on Verilator).
#  Safe to run again: pacman --needed skips what is already installed
#  and up to date.
#
#  Usage:  install/install_msys2.sh [options]
#    --venv             also make a Python venv at <repo>/944venv (sees the
#                       pacman packages; pip for anything else you add)
#    --with-dashboard   also clone whalenlg/dme-dashboard into <repo>/dashboard
#                       and run npm install there (to run the page locally)
#    --no-gtkwave       skip GTKWave (only needed to view waveforms)
#    --skip-tests       don't run the smoke tests at the end (they take a
#                       few minutes, mostly the Verilator compile)
#    -y, --yes          pass --noconfirm to pacman
#    -n, --dry-run      print the commands without running them
#    -h, --help         this text
#
#  The tools are native Windows programs (the mingw-w64-ucrt-x86_64-*
#  packages), so they work from the UCRT64 terminal; `source setup` there
#  as on Linux and macOS.
# ============================================================

for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$INSTALL_DIR/.." && pwd)"
VENV="$REPO_DIR/944venv"
DASHBOARD_URL="https://github.com/whalenlg/dme-dashboard.git"
MIN_VERILATOR=5.038

USE_VENV=0; DASHBOARD=0; GTKWAVE=1; TESTS=1; YES=0; DRY=0
for _arg in "$@"; do
    case "$_arg" in
        --venv)           USE_VENV=1 ;;
        --with-dashboard) DASHBOARD=1 ;;
        --no-gtkwave)     GTKWAVE=0 ;;
        --skip-tests)     TESTS=0 ;;
        -y|--yes)         YES=1 ;;
        -n|--dry-run)     DRY=1 ;;
        *) echo "install_msys2.sh: unknown option '$_arg' (see --help)" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }

if [ "$DRY" != 1 ]; then
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found; run this in an MSYS2 UCRT64 terminal (or use install/install_windows.ps1)"
    [ "${MSYSTEM:-}" = UCRT64 ] \
        || die "MSYSTEM is '${MSYSTEM:-}', not UCRT64: open the \"MSYS2 UCRT64\" terminal (or use install/install_windows.ps1)"
fi

# Verilator's generated makefiles, and make itself, don't cope with spaces
case "$REPO_DIR" in
    *" "*) warn "the checkout's path has a space in it ($REPO_DIR);"
           warn "Verilator's builds will fail there. Clone it somewhere without one, e.g. C:\\dmeklr" ;;
esac

NOCONFIRM=()
[ "$YES" = 1 ] && NOCONFIRM=(--noconfirm)

# ── Packages ──────────────────────────────────────────────────────────────
#   gcc           g++ with C++20 (Verilator --timing uses coroutines)
#   make, perl    Verilator's build (its front end is a perl script) and
#                 generated makefiles; MSYS2's own make runs them fine
#   git           clone/pull, the dashboard clone
#   verilator     >= 5.038: v_run_dashboard_tests.sh, live/build_live.sh
#   iverilog      iverilog + vvp: run_dashboard_tests.sh, the CPU regressions
#   gtkwave       viewing .vcd / .fst waveforms (optional)
#   nodejs        live/bridge.mjs (Node 18+) and npm, for the dashboard
#   python + python-*: the repo's Python scripts
P=mingw-w64-ucrt-x86_64
PKGS=(git make perl diffutils "$P-gcc" "$P-verilator" "$P-iverilog" "$P-nodejs" "$P-python")
[ "$GTKWAVE" = 1 ] && PKGS+=("$P-gtkwave")
PKGS+=("$P-python-openpyxl" "$P-python-pandas" "$P-python-matplotlib" "$P-python-numpy")
[ "$USE_VENV" = 1 ] && PKGS+=("$P-python-pip")

step "pacman packages"
# -Syu, not -Sy: like Arch, MSYS2 doesn't support partial upgrades. If this
# updates MSYS2's core it may ask to close the terminal: do, then run this again.
run pacman -Syu --needed "${NOCONFIRM[@]}" "${PKGS[@]}"

if [ "$DRY" != 1 ] && command -v verilator >/dev/null 2>&1; then
    _v="$(verilator --version | awk '{print $2}')"
    if [ "$(printf '%s\n%s\n' "$MIN_VERILATOR" "$_v" | sort -V | head -1)" != "$MIN_VERILATOR" ]; then
        warn "verilator $_v is older than $MIN_VERILATOR; run pacman -Syu to update MSYS2"
    fi
fi

# ── Python venv (only with --venv) ───────────────────────────────────────
#   numpy, pandas and matplotlib have no pip wheels for MSYS2's Python (pip
#   would build them from source, slowly), so the venv sees the pacman ones
#   (--system-site-packages) and pip adds only what they don't cover.
#   MSYS2's Python makes venvs with a bin/ folder, like Linux.
if [ "$USE_VENV" = 1 ]; then
    step "Python packages (venv at $VENV)"
    VPY="$VENV/bin/python"
    [ -x "$VPY" ] || run python3 -m venv --system-site-packages "$VENV"
    run "$VPY" -m pip install -r "$INSTALL_DIR/requirements.txt"
    # The repo's scripts call python3; make sure the venv has one
    if [ "$DRY" != 1 ] && [ ! -e "$VENV/bin/python3" ] && [ ! -e "$VENV/bin/python3.exe" ]; then
        cp "$VENV/bin/python.exe" "$VENV/bin/python3.exe"
    fi
fi

# ── Dashboard (optional) ─────────────────────────────────────────────────
if [ "$DASHBOARD" = 1 ]; then
    step "Dashboard (whalenlg/dme-dashboard in $REPO_DIR/dashboard)"
    if [ -d "$REPO_DIR/dashboard/.git" ]; then
        echo "already cloned"
    else
        run git clone "$DASHBOARD_URL" "$REPO_DIR/dashboard"
    fi
    if [ "$DRY" = 1 ]; then echo "+ (cd $REPO_DIR/dashboard && npm install)"
    else (cd "$REPO_DIR/dashboard" && npm install); fi
fi

# ── Check ─────────────────────────────────────────────────────────────────
step "Checking the toolchain"
if [ "$DRY" = 1 ]; then
    echo "+ $INSTALL_DIR/check_toolchain.sh"
else
    "$INSTALL_DIR/check_toolchain.sh" || exit 1
fi

# ── Smoke tests (skip with --skip-tests) ─────────────────────────────────
if [ "$TESTS" = 1 ]; then
    step "Smoke tests: KLR regression (iverilog), warm_idle_5s (Verilator)"
    if [ "$DRY" = 1 ]; then
        echo "+ $INSTALL_DIR/smoke_test.sh"
    elif ! "$INSTALL_DIR/smoke_test.sh"; then
        die "the tools are installed, but a smoke test failed (logs above); run install/smoke_test.sh again once it is fixed"
    fi
fi

echo
echo "Done. In each new MSYS2 UCRT64 terminal, first:"
printf '    source %s/setup\n' "$REPO_DIR"
cat <<EOF
For example:
    cd $REPO_DIR/klr && ./run_klr_regression
    cd $REPO_DIR/dme_klr && ./v_run_dashboard_tests.sh warm_idle
    cd $REPO_DIR/dme_klr/live && ./build_live.sh && node bridge.mjs
EOF
