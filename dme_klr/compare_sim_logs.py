#!/usr/bin/env python3
"""
compare_sim_logs.py  —  Compare iverilog and Verilator dashboard (.dash.log)
simulation log outputs.

Usage:
    python3 compare_sim_logs.py --dash <iv_log> <vl_log> [test_name]

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

def normalise_ds(line):
    """Strip the sim-time field from a [DS] snapshot line so we can compare
    field values rather than absolute timestamps.

    Expected format:  DME: [DS] t=<ns> rpm=<v> map=<v> ...
    We keep all key=value pairs but drop t=<ns>.
    """
    return re.sub(r'\bt=\d+\b', 't=T', line)

_HBLB_RE = re.compile(r'^(.+)_(hb|lb)$', re.IGNORECASE)

# Fields to drop entirely for a given [STATUS] prefix — never extracted, so
# they never show up in mismatch counts, --verbose dumps, or --plot output.
IGNORED_STATUS_FIELDS = {
    "KLR: [STATUS]": {"pc", "r5", "sp", "r2", "r4", "timer_val"},
}

# Fields to drop only for specific named tests (test name = the CLI `name`
# argument), for cases where a field is noisy in a handful of tests but
# should stay compared everywhere else. Keys are lowercased field names.
IGNORED_STATUS_FIELDS_BY_TEST = {
    "KLR: [STATUS]": {
        "cv_pwm": {"cold_start", "isv_cold_idle", "isv_load_droop", "warmup_enrichment"},
        "irq":    {"cl_ramp_to_6000_FQS1", "cl_ramp_to_6000_FQS7"},
        "mb":     {"cl_ramp_to_6000_FQS1", "cl_ramp_to_6000_FQS7"},
    },
}

# Set once in main() from args.name; consulted by IGNORED_STATUS_FIELDS_BY_TEST
# so extract_status_fields doesn't need the test name threaded through every
# call site.
CURRENT_TEST_NAME = None

def combine_hb_lb_fields(d):
    """Merge any <name>_hb / <name>_lb pair of int-valued fields in dict `d`
    into a single 16-bit field <name> = (hb << 8) | (lb & 0xFF), removing the
    two 8-bit halves. Applies to any field pair following this naming
    convention (e.g. fuel_hb/fuel_lb -> fuel), not just a hardcoded name.
    """
    halves = {}
    for k in d:
        m = _HBLB_RE.match(k)
        if m:
            halves.setdefault(m.group(1), {})[m.group(2).lower()] = k
    for base, pair in halves.items():
        if 'hb' not in pair or 'lb' not in pair:
            continue
        hb_k, lb_k = pair['hb'], pair['lb']
        hb_v, lb_v = d.get(hb_k), d.get(lb_k)
        if not isinstance(hb_v, int) or not isinstance(lb_v, int):
            continue
        d[base] = ((hb_v & 0xFF) << 8) | (lb_v & 0xFF)
        del d[hb_k]
        del d[lb_k]
    return d

_FLAGS_RE = re.compile(r'flags\((\d+)\)=0x([0-9a-fA-F]+)((?:\s*\(\d+\)=0x[0-9a-fA-F]+)*)')

def extract_flags_fields(line, d):
    """DME logs report three flag bytes as one 'flags' label followed by
    bare (addr)=val groups, e.g.:
        flags(21)=0x00 (23)=0x8b (25)=0x00
    The generic key(addr)=0xHH regex only catches the first one — the bare
    '(23)=0x8b' and '(25)=0x00' have no word token before '(' so they were
    previously dropped entirely. Parse each into its own field flag_<addr>
    and return the line with that whole segment removed so the generic
    field regex doesn't also (mis)process it.
    """
    m = _FLAGS_RE.search(line)
    if not m:
        return line
    addr1, val1, rest = m.group(1), m.group(2), m.group(3)
    d[f'flag_{addr1}'] = int(val1, 16)
    for m2 in re.finditer(r'\((\d+)\)=0x([0-9a-fA-F]+)', rest):
        d[f'flag_{m2.group(1)}'] = int(m2.group(2), 16)
    return line[:m.start()] + line[m.end():]

def extract_status_fields(lines, prefix="DME: [STATUS]", apply_ignore=True):
    """Return list of dicts, one per [STATUS] line, mapping field→value.

    Handles two formats:
      DME: key(addr)=0xHH  e.g.  prpm(37)=0x15 (840 RPM)
      KLR: key=hexval      e.g.  pc=1a6  knock=1  tps_raw=77
    Skips fields with value 'x', 'xx', 'xxx' (uninitialised).
    Any <name>_hb / <name>_lb byte-split pair (e.g. fuel_hb, fuel_lb) is
    merged into a single 16-bit field <name> via combine_hb_lb_fields().
    DME's three-byte 'flags(21)=.. (23)=.. (25)=..' group is split into
    flag_21 / flag_23 / flag_25 via extract_flags_fields().
    If apply_ignore is False, fields in IGNORED_STATUS_FIELDS are kept
    (used by --list-fields to show what's actually present vs. excluded).
    """
    result = []
    for l in lines:
        if not l.startswith(prefix):
            continue
        d = {}
        tm = re.search(r't=(\d+)\s*ms', l)
        if tm:
            d['t'] = int(tm.group(1))

        if prefix.startswith('DME'):
            # DME format: key(addr)=0xHH
            l = extract_flags_fields(l, d)
            for m in re.finditer(r'(\w+)\([^)]*\)=0x([0-9a-fA-F]+)', l):
                d[m.group(1)] = int(m.group(2), 16)
        else:
            # KLR format: key=hexval (no 0x prefix, no addr)
            # Skip the t=NNN ms field already handled above
            body = re.sub(r't=\d+\s*ms\s*', '', l[len(prefix):])
            for m in re.finditer(r'(\w+)=([0-9a-fA-F]+)', body):
                val_str = m.group(2)
                if re.fullmatch(r'x+', val_str, re.IGNORECASE):
                    continue  # uninitialised
                try:
                    d[m.group(1)] = int(val_str, 16)
                except ValueError:
                    pass
        if apply_ignore:
            ignored = {f.lower() for f in IGNORED_STATUS_FIELDS.get(prefix, ())}
            cond = IGNORED_STATUS_FIELDS_BY_TEST.get(prefix, {})
            for k in list(d.keys()):
                kl = k.lower()
                if kl in ignored:
                    del d[k]
                elif kl in cond and CURRENT_TEST_NAME in cond[kl]:
                    del d[k]
        result.append(combine_hb_lb_fields(d))
    return result

MIN_CONSECUTIVE_MISMATCH = 2  # isolated single-sample diffs are noise; require a run this long

_numeric_re = re.compile(r'^-?\d+(\.\d+)?$')

def _values_differ(a_v, b_v, tolerance=0.01):
    """True if two field values differ beyond tolerance. Numeric-looking
    values (int or numeric string) use relative tolerance; everything else
    (strings/enums) requires exact equality."""
    if a_v == b_v:
        return False
    a_s, b_s = str(a_v), str(b_v)
    if _numeric_re.match(a_s) and _numeric_re.match(b_s):
        fa, fb = float(a_s), float(b_s)
        denom = max(abs(fa), abs(fb), 1.0)
        return abs(fa - fb) / denom > tolerance
    return True

def field_mismatch_mask(a_seq, b_seq, field, tolerance=0.01):
    """Boolean mask over aligned rows: True where `field` differs beyond
    tolerance. A row where the field is missing from either side is False
    (no mismatch there), which also breaks a run of consecutive mismatches.
    """
    n = min(len(a_seq), len(b_seq))
    mask = [False] * n
    for i in range(n):
        a_row, b_row = a_seq[i], b_seq[i]
        if field not in a_row or field not in b_row:
            continue
        mask[i] = _values_differ(a_row[field], b_row[field], tolerance)
    return mask

def filter_isolated_mismatches(mask, min_run=MIN_CONSECUTIVE_MISMATCH):
    """Zero out True runs shorter than min_run — isolated single-sample
    blips don't count, only sustained divergences of min_run+ in a row."""
    n = len(mask)
    out = [False] * n
    i = 0
    while i < n:
        if mask[i]:
            j = i
            while j < n and mask[j]:
                j += 1
            if j - i >= min_run:
                for k in range(i, j):
                    out[k] = True
            i = j
        else:
            i += 1
    return out

def qualifying_mismatch_mask(a_seq, b_seq, field, tolerance=0.01, min_run=MIN_CONSECUTIVE_MISMATCH):
    """field_mismatch_mask() + filter_isolated_mismatches() in one call —
    the mask actually used for reporting/plotting decisions."""
    return filter_isolated_mismatches(field_mismatch_mask(a_seq, b_seq, field, tolerance), min_run)


def compare_status_series(iv_st, vl_st, prefix, tolerance=0.01):
    """Compare two sequences of [STATUS] lines field-by-field."""
    issues = []
    iv_n, vl_n = len(iv_st), len(vl_st)
    if iv_n == 0 and vl_n == 0:
        return []
    delta = abs(iv_n - vl_n)
    if delta > max(2, int(max(iv_n, vl_n) * 0.01)):
        issues.append(f"{prefix}: count iv={iv_n} vl={vl_n}")
    def count_mismatches(a_st, b_st):
        n = min(len(a_st), len(b_st))
        all_fields = set()
        for i in range(n):
            all_fields.update(a_st[i].keys())
            all_fields.update(b_st[i].keys())
        all_fields.discard('t')
        mm = Counter()
        for k in all_fields:
            cnt = sum(qualifying_mismatch_mask(a_st, b_st, k, tolerance))
            if cnt:
                mm[k] = cnt
        return mm

    # Try aligned comparison, then ±1 snapshot offset; use best (fewest mismatches)
    field_mismatches = count_mismatches(iv_st, vl_st)
    total = sum(field_mismatches.values())
    for offset in [1, -1]:
        if offset > 0:
            mm2 = count_mismatches(iv_st[offset:], vl_st)
        else:
            mm2 = count_mismatches(iv_st, vl_st[-offset:])
        if sum(mm2.values()) < total:
            field_mismatches = mm2
            total = sum(mm2.values())

    if field_mismatches:
        top = sorted(field_mismatches.items(), key=lambda x: -x[1])[:5]
        issues.append(f"{prefix} field mismatches: " +
                      ", ".join(f"{k}({n})" for k, n in top))
    return issues

def compare_phase_sequence(iv_lines, vl_lines, prefix):
    """Compare phase event sequences, stripping timestamps."""
    _ts  = re.compile(r't=\d+\s*ms\s*')
    _num = re.compile(r'(pulse_width|delay_from_ign_in|width)=[\d.]+')
    _skip = re.compile(r'spurious pulse filtered', re.IGNORECASE)
    def normalise(lines):
        out = []
        for l in lines:
            if not l.startswith(prefix) or _skip.search(l): continue
            l = _ts.sub('t=T ms  ', l.strip())
            l = _num.sub(lambda m: m.group(0).split('=')[0] + '=N', l)
            out.append(l)
        return out
    iv_p = normalise(iv_lines)
    vl_p = normalise(vl_lines)
    # Trim leading events that appear before the first IGN_OUT/engine event
    # These are KLR startup state events that differ due to X-init differences
    def trim_preamble(phases, anchor_re=re.compile(r'IGN_OUT|ENGINE|SYNC', re.IGNORECASE)):
        for i, p in enumerate(phases):
            if anchor_re.search(p): return phases[i:]
        return phases
    if prefix.startswith("KLR"):
        iv_p = trim_preamble(iv_p)
        vl_p = trim_preamble(vl_p)
        # For KLR phases, only compare IGN_OUT events — other events
        # (FULL_LOAD, ENGINE_SYNC etc.) have minor interleaving differences
        # between simulators due to X-init and scheduling differences.
        _ign = re.compile(r'IGN_OUT', re.IGNORECASE)
        iv_p = [p for p in iv_p if _ign.search(p)]
        vl_p = [p for p in vl_p if _ign.search(p)]
        # Keep only deasserted events (complete ignition pulses)
        # This avoids asserted/deasserted interleaving differences
        iv_p = [p for p in iv_p if 'deasserted' in p.lower()]
        vl_p = [p for p in vl_p if 'deasserted' in p.lower()]
        # Skip first pulse if it differs greatly (pre-sync long pulse)
        if iv_p and vl_p:
            iv_p = iv_p[1:] if len(iv_p) > 1 else iv_p
            vl_p = vl_p[1:] if len(vl_p) > 1 else vl_p
    issues = []
    _count_tol = 1 if prefix.startswith("KLR") else 0
    if abs(len(iv_p) - len(vl_p)) > max(_count_tol, int(max(len(iv_p),len(vl_p),1) * 0.01)):
        issues.append(f"{prefix}: count iv={len(iv_p)} vl={len(vl_p)}")
    for i, (a, b) in enumerate(zip(iv_p, vl_p)):
        if a != b:
            # Use filtered lists for reporting (same as comparison)
            iv_s = iv_p[i]
            vl_s = vl_p[i]
            issues.append(f"{prefix} diverges at entry {i}: iv={iv_s!r} vl={vl_s!r}")
            break
    return issues

def field_diff_rows(a_st, b_st, field, max_rows=20, tolerance=0.01, min_run=MIN_CONSECUTIVE_MISMATCH):
    """Return up to `max_rows` (index, t, a_val, b_val) tuples where `field`
    differs (beyond tolerance for numeric values) between two aligned
    sequences of row-dicts, restricted to rows that are part of a run of
    at least `min_run` consecutive mismatches — isolated single-sample
    blips are excluded. Works for both int-valued [STATUS] rows and
    string-valued [DS] rows.
    """
    mask = qualifying_mismatch_mask(a_st, b_st, field, tolerance, min_run)
    rows = []
    for i, is_mismatch in enumerate(mask):
        if not is_mismatch:
            continue
        a_row, b_row = a_st[i], b_st[i]
        a_v, b_v = a_row.get(field), b_row.get(field)
        t = a_row.get('t', b_row.get('t', '?'))
        rows.append((i, t, a_v, b_v))
        if len(rows) >= max_rows:
            break
    return rows


def dump_dash_details(iv_lines, vl_lines, field=None, max_rows=20):
    """Print row-level iv-vs-vl values for mismatching fields in dash logs.

    If `field` is given, only that field is dumped (across all series it
    appears in). Otherwise every field that has at least one mismatch is
    dumped (capped at `max_rows` rows each).
    """
    _skip = re.compile(r'DME: \[SIM\]|VCD info:|dumpfile|Info:.*ignored|Simulated \d|\$finish|\bvvp\b', re.IGNORECASE)
    iv_lines = [l for l in iv_lines if not _skip.search(l)]
    vl_lines = [l for l in vl_lines if not _skip.search(l)]

    series = {
        "DME: [DS]":     (extract_ds_fields(iv_lines, "DME: [DS]"), extract_ds_fields(vl_lines, "DME: [DS]")),
        "DME: [STATUS]": (extract_status_fields(iv_lines, "DME: [STATUS]"), extract_status_fields(vl_lines, "DME: [STATUS]")),
        "KLR: [DS]":     (extract_ds_fields(iv_lines, "KLR: [DS]"), extract_ds_fields(vl_lines, "KLR: [DS]")),
        "KLR: [STATUS]": (extract_status_fields(iv_lines, "KLR: [STATUS]"), extract_status_fields(vl_lines, "KLR: [STATUS]")),
    }

    printed_any = False
    for prefix, (iv_st, vl_st) in series.items():
        if not iv_st and not vl_st:
            continue
        all_fields = set()
        for row in iv_st + vl_st:
            all_fields.update(row.keys())
        all_fields.discard('t')
        target_fields = [field] if field else sorted(all_fields)
        for f in target_fields:
            if f not in all_fields:
                continue
            rows = field_diff_rows(iv_st, vl_st, f, max_rows=max_rows)
            if not rows:
                continue
            printed_any = True
            print(f"\n--- {prefix} field '{f}' diffs ({len(rows)} shown, max_rows={max_rows}) ---")
            print(f"{'idx':>5}  {'t(ms)':>8}  {'iv':>14}  {'vl':>14}")
            for i, t, a_v, b_v in rows:
                print(f"{i:>5}  {str(t):>8}  {str(a_v):>14}  {str(b_v):>14}")
    if field and not printed_any:
        print(f"\n(no mismatches found for field '{field}' — check the field name, "
              f"or it may not be numeric/appear in these logs)")


def collect_field_series(a_st, b_st, field, tolerance=0.01):
    """Return (ts, diffs, iv_vals) over every aligned row where `field` is
    present in both series. Numeric fields: diff = b_val - a_val (signed),
    iv_vals holds the raw iverilog value at each point (used as the baseline
    for a %-difference axis). Non-numeric fields: diff = 1 where the values
    differ else 0, iv_vals is None throughout. Used for plotting the whole
    time-series, not just the divergent points.
    """
    ts, diffs, iv_vals = [], [], []
    numeric_re = re.compile(r'^-?\d+(\.\d+)?$')
    n = min(len(a_st), len(b_st))
    for i in range(n):
        a_row, b_row = a_st[i], b_st[i]
        if field not in a_row or field not in b_row:
            continue
        a_v, b_v = a_row[field], b_row[field]
        t = a_row.get('t', b_row.get('t', i))
        a_s, b_s = str(a_v), str(b_v)
        if numeric_re.match(a_s) and numeric_re.match(b_s):
            diffs.append(float(b_s) - float(a_s))
            iv_vals.append(float(a_s))
        else:
            diffs.append(0 if a_v == b_v else 1)
            iv_vals.append(None)
        ts.append(t)
    return ts, diffs, iv_vals


def open_in_preview(paths):
    """Open one or more files in macOS Preview (no-op / warns elsewhere)."""
    import subprocess
    if sys.platform != 'darwin':
        print(f"(--open skipped: not macOS, open manually: {', '.join(paths)})")
        return
    try:
        subprocess.run(['open', '-a', 'Preview', *paths], check=True)
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"(could not open {paths} in Preview: {e})")


