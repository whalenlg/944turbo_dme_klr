#!/usr/bin/env python3
"""
check_replay.py — compare an open-loop replay run against the log's
expected outputs.

    check_replay.py <sim.log> <expect.csv> [--lag-rows N] [--min-pass F]
                    [--mismatches out.csv] [--tol name=value ...]

--mismatches also writes out.xlsx beside the CSV: a Summary tab, then one
tab per channel listing that channel's out-of-tolerance rows.

<sim.log> is replay_main's stdout; <expect.csv> comes from
xlsx_to_stim.py. Each "SIM: [ROW] idx=i" line is followed by the
DME:/KLR: [DS] snapshot taken at that row's time, which is paired with
expected row i + lag-rows (default 0; a positive lag compares each log
row with the model's state that many rows later, to allow for the
firmware's own update latency).

Model-side value of each channel
--------------------------------
  ign_adv     DME iram[31h] (timing advance, half-teeth) * 360/264 deg
  klr_retard  measured: delay from the DME's spark command (rising edge
              of tach A_1, which is low for the dwell; SIM: [TACH]) to
              the KLR's spark (falling edge of its coil output, which
              is high for the dwell), in crank degrees at the log RPM
  klr_adv     ign_adv - klr_retard
  inj_ms      DME iram[4Bh:4Ah] * 2 us (computed pulse width)
  dwell_ms    width of the last KLR coil pulse (SIM: [IGN] klr)
  icv_pct     ISV PWM duty from the timer-1 reloads: P1.4-high time
              65536-{41h,40h} over the period incl. 65536-{45h,44h}
  rpm         DME iram[37h] * 40 (sanity check that the pinned RPM took)
  full_load   KLR full_load output (DS tail bit)
  knock_pin   KLR knock output P1.6 (bit 6 of the KLR [DS] P1 byte),
              active low (the firmware clears P1.6 when it flags knock).
              Expected: "KLR Knocking" = "Yes" (= 1)

The summary also counts knock events over the compared rows: the log's
knock-count increments against the model's KNOCK_OUT pulses
(KLR: [PHASE] ... KNOCK_OUT cleared).

Each channel passes on a row when |model - log| <= its tolerance; the
run fails when any channel's pass rate is under --min-pass. Rows whose
model value is unavailable (no spark seen yet, etc.) are counted as
"n/a", not as failures.
"""
import argparse
import bisect
import csv
import os
import re
import sys

HALF_TOOTH_DEG = 360.0 / 264.0

TOLERANCES = {           # absolute, in the channel's own units
    'ign_adv': 1.5,      # one half-tooth is 1.36 deg
    'klr_adv': 1.5,
    'klr_retard': 1.5,
    'inj_ms': 0.3,
    'dwell_ms': 0.5,
    'icv_pct': 5.0,
    'rpm': 80.0,         # iram[37h] has 40 rpm resolution
    'full_load': 0.0,
    'knock_pin': 0.0,
}
CHANNELS = list(TOLERANCES)
# Channels that only mean something when the event happens: with no knock
# on either side the row-by-row match is trivially 100%, so they report n/a.
EVENT_CHANNELS = {'knock_pin'}
EXPECT_COL = {'knock_pin': 'knocking'}     # channel -> expect.csv column, where they differ
KNOCK_RE = re.compile(r'^KLR: \[PHASE\] t=(\d+) ms\s+KNOCK_OUT cleared')

ROW_RE = re.compile(r'^SIM: \[ROW\] idx=(\d+) log_ms=([\d.]+) t_ns=(\d+)')
IGN_RE = re.compile(r'^SIM: \[(IGN\] dme|IGN\] klr|TACH\]) t_ns=(\d+) width_ns=(\d+)')
IGN_KIND = {'IGN] dme': 'dme', 'IGN] klr': 'klr', 'TACH]': 'tach'}
INJ_RE = re.compile(r'^SIM: \[INJ\] t_ns=(\d+) width_ns=(\d+)')


