#!/usr/bin/env bash
# Start the lite package's live simulator for the dashboard.
#   ./run_lite.sh [bridge options, e.g. --port 8951]
# Then open https://whalenlg.github.io/dme-dashboard/ and press LIVE.
# Snapshots and map-graph caches go to $DMEKLR_TMP (default: data/ here).
set -e
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DMEKLR_TMP="${DMEKLR_TMP:-$PKG/data}"
mkdir -p "$DMEKLR_TMP"

command -v node >/dev/null 2>&1 || { echo "run_lite.sh: Node.js 18 or newer is needed (https://nodejs.org)" >&2; exit 1; }
_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$_major" -ge 18 ] || { echo "run_lite.sh: Node.js $_major is too old; 18 or newer is needed" >&2; exit 1; }
if ! python3 -c "import matplotlib, numpy, pandas, openpyxl" >/dev/null 2>&1; then
    echo "run_lite.sh: note: python3 with pandas, openpyxl, matplotlib and numpy isn't available" >&2
    echo "  (pip install -r requirements.txt): edited workbooks won't update the listings," >&2
    echo "  and the MAPS tabs have no graphs" >&2
fi

# macOS marks files from a download as quarantined, and then won't run the
# (unsigned) simulator; this package is what you chose to run, so clear it
if [ "$(uname -s)" = Darwin ] && command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$PKG" 2>/dev/null || true
fi

echo "Dashboard: https://whalenlg.github.io/dme-dashboard/  (press LIVE)"
exec node "$PKG/dme_klr/live/bridge.mjs" "$@"
