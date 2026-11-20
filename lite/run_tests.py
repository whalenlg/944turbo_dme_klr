#!/usr/bin/env python3
"""
run_tests.py: the regression tests, in the lite package

Runs the dashboard regression tests on the package's two prebuilt
simulators (dme_klr/runtime/dme_klr_sim and dme_klr_sim_cl: the testbench
built once with every test option read at run time), checks each run with
validate_dash_log.py and prints PASS / WARN / FAIL, as the developer
install's run_dashboard_parallel.sh --verilator does. No Verilator,
compiler or Verilog needed.

Usage:
    python3 run_tests.py [options] [test or pattern ...]

    test or pattern   test names, or shell patterns (cl_ramp_*); default all
    -j N              tests at a time (default: the number of CPUs, at most 8)
    --interval MS     snapshot interval in simulated ms (default 100, or
                      $DASH_INTERVAL_MS)
    --sim-ms N        stop every test at N simulated ms (a quick check; the
                      validator's verdicts assume the full length)
    --list            list the tests with their simulated length and exit

Regression hosts: other machines running this package's bridge (or a
developer install of the same software) with --listen and --token can take
some of the tests. $DMEKLR_REGRESS_HOSTS names a JSON file
[{"name", "url", "token", "threads"}] (the dashboard's RUN REGRESSIONS
panel writes it); each host's threads run tests through
dme_klr/live/remote_test.mjs (Node), which brings their logs back here to
be checked like the rest. A host that drops gets no more tests, and its
test goes back in the queue.

The ROM images are the defaults (89DME_951pin.mem, 89KLR_951.mem) unless
DME_ROM_FILE / KLR_ROM_FILE (and DME_ROM_DIR / KLR_ROM_DIR) are set, as for
the developer install's runners.

Output, in $DMEKLR_TMP/dme_klr/<rom>/v_dash_logs (default <package>/data/...,
as run_lite.sh uses; <rom> is the ROM pair's folder: 89 for the default
pair, 86 for run86.sh's, carpokes for run_carpokes.sh's, otherwise
the DME image's name): <test>.log (the whole run), <test>.dash.log (open
it in the dashboard), validation.log and parallel_summary.log. A WARN or
FAIL verdict, and each kind of warning a run prints (a PASS too), leave a
TEST row in the live page's SNAPSHOTS list (LOAD runs the test to that
moment in the debugger).
"""
import fnmatch, json, os, re, subprocess, sys, threading, time

if any(a in ('-h', '--help') for a in sys.argv[1:]):
    print(__doc__.strip())
    sys.exit(0)

PKG = os.path.dirname(os.path.abspath(__file__))
DMEKLR = os.path.join(PKG, 'dme_klr')
LIVE = os.path.join(DMEKLR, 'live')
EXE = '.exe' if os.name == 'nt' else ''
TMP = os.environ.get('DMEKLR_TMP') or os.path.join(PKG, 'data')
os.environ['DMEKLR_TMP'] = TMP
# The ROM pair's log folder, named as paths.sh / dmeklr_paths.py / live/logdirs.mjs do
_NAMED = {('89DME_951pin', '89KLR_951'): '89', ('28PIN_86DME', '86KLR_951'): '86',
          ('28PIN_DME_PERFORMANCE', '87KLR_951'): 'carpokes'}
_stem = lambda f: os.path.splitext(os.path.basename(f.replace('\\', '/')))[0]
_d = _stem(os.environ.get('DME_ROM_FILE') or '89DME_951pin.mem')
_k = _stem(os.environ.get('KLR_ROM_FILE') or '89KLR_951.mem')
ROM_VARIANT = _NAMED.get((_d, _k)) or re.sub(r'[^A-Za-z0-9_.+-]', '_', _d)
LOGDIR = os.path.join(TMP, 'dme_klr', ROM_VARIANT, 'v_dash_logs')
HEXDIR = os.path.join(TMP, 'dme_klr', 'lite_hex')
# The lines the dashboard reads (as v_run_dashboard_tests.sh greps them)
DASH = re.compile(r'^(DME: \[DS\]|\[DS\]|KLR: \[DS\]|DME: \[PHASE\]|DME: \[STATUS\]|KLR: \[STATUS\]|KLR: \[PHASE\]'
                  r'|KLR: \[SPARK\]|DME: \[SEED\]|DME: \[WARN\]|DME: \[LKUP\]|KLR: \[LKUP\]|DME: \[SER\]|DME: \[SERPEEK\]|DME: \[SERWR\])')
