#!/usr/bin/env bash
# =============================================================================
#  run86.sh — run_all.sh against the 86-pin DME/KLR ROM images
#    DME ROM: 28PIN_86DME.mem
#    KLR ROM: 86KLR_951.mem
#
#  Usage: ./run86.sh [--verilator | --iverilog] [workers]
#  (same arguments as run_all.sh — passed through unchanged)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export DME_ROM_FILE=28PIN_86DME.mem
export KLR_ROM_FILE=86KLR_951.mem

exec "$SCRIPT_DIR/run_all.sh" "$@"
