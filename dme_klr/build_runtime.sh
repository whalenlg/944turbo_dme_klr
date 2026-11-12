#!/bin/bash
# ============================================================
#  build_runtime.sh: build the combined DME+KLR testbench once, with
#  RUNTIME_OPTS, so a single binary runs every regression test.
#
#  A test's options (test_opts.vh) then come from the command line as
#  +X=<n> instead of -DX at compile time; test_opts.py prints them:
#      dme_klr/test_opts.py plusargs warm_idle_5s
#  So do the ROM images and disassembly tables, as the -D flags of the
#  same names: +DMEKLR_REPO=<dir/> +DME_ROM_FILE=<name> +DME_ASM_DIR=<dir/>
#  +KLR_ROM_FILE=<name> +KLR_ASM_DIR=<dir/> (and +DME_ROM_DIR, +KLR_ROM_DIR).
#
#  Two binaries, as the closed-loop tests compile another RPM generator
#  (files_cl, -DCL_MODE):
#      <out>/dme_klr_sim      open-loop tests     (test_opts.py: files: files)
#      <out>/dme_klr_sim_cl   closed-loop tests   (files: files_cl)
#
#  Usage: build_runtime.sh [--out DIR] [--trace] [--jobs N]
#         (default DIR: $DMEKLR_TMP/dme_klr/runtime)
# ============================================================
set -e
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"   # DMEKLR_REPO, DMEKLR_TMP

OUT="$DMEKLR_TMP/dme_klr/runtime"
TRACE=""
JOBS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --out)   OUT="$2"; shift 2 ;;
        --trace) TRACE="--trace"; shift ;;
        --jobs)  JOBS="$2"; shift 2 ;;
        *) echo "build_runtime.sh: unknown option $1" >&2; exit 2 ;;
    esac
done
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
[ -n "$JOBS" ] || JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)

cd "$SCRIPT_DIR"
python3 test_opts.py gen --check   # the generated header matches the tests

build() {   # <file list> <exe name> [extra -D]
    local fl=$1 exe=$2; shift 2
    echo "== $exe ($fl)"
    rm -rf "$OUT/obj_$exe"
    # shellcheck disable=SC2086
    verilator --binary $TRACE -j "$JOBS" \
        -o "$OUT/$exe" \
        --Mdir "$OUT/obj_$exe" \
        -f "$fl" \
        +incdir+rtl/verilog +incdir+bench/verilog \
        +incdir+../dme/rtl/verilog +incdir+../dme/bench/verilog \
        +incdir+../klr/rtl/verilog +incdir+../klr/bench/verilog \
        --top-module dme_klr_dashboard_tb \
        -DRUNTIME_OPTS \
        -DRPMRAMP \
        -DVLT_SIM \
        -DDASHBOARD_TB \
        -DDME_KLR_COMBINED \
        -Wno-fatal \
        -Wno-PINMISSING \
        -Wno-IMPLICIT \
        -Wno-WIDTHTRUNC \
        -Wno-WIDTHEXPAND \
        -Wno-REDEFMACRO \
        -Wno-DEFOVERRIDE \
        -Wno-CASEINCOMPLETE \
        -Wno-LATCH \
        -Wno-MULTIDRIVEN \
        "$@"
}
build files    dme_klr_sim
build files_cl dme_klr_sim_cl -DCL_MODE
echo "built $OUT/dme_klr_sim and $OUT/dme_klr_sim_cl"
