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

The ROM images are the defaults (89DME_951pin.mem, 89KLR_951.mem) unless
DME_ROM_FILE / KLR_ROM_FILE (and DME_ROM_DIR / KLR_ROM_DIR) are set, as for
the developer install's runners.

Output, in $DMEKLR_TMP/dme_klr/v_dash_logs (default <package>/data/...,
as run_lite.sh uses): <test>.log (the whole run), <test>.dash.log (open
it in the dashboard), validation.log and parallel_summary.log. A WARN or
FAIL also leaves a TEST row in the live page's SNAPSHOTS list (LOAD runs
the test to that moment in the debugger).
"""
import fnmatch, json, os, re, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor, as_completed

if any(a in ('-h', '--help') for a in sys.argv[1:]):
    print(__doc__.strip())
    sys.exit(0)

PKG = os.path.dirname(os.path.abspath(__file__))
DMEKLR = os.path.join(PKG, 'dme_klr')
LIVE = os.path.join(DMEKLR, 'live')
EXE = '.exe' if os.name == 'nt' else ''
TMP = os.environ.get('DMEKLR_TMP') or os.path.join(PKG, 'data')
os.environ['DMEKLR_TMP'] = TMP
LOGDIR = os.path.join(TMP, 'dme_klr', 'v_dash_logs')
HEXDIR = os.path.join(TMP, 'dme_klr', 'lite_hex')
# The lines the dashboard reads (as v_run_dashboard_tests.sh greps them)
DASH = re.compile(r'^(DME: \[DS\]|\[DS\]|KLR: \[DS\]|DME: \[PHASE\]|DME: \[STATUS\]|KLR: \[STATUS\]|KLR: \[PHASE\]'
                  r'|KLR: \[SPARK\]|DME: \[SEED\]|DME: \[WARN\]|DME: \[LKUP\]|KLR: \[LKUP\])')
fwd = lambda p: p.replace('\\', '/')


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
    r = subprocess.run([sys.executable, os.path.join(DMEKLR, 'validate_dash_log.py'), name, dash, rom('dme')[1]],
                       capture_output=True, text=True)
    parts = (r.stdout.strip().splitlines() or ['FAIL\t\tno verdict: ' + r.stderr.strip()[-200:]])[-1].split('\t')
    verdict = parts[0] if parts[0] in ('PASS', 'WARN', 'FAIL') else 'FAIL'
    detail = parts[2] if len(parts) > 2 else ' '.join(parts[1:])
    if verdict in ('WARN', 'FAIL'):
        # a TEST row for the live page (test_snap.py reads tests.json here)
        subprocess.run([sys.executable, os.path.join(LIVE, 'test_snap.py'), 'scan', name, log,
                        f'--{verdict.lower()}', detail, '--script', os.path.join(DMEKLR, 'no-runner-script')],
                       capture_output=True, env={**os.environ, 'DASH_INTERVAL_MS': str(o['interval'])})
    return name, verdict, detail, secs


def main():
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
    with ThreadPoolExecutor(o['jobs']) as ex:
        futs = [ex.submit(run_one, n, tests[n], o, paths) for n in names]
        for k, f in enumerate(as_completed(futs), 1):
            name, v, detail, secs = f.result()
            res.append((name, v, detail))
            print(f'  [{col.get(v, "")}{v}{reset}] {name:40s} {secs:6.0f} s  {detail}   ({k}/{len(names)})', flush=True)
    n = {v: sum(r[1] == v for r in res) for v in ('PASS', 'WARN', 'FAIL')}
    wall = time.time() - t0
    with open(os.path.join(LOGDIR, 'validation.log'), 'w') as f:
        for name, v, detail in res:
            f.write(f'{v}\t{name:22s}\t{detail}\n')
    with open(os.path.join(LOGDIR, 'parallel_summary.log'), 'w') as f:
        f.write(f'89 DME 951 Parallel Test Run (lite) — {time.strftime("%Y-%m-%d %H:%M:%S")}\n')
        f.write(f'Wall time: {int(wall) // 60}m{int(wall) % 60}s   Total: {len(res)}   PASS: {n["PASS"]}   WARN: {n["WARN"]}   FAIL: {n["FAIL"]}\n\n')
        for name, v, detail in sorted(res, key=lambda r: ('FAIL', 'WARN', 'PASS').index(r[1])):
            f.write(f'  {v:6s} {name:22s} {detail}\n')
    print(f'Total: {len(res)}   PASS: {n["PASS"]}   WARN: {n["WARN"]}   FAIL: {n["FAIL"]}   ({int(wall) // 60}m{int(wall) % 60}s)')
    return 1 if n['FAIL'] else 0


if __name__ == '__main__':
    sys.exit(main())
