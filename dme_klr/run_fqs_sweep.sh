#!/bin/bash
# run_fqs_sweep.sh — Run cl_ramp_to_6000 FQS0-7 in both iverilog and Verilator
# then compare and analyse fuel pulse width effect.
#
# Usage:
#   ./run_fqs_sweep.sh [workers]       # default 8 workers
#   ./run_fqs_sweep.sh 4               # use 4 parallel workers

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKERS="${1:-8}"

# 6000 RPM sweep: FQS0-3 (4 main positions)
FQS_TESTS="cl_ramp_to_6000_FQS0 cl_ramp_to_6000_FQS1 cl_ramp_to_6000_FQS2 cl_ramp_to_6000_FQS3 \
           cl_ramp_to_6000_FQS4 cl_ramp_to_6000_FQS5 cl_ramp_to_6000_FQS6 cl_ramp_to_6000_FQS7"
# 3000 RPM sweep: all 8 positions for more stable timing analysis
FQS3K_TESTS="cl_ramp_to_3000_FQS0 cl_ramp_to_3000_FQS1 cl_ramp_to_3000_FQS2 cl_ramp_to_3000_FQS3 \
             cl_ramp_to_3000_FQS4 cl_ramp_to_3000_FQS5 cl_ramp_to_3000_FQS6 cl_ramp_to_3000_FQS7"
# Short 4s versions with CPU_DEBUG for VCD analysis
#FQS_SHORT="cl_ramp_to_6000_FQS0_short cl_ramp_to_6000_FQS1_short cl_ramp_to_6000_FQS2_short cl_ramp_to_6000_FQS3_short"

echo ""
echo "============================================================"
echo "  FQS Fuel Quality Sweep — iverilog + Verilator"
echo "  Workers: $WORKERS"
echo "  Tests:   FQS0–FQS7"
echo "============================================================"

# ── 1. iverilog ──────────────────────────────────────────────────────────────
echo ""
echo "  [1/3] Running iverilog FQS sweep..."
cd "$SCRIPT_DIR"
bash run_dashboard_parallel.sh "$WORKERS" $FQS_TESTS $FQS3K_TESTS # $FQS_SHORT
echo "  iverilog done."

# ── 2. Verilator ─────────────────────────────────────────────────────────────
echo ""
echo "  [2/3] Running Verilator FQS sweep..."
bash run_dashboard_parallel.sh --verilator "$WORKERS" $FQS_TESTS $FQS3K_TESTS # $FQS_SHORT
echo "  Verilator done."

# ── 3. Compare + analyse ─────────────────────────────────────────────────────
echo ""
echo "  [3/3] Comparing results..."
echo ""

for test in $FQS_TESTS; do
    iv_log=~/coding_projects/944/tmp/dme_klr/dash_logs/${test}.dash.log
    vl_log=~/coding_projects/944/tmp/dme_klr/v_dash_logs/${test}.dash.log
    if [ -f "$iv_log" ] && [ -f "$vl_log" ]; then
        result=$(python3 "$SCRIPT_DIR/compare_sim_logs.py" --dash "$iv_log" "$vl_log" "$test" 2>&1)
        verdict=$(echo "$result" | cut -f1)
        detail=$(echo "$result" | cut -f3-)
        case "$verdict" in
            MATCH)      colour="\033[32m" ;;
            NEAR-MATCH) colour="\033[33m" ;;
            *)          colour="\033[31m" ;;
        esac
        printf "  ${colour}%-10s\033[0m %-35s %s\n" "$verdict" "$test" "$detail"
    else
        printf "  \033[31m%-10s\033[0m %-35s missing logs\n" "ERROR" "$test"
    fi
done

echo ""
echo "  Fuel pulse width analysis:"
echo ""
python3 "$SCRIPT_DIR/fqs_analysis.py"
