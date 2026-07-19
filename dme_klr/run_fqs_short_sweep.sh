#!/bin/bash
# run_fqs_short_sweep.sh — Run short 4s FQS tests (CPU_DEBUG) in iverilog only
# Produces small FST files suitable for GTKWave analysis of FQS map routine.
#
# Usage:
#   ./run_fqs_short_sweep.sh [workers]    # default 4 workers

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKERS="${1:-4}"

FQS_SHORT="cl_ramp_to_6000_FQS0_short cl_ramp_to_6000_FQS1_short \
           cl_ramp_to_6000_FQS2_short cl_ramp_to_6000_FQS3_short"

echo ""
echo "============================================================"
echo "  FQS Short Sweep — iverilog only, 4s sim, CPU_DEBUG"
echo "  Workers : $WORKERS"
echo "  Tests   : FQS0–FQS3 short (pos0=neutral, pos1=+4, pos2=-4, pos3=+8)"
echo "============================================================"

cd "$SCRIPT_DIR"
bash run_dashboard_parallel.sh "$WORKERS" $FQS_SHORT

echo ""
echo "  FST files:"
for test in $FQS_SHORT; do
    fst=~/coding_projects/944/tmp/dme_klr/dash_logs/fst/${test}.fst
    if [ -f "$fst" ]; then
        size=$(du -sh "$fst" | cut -f1)
        echo "    $size  $fst"
    else
        echo "    MISSING: $fst"
    fi
done
echo ""
echo "  Load in GTKWave:"
echo "    gtkwave ~/coding_projects/944/tmp/dme_klr/dash_logs/fst/cl_ramp_to_6000_FQS0_short.fst &"