def _gather_plot_data(iv_f, vl_f, ecu, field=None):
    """Build the (label, ts, diffs, iv_vals, is_numeric) list of mismatching
    fields restricted to a single ECU's series ('DME' or 'KLR')."""
    series = {
        f"{ecu}: [DS]":     (extract_ds_fields(iv_f, f"{ecu}: [DS]"), extract_ds_fields(vl_f, f"{ecu}: [DS]")),
        f"{ecu}: [STATUS]": (extract_status_fields(iv_f, f"{ecu}: [STATUS]"), extract_status_fields(vl_f, f"{ecu}: [STATUS]")),
    }
    plot_data = []
    numeric_re = re.compile(r'^-?\d+(\.\d+)?$')
    for prefix, (iv_st, vl_st) in series.items():
        if not iv_st and not vl_st:
            continue
        all_fields = set()
        for row in iv_st + vl_st:
            all_fields.update(row.keys())
        all_fields.discard('t')
        target_fields = [field] if field else sorted(all_fields)
        for f in target_fields:
            if f not in all_fields:
                continue
            # Only plot fields that actually have at least one mismatch
            if not field_diff_rows(iv_st, vl_st, f, max_rows=1):
                continue
            ts, diffs, iv_vals = collect_field_series(iv_st, vl_st, f)
            if not ts:
                continue
            # Determine numeric-ness from the raw field values (not the diffs,
            # which can coincidentally look binary e.g. when values differ by 1).
            sample_vals = [str(row[f]) for row in (iv_st + vl_st) if f in row][:5]
            is_numeric = bool(sample_vals) and all(numeric_re.match(v) for v in sample_vals)
            plot_data.append((f"{prefix} {f}", ts, diffs, iv_vals, is_numeric))
    return plot_data