fwd = lambda p: p.replace('\\', '/')
_out = threading.Lock()


def say(line):
    """One whole line to stdout: print() from several threads can write
    one's text before another's newline, and the panel reads lines"""
    with _out:
        sys.stdout.write(line + '\n')
        sys.stdout.flush()


def args_of(argv):
    o = {'jobs': min(os.cpu_count() or 2, 8), 'interval': int(os.environ.get('DASH_INTERVAL_MS', '100')),
         'sim_ms': None, 'list': False, 'tests': []}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '-j':
            o['jobs'] = max(1, int(argv[i + 1])); i += 2
        elif a.startswith('-j') and a[2:].isdigit():
            o['jobs'] = max(1, int(a[2:])); i += 1
        elif a == '--interval':
            o['interval'] = int(argv[i + 1]); i += 2
        elif a == '--sim-ms':
            o['sim_ms'] = int(argv[i + 1]); i += 2
        elif a == '--list':
            o['list'] = True; i += 1
        elif a.startswith('-'):
            sys.exit(f'run_tests.py: unknown option {a} (see --help)')
        else:
            o['tests'].append(a); i += 1
    return o


def rom(cpu):
    CPU = cpu.upper()
    d = os.environ.get(f'{CPU}_ROM_DIR') or os.path.join(PKG, 'bin_images', cpu) + '/'
    f = os.environ.get(f'{CPU}_ROM_FILE') or ('89DME_951pin.mem' if cpu == 'dme' else '89KLR_951.mem')
    if not d.endswith(('/', '\\')):
        d += '/'
    return fwd(d), f


def path_args():
    """+DMEKLR_REPO and the ROM / disassembly-table paths"""
    try:
        tables = json.load(open(os.path.join(LIVE, 'asm_tables.json')))
    except (OSError, ValueError):
        tables = {}
    out = [f'+DMEKLR_REPO={fwd(PKG)}/']
    for cpu in ('dme', 'klr'):
        CPU = cpu.upper()
        d, f = rom(cpu)
        if not os.path.exists(d + f):
            sys.exit(f'run_tests.py: no {CPU} image {d + f}')
        out += [f'+{CPU}_ROM_DIR={d}', f'+{CPU}_ROM_FILE={f}']
        # the tables made for this image; an image without its own gets the
        # default image's (labels may not line up with its code)
        dflt = '89DME_951pin.mem' if cpu == 'dme' else '89KLR_951.mem'
        sub = tables.get(cpu, {}).get(f) or tables.get(cpu, {}).get(dflt)
        if sub:
            out.append(f'+{CPU}_ASM_DIR={fwd(os.path.join(PKG, cpu, "disassemble", sub))}/')
    return out


