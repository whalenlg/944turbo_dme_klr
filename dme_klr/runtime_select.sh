#!/bin/bash
# ============================================================
#  runtime_select.sh: sourced by run_dashboard_tests.sh and
#  v_run_dashboard_tests.sh. Lets a test run on the shared
#  RUNTIME_OPTS build (build_runtime.sh) instead of a build of its own.
#
#  runtime_select <verilator|iverilog> <interval_ms> <rom array name> -D...
#    When $DMEKLR_RUNTIME_DIR holds a shared build that can run this test,
#    sets RT_EXE (the binary or .vvp) and RT_ARGS (its +X=<n> options:
#    the test's, from test_opts.py, then the ROM / disassembly paths from
#    the named array of -D flags) and returns 0. Otherwise returns 1 and
#    the caller builds the test as before: no DMEKLR_RUNTIME_DIR, a
#    --DME_DEBUG / --DME_DEEP_DEBUG / --KLR_DEBUG run, Verilator with
#    VCD_ENABLE=1 (the shared binary has no tracing), or a test the shared
#    build can't take (no RPMRAMP).
#  (bash 3.2: no mapfile, no namerefs)
# ============================================================

RT_PATHS="DMEKLR_REPO DME_ROM_DIR DME_ROM_FILE DME_ASM_DIR KLR_ROM_DIR KLR_ROM_FILE KLR_ASM_DIR"

runtime_select() {
    local sim=$1 interval=$2 romvar=$3
    shift 3
    RT_EXE=""
    RT_ARGS=()
    [ -n "$DMEKLR_RUNTIME_DIR" ] || return 1
    local a
    for a in "$@"; do
        case "$a" in -DDME_DEBUG|-DDME_DEEP_DEBUG|-DKLR_DEBUG) return 1 ;; esac
    done
    [ "$sim" = verilator ] && [ "$VCD_ENABLE" = "1" ] && return 1

    local here out fl line
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    out=$(python3 "$here/test_opts.py" resolve --interval "$interval" "$@") || return 1
    case "$out" in *"+RPMRAMP=1"*) ;; *) return 1 ;; esac
    fl=$(printf '%s\n' "$out" | sed -n 's/^files: //p')
    RT_EXE="$DMEKLR_RUNTIME_DIR/dme_klr_sim"
    [ "$fl" = files_cl ] && RT_EXE="${RT_EXE}_cl"
    [ "$sim" = iverilog ] && RT_EXE="$RT_EXE.vvp"
    if [ ! -f "$RT_EXE" ]; then
        echo "  NOTE: no shared build $RT_EXE — building this test on its own"
        RT_EXE=""
        return 1
    fi
    while IFS= read -r line; do
        case "$line" in +*) RT_ARGS+=("$line") ;; esac
    done <<EOF
$out
EOF
    # -DNAME="value" → +NAME=value, for the paths the shared build reads
    local ro name val
    eval "ro=(\"\${${romvar}[@]}\")"
    for a in "${ro[@]}"; do
        case "$a" in -D*=*) ;; *) continue ;; esac
        name="${a#-D}"; name="${name%%=*}"
        val="${a#*=}"; val="${val#\"}"; val="${val%\"}"
        case " $RT_PATHS " in *" $name "*) RT_ARGS+=("+$name=$val") ;; esac
    done
    return 0
}
