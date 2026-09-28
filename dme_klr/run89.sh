#!/usr/bin/env bash
# =============================================================================
#  run89.sh — run_all.sh against the 89-pin DME/KLR ROM images
#    DME ROM: 89DME_951pin.mem
#    KLR ROM: 89KLR_951.mem
#
#  Usage: ./run89.sh [--verilator | --iverilog] [workers]
#  (same arguments as run_all.sh — passed through unchanged)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export DME_ROM_FILE=89DME_951pin.mem
export KLR_ROM_FILE=89KLR_951.mem

exec "$SCRIPT_DIR/run_all.sh" "$@"
