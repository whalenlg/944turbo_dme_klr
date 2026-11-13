#!/bin/bash
# ============================================================
#  runtime_equiv.sh: check that the run-time-options build
#  (build_runtime.sh) gives the same simulation as the usual
#  one-build-per-test flow (v_run_dashboard_tests.sh), test by test.
#
#  For each test: build it the usual way (its -D flags), run it, run the
#  shared RUNTIME_OPTS binary with the same test as +X=<n>
#  (test_opts.py plusargs), and compare the two outputs line for line
#  (only the simulator's own report and the source line of $finish may
#  differ). Two $display lines that come from separate always blocks at
#  the same simulated time have no set order: Verilator picks one per
#  build. A test whose output differs only in such an order (the same
#  lines, each at the same time) is reported as "order" and passes.
#
#  Usage: runtime_equiv.sh [--sim-ms N] [--shard I/N] [--out DIR] [test ...]
#    --sim-ms N   stop every test at N ms (its options as for the full
#                 run, and the RPM ramp over N ms); default: full length
#    --shard I/N  only every Nth test of the list, from the Ith (1-based)
#    test ...     these tests (default: every test in the runner)
#  Exit status: the number of tests that differ or fail (0 = all same).
# ============================================================
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"   # DMEKLR_REPO, DMEKLR_TMP

SIM_MS=""
SHARD=""
OUT="$DMEKLR_TMP/dme_klr/runtime_equiv"
TESTS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --sim-ms) SIM_MS="$2"; shift 2 ;;
        --shard)  SHARD="$2"; shift 2 ;;
        --out)    OUT="$2"; shift 2 ;;
        -*) echo "runtime_equiv.sh: unknown option $1" >&2; exit 2 ;;
        *)  TESTS+=("$1"); shift ;;
    esac
done
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
cd "$SCRIPT_DIR"