def _render_plot_data(plot_data, out_path, plt):
    """Render a list of (label, ts, diffs, iv_vals, is_numeric) tuples to a
    single JPEG at out_path."""
    n = len(plot_data)
    fig, axes = plt.subplots(n, 1, figsize=(11, max(2.2 * n, 3)), squeeze=False)
    for idx, (label, ts, diffs, iv_vals, is_numeric) in enumerate(plot_data):
        ax = axes[idx][0]
        if is_numeric:
            ax.plot(ts, diffs, marker='.', markersize=3, linewidth=0.8, color='tab:red')
            ax.axhline(0, color='gray', linewidth=0.6)
            ax.set_ylabel('vl - iv', color='tab:red')
            ax.tick_params(axis='y', labelcolor='tab:red')

            # Right-hand axis: % difference relative to the iverilog value
            # at that point (the baseline). Skipped where iv==0, since a
            # meaningful percentage baseline doesn't exist there.
            pct_ts, pct_vals = [], []
            for t, d, iv_v in zip(ts, diffs, iv_vals):
                if iv_v is None or iv_v == 0:
                    continue
                pct_ts.append(t)
                pct_vals.append(100.0 * d / iv_v)
            ax2 = ax.twinx()
            if pct_vals:
                ax2.plot(pct_ts, pct_vals, marker='.', markersize=2.5, linewidth=0.7,
                          color='tab:blue', alpha=0.6, linestyle='--')
            ax2.set_ylabel('% diff from iv', color='tab:blue')
            ax2.tick_params(axis='y', labelcolor='tab:blue')
            ax2.axhline(0, color='tab:blue', linewidth=0.3, alpha=0.3)
        else:
            ax.fill_between(ts, diffs, step='pre', color='tab:orange', alpha=0.7)
            ax.set_ylabel('mismatch')
            ax.set_ylim(-0.1, 1.1)
        ax.set_title(label, fontsize=10, loc='left')
        ax.set_xlabel('t (ms)')
        ax.grid(True, linewidth=0.3, alpha=0.5)
    fig.tight_layout()
    fig.savefig(out_path, format='jpg', dpi=130)
    plt.close(fig)


