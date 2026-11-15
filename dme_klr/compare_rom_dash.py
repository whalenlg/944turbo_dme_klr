#!/usr/bin/env python3
"""
compare_rom_dash.py — compare the dashboard values (.dash.log) of the same
tests run on two or more ROM variants, one simulator at a time.

Usage:
    python3 compare_rom_dash.py [--out FILE] [--max-issues N] BASE SIM_DIR V1 V2 [V3 ...]

    BASE      the folder holding the ROM pairs' log folders ($DMEKLR_TMP/dme_klr)
    SIM_DIR   dash_logs (iverilog) or v_dash_logs (Verilator)
    V1 ...    ROM folder names (89, 86, carpokes, a DME image's name); V1 is the
              reference, and each other variant is compared with it

For each test that both variants have a .dash.log for, it runs the same
comparison compare_sim_logs.py makes between iverilog and Verilator
(compare_dash: the DME/KLR [DS] snapshot fields, [PHASE], [STATUS] and the
event counts) and prints one row per test: MATCH, NEAR-MATCH or DIFF, and the
first differences, labelled with the variants' names, then the [STATUS]
fields that differ most (their ranges in each run and the biggest gap). compare_rom_variants.sh
runs it after its PASS/WARN/FAIL table, so two variants that both PASS but
fuel, time or idle differently still show up.

Exit: 0 (always, unless the arguments are wrong: 2).
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare_sim_logs  # noqa: E402
from compare_sim_logs import compare_dash, read_lines  # noqa: E402


def relabel(text, a, b):
    """compare_dash names its two sides iv / vl: name them after the variants."""
    text = re.sub(r'\biv=', f'{a}=', text)
    text = re.sub(r'\bvl=', f'{b}=', text)
    return text.replace('iv-vs-vl', f'{a}-vs-{b}')


def biggest(la, lb, a, b, n):
    """The [STATUS] fields that differ most between the two runs, matched by
    snapshot time: "DME fuel: 89 1162..1180, 86 1162..1931; max 86-89 +751 at 2102 ms"."""
    out = []
    for p in ('DME: [STATUS]', 'KLR: [STATUS]'):
        ra = {r['t']: r for r in compare_sim_logs.extract_status_fields(la, p)}
        rb = {r['t']: r for r in compare_sim_logs.extract_status_fields(lb, p)}
        common = sorted(set(ra) & set(rb))
        fields = {}
        for t in common:
            for f, va in ra[t].items():
                vb = rb[t].get(f)
                if f == 't' or not isinstance(va, (int, float)) or not isinstance(vb, (int, float)):
                    continue
                d = vb - va
                st = fields.setdefault(f, {'n': 0, 'max': 0, 't': None, 'a': [], 'b': []})
                st['a'].append(va); st['b'].append(vb)
                if d:
                    st['n'] += 1
                    if abs(d) > abs(st['max']):
                        st['max'], st['t'] = d, t
        for f, st in fields.items():
            if st['n']:
                out.append((st['n'] / max(1, len(common)), abs(st['max']), p.split(':')[0], f, st))
    out.sort(key=lambda x: (-x[0], -x[1]))
    rows = []
    for frac, _, cpu, f, st in out[:n]:
        rows.append(f'{cpu} {f}: {a} {min(st["a"])}..{max(st["a"])}, {b} {min(st["b"])}..{max(st["b"])}; '
                    f'differs in {frac:.0%} of snapshots, most {b}-{a} {st["max"]:+} at {st["t"]} ms')
    return rows


def tests_in(folder):
    try:
        return {f[:-len('.dash.log')] for f in os.listdir(folder) if f.endswith('.dash.log')}
    except OSError:
        return set()


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    p.add_argument('base')
    p.add_argument('sim_dir')
    p.add_argument('variants', nargs='+')
    p.add_argument('--out', help='also write the report to this file')
    p.add_argument('--max-issues', type=int, default=3,
                   help='differences shown per test (default 3)')
    a = p.parse_args()
    if len(a.variants) < 2:
        p.error('needs two variants or more')

    ref = a.variants[0]
    lines = []
    for other in a.variants[1:]:
        da = os.path.join(a.base, ref, a.sim_dir)
        db = os.path.join(a.base, other, a.sim_dir)
        both = sorted(tests_in(da) & tests_in(db))
        lines.append(f'-- values: {other} vs {ref} ({a.sim_dir}) --')
        if not both:
            lines.append(f'   no test has a .dash.log in both {ref}/{a.sim_dir} and {other}/{a.sim_dir}')
            lines.append('')
            continue
        counts = {}
        for t in both:
            la = read_lines(os.path.join(da, f'{t}.dash.log'))
            lb = read_lines(os.path.join(db, f'{t}.dash.log'))
            if la is None or lb is None:
                verdict, issues = 'ERROR', ['could not read a .dash.log']
            else:
                compare_sim_logs.CURRENT_TEST_NAME = t   # its per-test settings
                issues = compare_dash(la, lb, t)
                if not issues:
                    verdict = 'MATCH'
                elif all(i.startswith('NEAR-MATCH') for i in issues):
                    verdict = 'NEAR-MATCH'
                else:
                    verdict = 'DIFF'
            counts[verdict] = counts.get(verdict, 0) + 1
            lines.append(f'{verdict:<11} {t}')
            shown = [relabel(str(i), ref, other) for i in issues[:a.max_issues]]
            for s in shown:
                lines.append(f'              {s[:300]}{"..." if len(s) > 300 else ""}')
            if len(issues) > a.max_issues:
                lines.append(f'              (+{len(issues) - a.max_issues} more)')
            if verdict == 'DIFF':
                for r in biggest(la, lb, ref, other, a.max_issues):
                    lines.append(f'              {r}')
        lines.append('   ' + ', '.join(f'{n} {v}' for v, n in sorted(counts.items()))
                     + f' of {len(both)} test(s) both ran')
        lines.append(f'   Details for one test: python3 compare_sim_logs.py --dash '
                     f'{da}/<test>.dash.log {db}/<test>.dash.log <test> --verbose  '
                     f'(its "iv" is {ref}, "vl" is {other}; --plot draws {other} - {ref})')
        lines.append('')

    text = '\n'.join(lines)
    print(text)
    if a.out:
        with open(a.out, 'a') as f:
            f.write('\n' + text + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
