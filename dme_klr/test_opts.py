#!/usr/bin/env python3
"""
test_opts.py: the regression tests' options, as compile-time -D flags or as
run-time +plusargs for a testbench built once with RUNTIME_OPTS.

Every test in the runner scripts is a set of -D flags (run_test <name>
-DTEST_... -DRPMRAMP -DSIM_TIME=...). The testbench turns those into the
options it reads (test_opts.vh: the TEST_* blocks set RPMRAMP, SIM_TIME,
_COOLANT_RAW and so on), and each option is either a flag (`ifdef X) or a
value (`X). This script runs the same Verilog preprocessing over the same
file list as the compile, so it knows every option's final value for a
test, and from that writes:

  * the run-time options for a RUNTIME_OPTS build:
        +RPMRAMP=1 +SIM_TIME=5000000000 +_COOLANT_RAW=49 ...
    (every option, so the binary needs nothing from the test name), and
  * test_opts_gen.vh, the header that gives each option two forms:
        `OPT_X  a flag: 1'b1 / 1'b0 from `ifdef X in a normal build,
                test_opts::X in a RUNTIME_OPTS build
        `VAL_X  a value: `X in a normal build, test_opts::X in a
                RUNTIME_OPTS build (the test_opts package reads +X=<n>)

Usage:
  test_opts.py tests    [--script S]           the test names, one per line
  test_opts.py defines  <test> [--script S]    its -D flags, one per line
  test_opts.py plusargs <test> [--script S] [-D... extra]
                                               its +X=<n>, one per line, and
                                               "files: files|files_cl"
  test_opts.py resolve  -D... [-D...]          the same for a bare -D set
  test_opts.py gen      [--check]              (re)write test_opts_gen.vh;
                                               --check: fail if it is stale
  test_opts.py same     <git-rev> [--script S] check that every test's
                                               preprocessing (each `ifdef's
                                               result and each macro's value
                                               where it is used) is the same
                                               as in <git-rev>'s sources
  test_opts.py lint                            list option sites a RUNTIME_OPTS
                                               build would get wrong: an
                                               `ifdef of a flag, or a bare `X
                                               of a value, outside test_opts.vh

S defaults to v_run_dashboard_tests.sh (run_dashboard_tests.sh has the
same tests). Needs only the Python standard library.
"""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
GEN = os.path.join(REPO, 'dme', 'bench', 'verilog', 'test_opts_gen.vh')
SCRIPT = os.path.join(HERE, 'v_run_dashboard_tests.sh')
INCDIRS = ['rtl/verilog', 'bench/verilog', '../dme/rtl/verilog', '../dme/bench/verilog',
           '../klr/rtl/verilog', '../klr/bench/verilog']

# What every test build passes besides the test's own flags (v_run_dashboard_tests.sh)
FIXED = ['-DVLT_SIM', '-DDASHBOARD_TB', '-DDME_KLR_COMBINED', '-DDASH_INTERVAL_MS=100',
         '-DVERILATOR', '-DSTEP_CLOCKS=0']

