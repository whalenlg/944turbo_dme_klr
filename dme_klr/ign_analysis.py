#!/usr/bin/env python3
"""
ign_analysis.py — IGN_OUT delay and pulse width analysis from KLR PHASE log
Usage: python3 ign_analysis.py <test.dash.log> [test2.dash.log ...]
       python3 ign_analysis.py --dir <logdir> [--rpm-min N] [--rpm-max N]
"""

import re, sys, os, argparse, statistics
from pathlib import Path

# ── Argument parsing ──────────────────────────────────────────────────────────
ap = argparse.ArgumentParser(description='IGN_OUT delay/pulse analysis from KLR PHASE log')
ap.add_argument('logs', nargs='*', help='dash.log files to analyse')
ap.add_argument('--dir',     help='Directory of dash.log files')
ap.add_argument('--rpm-min', type=int, default=0,      help='Min RPM filter (default 0)')
ap.add_argument('--rpm-max', type=int, default=9999,   help='Max RPM filter (default 9999)')
ap.add_argument('--t-min',   type=int, default=0,      help='Min sim time ms (default 0)')
ap.add_argument('--t-max',   type=int, default=999999, help='Max sim time ms')
args = ap.parse_args()

logs = list(args.logs)
if args.dir:
    logs += sorted(Path(args.dir).glob('*.dash.log'))

if not logs:
    ap.print_help()
    sys.exit(1)

# ── Parse one log file ────────────────────────────────────────────────────────
def parse_log(path):
    path = str(path)
    events = []
    rpm_by_t = {}

    with open(path) as f:
        for line in f:
            # RPM from STATUS lines
            m = re.search(r'(?:DME|KLR): \[STATUS\].*?t=(\d+).*?\((\d+) RPM\)', line)
            if m:
                rpm_by_t[int(m.group(1))] = int(m.group(2))
            # RPM from DS lines (iram[0x37]*40)
            m2 = re.match(r'DME: \[DS\] (\d+),([0-9a-fx]+)', line)
            if m2:
                _t = int(m2.group(1)); _h = m2.group(2)
                if len(_h) >= 0x38*2+2 and 'x' not in _h[0x37*2:0x37*2+2]:
                    rpm_by_t[_t] = int(_h[0x37*2:0x37*2+2], 16) * 40

            # IGN_OUT events
            if 'KLR: [PHASE]' not in line or 'IGN_OUT' not in line:
                continue
            if 'spurious' in line:
                continue
            t_m = re.search(r't=(\d+)', line)
            if not t_m:
                continue
            t = int(t_m.group(1))
            if t < args.t_min or t > args.t_max:
                continue

            if 'deasserted' in line:
                p_m = re.search(r'pulse_width=([\d.]+)', line)
                if p_m:
                    events.append({'t': t, 'type': 'pulse', 'val': float(p_m.group(1))})
            elif 'asserted' in line:
                d_m = re.search(r'delay_from_ign_in=([\d.]+)', line)
                if d_m:
                    events.append({'t': t, 'type': 'delay', 'val': float(d_m.group(1))})

    # Compute coil-off = gap between consecutive IGN assertions
    asserted_ts = [e['t'] for e in events if e['type'] == 'delay']
    for i in range(1, len(asserted_ts)):
        gap_ms = asserted_ts[i] - asserted_ts[i-1]
        events.append({'t': asserted_ts[i-1], 'type': 'coiloff', 'val': float(gap_ms)})

    # Attach nearest RPM to each event
    rpm_times = sorted(rpm_by_t.keys())
    def nearest_rpm(t):
        if not rpm_times: return 0
        idx = min(range(len(rpm_times)), key=lambda i: abs(rpm_times[i]-t))
        return rpm_by_t[rpm_times[idx]]

    for e in events:
        e['rpm'] = nearest_rpm(e['t'])

    return events