def hexbytes(h):
    out = []
    for i in range(0, 256, 2):
        s = h[i:i + 2]
        out.append(None if 'x' in s.lower() or 'z' in s.lower() else int(s, 16))
    return out


def parse_sim(path):
    rows = {}            # idx -> dict(t_ns, dme, klr, klr_bits)
    ign = {'dme': [], 'klr': [], 'tach': [], 'knock_ms': []}
    cur = None
    with open(path, errors='replace') as f:
        for line in f:
            m = KNOCK_RE.match(line)
            if m:
                ign['knock_ms'].append(int(m.group(1)))
                continue
            m = ROW_RE.match(line)
            if m:
                cur = int(m.group(1))
                rows[cur] = {'t_ns': int(m.group(3)), 'log_ms': float(m.group(2))}
                continue
            m = IGN_RE.match(line)
            if m:
                kind, t, w = IGN_KIND[m.group(1)], int(m.group(2)), int(m.group(3))
                # tach: keyed by its rising edge (the spark command), which
                # is where the high pulse it reports started
                ign[kind].append((t - w, w) if kind == 'tach' else (t, w))
                continue
            if cur is None:
                continue
            if line.startswith('DME: [DS]') and 'dme' not in rows[cur]:
                parts = line[9:].strip().split(',')
                if len(parts) >= 2 and len(parts[1]) >= 256:
                    rows[cur]['dme'] = hexbytes(parts[1])
            elif line.startswith('KLR: [DS]') and 'klr' not in rows[cur]:
                parts = line[9:].strip().split(',')
                if len(parts) >= 4:
                    rows[cur]['klr_bits'] = parts[3].strip()
                    p1 = parts[2].strip()[:2]
                    if re.fullmatch(r'[0-9a-fA-F]{2}', p1):
                        rows[cur]['klr_p1'] = int(p1, 16)
    for k in ign:
        ign[k].sort()
    return rows, ign


def last_before(events, t):
    """Last (t_ns, width) with t_ns <= t, or None."""
    i = bisect.bisect_right(events, (t, float('inf')))
    return events[i - 1] if i else None


def model_values(row, ign, rpm_log):
    d = row.get('dme')
    t = row['t_ns']
    v = dict.fromkeys(CHANNELS)
    if d:
        if d[0x31] is not None:
            v['ign_adv'] = d[0x31] * HALF_TOOTH_DEG
        if d[0x4A] is not None and d[0x4B] is not None:
            v['inj_ms'] = ((d[0x4B] << 8) | d[0x4A]) * 2 / 1000.0
        if d[0x37] is not None:
            v['rpm'] = d[0x37] * 40.0
        if None not in (d[0x40], d[0x41], d[0x44], d[0x45]):
            hi = 65536 - ((d[0x41] << 8) | d[0x40])
            lo = 65536 - ((d[0x45] << 8) | d[0x44])
            if hi + lo > 0:
                v['icv_pct'] = 100.0 * hi / (hi + lo)
    # KLR retard: latest KLR spark, against the DME spark command before it
    k = last_before(ign['klr'], t)
    if k:
        v['dwell_ms'] = k[1] / 1e6
    if k and rpm_log:
        dsp = last_before(ign['tach'], k[0])
        if dsp:
            delay_ns = k[0] - dsp[0]
            # a delay longer than one firing interval means a missed pair
            if delay_ns < 60e9 / rpm_log / 2:
                v['klr_retard'] = delay_ns * 1e-9 * rpm_log / 60.0 * 360.0
    if v['ign_adv'] is not None and v['klr_retard'] is not None:
        v['klr_adv'] = v['ign_adv'] - v['klr_retard']
    bits = row.get('klr_bits', '')
    if len(bits) >= 3 and bits[2] in '01':
        v['full_load'] = float(bits[2])
    if row.get('klr_p1') is not None:
        v['knock_pin'] = float(1 - ((row['klr_p1'] >> 6) & 1))   # P1.6 low = knock
    return v



