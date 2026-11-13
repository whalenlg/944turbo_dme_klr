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
#  With --iverilog, Icarus Verilog instead (plain Verilog-2005, no -g2012):
#      <out>/dme_klr_sim.vvp, <out>/dme_klr_sim_cl.vvp   (vvp <file> +X=<n> ...)
#
#  Usage: build_runtime.sh [--out DIR] [--iverilog] [--trace] [--jobs N] [-- extra]
#         (default DIR: $DMEKLR_TMP/dme_klr/runtime; extra: more Verilator or
#         iverilog arguments, e.g. -LDFLAGS -static for the lite package)
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
SIM=verilator
EXTRA=()
while [ $# -gt 0 ]; do
    case "$1" in
        --out)   OUT="$2"; shift 2 ;;
        --trace) TRACE="--trace"; shift ;;
        --jobs)  JOBS="$2"; shift 2 ;;
        --iverilog) SIM=iverilog; shift ;;
        --) shift; EXTRA=("$@"); break ;;
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
    if [ "$SIM" = iverilog ]; then
        # test_opts is a module of its own here: a second root
        iverilog -o "$OUT/$exe.vvp" -f "$fl" \
            -I rtl/verilog -I bench/verilog -I ../dme/rtl/verilog -I ../dme/bench/verilog \
            -I ../klr/rtl/verilog -I ../klr/bench/verilog \
            -s dme_klr_dashboard_tb -s test_opts \
            -DRUNTIME_OPTS -DRPMRAMP -DDASHBOARD_TB -DDME_KLR_COMBINED "$@"
        return
    fi
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
build files    dme_klr_sim ${EXTRA[@]+"${EXTRA[@]}"}
build files_cl dme_klr_sim_cl -DCL_MODE ${EXTRA[@]+"${EXTRA[@]}"}
[ "$SIM" = iverilog ] && x=.vvp || x=
echo "built $OUT/dme_klr_sim$x and $OUT/dme_klr_sim_cl$x"
