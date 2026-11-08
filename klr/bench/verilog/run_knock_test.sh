#!/bin/bash
# ============================================================
#  run_knock_test.sh — compile and run the knock_gen testbench
#
#  Usage: ./run_knock_test.sh   (run from klr/bench/verilog; no arguments)
# ============================================================

# -h / --help: print the header comment above and exit before anything runs.
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

iverilog -o knock_gen_tb.vvp -s knock_gen_tb timescale.v klr_defs.v knock_gen.v knock_gen_tb.v
vvp knock_gen_tb.vvp

