#!/usr/bin/env python3
"""
fqs_analysis.py — Compare fuel injection pulse width across FQS sweep tests.

Reads DME: [STATUS] lines from both iverilog and Verilator dash logs,
extracts fuel_hb/fuel_lb, and shows how _FUEL_QUAL affects steady-state
injection pulse width.

Usage:
    python3 fqs_analysis.py [log_dir_iv] [log_dir_vl]

Defaults:
    iv: ~/coding_projects/944/tmp/dme_klr/dash_logs
    vl: ~/coding_projects/944/tmp/dme_klr/v_dash_logs
"""

import re
import os
import sys
from pathlib import Path

# FQS test definitions
FQS_TESTS = [
    ('cl_ramp_to_6000_FQS0', '0x00',   0),   # sw pos 0: 0.000V
    ('cl_ramp_to_6000_FQS1', '0x3B',  59),   # sw pos 1: 1.143V
    ('cl_ramp_to_6000_FQS2', '0x5A',  90),   # sw pos 2: 1.754V
    ('cl_ramp_to_6000_FQS3', '0x75', 117),   # sw pos 3: 2.281V
    ('cl_ramp_to_6000_FQS4', '0x81', 129),   # sw pos 4: 2.516V
    ('cl_ramp_to_6000_FQS5', '0x91', 145),   # sw pos 5: 2.839V
    ('cl_ramp_to_6000_FQS6', '0x9C', 156),   # sw pos 6: 3.048V
    ('cl_ramp_to_6000_FQS7', '0xA7', 167),   # sw pos 7: 3.254V
    # Reference: base cl_ramp_to_6000 (no FQS override)
    ('cl_ramp_to_6000',      'N/A',   -1),
    # --- ramp to 3000 RPM (more stable steady-state) ---
    ('cl_ramp_to_3000_FQS0', '0x00',   0),
    ('cl_ramp_to_3000_FQS1', '0x3B',  59),
    ('cl_ramp_to_3000_FQS2', '0x5A',  90),
    ('cl_ramp_to_3000_FQS3', '0x75', 117),
    ('cl_ramp_to_3000_FQS4', '0x81', 129),
    ('cl_ramp_to_3000_FQS5', '0x91', 145),
    ('cl_ramp_to_3000_FQS6', '0x9C', 156),
    ('cl_ramp_to_3000_FQS7', '0xA7', 167),
    # Reference: base cl_ramp_to_3000
    ('cl_ramp_to_3000',      'N/A',   -1),
]

# Also check RPM range to find steady-state
RPM_STEADY = 5000  # prpm threshold for 6000RPM tests
RPM_STEADY_3K = 2000  # prpm threshold for 3000RPM tests (engine peaks ~2880 RPM)


def parse_ign_delays(path, t_start=15000, t_end=25000, min_delay=100):
    """Parse KLR IGN_OUT asserted events, return delay_from_ign_in values.
    
    delay_from_ign_in is the crank-to-spark delay in microseconds.
    Shorter delay = more retard (spark fires closer to crank reference).
    Filter to t_start-t_end ms window for stable steady-state comparison.
    """
    delays = []
    try:
        with open(path) as f:
            for line in f:
                if 'IGN_OUT asserted' not in line: continue
                mt = re.search(r't=(\d+)', line)
                md = re.search(r'delay_from_ign_in=([\d.]+)', line)
                if mt and md:
                    t = int(mt.group(1))
                    d = float(md.group(1))
                    if t_start <= t <= t_end and d > min_delay:
                        delays.append(d)
    except FileNotFoundError:
        pass
    return delays


def steady_state_timing(delays):
    """Return timing stats from IGN delay list."""
    if not delays: return None
    return {'avg': sum(delays)/len(delays), 'n': len(delays),
            'min': min(delays), 'max': max(delays)}


def parse_status_lines(path):
    """Parse DME: [STATUS] lines, return list of dicts."""
    results = []
    try:
        with open(path) as f:
            for line in f:
                if not line.startswith('DME: [STATUS]'):
                    continue
                d = {}
                m = re.search(r't=(\d+)', line)
                if m:
                    d['t'] = int(m.group(1))
                for field, pat in [
                    ('fuel_hb', r'fuel_hb\(4B\)=0x([0-9a-fA-F]+)'),
                    ('fuel_lb', r'fuel_lb\(4A\)=0x([0-9a-fA-F]+)'),
                    ('prpm',    r'prpm\(37\)=0x([0-9a-fA-F]+)'),
                    ('load',    r'load\(46:47\)=0x([0-9a-fA-F]+)'),
                    ('dwell',   r'dwell\(2F\)=0x([0-9a-fA-F]+)'),
                    ('wu',      r'wu\(58:59\)=0x([0-9a-fA-F]+)'),
                ]:
                    mm = re.search(pat, line)
                    if mm:
                        d[field] = int(mm.group(1), 16)
                if 'fuel_hb' in d and 'fuel_lb' in d:
                    hb, lb = d['fuel_hb'], d['fuel_lb']
                    d['fuel_ms'] = ((hb << 8) | lb) * 2 / 1000
                if 'prpm' in d:
                    d['rpm'] = d['prpm'] * 40
                results.append(d)
    except FileNotFoundError:
        pass
    return results


