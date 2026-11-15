#!/bin/bash
# ============================================================
#  iv_disk_usage.sh — measure the disk space (and time) the iverilog
#  dashboard tests take with each combination of debug flags
#
#  Runs a few tests (default: 5 from the Fuel / FQS group of Appendix A)
#  with run_dashboard_tests.sh under every combination of
#  --KLR_DEBUG, --DME_DEBUG and --DME_DEEP_DEBUG (8 configurations),
#  each configuration in a DMEKLR_TMP of its own so no run overwrites
#  another's dash logs, .log.gz, FST (dash_logs/fst/) or build.
#  Then prints a table per test and configuration (FST, logs, build,
#  total kept, peak while running, wall time) and an estimate for the
#  whole suite (run_dashboard_parallel.sh's ALL_TESTS) from each test's
#  simulated length, since the output grows with simulated time.
#
#  Usage:
#    ./iv_disk_usage.sh [options]
#      -j N            tests run at once (default: CPU cores, at most 8).
#                      One core per test: more than the cores only slows
#                      every test down and skews the wall times.
#      --tests "a b"   the tests to measure (default below)
#      --configs "c d" only these configurations, of:
#                        none klr dme deep dme_deep klr_dme klr_deep all
#                      (deep = --DME_DEEP_DEBUG alone; all = the 3 flags)
#      --sim-s S       run each test for S simulated seconds instead of
#                      its own length (a quick check; the estimate is
#                      scaled from it, and is rougher for it)
#      --out DIR       where it all goes (default $DMEKLR_TMP/iv_disk_usage).
#                      Results of an earlier run there are deleted first.
#      --report-only   don't run anything; print the report again from
#                      the results already in --out
#      --save-rates    also copy the measured rates (DIR/iv_disk_rates.json)
#                      to dme_klr/iv_disk_rates.json, where the dashboard's
#                      RUN REGRESSIONS panel reads its estimates from
#      -h, --help      this text
#
#  Output:  DIR/<config>/dme_klr/<rom>/dash_logs/...  each configuration's files,
#           as the suite leaves them (kept, so you can look at them)
#           DIR/results.tsv   one row per test and configuration
#           DIR/report.txt    the tables printed at the end
#           DIR/iv_disk_rates.json  MB per simulated second per configuration
#  Sizes are what du reports (disk blocks used), in MB of 1024*1024 bytes.
#  "peak" is the most one test had on disk at once while it ran (the raw
#  .log before it is gzipped and the raw VCD before vcd2fst), sampled every
#  2 s, so a debug run needs at least that much free space per worker.
#
#  Each FQS test is 40 s of simulated time: about 26-28 min on its own
#  with no flags (Appendix A), and much longer with the debug flags, so the
#  full measurement (40 runs) takes hours. Try --sim-s 2 first.
# ============================================================

for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_TESTS="$SCRIPT_DIR/run_dashboard_tests.sh"
PARALLEL="$SCRIPT_DIR/run_dashboard_parallel.sh"

ALL_CONFIGS="none klr dme deep dme_deep klr_dme klr_deep all"
config_flags() {
    case "$1" in
        none)     echo "" ;;
        klr)      echo "--KLR_DEBUG" ;;
        dme)      echo "--DME_DEBUG" ;;
        deep)     echo "--DME_DEEP_DEBUG" ;;
        dme_deep) echo "--DME_DEBUG --DME_DEEP_DEBUG" ;;
        klr_dme)  echo "--KLR_DEBUG --DME_DEBUG" ;;
        klr_deep) echo "--KLR_DEBUG --DME_DEEP_DEBUG" ;;
        all)      echo "--KLR_DEBUG --DME_DEBUG --DME_DEEP_DEBUG" ;;
        *)        return 1 ;;
    esac
}

# kilobytes on disk of the given files/dirs (missing ones count 0)
kb_of() {
    local f n=0 k
    for f in "$@"; do
        [ -e "$f" ] || continue
        k=$(du -sk "$f" 2>/dev/null | awk '{ print $1 }')
        n=$(( n + ${k:-0} ))
    done
    echo "$n"
}

