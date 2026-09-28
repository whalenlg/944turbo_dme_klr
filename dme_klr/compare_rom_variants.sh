#!/usr/bin/env bash
# =============================================================================
#  compare_rom_variants.sh — run multiple ROM-variant test suites back to
#  back and diff their PASS/WARN/FAIL results.
#
#  run86.sh / run89.sh / run_carpokes.sh (and run_all.sh underneath them)
#  all write to the same fixed output paths (tmp/dme_klr/dash_logs,
#  tmp/dme_klr/v_dash_logs) regardless of which ROM ran, so running them
#  back to back silently overwrites the previous variant's results. This
#  script archives each variant's validation.log/parallel_summary.log/
#  per-test *.log files to its own directory right after that variant's
#  run finishes, then diffs the archived validation.log files across
#  variants so you can see at a glance which tests changed verdict.
#
#  Usage:
#    ./compare_rom_variants.sh [--variants v1,v2,...] [run_all.sh args...]
#
#  Examples:
#    ./compare_rom_variants.sh                    # 86,89,carpokes; both simulators
#    ./compare_rom_variants.sh --iverilog 4        # iverilog only, 4 workers
#    ./compare_rom_variants.sh --variants 86,89    # just those two
#
#  --variants takes a comma-separated subset of: 86 89 carpokes (default:
#  86,89,carpokes). Any other arguments are forwarded verbatim to
#  run_all.sh for every variant run — e.g. --verilator, --iverilog, a
#  worker count — so all variants are compared under identical conditions.
#
#  NOTE: run_all.sh itself starts with `git checkout main && git pull
#  origin main`, so this runs that once per variant.
#
#  Archived per-variant results land in:
#    tmp/dme_klr/rom_compare/<variant>/dash_logs/*.log     (iverilog)
#    tmp/dme_klr/rom_compare/<variant>/v_dash_logs/*.log   (Verilator)
#  (validation.log, parallel_summary.log, and every per-test *.log/
#  *.dash.log — vcd/hex/compiled-binary artifacts are NOT archived, to
#  keep this lightweight; re-run a single variant if you need those for
#  a specific test.)
#
#  Diff tables are written to:
#    tmp/dme_klr/rom_compare/diff_dash_logs.log     (iverilog)
#    tmp/dme_klr/rom_compare/diff_v_dash_logs.log   (Verilator)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Same relative resolution run_dashboard_tests.sh/run_dashboard_parallel.sh
# use, so this lands exactly where those scripts write their logs
# regardless of where the repo happens to be checked out.
_BASE="$(cd "$SCRIPT_DIR" && cd ../../tmp/dme_klr 2>/dev/null || \
         { mkdir -p ../../tmp/dme_klr && cd ../../tmp/dme_klr; } && pwd)"
COMPARE_DIR="$_BASE/rom_compare"
mkdir -p "$COMPARE_DIR"

ALL_VARIANTS=(86 89 carpokes)
VARIANTS=()
RUN_ALL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --variants)
            shift
            IFS=',' read -r -a VARIANTS <<< "${1:-}"
            ;;
        *)
            RUN_ALL_ARGS+=("$1")
            ;;
    esac
    shift
done
[ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=("${ALL_VARIANTS[@]}")

variant_script() {
    case "$1" in
        86)       echo "$SCRIPT_DIR/run86.sh" ;;
        89)       echo "$SCRIPT_DIR/run89.sh" ;;
        carpokes) echo "$SCRIPT_DIR/run_carpokes.sh" ;;
        *)        echo "" ;;
    esac
}

echo "== compare_rom_variants: ${VARIANTS[*]} =="

for v in "${VARIANTS[@]}"; do
    script="$(variant_script "$v")"
    if [ -z "$script" ] || [ ! -x "$script" ]; then
        echo "Unknown or missing variant script for '$v' — skipping (known: ${ALL_VARIANTS[*]})" >&2
        continue
    fi

    echo ""
    echo "== Running $v (${script##*/} ${RUN_ALL_ARGS[*]}) =="
    "$script" "${RUN_ALL_ARGS[@]}"

    dest="$COMPARE_DIR/$v"
    for sim_dir in dash_logs v_dash_logs; do
        if [ -d "$_BASE/$sim_dir" ]; then
            echo "  archiving $sim_dir/*.log -> rom_compare/$v/$sim_dir/"
            mkdir -p "$dest/$sim_dir"
            rm -f "$dest/$sim_dir"/*.log 2>/dev/null || true
            cp "$_BASE/$sim_dir"/*.log "$dest/$sim_dir/" 2>/dev/null || true
        fi
    done
done

# ── Diff table per simulator side ────────────────────────────────────────
diff_side() {
    local sim_dir="$1" label="$2"
    local out="$COMPARE_DIR/diff_${sim_dir}.log"
    local -a present=()
    for v in "${VARIANTS[@]}"; do
        [ -f "$COMPARE_DIR/$v/$sim_dir/validation.log" ] && present+=("$v")
    done
    if [ ${#present[@]} -lt 2 ]; then
        echo ""
        echo "$label: fewer than 2 variants have results — skipping diff"
        return
    fi

    echo ""
    echo "== $label diff (${present[*]}) — writing $out =="
    python3 - "$out" "$COMPARE_DIR" "$sim_dir" "${present[@]}" <<'PYEOF'
import sys

out_path, compare_dir, sim_dir = sys.argv[1], sys.argv[2], sys.argv[3]
variants = sys.argv[4:]

results = {}   # test_name -> {variant: verdict}
for v in variants:
    path = f"{compare_dir}/{v}/{sim_dir}/validation.log"
    with open(path) as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            verdict, name = parts[0], parts[1]
            results.setdefault(name, {})[v] = verdict

lines = []
header = "TEST".ljust(40) + "".join(v.ljust(12) for v in variants) + "DIFFERS?"
lines.append(header)
lines.append("-" * len(header))

differing = 0
for name in sorted(results):
    verdicts = results[name]
    row_verdicts = [verdicts.get(v, "MISSING") for v in variants]
    differs = len(set(row_verdicts)) > 1
    if differs:
        differing += 1
    row = name.ljust(40) + "".join(rv.ljust(12) for rv in row_verdicts) + ("  <-- DIFFERS" if differs else "")
    lines.append(row)

lines.append("")
lines.append(f"{differing} test(s) differ across {len(variants)} variants "
             f"({', '.join(variants)}), {len(results)} total tests seen")

text = "\n".join(lines)
with open(out_path, "w") as f:
    f.write(text + "\n")
print(text)
PYEOF
}

diff_side dash_logs "iverilog"
diff_side v_dash_logs "Verilator"

echo ""
echo "== compare_rom_variants complete — results in $COMPARE_DIR =="