def steady_state_stats(snapshots, rpm_min=RPM_STEADY):
    """Return stats for snapshots where RPM >= rpm_min."""
    ss = [s for s in snapshots if s.get('rpm', 0) >= rpm_min and s.get('fuel_ms', 0) > 0]
    if not ss:
        return None
    fuels = [s['fuel_ms'] for s in ss]
    rpms  = [s['rpm'] for s in ss]
    return {
        'n':        len(ss),
        'fuel_min': min(fuels),
        'fuel_max': max(fuels),
        'fuel_avg': sum(fuels) / len(fuels),
        'rpm_avg':  sum(rpms) / len(rpms),
        't_start':  ss[0]['t'],
        't_end':    ss[-1]['t'],
    }


def main():
    iv_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'coding_projects/944/tmp/dme_klr/dash_logs'
    vl_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path.home() / 'coding_projects/944/tmp/dme_klr/v_dash_logs'

    print(f"\n{'='*80}")
    print(f"  FQS Fuel Quality Sweep — Injection Pulse Width Analysis")
    print(f"  Steady-state = RPM ≥ {RPM_STEADY}")
    print(f"  IV : {iv_dir}")
    print(f"  VL : {vl_dir}")
    print(f"{'='*80}\n")

    print(f"{'Test':<30} {'FQ_VAL':>6} {'Dec':>4}  "
          f"{'IV fuel_ms':>12}  {'VL fuel_ms':>12}  {'Diff%':>6}  {'IV RPM':>7}  {'IV timing':>10}")
    print(f"{'-'*30} {'-'*6} {'-'*4}  {'-'*12}  {'-'*12}  {'-'*6}  {'-'*7}  {'-'*10}")

    results = []
    for test, fq_hex, fq_dec in FQS_TESTS:
        iv_path = iv_dir / f'{test}.dash.log'
        vl_path = vl_dir / f'{test}.dash.log'

        iv_snaps = parse_status_lines(iv_path)
        vl_snaps = parse_status_lines(vl_path)
        iv_delays = parse_ign_delays(iv_path)

        rpm_thresh = RPM_STEADY_3K if 'ramp_to_3000' in test else RPM_STEADY
        iv_ss = steady_state_stats(iv_snaps, rpm_thresh)
        vl_ss = steady_state_stats(vl_snaps, rpm_thresh)
        iv_timing = steady_state_timing(iv_delays)

        iv_str = f"{iv_ss['fuel_avg']:.3f}ms ({iv_ss['n']}pts)" if iv_ss else "  no data"
        vl_str = f"{vl_ss['fuel_avg']:.3f}ms ({vl_ss['n']}pts)" if vl_ss else "  no data"

        if iv_ss and vl_ss and iv_ss['fuel_avg'] > 0:
            diff_pct = (vl_ss['fuel_avg'] - iv_ss['fuel_avg']) / iv_ss['fuel_avg'] * 100
            diff_str = f"{diff_pct:+.1f}%"
        else:
            diff_pct = None
            diff_str = "   N/A"

        iv_rpm = f"{iv_ss['rpm_avg']:.0f}" if iv_ss else "N/A"
        vl_rpm = f"{vl_ss['rpm_avg']:.0f}" if vl_ss else "N/A"

        timing_str = f"{iv_timing['avg']:.0f}us({iv_timing['n']})" if iv_timing else "  N/A"
        # Suppress VL column if diff is implausibly large (>50%) — VL test not run yet
        if diff_pct is not None and abs(diff_pct) > 50:
            vl_str = "  (not run)"
            diff_str = "   N/A"
        print(f"{test:<30} {fq_hex:>6} {fq_dec:>4}  {iv_str:>12}  {vl_str:>12}  {diff_str:>6}  {iv_rpm:>7}  {timing_str:>10}")

        results.append((test, fq_dec, iv_ss, vl_ss, diff_pct, iv_timing))

    # ── FQS effect analysis ───────────────────────────────────────────────────
    print(f"\n{'='*80}")
    print("  FQS Effect on Fuel — iverilog reference")
    print(f"{'='*80}")

    base = next((r for r in results if r[0] == 'cl_ramp_to_6000'), None)
    base_fuel = base[2]['fuel_avg'] if base and base[2] else None
    fqs_results = [(r[0], r[1], r[2], r[3], r[5] if len(r)>5 else None) for r in results if 'FQS' in r[0] and 'ramp_to_6000' in r[0]]

    if base_fuel:
        print(f"\n  Base (no FQS override): {base_fuel:.3f}ms\n")

    print(f"  {'FQS':<5} {'Dec':>4}  {'IV fuel_ms':>10}  {'vs base':>8}  {'VL fuel_ms':>10}  {'vs base':>8}  {'IGN delay':>10}  {'vs FQS0':>18}")
    print(f"  {'-'*5} {'-'*4}  {'-'*10}  {'-'*8}  {'-'*10}  {'-'*8}  {'-'*10}  {'-'*18}")
    base_timing = None

    for test, fq_dec, iv_ss, vl_ss, iv_t in fqs_results:
        fqs_num = test.split('FQS')[1] if 'FQS' in test else '?'
        iv_f = iv_ss['fuel_avg'] if iv_ss else None
        vl_f = vl_ss['fuel_avg'] if vl_ss else None
        iv_base = f"{(iv_f-base_fuel)/base_fuel*100:+.1f}%" if iv_f and base_fuel else "  N/A"
        vl_base = f"{(vl_f-base_fuel)/base_fuel*100:+.1f}%" if vl_f and base_fuel else "  N/A"
        iv_str = f"{iv_f:.3f}ms" if iv_f else "  N/A"
        vl_str = f"{vl_f:.3f}ms" if vl_f else "  N/A"
        t_avg = iv_t["avg"] if iv_t else None
        if t_avg is not None and base_timing is None and fqs_num == "0": base_timing = t_avg
        t_str = f"{t_avg:.0f}us" if t_avg is not None else "  N/A"
        # Convert delay difference to degrees at ~6742 RPM
        # 1° = 60/(RPM*360) sec = 24.7µs at 6742 RPM
        us_per_deg = 60_000_000 / (6742 * 360)
        t_vs_deg = f"{(t_avg-base_timing)/us_per_deg:+.2f}°" if t_avg is not None and base_timing is not None else "  N/A"
        t_vs = f"{t_avg-base_timing:+.0f}µs ({t_vs_deg})"
        print(f"  FQS{fqs_num:<2} {fq_dec:>4}  {iv_str:>10}  {iv_base:>8}  {vl_str:>10}  {vl_base:>8}  {t_str:>10}  {t_vs:>18}")

    # Check if FQS is having any effect
    iv_fuels = [r[2]['fuel_avg'] for r in fqs_results if r[2]]
    if iv_fuels:
        fuel_range = max(iv_fuels) - min(iv_fuels)
        print(f"\n  IV fuel range across FQS sweep: {min(iv_fuels):.3f} – {max(iv_fuels):.3f}ms")
        print(f"  Range: {fuel_range:.3f}ms ({fuel_range/min(iv_fuels)*100:.1f}%)")
        if fuel_range < 0.05:
            print(f"\n  ⚠  WARNING: FQS has almost NO effect on fuel pulse width!")
            print(f"     _FUEL_QUAL may not be connected to the fuel calculation.")
        else:
            print(f"\n  ✓  FQS is affecting fuel — range of {fuel_range:.3f}ms seen.")

    # ── 3000 RPM section ─────────────────────────────────────────────────────
    # Use FQS0 (neutral, no correction) as base for 3000RPM comparison
    base_3k = next((r for r in results if r[0] == 'cl_ramp_to_3000_FQS0'), None)
    base_fuel_3k = base_3k[2]['fuel_avg'] if base_3k and base_3k[2] else None
    fqs_3k = [(r[0], r[1], r[2], r[3]) for r in results
              if 'FQS' in r[0] and 'ramp_to_3000' in r[0]]
    if fqs_3k and base_fuel_3k:
        print(f"\n{'='*80}")
        print("  FQS Effect on Fuel @ 3000 RPM — iverilog reference")
        print(f"{'='*80}")
        print(f"\n  Base (no FQS override): {base_fuel_3k:.3f}ms\n")
        print(f"  {'FQS':<5} {'Dec':>4}  {'IV fuel_ms':>10}  {'vs base':>8}")
        print(f"  {'-'*5} {'-'*4}  {'-'*10}  {'-'*8}")
        for test, fq_dec, iv_ss, vl_ss in fqs_3k:
            fqs_num = test.split('FQS')[1] if 'FQS' in test else '?'
            iv_f = iv_ss['fuel_avg'] if iv_ss else None
            iv_b = f"{(iv_f-base_fuel_3k)/base_fuel_3k*100:+.1f}%" if iv_f and base_fuel_3k else '  N/A'
            iv_str = f"{iv_f:.3f}ms" if iv_f else "  N/A"
            print(f"  FQS{fqs_num:<2} {fq_dec:>4}  {iv_str:>10}  {iv_b:>8}")
        iv_fuels_3k = [r[2]['fuel_avg'] for r in fqs_3k if r[2]]
        if iv_fuels_3k:
            r3k = max(iv_fuels_3k) - min(iv_fuels_3k)
            print(f"\n  IV fuel range: {min(iv_fuels_3k):.3f} – {max(iv_fuels_3k):.3f}ms")
            print(f"  Range: {r3k:.3f}ms ({r3k/min(iv_fuels_3k)*100:.1f}%)")
            if r3k < 0.05:
                print("  ⚠  WARNING: FQS has almost NO effect at 3000 RPM!")
            else:
                print(f"  ✓  FQS affecting fuel at 3000 RPM — {r3k:.3f}ms range.")

    print()


if __name__ == '__main__':
    main()
