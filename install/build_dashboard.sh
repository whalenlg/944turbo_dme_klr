#!/usr/bin/env bash
# ============================================================
#  build_dashboard.sh — npm install the dashboard checkout and build the
#  offline copy (npm run build:lite -> dist-lite/) that bridge.mjs serves
#  at http://127.0.0.1:8951/?live
#
#  Usage: install/build_dashboard.sh [<dashboard dir>]   (default <repo>/dashboard)
#
#  The dashboard builds with Vite, whose bundler (rolldown) is a native
#  add-on published as one npm package per platform
#  (@rolldown/binding-<os>-<cpu>[-<abi>]). npm often leaves that package
#  out (npm/cli#4828: a lockfile made on one platform lacks the others'
#  optional packages), and the build then stops with "Cannot find native
#  binding". This script reads the package name from that error, installs
#  it at rolldown's version (--no-save, so the checkout stays as it is) and
#  builds again.
#
#  Windows: MSYS2's own Node.js is a MinGW build, for which rolldown can
#  ask for a -gnu add-on that isn't published. Then the build is done with
#  the regular Windows Node.js from C:\Program Files\nodejs if it is there
#  (winget install OpenJS.NodeJS.LTS); otherwise this says how to get it.
#
#  Exits 0 when dist-lite/index.html was built, 1 otherwise.
# ============================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH="${1:-$REPO_DIR/dashboard}"
cd "$DASH" 2>/dev/null || { echo "build_dashboard: no dashboard at $DASH" >&2; exit 1; }
LOG="$(mktemp "${TMPDIR:-/tmp}/build_dashboard.XXXXXX")"
trap 'rm -f "$LOG"' EXIT

warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# The npm to use: "npm", or the Windows Node's npm-cli.js run by its node.exe
NPM=(npm)
npm_() { echo "+ ${NPM[*]} $*"; "${NPM[@]}" "$@"; }

build() {
    rm -rf dist-lite
    npm_ run build:lite 2>&1 | tee "$LOG"
    [ -f dist-lite/index.html ]
}

# The add-on the last build looked for, e.g. @rolldown/binding-win32-arm64-msvc
wanted_binding() {
    grep -q 'Cannot find native binding' "$LOG" || return 1
    grep -o "@rolldown/binding-[a-z0-9-]*" "$LOG" | head -1
}

rolldown_version() {
    node -p "require('./node_modules/rolldown/package.json').version" 2>/dev/null
}

# Builds with the current NPM, fetching the native add-on once if it is missing.
# 0: built; 1: failed for another reason; 2: the add-on it needs can't be had
try_build() {
    npm_ install --no-audit --no-fund || return 1
    build && return 0
    local pkg ver
    pkg="$(wanted_binding)" || return 1
    ver="$(rolldown_version)"
    echo "build_dashboard: $pkg is missing; installing it${ver:+ ($ver)}"
    npm_ install --no-save --no-audit --no-fund "$pkg${ver:+@$ver}" || return 2
    build && return 0
    wanted_binding >/dev/null && return 2
    return 1
}

try_build; rc=$?
[ "$rc" = 0 ] && { echo "build_dashboard: built $DASH/dist-lite"; exit 0; }

# MSYS2 (Windows): retry with the regular Windows Node.js
if [ "$rc" = 2 ] && [ -n "${MSYSTEM:-}" ]; then
    pf="$(cygpath -u "${ProgramW6432:-${ProgramFiles:-C:\\Program Files}}" 2>/dev/null)"
    winnode="$pf/nodejs/node.exe"
    if [ -x "$winnode" ]; then
        echo "build_dashboard: MSYS2's Node.js can't load rolldown; using $winnode"
        NPM=("$winnode" "$pf/nodejs/node_modules/npm/bin/npm-cli.js")
        # Scripts npm runs (vite) must find the Windows node first too
        PATH="$pf/nodejs:$PATH"
        rolldown_version() { "$winnode" -p "require('./node_modules/rolldown/package.json').version" 2>/dev/null; }
        try_build && { echo "build_dashboard: built $DASH/dist-lite"; exit 0; }
    else
        warn "MSYS2's Node.js can't load the dashboard's bundler (rolldown) on this PC."
        warn "Install the regular Windows Node.js, then run install/build_dashboard.sh again:"
        warn "    winget install OpenJS.NodeJS.LTS --source winget --accept-source-agreements --accept-package-agreements"
    fi
fi

warn "the dashboard didn't build (output above). The live bridge still works with"
warn "the published page: https://whalenlg.github.io/dme-dashboard/ and press LIVE."
exit 1