# ── One test in one configuration (run by xargs below) ──────────────────────
#   --_job <out> <config> <test>
# Runs the test with DMEKLR_TMP=<out>/<config>, samples its files every 2 s
# for the peak, and writes <out>/<config>/results/<test>.tsv.
if [ "$1" = "--_job" ]; then
    out="$2"; cfg="$3"; test="$4"
    export DMEKLR_TMP="$out/$cfg"
    base="$DMEKLR_TMP/dme_klr"
    logdir="$(source "$SCRIPT_DIR/../paths.sh"; echo "$DMEKLR_LOGS")/dash_logs"   # this ROM pair's folder
    mkdir -p "$DMEKLR_TMP/results" "$DMEKLR_TMP/runner"
    runner_log="$DMEKLR_TMP/runner/$test.runner.log"
    t0=$(date +%s)
    # shellcheck disable=SC2046
    bash "$RUN_TESTS" "$test" $(config_flags "$cfg") > "$runner_log" 2>&1 &
    pid=$!
    peak=0; t_build=""
    while kill -0 "$pid" 2>/dev/null; do
        now=$(kb_of "$logdir/$test.log" "$logdir/$test.log.gz" "$logdir/$test.dash.log" \
                    "$logdir/hex/$test" "$logdir/fst/$test.fst" "$logdir/vcd/$test.vcd")
        [ "$now" -gt "$peak" ] && peak=$now
        if [ -z "$t_build" ] && grep -q "^  Running →" "$runner_log" 2>/dev/null; then
            t_build=$(( $(date +%s) - t0 ))
        fi
        sleep 2
    done
    wait "$pid"; rc=$?
    t1=$(date +%s)
    [ -n "$t_build" ] || t_build=0
    fst=$(kb_of "$logdir/fst/$test.fst")
    # the full log: .log.gz, or the plain .log a debug run keeps
    loggz=$(kb_of "$logdir/$test.log.gz" "$logdir/$test.log")
    dash=$(kb_of "$logdir/$test.dash.log")
    other=$(kb_of "$logdir/hex/$test" "$logdir/vcd/$test.vcd" "$logdir/vcd/$test.vcd.gz")
    build=$(kb_of "$base/iverilog_vvp/dash_klr_$test.vvp")
    final=$(( fst + loggz + dash + other ))
    [ "$final" -gt "$peak" ] && peak=$final
    # uncompressed size of the full .log (gzip -l wraps above 4 GB, so read it)
    raw=0
    if [ -f "$logdir/$test.log.gz" ]; then raw=$(( $(gzip -dc "$logdir/$test.log.gz" | wc -c) / 1024 ))
    elif [ -f "$logdir/$test.log" ]; then raw=$(kb_of "$logdir/$test.log"); fi
    status=ok
    [ "$rc" -eq 0 ] || status="exit$rc"
    grep -q "SIM FAILED\|COMPILE FAILED" "$runner_log" && status=failed
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$cfg" "$test" "$status" "$fst" "$loggz" "$dash" "$other" "$build" "$final" "$peak" "$raw" \
        "$t_build" "$(( t1 - t0 ))" > "$DMEKLR_TMP/results/$test.tsv"
    printf "  [%s] %-8s %-24s %4ds  %s\n" "$(date +%H:%M:%S)" "$cfg" "$test" "$(( t1 - t0 ))" "$status"
    exit 0
fi

# ── Options ─────────────────────────────────────────────────────────────────
source "$SCRIPT_DIR/../paths.sh"   # DMEKLR_REPO, DMEKLR_TMP
_ncpu=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
JOBS=$(( _ncpu > 8 ? 8 : _ncpu ))
TESTS="ramp_to_6000_FQS0 ramp_to_6000_FQS7 cl_ramp_to_6000_FQS0 cl_ramp_to_6000_FQS3 cl_ramp_to_6000_FQS7"
CONFIGS="$ALL_CONFIGS"
SIM_S=""
OUT="$DMEKLR_TMP/iv_disk_usage"
REPORT_ONLY=0
SAVE_RATES=0
while [ $# -gt 0 ]; do
    case "$1" in
        -j)            JOBS="$2"; shift ;;
        -j*)           JOBS="${1#-j}" ;;
        --tests)       TESTS="$2"; shift ;;
        --configs)     CONFIGS="$2"; shift ;;
        --sim-s)       SIM_S="$2"; shift ;;
        --out)         OUT="$2"; shift ;;
        --report-only) REPORT_ONLY=1 ;;
        --save-rates)  SAVE_RATES=1 ;;
        *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
    esac
    shift
done
for c in $CONFIGS; do
    config_flags "$c" >/dev/null || { echo "Unknown configuration: $c (one of: $ALL_CONFIGS)" >&2; exit 1; }
