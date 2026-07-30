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
ap.add_argument('--dir', help='Directory of dash.log files')
ap.add_argument('--rpm-min', type=int, default=0,   help='Min RPM filter (default 0)')
ap.add_argument('--rpm-max', type=int, default=9999, help='Max RPM filter (default 9999)')
ap.add_argument('--t-min',   type=int, default=0,   help='Min sim time ms (default 0)')
ap.add_argument('--t-max',   type=int, default=999999, help='Max sim time ms')
ap.add_argument('--no-spurious', action='store_true', default=True,
                help='Exclude spurious pulses (default True)')
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
    rpm_by_t = {}  # t_ms → rpm

    with open(path) as f:
        for line in f:
            # Build RPM lookup from DS snapshots
            m = re.search(r'(?:DME|KLR): \[(?:DS|STATUS)\].*?t=(\d+)', line)
            if m:
                t = int(m.group(1))
                rpm_m = re.search(r'\((\d+) RPM\)', line)
                if rpm_m:
                    rpm_by_t[t] = int(rpm_m.group(1))

            if 'KLR: [PHASE]' not in line or 'IGN_OUT' not in line:
                continue
            if args.no_spurious and 'spurious' in line:
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

    # Separate dwell pulses (short) from inter-spark intervals (long)
    # Dwell: typically < 20ms; inter-spark: > 20ms
    dwell   = [p for p in pulses if p < 20.0]
    inter   = [p for p in pulses if p >= 20.0]

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
    stats(dwell,  'Dwell pulse width',       'ms')
    stats(inter,  'Inter-spark interval',    'ms')

    # RPM distribution of delay events
    if delays:
        rpms = [e['rpm'] for e in events
                if e['type'] == 'delay'
                and args.rpm_min <= e['rpm'] <= args.rpm_max]
        if rpms:
            print(f"  {'RPM range':25s}: {min(rpms)} – {max(rpms)} RPM")

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
