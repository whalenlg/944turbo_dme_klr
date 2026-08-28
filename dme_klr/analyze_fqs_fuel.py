#!/usr/bin/env python3
"""
analyze_fqs_fuel.py — RPM-normalized fuel comparison across an FQS family.

The plain "compare average fuel to a fixed baseline" check
(validate_dash_log.py) confounds two different effects: fuel-quality-driven
adjustment (what FQS is supposed to test) and RPM-driven fuel need (since
different FQS positions can settle at meaningfully different closed-loop
RPMs even with an identical AFM_CL_TARGET). This script separates them:

  1. For each test, find a genuinely SETTLED window: take the tail of the
     log (last 30%, same convention as validate_dash_log.py /
     extract_timing_adv.py), then further filter to only the samples
     within --rpm-band of that window's own final RPM. This drops
     still-converging/transient rows that a plain tail window can't tell
     apart from real steady state.
  2. "Undo" each position's EXPECTED fuel-quality percentage:
         normalized_fuel = fuel_avg / (1 + expected_pct/100)
     This estimates what fuel a position's own RPM would need at the
     baseline (0%) fuel quality, IF the firmware is correctly applying
     the expected adjustment.
  3. Fit a line through (rpm, normalized_fuel) using ALL positions
     together — this is the underlying RPM-vs-fuel relationship with the
     fuel-quality effect factored out.
  4. Report each position's residual against that fit. Small, randomly-
     signed residuals mean the fuel-quality mechanism is working and the
     RPM differences were the actual confound. Large or consistently-
     signed residuals point at a real fuel-quality miscalibration instead.

Usage:
    python3 analyze_fqs_fuel.py [log_dir] [test1 test2 ...] [--expected p0 p1 ...]

Defaults:
    log_dir  : ~/coding_projects/944/tmp/dme_klr/dash_logs   (iverilog)
    tests    : the 8 cl_ramp_to_3000_FQS0-7 tests
    expected : 0 3 -3 6 0 3 -3 6   (the standard FQS0-7 fuel_pct pattern)
"""

import re
import sys
import argparse
from pathlib import Path


def guess_rpm_target(test_name):
    m = re.search(r'to_(\d{3,5})', test_name)
    return int(m.group(1)) if m else None


def parse_ds(line):
    """Parse one 'DME: [DS] t,<256-hex-char iram dump>,...' line."""
    line = line.strip()
    if not line.startswith('DME: [DS]'):
        return None
    parts = line[len('DME: [DS]'):].strip().split(',')
    if len(parts) < 3:
        return None
    try:
        t = int(parts[0])
    except ValueError:
        return None
    h = parts[1]
    if len(h) < 256:
        return None
    h = h[:256]

    def b(n):
        s = h[n*2:n*2+2]
        return int(s, 16) if 'x' not in s.lower() else 0

    hb = b(0x4B)
    lb = b(0x4A)
    fuelcut = (b(0x23) >> 5) & 1
    rpm_raw = parts[3] if len(parts) >= 4 else '0'
    m = re.match(r'^(\d+)', rpm_raw)
    rpm = int(m.group(1)) if m else 0
    if rpm > 9000:
        rpm = 0
    return {
        't': t,
        'fuel_actual': 0 if fuelcut else ((hb << 8) | lb) * 2 / 1000,
        'rpm': rpm,
    }


def load_rows(path):
    rows = []
    try:
        with open(path) as f:
            for line in f:
                r = parse_ds(line)
                if r:
                    rows.append(r)
    except FileNotFoundError:
        pass
    return rows


