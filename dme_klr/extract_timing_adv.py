#!/usr/bin/env python3
"""
extract_timing_adv.py — Pull iram[0x31] (timing_adv, half-teeth before TDC)
and RPM from DME: [STATUS] log lines at steady state, for a set of tests.

Built to answer: what does timing_adv actually read, and at what RPM, for
each FQS variant? — so a retard check can be compared against a same-family,
same-RPM-range baseline instead of a fixed number from a different test.

Usage:
    python3 extract_timing_adv.py [log_dir] [test1 test2 ...]

Defaults:
    log_dir : ~/coding_projects/944/tmp/dme_klr/dash_logs   (iverilog)
    tests   : the 8 cl_ramp_to_3000_FQS0-7 tests

Steady-state RPM threshold defaults to 90% of the RPM implied by the test
name (e.g. "...to_3000..." -> 2700, "...to_6000..." -> 5400); override with
--rpm-thresh if a test doesn't follow that naming pattern.
"""

import re
import sys
import argparse
from pathlib import Path


def guess_rpm_target(test_name):
    """Best-effort RPM target from the test name (…_to_NNNN…)."""
    m = re.search(r'to_(\d{3,5})', test_name)
    return int(m.group(1)) if m else None


def parse_status_lines(path):
    """Parse DME: [STATUS] lines, return list of {rpm, timing_adv} dicts."""
    results = []
    try:
        with open(path) as f:
            for line in f:
                if not line.startswith('DME: [STATUS]'):
                    continue
                d = {}
                mp = re.search(r'prpm\(37\)=0x([0-9a-fA-F]+)', line)
                mt = re.search(r'timing_adv\(31\)=0x([0-9a-fA-F]+)', line)
                if mp:
                    d['rpm'] = int(mp.group(1), 16) * 40
                if mt:
                    d['timing_adv'] = int(mt.group(1), 16)
                if 'rpm' in d and 'timing_adv' in d:
                    results.append(d)
    except FileNotFoundError:
        pass
    return results


def steady_state(rows, rpm_thresh):
    # Tail-of-log window, same convention validate_dash_log.py uses
    # (last 20% of samples, min 10) — NOT "any sample where RPM happened
    # to be above threshold", which also catches ramp-up transient rows
    # the moment RPM first crosses the threshold, before timing_adv (or
    # fuel) has actually settled. An RPM floor alone isn't enough to
    # isolate genuine steady state.
    cutoff_idx = max(0, len(rows) - max(10, len(rows) // 5))
    tail = rows[cutoff_idx:]
    return [r for r in tail if r['rpm'] >= rpm_thresh]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('log_dir', nargs='?',
                     default=str(Path.home() / 'coding_projects/944/tmp/dme_klr/dash_logs'),
                     help='Directory containing <test>.dash.log files')
    ap.add_argument('tests', nargs='*',
                     default=[f'cl_ramp_to_3000_FQS{i}' for i in range(8)],
                     help='Test names to check (default: the 8 cl_ramp_to_3000 FQS tests)')
    ap.add_argument('--rpm-thresh', type=float, default=None,
                     help='Override the steady-state RPM threshold for every test '
                          '(default: 90%% of the RPM guessed from each test name)')
    args = ap.parse_args()

    log_dir = Path(args.log_dir)

    print(f"\n{'='*90}")
    print(f"  timing_adv (iram[0x31]) steady-state extraction")
    print(f"  log_dir: {log_dir}")
    print(f"{'='*90}\n")
    print(f"{'Test':<26} {'RPM thresh':>10}  {'n':>4}  "
          f"{'RPM min':>8}  {'RPM avg':>8}  {'RPM max':>8}  "
          f"{'adv min':>7}  {'adv avg':>7}  {'adv max':>7}")
    print(f"{'-'*26} {'-'*10}  {'-'*4}  {'-'*8}  {'-'*8}  {'-'*8}  {'-'*7}  {'-'*7}  {'-'*7}")

    summary = []
    for test in args.tests:
        path = log_dir / f'{test}.dash.log'
        rows = parse_status_lines(path)

        if args.rpm_thresh is not None:
            rpm_thresh = args.rpm_thresh
        else:
            target = guess_rpm_target(test)
            rpm_thresh = target * 0.9 if target else 0

        ss = steady_state(rows, rpm_thresh)

        if not ss:
            print(f"{test:<26} {rpm_thresh:>10.0f}  {'--':>4}  "
                  f"{'--':>8}  {'--':>8}  {'--':>8}  {'--':>7}  {'--':>7}  {'--':>7}"
                  f"   (no data — missing log or no steady-state rows)")
            continue

        rpms = [r['rpm'] for r in ss]
        advs = [r['timing_adv'] for r in ss]
        n = len(ss)
        rpm_min, rpm_avg, rpm_max = min(rpms), sum(rpms)/n, max(rpms)
        adv_min, adv_avg, adv_max = min(advs), sum(advs)/n, max(advs)

        print(f"{test:<26} {rpm_thresh:>10.0f}  {n:>4}  "
              f"{rpm_min:>8.0f}  {rpm_avg:>8.0f}  {rpm_max:>8.0f}  "
              f"{adv_min:>7d}  {adv_avg:>7.2f}  {adv_max:>7d}")

        summary.append((test, rpm_avg, adv_avg))

    if summary:
        print(f"\n{'='*90}")
        print("  Quick diff vs first test in the list")
        print(f"{'='*90}")
        base_name, base_rpm, base_adv = summary[0]
        print(f"  Base: {base_name}  rpm_avg={base_rpm:.0f}  adv_avg={base_adv:.2f}ht\n")
        HALF_TEETH_DEG = 360.0 / 264.0
        for name, rpm_avg, adv_avg in summary[1:]:
            d_rpm = rpm_avg - base_rpm
            d_adv_ht = adv_avg - base_adv
            d_adv_deg = d_adv_ht * HALF_TEETH_DEG
            print(f"  {name:<26} rpm {d_rpm:+.0f}   adv {d_adv_ht:+.2f}ht ({d_adv_deg:+.2f}°)")

    print()


if __name__ == '__main__':
    main()