def write_mismatch_xlsx(path, mism, stats, tol, min_pass):
    """The mismatches as a workbook: a Summary tab, then one tab per
    channel with that channel's out-of-tolerance rows in log order."""
    try:
        from openpyxl import Workbook
        from openpyxl.styles import Font
    except ImportError:
        print(f"openpyxl not installed; skipping {path}")
        return
    wb = Workbook()
    ws = wb.active
    ws.title = 'Summary'
    ws.append(['channel', 'tolerance', 'compared', 'passed', 'pass rate', 'mismatches',
               'mean error', 'max |error|', 'result'])
    for c in CHANNELS:
        st = stats[c]
        n = st['n']
        ws.append([c, tol[c], n, st['pass'], st['pass'] / n if n else None, n - st['pass'],
                   sum(st['err']) / n if n else None,
                   max((abs(x) for x in st['err']), default=None),
                   'N/A' if c in EVENT_CHANNELS and not st['events']
                   else 'PASS' if n and st['pass'] / n >= min_pass else 'FAIL'])
    for row in ws.iter_rows(min_row=2, min_col=5, max_col=5):
        row[0].number_format = '0%'
    cols = ['row', 't (s)', 'segment', 'rpm', 'tps_status', 'log', 'model', 'error', 'tolerance']
    for c in CHANNELS:
        t = wb.create_sheet(c[:31])
        t.append(cols)
        for m in mism:
            if m['channel'] == c:
                t.append([m['row'], round(float(m['t_ms']) / 1000, 3), int(m['segment']),
                          float(m['rpm']), m['tps_status'], m['log'], m['model'], m['error'],
                          m['tolerance']])
    for t in wb.worksheets:
        for cell in t[1]:
            cell.font = Font(bold=True)
        t.freeze_panes = 'A2'
        if t.max_row > 1:
            t.auto_filter.ref = t.dimensions
        for col in t.columns:
            t.column_dimensions[col[0].column_letter].width = max(10, len(str(col[0].value)) + 3)
    wb.save(path)

