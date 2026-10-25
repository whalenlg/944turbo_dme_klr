#!/usr/bin/env bash
# =============================================================================
#  asm_select.sh — pick the DME and KLR disassembly tables for the ROMs in use
#
#  Sourced (not run) by the scripts that compile the testbenches. vcd.v and
#  klr_vcd.v load their instruction text (test_sim.hex, asm_*.hex) from
#  `DME_ASM_DIR / `KLR_ASM_DIR. dme_asm_select / klr_asm_select pick the
#  workbook for DME_ROM_FILE / KLR_ROM_FILE, keep everything derived from it
#  up to date, and add the matching -DDME_ASM_DIR / -DKLR_ASM_DIR to the array
#  named by $1 (default rom_overrides):
#
#  DME (dme/disassemble/)
#  ROM file                   workbook                       tables
#  28PIN_DME_PERFORMANCE.mem  disassembleperformance.xlsx    asm_performance/
#  28PIN_86DME.mem            disassemble1986.xlsx           asm_1986/
#  89DME_951pin.mem           disassemble1989.xlsx           asm_1989/
#
#  KLR (klr/disassemble/)
#  87KLR_951.mem              87KLR951.xlsx                  asm_87/
#  86KLR_951.mem              86KLR951.xlsx                  asm_86/
#  89KLR_951.mem              89KLR951.xlsx                  asm_89/
#
#  An unset ROM file means the one i8051_top.v / klr_top.v default to
#  (28PIN_DME_PERFORMANCE.mem / 87KLR_951.mem).
#
#  disassembleperformance.xlsx and 87KLR951.xlsx are the hand-annotated
#  sources. The other workbooks are generated from them (build_variant.py /
#  build_klr_variant.py) and rebuilt whenever the source or its generator is
#  newer; the previous copy is kept as <name>.prev.xlsx. Each tables directory
#  is rebuilt whenever its workbook is newer.
#
#  Setting DME_ASM_DIR / KLR_ASM_DIR yourself skips all of this and uses that
#  directory. The directory chosen is left in DME_ASM_SEL / KLR_ASM_SEL
#  (empty = the testbench's default).
# =============================================================================

# Per-CPU settings: sets the _c_* locals of the caller
_asm_cfg() {   # <dme|klr> <repo>
    case "$1" in
        dme)
            _c_name=DME; _c_dis="$2/dme/disassemble"; _c_roms="$2/bin_images/dme"; _c_size=8192
            _c_src=disassembleperformance.xlsx; _c_refimg=28PIN_DME_PERFORMANCE.bin; _c_reftag=perf
            _c_gen=build_variant.py; _c_deps=(build_variant.py dis8051.py)
            _c_variants=(1986:28PIN_86DME.mem:disassemble1986.xlsx 1989:89DME_951pin.mem:disassemble1989.xlsx)
            _c_default=28PIN_DME_PERFORMANCE.mem
            _c_files=(test_sim.hex asm_opcode_ins.hex asm_instr.hex asm_operand_mapped.hex
                      asm_operands_numeric.hex asm_full.json) ;;
        klr)
            _c_name=KLR; _c_dis="$2/klr/disassemble"; _c_roms="$2/bin_images/klr"; _c_size=4096
            _c_src=87KLR951.xlsx; _c_refimg=87KLR_951.mem; _c_reftag=87
            _c_gen=build_klr_variant.py; _c_deps=(build_klr_variant.py dis8048.py)
            _c_variants=(86:86KLR_951.mem:86KLR951.xlsx 89:89KLR_951.mem:89KLR951.xlsx)
            _c_default=87KLR_951.mem
            _c_files=(test_sim.hex asm_opcode_ins.hex asm_instr.hex asm_operands.hex
                      asm_operands_numeric.hex asm_full.json) ;;
    esac
}

# ROM file -> "<workbook> <tag>" (empty if it has none)
_asm_workbook() {   # <dme|klr> <rom file name>
    case "$1:$2" in
        dme:28PIN_DME_PERFORMANCE.mem) echo "disassembleperformance.xlsx performance" ;;
        dme:28PIN_86DME.mem)           echo "disassemble1986.xlsx 1986" ;;
        dme:89DME_951pin.mem)          echo "disassemble1989.xlsx 1989" ;;
        klr:87KLR_951.mem)             echo "87KLR951.xlsx 87" ;;
        klr:86KLR_951.mem)             echo "86KLR951.xlsx 86" ;;
        klr:89KLR_951.mem)             echo "89KLR951.xlsx 89" ;;
    esac
}

# generated workbook whose source workbook or generator is newer -> stale
_asm_variant_stale() {   # <variant xlsx>   (uses _c_*)
    local _x="$_c_dis/$1" _d
    [ ! -e "$_x" ] && return 0
    [ "$_c_dis/$_c_src" -nt "$_x" ] && return 0
    for _d in "${_c_deps[@]}"; do [ "$_c_dis/$_d" -nt "$_x" ] && return 0; done
    return 1
}

_asm_tables_stale() {    # <xlsx> <tables dir>   (uses _c_*)
    local _f
    for _f in "${_c_files[@]}"; do
        [ "$_c_dis/$1" -nt "$2/$_f" ] && return 0
    done
    return 1
}