# ── Analyse events ────────────────────────────────────────────────────────────
def analyse(events, label):
    delays = [e['val'] for e in events
              if e['type'] == 'delay'
              and args.rpm_min <= e['rpm'] <= args.rpm_max]
    pulses = [e['val'] for e in events
              if e['type'] == 'pulse'
              and args.rpm_min <= e['rpm'] <= args.rpm_max]

    # All deasserted pulse widths = dwell time (IGN_OUT was HIGH)
    dwell = pulses  # all pulse widths
    inter = []

    print(f"\n{'─'*70}")
    print(f"  {label}")
    print(f"{'─'*70}")

    def stats(vals, name, unit):
        if not vals:
            print(f"  {name:25s}: no data")
            return
        avg = statistics.mean(vals)
        mn  = min(vals)
        mx  = max(vals)
        med = statistics.median(vals)
        std = statistics.stdev(vals) if len(vals) > 1 else 0
        print(f"  {name:25s}: n={len(vals):4d}  "
              f"min={mn:8.3f}{unit}  avg={avg:8.3f}{unit}  "
              f"med={med:8.3f}{unit}  max={mx:8.3f}{unit}  "
              f"σ={std:6.3f}{unit}")

    stats(delays, 'IGN delay (crank→spark)', 'µs')
    dwell_filt = [p for p in dwell if p < 20.0]
    stats(dwell_filt, 'IGN dwell pulse width',   'ms')
    coiloff = [e['val'] for e in events
               if e['type'] == 'coiloff'
               and args.rpm_min <= e.get('rpm',0) <= args.rpm_max
               and 1.0 < e['val'] < 200.0]
    stats(coiloff, 'Coil-off interval',      'ms')

    if delays:
        rpms = [e['rpm'] for e in events
                if e['type'] == 'delay'
                and args.rpm_min <= e['rpm'] <= args.rpm_max]
        if rpms:
            print(f"  {'RPM range':25s}: {min(rpms)} – {max(rpms)} RPM")

    # RPM bin table
    rpm_bins   = [(0,1000),(1000,2000),(2000,3000),(3000,4000),
                  (4000,5000),(5000,6000),(6000,9999)]
    bin_labels = ['<1k','1-2k','2-3k','3-4k','4-5k','5-6k','>6k']
    delay_by_rpm   = {b: [] for b in rpm_bins}
    dwell_by_rpm   = {b: [] for b in rpm_bins}
    coiloff_by_rpm = {b: [] for b in rpm_bins}

    for e in events:
        if not (args.rpm_min <= e['rpm'] <= args.rpm_max):
            continue
        for b in rpm_bins:
            if b[0] <= e['rpm'] < b[1]:
                if e['type'] == 'delay':
                    delay_by_rpm[b].append(e['val'])
                elif e['type'] == 'pulse' and e['val'] < 20.0:
                    dwell_by_rpm[b].append(e['val'])
                elif e['type'] == 'coiloff' and 1.0 < e['val'] < 200.0:
                    coiloff_by_rpm[b].append(e['val'])
                break

    has_data = [b for b in rpm_bins if delay_by_rpm[b] or dwell_by_rpm[b]]
    if has_data:
        print(f"\n  {'RPM':<8s} {'n(delay)':<10s} {'delay avg(µs)':<16s} "
              f"{'n(dwell)':<10s} {'dwell avg(ms)':<14s} {'coil-off(ms)':<13s}")
        print(f"  {'─'*8} {'─'*10} {'─'*16} {'─'*10} {'─'*14} {'─'*13}")
        for b, lbl in zip(rpm_bins, bin_labels):
            dl = delay_by_rpm[b]; dw = dwell_by_rpm[b]; co = coiloff_by_rpm[b]
            if not dl and not dw: continue
            d_str = f"{statistics.mean(dl):8.2f}" if dl else "     N/A"
            w_str = f"{statistics.mean(dw):8.3f}" if dw else "     N/A"
            c_str = f"{statistics.mean(co):8.3f}" if co else "     N/A"
            print(f"  {lbl:<8s} {len(dl):<10d} {d_str:<16s} {len(dw):<10d} {w_str:<14s} {c_str:<13s}")

    return {'delays': delays, 'dwell': dwell, 'inter': inter}

# ── Main ──────────────────────────────────────────────────────────────────────
print(f"\n{'═'*70}")
print(f"  IGN_OUT Analysis")
if args.rpm_min > 0 or args.rpm_max < 9999:
    print(f"  RPM filter: {args.rpm_min} – {args.rpm_max} RPM")
if args.t_min > 0 or args.t_max < 999999:
    print(f"  Time filter: {args.t_min} – {args.t_max} ms")
print(f"{'═'*70}")

results = {}
for log in logs:
    name = Path(str(log)).stem.replace('.dash', '')
    events = parse_log(log)
    if not events:
        print(f"\n  {name}: no IGN_OUT events found")
        continue
    results[name] = analyse(events, name)

# ── Multi-file comparison ─────────────────────────────────────────────────────
if len(results) > 1:
    print(f"\n{'═'*70}")
    print(f"  COMPARISON — avg IGN delay (µs)")
    print(f"{'═'*70}")
    print(f"  {'Test':<35s}  {'Delay avg':>10s}  {'vs first':>10s}  {'Dwell avg':>10s}")
    print(f"  {'─'*35}  {'─'*10}  {'─'*10}  {'─'*10}")
    base_delay = None
    for name, r in results.items():
        if r['delays']:
            avg = statistics.mean(r['delays'])
            if base_delay is None: base_delay = avg
            diff = avg - base_delay
            dwell_avg = statistics.mean(r['dwell']) if r['dwell'] else float('nan')
            print(f"  {name:<35s}  {avg:>10.3f}µs  {diff:>+10.3f}µs  {dwell_avg:>10.3f}ms")
        else:
            print(f"  {name:<35s}  {'N/A':>10s}")

print()
