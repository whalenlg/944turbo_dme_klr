#!/usr/bin/env python3
"""
test_groups.py: the regression-test groups, as the manuals list them

The RUN REGRESSIONS panel of the dashboard lists the regression tests in the
groups of the manuals' Appendix A (Idle, Closed-loop drive cycles, ...), each
with a MANUAL button to its section. The bridge reads them from
test_groups.json beside this script; this script makes that file from
docs/USER_MANUAL.md (plus the groups only docs/DEVELOPER_MANUAL.md has,
marked dev_only) and checks that the file and both manuals still agree.
Each group heading carries a stable anchor, <a id="tests-..."></a>, the
same in both manuals: the panel links to it.

Usage:
    python3 test_groups.py gen     print test_groups.json from the manual
    python3 test_groups.py check   exit 1 (and say why) if test_groups.json
                                   differs from the manuals, the manuals
                                   differ from each other, or a test is
                                   in no group or unknown
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MANUAL = os.path.join(REPO, 'docs', 'USER_MANUAL.md')
DEV_MANUAL = os.path.join(REPO, 'docs', 'DEVELOPER_MANUAL.md')
OUT = os.path.join(HERE, 'test_groups.json')


def groups_in(path):
    """[{name, anchor, tests}] from a manual's Appendix A"""
    text = open(path, encoding='utf-8').read()
    m = re.search(r'^## Appendix A\..*?$(.*?)^## Appendix B', text, re.M | re.S)
    if not m:
        sys.exit('test_groups.py: no Appendix A in ' + path)
    groups, cur = [], None
    for line in m.group(1).splitlines():
        h = re.match(r'^### (?:<a id="([^"]+)"></a>)?(.+)$', line)
        if h:
            name = h.group(2).strip()
            cur = None if name == 'Run times' else {'name': name, 'anchor': h.group(1), 'tests': []}
            if cur:
                groups.append(cur)
            continue
        if not cur or not line.startswith('| `'):
            continue
        cell = line.split('|')[1]
        names = re.findall(r'`([A-Za-z0-9_]+)`', cell)
        # `cl_ramp_to_6000_FQS0` … `FQS7`: the whole run of them
        r = re.match(r'^(.*?)(\d+)$', names[0]) if len(names) == 2 and '…' in cell else None
        if r and names[1].endswith(tuple('0123456789')):
            last = int(re.search(r'(\d+)$', names[1]).group(1))
            names = [f'{r.group(1)}{i}' for i in range(int(r.group(2)), last + 1)]
        cur['tests'] += names
    return groups


def from_manual():
    groups = groups_in(MANUAL)
    names = {g['name'] for g in groups}
    groups += [{**g, 'dev_only': True} for g in groups_in(DEV_MANUAL) if g['name'] not in names]
    return {'format': 'dme-klr-test-groups', 'version': 2,
            'source': 'docs/USER_MANUAL.md and docs/DEVELOPER_MANUAL.md, Appendix A', 'groups': groups}


def main(argv):
    cmd = argv[0] if argv else ''
    if cmd == 'gen':
        print(json.dumps(from_manual(), indent=1))
        return 0
    if cmd == 'check':
        want = from_manual()
        have = json.load(open(OUT, encoding='utf-8'))
        bad = []
        if have.get('groups') != want['groups']:
            bad.append(f'{OUT} differs from the manuals: run  python3 {sys.argv[0]} gen > {OUT}')
        dev = {g['name']: g for g in groups_in(DEV_MANUAL)}
        for g in groups_in(MANUAL):
            d = dev.get(g['name'])
            if not d:
                bad.append(f'group {g["name"]} is in USER_MANUAL.md but not DEVELOPER_MANUAL.md')
            elif d != g:
                bad.append(f'group {g["name"]} differs between the two manuals (tests or anchor)')
        for g in want['groups']:
            if not g['anchor']:
                bad.append(f'group {g["name"]} has no <a id="tests-..."></a> anchor in its heading')
        r = subprocess.run([sys.executable, os.path.join(REPO, 'dme_klr', 'test_opts.py'), 'tests-json'],
                           capture_output=True, text=True)
        known = set(json.loads(r.stdout)['tests']) if r.returncode == 0 else None
        names = [t for g in have.get('groups', []) for t in g['tests']]
        if known is not None:
            # (dev-only groups hold tests test_opts.py doesn't, e.g. log replays)
            unknown = [t for g in have.get('groups', []) if not g.get('dev_only') for t in g['tests'] if t not in known]
            if unknown:
                bad.append('not a test (test_opts.py tests-json): ' + ' '.join(unknown))
            missing = sorted(known - set(names))
            if missing:
                bad.append('in no group: ' + ' '.join(missing))
        dup = sorted({t for t in names if names.count(t) > 1})
        if dup:
            bad.append('in more than one group: ' + ' '.join(dup))
        for b in bad:
            print('test_groups.py: ' + b, file=sys.stderr)
        if not bad:
            print(f'test_groups.py: {len(names)} tests in {len(have["groups"])} groups, as the manuals list them')
        return 1 if bad else 0
    print(__doc__.strip())
    return 0 if cmd in ('-h', '--help') else 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
