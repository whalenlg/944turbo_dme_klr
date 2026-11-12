#!/usr/bin/env bash
# ============================================================
#  install_arch.sh — install the DME+KLR toolchain on Arch Linux (pacman)
#
#  Installs everything the repo's build, regression, live-sim bridge,
#  Python scripts and dashboard need, all from the official repos:
#    - base-devel (gcc/g++ with C++20, make), git
#    - verilator, iverilog, gtkwave
#    - nodejs, npm
#    - python with python-openpyxl, python-pandas, python-matplotlib,
#      python-numpy (the packages in install/requirements.txt)
#  then runs install/check_toolchain.sh and install/smoke_test.sh (the
#  KLR regression on Icarus Verilog and warm_idle_5s on Verilator).
#  Safe to run again: pacman --needed skips what is already installed
#  and up to date.
#
#  Usage:  install/install_arch.sh [options]
#    --venv             put the Python packages in a venv at <repo>/944venv
#                       (pip, install/requirements.txt) instead of pacman
#    --with-dashboard   also clone whalenlg/dme-dashboard into <repo>/dashboard
#                       and run npm install there (to run the page locally)
#    --no-gtkwave       skip GTKWave (only needed to view waveforms)
#    --skip-tests       don't run the smoke tests at the end (they take a
#                       few minutes, mostly the Verilator compile)
#    -y, --yes          pass --noconfirm to pacman
#    -n, --dry-run      print the commands without running them
#    -h, --help         this text
#
#  Runs pacman through sudo unless it is already running as root.
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
        *) echo "install_arch.sh: unknown option '$_arg' (see --help)" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }

[ "$DRY" = 1 ] || command -v pacman >/dev/null 2>&1 \
    || die "pacman not found; this script is for Arch Linux (on macOS use install/install_macos.sh)"

SUDO=()
[ "$(id -u)" -eq 0 ] || SUDO=(sudo)
NOCONFIRM=()
[ "$YES" = 1 ] && NOCONFIRM=(--noconfirm)

# ── Packages ──────────────────────────────────────────────────────────────
#   base-devel   gcc/g++ (C++20 for Verilator --timing), make, and the rest
#   git          clone/pull (run_all.sh does git pull), the dashboard clone
#   verilator    >= 5.038: v_run_dashboard_tests.sh, live/build_live.sh
#   iverilog     iverilog + vvp: run_dashboard_tests.sh, i8048/i8051 regressions
#   gtkwave      viewing .vcd / .fst waveforms (optional)
#   nodejs, npm  live/bridge.mjs (Node 18+), the dashboard
#   python + python-*: the repo's Python scripts
PKGS=(base-devel git verilator iverilog nodejs npm python)
[ "$GTKWAVE" = 1 ] && PKGS+=(gtkwave)
if [ "$USE_VENV" = 1 ]; then
    PKGS+=(python-pip)
else
    PKGS+=(python-openpyxl python-pandas python-matplotlib python-numpy)
fi

step "pacman packages"
# -Syu, not -Sy: Arch doesn't support partial upgrades
run "${SUDO[@]}" pacman -Syu --needed "${NOCONFIRM[@]}" "${PKGS[@]}"

# Arch tracks Verilator releases closely, but warn if the repo's is too old
if [ "$DRY" != 1 ] && command -v verilator >/dev/null 2>&1; then
    _v="$(verilator --version | awk '{print $2}')"
    if [ "$(printf '%s\n%s\n' "$MIN_VERILATOR" "$_v" | sort -V | head -1)" != "$MIN_VERILATOR" ]; then
        warn "verilator $_v is older than $MIN_VERILATOR; build a newer one from"
        warn "https://verilator.org/guide/latest/install.html (or the AUR's verilator-git)"
    fi
fi

# ── Python venv (only with --venv) ───────────────────────────────────────
if [ "$USE_VENV" = 1 ]; then
    step "Python packages (venv at $VENV)"
    [ -x "$VENV/bin/python" ] || run python3 -m venv "$VENV"
    run "$VENV/bin/python" -m pip install --upgrade pip
    run "$VENV/bin/python" -m pip install -r "$INSTALL_DIR/requirements.txt"
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
#   The KLR CPU regression on Icarus Verilog and warm_idle_5s on Verilator,
#   in the environment `source setup` gives a new terminal
if [ "$TESTS" = 1 ]; then
    step "Smoke tests: KLR regression (iverilog), warm_idle_5s (Verilator)"
    if [ "$DRY" = 1 ]; then
        echo "+ $INSTALL_DIR/smoke_test.sh"
    elif ! "$INSTALL_DIR/smoke_test.sh"; then
        die "the tools are installed, but a smoke test failed (logs above); run install/smoke_test.sh again once it is fixed"
    fi
fi

echo
echo "Done."
[ "$USE_VENV" = 1 ] && printf 'In each new terminal, first:  source %s/setup\n' "$REPO_DIR"
cat <<EOF
For example:
    cd $REPO_DIR/klr && ./run_klr_regression
    cd $REPO_DIR/dme_klr && ./v_run_dashboard_tests.sh warm_idle
    cd $REPO_DIR/dme_klr/live && ./build_live.sh && node bridge.mjs
EOF