done
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# Each test's own simulated length in s (its -DSIM_TIME in the single-test
# case entry of run_dashboard_tests.sh; 40 s when it has none, the
# testbench default; --end-s minus --start-s for the replay test). The same
# table run_dashboard_parallel.sh orders its tests by.
sim_seconds_table() {
    awk '
        /^[[:space:]]+[A-Za-z0-9_]+\)[[:space:]]+run_(replay_)?test / {
            name = $1; sub(/\)$/, "", name)
            secs = 40
            if (match($0, /-DSIM_TIME=[0-9]+/))
                secs = substr($0, RSTART + 11, RLENGTH - 11) / 1e9
            if (match($0, /--end-s [0-9.]+/)) {
                secs = substr($0, RSTART + 8, RLENGTH - 8)
                if (match($0, /--start-s [0-9.]+/))
                    secs -= substr($0, RSTART + 10, RLENGTH - 10)
            }
            print name, secs
        }' "$RUN_TESTS"
}
# the full suite: run_dashboard_parallel.sh's ALL_TESTS
all_tests() {
    awk '/^ALL_TESTS=\(/ { on = 1; next } on && /^\)/ { exit } on' "$PARALLEL" | tr -s ' \t' '\n' | grep -v '^$'
}

if [ "$REPORT_ONLY" = "0" ]; then
    for t in $TESTS; do
        sim_seconds_table | awk -v t="$t" '$1 == t { f = 1 } END { exit !f }' \
            || { echo "Unknown test: $t (not in $RUN_TESTS)" >&2; exit 1; }
    done
    command -v iverilog >/dev/null || { echo "iverilog not found" >&2; exit 1; }
    command -v vcd2fst >/dev/null || echo "WARNING: vcd2fst (GTKWave) not found — no FST files will be written, so the FST column will be 0"

    if [ -n "$SIM_S" ]; then
        export DMEKLR_SIM_TIME_NS
        DMEKLR_SIM_TIME_NS=$(awk -v s="$SIM_S" 'BEGIN { printf "%d", s * 1e9 }')
    else
        unset DMEKLR_SIM_TIME_NS
    fi
    # the shared build isn't used: every test builds on its own, as it does
    # under a debug flag, so all configurations are timed the same way
    unset DMEKLR_RUNTIME_DIR

    for c in $CONFIGS; do rm -rf "${OUT:?}/$c"; done
    rm -f "$OUT/results.tsv" "$OUT/report.txt"
    n_runs=$(( $(echo $CONFIGS | wc -w) * $(echo $TESTS | wc -w) ))
    echo "============================================================"
    echo "  iverilog disk usage: $(echo $TESTS | wc -w) tests x $(echo $CONFIGS | wc -w) configurations = $n_runs runs, $JOBS at a time"
    echo "  Tests   : $TESTS"
    echo "  Configs : $CONFIGS"
    [ -n "$SIM_S" ] && echo "  Sim time: ${SIM_S} s each (--sim-s)"
    echo "  Output  : $OUT"
    echo "  Started : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================"

    # Ctrl-C: stop every test (and its vvp), not just xargs
    kill_tree() {
        local c
        for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done
        kill -TERM "$1" 2>/dev/null
    }
    trap 'echo "  Interrupted"; kill_tree $$; exit 130' INT TERM

    T_START=$(date +%s)
    # The longest-running runs first: the deepest debug configurations,
    # then the longest tests
    {
        for c in all klr_deep dme_deep deep klr_dme dme klr none; do
            case " $CONFIGS " in *" $c "*) ;; *) continue ;; esac
            for t in $TESTS; do echo "$c $t"; done
        done
    } | xargs -P "$JOBS" -L 1 bash "$SCRIPT_DIR/${0##*/}" --_job "$OUT" &
    wait $!
    T_WALL=$(( $(date +%s) - T_START ))
    echo "$T_WALL" > "$OUT/wall_s"
    echo "$SIM_S" > "$OUT/sim_s"
    echo "$JOBS" > "$OUT/jobs"
fi
[ -f "$OUT/sim_s" ] && SIM_S=$(cat "$OUT/sim_s")
[ "$REPORT_ONLY" = "1" ] && [ -f "$OUT/jobs" ] && JOBS=$(cat "$OUT/jobs")