def step_clocks(sim_ns, pct):
    return (sim_ns // 1000000) * pct // 100 * 6000 // 200


TEMPFAIL = 75   # remote_test.mjs: the host couldn't take the test
GIVEBACK = 76   # remote_test.mjs: it ran there, but its logs didn't come back


def run_remote(name, o, host):
    """The test on a regression host: its log and dash.log end up in
    LOGDIR as if it ran here. None when the host dropped out."""
    log = os.path.join(LOGDIR, f'{name}.log')
    say(f'  [START] {name}  @{host["name"]}')
    t0 = time.time()
    cmd = ['node', os.path.join(LIVE, 'remote_test.mjs'), '--host', host['url'], '--test', name,
           '--out', LOGDIR, '--interval', str(o['interval']), '--log', 'raw']
    if o['sim_ms']:
        cmd += ['--sim-ms', str(o['sim_ms'])]
    with open(os.path.join(LOGDIR, f'{name}.remote.log'), 'w') as rf:
        rc = subprocess.call(cmd, stdout=rf, stderr=subprocess.STDOUT,
                             env={**os.environ, 'DMEKLR_REGRESS_TOKEN': host['token']})
    secs = time.time() - t0
    if rc == TEMPFAIL:
        return None
    if rc == GIVEBACK:
        return 'giveback'
    # (its exit is 1 when it ran but the host's run_tests.py judged it FAIL:
    # the verdict is made here, from the logs it brought back)
    if not os.path.exists(os.path.join(LOGDIR, f'{name}.dash.log')):
        return name, 'FAIL', f'failed on {host["name"]} (see {name}.remote.log)', secs
    return check(name, log, os.path.join(LOGDIR, f'{name}.dash.log'), o, secs)


def check(name, log, dash, o, secs):
    """Validate a run's dash.log and leave its TEST rows"""
    r = subprocess.run([sys.executable, os.path.join(DMEKLR, 'validate_dash_log.py'), name, dash, rom('dme')[1]],
                       capture_output=True, text=True, encoding='utf-8', errors='replace',
                       env={**os.environ, 'PYTHONIOENCODING': 'utf-8'})
    parts = (r.stdout.strip().splitlines() or ['FAIL\t\tno verdict: ' + r.stderr.strip()[-200:]])[-1].split('\t')
    verdict = parts[0] if parts[0] in ('PASS', 'WARN', 'FAIL') else 'FAIL'
    detail = parts[2] if len(parts) > 2 else ' '.join(parts[1:])
    test_rows(name, log, verdict, detail, o['interval'])
    return name, verdict, detail, secs


def run_one(name, t, o, paths):
    plus = list(t['plusargs'])
    if o['sim_ms']:
        pct = next((int(p.split('=', 1)[1]) for p in plus if p.startswith('+RPM_RAMP_PCT=')), 25)
        sim_ns = o['sim_ms'] * 1000000
        plus = [p for p in plus if not p.startswith(('+SIM_TIME=', '+STEP_CLOCKS='))]
        plus += [f'+SIM_TIME={sim_ns}', f'+STEP_CLOCKS={step_clocks(sim_ns, pct)}']
    exe = os.path.join(DMEKLR, 'runtime', ('dme_klr_sim_cl' if t['files'] == 'files_cl' else 'dme_klr_sim') + EXE)
    hexd = os.path.join(HEXDIR, name)
    os.makedirs(hexd, exist_ok=True)
    log = os.path.join(LOGDIR, f'{name}.log')
    dash = os.path.join(LOGDIR, f'{name}.dash.log')
    for f in (log, dash):
        if os.path.exists(f):
            os.remove(f)
    # (the dashboard's RUN REGRESSIONS panel marks the test running from this line)
    say(f'  [START] {name}')
    t0 = time.time()
    with open(log, 'w') as lf:
        rc = subprocess.call([exe, f'+vcd={os.devnull}', *plus, f'+DASH_INTERVAL_MS={o["interval"]}', *paths],
                             cwd=hexd, stdout=lf, stderr=subprocess.STDOUT)
    secs = time.time() - t0
    if rc != 0:
        return name, 'FAIL', f'simulator exited {rc} (see {log})', secs
    # Which ROM images the run used, first, for the dashboard; then its lines
    stamp = subprocess.run([sys.executable, os.path.join(DMEKLR, 'rom_stamp.py'), log],
                           capture_output=True, text=True).stdout
    with open(log, errors='replace') as lf, open(dash, 'w') as df:
        df.write(stamp)
        for line in lf:
            if DASH.match(line):
                df.write(line)
    return check(name, log, dash, o, secs)


def test_rows(name, log, verdict, detail, interval):
    """TEST rows for the live page's SNAPSHOTS list (test_snap.py reads
    tests.json here), as the developer runners make them: one at each kind
    of warning the run printed (v_run_dashboard_tests.sh's plain scan, run
    for every test, a PASS too), then, for a WARN or FAIL verdict, one at
    the time the validator names (run_dashboard_parallel.sh). The verdict
    scan alone adds nothing when the run printed a warning and the verdict
    names no time: it leaves that to the plain scan."""
    snap = [sys.executable, os.path.join(LIVE, 'test_snap.py'), 'scan', name, log]
    script = ['--script', os.path.join(DMEKLR, 'no-runner-script')]
    env = {**os.environ, 'DASH_INTERVAL_MS': str(interval)}
    subprocess.run(snap + script, capture_output=True, env=env)
    if verdict in ('WARN', 'FAIL'):
        subprocess.run(snap + [f'--{verdict.lower()}', detail] + script, capture_output=True, env=env)


def read_control(limit, hosts, queue, cancelled):
    """RUN CONTROL: the RUN REGRESSIONS panel (live/runall.mjs) changes the
    run as it goes through $DMEKLR_RUN_CONTROL, a folder (as
    run_dashboard_parallel.sh reads it):
      threads  "local <n>" (tests at a time here, 1 or more) and
               "host <name> <n>" (a regression host's threads, 0: no more
               tests there) lines; a test already running ends as it would
      cancel   "<sim> <rom> <test>" lines, shell patterns (* for any); sim
               vl here, rom the ROM pair's folder (ROM_VARIANT): a queued
               test that matches never starts ("[CANCEL] <test>")"""
    d = os.environ.get('DMEKLR_RUN_CONTROL')
    if not d or not os.path.isdir(d):
        return
    try:
        with open(os.path.join(d, 'threads'), encoding='utf-8') as f:
            for line in f:
                w = line.split()
                if len(w) == 2 and w[0] == 'local' and w[1].isdigit() and int(w[1]) >= 1:
                    limit[None] = int(w[1])
                elif len(w) == 3 and w[0] == 'host' and w[1] in hosts and w[2].isdigit():
                    limit[w[1]] = int(w[2])
    except OSError:
        pass
    try:
        with open(os.path.join(d, 'cancel'), encoding='utf-8') as f:
            pats = [w for w in (line.split() for line in f) if len(w) == 3]
    except OSError:
        pats = []
    if not pats or not queue:
        return
    keep = []
    for n in queue:
        if any(fnmatch.fnmatchcase('vl', s) and fnmatch.fnmatchcase(ROM_VARIANT, r) and fnmatch.fnmatchcase(n, t)
               for s, r, t in pats):
            cancelled.append(n)
            # (the RUN REGRESSIONS panel marks the test cancelled from this line)
            say(f'  [CANCEL] {n}')
        else:
            keep.append(n)
    queue[:] = keep


def main():
    # the verdicts have ✓ and the like, which a Windows console or pipe's
    # code page may not have
    for st in (sys.stdout, sys.stderr):
        try:
            st.reconfigure(errors='replace')
        except (AttributeError, ValueError):
            pass
    o = args_of(sys.argv[1:])
    try:
        tests = json.load(open(os.path.join(LIVE, 'tests.json')))['tests']
    except (OSError, ValueError, KeyError) as e:
        sys.exit(f'run_tests.py: no test list ({e}); this needs a lite package with the regression tests')
    names = list(tests)
    if o['tests']:
        pick = [n for p in o['tests'] for n in names if fnmatch.fnmatchcase(n, p)]
        missing = [p for p in o['tests'] if not any(fnmatch.fnmatchcase(n, p) for n in names)]
        if missing:
            sys.exit(f'run_tests.py: no test {", ".join(missing)} (--list shows them)')
        names = list(dict.fromkeys(pick))
    # longest first, so the run ends as soon as it can
    names.sort(key=lambda n: -(tests[n].get('sim_ns') or 0))
    if o['list']:
        for n in names:
            print(f'{n:44s} {(tests[n].get("sim_ns") or 0) / 1e9:6.1f} s  {tests[n]["files"]}')
        return 0
    for f in ('dme_klr_sim', 'dme_klr_sim_cl'):
        if not os.path.exists(os.path.join(DMEKLR, 'runtime', f + EXE)):
            sys.exit(f'run_tests.py: no dme_klr/runtime/{f}{EXE} in this package')
    os.makedirs(LOGDIR, exist_ok=True)
    paths = path_args()
    print(f'{len(names)} test(s), {o["jobs"]} at a time; DME {rom("dme")[1]}, KLR {rom("klr")[1]}; logs in {LOGDIR}')
    col = {'PASS': '\033[32m', 'WARN': '\033[33m', 'FAIL': '\033[31m'} if sys.stdout.isatty() else {}
    reset = '\033[0m' if col else ''
    res, t0 = [], time.time()
    hosts = []
    if os.environ.get('DMEKLR_REGRESS_HOSTS'):
        try:
            hosts = json.load(open(os.environ['DMEKLR_REGRESS_HOSTS']))
        except (OSError, ValueError) as e:
            print(f'run_tests.py: regression hosts not used ({e})')
    for h in hosts:
        print(f'Regression host: {h["name"]}, {h["threads"]} thread(s)')
    # A dispatcher starts each test on a thread of its own when a slot is
    # free: -j here, each host's threads there (RUN CONTROL can change them
    # as the run goes: read_control); a test whose host drops goes back on
    # the queue, and that host gets no more tests
    queue, lock, off = list(names), threading.Lock(), set()
    limit = {None: o['jobs'], **{h['name']: int(h['threads']) for h in hosts}}
    running = {k: 0 for k in limit}
    cancelled = []
    gave = {}   # host → tests whose logs didn't come back
    by_name = {h['name']: h for h in hosts}

    def job(n, host):
        try:
            r = run_remote(n, o, host) if host else run_one(n, tests[n], o, paths)
        except Exception as e:   # one test's crash mustn't hang the run
            r = (n, 'FAIL', f'runner error: {e}', 0)
        with lock:
            running[host['name'] if host else None] -= 1
            if r is None:
                off.add(host['name'])
                queue.insert(0, n)
                say(f'  [REQUEUE] {n}  {host["name"]} dropped out (see {n}.remote.log)')
                return
            if r == 'giveback':
                # its logs didn't come back: run it again; the host keeps
                # getting tests until this happens 3 times
                gave[host['name']] = gave.get(host['name'], 0) + 1
                if gave[host['name']] >= 3:
                    off.add(host['name'])
                queue.insert(0, n)
                say(f'  [REQUEUE] {n}  {host["name"]} ran it but its logs didn\'t come back '
                    f'({gave[host["name"]]} of 3; see {n}.remote.log)')
                return
            name, v, detail, secs = r
            res.append((name, v, detail))
            say(f'  [{col.get(v, "")}{v}{reset}] {name:40s} {secs:6.0f} s  '
                f'{detail}   ({len(res)}/{len(names) - len(cancelled)})')

    while True:
        with lock:
            read_control(limit, by_name, queue, cancelled)
            if not queue and not any(running.values()):
                break
            for key in [None, *by_name]:
                while queue and running[key] < limit[key] and key not in off:
                    n = queue.pop(0)
                    running[key] += 1
                    threading.Thread(target=job, args=(n, by_name.get(key)), daemon=True).start()
        time.sleep(0.5)
    n = {v: sum(r[1] == v for r in res) for v in ('PASS', 'WARN', 'FAIL')}
    wall = time.time() - t0
    with open(os.path.join(LOGDIR, 'validation.log'), 'w', encoding='utf-8') as f:
        for name, v, detail in res:
            f.write(f'{v}\t{name:22s}\t{detail}\n')
    with open(os.path.join(LOGDIR, 'parallel_summary.log'), 'w', encoding='utf-8') as f:
        f.write(f'89 DME 951 Parallel Test Run (lite) — {time.strftime("%Y-%m-%d %H:%M:%S")}\n')
        f.write(f'Wall time: {int(wall) // 60}m{int(wall) % 60}s   Total: {len(res)}   PASS: {n["PASS"]}   WARN: {n["WARN"]}   FAIL: {n["FAIL"]}'
                + (f'   CANCELLED: {len(cancelled)}' if cancelled else '') + '\n')
        if cancelled:
            f.write(f'Cancelled (never started): {" ".join(cancelled)}\n')
        f.write('\n')
        for name, v, detail in sorted(res, key=lambda r: ('FAIL', 'WARN', 'PASS').index(r[1])):
            f.write(f'  {v:6s} {name:22s} {detail}\n')
    print(f'Total: {len(res)}   PASS: {n["PASS"]}   WARN: {n["WARN"]}   FAIL: {n["FAIL"]}'
          + (f'   CANCELLED: {len(cancelled)}' if cancelled else '') + f'   ({int(wall) // 60}m{int(wall) % 60}s)')
    return 1 if n['FAIL'] else 0


if __name__ == '__main__':
    sys.exit(main())