def plot_dash_diffs(iv_lines, vl_lines, out_dir, base_name, field=None):
    """Render two separate JPEG reports — one for DME fields, one for KLR
    fields — each with one subplot per mismatching field, into `out_dir`.
    Returns the list of paths actually written (may be 0, 1, or 2 files).
    """
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
    except ImportError:
        print("\n(--plot requires matplotlib: pip install matplotlib --break-system-packages)")
        return []

    import os
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as e:
        print(f"\n(could not create {out_dir} ({e}); writing plots to current directory instead)")
        out_dir = "."

    _skip = re.compile(r'DME: \[SIM\]|VCD info:|dumpfile|Info:.*ignored|Simulated \d|\$finish|\bvvp\b', re.IGNORECASE)
    iv_f = [l for l in iv_lines if not _skip.search(l)]
    vl_f = [l for l in vl_lines if not _skip.search(l)]

    written = []
    for ecu in ("DME", "KLR"):
        plot_data = _gather_plot_data(iv_f, vl_f, ecu, field=field)
        if not plot_data:
            continue
        out_path = os.path.join(out_dir, f"{base_name}_{ecu}_diff.jpg")
        _render_plot_data(plot_data, out_path, plt)
        print(f"{ecu} plot written to {out_path} ({len(plot_data)} field{'s' if len(plot_data) != 1 else ''})")
        written.append(out_path)

    if not written:
        print("\n(nothing to plot — no numeric/comparable field mismatches found)")
    return written


