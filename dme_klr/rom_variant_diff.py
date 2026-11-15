#!/usr/bin/env python3
"""
rom_variant_diff.py — compare the dashboard tests of two or more ROM pairs

Each ROM pair's tests write in its own folder, $DMEKLR_TMP/dme_klr/<rom>
(89, 86, carpokes, or the DME image's name; paths.sh). For every test that
ran on more than one of the given pairs this lists, side by side:
  * its verdict (PASS / WARN / FAIL, from validation.log) and the
    validator's detail line (fuel, RPM, ASE, timing, ...)
  * the values that differ: each DME and KLR [STATUS] field (and the DME
    RPM) of its .dash.log, as the mean over the second half of the run
    (settled) and its last value, against the first ROM pair given (the
    reference). The fields that differ most come first.

Different ROMs are expected to differ; this shows where and by how much,
not whether that's right.

Usage:
    python3 rom_variant_diff.py [options] <rom> <rom> [<rom> ...]
      --sim verilator|iverilog|both   which suite's logs (default both)
      --test NAME     just this test (repeatable)
      --top N         differing fields to show per test and ECU (default 8)
      --all           every test, also those whose verdicts and values match
      --json          JSON for the bridge (GET /runall/romdiff)
      --base DIR      the folder holding the ROM folders
                      (default $DMEKLR_TMP/dme_klr)

Exit: 0, or 2 when fewer than two of the ROM folders exist.
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dmeklr_paths import TMP  # noqa: E402
from compare_sim_logs import extract_status_fields  # noqa: E402

SIDES = {'verilator': 'v_dash_logs', 'iverilog': 'dash_logs'}
# Where the CPU happens to be when a snapshot lands, not what it computed
NOISE = {'DME': {'t', 'b', 'wdog'}, 'KLR': {'t'}}
REL_MIN = 0.02      # a mean must differ by 2 % ...
ABS_MIN = 1.0       # ... and by more than one count to be listed
RPM_RE = re.compile(r'\((\d+) RPM\)')
ROM_RE = re.compile(r'^(DME|KLR): \[ROM\] (\S+)')


def read_validation(path):
    """{test: (verdict, detail)} from a validation.log (the last line per test)."""
    out = {}
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            for line in f:
                p = line.rstrip('\n').split('\t')
                if len(p) >= 2 and p[0] in ('PASS', 'WARN', 'FAIL'):
                    out[p[1].strip()] = (p[0], p[2].strip() if len(p) > 2 else '')
    except OSError:
        pass
    return out


def dash_stats(path):
    """{'roms': {DME: file, KLR: file}, 'DME': {field: stats}, 'KLR': {...}}
    from a .dash.log, or None. stats = {mean, last, mode}: mean over the
    second half of the run (by row), last value, most common value."""
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    except OSError:
        return None
    res = {'roms': {}}
    for line in lines[:10]:
        m = ROM_RE.match(line)
        if m:
            res['roms'][m.group(1)] = m.group(2)
    for ecu in ('DME', 'KLR'):
        prefix = f'{ecu}: [STATUS]'
        rows = extract_status_fields(lines, prefix)
        if ecu == 'DME':
            st = [l for l in lines if l.startswith(prefix)]
            for row, l in zip(rows, st):
                m = RPM_RE.search(l)
                if m:
                    row['rpm'] = int(m.group(1))
        series = {}
        for row in rows:
            for k, v in row.items():
                if k.lower() not in NOISE[ecu] and isinstance(v, int):
                    series.setdefault(k, []).append(v)
        stats = {}
        for k, vals in series.items():
            half = vals[len(vals) // 2:] or vals
            counts = {}
            for v in vals:
                counts[v] = counts.get(v, 0) + 1
            stats[k] = {'mean': sum(half) / len(half), 'last': vals[-1],
                        'mode': max(counts, key=counts.get), 'n': len(vals)}
        res[ecu] = stats
    return res


def value_diffs(ref, other, top):
    """The fields that differ most between two dash_stats, per ECU."""
    out = {}
    for ecu in ('DME', 'KLR'):
        a, b = ref.get(ecu, {}), other.get(ecu, {})
        rows = []
        for k in sorted(set(a) | set(b)):
            if k not in a or k not in b:
                rows.append({'field': k, 'ref': a.get(k, {}).get('mean'), 'val': b.get(k, {}).get('mean'),
                             'ref_last': a.get(k, {}).get('last'), 'last': b.get(k, {}).get('last'),
                             'rel': 1.0, 'note': 'only in one'})
                continue
            if k.startswith('flag_'):
                # flag bytes: the value it holds most of the run, not a mean
                if a[k]['mode'] != b[k]['mode']:
                    rows.append({'field': k, 'ref': a[k]['mode'], 'val': b[k]['mode'],
                                 'ref_last': a[k]['last'], 'last': b[k]['last'], 'rel': 0.5, 'hex': True,
                                 'note': 'bits ' + format(a[k]['mode'] ^ b[k]['mode'], '#04x')})
                continue
            ma, mb = a[k]['mean'], b[k]['mean']
            d = abs(ma - mb)
            rel = d / max(abs(ma), abs(mb), 1.0)
            if d > ABS_MIN and rel >= REL_MIN:
                rows.append({'field': k, 'ref': round(ma, 1), 'val': round(mb, 1),
                             'ref_last': a[k]['last'], 'last': b[k]['last'], 'rel': round(rel, 3)})
        rows.sort(key=lambda r: -r['rel'])
        out[ecu] = {'count': len(rows), 'fields': rows[:top]}
    return out


def compare_side(base, roms, side, tests, top, show_all):
    sub = SIDES[side]
    def has_logs(r):
        v = base / r / sub / 'validation.log'
        return (v.is_file() and v.stat().st_size > 0) or any((base / r / sub).glob('*.dash.log'))
    present = [r for r in roms if has_logs(r)]
    res = {'sim': side, 'roms': present, 'missing': [r for r in roms if r not in present],
           'images': {}, 'tests': [], 'differing': 0, 'total': 0}
    if len(present) < 2:
        return res
    verdicts = {r: read_validation(base / r / sub / 'validation.log') for r in present}
    names = set()
    for r in present:
        names |= set(verdicts[r])
        names |= {p.name[:-len('.dash.log')] for p in (base / r / sub).glob('*.dash.log')}
    if tests:
        names &= set(tests)
    ref = present[0]
    for name in sorted(names):
        stats = {r: dash_stats(base / r / sub / f'{name}.dash.log') for r in present}
        ran = [r for r in present if name in verdicts[r] or stats[r]]
        if len(ran) < 2:
            continue
        res['total'] += 1
        for r in ran:
            if stats[r] and stats[r]['roms'] and r not in res['images']:
                res['images'][r] = stats[r]['roms']
        row = {'test': name, 'verdicts': {}, 'values': {}}
        for r in present:
            v = verdicts[r].get(name)
            row['verdicts'][r] = {'verdict': v[0], 'detail': v[1]} if v else \
                {'verdict': 'NO VERDICT' if stats[r] else 'MISSING', 'detail': ''}
        vset = {row['verdicts'][r]['verdict'] for r in ran}
        row['verdict_differs'] = len(vset) > 1
        base_r = ref if stats.get(ref) else next((r for r in ran if stats[r]), None)
        row['ref'] = base_r
        nvals = 0
        if base_r:
            for r in ran:
                if r != base_r and stats[r]:
                    d = value_diffs(stats[base_r], stats[r], top)
                    row['values'][r] = d
                    nvals += d['DME']['count'] + d['KLR']['count']
        row['values_differ'] = nvals
        if row['verdict_differs'] or nvals:
            res['differing'] += 1
        if show_all or row['verdict_differs'] or nvals:
            row['ran'] = ran
            res['tests'].append(row)
    return res


def fmt(v, hexv=False):
    if v is None:
        return '-'
    if hexv:
        return f'0x{int(v):02x}'
    return f'{v:g}' if isinstance(v, float) else str(v)


def print_text(results, roms):
    for res in results:
        print(f"== {res['sim']} ({', '.join(res['roms']) or 'no logs'}) ==")
        if res['missing']:
            print(f"   no {res['sim']} logs for: {', '.join(res['missing'])}")
        if len(res['roms']) < 2:
            print('   fewer than two ROM folders have logs: nothing to compare\n')
            continue
        for r, im in res['images'].items():
            print(f"   {r}: DME {im.get('DME', '?')}  KLR {im.get('KLR', '?')}")
        print()
        hdr = 'TEST'.ljust(40) + ''.join(r.ljust(14) for r in res['roms']) + 'VALUES'
        print(hdr)
        print('-' * len(hdr))
        for t in res['tests']:
            vs = ''.join(t['verdicts'][r]['verdict'].ljust(14) for r in res['roms'])
            mark = ('  <-- VERDICT' if t['verdict_differs'] else '')
            print(t['test'].ljust(40) + vs + (f"{t['values_differ']} differ" if t['values_differ'] else 'same') + mark)
        print()
        for t in res['tests']:
            if not t['values'] and not t['verdict_differs']:
                continue
            print(f"-- {t['test']}")
            for r in res['roms']:
                v = t['verdicts'][r]
                print(f"   {r:<10} {v['verdict']:<5} {v['detail'][:160]}")
            for r, d in t['values'].items():
                for ecu in ('DME', 'KLR'):
                    if not d[ecu]['count']:
                        continue
                    more = d[ecu]['count'] - len(d[ecu]['fields'])
                    print(f"   {ecu} {r} vs {t['ref']}: {d[ecu]['count']} field(s) differ"
                          + (f' ({more} more not shown)' if more > 0 else ''))
                    for f in d[ecu]['fields']:
                        h = f.get('hex', False)
                        print(f"      {f['field']:<14} {fmt(f['ref'], h):>9} -> {fmt(f['val'], h):<9}"
                              f"  last {fmt(f['ref_last'], h)} -> {fmt(f['last'], h)}"
                              + (f"  ({f['note']})" if f.get('note') else f"  ({f['rel'] * 100:.0f} %)"))
            print()
        print(f"{res['differing']} of the {res['total']} test(s) run on two or more differ in verdict or values "
              f"across {', '.join(res['roms'])}\n")


def main():
    ap = argparse.ArgumentParser(description='Compare the dashboard tests of two or more ROM pairs')
    ap.add_argument('roms', nargs='+', help='ROM folders under $DMEKLR_TMP/dme_klr (89, 86, carpokes, ...)')
    ap.add_argument('--sim', choices=['verilator', 'iverilog', 'both'], default='both')
    ap.add_argument('--test', action='append', default=[])
    ap.add_argument('--top', type=int, default=8)
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--base', default=str(TMP / 'dme_klr'))
    a = ap.parse_args()
    base = Path(a.base)
    roms = []
    for r in a.roms:
        if not re.fullmatch(r'[\w.+-]+', r) or r.startswith('.'):
            ap.error(f'not a ROM folder name: {r}')
        if r not in roms:
            roms.append(r)
    if len(roms) < 2:
        ap.error('give two or more ROM folders')
    sides = ['verilator', 'iverilog'] if a.sim == 'both' else [a.sim]
    results = [compare_side(base, roms, s, a.test, max(1, a.top), a.all) for s in sides]
    if a.json:
        json.dump({'base': str(base), 'roms': roms, 'sides': results}, sys.stdout)
        print()
    else:
        print_text(results, roms)
    return 0 if any(len(r['roms']) >= 2 for r in results) else 2


if __name__ == '__main__':
    sys.exit(main())
