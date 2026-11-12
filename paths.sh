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
# Windows (MSYS2): the tools are native Windows programs, which don't know
# MSYS2's /c/... or /home/... paths, so hand everything C:/... ones (bash
# takes those too). PATH entries still need the /c/... form: see setup.
case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*)
        DMEKLR_REPO="$(cygpath -m "$DMEKLR_REPO")"
        DMEKLR_TMP="$(cygpath -m "$DMEKLR_TMP")"
        # MSYS2's gcc 16, at -Os, calls std::string's constructors through
        # the "C4" unified-constructor symbol (-fdeclone-ctor-dtor), which
        # its libstdc++ doesn't export: "undefined reference to
        # std::__cxx11::basic_string(basic_string&&)" when linking any
        # Verilator build (its runtime is compiled at -Os). Turn that off.
        # Verilator's makefiles pass CXXFLAGS to every compile;
        # build_live.sh and run_replay.sh also pass it with -CFLAGS.
        case " ${CXXFLAGS:-} " in *" -fno-declone-ctor-dtor "*) ;;
            *) export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-fno-declone-ctor-dtor" ;; esac ;;
esac
export DMEKLR_REPO DMEKLR_TMP

dmeklr_vdefs() {
    local _arr="${1:-rom_overrides}"
    eval "$_arr+=(\"-DDMEKLR_REPO=\\\"\$DMEKLR_REPO/\\\"\" \"-DDMEKLR_TMP=\\\"\$DMEKLR_TMP/\\\"\")"
}

# dmeklr_rom_mem: DME_ROM_FILE / KLR_ROM_FILE may name a raw binary (.bin)
# or an Intel HEX file instead of a .mem: convert it (bin_images/rom2mem.py)
# to $DMEKLR_TMP/roms/<cpu>/<name>.mem, once and again whenever the image
# is newer, and point DME_ROM_DIR/FILE (KLR_...) there. A .mem, or an
# unset name, is left alone. Returns 1 if a conversion fails.
dmeklr_rom_mem() {
    local _cpu _CPU _dir _file _src _out _py
    _py="$DMEKLR_REPO/944venv/bin/python"; [ -x "$_py" ] || _py=python3
    for _cpu in dme klr; do
        _CPU="$(echo "$_cpu" | tr a-z A-Z)"
        eval "_dir=\"\${${_CPU}_ROM_DIR:-}\" _file=\"\${${_CPU}_ROM_FILE:-}\""
        case "$_file" in ""|*.mem|*.MEM) continue ;; esac
        _src="${_dir:-$DMEKLR_REPO/bin_images/$_cpu/}$_file"
        [ -f "$_src" ] || { echo "dmeklr_rom_mem: $_CPU ROM $_src not found" >&2; return 1; }
        _out="$DMEKLR_TMP/roms/$_cpu/${_file%.*}.mem"
        if [ ! -f "$_out" ] || [ "$_src" -nt "$_out" ]; then
            mkdir -p "$DMEKLR_TMP/roms/$_cpu"
            "$_py" "$DMEKLR_REPO/bin_images/rom2mem.py" "$_src" "$_out" --cpu "$_cpu" >&2 || return 1
        fi
        eval "${_CPU}_ROM_DIR=\"\$DMEKLR_TMP/roms/\$_cpu/\" ${_CPU}_ROM_FILE=\"\${_file%.*}.mem\""
        export "${_CPU}_ROM_DIR" "${_CPU}_ROM_FILE"
    done
}