_asm_any_stale() {       # <xlsx> <tables dir>
    local _v
    for _v in "${_c_variants[@]}"; do _asm_variant_stale "${_v##*:}" && return 0; done
    _asm_tables_stale "$1" "$2"
}

_asm_select() {   # <dme|klr> <array name>
    local _cpu="$1" _arr="${2:-rom_overrides}"
    local _repo
    _repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local _c_name _c_dis _c_roms _c_size _c_src _c_refimg _c_reftag _c_gen _c_default
    local -a _c_deps _c_variants _c_files
    _asm_cfg "$_cpu" "$_repo"
    local _NAME="$_c_name" _sel _rom _pin
    if [ "$_cpu" = dme ]; then _pin="${DME_ASM_DIR:-}"; _rom="${DME_ROM_FILE:-}"
    else                       _pin="${KLR_ASM_DIR:-}"; _rom="${KLR_ROM_FILE:-}"; fi
    _sel="$_pin"

    if [ -z "$_sel" ]; then
        local _wb
        _wb="$(_asm_workbook "$_cpu" "$(basename "${_rom:-$_c_default}")")"
        if [ -z "$_wb" ]; then
            echo "  $_NAME ASM: no workbook for ${_rom}, using the testbench's default tables"
            [ "$_cpu" = dme ] && DME_ASM_SEL="" || KLR_ASM_SEL=""
            return 0
        fi
        local _xlsx="${_wb% *}" _tag="${_wb#* }"
        local _dir="$_c_dis/asm_$_tag"

        if _asm_any_stale "$_xlsx" "$_dir"; then
            # Parallel test runners can all get here at once: one builds
            # (mkdir is the lock), the rest wait for it and then find
            # nothing stale.
            local _lock="$_c_dis/.asm_lock" _waited=0
            until mkdir "$_lock" 2>/dev/null; do
                sleep 1; _waited=$((_waited + 1))
                [ "$_waited" -ge 600 ] && { echo "  asm_select: stale lock $_lock, remove it and retry" >&2; return 1; }
            done
            local _py="$_repo/8051venv/bin/python"
            [ -x "$_py" ] || _py=python3
            local _gens="$_repo/dme/disassemble"   # xlsx -> hex table scripts
            local _rc=0 _v _vtag _mem _out
            for _v in "${_c_variants[@]}"; do
                _vtag="${_v%%:*}"; _mem="${_v#*:}"; _mem="${_mem%%:*}"; _out="${_v##*:}"
                _asm_variant_stale "$_out" || continue
                echo "  $_NAME ASM: regenerating $_out from $_c_src"
                [ -e "$_c_dis/$_out" ] && cp -p "$_c_dis/$_out" "$_c_dis/${_out%.xlsx}.prev.xlsx"
                "$_py" "$_c_dis/$_c_gen" "$_c_dis/$_c_src" \
                    "$_c_roms/$_mem" "$_c_roms/$_c_refimg" "$_c_dis/$_out.tmp.xlsx" \
                    "$_vtag" "$_c_reftag" >/dev/null \
                  && mv -f "$_c_dis/$_out.tmp.xlsx" "$_c_dis/$_out" \
                  || { echo "  asm_select: failed to regenerate $_out" >&2; rm -f "$_c_dis/$_out.tmp.xlsx"; _rc=1; }
            done
            if [ "$_rc" = "0" ] && _asm_tables_stale "$_xlsx" "$_dir"; then
                echo "  $_NAME ASM: generating $_dir from $_xlsx"
                local _tmp="$_c_dis/.asm_tmp.$$" _f
                mkdir -p "$_dir" "$_tmp"
                if ( cd "$_tmp" &&
                     "$_py" "$_gens/xlsxinstr2veriloghex.py" "$_c_dis/$_xlsx" "$_c_size" >/dev/null &&
                     "$_py" "$_gens/xlsx2veriloghex.py" "$_c_dis/$_xlsx" test_sim.hex "$_c_size" >/dev/null &&
                     "$_py" "$_repo/dme_klr/live/asm_full.py" "--$_cpu" "$_c_dis/$_xlsx" --out asm_full.json >/dev/null ) &&
                   [ -s "$_tmp/asm_instr.hex" ] && [ -s "$_tmp/test_sim.hex" ] && [ -s "$_tmp/asm_full.json" ]; then
                    for _f in "${_c_files[@]}"; do mv -f "$_tmp/$_f" "$_dir/$_f"; done
                else
                    echo "  asm_select: failed to generate tables from $_xlsx" >&2
                    _rc=1
                fi
                rm -rf "$_tmp"
            fi
            rmdir "$_lock"
            [ "$_rc" = "0" ] || return 1
        fi
        _sel="$_dir/"
    fi

    if [ "$_cpu" = dme ]; then DME_ASM_SEL="$_sel"; else KLR_ASM_SEL="$_sel"; fi
    echo "  $_NAME ASM: $_sel"
    eval "$_arr+=(\"-D${_NAME}_ASM_DIR=\\\"\${_sel%/}/\\\"\")"
}

dme_asm_select() { _asm_select dme "$@"; }
klr_asm_select() { _asm_select klr "$@"; }
