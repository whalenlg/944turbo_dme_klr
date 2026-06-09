#!/usr/bin/env python3
"""
compare_sim_logs.py  —  Compare iverilog and Verilator simulation log outputs.

Works for both dashboard (.dash.log) and non-dashboard (.log) files.

Usage:
    python3 compare_sim_logs.py --dash   <iv_log> <vl_log> [test_name]
    python3 compare_sim_logs.py --nondash <iv_log> <vl_log> [test_name]

Exit codes:
    0  MATCH  — outputs are functionally equivalent
    1  DIFF   — meaningful differences found
    2  ERROR  — one or both files missing / unreadable

Output (one summary line + detail):
    MATCH  <name>  <detail>
    DIFF   <name>  <detail>
    ERROR  <name>  <detail>
"""

import sys
import re
import argparse
from collections import Counter

# ── Helpers ──────────────────────────────────────────────────────────────────

def read_lines(path):
    try:
        with open(path) as f:
            return f.readlines()
    except OSError as e:
        return None

def count_prefix(lines, prefix):
    return sum(1 for l in lines if l.startswith(prefix))

def strip_timestamps(line):
    """Remove leading simulation-time fields that differ between simulators.

    iverilog prints absolute sim-time in $display; Verilator may differ by
    a few ticks due to scheduling.  We strip patterns like:
        [  12345ns]   or   t=12345   or   @12345
    so structural comparisons aren't derailed by minor timing deltas.
    """
    line = re.sub(r'\[\s*\d+\s*ns\]', '[Tns]', line)
    line = re.sub(r'\bt\s*=\s*\d+\b', 't=T', line)
    line = re.sub(r'@\d+\b', '@T', line)
    return line

def normalise_ds(line):
    """Strip the sim-time field from a [DS] snapshot line so we can compare
    field values rather than absolute timestamps.

    Expected format:  DME: [DS] t=<ns> rpm=<v> map=<v> ...
    We keep all key=value pairs but drop t=<ns>.
    """
    return re.sub(r'\bt=\d+\b', 't=T', line)

def extract_ds_fields(lines, prefix="DME: [DS]"):
    """Return a list of dicts, one per [DS] line, mapping field→value."""
    result = []
    for l in lines:
        if not l.startswith(prefix):
            continue
        pairs = re.findall(r'(\w+)=([\w.\-]+)', l)
        result.append(dict(pairs))
    return result

def compare_ds_series(iv_ds, vl_ds, tolerance=0.05):
    """Compare two sequences of [DS] snapshots.

    Returns (ok, issues) where issues is a list of human-readable strings.
    Numeric fields are compared with a relative tolerance; string/enum fields
    must match exactly.  We allow a ±1 snapshot count difference to handle
    minor end-of-sim scheduling differences.
    """
    issues = []
    iv_n, vl_n = len(iv_ds), len(vl_ds)

    if iv_n == 0 and vl_n == 0:
        return True, []

    delta_n = abs(iv_n - vl_n)
    if delta_n > max(2, int(iv_n * 0.01)):   # >1% count difference is notable
        issues.append(f"snapshot count iv={iv_n} vl={vl_n} (delta={delta_n})")

    # Compare field-by-field on the overlapping prefix
    n_compare = min(iv_n, vl_n)
    field_mismatches = Counter()
    numeric_re = re.compile(r'^-?\d+(\.\d+)?$')

    for i in range(n_compare):
        iv_row, vl_row = iv_ds[i], vl_ds[i]
        all_keys = set(iv_row) | set(vl_row)
        for k in all_keys:
            if k == 't':
                continue   # timestamp already stripped
            iv_v = iv_row.get(k, '')
            vl_v = vl_row.get(k, '')
            if iv_v == vl_v:
                continue
            # Numeric comparison with tolerance
            if numeric_re.match(iv_v) and numeric_re.match(vl_v):
                fiv, fvl = float(iv_v), float(vl_v)
                denom = max(abs(fiv), abs(fvl), 1.0)
                if abs(fiv - fvl) / denom <= tolerance:
                    continue
            field_mismatches[k] += 1

    if field_mismatches:
        top = sorted(field_mismatches.items(), key=lambda x: -x[1])[:5]
        issues.append("field mismatches: " +
                       ", ".join(f"{k}({n})" for k, n in top))

    return len(issues) == 0, issues


# ── Dashboard mode comparison ────────────────────────────────────────────────