def settled_window(rows, rpm_band):
    """Last 30% of samples (same convention as elsewhere), fuel>0 only,
    then further filtered to within rpm_band of that window's own final
    RPM — dropping rows that are still mid-transient."""
    if not rows:
        return []
    cutoff_idx = max(0, len(rows) - max(10, len(rows) * 3 // 10))
    tail = [r for r in rows[cutoff_idx:] if r['fuel_actual'] > 0]
    if not tail:
        return []
    ref_rpm = tail[-1]['rpm']
    return [r for r in tail if abs(r['rpm'] - ref_rpm) <= rpm_band]


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('log_dir', nargs='?',
                     default=str(Path.home() / 'coding_projects/944/tmp/dme_klr/dash_logs'),
                     help='Directory containing <test>.dash.log files')
    ap.add_argument('tests', nargs='*',
                     default=[f'cl_ramp_to_3000_FQS{i}' for i in range(8)],
                     help='Test names to check (default: the 8 cl_ramp_to_3000 FQS tests)')
    ap.add_argument('--expected', nargs='+', type=float, default=None,
                     help='Expected fuel_pct per test, same order as tests '
                          '(default: 0 3 -3 6 0 3 -3 6, the standard FQS0-7 pattern)')
    ap.add_argument('--rpm-band', type=float, default=15.0,
                     help='RPM band (+/-) around each window\'s final RPM to '
                          'treat as genuinely settled (default: 15)')
    ap.add_argument('--targets', nargs='+', type=float, default=[0, 3, -3, 6],
                     help='The full set of possible fuel_pct settings a '
                          'measurement could correlate to (default: 0 3 -3 6, '
                          'the standard FQS target values)')
    args = ap.parse_args()

    log_dir = Path(args.log_dir)
    expected = args.expected if args.expected is not None else \
        [0, 3, -3, 6, 0, 3, -3, 6][:len(args.tests)]
    if len(expected) != len(args.tests):
        print(f"ERROR: {len(expected)} expected values given for {len(args.tests)} tests")
        sys.exit(1)

    print(f"\n{'='*100}")
    print(f"  RPM-normalized FQS fuel comparison")
    print(f"  log_dir: {log_dir}   rpm_band: +/-{args.rpm_band:.0f}")
    print(f"{'='*100}\n")
    print(f"{'Test':<26} {'n':>4} {'RPM avg':>8} {'RPM range':>14} "
          f"{'fuel avg':>9} {'expect%':>8} {'norm fuel':>10}")
    print(f"{'-'*26} {'-'*4} {'-'*8} {'-'*14} {'-'*9} {'-'*8} {'-'*10}")

    points = []  # (name, rpm, fuel_avg, expected_pct, norm_fuel)
    for test, exp_pct in zip(args.tests, expected):
        path = log_dir / f'{test}.dash.log'
        rows = load_rows(path)
        ss = settled_window(rows, args.rpm_band)

        if not ss:
            print(f"{test:<26} {'--':>4} {'--':>8} {'--':>14} {'--':>9} {exp_pct:>+7.0f}% {'--':>10}"
                  f"   (no data — missing log or no settled rows)")
            continue

        rpms = [r['rpm'] for r in ss]
        fuels = [r['fuel_actual'] for r in ss]
        n = len(ss)
        rpm_avg = sum(rpms) / n
        fuel_avg = sum(fuels) / n
        norm_fuel = fuel_avg / (1 + exp_pct / 100.0)

        print(f"{test:<26} {n:>4} {rpm_avg:>8.0f} {min(rpms):>6}-{max(rpms):<6}   "
              f"{fuel_avg:>8.3f} {exp_pct:>+7.0f}% {norm_fuel:>10.4f}")

        points.append((test, rpm_avg, fuel_avg, exp_pct, norm_fuel))

    if len(points) < 2:
        print("\nNeed at least 2 tests with data to fit an RPM/fuel relationship.")
        return

    # Fit normalized_fuel = slope*rpm + intercept, no numpy dependency
    n = len(points)
    xs = [p[1] for p in points]
    ys = [p[4] for p in points]
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    num = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    den = sum((x - mean_x) ** 2 for x in xs)
    slope = num / den if den else 0.0
    intercept = mean_y - slope * mean_x

    print(f"\n{'='*100}")
    print(f"  Fit: normalized_fuel = {slope:.6f}*rpm + {intercept:.4f}")
    print(f"  (fit uses ALL {n} tests together — the underlying RPM/fuel relationship")
    print(f"   with each position's own expected fuel-quality effect factored out)")
    print(f"{'='*100}\n")
    print(f"{'Test':<26} {'predicted':>10} {'actual norm':>12} {'residual':>10} {'residual%':>10}  "
          f"{'expect%':>8} {'correlates to':>13}")
    print(f"{'-'*26} {'-'*10} {'-'*12} {'-'*10} {'-'*10}  {'-'*8} {'-'*13}")
    for test, rpm_avg, fuel_avg, exp_pct, norm_fuel in points:
        predicted = slope * rpm_avg + intercept
        residual = norm_fuel - predicted
        residual_pct = residual / predicted * 100 if predicted else float('nan')

        # "Correlates to": what does the RAW (un-normalized) fuel_avg imply about
        # this position's actual fuel-quality percentage, independent of what we
        # assumed it should be? Compare against the fitted baseline curve at this
        # position's own RPM, then find the closest of the full set of possible
        # target values. If this doesn't match the position's own expected%,
        # that's a real flag — either a miscalibration or a mislabeled position.
        implied_pct = (fuel_avg / predicted - 1) * 100 if predicted else float('nan')
        closest_target = min(args.targets, key=lambda t: abs(t - implied_pct))
        match = "✓" if closest_target == exp_pct else "✗ MISMATCH"

        print(f"{test:<26} {predicted:>10.4f} {norm_fuel:>12.4f} {residual:>+10.4f} {residual_pct:>+9.2f}%  "
              f"{exp_pct:>+7.0f}% {closest_target:>+8.0f}% {match}")

    print(f"\n  'correlates to' = which of the possible targets ({', '.join(f'{t:+.0f}%' for t in args.targets)})")
    print(f"  this position's RAW (un-normalized) fuel_avg most closely implies, based on")
    print(f"  the fitted baseline curve at its own RPM — independent of what we assumed")
    print(f"  the answer should be. A mismatch flags either a real fuel-quality")
    print(f"  miscalibration, or a position that may be mislabeled/misconfigured.")
    print(f"\n  Small, randomly-signed residuals -> fuel-quality mechanism looks correct,")
    print(f"  raw comparison failures were mostly an RPM-mismatch artifact.")
    print(f"  Large or consistently-signed residuals -> a real fuel-quality")
    print(f"  miscalibration, not just RPM confounding.")
    print()


if __name__ == '__main__':
    main()
