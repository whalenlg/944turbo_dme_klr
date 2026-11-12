#!/usr/bin/env bash
# ============================================================
#  install_macos.sh — install the DME+KLR toolchain on macOS (Homebrew)
#
#  Installs everything the repo's build, regression, live-sim bridge,
#  Python scripts and dashboard need:
#    - Xcode Command Line Tools: clang/clang++ (C++20), make, git
#    - Homebrew, if it isn't installed (asks first)
#    - brew: verilator, icarus-verilog, node, python
#    - GTKWave, built from source into <repo>/gtkwave (Homebrew no longer
#      has it): the GTK libraries and meson from brew, then GTKWave at a
#      pinned commit of github.com/gtkwave/gtkwave. About 5 minutes.
#    - a Python venv at <repo>/944venv with install/requirements.txt
#      (openpyxl, pandas, matplotlib, numpy)
#  then runs install/check_toolchain.sh and install/smoke_test.sh (the
#  KLR regression on Icarus Verilog and warm_idle_5s on Verilator).
#  Safe to run again: anything already installed is left as it is (use
#  --upgrade to update it).
#
#  Usage:  install/install_macos.sh [options]
#    --upgrade          brew upgrade the formulae that are already installed
#    --with-dashboard   also clone whalenlg/dme-dashboard into <repo>/dashboard
#                       and run npm install there (to run the page locally)
#    --no-gtkwave       skip GTKWave (only needed to view waveforms)
#    --rebuild-gtkwave  build GTKWave again even if it's already installed
#                       (GTKWAVE_REF=<commit or tag> builds another version)
#    --skip-tests       don't run the smoke tests at the end (they take a
#                       few minutes, mostly the Verilator compile)
#    -y, --yes          don't ask before installing Homebrew
#    -n, --dry-run      print the commands without running them
#    -h, --help         this text
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

UPGRADE=0; DASHBOARD=0; GTKWAVE=1; GTKWAVE_REBUILD=0; TESTS=1; YES=0; DRY=0
for _arg in "$@"; do
    case "$_arg" in
        --upgrade)        UPGRADE=1 ;;
        --with-dashboard) DASHBOARD=1 ;;
        --no-gtkwave)     GTKWAVE=0 ;;
        --rebuild-gtkwave) GTKWAVE_REBUILD=1 ;;
        --skip-tests)     TESTS=0 ;;
        -y|--yes)         YES=1 ;;
        -n|--dry-run)     DRY=1 ;;
        *) echo "install_macos.sh: unknown option '$_arg' (see --help)" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }

[ "$(uname -s)" = Darwin ] || die "this script is for macOS; on Arch Linux use install/install_arch.sh"

# ── 1. Xcode Command Line Tools (clang++, make, git) ──────────────────────
step "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
    echo "installed at $(xcode-select -p)"
else
    run xcode-select --install || true
    [ "$DRY" = 1 ] || die "finish the Command Line Tools install in the window that opened, then run this script again"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────
step "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
    for _b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$_b" ] && eval "$("$_b" shellenv)" && break
    done
fi
if command -v brew >/dev/null 2>&1; then
    echo "$(brew --version | head -1) at $(brew --prefix)"
else
    if [ "$YES" != 1 ] && [ "$DRY" != 1 ]; then
        printf 'Homebrew is not installed. Install it now from https://brew.sh? [y/N] '
        read -r _ans
        case "$_ans" in y|Y|yes|YES) ;; *) die "Homebrew is required; install it from https://brew.sh and run this again" ;; esac
    fi
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ "$DRY" != 1 ]; then
        for _b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [ -x "$_b" ] && eval "$("$_b" shellenv)" && break
        done
        command -v brew >/dev/null 2>&1 || die "Homebrew installed but brew isn't on PATH; open a new terminal and run this again"
        echo "Add Homebrew to your shell: see the 'Next steps' the installer printed above."
    fi
fi

# ── 3. Formulae ───────────────────────────────────────────────────────────
#   verilator       Verilator >= 5.038: v_run_dashboard_tests.sh, live/build_live.sh
#   icarus-verilog  iverilog + vvp: run_dashboard_tests.sh, the i8048/i8051 regressions
#   node            Node.js + npm: live/bridge.mjs, the dashboard
#   python          Python 3 for the venv below
step "Homebrew formulae"
FORMULAE=(verilator icarus-verilog node python)
for f in "${FORMULAE[@]}"; do
    if [ "$DRY" != 1 ] && brew list --formula "$f" >/dev/null 2>&1; then
        if [ "$UPGRADE" = 1 ]; then run brew upgrade "$f" || true
        else echo "$f: already installed ($(brew list --versions "$f" | cut -d' ' -f2-))"; fi
    else
        run brew install "$f"
    fi