# ── the options ──────────────────────────────────────────────
# Flags: tested with `ifdef. Values: used as `X. Everything a test sets,
# directly or through its TEST_* block, is one of these.
FLAGS = '''
AC_COMP_ON AFM_CL_RAMP AFM_FAULT AFM_FROM_ENGINE_MODEL AFM_SHORT_TO_GROUND AFM_TIPPY
AIRTEMP_OPEN_CIRCUIT BOOST BOOST_LOW BOOST_OPEN_CIRCUIT BOOST_STEP_DOWN BOOST_STEP_OVERBOOST
BOOST_ZERO BOOST_HIGH CL_AC_HALFWAY CL_CONDITION_CYCLE_ACTIVE CL_ISV_AIR CL_MODE CL_RPM_CRANK_RAMP
CL_THROTTLE_CLOSED COOLANT_OPEN_CIRCUIT DME_BATT_DISCONNECTED ISV_LOAD_DROOP
KLR_ADC0_NOISE_HIGH KLR_ADC0_NOISE_LOW KLR_BATT_DISCONNECTED KLR_BATT_LOW
KLR_FULL_LOAD_STUCK_HIGH KLR_FULL_LOAD_STUCK_LOW KLR_IGN_IN_STUCK_HIGH KLR_IGN_IN_STUCK_LOW
KLR_TPS_HIGH KLR_TPS_OPEN_CIRCUIT KLR_TPS_SHORT_TO_GROUND KLR_TPS_SUPPLY_LOST
KLR_TPS_SUPPLY_LOW KLR_TRIGGER_STUCK_HIGH KLR_TRIGGER_STUCK_LOW O2_FLAT_DISCONNECTED
O2_FLAT_LEAN O2_FLAT_RICH REF_SENSOR_ABSENT REF_SENSOR_STUCK_LOW RPMRAMP RPM_RAMP_DOWN
SKIP_LAMBDA_WARMUP SPEED_SENSOR_STUCK_LOW
TEST_AIRTEMP_FAIL TEST_CL_COLD_START TEST_CL_CONDITION_CYCLE_IDLE TEST_COLD_START
TEST_COOLANT_FAIL TEST_ISV_COLD_IDLE TEST_KNOCK_FAKE_BLOCKED TEST_KNOCK_PULSE
TEST_KNOCK_SHORT_TO_GROUND TEST_OVERRUN_CUTOFF TEST_REF_SENSOR_LOSS TEST_SPEED_SENSOR_LOSS
TEST_TIPPY_IN
'''.split()
VALUES = '''
AFM_CL_STEP_NS AFM_CL_TARGET BOOST_CUT_TAU_MS CL_FUEL_ENERGY_PCT CL_ISV_AIR_GAIN
CL_ISV_REF_PCT10 CL_ISV_WIN_NS CL_RPM_CRANK_RAMP_NS CL_RPM_CRANK_START CL_RPM_MAX
IGN_IN_LOSS_T_MS O2_DELAY_MS O2_STOICH_X1000 O2_TAU_MS OVERBOOST_END_PSI OVERBOOST_KLR_TPS
OVERBOOST_START_PSI OVERBOOST_STEP_NS OVERBOOST_STEP_RPM REF_LOSS_T_MS RPMEND RPMSTART
RPM_DOWN_END_MS RPM_DOWN_START_MS RPM_DOWN_TARGET RPM_RAMP_PCT SIM_TIME SPEED_LOSS_T_MS
TPS_FIXED TRIGGER_LOSS_T_MS _AIRTEMP_RAW _ALTITUDE _BATTERY _COOLANT_RAW _FUEL_QUAL
STEP_CLOCKS DASH_INTERVAL_MS
'''.split()
# The run-time paths (RUNTIME_OPTS: +NAME=<path>), with their defaults
# (i8051_top.v, klr_top.v, vcd.v, klr_vcd_combined.v)
PATHS = [('DMEKLR_REPO', None),
         ('DME_ROM_DIR', '{DMEKLR_REPO, "bin_images/dme/"}'),
         ('DME_ROM_FILE', '"89DME_951pin.mem"'),
         ('DME_ASM_DIR', '{DMEKLR_REPO, "dme/disassemble/"}'),
         ('KLR_ROM_DIR', '{DMEKLR_REPO, "bin_images/klr/"}'),
         ('KLR_ROM_FILE', '"89KLR_951.mem"'),
         ('KLR_ASM_DIR', '{DMEKLR_REPO, "klr/disassemble/"}')]
# Values a testbench also tests for presence: `OPT_X says whether X was
# given at all, `VAL_X is its value (0 if not)
PRESENT = ['TPS_FIXED']


# ── a Verilog preprocessor, as far as these sources need one ─────
DIRECTIVE = re.compile(r'^\s*`(define|undef|ifdef|ifndef|elsif|else|endif|include)\b\s*(.*)$')


def _code(s):
    i = s.find('//')
    return s if i < 0 else s[:i]


