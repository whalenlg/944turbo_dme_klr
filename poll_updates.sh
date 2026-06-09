#!/usr/bin/env bash
# poll_updates.sh
# Polls for git updates in 944turbo_dme_klr, then runs the build/test pipeline.

REPO_DIR="/Users/mike/coding_projects/DME_sim/944turbo_dme_klr"
GEMINI_DIR="/Users/mike/coding_projects/DME_sim/944turbo_dme_klr/gemini8048"
CLAUDE_DIR="/Users/mike/coding_projects/DME_sim/claude_8051"
DME_DIR="/Users/mike/coding_projects/DME_sim/dme_klr"
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

    # Step 1: run_48 in gemini8048
    log "Running run_48 in $GEMINI_DIR..."
    cd "$GEMINI_DIR"
    if ! ./run_48; then
        log "ERROR: run_48 failed. Exiting."
        exit 1
    fi
    log "run_48 completed successfully."

    # Step 2: run_reg in claude_8051
    log "Running run_reg in $CLAUDE_DIR..."
    cd "$CLAUDE_DIR"
    if ! ./run_reg; then
        log "ERROR: run_reg failed. Exiting."
        exit 1
    fi
    log "run_reg completed successfully."

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
