# shellcheck shell=bash
# ============================================================
#  paths.sh — where the repo is and where its output goes
#
#  Sourced (not run) by every script that builds, runs or reads the
#  simulations, so the checkout can live anywhere, under any name:
#
#    DMEKLR_REPO   this checkout (worked out from this file's location)
#    DMEKLR_TMP    root for build products, logs, snapshots and map-graph
#                  caches. Default: a "tmp" folder beside the checkout,
#                  i.e. <checkout>/../tmp. Set DMEKLR_TMP in your shell to
#                  put it anywhere else (an absolute path).
#
#  Under DMEKLR_TMP:  dme_klr/ (dashboard tests, replay, live snapshots,
#  map graphs), klr/ and dme/ (CPU regressions), run_all/ (run_all.sh's
#  step logs).
#
#  dmeklr_vdefs ARRAY appends the Verilog defines that tell the testbenches
#  the same two paths (-DDMEKLR_REPO, -DDMEKLR_TMP, each with a trailing
#  slash) to the named bash array.
#
#  The Python scripts get the same answers from dme_klr/dmeklr_paths.py,
#  and the live bridge from DMEKLR_TMP in its environment.
# ============================================================

# This file's own path, in bash or zsh (setup is often sourced from zsh)
if [ -n "${BASH_SOURCE[0]:-}" ]; then _dmeklr_self="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then eval '_dmeklr_self="${(%):-%x}"'
else _dmeklr_self="$0"; fi
DMEKLR_REPO="$(cd "$(dirname "$_dmeklr_self")" && pwd)"
unset _dmeklr_self
if [ -n "${DMEKLR_TMP:-}" ]; then
    mkdir -p "$DMEKLR_TMP"
    DMEKLR_TMP="$(cd "$DMEKLR_TMP" && pwd)"
else
    mkdir -p "$DMEKLR_REPO/../tmp"
    DMEKLR_TMP="$(cd "$DMEKLR_REPO/../tmp" && pwd)"
fi
export DMEKLR_REPO DMEKLR_TMP

dmeklr_vdefs() {
    local _arr="${1:-rom_overrides}"
    eval "$_arr+=(\"-DDMEKLR_REPO=\\\"\$DMEKLR_REPO/\\\"\" \"-DDMEKLR_TMP=\\\"\$DMEKLR_TMP/\\\"\")"
}