class Pre:
    """Runs `define/`undef/`ifdef/`ifndef/`elsif/`else/`endif/`include over
    a file list. record=True keeps, per active line, each `ifdef's result
    and each used macro's value, keyed by file name and the line's text."""

    def __init__(self, base, incdirs, record=False):
        self.base, self.incdirs, self.record = base, incdirs, record
        self.macros = {}
        self.events = []

    def find(self, name, here):
        for d in [os.path.dirname(here)] + [os.path.join(self.base, i) for i in self.incdirs]:
            p = os.path.normpath(os.path.join(d, name))
            if os.path.exists(p):
                return p
        return None

    def run_file(self, path):
        lines = open(path, encoding='utf8', errors='replace').read().split('\n')
        stack = []
        fname = os.path.basename(path)
        i = 0
        while i < len(lines):
            raw = lines[i]
            i += 1
            m = DIRECTIVE.match(raw)
            active = all(a for a, _ in stack)
            if not m:
                if active and self.record:
                    for nm in re.findall(r'`([A-Za-z_]\w*)', _code(raw)):
                        self.events.append((fname, raw.strip(), 'use', nm, self.macros.get(nm)))
                continue
            d, rest = m.group(1), _code(m.group(2)).rstrip()
            words = rest.split()
            if d in ('ifdef', 'ifndef'):
                name = words[0]
                cond = (name in self.macros) == (d == 'ifdef')
                if active and self.record:
                    self.events.append((fname, raw.strip(), d, name, name in self.macros))
                stack.append((cond and active, cond))
            elif d == 'elsif':
                _, taken = stack.pop()
                parent = all(a for a, _ in stack)
                cond = (not taken) and words[0] in self.macros
                if parent and not taken and self.record:
                    self.events.append((fname, raw.strip(), d, words[0], words[0] in self.macros))
                stack.append((cond and parent, taken or cond))
            elif d == 'else':
                _, taken = stack.pop()
                parent = all(a for a, _ in stack)
                stack.append(((not taken) and parent, True))
            elif d == 'endif':
                stack.pop()
            elif not active:
                continue
            elif d == 'define':
                body = rest
                while raw.rstrip().endswith('\\') and i < len(lines):
                    raw = lines[i]
                    i += 1
                    body = body.rstrip('\\') + ' ' + _code(raw).rstrip()
                name = re.match(r'[A-Za-z_]\w*', body).group(0)
                self.macros[name] = body[len(name):].strip().rstrip('\\').strip()
            elif d == 'undef':
                self.macros.pop(words[0], None)
            elif d == 'include':
                inc = re.match(r'"([^"]+)"', rest)
                p = inc and self.find(inc.group(1), path)
                if p:
                    self.run_file(p)
        return self.macros


def file_list(name):
    out = []
    for line in open(os.path.join(HERE, name)):
        line = line.strip()
        if line and not line.startswith(('//', '+', '-')):
            out.append(line)
    return out


def parse_defines(args):
    d = {}
    for a in args:
        if a.startswith('-D'):
            k, _, v = a[2:].partition('=')
            d[k] = v
    return d


def files_for(args):
    return 'files_cl' if '-DCL_MODE' in args else 'files'


def preprocess(args, record=False, base=HERE):
    p = Pre(base, INCDIRS, record)
    p.macros = parse_defines(FIXED + args)
    for f in file_list_at(base, files_for(args)):
        p.run_file(os.path.normpath(os.path.join(base, f)))
    return p


def file_list_at(base, name):
    out = []
    for line in open(os.path.join(base, name)):
        line = line.strip()
        if line and not line.startswith(('//', '+', '-')):
            out.append(line)
    return out


# ── Verilog numbers ──────────────────────────────────────────
def to_int(expr, macros, depth=0):
    """The integer a macro's text stands for: 8'hD8, 64'd30_000_000_000,
    (-6), `WARM_COOLANT_RAW, (60 * 1000 * `DME_FREQ / 132) ..."""
    if depth > 20:
        raise ValueError(f'macro loop in {expr}')
    s = re.sub(r'`([A-Za-z_]\w*)', lambda m: '(' + str(to_int(macros[m.group(1)], macros, depth + 1)) + ')', expr)

    def lit(m):
        base = m.group(2).lower()
        digits = m.group(3).replace('_', '')
        return str(int(digits, {'h': 16, 'd': 10, 'b': 2, 'o': 8}[base]))
    s = re.sub(r"(\d+)?'s?([hdbo])\s*([0-9a-fA-F_]+)", lit, s)
    s = re.sub(r'(?<=\d)_(?=\d)', '', s)
    if not re.fullmatch(r'[\d\s()+\-*/%]*', s):
        raise ValueError(f"can't evaluate {expr!r}")
    s = s.replace('/', '//')   # all positive in these sources
    return int(eval(s, {'__builtins__': {}}))