[ ${#TESTS[@]} -gt 0 ] || mapfile -t TESTS < <(python3 test_opts.py tests)
if [ -n "$SHARD" ]; then
    i=${SHARD%/*}; n=${SHARD#*/}; sel=()
    for k in "${!TESTS[@]}"; do [ $(( k % n )) -eq $(( i - 1 )) ] && sel+=("${TESTS[$k]}"); done
    TESTS=("${sel[@]}")
fi
echo "tests: ${TESTS[*]}"

bash "$SCRIPT_DIR/build_runtime.sh" --out "$OUT/rt" || exit 100

# The usual per-test build: v_run_dashboard_tests.sh's Verilator command
build_one() {   # <name> <file list> <exe> -D...
    local name=$1 fl=$2 exe=$3; shift 3
    rm -rf "$OUT/obj_$name"
    verilator --binary -j "$(nproc 2>/dev/null || echo 2)" \
        -o "$exe" --Mdir "$OUT/obj_$name" -f "$fl" \
        +incdir+rtl/verilog +incdir+bench/verilog \
        +incdir+../dme/rtl/verilog +incdir+../dme/bench/verilog \
        +incdir+../klr/rtl/verilog +incdir+../klr/bench/verilog \
        --top-module dme_klr_dashboard_tb \
        -DVLT_SIM -DDASHBOARD_TB -DDME_KLR_COMBINED \
        -Wno-fatal -Wno-PINMISSING -Wno-IMPLICIT -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
        -Wno-REDEFMACRO -Wno-DEFOVERRIDE -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-MULTIDRIVEN \
        "-DDMEKLR_REPO=\"$DMEKLR_REPO/\"" "$@" > "$OUT/$name.build.log" 2>&1
}

# What may differ: Verilator's run report, and $finish's source line
norm() {
    grep -v -e '^- ' -e '^\s*$' "$1" | sed -e 's/dashboard_tb\.v:[0-9]*:/dashboard_tb.v:/'
}

# The lines of a log, each with the time it was printed at (the t=<ms> of
# the last line that had one; a [DS] snapshot gives its own), sorted:
# equal for two logs whose lines differ only in their order within a
# time step
by_time() {
    norm "$1" | awk '{
        if (match($0, /t=[0-9]+ ms/)) t = substr($0, RSTART + 2, RLENGTH - 5)
        else if (match($0, /\[DS\] [0-9]+/)) t = substr($0, RSTART + 5, RLENGTH - 5)
        print t "\t" $0 }' | LC_ALL=C sort
}

# Wall-clock seconds, to the millisecond where the shell can
now() { if [ -n "${EPOCHREALTIME:-}" ]; then echo "${EPOCHREALTIME/,/.}"; else date +%s; fi; }
since() { awk -v a="$1" -v b="$(now)" 'BEGIN { printf "%.1f", b - a }'; }

fails=0 t_old=0 t_rt=0
for t in "${TESTS[@]}"; do
    mapfile -t D < <(python3 test_opts.py defines "$t")
    extra=()
    [ -n "$SIM_MS" ] && extra=("-DSIM_TIME=$(( SIM_MS * 1000000 ))")
    mapfile -t P < <(python3 test_opts.py plusargs "$t" "${extra[@]}")
    fl=$(printf '%s\n' "${P[@]}" | sed -n 's/^files: //p')
    mapfile -t PA < <(printf '%s\n' "${P[@]}" | grep '^+')
    sc=$(printf '%s\n' "${PA[@]}" | sed -n 's/^+STEP_CLOCKS=//p')
    iv=$(printf '%s\n' "${PA[@]}" | sed -n 's/^+DASH_INTERVAL_MS=//p')
    exe_rt="$OUT/rt/dme_klr_sim"; [ "$fl" = files_cl ] && exe_rt="$OUT/rt/dme_klr_sim_cl"
    W="$OUT/$t"; rm -rf "$W"; mkdir -p "$W/old" "$W/rt"

    t0=$SECONDS
    if ! build_one "$t" "$fl" "$OUT/$t.exe" "${D[@]}" "${extra[@]}" \
            "-DSTEP_CLOCKS=$sc" "-DDASH_INTERVAL_MS=$iv"; then
        echo "FAIL  $t: per-test build failed (see $OUT/$t.build.log)"; fails=$((fails + 1)); continue
    fi
    ( cd "$W/old" && s=$(now) && "$OUT/$t.exe" +vcd=/dev/null > ../old.log 2>&1; since "$s" > ../old.secs ) &
    ( cd "$W/rt"  && s=$(now) && "$exe_rt" +vcd=/dev/null "${PA[@]}" "+DMEKLR_REPO=$DMEKLR_REPO/" > ../rt.log 2>&1; since "$s" > ../rt.secs ) &
    wait
    # how long each simulator took (they run side by side, one core each)
    speed="per-test $(cat "$W/old.secs")s, shared $(cat "$W/rt.secs")s"
    t_old=$(awk -v a="$t_old" -v b="$(cat "$W/old.secs")" 'BEGIN { print a + b }')
    t_rt=$(awk -v a="$t_rt" -v b="$(cat "$W/rt.secs")" 'BEGIN { print a + b }')
    rm -rf "$OUT/obj_$t" "$OUT/$t.exe"
    if [ ! -s "$W/old.log" ]; then
        echo "FAIL  $t: no output"; fails=$((fails + 1))
    elif cmp -s <(norm "$W/old.log") <(norm "$W/rt.log"); then
        echo "same  $t ($(wc -l < "$W/old.log") lines, $((SECONDS - t0)) s; $speed)"
    elif cmp -s <(by_time "$W/old.log") <(by_time "$W/rt.log"); then
        echo "order $t ($(wc -l < "$W/old.log") lines; same lines, some in another order within a time step; $speed)"
        diff -U2 <(norm "$W/old.log") <(norm "$W/rt.log") | head -30 | cut -c1-160
    else
        echo "DIFF  $t: diff $W/old.log $W/rt.log"
        diff -U2 <(norm "$W/old.log") <(norm "$W/rt.log") | head -40 | cut -c1-160
        fails=$((fails + 1))
    fi
done
echo "${#TESTS[@]} test(s), $fails differ"
awk -v a="$t_old" -v b="$t_rt" 'BEGIN { printf "simulation time: per-test builds %.0f s, shared build %.0f s (%+.1f%%)\n", a, b, a > 0 ? 100 * (b - a) / a : 0 }'
exit $fails
