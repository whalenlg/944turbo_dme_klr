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
#    test_snap.py scan <test> <log[.gz]> [--fail <detail>] [--script <runner.sh>]
#        write requests for the first warning/error of each kind in the
#        log (at most 5), or, with --fail, one at the end of the run when
#        the log has none; earlier requests for that test are replaced
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


def scan(name, log, fail, script):
    opener = gzip.open if str(log).endswith('.gz') else open
    hits, last_ms = [], 0
    interval = int(os.environ.get('DASH_INTERVAL_MS', '100'))
    seen = set()
    try:
        with opener(log, 'rt', errors='replace') as f:
            for line in f:
                line = line.rstrip('\n')
                m = T_MS.search(line)
                if m:
                    last_ms = int(next(g for g in m.groups() if g))
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
    if fail is not None and not hits:
        hits.append((last_ms, 'fail', f'FAIL {name}: {fail}', 'fail', 0))

    SNAPDIR.mkdir(parents=True, exist_ok=True)
    if fail is None:
        # a fresh run replaces this test's earlier requests
        for d in SNAPDIR.iterdir():
            req = d / 'request.json'
            if req.is_file() and not (d / 'state.bin').exists():
                if req_test(d) == name:
                    shutil.rmtree(d, ignore_errors=True)
    elif any(req_test(d) == name for d in SNAPDIR.iterdir()):
        return 0   # the run's warnings are already recorded

    defines = test_defines(name, script) or []
    stamp = time.strftime('%Y%m%d-%H%M%S')
    for t_ms, reason, line, k, after in hits:
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
            'roms': roms(), 'interval_ms': interval,
            't_ms': t_ms, 't_ns': (t_ms + after) * 1_000_000, 'reason': reason, 'trigger': line,
            'log': str(Path(log).resolve()),
        }, indent=1) + '\n')
        print(f'  SNAP: {name} t={t_ms} ms {reason}: {d}')
    return 0


def main(argv):
    if len(argv) < 3 or argv[1] not in ('scan', 'defines'):
        sys.exit('usage: test_snap.py scan <test> <log> [--fail <detail>] [--script <sh>] | defines <test> [--script <sh>]')
    cmd, name, rest = argv[1], argv[2], argv[3:]
    script = DMEKLR / 'run_dashboard_tests.sh'
    fail = None
    log = None
    i = 0
    while i < len(rest):
        if rest[i] == '--script':
            script = Path(rest[i + 1]); i += 2
        elif rest[i] == '--fail':
            fail = rest[i + 1]; i += 2
        else:
            log = rest[i]; i += 1
    if cmd == 'defines':
        d = test_defines(name, script)
        if d is None:
            sys.exit(f'test_snap.py: no test "{name}" in {script}')
        print('\n'.join(d))
        return 0
    if not log:
        sys.exit('test_snap.py scan needs a log file')
    return scan(name, log, fail, script)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
