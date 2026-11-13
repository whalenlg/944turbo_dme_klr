#!/usr/bin/env bash
# ============================================================
#  make_lite.sh — build the lite package: the live simulator without the
#  Verilog
#
#  The lite package runs the dashboard's live mode, the code debugger and
#  snapshots from a prebuilt simulator. It holds no Verilog, testbenches or
#  simulator build scripts, and needs no Verilator, iverilog or GTKWave:
#
#    dme_klr/live/obj/dme_klr_live   the simulator (build_live.sh --relocatable)
#    dme_klr/live/bridge.mjs         the bridge (Node 18+)
#    dme_klr/live/*map_graphs.py     the MAPS tab graphs (matplotlib, numpy)
#    bin_images/                     the ROM images
#    {dme,klr}/disassemble/          the disassembly workbooks (.xlsx), the
#                                    scripts that make tables and variant
#                                    workbooks from them (pandas, openpyxl),
#                                    and the tables already made (asm_*/)
#    dme_klr/asm_select.sh           regenerates tables/workbooks (bash)
#    dme_klr/live/asm_tables.json    which asm_*/ goes with which ROM, for
#                                    when asm_select.sh can't run
#    run_lite.sh, run_lite.cmd       start the bridge
#    dme_klr/runtime/dme_klr_sim[_cl]  the regression testbench, built once
#                                    (build_runtime.sh), for run_tests.py
#    dme_klr/live/obj/tests_rt/      the live sim with every test's options
#                                    read at run time (build_live.sh --tests),
#                                    for TEST LOAD
#    dme_klr/live/tests.json         every test's options (test_opts.py
#                                    tests-json)
#    run_tests.py                    runs and checks the regression tests
#
#  Needs the developer install (Verilator, a C++ compiler, Python with
#  pandas and openpyxl to make the tables). Builds into
#  dme_klr/live/obj/lite/, then writes
#    <out>/dmeklr-lite-<version>-<platform>/       and
#    <out>/dmeklr-lite-<version>-<platform>.tar.gz (.zip on Windows)
#
#  Usage:  lite/make_lite.sh [--out <dir>] [--version <v>] [--no-build]
#    --out <dir>      where the package goes (default $DMEKLR_TMP/lite)
#    --version <v>    version in the name (default: git describe)
#    --no-build       package the simulator already in obj/lite/
# ============================================================

# shellcheck disable=SC2154  # the _c_* settings come from asm_select.sh's _asm_cfg
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -euo pipefail

LITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$LITE_DIR/.." && pwd)"
source "$REPO/paths.sh"

OUT=""; VERSION=""; BUILD=1
while [ $# -gt 0 ]; do
    case "$1" in
        --out)      OUT="$2"; shift 2 ;;
        --version)  VERSION="$2"; shift 2 ;;
        --no-build) BUILD=0; shift ;;
        *) echo "make_lite.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
done
OUT="${OUT:-$DMEKLR_TMP/lite}"
VERSION="${VERSION:-$(git -C "$REPO" describe --tags --always --dirty 2>/dev/null || echo dev)}"

EXE=""
case "$(uname -s)" in
    Darwin)               PLATFORM="macos-$(uname -m)" ;;
    Linux)                PLATFORM="linux-$(uname -m)" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows-$(uname -m)"; EXE=".exe" ;;
    *)                    PLATFORM="$(uname -s | tr 'A-Z' 'a-z')-$(uname -m)" ;;
esac
NAME="dmeklr-lite-$VERSION-$PLATFORM"
PKG="$OUT/$NAME"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# ── 1. Disassembly tables for every ROM that has a workbook ──────────────
#    (asm_select.sh makes them from the .xlsx; the package gets only the
#    tables)
step "Disassembly tables"
# shellcheck source=../dme_klr/asm_select.sh
source "$REPO/dme_klr/asm_select.sh"
TABLES_JSON="{"
for cpu in dme klr; do
    CPU="$(echo "$cpu" | tr a-z A-Z)"
    [ "$cpu" = klr ] && TABLES_JSON+=", "
    TABLES_JSON+="\"$cpu\": {"
    _first=1
    for rom in $(_asm_cfg "$cpu" "$REPO"; for v in "${_c_variants[@]}"; do echo "${v#*:}" | cut -d: -f1; done; echo "$_c_refimg" | sed 's/\.bin$/.mem/'); do
        _arr=()
        if [ "$cpu" = dme ]; then DME_ROM_FILE="$rom" DME_ASM_DIR="" dme_asm_select _arr >&2; sel="$DME_ASM_SEL"
        else                      KLR_ROM_FILE="$rom" KLR_ASM_DIR="" klr_asm_select _arr >&2; sel="$KLR_ASM_SEL"; fi
        [ -n "$sel" ] || { echo "make_lite.sh: no $CPU tables for $rom" >&2; exit 1; }
        [ "$_first" = 1 ] || TABLES_JSON+=", "
        _first=0
        TABLES_JSON+="\"$rom\": \"$(basename "$sel")\""
    done
    TABLES_JSON+="}"
done
TABLES_JSON+="}"
echo "$TABLES_JSON"

