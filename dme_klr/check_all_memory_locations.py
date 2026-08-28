#!/usr/bin/env python3
"""
check_all_memory_locations.py — wrapper around check_memory_location.py's
logic that scans EVERY IRAM address across every DME simulation log, to
find any location that was ever non-zero when it shouldn't have been.

Same log format and same DME-IRAM-only scope as check_memory_location.py
(see that script's docstring for the KLR-side limitation and the
hex-address convention this project uses).

This does NOT just call check_memory_location.py once per address — with
many log files that could mean re-parsing every log 128 times over. It
parses each log ONCE and checks all addresses in that single pass instead,
then reports three groups: addresses that went non-zero in at least one
log ("flagged"), addresses that had real samples but never went non-zero
("always zero"), and addresses that had no valid samples at all in any
log (always 'xx'/uninitialized — no evidence either way).

Usage:
    python3 check_all_memory_locations.py [--lo 0x00] [--hi 0x7F] [log_dir ...]

Examples:
    python3 check_all_memory_locations.py
    python3 check_all_memory_locations.py --lo 0x30 --hi 0x3F
    python3 check_all_memory_locations.py dash_logs v_dash_logs

Defaults to both the iverilog and Verilator log directories:
    ~/coding_projects/944/tmp/dme_klr/dash_logs
    ~/coding_projects/944/tmp/dme_klr/v_dash_logs
"""
import sys
import argparse
from pathlib import Path


def parse_addr(s):
    s = s.strip().lower()
    if s.startswith('0x'):
        return int(s, 16)
    if s.endswith('h'):
        return int(s[:-1], 16)
    return int(s, 16)  # bare numbers default to hex — see docstring


def find_logs(log_dirs):
    logs = []
    for d in log_dirs:
        d = Path(d)
        if d.is_dir():
            logs.extend(sorted(d.glob('*.dash.log')))
    return logs


def scan_log_all_addrs(path, lo, hi):
    """Single pass over one log: for every address in [lo, hi], track
    whether it was ever non-zero, its first hit, distinct values, and how
    many valid (non-'xx') samples it had. Returns {addr: {...}} plus
    n_snapshots."""
    n_addrs = hi - lo + 1
    any_nonzero = [False] * n_addrs
    first_hit = [None] * n_addrs
    distinct = [set() for _ in range(n_addrs)]
    n_valid = [0] * n_addrs
    n_snapshots = 0

    try:
        with open(path, errors='replace') as f:
            for line in f:
                if not line.startswith('DME: [DS]'):
                    continue
                parts = line[len('DME: [DS]'):].strip().split(',')
                if len(parts) < 2:
                    continue
                try:
                    t = int(parts[0])
                except ValueError:
                    continue
                h = parts[1]
                if len(h) < (hi + 1) * 2:
                    continue
                n_snapshots += 1
                for addr in range(lo, hi + 1):
                    idx = addr - lo
                    byte_str = h[addr*2:addr*2+2]
                    if 'x' in byte_str.lower():
                        continue
                    val = int(byte_str, 16)
                    n_valid[idx] += 1
                    if val != 0:
                        any_nonzero[idx] = True
                        distinct[idx].add(val)
                        if first_hit[idx] is None:
                            first_hit[idx] = (t, val)
    except FileNotFoundError:
        return None

    return {
        'n_snapshots': n_snapshots,
        'per_addr': {
            lo + i: {'any_nonzero': any_nonzero[i], 'first_hit': first_hit[i],
                     'distinct': sorted(distinct[i]), 'n_valid': n_valid[i]}
            for i in range(n_addrs)
        }
    }


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('log_dirs', nargs='*', default=[
        str(Path.home() / 'coding_projects/944/tmp/dme_klr/dash_logs'),
        str(Path.home() / 'coding_projects/944/tmp/dme_klr/v_dash_logs'),
    ])
    ap.add_argument('--lo', default='0x00', help='Low address, inclusive (default 0x00)')
    ap.add_argument('--hi', default='0x7F', help='High address, inclusive (default 0x7F)')
    args = ap.parse_args()

    lo = parse_addr(args.lo)
    hi = parse_addr(args.hi)

    logs = find_logs(args.log_dirs)
    if not logs:
        print(f"No .dash.log files found in: {', '.join(args.log_dirs)}")
        sys.exit(1)

    print(f"\n{'='*100}")
    print(f"  Scanning IRAM[0x{lo:02X}..0x{hi:02X}] across {len(logs)} log(s)")
    print(f"{'='*100}\n")

    # addr -> [(test_name, first_hit, distinct), ...] for logs where it went non-zero
    findings = {addr: [] for addr in range(lo, hi + 1)}
    total_valid = {addr: 0 for addr in range(lo, hi + 1)}
    logs_checked = 0

    for log in logs:
        name = log.name
        if name.endswith('.dash.log'):
            name = name[:-len('.dash.log')]
        result = scan_log_all_addrs(log, lo, hi)
        if result is None:
            continue
        logs_checked += 1
        for addr, info in result['per_addr'].items():
            total_valid[addr] += info['n_valid']
            if info['any_nonzero']:
                findings[addr].append((name, info['first_hit'], info['distinct']))

    flagged = {addr: hits for addr, hits in findings.items() if hits}
    always_zero = {addr for addr in range(lo, hi + 1)
                    if addr not in flagged and total_valid[addr] > 0}
    no_data = {addr for addr in range(lo, hi + 1) if total_valid[addr] == 0}

    print(f"{'Addr':>6}  {'# logs':>7}  {'first offender (test @ time = value)'}")
    print(f"{'-'*6}  {'-'*7}  {'-'*60}")
    for addr in sorted(flagged.keys()):
        hits = flagged[addr]
        first_test, first_hit, distinct = hits[0]
        first_str = f"{first_test} @ t={first_hit[0]}ms = 0x{first_hit[1]:02X}" if first_hit else "--"
        print(f"0x{addr:02X}    {len(hits):>7}  {first_str}")

    print(f"\n{'='*100}")
    print(f"  ALWAYS ZERO: {len(always_zero)} address(es) never went non-zero in any log")
    print(f"  (with real, valid samples — not just uninitialized 'xx')")
    print(f"{'='*100}")
    if always_zero:
        addrs = sorted(always_zero)
        # print in rows of 8 for readability
        for i in range(0, len(addrs), 8):
            row = addrs[i:i+8]
            print("  " + "  ".join(f"0x{a:02X}" for a in row))

    if no_data:
        print(f"\n  NOTE: {len(no_data)} address(es) had NO valid samples at all in any log")
        print(f"  (always 'xx'/uninitialized — no evidence either way, not counted as")
        print(f"  'always zero' above): {', '.join(f'0x{a:02X}' for a in sorted(no_data))}")

    print(f"\n{'='*100}")
    print(f"  SUMMARY: {len(flagged)} flagged (went non-zero), {len(always_zero)} always zero,")
    print(f"  {len(no_data)} no data — out of {hi-lo+1} address(es), across {logs_checked} log(s) checked.")
    if flagged:
        print(f"\n  Flagged addresses: {', '.join(f'0x{a:02X}' for a in sorted(flagged.keys()))}")
        print(f"\n  For full per-log detail on any one address, run:")
        print(f"    python3 check_memory_location.py 0x{sorted(flagged.keys())[0]:02X}")
    print(f"{'='*100}\n")


if __name__ == '__main__':
    main()