# ── tests ────────────────────────────────────────────────────
def test_names(script):
    text = open(script).read()
    body = re.search(r'^run_all\(\) \{(.*?)^\}', text, re.S | re.M).group(1)
    return re.findall(r'^\s*run_test\s+([A-Za-z0-9_]+)', body, re.M)


def test_defines(name, script):
    sys.path.insert(0, os.path.join(HERE, 'live'))
    from test_snap import test_defines as td
    return td(name, script)


def step_clocks(d):
    # as v_run_dashboard_tests.sh works it out for -DSTEP_CLOCKS
    sim = to_int(d.get('SIM_TIME', '40000000000'), d)
    pct = to_int(d.get('RPM_RAMP_PCT', '25'), d)
    return (sim // 1000000) * pct // 100 * 6000 // 200


def resolve(args, interval=100):
    """{option: int} for a test's -D flags: flags 0/1, values as numbers.
    A value the sources leave undefined for this test is left out."""
    d = parse_defines(args)
    args = [a for a in args if not a.startswith(('-DSTEP_CLOCKS', '-DDASH_INTERVAL_MS'))]
    args += [f'-DSTEP_CLOCKS={step_clocks(d)}', f'-DDASH_INTERVAL_MS={interval}']
    m = preprocess(args).macros
    out = {f: int(f in m) for f in FLAGS}
    for v in VALUES:
        if v in m:
            out[v] = to_int(m[v], m)
    return out


def plusargs(opts):
    return [f'+{k}={v}' for k, v in opts.items()]


# ── test_opts_gen.vh ─────────────────────────────────────────
def value_type(text):
    """A package variable's type for a value: the width its literal has"""
    t = text.strip().strip('()').strip()
    m = re.match(r"(\d+)'s?[hdbo]", t)
    if m:
        return f'logic [{int(m.group(1)) - 1}:0]'
    try:
        n = int(t.replace('_', ''))
    except ValueError:
        return 'longint'
    return 'integer' if -2**31 <= n < 2**31 else 'longint'


def gen_text():
    base = preprocess([]).macros          # a build with no test flags
    types = {}
    for name in test_names(SCRIPT):       # the widest literal any test gives
        m = preprocess(test_defines(name, SCRIPT)).macros
        for v in VALUES:
            if v in m and v not in ('STEP_CLOCKS', 'DASH_INTERVAL_MS'):
                t = value_type(m[v])
                if types.get(v) in (None, 'integer') or t == 'longint':
                    types[v] = t if types.get(v) != 'longint' else 'longint'
    types.update(STEP_CLOCKS='longint', DASH_INTERVAL_MS='integer')
    L = ['// Generated by dme_klr/test_opts.py gen: do not edit. See test_opts.vh.',
         '//',
         '// `OPT_X: flag X. `VAL_X: value X. A normal build reads them from',
         '// the -D flags (as `ifdef X / `X always did); a RUNTIME_OPTS build',
         '// from +X=<n> on the command line (test_opts.py plusargs <test>).',
         '`ifdef RUNTIME_OPTS',
         '`ifndef DMEKLR_REPO',
         '  `define DMEKLR_REPO ""',
         '`endif']
    for name, dflt in PATHS[1:]:      # a -D at compile time is the default
        L += [f'`ifndef {name}', f'  `define {name} {dflt}', '`endif']
    L += ['package test_opts;',
         '  function automatic longint arg(string name, longint dflt);',
         '    longint v;',
         '    if ($value$plusargs({name, "=%d"}, v)) return v;',
         '    return dflt;',
         '  endfunction',
         '  function automatic string sarg(string name, string dflt);',
         '    string v;',
         '    if ($value$plusargs({name, "=%s"}, v)) return v;',
         '    return dflt;',
         '  endfunction',
         '  // Paths: +DMEKLR_REPO=<dir/> +DME_ROM_DIR=<dir/> +DME_ROM_FILE=<name>',
         '  // +DME_ASM_DIR=<dir/> and the KLR_ ones, as the -D flags of the same',
         '  // names (paths.sh, asm_select.sh) set them in a normal build',
         ]
    for name, dflt in PATHS:
        L.append(f'  string {name} = sarg("{name}", `{name});')
    L.append('  // Flags')
    for f in FLAGS:
        L.append(f'  bit {f} = arg("{f}", {int(f in base)}) != 0;')
    for v in PRESENT:
        L.append(f'  bit {v}__GIVEN = $test$plusargs("{v}=");')
    L.append('  // Values (defaults: a build without test flags)')
    for v in VALUES:
        d = to_int(base[v], base) if v in base else 0
        t = types.get(v, 'longint')
        w = '' if t == 'longint' else '32' if t == 'integer' else str(int(re.search(r'\[(\d+)', t).group(1)) + 1)
        L.append(f'  {t} {v} = ' + (f'{w}\'(arg("{v}", {d}));' if w else f'arg("{v}", {d});'))
    L.append('endpackage')
    for f in FLAGS:
        L.append(f'`define OPT_{f} test_opts::{f}')
    for v in VALUES:
        L.append(f'`define VAL_{v} test_opts::{v}')
    for v in PRESENT:
        L.append(f'`define OPT_{v} test_opts::{v}__GIVEN')
    for name, _ in PATHS:
        L += [f'`undef {name}', f'`define {name} test_opts::{name}']
    L.append('`else')
    for f in FLAGS:
        L += [f'`ifdef {f}', f'  `define OPT_{f} 1\'b1', '`else', f'  `define OPT_{f} 1\'b0', '`endif']
    for v in VALUES:
        if v not in PRESENT:
            L.append(f'`define VAL_{v} `{v}')
    for v in PRESENT:
        L += [f'`ifdef {v}', f'  `define OPT_{v} 1\'b1', f'  `define VAL_{v} `{v}',
              '`else', f'  `define OPT_{v} 1\'b0', f'  `define VAL_{v} 0', '`endif']
    L.append('`endif')
    return '\n'.join(L) + '\n'


# ── same: compile-time equivalence with another revision ─────
def events(base, args):
    p = preprocess(args, record=True, base=base)
    # key by file + line text so moved lines still match
    out = {}
    for fname, text, kind, name, val in p.events:
        out.setdefault((fname, text, kind, name), set()).add(str(val))
    return out


# Differences that change nothing: the guard of a derived flag that
# test_opts.vh now defines first (`ifndef CL_ISV_AIR `define CL_ISV_AIR),
# and klr_tb.v's own crank generator, unused in the combined testbench
# (EXT_STIM=1 takes the trigger and ignition from the DME)
DERIVED = {'CL_ISV_AIR', 'CL_RPM_CRANK_RAMP', 'CL_THROTTLE_CLOSED', 'AFM_FROM_ENGINE_MODEL'}


def benign(k, old, new):
    fname, text, kind, name = k
    if kind == 'ifndef' and name in DERIVED and old == {'False'} and new == {'True'}:
        return True
    # a value's default, now given once where it was given in two places
    # (the second guard saw the first's define)
    if kind == 'ifndef' and name in VALUES and new < old:
        return True
    return fname == 'var_timing_gen.v'


def same(rev, script):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['git', '-C', REPO, 'worktree', 'add', '--detach', tmp, rev],
                       check=True, capture_output=True)
        try:
            bad = 0
            for name in test_names(script):
                args = test_defines(name, script)
                a = events(os.path.join(tmp, 'dme_klr'), args)
                b = events(HERE, args)
                diff = [(k, a[k], b[k]) for k in a.keys() & b.keys() if a[k] != b[k] and not benign(k, a[k], b[k])]
                if diff:
                    bad += 1
                    print(f'{name}: {len(diff)} differences')
                    for k, x, y in diff[:10]:
                        print(f'   {k[0]}: {k[1][:70]!r}  {k[3]}: {sorted(x)} -> {sorted(y)}')
            print(f'{bad} test(s) preprocess differently from {rev}' if bad else f'every test preprocesses as in {rev}')
            return 1 if bad else 0
        finally:
            subprocess.run(['git', '-C', REPO, 'worktree', 'remove', '--force', tmp], capture_output=True)


