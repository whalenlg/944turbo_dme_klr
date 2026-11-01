#!/usr/bin/env python3
# ============================================================
#  test_snap.py — snapshots from the regression tests
#
#  The regression runs (run_dashboard_tests.sh, v_run_dashboard_tests.sh,
#  run_dashboard_parallel.sh) use their own builds with each test's
#  scripted stimulus, so they can't save the live sim's state.bin. When a
#  test warns or fails, this records where: a folder in the snapshot
#  directory with request.json (test, its -D flags, ROM images, time and
#  the line that triggered it). The live dashboard lists it with the
#  other snapshots; LOAD builds the test with the live debugger's hooks
#  (build_live.sh --test <name>) and runs it to that time, paused.
#
#  Usage:
#    test_snap.py scan <test> <log[.gz]> [--fail|--warn <detail>] [--script <runner.sh>]
#        write requests for the first warning/error of each kind in the
#        log (at most 5); with --fail / --warn (the validator's verdict,
#        run_dashboard_parallel.sh), one at the first t=<ms> its detail
#        names, else at the end of the run if the log had no warning;
#        a plain scan replaces the test's earlier requests
#    test_snap.py add <test> <ms> [label] [--script <runner.sh>]
#        a request for a moment you pick, without running the regression:
#        LOAD in the dashboard then builds the test and runs it there
#    test_snap.py defines <test> [--script <runner.sh>]
#        print the test's -D flags, one per line (used by build_live.sh)
#
#  Env: DMEKLR_SNAPDIR (default ../tmp/dme_klr/snapshots beside the
#       checkout, as the bridge uses), DME_ROM_DIR / DME_ROM_FILE /
#       KLR_ROM_DIR / KLR_ROM_FILE, DASH_INTERVAL_MS
# ============================================================
import gzip
import json
import os
import re
import shlex
import shutil
import sys
import time
from pathlib import Path

LIVE = Path(__file__).resolve().parent
DMEKLR = LIVE.parent
REPO = DMEKLR.parent
SNAPDIR = Path(os.environ.get('DMEKLR_SNAPDIR') or REPO.parent / 'tmp' / 'dme_klr' / 'snapshots')
MAX_PER_TEST = 5


def test_defines(name, script):
    """The -D flags run_test gets for <name> in the runner script: the
    one-line form in its case block, else the multi-line one in run_all."""
    text = Path(script).read_text()
    # join continuation lines
    lines = re.sub(r'\\\n', ' ', text).split('\n')
    found = None
    for ln in lines:
        m = re.match(rf'\s*{re.escape(name)}\)\s+run_test\s+{re.escape(name)}\s+(.*?);;', ln)
        if m:
            found = m.group(1)
            break
    if found is None:
        for ln in lines:
            m = re.match(rf'\s*run_test\s+{re.escape(name)}\s+(.*)$', ln)
            if m:
                found = m.group(1)
                break
    if found is None:
        return None
    args = [a for a in shlex.split(found, comments=True) if a != '$IARG']
    if args and args[0].isdigit():   # optional interval override
        args = args[1:]
    return [a for a in args if a.startswith('-D') and a not in ('-DKLR_DEBUG', '-DDME_DEBUG', '-DDME_DEEP_DEBUG')]


def roms():
    return {
        'dme': os.environ.get('DME_ROM_DIR', str(REPO / 'bin_images' / 'dme') + '/')
               + os.environ.get('DME_ROM_FILE', '28PIN_DME_PERFORMANCE.mem'),
        'klr': os.environ.get('KLR_ROM_DIR', str(REPO / 'bin_images' / 'klr') + '/')
               + os.environ.get('KLR_ROM_FILE', '87KLR_951.mem'),
    }


WARN = re.compile(r'\[WARN\]|WARNING|ERROR')
T_MS = re.compile(r'\bt=(\d+)\s*ms|^(?:DME|KLR): \[DS\] (\d+),|^\[DS\] (\d+),')


def kind_of(line):
    """A short tag for the warning, also used to keep one per kind"""
    s = re.sub(r'^(DME|KLR): \[\w+\]\s*(t=\d+\s*ms\s*)?', '', line)
    s = re.sub(r'\b(0x)?[0-9A-Fa-f]*\d[0-9A-Fa-f.]*\b', ' ', s)   # numbers, hex included
    words = [w for w in re.split(r'[^a-z]+', s.lower()) if len(w) > 1 and w not in ('ms', 'rpm', 'at', 'from')]
    return '-'.join(words[:4]) or 'warn'


def req_test(d):
    try:
        return json.loads((d / 'request.json').read_text()).get('test')
    except (OSError, ValueError):
        return None


def req_reason(d):
    try:
        r = json.loads((d / 'request.json').read_text())
        return f"{r.get('source', 'log')}-{r.get('reason')}"
    except (OSError, ValueError):
        return None


