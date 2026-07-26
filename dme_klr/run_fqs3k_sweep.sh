#!/bin/bash
# run_fqs3k_sweep.sh — Run cl_ramp_to_3000 FQS0-7 in both iverilog and Verilator
#
# Usage:
#   ./run_fqs3k_sweep.sh [workers]    # default 8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKERS="${1:-8}"

FQS3K="cl_ramp_to_3000_FQS0 cl_ramp_to_3000_FQS1 \
        cl_ramp_to_3000_FQS2 cl_ramp_to_3000_FQS3 \
        cl_ramp_to_3000_FQS4 cl_ramp_to_3000_FQS5 \
        cl_ramp_to_3000_FQS6 cl_ramp_to_3000_FQS7"

echo ""
echo "============================================================"
echo "  FQS 3000 RPM Sweep — iverilog + Verilator"
echo "  Workers: $WORKERS"
echo "============================================================"

cd "$SCRIPT_DIR"

echo ""
echo "  [1/2] Running iverilog..."
bash run_dashboard_parallel.sh "$WORKERS" $FQS3K

echo ""
echo "  [2/2] Running Verilator..."
bash run_dashboard_parallel.sh --verilator "$WORKERS" $FQS3K

echo ""
echo "  FQS analysis:"
python3 "$SCRIPT_DIR/fqs_analysis.py"