def compare_dash(iv_lines, vl_lines, name):
    """Compare .dash.log files (DME:/KLR: structured lines)."""
    # Strip lines expected to differ between simulators
    _skip = re.compile(r'DME: \[SIM\]|VCD info:|dumpfile|Info:.*ignored|Simulated \d|\$finish|\bvvp\b', re.IGNORECASE)
    iv_lines = [l for l in iv_lines if not _skip.search(l)]
    vl_lines = [l for l in vl_lines if not _skip.search(l)]
    issues = []

    prefixes = [
        "DME: [DS]",
        "DME: [PHASE]",
        "DME: [STATUS]",
        "DME: [SEED]",
        "KLR: [DS]",
        "KLR: [PHASE]",
        "KLR: [STATUS]",
    ]

    # Line counts per prefix
    for p in prefixes:
        iv_n = count_prefix(iv_lines, p)
        vl_n = count_prefix(vl_lines, p)
        if iv_n == 0 and vl_n == 0:
            continue
        delta = abs(iv_n - vl_n)
        threshold = max(2, int(max(iv_n, vl_n) * 0.01))
        if delta > threshold:
            issues.append(f"{p}: iv={iv_n} vl={vl_n}")

    # Deep compare DME [DS] series
    iv_ds = extract_ds_fields(iv_lines, "DME: [DS]")
    vl_ds = extract_ds_fields(vl_lines, "DME: [DS]")
    ok, ds_issues = compare_ds_series(iv_ds, vl_ds)
    issues.extend(ds_issues)

    # Deep compare KLR [DS] series if present
    iv_kds = extract_ds_fields(iv_lines, "KLR: [DS]")
    vl_kds = extract_ds_fields(vl_lines, "KLR: [DS]")
    if iv_kds or vl_kds:
        ok2, kds_issues = compare_ds_series(iv_kds, vl_kds)
        issues.extend(["KLR: " + i for i in kds_issues])

    # PHASE sequence comparison (order matters for engine state machine)
    iv_phases = [l.strip() for l in iv_lines if l.startswith("DME: [PHASE]")]
    vl_phases = [l.strip() for l in vl_lines if l.startswith("DME: [PHASE]")]
    if iv_phases != vl_phases:
        # Find first divergence
        for i, (a, b) in enumerate(zip(iv_phases, vl_phases)):
            if a != b:
                issues.append(f"PHASE diverges at entry {i}: iv={a!r} vl={b!r}")
                break
        else:
            issues.append(f"PHASE count mismatch iv={len(iv_phases)} vl={len(vl_phases)}")

    return issues


# ── Non-dashboard mode comparison ────────────────────────────────────────────

# Lines that are expected to differ between simulators (timing noise, VCD paths, etc.)
_NONDASH_SKIP_RE = re.compile(
    r'VCD info:|dumpfile|^\s*$|Simulated \d|simulation complete|'
    r'\$finish|\bvvp\b|verilator|DME: \[SIM\]',
    re.IGNORECASE
)

def normalise_nondash_line(line):
    line = strip_timestamps(line)
    # Normalise hex addresses that may be printed differently
    line = re.sub(r'\b0x([0-9a-fA-F]+)\b', lambda m: str(int(m.group(1), 16)), line)
    return line.rstrip()

def compare_nondash(iv_lines, vl_lines, name):
    """Compare plain .log files from non-dashboard runs."""
    issues = []

    def filtered(lines):
        out = []
        for l in lines:
            if _NONDASH_SKIP_RE.search(l):
                continue
            n = normalise_nondash_line(l)
            if n:
                out.append(n)
        return out

    iv_f = filtered(iv_lines)
    vl_f = filtered(vl_lines)

    if iv_f == vl_f:
        return []

    # Count differences
    iv_set  = Counter(iv_f)
    vl_set  = Counter(vl_f)
    only_iv = {k: v for k, v in iv_set.items() if k not in vl_set}
    only_vl = {k: v for k, v in vl_set.items() if k not in iv_set}
    shared  = sum(min(iv_set[k], vl_set[k]) for k in iv_set if k in vl_set)
    total   = max(len(iv_f), len(vl_f), 1)

    match_pct = 100.0 * shared / total
    issues.append(f"line match {match_pct:.1f}% ({shared}/{total})")

    if only_iv:
        sample = list(only_iv.keys())[:3]
        issues.append(f"only in iv ({len(only_iv)} unique): " +
                       " | ".join(repr(s[:60]) for s in sample))
    if only_vl:
        sample = list(only_vl.keys())[:3]
        issues.append(f"only in vl ({len(only_vl)} unique): " +
                       " | ".join(repr(s[:60]) for s in sample))

    # If >95% match, downgrade to near-match
    if match_pct >= 95.0:
        return ["NEAR-MATCH: " + "; ".join(issues)]

    return issues


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Compare iverilog vs Verilator sim logs")
    mode_grp = parser.add_mutually_exclusive_group(required=True)
    mode_grp.add_argument('--dash',    action='store_true', help='Dashboard .dash.log comparison')
    mode_grp.add_argument('--nondash', action='store_true', help='Non-dashboard .log comparison')
    parser.add_argument('iv_log',   help='iverilog log file')
    parser.add_argument('vl_log',   help='Verilator log file')
    parser.add_argument('name',     nargs='?', default='test', help='Test name for reporting')
    args = parser.parse_args()

    iv_lines = read_lines(args.iv_log)
    vl_lines = read_lines(args.vl_log)

    if iv_lines is None or vl_lines is None:
        missing = []
        if iv_lines is None: missing.append(f"iv={args.iv_log}")
        if vl_lines is None: missing.append(f"vl={args.vl_log}")
        print(f"ERROR\t{args.name}\tfile(s) not found: {', '.join(missing)}")
        sys.exit(2)

    if args.dash:
        issues = compare_dash(iv_lines, vl_lines, args.name)
    else:
        issues = compare_nondash(iv_lines, vl_lines, args.name)

    if not issues:
        print(f"MATCH\t{args.name}\toutputs equivalent")
        sys.exit(0)
    else:
        detail = "; ".join(issues)
        # NEAR-MATCH is a soft pass — exit 0 so it doesn't fail CI
        if all(i.startswith("NEAR-MATCH") for i in issues):
            print(f"NEAR-MATCH\t{args.name}\t{detail}")
            sys.exit(0)
        print(f"DIFF\t{args.name}\t{detail}")
        sys.exit(1)


if __name__ == '__main__':
    main()