def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('sim_log')
    ap.add_argument('expect_csv')
    ap.add_argument('--lag-rows', type=int, default=0)
    ap.add_argument('--min-pass', type=float, default=0.90)
    ap.add_argument('--mismatches', help='write every out-of-tolerance sample here (CSV)')
    ap.add_argument('--tol', action='append', default=[], metavar='NAME=VALUE')
    a = ap.parse_args()

    tol = dict(TOLERANCES)
    for t in a.tol:
        name, _, val = t.partition('=')
        if name not in tol:
            sys.exit(f"unknown channel {name!r}; channels: {', '.join(CHANNELS)}")
        tol[name] = float(val)

    with open(a.expect_csv) as f:
        expect = list(csv.DictReader(f))
    rows, ign = parse_sim(a.sim_log)
    if not rows:
        sys.exit(f"no SIM: [ROW] lines in {a.sim_log} — did the replay run?")

    stats = {c: {'n': 0, 'pass': 0, 'na': 0, 'err': [], 'worst': None, 'events': 0} for c in CHANNELS}
    seg_stats = {}
    mism = []
    for i, exp in enumerate(expect):
        j = i + a.lag_rows
        if j not in rows:
            continue
        rpm_log = float(exp['rpm'])
        mv = model_values(rows[j], ign, rpm_log)
        seg = exp['segment'] + (' (' + exp['fill'] + ')' if exp['fill'] else '')
        for c in CHANNELS:
            st = stats[c]
            if mv[c] is None:
                st['na'] += 1
                continue
            e = float(exp[EXPECT_COL.get(c, c)])
            err = mv[c] - e
            ok = abs(err) <= tol[c] + 1e-9
            st['n'] += 1
            st['events'] += bool(e or mv[c])
            st['pass'] += ok
            st['err'].append(err)
            if st['worst'] is None or abs(err) > abs(st['worst'][0]):
                st['worst'] = (err, exp['t_ms'], e, mv[c])
            ss = seg_stats.setdefault(seg, {}).setdefault(c, [0, 0])
            ss[0] += 1
            ss[1] += ok
            if not ok:
                mism.append({'row': i, 't_ms': exp['t_ms'], 'segment': exp['segment'],
                             'channel': c, 'log': e, 'model': round(mv[c], 3),
                             'error': round(err, 3), 'tolerance': tol[c], 'rpm': exp['rpm'],
                             'tps_status': exp['tps_status']})

    played = sum(1 for i in range(len(expect)) if i + a.lag_rows in rows)
    # Knock events over the compared window
    cmp_idx = [i for i in range(len(expect)) if i + a.lag_rows in rows]
    log_knocks = model_knocks = 0
    if cmp_idx:
        log_knocks = int(float(expect[cmp_idx[-1]]['knock_cnt']) - float(expect[cmp_idx[0]]['knock_cnt']))
        t0 = rows[cmp_idx[0] + a.lag_rows]['t_ns'] / 1e6
        t1 = rows[cmp_idx[-1] + a.lag_rows]['t_ns'] / 1e6
        model_knocks = sum(1 for t in ign['knock_ms'] if t0 <= t <= t1)
    print(f"Replay check: {played}/{len(expect)} log rows compared "
          f"(lag {a.lag_rows} rows), {len(ign['tach'])} DME spark commands, {len(ign['klr'])} KLR sparks")
    print(f"Knock events in the compared window: log {log_knocks} (KLR Knock Cnt. increments), "
          f"model {model_knocks} (KNOCK_OUT pulses)")
    print()
    print(f"{'channel':<11} {'tol':>6} {'pass':>13} {'n/a':>5} {'mean err':>9} {'max |err|':>10}  worst at")
    failed = []
    for c in CHANNELS:
        st = stats[c]
        n = st['n']
        rate = st['pass'] / n if n else 0.0
        mean = sum(st['err']) / n if n else 0.0
        if st['worst']:
            err, t_ms, e, m = st['worst']
            worst = f"t={float(t_ms) / 1000:.2f}s log={e:g} model={m:.2f}"
        else:
            worst = '-'
        if c in EVENT_CHANNELS and not st['events']:
            print(f"{c:<11} {tol[c]:>6g} {'n/a':>13} {st['na']:>4}  (no knock in the log or the model "
                  f"over these {n} rows)")
            continue
        flag = '' if n and rate >= a.min_pass else '  <-- FAIL'
        if flag:
            failed.append(c)
        print(f"{c:<11} {tol[c]:>6g} {st['pass']:>5}/{n:<5}{rate:>4.0%} {st['na']:>4} "
              f"{mean:>+9.2f} {max((abs(x) for x in st['err']), default=0):>10.2f}  {worst}{flag}")
    print()
    print("Pass rate by log segment (fill colour marks the gear pulls):")
    for seg, cs in seg_stats.items():
        cells = '  '.join(f"{c}={p / n:.0%}" for c, (n, p) in cs.items()
                          if c not in EVENT_CHANNELS or stats[c]['events'])
        print(f"  segment {seg}: {cells}")

    if a.mismatches:
        with open(a.mismatches, 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=['row', 't_ms', 'segment', 'channel', 'log', 'model',
                                              'error', 'tolerance', 'rpm', 'tps_status'])
            w.writeheader()
            w.writerows(mism)
        xlsx = os.path.splitext(a.mismatches)[0] + '.xlsx'
        write_mismatch_xlsx(xlsx, mism, stats, tol, a.min_pass)
        print(f"\n{len(mism)} out-of-tolerance samples -> {a.mismatches}, {xlsx} (one tab per channel)")

    if failed:
        print(f"\nFAIL: pass rate under {a.min_pass:.0%} on {', '.join(failed)}")
        return 1
    print(f"\nPASS: every channel within tolerance on >= {a.min_pass:.0%} of rows")
    return 0


if __name__ == '__main__':
    sys.exit(main())
