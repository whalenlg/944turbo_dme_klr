#!/usr/bin/env bash
# =============================================================================
#  run_carpokes.sh — run_all.sh against the CarPokes DME/KLR ROM images
#    DME ROM: 28PIN_DME_PERFORMANCE.mem
#    KLR ROM: 87KLR_951.mem
#
#  These happen to be the same images run_dashboard_tests.sh/v_run_dashboard_tests.sh
#  fall back to when DME_ROM_FILE/KLR_ROM_FILE aren't set — set explicitly
#  here anyway so this script's behavior doesn't silently change if those
#  defaults ever do.
#
#  Usage: ./run_carpokes.sh [--verilator | --iverilog] [workers]
#  (same arguments as run_all.sh — passed through unchanged)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export DME_ROM_FILE=28PIN_DME_PERFORMANCE.mem
export KLR_ROM_FILE=87KLR_951.mem

exec "$SCRIPT_DIR/run_all.sh" "$@"
