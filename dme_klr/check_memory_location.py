#!/usr/bin/env python3
"""
check_memory_location.py — scan every DME simulation log (iverilog +
Verilator) to see if a specific IRAM address was EVER non-zero.

Reads "DME: [DS]" snapshot lines (raw hex IRAM dumps) — the same log
format validate_dash_log.py / extract_timing_adv.py / analyze_fqs_fuel.py
all use — and checks ONE byte address across every *.dash.log file found.

Scope: DME IRAM only (0x00-0x7F). The KLR side only exposes a handful of
specific addresses as named fields in "KLR: [STATUS]" lines (ram[16],
ram[17], ram[26], ram[33], ram[38]) — there's no full KLR memory dump to
check arbitrary addresses against.

Address format: bare numbers are treated as HEX, matching this codebase's
own convention (e.g. "33" means iram[0x33], same as "ram[33]" elsewhere
in this project — NOT decimal 33). "0x33" and "33h" are also accepted.

Usage:
    python3 check_memory_location.py <address> [log_dir ...]

Examples:
    python3 check_memory_location.py 33
    python3 check_memory_location.py 0x31 dash_logs v_dash_logs

Defaults to both the iverilog and Verilator log directories:
    ~/coding_projects/944/tmp/dme_klr/dash_logs
    ~/coding_projects/944/tmp/dme_klr/v_dash_logs
"""
import sys
from pathlib import Path


def parse_addr(s):
    s = s.strip().lower()
    if s.startswith('0x'):
        return int(s, 16)
    if s.endswith('h'):
        return int(s[:-1], 16)
    # Bare numbers default to HEX here, matching this codebase's own
    # address-naming convention (see docstring) — deliberately NOT the
    # more common "bare number = decimal" assumption.
    return int(s, 16)


def scan_log(path, addr):
    """Return {any_nonzero, first_hit, distinct, n} for one log, or None
    if the file doesn't exist."""
    any_nonzero = False
    first_hit = None   # (timestamp_ms, value)
    distinct = set()
    n = 0
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
                if len(h) < (addr + 1) * 2:
                    continue
                byte_str = h[addr*2:addr*2+2]
                if 'x' in byte_str.lower():
                    continue  # uninitialized ('xx') sample — skip, not a real 0
                val = int(byte_str, 16)
                n += 1
                if val != 0:
                    any_nonzero = True
                    distinct.add(val)
                    if first_hit is None:
                        first_hit = (t, val)
    except FileNotFoundError:
        return None
    return {'any_nonzero': any_nonzero, 'first_hit': first_hit,
            'distinct': sorted(distinct), 'n': n}


def find_logs(log_dirs):
    logs = []
    for d in log_dirs:
        d = Path(d)
        if d.is_dir():
            logs.extend(sorted(d.glob('*.dash.log')))
    return logs


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    addr = parse_addr(sys.argv[1])
    log_dirs = sys.argv[2:] if len(sys.argv) > 2 else [
        str(Path.home() / 'coding_projects/944/tmp/dme_klr/dash_logs'),
        str(Path.home() / 'coding_projects/944/tmp/dme_klr/v_dash_logs'),
    ]

    logs = find_logs(log_dirs)
    if not logs:
        print(f"No .dash.log files found in: {', '.join(log_dirs)}")
        sys.exit(1)

    print(f"\n{'='*100}")
    print(f"  Checking IRAM[0x{addr:02X}] ({addr} decimal) across {len(logs)} log(s)")
    print(f"{'='*100}\n")
    print(f"{'Test':<34} {'snapshots':>10} {'ever!=0':>9} {'first hit':>18} {'distinct values'}")
    print(f"{'-'*34} {'-'*10} {'-'*9} {'-'*18} {'-'*30}")

    offenders = 0
    checked = 0
    for log in logs:
        name = log.name
        if name.endswith('.dash.log'):
            name = name[:-len('.dash.log')]
        result = scan_log(log, addr)
        if result is None:
            continue
        checked += 1
        flag = "YES" if result['any_nonzero'] else "no"
        if result['any_nonzero']:
            offenders += 1
        first = f"t={result['first_hit'][0]}ms=0x{result['first_hit'][1]:02X}" if result['first_hit'] else "--"
        distinct_vals = result['distinct']
        distinct_str = ', '.join(f"0x{v:02X}" for v in distinct_vals[:8])
        if len(distinct_vals) > 8:
            distinct_str += f" (+{len(distinct_vals)-8} more)"
        print(f"{name:<34} {result['n']:>10} {flag:>9} {first:>18} {distinct_str}")

    print(f"\n{'='*100}")
    print(f"  SUMMARY: {offenders} of {checked} log(s) showed IRAM[0x{addr:02X}] go non-zero")
    print(f"{'='*100}\n")


if __name__ == '__main__':
    main()