def scan(name, log, fail, script, verdict='FAIL'):
    opener = gzip.open if str(log).endswith('.gz') else open
    hits, last_ms, saw_ds = [], 0, False
    interval = int(os.environ.get('DASH_INTERVAL_MS', '100'))
    seen = set()
    try:
        with opener(log, 'rt', errors='replace') as f:
            for line in f:
                line = line.rstrip('\n')
                m = T_MS.search(line)
                if m:
                    last_ms = int(next(g for g in m.groups() if g))
                    saw_ds = saw_ds or '[DS]' in line
                if WARN.search(line) and not line.startswith('SIM: '):
                    k = kind_of(line)
                    if k in seen:
                        continue
                    seen.add(k)
                    # Run to just after it: 1 ms past a line that carries
                    # its own time (t=<ms>, rounded down), else to the next
                    # [DS] after the last one seen
                    own = re.search(r'\bt=(\d+)\s*ms', line)
                    hits.append((last_ms, 'warn', line, k, 1 if own else interval))
                    if len(hits) >= MAX_PER_TEST:
                        break
    except OSError as e:
        sys.exit(f'test_snap.py: {log}: {e}')
    if fail is not None:
        # The validator's verdict: at the first time its detail names
        # ("at t=6410ms", "@t=812ms"), else at the end of the run, and
        # then only if the log had no warning of its own
        # the problem itself is after "WARN:" / "FAIL:" when the detail has one
        mark = max(fail.find('WARN:'), fail.find('FAIL:'))
        tm = re.search(r'\bt=(\d+)\s*ms', fail[mark:] if mark >= 0 else '') or re.search(r'\bt=(\d+)\s*ms', fail)
        warned = bool(hits)
        hits = []
        if tm:
            hits.append((int(tm.group(1)), verdict.lower(), f'{verdict} {name}: {fail}', verdict.lower(), 1))
        elif not warned and saw_ds:   # a run with no [DS] (killed, crashed) has nothing to show
            hits.append((last_ms, verdict.lower(), f'{verdict} {name}: {fail}', verdict.lower(), 0))

    SNAPDIR.mkdir(parents=True, exist_ok=True)
    if fail is None:
        # a fresh run replaces this test's earlier requests
        for d in SNAPDIR.iterdir():
            req = d / 'request.json'
            if req.is_file() and not (d / 'state.bin').exists():
                if req_test(d) == name:
                    shutil.rmtree(d, ignore_errors=True)
    elif any(req_test(d) == name and req_reason(d) == 'validator-' + verdict.lower() for d in SNAPDIR.iterdir()):
        return 0   # this verdict is already recorded

    defines = test_defines(name, script) or []
    for t_ms, reason, line, k, after in hits:
        write_request(name, script, defines, t_ms, (t_ms + after) * 1_000_000, reason, line, k,
                      'log' if fail is None else 'validator', str(Path(log).resolve()))
    return 0


def write_request(name, script, defines, t_ms, t_ns, reason, line, k, source, log):
    SNAPDIR.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime('%Y%m%d-%H%M%S')
    d = SNAPDIR / f'{stamp}-t{t_ms}ms-{name}-{k}'[:120]
    n = 2
    while d.exists():
        d = SNAPDIR / f'{stamp}-t{t_ms}ms-{name}-{k}-{n}'[:120]
        n += 1
    d.mkdir(parents=True)
    (d / 'request.json').write_text(json.dumps({
        'format': 'dme-klr-test-snapshot', 'version': 1,
        'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'test': name, 'script': str(Path(script).resolve()), 'defines': defines,
        'roms': roms(), 'interval_ms': int(os.environ.get('DASH_INTERVAL_MS', '100')),
        'source': source, 't_ms': t_ms, 't_ns': t_ns, 'reason': reason, 'trigger': line,
        'log': log,
    }, indent=1) + '\n')
    print(f'  SNAP: {name} t={t_ms} ms {reason}: {d}')
    return d


def add(name, ms, script, label):
    """A request for a moment chosen by hand, no regression run needed"""
    defines = test_defines(name, script)
    if defines is None:
        sys.exit(f'test_snap.py: no test "{name}" in {script}')
    t_ns = int(round(ms * 1e6))
    sim = next((int(d.split('=', 1)[1]) for d in defines if d.startswith('-DSIM_TIME=')), None)
    if sim is not None and t_ns > sim:
        sys.exit(f'test_snap.py: {name} only runs to {sim / 1e6:g} ms')
    tag = re.sub(r'[^\w.+-]+', '-', label).strip('-')[:40] if label else 'manual'
    write_request(name, script, defines, int(ms), t_ns, 'manual',
                  f'{label or "chosen time"} ({ms:g} ms)', tag, 'manual', None)
    return 0


def main(argv):
    if len(argv) < 3 or argv[1] not in ('scan', 'defines', 'add'):
        sys.exit('usage: test_snap.py scan <test> <log> [--fail|--warn <detail>] [--script <sh>]\n'
                 '       test_snap.py add <test> <ms> [label] [--script <sh>]\n'
                 '       test_snap.py defines <test> [--script <sh>]')
    cmd, name, rest = argv[1], argv[2], argv[3:]
    script = DMEKLR / 'run_dashboard_tests.sh'
    fail = None
    verdict = 'FAIL'
    log = None
    extra = []
    i = 0
    while i < len(rest):
        if rest[i] == '--script':
            script = Path(rest[i + 1]); i += 2
        elif rest[i] in ('--fail', '--warn'):
            verdict = rest[i][2:].upper()
            fail = rest[i + 1]; i += 2
        elif log is None:
            log = rest[i]; i += 1
        else:
            extra.append(rest[i]); i += 1
    if cmd == 'add':
        pos = [log] + extra if log else extra
        try:
            ms = float(pos[0])
        except (IndexError, ValueError):
            sys.exit('test_snap.py add needs a time in ms')
        return add(name, ms, script, ' '.join(pos[1:]))
    if cmd == 'defines':
        d = test_defines(name, script)
        if d is None:
            sys.exit(f'test_snap.py: no test "{name}" in {script}')
        print('\n'.join(d))
        return 0
    if not log:
        sys.exit('test_snap.py scan needs a log file')
    return scan(name, log, fail, script, verdict)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