# ── Report ──────────────────────────────────────────────────────────────────
{
    printf "config\ttest\tstatus\tfst_kb\tlog_gz_kb\tdash_log_kb\tother_kb\tbuild_kb\tkept_kb\tpeak_kb\traw_log_kb\tbuild_s\twall_s\n"
    for c in $ALL_CONFIGS; do
        cat "$OUT/$c"/results/*.tsv 2>/dev/null
    done
} > "$OUT/results.tsv"

sim_seconds_table > "$OUT/sim_seconds.txt"
all_tests > "$OUT/all_tests.txt"
python3 - "$OUT" "${SIM_S:-}" "$JOBS" "$(cat "$OUT/wall_s" 2>/dev/null)" <<'PY' | tee "$OUT/report.txt"
import csv, sys, os
out, sim_s, jobs, wall = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
CONFIGS = ["none", "klr", "dme", "deep", "dme_deep", "klr_dme", "klr_deep", "all"]
LABEL = {"none": "no flags", "klr": "KLR", "dme": "DME", "deep": "DEEP",
         "dme_deep": "DME+DEEP", "klr_dme": "KLR+DME", "klr_deep": "KLR+DEEP",
         "all": "KLR+DME+DEEP"}
own = {}
for line in open(os.path.join(out, "sim_seconds.txt")):
    n, s = line.split()
    own[n] = float(s)
suite = [t for t in open(os.path.join(out, "all_tests.txt")).read().split() if t]
rows = list(csv.DictReader(open(os.path.join(out, "results.tsv")), delimiter="\t"))
if not rows:
    print("No results in", out); sys.exit(0)
for r in rows:
    for k in r:
        if k.endswith("_kb") or k.endswith("_s"):
            r[k] = float(r[k])
    r["sim"] = float(sim_s) if sim_s else own.get(r["test"], 40.0)

mb = lambda kb: kb / 1024.0
def fmt_mb(kb):
    m = mb(kb)
    return "%.0f" % m if m >= 100 else "%.1f" % m
def fmt_gb(kb):
    return "%.1f" % (kb / 1024.0 / 1024.0)
def fmt_t(s):
    s = int(round(s))
    return "%dh%02dm" % (s // 3600, (s % 3600) // 60) if s >= 3600 else "%dm%02ds" % (s // 60, s % 60)

print()
print("Per test (MB; logs = full log (.log.gz, or a debug run's plain .log) + .dash.log + hex dumps; kept = FST + logs;")
print("peak = most on disk at once while it ran; raw log = the .log before gzip)")
if sim_s:
    print("Every test ran for %s simulated s (--sim-s)." % sim_s)
print()
hdr = "%-13s %-22s %8s %8s %8s %8s %9s %7s %8s  %s" % (
    "config", "test", "FST", "logs", "kept", "peak", "raw log", "build", "wall", "")
print(hdr); print("-" * len(hdr))
present = [c for c in CONFIGS if any(r["config"] == c for r in rows)]
for c in present:
    for r in [r for r in rows if r["config"] == c]:
        logs = r["log_gz_kb"] + r["dash_log_kb"] + r["other_kb"]
        print("%-13s %-22s %8s %8s %8s %8s %9s %7s %8s  %s" % (
            LABEL[c], r["test"], fmt_mb(r["fst_kb"]), fmt_mb(logs), fmt_mb(r["kept_kb"]),
            fmt_mb(r["peak_kb"]), fmt_mb(r["raw_log_kb"]), fmt_mb(r["build_kb"]),
            fmt_t(r["wall_s"]), "" if r["status"] == "ok" else r["status"]))
    print()

print("Per configuration, for the %s measured test(s) together:" % len({r["test"] for r in rows}))
print()
hdr = "%-13s %8s %8s %8s %9s %8s %10s %9s" % ("config", "FST", "logs", "kept", "max peak", "build", "wall sum", "MB/sim s")
print(hdr); print("-" * len(hdr))
est = {}
for c in present:
    rs = [r for r in rows if r["config"] == c and r["status"] == "ok"] or [r for r in rows if r["config"] == c]
    fst = sum(r["fst_kb"] for r in rs)
    kept = sum(r["kept_kb"] for r in rs)
    logs = kept - fst
    sim = sum(r["sim"] for r in rs)
    simwall = sum(max(r["wall_s"] - r["build_s"], 0) for r in rs)
    build_s = sum(r["build_s"] for r in rs) / len(rs)
    build_kb = sum(r["build_kb"] for r in rs) / len(rs)
    peak_rate = max(r["peak_kb"] / r["sim"] for r in rs)
    print("%-13s %8s %8s %8s %9s %8s %10s %9.1f" % (
        LABEL[c], fmt_mb(fst), fmt_mb(logs), fmt_mb(kept), fmt_mb(max(r["peak_kb"] for r in rs)),
        fmt_mb(sum(r["build_kb"] for r in rs)), fmt_t(sum(r["wall_s"] for r in rs)), mb(kept) / sim))
    est[c] = dict(fst=fst / sim, kept=kept / sim, wall=simwall / sim, build_s=build_s,
                  build_kb=build_kb, peak=peak_rate)
print()

tot_sim = sum(own.get(t, 40.0) for t in suite)
longest = sorted((own.get(t, 40.0) for t in suite), reverse=True)
print("Whole suite estimate: %d tests, %.0f simulated s in all (run_dashboard_parallel.sh's" % (len(suite), tot_sim))
print("ALL_TESTS), scaled from the measured MB and wall time per simulated second.")
print("'peak, %d at once' is the space the %d longest tests need while running side by side;" % (jobs, jobs))
print("add it to 'kept' for the most the run needs free. Wall time assumes %d workers." % jobs)
if sim_s:
    print("Rough: the measured runs were %s s long (the ramp squeezed into that time), and" % sim_s)
    print("startup and the build weigh more in a short run. Wall time isn't scaled from a")
    print("short run; 'wall' is the time against the no-flag runs of this measurement")
    print("(the manuals' rate with no flags: about 40 s per simulated second).")
print()
hdr = "%-13s %9s %9s %9s %17s %12s %12s" % ("config", "FST GB", "logs GB", "kept GB", "peak, %d at once" % jobs, "builds GB", "wall")
print(hdr); print("-" * len(hdr))
for c in present:
    e = est[c]
    fst = e["fst"] * tot_sim
    kept = e["kept"] * tot_sim
    peak = e["peak"] * sum(longest[:jobs])
    builds = e["build_kb"] * len(suite)
    cpu = e["wall"] * tot_sim + e["build_s"] * len(suite)
    if sim_s:
        base = est.get("none")
        wall_s = "x%.2f" % ((e["wall"] + e["build_s"] / float(sim_s)) / (base["wall"] + base["build_s"] / float(sim_s))) if base else "—"
    else:
        wall_s = fmt_t(cpu / max(jobs, 1))
    print("%-13s %9s %9s %9s %17s %12s %12s" % (
        LABEL[c], fmt_gb(fst), fmt_gb(kept - fst), fmt_gb(kept), fmt_gb(peak), fmt_gb(builds), wall_s))
print()

# The rates, for the dashboard's RUN REGRESSIONS panel (dme_klr/iv_disk_rates.json,
# served by the bridge): MB per simulated second for each flag combination
FLAGS = {"none": [], "klr": ["KLR_DEBUG"], "dme": ["DME_DEBUG"], "deep": ["DME_DEEP_DEBUG"],
         "dme_deep": ["DME_DEBUG", "DME_DEEP_DEBUG"], "klr_dme": ["DME_DEBUG", "KLR_DEBUG"],
         "klr_deep": ["DME_DEEP_DEBUG", "KLR_DEBUG"], "all": ["DME_DEBUG", "DME_DEEP_DEBUG", "KLR_DEBUG"]}
import json, time
rates = {"format": "dme-klr-iv-disk-rates", "version": 1,
         "about": "iverilog dashboard tests: MB on disk per simulated second for each debug flag "
                  "combination (key: the flags, sorted, joined by +; '' = none). kept = FST + the full log "
                  "(.log.gz; a debug run keeps its plain .log) "
                  "+ .dash.log + hex dumps after the test; peak = the most one test has on disk while it "
                  "runs (raw .log and VCD before gzip / vcd2fst); build_mb = its own .vvp. "
                  "Made by dme_klr/iv_disk_usage.sh.",
         "measured": {"date": time.strftime("%Y-%m-%d"), "tests": sorted({r["test"] for r in rows}),
                      "sim_s": float(sim_s) if sim_s else None},
         "configs": {}}
for c in present:
    e = est[c]
    rates["configs"]["+".join(FLAGS[c])] = {
        "kept_mb_per_sim_s": round(e["kept"] / 1024, 3), "fst_mb_per_sim_s": round(e["fst"] / 1024, 3),
        "peak_mb_per_sim_s": round(e["peak"] / 1024, 3), "build_mb": round(e["build_kb"] / 1024, 2),
        **({} if sim_s else {"wall_s_per_sim_s": round(e["wall"], 1)})}
json.dump(rates, open(os.path.join(out, "iv_disk_rates.json"), "w"), indent=1)
if wall:
    print("This measurement took %s with %d at a time. Files: %s" % (fmt_t(float(wall)), jobs, out))
PY

if [ "$SAVE_RATES" = "1" ] && [ -f "$OUT/iv_disk_rates.json" ]; then
    cp "$OUT/iv_disk_rates.json" "$SCRIPT_DIR/iv_disk_rates.json"
    echo "Rates saved to $SCRIPT_DIR/iv_disk_rates.json (the RUN REGRESSIONS panel's estimates)"
fi