done
# ── 3b. GTKWave (optional: viewing .vcd / .fst waveforms) ────────────────
#   Homebrew dropped both its gtkwave formula and cask, and the old
#   gtkwave.app from SourceForge doesn't run on current macOS. So it is
#   built from source the way GTKWave's own macOS CI does it: GTK 3/4 and
#   meson from Homebrew, flex/gperf from the Command Line Tools. It goes in
#   <repo>/gtkwave (git-ignored, no sudo); `source setup` puts its bin/ on
#   PATH. That gives gtkwave plus vcd2fst / fst2vcd.
#   GTKWAVE_REF pins the upstream commit (GTKWave 4 development branch,
#   2026-11-03); set it in the environment to build another commit or tag.
GTKWAVE_URL="https://github.com/gtkwave/gtkwave.git"
GTKWAVE_REF="${GTKWAVE_REF:-e40ba7937336824f12f7db870ea36f6f090dd90d}"
GTKWAVE_DIR="$REPO_DIR/gtkwave"
GTKWAVE_DEPS=(meson ninja pkg-config gtk+3 gtk4 gtk-mac-integration json-glib
              desktop-file-utils shared-mime-info librsvg)

build_gtkwave() {
    local src="$GTKWAVE_DIR/src" bld="$GTKWAVE_DIR/src/build" d
    for d in "${GTKWAVE_DEPS[@]}"; do
        if [ "$DRY" != 1 ] && brew list --formula "$d" >/dev/null 2>&1; then
            echo "$d: already installed"
        else
            run brew install "$d" || return 1
        fi
    done
    if [ ! -d "$src/.git" ]; then
        run mkdir -p "$GTKWAVE_DIR" || return 1
        run git clone "$GTKWAVE_URL" "$src" || return 1
    else
        run git -C "$src" fetch origin || return 1
    fi
    run git -C "$src" -c advice.detachedHead=false checkout --force "$GTKWAVE_REF" || return 1
    run rm -rf "$bld"
    # introspection and tests are off: neither is needed to view waveforms,
    # and the tests add a few minutes. The prefix isn't /usr, so meson sets
    # an rpath and the binaries find libgtkwave without DYLD_LIBRARY_PATH.
    run meson setup "$bld" "$src" --prefix="$GTKWAVE_DIR" --buildtype=release \
        -Dintrospection=false -Dtests=false -Dupdate_mime_database=false || return 1
    run meson compile -C "$bld" || return 1
    run meson install -C "$bld" || return 1
    [ "$DRY" = 1 ] || "$GTKWAVE_DIR/bin/gtkwave" --version 2>/dev/null | grep -m1 GTKWave || true
}

if [ "$GTKWAVE" = 1 ]; then
    step "GTKWave (built from source into $GTKWAVE_DIR)"
    if [ "$GTKWAVE_REBUILD" != 1 ] && [ -x "$GTKWAVE_DIR/bin/gtkwave" ]; then
        echo "gtkwave: already built at $GTKWAVE_DIR/bin/gtkwave (--rebuild-gtkwave builds it again)"
    elif [ "$GTKWAVE_REBUILD" != 1 ] && command -v gtkwave >/dev/null 2>&1; then
        echo "gtkwave: already installed at $(command -v gtkwave)"
    elif ! build_gtkwave; then
        warn "GTKWave didn't build (output above). It is only needed to view waveforms,"
        warn "so the rest of the install carries on; --rebuild-gtkwave tries again."
    fi
    # so check_toolchain.sh below finds it, as `source setup` will later
    [ -d "$GTKWAVE_DIR/bin" ] && export PATH="$GTKWAVE_DIR/bin:$PATH"
fi

# ── 4. Python venv with the repo's packages ──────────────────────────────
#   Homebrew's Python refuses system-wide pip installs (PEP 668), so the
#   packages go in <repo>/944venv, the venv asm_select.sh already looks for.
step "Python packages (venv at $VENV)"
PY="python3"
[ "$DRY" = 1 ] || PY="$(brew --prefix)/bin/python3"
if [ ! -x "$VENV/bin/python" ]; then
    run "$PY" -m venv "$VENV"
fi
run "$VENV/bin/python" -m pip install --upgrade pip
run "$VENV/bin/python" -m pip install -r "$INSTALL_DIR/requirements.txt"

# ── 5. Dashboard (optional) ──────────────────────────────────────────────
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

# ── 6. Check ──────────────────────────────────────────────────────────────
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

cat <<EOF

Done. In each new terminal, before running the repo's scripts (they call
python3), activate the Python venv and set the output folder:

    source $REPO_DIR/setup

Build output and logs go to \$DMEKLR_TMP, by default $(cd "$REPO_DIR/.." && pwd)/tmp
(set DMEKLR_TMP to put them elsewhere; see docs/USER_MANUAL.md, section 1).

Then, for example:
    cd $REPO_DIR/klr && ./run_klr_regression
    cd $REPO_DIR/dme_klr && ./v_run_dashboard_tests.sh warm_idle
    cd $REPO_DIR/dme_klr/live && ./build_live.sh && node bridge.mjs
EOF