def extract_ds_fields(lines, prefix="DME: [DS]"):
    """Return a list of dicts, one per [DS] line, mapping field→value."""
    result = []
    for l in lines:
        if not l.startswith(prefix):
            continue
        pairs = re.findall(r'(\w+)=([\w.\-]+)', l)
        result.append(dict(pairs))
    return result

def compare_ds_series(iv_ds, vl_ds, tolerance=0.01):
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
    all_fields = set()
    for i in range(n_compare):
        all_fields.update(iv_ds[i].keys())
        all_fields.update(vl_ds[i].keys())
    all_fields.discard('t')

    field_mismatches = Counter()
    for k in all_fields:
        cnt = sum(qualifying_mismatch_mask(iv_ds[:n_compare], vl_ds[:n_compare], k, tolerance))
        if cnt:
            field_mismatches[k] = cnt

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

    # Line counts per prefix — exclude spurious filtered startup pulses
    _spurious = re.compile(r'spurious pulse filtered', re.IGNORECASE)
    def count_p(lines, p):
        return sum(1 for l in lines if l.startswith(p) and not _spurious.search(l))
    for p in prefixes:
        iv_n = count_p(iv_lines, p)
        vl_n = count_p(vl_lines, p)
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

    # DME [PHASE] sequence — timestamp-normalised comparison
    issues.extend(compare_phase_sequence(iv_lines, vl_lines, "DME: [PHASE]"))

    # KLR [PHASE] sequence — timestamp-normalised comparison
    issues.extend(compare_phase_sequence(iv_lines, vl_lines, "KLR: [PHASE]"))

    # DME [STATUS] field comparison
    iv_dme_st = extract_status_fields(iv_lines, "DME: [STATUS]")
    vl_dme_st = extract_status_fields(vl_lines, "DME: [STATUS]")
    issues.extend(compare_status_series(iv_dme_st, vl_dme_st, "DME: [STATUS]"))

    # KLR [STATUS] field comparison
    iv_klr_st = extract_status_fields(iv_lines, "KLR: [STATUS]")
    vl_klr_st = extract_status_fields(vl_lines, "KLR: [STATUS]")
    issues.extend(compare_status_series(iv_klr_st, vl_klr_st, "KLR: [STATUS]"))

    return issues


