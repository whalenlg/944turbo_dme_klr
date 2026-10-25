#!/usr/bin/env bash
# =============================================================================
#  dme_asm_select.sh — pick the DME disassembly tables for the ROM in use
#
#  Sourced (not run) by the scripts that compile the DME testbench. vcd.v
#  loads its instruction text (test_sim.hex, asm_*.hex) from `DME_ASM_DIR.
#  dme_asm_select picks the workbook for DME_ROM_FILE, keeps everything
#  derived from it up to date, and adds the matching -DDME_ASM_DIR to the
#  array named by $1 (default rom_overrides):
#
#  ROM file                   workbook (disassemble/)        tables (disassemble/)
#  28PIN_DME_PERFORMANCE.mem  disassembleperformance.xlsx    asm_performance/
#  28PIN_86DME.mem            disassemble1986.xlsx           asm_1986/
#  89DME_951pin.mem           disassemble1989.xlsx           asm_1989/
#  (unset)                    = 28PIN_DME_PERFORMANCE.mem, the ROM i8051_top.v defaults to
#
#  disassembleperformance.xlsx is the hand-annotated source. disassemble1986/
#  1989.xlsx are generated from it by build_variant.py, and are rebuilt
#  whenever it (or build_variant.py / dis8051.py) is newer; the previous copy
#  is kept as disassemble<year>.prev.xlsx. Each tables directory is rebuilt
#  whenever its workbook is newer.
#
#  Setting DME_ASM_DIR yourself skips all of this and uses that directory.
#  The directory chosen is left in DME_ASM_SEL (empty = vcd.v's default).
# =============================================================================

_DME_ASM_FILES=(test_sim.hex asm_opcode_ins.hex asm_instr.hex
                asm_operand_mapped.hex asm_operands_numeric.hex
                asm_full.json)   # full-length labels/operands for the live bridge
_DME_ASM_PERF_BIN=28PIN_DME_PERFORMANCE.bin   # the image disassembleperformance.xlsx describes

# variant xlsx whose source workbook or generator is newer -> stale
_dme_variant_stale() {   # <dis dir> <variant xlsx>
    local _d="$1" _x="$2"
    [ ! -e "$_d/$_x" ] && return 0
    [ "$_d/disassembleperformance.xlsx" -nt "$_d/$_x" ] && return 0
    [ "$_d/build_variant.py" -nt "$_d/$_x" ] && return 0
    [ "$_d/dis8051.py" -nt "$_d/$_x" ] && return 0
    return 1
}

_dme_tables_stale() {    # <dis dir> <xlsx> <tables dir>
    local _f
    for _f in "${_DME_ASM_FILES[@]}"; do
        [ "$1/$2" -nt "$3/$_f" ] && return 0
    done
    return 1
}

_dme_any_stale() {       # <dis dir> <xlsx> <tables dir>
    _dme_variant_stale "$1" disassemble1986.xlsx && return 0
    _dme_variant_stale "$1" disassemble1989.xlsx && return 0
    _dme_tables_stale "$1" "$2" "$3"
}

dme_asm_select() {
    local _arr="${1:-rom_overrides}"
    local _repo
    _repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local _dis="$_repo/disassemble"
    local _roms="$_repo/bin_images/dme"
    DME_ASM_SEL="${DME_ASM_DIR:-}"

    if [ -z "$DME_ASM_SEL" ]; then
        local _xlsx="" _tag=""
        case "$(basename "${DME_ROM_FILE:-28PIN_DME_PERFORMANCE.mem}")" in
            28PIN_DME_PERFORMANCE.mem) _xlsx="disassembleperformance.xlsx"; _tag="performance" ;;
            28PIN_86DME.mem)           _xlsx="disassemble1986.xlsx";        _tag="1986" ;;
            89DME_951pin.mem)          _xlsx="disassemble1989.xlsx";        _tag="1989" ;;
            *) echo "  DME ASM: no workbook for ${DME_ROM_FILE}, using vcd.v's default tables"
               return 0 ;;
        esac
        local _dir="$_dis/asm_$_tag"

        if _dme_any_stale "$_dis" "$_xlsx" "$_dir"; then
            # Parallel test runners can all get here at once: one builds
            # (mkdir is the lock), the rest wait for it and then find
            # nothing stale.
            local _lock="$_dis/.asm_lock" _waited=0
            until mkdir "$_lock" 2>/dev/null; do
                sleep 1; _waited=$((_waited + 1))
                [ "$_waited" -ge 600 ] && { echo "  dme_asm_select: stale lock $_lock, remove it and retry" >&2; return 1; }
            done
            local _py="$_repo/8051venv/bin/python"
            [ -x "$_py" ] || _py=python3
            local _rc=0 _v _mem _out
            for _v in 1986:28PIN_86DME.mem 1989:89DME_951pin.mem; do
                _mem="${_v#*:}"; _out="disassemble${_v%%:*}.xlsx"
                _dme_variant_stale "$_dis" "$_out" || continue
                echo "  DME ASM: regenerating $_out from disassembleperformance.xlsx"
                [ -e "$_dis/$_out" ] && cp -p "$_dis/$_out" "$_dis/${_out%.xlsx}.prev.xlsx"
                "$_py" "$_dis/build_variant.py" "$_dis/disassembleperformance.xlsx" \
                    "$_roms/$_mem" "$_roms/$_DME_ASM_PERF_BIN" "$_dis/$_out.tmp.xlsx" \
                    "${_v%%:*}" perf >/dev/null \
                  && mv -f "$_dis/$_out.tmp.xlsx" "$_dis/$_out" \
                  || { echo "  dme_asm_select: failed to regenerate $_out" >&2; rm -f "$_dis/$_out.tmp.xlsx"; _rc=1; }
            done
            if [ "$_rc" = "0" ] && _dme_tables_stale "$_dis" "$_xlsx" "$_dir"; then
                echo "  DME ASM: generating $_dir from $_xlsx"
                local _tmp="$_dis/.asm_tmp.$$" _f
                mkdir -p "$_dir" "$_tmp"
                if ( cd "$_tmp" &&
                     "$_py" "$_dis/xlsxinstr2veriloghex.py" "$_dis/$_xlsx" 8192 >/dev/null &&
                     "$_py" "$_dis/xlsx2veriloghex.py" "$_dis/$_xlsx" test_sim.hex 8192 >/dev/null &&
                     "$_py" "$_repo/dme_klr/live/asm_full.py" --dme "$_dis/$_xlsx" --out asm_full.json >/dev/null ) &&
                   [ -s "$_tmp/asm_instr.hex" ] && [ -s "$_tmp/test_sim.hex" ] && [ -s "$_tmp/asm_full.json" ]; then
                    for _f in "${_DME_ASM_FILES[@]}"; do mv -f "$_tmp/$_f" "$_dir/$_f"; done
                else
                    echo "  dme_asm_select: failed to generate tables from $_xlsx" >&2
                    _rc=1
                fi
                rm -rf "$_tmp"
            fi
            rmdir "$_lock"
            [ "$_rc" = "0" ] || return 1
        fi
        DME_ASM_SEL="$_dir/"
    fi

    echo "  DME ASM: $DME_ASM_SEL"
    eval "$_arr+=(\"-DDME_ASM_DIR=\\\"\${DME_ASM_SEL%/}/\\\"\")"
}