# ── 2. The simulator, with relative paths ────────────────────────────────
OBJ="$REPO/dme_klr/live/obj/lite"
if [ "$BUILD" = 1 ]; then
    step "Building the live simulator (build_live.sh --relocatable)"
    LDF=()
    case "$PLATFORM" in
        linux-*)   LDF=(-LDFLAGS "-static-libstdc++ -static-libgcc") ;;
        windows-*) LDF=(-LDFLAGS "-static") ;;
    esac
    "$REPO/dme_klr/live/build_live.sh" --relocatable ${LDF[@]+"${LDF[@]}"}   # (bash 3.2: an empty array is "unbound" under set -u)
    step "Building the live sim for TEST LOAD (build_live.sh --relocatable --tests)"
    "$REPO/dme_klr/live/build_live.sh" --relocatable --tests ${LDF[@]+"${LDF[@]}"}
    step "Building the regression testbench (build_runtime.sh)"
    "$REPO/dme_klr/build_runtime.sh" --out "$OBJ/runtime" -- ${LDF[@]+"${LDF[@]}"}
fi
for f in dme_klr_live tests_rt/open/dme_klr_live tests_rt/cl/dme_klr_live runtime/dme_klr_sim runtime/dme_klr_sim_cl; do
    [ -x "$OBJ/$f$EXE" ] || { echo "make_lite.sh: no $OBJ/$f$EXE (build it first)" >&2; exit 1; }
done

# ── 3. The package ───────────────────────────────────────────────────────
step "Package $PKG"
rm -rf "$PKG"
mkdir -p "$PKG/dme_klr/live/obj" "$PKG/bin_images/dme" "$PKG/bin_images/klr" \
         "$PKG/dme/disassemble" "$PKG/klr/disassemble"

cp "$OBJ/dme_klr_live$EXE" "$PKG/dme_klr/live/obj/"
for v in open cl; do
    mkdir -p "$PKG/dme_klr/live/obj/tests_rt/$v"
    cp "$OBJ/tests_rt/$v/dme_klr_live$EXE" "$PKG/dme_klr/live/obj/tests_rt/$v/"
done
mkdir -p "$PKG/dme_klr/runtime"
cp "$OBJ/runtime/dme_klr_sim$EXE" "$OBJ/runtime/dme_klr_sim_cl$EXE" "$PKG/dme_klr/runtime/"
# The regression tests: their options, the runner and the checks
python3 "$REPO/dme_klr/test_opts.py" tests-json > "$PKG/dme_klr/live/tests.json"
cp "$REPO/dme_klr/live/test_snap.py" "$PKG/dme_klr/live/"
cp "$REPO/dme_klr/validate_dash_log.py" "$REPO/dme_klr/rom_stamp.py" "$PKG/dme_klr/"
cp "$LITE_DIR/run_tests.py" "$PKG/"
for f in bridge.mjs map_graphs.py klr_map_graphs.py asm_full.json; do
    cp "$REPO/dme_klr/live/$f" "$PKG/dme_klr/live/"
done
printf '%s\n' "$TABLES_JSON" > "$PKG/dme_klr/live/asm_tables.json"

# The ROM images and the disassembly workbooks with the scripts that make
# the tables and variant workbooks from them (asm_select.sh, the
# build_*variant.py / dis80*.py / xlsx*2veriloghex.py scripts), so the
# lite package regenerates tables and workbooks just as the developer
# install does. cp -p keeps the times asm_select.sh compares.
git -C "$REPO" ls-files -z bin_images dme/disassemble klr/disassemble \
    | while IFS= read -r -d '' f; do
        case "$f" in *.DS_Store|*.prev.xlsx) continue ;; esac
        mkdir -p "$PKG/$(dirname "$f")"
        cp -p "$REPO/$f" "$PKG/$f"
    done
cp -p "$REPO/dme_klr/asm_select.sh" "$PKG/dme_klr/"
cp -p "$REPO/dme_klr/live/asm_full.py" "$PKG/dme_klr/live/"
cp "$REPO/install/requirements.txt" "$PKG/requirements.txt"
# The tables already made (asm_<tag>/), for when asm_select.sh can't run
for cpu in dme klr; do
    _asm_cfg "$cpu" "$REPO"
    for d in "$_c_dis"/asm_*/; do
        [ -d "$d" ] || continue
        t="$(basename "$d")"
        mkdir -p "$PKG/$cpu/disassemble/$t"
        for f in "${_c_files[@]}"; do cp -p "$d/$f" "$PKG/$cpu/disassemble/$t/"; done
    done
done

cp "$LITE_DIR/run_lite.sh" "$LITE_DIR/run_lite.cmd" "$PKG/"
chmod +x "$PKG/run_lite.sh"
sed -e "s/@VERSION@/$VERSION/g" -e "s/@PLATFORM@/$PLATFORM/g" "$LITE_DIR/README.txt" > "$PKG/README.txt"
cp "$LITE_DIR/NOTICE.txt" "$PKG/"

# Nothing that the lite package mustn't carry
if find "$PKG" \( -name '*.v' -o -name '*.sv' -o -name '*.vh' -o -name '*.cpp' -o -name '*.h' -o -name 'files*' \) | grep -q .; then
    echo "make_lite.sh: simulator source ended up in the package:" >&2
    find "$PKG" \( -name '*.v' -o -name '*.sv' -o -name '*.vh' -o -name '*.cpp' -o -name '*.h' -o -name 'files*' \) >&2
    exit 1
fi

step "Archive"
cd "$OUT"
rm -f "$NAME.tar.gz" "$NAME.zip"
if [ -n "$EXE" ] && command -v zip >/dev/null 2>&1; then
    zip -qr "$NAME.zip" "$NAME"; ARCHIVE="$OUT/$NAME.zip"
else
    tar -czf "$NAME.tar.gz" "$NAME"; ARCHIVE="$OUT/$NAME.tar.gz"
fi
du -sh "$PKG" "$ARCHIVE" | sed 's/^/  /'
echo "Built $ARCHIVE"