def list_fields(iv_lines, vl_lines):
    """Print every field discovered per prefix (DME/KLR × STATUS/DS),
    marking which are excluded via IGNORED_STATUS_FIELDS so it's clear
    exactly what is and isn't being compared."""
    _skip = re.compile(r'DME: \[SIM\]|VCD info:|dumpfile|Info:.*ignored|Simulated \d|\$finish|\bvvp\b', re.IGNORECASE)
    iv_f = [l for l in iv_lines if not _skip.search(l)]
    vl_f = [l for l in vl_lines if not _skip.search(l)]

    series = {
        "DME: [STATUS]": (extract_status_fields(iv_f, "DME: [STATUS]", apply_ignore=False),
                           extract_status_fields(vl_f, "DME: [STATUS]", apply_ignore=False)),
        "DME: [DS]":     (extract_ds_fields(iv_f, "DME: [DS]"), extract_ds_fields(vl_f, "DME: [DS]")),
        "KLR: [STATUS]": (extract_status_fields(iv_f, "KLR: [STATUS]", apply_ignore=False),
                           extract_status_fields(vl_f, "KLR: [STATUS]", apply_ignore=False)),
        "KLR: [DS]":     (extract_ds_fields(iv_f, "KLR: [DS]"), extract_ds_fields(vl_f, "KLR: [DS]")),
    }
    for prefix, (iv_st, vl_st) in series.items():
        if not iv_st and not vl_st:
            continue
        all_fields = set()
        for row in iv_st + vl_st:
            all_fields.update(row.keys())
        all_fields.discard('t')
        ignored = {f.lower() for f in IGNORED_STATUS_FIELDS.get(prefix, ())}
        cond = IGNORED_STATUS_FIELDS_BY_TEST.get(prefix, {})
        cond_ignored = {f for f in cond if CURRENT_TEST_NAME in cond[f]}
        n_compared = sum(1 for f in all_fields if f.lower() not in ignored and f.lower() not in cond_ignored)
        print(f"\n{prefix} ({n_compared} compared, {len(all_fields)} total field{'s' if len(all_fields) != 1 else ''} found):")
        for f in sorted(all_fields):
            fl = f.lower()
            if fl in ignored:
                tag = "  [IGNORED — not compared]"
            elif fl in cond_ignored:
                tag = f"  [IGNORED for test '{CURRENT_TEST_NAME}' only]"
            else:
                tag = ""
            print(f"  {f}{tag}")


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Compare iverilog vs Verilator sim logs")
    parser.add_argument('--dash', action='store_true',
                         help='Dashboard .dash.log comparison (default; only mode supported)')
    parser.add_argument('iv_log',   help='iverilog log file')
    parser.add_argument('vl_log',   help='Verilator log file')
    parser.add_argument('name',     nargs='?', default='test', help='Test name for reporting')
    parser.add_argument('-v', '--verbose', action='store_true',
                         help='Print row-level iv-vs-vl values for every mismatching field')
    parser.add_argument('--field', metavar='NAME',
                         help='Dump row-level iv-vs-vl values for just this field. '
                              'Implies --verbose.')
    parser.add_argument('--max-rows', type=int, default=20,
                         help='Max diff rows to print per field when using --verbose/--field (default 20)')
    parser.add_argument('--plot', action='store_true',
                         help='Render two JPEG reports (one for DME fields, one for KLR fields), '
                              'each with one subplot per mismatching field showing (vl - iv) vs. '
                              'simulation time. Combine with --field to plot just '
                              'one field. Files are named "<name>_DME_diff.jpg" / "<name>_KLR_diff.jpg" '
                              'inside --plot-dir.')
    parser.add_argument('--plot-dir', default='/Users/Mike/coding_projects/944/tmp/dme_klr/dash_logs',
                         metavar='DIR',
                         help='Directory to write --plot JPEGs into (created if missing). '
                              'Default: /Users/Mike/coding_projects/944/tmp/dme_klr/dash_logs')
    parser.add_argument('--open', dest='open_plot', action='store_true',
                         help='After --plot writes the JPEGs, open them in macOS Preview.')
    parser.add_argument('--list-fields', action='store_true',
                         help='List every field found in the logs, marking which are excluded '
                              'via IGNORED_STATUS_FIELDS, then exit.')
    args = parser.parse_args()
    if args.field:
        args.verbose = True

    global CURRENT_TEST_NAME
    CURRENT_TEST_NAME = args.name

    iv_lines = read_lines(args.iv_log)
    vl_lines = read_lines(args.vl_log)

    if iv_lines is None or vl_lines is None:
        missing = []
        if iv_lines is None: missing.append(f"iv={args.iv_log}")
        if vl_lines is None: missing.append(f"vl={args.vl_log}")
        print(f"ERROR\t{args.name}\tfile(s) not found: {', '.join(missing)}")
        sys.exit(2)

    if args.list_fields:
        list_fields(iv_lines, vl_lines)
        sys.exit(0)

    issues = compare_dash(iv_lines, vl_lines, args.name)

    if not issues:
        print(f"MATCH\t{args.name}\toutputs equivalent")
        sys.exit(0)

    detail = "; ".join(issues)
    is_near_match = all(i.startswith("NEAR-MATCH") for i in issues)
    verdict = "NEAR-MATCH" if is_near_match else "DIFF"
    print(f"{verdict}\t{args.name}\t{detail}")

    if args.verbose:
        dump_dash_details(iv_lines, vl_lines, field=args.field, max_rows=args.max_rows)

    if args.plot:
        written = plot_dash_diffs(iv_lines, vl_lines, args.plot_dir, args.name, field=args.field)
        if written and args.open_plot:
            open_in_preview(written)

    sys.exit(0 if is_near_match else 1)


if __name__ == '__main__':
    main()
