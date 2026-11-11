#!/usr/bin/env bash
# =============================================================================
#  run_carpokes.sh — run_all.sh against the CarPokes DME/KLR ROM images
#    DME ROM: 28PIN_DME_PERFORMANCE.mem
#    KLR ROM: 87KLR_951.mem
#
#  run_dashboard_tests.sh/v_run_dashboard_tests.sh fall back to the stock
#  '89 images (89DME_951pin.mem / 89KLR_951.mem, same as run89.sh) when
#  DME_ROM_FILE/KLR_ROM_FILE aren't set; this script selects the CarPokes
#  images explicitly.
#
#  Usage: ./run_carpokes.sh [--verilator | --iverilog] [workers]
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

export DME_ROM_FILE=28PIN_DME_PERFORMANCE.mem
export KLR_ROM_FILE=87KLR_951.mem

exec "$SCRIPT_DIR/run_all.sh" "$@"
