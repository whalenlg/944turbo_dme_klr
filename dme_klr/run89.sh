#!/usr/bin/env bash
# =============================================================================
#  run89.sh — run_all.sh against the 89-pin DME/KLR ROM images
#    DME ROM: 89DME_951pin.mem
#    KLR ROM: 89KLR_951.mem
#
#  Usage: ./run89.sh [--verilator | --iverilog] [workers]
#  (same arguments as run_all.sh — passed through unchanged)
# =============================================================================

# -h / --help: print the header comment above and exit before anything runs.
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export DME_ROM_FILE=89DME_951pin.mem
export KLR_ROM_FILE=89KLR_951.mem

exec "$SCRIPT_DIR/run_all.sh" "$@"