# Flags a RUNTIME_OPTS build fixes at compile time: they pick the file
# list (CL_MODE) or a module instance (RPMRAMP, set by every test). The
# runner checks a test's value against the binary's.
STRUCTURAL = {'CL_MODE': None, 'RPMRAMP': 1}
# test_opts.vh is where the options are worked out; var_timing_gen.v is
# klr_tb.v's own crank generator, unused in the combined testbench
# (EXT_STIM=1), whose localparams read the default build's values
LINT_SKIP = ('test_opts.vh', 'test_opts_gen.vh', 'var_timing_gen.v')
COMPILE_TIME = ('LIVE', 'LIVE_DEBUG')      # live builds keep their -D flags


def lint():
    files = []
    for fl in ('files', 'files_cl'):
        for f in file_list(fl):
            p = os.path.normpath(os.path.join(HERE, f))
            if p not in files:
                files.append(p)
    # the includes of test_opts.vh / i8051_dashboard_tb.v are the TEST_ blocks
    flags, values = set(FLAGS) - set(STRUCTURAL), set(VALUES)
    bad = 0
    for p in files:
        if os.path.basename(p) in LINT_SKIP:
            continue
        lines = open(p, encoding='utf8', errors='replace').read().split('\n')
        live = []          # per open `if: inside a LIVE-only branch?
        for i, raw in enumerate(lines):
            code = _code(raw)
            d = re.match(r'\s*`(ifdef|ifndef|elsif|else|endif)\b\s*(\w*)', code)
            if d:
                k, name = d.groups()
                if k == 'ifdef':
                    live.append(name in COMPILE_TIME)
                elif k == 'ifndef':
                    live.append(False)
                elif k in ('elsif', 'else') and live:
                    live[-1] = False
                elif k == 'endif' and live:
                    live.pop()
            if any(live):
                continue
            m = re.match(r'\s*`(ifdef|ifndef|elsif)\s+(\w+)', code)
            if m:
                name = m.group(2)
                j = i + 1                  # the next line that isn't a comment
                while j < len(lines) and not _code(lines[j]).strip():
                    j += 1
                nxt = _code(lines[j]) if j < len(lines) else ''
                default = (m.group(1) == 'ifndef' and name in values
                           and re.match(r'\s*`define\s+' + name + r'\b', nxt))
                if (name in flags or name in values) and not default:
                    print(f'{os.path.relpath(p, REPO)}:{i + 1}: `{m.group(1)} {name}')
                    bad += 1
                continue
            if re.match(r'\s*`define\b', code):
                continue
            for name in re.findall(r'`(\w+)', code):
                if name in values:
                    print(f'{os.path.relpath(p, REPO)}:{i + 1}: `{name}')
                    bad += 1
    print(f'{bad} site(s)', file=sys.stderr)
    return 1 if bad else 0


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        print(__doc__.strip())
        return 0
    script = SCRIPT
    if '--script' in argv:
        i = argv.index('--script')
        script = argv[i + 1]
        del argv[i:i + 2]
    cmd, rest = argv[0], argv[1:]
    if cmd == 'tests':
        print('\n'.join(test_names(script)))
    elif cmd == 'defines':
        print('\n'.join(test_defines(rest[0], script) or []))
    elif cmd in ('plusargs', 'resolve'):
        if cmd == 'plusargs':
            args = test_defines(rest[0], script)
            if args is None:
                print(f'test_opts.py: no test {rest[0]} in {script}', file=sys.stderr)
                return 1
            args += [a for a in rest[1:] if a.startswith('-D')]
        else:
            args = rest
        print('\n'.join(plusargs(resolve(args))))
        print(f'files: {files_for(args)}')
    elif cmd == 'gen':
        text = gen_text()
        if '--check' in rest:
            old = open(GEN).read() if os.path.exists(GEN) else ''
            if old != text:
                print(f'{GEN} is stale: run dme_klr/test_opts.py gen', file=sys.stderr)
                return 1
            return 0
        with open(GEN, 'w', newline='\n') as f:
            f.write(text)
        print(f'wrote {GEN}')
    elif cmd == 'lint':
        return lint()
    elif cmd == 'same':
        return same(rest[0], script)
    else:
        print(f'test_opts.py: unknown command {cmd}', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
