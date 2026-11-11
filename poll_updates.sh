#!/usr/bin/env bash
# poll_updates.sh
# Polls for git updates in 944turbo_dme_klr, then runs the build/test pipeline.

# -h / --help: print the header comment above and exit before anything runs.
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # this checkout, wherever it is
KLR_DIR="$REPO_DIR/klr"
DME_CORE_DIR="$REPO_DIR/dme"
DME_DIR="$REPO_DIR/dme_klr"
POLL_INTERVAL=300  # seconds (5 minutes)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting update poller..."

while true; do
    log "Checking for updates in $REPO_DIR..."
    cd "$REPO_DIR"

    # Stash any unstaged changes so rebase pull can proceed
    STASH_OUTPUT=$(git stash 2>&1)
    STASHED=0
    if echo "$STASH_OUTPUT" | grep -q "Saved working directory"; then
        log "Stashed local changes before pull."
        STASHED=1
    fi

    PULL_OUTPUT=$(git pull 2>&1)
    PULL_EXIT=$?
    echo "$PULL_OUTPUT"

    # Restore stashed changes if we stashed anything
    if [ $STASHED -eq 1 ]; then
        log "Restoring stashed changes..."
        git stash pop
    fi

    if [ $PULL_EXIT -ne 0 ]; then
        log "WARNING: git pull exited with code $PULL_EXIT. Will retry in $POLL_INTERVAL seconds..."
        sleep "$POLL_INTERVAL"
        continue
    fi

    if echo "$PULL_OUTPUT" | grep -q "Already up to date."; then
        log "No changes. Waiting $POLL_INTERVAL seconds before next check..."
        sleep "$POLL_INTERVAL"
        continue
    fi

    log "Changes detected! Starting build pipeline..."

    # Step 1: run_klr_regression in klr
    log "Running run_klr_regression in $KLR_DIR..."
    cd "$KLR_DIR"
    if ! ./run_klr_regression; then
        log "ERROR: run_klr_regression failed. Exiting."
        exit 1
    fi
    log "run_klr_regression completed successfully."

    # Step 2: run_dme_regression in dme
    log "Running run_dme_regression in $DME_CORE_DIR..."
    cd "$DME_CORE_DIR"
    if ! ./run_dme_regression; then
        log "ERROR: run_dme_regression failed. Exiting."
        exit 1
    fi
    log "run_dme_regression completed successfully."

    # Step 3: run_dashboard_parallel.sh in dme_klr
    log "Running run_dashboard_parallel.sh -verilator run 8 in $DME_DIR..."
    cd "$DME_DIR"
    ./run_dashboard_parallel.sh -verilator run 8

    # Step 4: compare_all_logs
    log "Running compare_all_logs..."
    ./compare_all_logs

    log "Pipeline completed successfully."
    break
done
