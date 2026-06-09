#!/bin/bash
# ============================================================
#  kill_verilator.sh
#
#  Kills all running Verilator simulation processes.
#  Matches compiled sim binaries from tmp/dme_klr/ and any
#  verilator_bin processes.
#
#  Usage:
#    ./kill_verilator.sh          # kill all, with confirmation
#    ./kill_verilator.sh -f       # force kill (no confirmation)
#    ./kill_verilator.sh -n       # dry run (show what would be killed)
# ============================================================

FORCE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        -f|--force) FORCE=1 ;;
        -n|--dry-run) DRY_RUN=1 ;;
    esac
done

# Find Verilator sim processes:
#   - compiled sim binaries: dash_*, dash_klr_*, nondash_klr_* in tmp/dme_klr/
#     These are ELF executables run directly (not via vvp), so we match
#     processes whose argv[0] IS the binary path — not vvp or bash.
#   - verilator_bin itself (compile phase)
# ps -o comm= gives just the executable name (no path, no args).
# Verilator binaries are named dash_*, dash_klr_*, nondash_klr_*.
# vvp processes have comm='vvp', so they won't match.
PIDS=$(ps ax -o pid=,comm= 2>/dev/null | \
    awk '$2 ~ /^(dash_|dash_klr_|nondash_klr_)/ {print $1}')
VLT_PIDS=$(pgrep -f 'verilator_bin' 2>/dev/null)
ALL_PIDS=$(printf '%s\n%s\n' "$PIDS" "$VLT_PIDS" | grep -E '^[0-9]+$' | sort -u)

if [ -z "$ALL_PIDS" ]; then
    echo "No Verilator processes found."
    exit 0
fi

echo ""
echo "Found Verilator processes:"
echo ""
for pid in $ALL_PIDS; do
    cmd=$(ps -p "$pid" -o pid=,etime=,command= 2>/dev/null | sed 's/+vcd=[^ ]*/+vcd=.../')
    [ -n "$cmd" ] && printf "  %s\n" "$cmd"
done
echo ""
COUNT=$(echo "$ALL_PIDS" | wc -w | tr -d ' ')
echo "  Total: $COUNT process(es)"
echo ""

if [ "$DRY_RUN" = "1" ]; then
    echo "  Dry run — nothing killed."
    exit 0
fi

if [ "$FORCE" = "0" ]; then
    read -r -p "Kill all $COUNT process(es)? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "  Aborted."; exit 0; }
fi

# Send SIGTERM first, then SIGKILL after 3s for any that don't respond
kill $ALL_PIDS 2>/dev/null
sleep 1

# Check for survivors
SURVIVORS=$(echo "$ALL_PIDS" | tr ' ' '\n' | while read -r pid; do
    kill -0 "$pid" 2>/dev/null && echo "$pid"
done)

if [ -n "$SURVIVORS" ]; then
    echo "  Sending SIGKILL to stubborn processes: $SURVIVORS"
    kill -9 $SURVIVORS 2>/dev/null
    sleep 1
fi

# Final count
REMAINING=$(echo "$ALL_PIDS" | tr ' ' '\n' | while read -r pid; do
    kill -0 "$pid" 2>/dev/null && echo "$pid"
done)

if [ -z "$REMAINING" ]; then
    echo "  All $COUNT process(es) killed."
else
    echo "  WARNING: $(echo "$REMAINING" | wc -w | tr -d ' ') process(es) still running: $REMAINING"
    exit 1
fi
