// ============================================================
//  runall.mjs — the dashboard's RUN REGRESSIONS panel, on the bridge
//
//  Runs the regression suite for the page and reports its progress:
//    developer install  dme_klr/run_all.sh (both CPU regressions, the
//                       Verilator and iverilog dashboard suites, the
//                       comparison, the macOS VM test)
//    lite package       run_tests.py (the dashboard tests on the
//                       package's prebuilt Verilator simulators; there
//                       is no iverilog in the package)
//
//    GET  /runall         {mode, platform, tart, cpus, groups, manual, roms, run}
//                         groups: the tests in the manuals' Appendix A
//                         groups (test_groups.json), each with its
//                         simulated length and the anchor of its section
//                         in manual; run: the current or last run
//    POST /runall/start   JSON body: {sims: ['verilator','iverilog'],
//                         workers, perTestBuild, macosTest, pull,
//                         interval_ms, sim_ms (lite), tests: [names]
//                         (none or every test = the whole suite),
//                         roms: {dme: <file.mem>, klr: <file.mem>}}
//                         roms: the images every test runs on, as
//                         DME_ROM_DIR / DME_ROM_FILE and the KLR_ ones
//                         (run86.sh, run_carpokes.sh); default the 1989
//                         ones. GET /runall lists them (bin_images/<cpu>
//                         and the uploaded ones) and the named pairs
//    POST /runall/stop    stop the run and every test it started
//
//  Progress is simulated time: a running test's share is the newest
//  "t=<ms> ms" or "[DS] <ms>," in its log against the test's length,
//  a finished test counts whole. The suites print "[START] <test>" as
//  each test starts and "[PASS|WARN|FAIL] <test>" as it is checked.
//  Only one run at a time; it ends if the bridge stops.
//
//  Regression hosts: other machines running this bridge with --listen
//  and --token (regress_host.mjs) share the dashboard tests. The list is
//  kept in $DMEKLR_TMP/dme_klr/regress_hosts.json:
//    GET    /runall/hosts[?probe=1]  {local, hosts: [{id, host, port,
//                                     threads, enabled, token: bool,
//                                     status: {ok, why, info}}]}
//    POST   /runall/hosts            JSON {host, port, threads, token,
//                                     enabled}: add, or change (same
//                                     host:port; a blank token keeps it)
//    DELETE /runall/hosts?id=<host:port>
//  A run uses the enabled hosts whose software is the same as here
//  (srchash) and that answer; the runners get them as
//  $DMEKLR_REGRESS_HOSTS (a JSON file) and run their tests through
//  remote_test.mjs, putting a test back in the queue if its host drops.
// ============================================================

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync, openSync, readSync, fstatSync, closeSync } from 'node:fs';
import { cpus } from 'node:os';
import { dirname, join } from 'node:path';
import { softwareVersion } from './regress_host.mjs';
import { createInterface } from 'node:readline';

const ANSI = /\x1b\[[0-9;]*[A-Za-z]/g;
const NAME = /^[A-Za-z0-9_]+$/;
const MAX_OUT = 400;           // output lines kept for the panel
const POLL_MS = 2000;          // read the running tests' logs this often
const TAIL_BYTES = 64 * 1024;  // of each log, from the end
const RANK = { PASS: 0, SKIP: 0, WARN: 1, FAIL: 2 };

const readJson = f => { try { return JSON.parse(readFileSync(f, 'utf8')); } catch { return null; } };

// Newest simulated time in a log, in ms (DS lines start with it, the
// PHASE / STATUS lines carry t=<ms> ms), from its last TAIL_BYTES
function logTimeMs(file) {
  let fd;
  try {
    fd = openSync(file, 'r');
    const size = fstatSync(fd).size;
    const len = Math.min(size, TAIL_BYTES);
    const buf = Buffer.alloc(len);
    readSync(fd, buf, 0, len, size - len);
    let best = 0;
    for (const m of buf.toString('latin1').matchAll(/\[DS\] (\d+),|\bt=(\d+) ms/g)) best = Math.max(best, +(m[1] ?? m[2]));
    return best;
  } catch { return 0; } finally { if (fd !== undefined) closeSync(fd); }
}

// The ROM image pairs the developer scripts name (run89.sh, run86.sh,
// run_carpokes.sh); listed when both images are here
const ROM_PRESETS = [
  { name: '1989 (stock)', dme: '89DME_951pin.mem', klr: '89KLR_951.mem' },
  { name: '1986 (run86.sh)', dme: '28PIN_86DME.mem', klr: '86KLR_951.mem' },
  { name: 'CarPokes performance (run_carpokes.sh)', dme: '28PIN_DME_PERFORMANCE.mem', klr: '87KLR_951.mem' },
];
const DEFAULT_ROM = { dme: '89DME_951pin.mem', klr: '89KLR_951.mem' };

// romImages(cpu): [{name, dir, src: 'repo'|'upload'}], the whole .mem
// images the bridge knows for that CPU
export function makeRunAll({ REPO, HERE, TMP_ROOT, PY, romImages = () => [] }) {
  const DMEKLR = join(REPO, 'dme_klr');
  const RUN_ALL = join(DMEKLR, 'run_all.sh');
  const RUN_TESTS = join(REPO, 'run_tests.py');
  const MODE = existsSync(RUN_ALL) ? 'dev' : existsSync(RUN_TESTS) ? 'lite' : null;
  const tart = process.platform === 'darwin' && spawnSync('sh', ['-c', 'command -v tart'], { encoding: 'utf8' }).status === 0;

  // ── The tests, their lengths and the manuals' groups ─────────
  let catalog = null;
  function getCatalog() {
    if (catalog) return catalog;
    const len = {};        // test → simulated seconds
    let all = [];
    if (MODE === 'dev') {
      // As run_dashboard_parallel.sh orders them: SIM_TIME of each case
      // entry, or --end-s minus --start-s for a replay; 40 s by default
      const script = readFileSync(join(DMEKLR, 'v_run_dashboard_tests.sh'), 'utf8');
      for (const line of script.split('\n')) {
        const m = line.match(/^\s+([A-Za-z0-9_]+)\)\s+run_(?:replay_)?test /);
        if (!m) continue;
        let s = 40;
        const st = line.match(/-DSIM_TIME=(\d+)/);
        if (st) s = +st[1] / 1e9;
        const end = line.match(/--end-s ([0-9.]+)/);
        if (end) s = +end[1] - +(line.match(/--start-s ([0-9.]+)/)?.[1] ?? 0);
        len[m[1]] = s;
      }
      const par = readFileSync(join(DMEKLR, 'run_dashboard_parallel.sh'), 'utf8');
      const block = par.match(/^ALL_TESTS=\(([\s\S]*?)^\)/m)?.[1] ?? '';
      all = block.split(/\s+/).filter(t => NAME.test(t));
    } else if (MODE === 'lite') {
      const tests = readJson(join(HERE, 'tests.json'))?.tests ?? {};
      all = Object.keys(tests);
      for (const t of all) len[t] = (tests[t].sim_ns ?? 40e9) / 1e9;
    }
    const known = new Set(all);
    const seen = new Set();
    const groups = [];
    for (const g of readJson(join(HERE, 'test_groups.json'))?.groups ?? []) {
      const tests = g.tests.filter(t => known.has(t) && !seen.has(t));
      tests.forEach(t => seen.add(t));
      if (tests.length) groups.push({ name: g.name, anchor: g.anchor ?? null, tests: tests.map(t => ({ name: t, sim_s: len[t] ?? 40 })) });
    }
    const rest = all.filter(t => !seen.has(t));
    if (rest.length) groups.push({ name: 'Other', tests: rest.map(t => ({ name: t, sim_s: len[t] ?? 40 })) });
    catalog = { groups, all, len };
    return catalog;
  }

  // ── Regression hosts ─────────────────────────────────────────
  const HOSTS_FILE = join(TMP_ROOT, 'dme_klr', 'regress_hosts.json');
  let hosts = readJson(HOSTS_FILE)?.hosts ?? [];
  const saveHosts = () => {
    mkdirSync(dirname(HOSTS_FILE), { recursive: true });
    writeFileSync(HOSTS_FILE, JSON.stringify({ hosts }, null, 1), { mode: 0o600 });
  };
  const hostUrl = h => `http://${h.host.includes(':') ? `[${h.host}]` : h.host}:${h.port}`;
  const hostStatus = new Map();   // id → {ok, why, info, at}
  let me = null, meAt = 0;
  const local = () => {
    if (!me || Date.now() - meAt > 30000) { me = softwareVersion(REPO); meAt = Date.now(); }
    return me;
  };
  async function probe(h) {
    let st;
    try {
      const r = await fetch(`${hostUrl(h)}/regress/info`, { headers: { Authorization: `Bearer ${h.token}` }, signal: AbortSignal.timeout(5000) });
      if (r.status === 403) st = { ok: false, why: 'refused: wrong token, or this machine is not on its LAN' };
      else if (!r.ok) st = { ok: false, why: `answered ${r.status}: an older bridge, or not started with --listen` };
      else {
        const info = await r.json();
        const same = !!info.srchash && info.srchash === local().srchash;
        st = { ok: same, info, why: same ? '' : `different software: ${info.version} there, ${local().version} here` };
      }
    } catch (e) {
      st = { ok: false, why: `unreachable (${e.cause?.code ?? e.name}); start its bridge with --listen 0.0.0.0 --token <secret>` };
    }
    hostStatus.set(h.id, { ...st, at: Date.now() });
    return st;
  }
  const hostView = h => ({ id: h.id, host: h.host, port: h.port, threads: h.threads, enabled: h.enabled !== false,
                           token: !!h.token, status: hostStatus.get(h.id) ?? null });
  async function hostsView(force) {
    await Promise.all(hosts.filter(h => force || !hostStatus.has(h.id) || Date.now() - hostStatus.get(h.id).at > 15000).map(probe));
    const v = local();
    return { local: { version: v.version, mode: v.mode, cpus: cpus().length }, hosts: hosts.map(hostView) };
  }
  function setHost(o) {
    const host = String(o.host ?? '').trim().replace(/^https?:\/\//, '').replace(/^\[|\]$/g, '');
    if (!/^[A-Za-z0-9.-]{1,253}$/.test(host) && !/^[0-9A-Fa-f:]{2,45}$/.test(host)) return [400, 'a host name or IP address, please'];
    const port = Math.floor(+o.port || 8951);
    if (port < 1 || port > 65535) return [400, 'bad port'];
    const id = `${host}:${port}`;
    const old = hosts.find(h => h.id === id);
    const token = typeof o.token === 'string' && o.token ? o.token : old?.token;
    if (!token) return [400, 'the token the other bridge was started with (--token)'];
    const h = { id, host, port, threads: Math.min(64, Math.max(1, Math.floor(+o.threads || old?.threads || 4))), token,
                enabled: o.enabled ?? old?.enabled ?? true };
    hosts = old ? hosts.map(x => (x.id === id ? h : x)) : [...hosts, h];
    hostStatus.delete(id);
    saveHosts();
    return [200, ''];
  }

  // ── The run ──────────────────────────────────────────────────
  let run = null;
  let proc = null;
  let starting = false;   // checking the hosts before a run
  let timer = null;

  const suite = (label, dir, names, simS) => ({
    label, dir, building: false, startedAt: null,
    tests: Object.fromEntries(names.map(n => [n, { len_s: simS(n), state: 'queued', t_s: 0, verdict: null, detail: '' }])),
  });

  async function start(body) {
    if (!MODE) return [404, 'no run_all.sh or run_tests.py here'];
    if (proc || starting) return [409, 'a run is already going'];
    const cat = getCatalog();
    const o = body ?? {};
    const pick = Array.isArray(o.tests) ? [...new Set(o.tests)] : [];
    const bad = pick.filter(t => !NAME.test(t) || !cat.all.includes(t));
    if (bad.length) return [400, `not a test: ${bad.join(' ')}`];
    if (Array.isArray(o.tests) && !pick.length) return [400, 'no tests picked'];
    const subset = pick.length && pick.length < cat.all.length ? pick : null;
    const names = subset ?? cat.all;
    const maxW = MODE === 'dev' ? 8 : 64;
    const workers = Math.min(maxW, Math.max(1, Math.floor(+o.workers || Math.min(8, cpus().length))));
    const interval = Math.min(10000, Math.max(1, Math.floor(+o.interval_ms || 100)));
    const simMs = MODE === 'lite' && +o.sim_ms > 0 ? Math.floor(+o.sim_ms) : null;
    const simS = n => simMs ? Math.min(simMs / 1000, cat.len[n] ?? 40) : (cat.len[n] ?? 40);
    const logs = d => join(TMP_ROOT, 'dme_klr', d);
    // The ROM images: by name, from the bridge's list only
    const roms = {};
    for (const cpu of ['dme', 'klr']) {
      const name = o.roms?.[cpu] || DEFAULT_ROM[cpu];
      const img = romImages(cpu).find(i => i.name === name);
      if (!img) return [400, `no ${cpu.toUpperCase()} image ${name}`];
      roms[cpu] = img;
    }
    let cmd, args, cwd, steps, suites;
    const env = { ...process.env, DASH_INTERVAL_MS: String(interval), DMEKLR_TMP: TMP_ROOT, PYTHONUNBUFFERED: '1' };
    for (const cpu of ['dme', 'klr']) {
      const CPU = cpu.toUpperCase();
      env[`${CPU}_ROM_DIR`] = roms[cpu].dir.replace(/\\/g, '/').replace(/\/?$/, '/');
      env[`${CPU}_ROM_FILE`] = roms[cpu].name;
    }
    if (MODE === 'dev') {
      const sims = (Array.isArray(o.sims) ? o.sims : ['verilator', 'iverilog']).filter(s => s === 'verilator' || s === 'iverilog');
      if (!sims.length) return [400, 'pick Verilator, iverilog or both'];
      const macos = ['install', 'lite', 'both', 'none'].includes(o.macosTest) ? o.macosTest : 'both';
      args = [RUN_ALL];
      if (sims.length === 1) args.push(`--${sims[0]}`);
      if (o.perTestBuild) args.push('--per-test-build');
      args.push('--macos-test', macos);
      if (o.pull === false) args.push('--no-pull');
      if (subset) args.push('--tests', subset.join(' '));
      args.push(String(workers));
      cmd = 'bash'; cwd = DMEKLR;
      suites = {};
      if (sims.includes('verilator')) suites.vl = suite('Verilator', logs('v_dash_logs'), names, simS);
      if (sims.includes('iverilog')) suites.iv = suite('iverilog', logs('dash_logs'), names, simS);
      steps = [
        { label: 'i8048 KLR regression' }, { label: 'i8051 DME regression' },
        { label: 'Verilator dashboard suite', suite: 'vl' }, { label: 'iverilog dashboard suite', suite: 'iv' },
        { label: 'iverilog vs Verilator comparison + FQS analysis' }, { label: 'macOS install test (clean VM)' },
      ];
    } else {
      args = [RUN_TESTS, '-j', String(workers), '--interval', String(interval)];
      if (simMs) args.push('--sim-ms', String(simMs));
      if (subset) args.push(...subset);
      cmd = PY; cwd = REPO;
      suites = { vl: suite('Verilator', logs('v_dash_logs'), names, simS) };
      steps = [{ label: 'Dashboard regression tests (run_tests.py)', suite: 'vl' }];
    }
    steps = steps.map((s, i) => ({ n: i + 1, state: 'pending', verdict: null, note: '', ...s }));
    // The regression hosts this run can use: enabled, answering, same software
    const useHosts = [], hostNotes = [];
    if (o.useHosts !== false && hosts.some(h => h.enabled !== false)) {
      starting = true;
      try {
        for (const h of hosts.filter(x => x.enabled !== false)) {
          const st = await probe(h);
          if (st.ok) useHosts.push(h); else hostNotes.push(`RUN REGRESSIONS: not using ${h.id}: ${st.why}`);
        }
      } finally { starting = false; }
      if (proc) return [409, 'a run is already going'];
    }
    if (useHosts.length) {
      const f = join(TMP_ROOT, 'run_all', 'regress_hosts.run.json');
      mkdirSync(dirname(f), { recursive: true });
      writeFileSync(f, JSON.stringify(useHosts.map(h => ({ name: h.id, url: hostUrl(h), token: h.token, threads: h.threads }))), { mode: 0o600 });
      env.DMEKLR_REGRESS_HOSTS = f;
    } else delete env.DMEKLR_REGRESS_HOSTS;
    run = {
      id: Date.now().toString(36), mode: MODE, startedAt: Date.now(), endedAt: null, exit: null, stopping: false,
      command: [MODE === 'dev' ? 'run_all.sh' : 'run_tests.py', ...args.slice(1)].join(' '),
      opts: { workers, interval_ms: interval, sim_ms: simMs, tests: subset ? subset.length : 'all',
              roms: { dme: roms.dme.name, klr: roms.klr.name },
              hosts: useHosts.map(h => ({ name: h.id, threads: h.threads })) },
      steps, suites, cur: MODE === 'lite' ? 1 : 0, out: [...hostNotes],
    };
    if (MODE === 'lite') { steps[0].state = 'running'; suites.vl.startedAt = Date.now(); }
    console.log(`bridge: RUN REGRESSIONS: ${run.command}  (DME ${roms.dme.name}, KLR ${roms.klr.name})`);
    proc = spawn(cmd, args, { cwd, env, detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'] });
    const mine = run;
    createInterface({ input: proc.stdout }).on('line', l => onLine(mine, l));
    createInterface({ input: proc.stderr }).on('line', l => onLine(mine, l));
    proc.on('error', e => onLine(mine, `RUN REGRESSIONS: couldn't start ${cmd}: ${e.message}`));
    proc.on('exit', (code, signal) => {
      proc = null;
      clearInterval(timer); timer = null;
      poll(mine);
      mine.endedAt = Date.now();
      mine.exit = signal ? signal : code;
      for (const s of mine.steps) if (s.state === 'running') s.state = mine.stopping ? 'stopped' : 'done';
      for (const su of Object.values(mine.suites))
        for (const t of Object.values(su.tests)) if (t.state === 'running') t.state = 'stopped';
      onLine(mine, `RUN REGRESSIONS: ${mine.stopping ? 'stopped' : `finished, exit ${mine.exit}`}`);
    });
    timer = setInterval(() => poll(mine), POLL_MS);
    return [202, ''];
  }

  function curSuite(r) {
    const s = r.steps[r.cur - 1];
    return s?.suite ? r.suites[s.suite] : null;
  }

  function onLine(r, raw) {
    const line = raw.replace(ANSI, '').replace(/\r/g, '');
    r.out.push(line);
    if (r.out.length > MAX_OUT) r.out.splice(0, r.out.length - MAX_OUT);
    let m;
    if (r.mode === 'dev' && (m = line.match(/^\s*([1-6])\/6\s+\S/))) {
      for (const s of r.steps) if (s.state === 'running') s.state = 'done';
      r.cur = +m[1];
      const s = r.steps[r.cur - 1];
      s.state = 'running';
      if (s.suite && r.suites[s.suite]) r.suites[s.suite].startedAt = Date.now();
      return;
    }
    if (r.mode === 'dev' && /^\s*SUMMARY\s*$/.test(line)) {
      for (const s of r.steps) if (s.state === 'running') s.state = 'done';
      r.cur = 0;
      return;
    }
    const step = r.steps[r.cur - 1];
    if (step && /\[run_all\] (Skipped|.*Skipped)/.test(line)) { step.state = 'skipped'; step.note = line.replace(/^.*\[run_all\]\s*/, ''); return; }
    if (step && (m = line.match(/^\s*[✓⚠✗] (PASS|WARN|FAIL)\s+(.*)$/))) {
      if (step.verdict == null || RANK[m[1]] > RANK[step.verdict]) step.verdict = m[1];
      step.note = step.note ? `${step.note}; ${m[2]}` : m[2];
      return;
    }
    const su = curSuite(r);
    if (!su) return;
    if (/Building the shared testbench/.test(line)) { su.building = true; return; }
    if (/^\s*built in \d+ s/.test(line) || /Shared build FAILED/.test(line)) { su.building = false; return; }
    if ((m = line.match(/^\s*\[REQUEUE\]\s+([A-Za-z0-9_]+)/)) && su.tests[m[1]]) {
      Object.assign(su.tests[m[1]], { state: 'queued', t_s: 0, host: null });
      return;
    }
    if ((m = line.match(/^\s*\[START\]\s+([A-Za-z0-9_]+)(?:\s+@(\S+))?/)) && su.tests[m[1]]) {
      Object.assign(su.tests[m[1]], { state: 'running', t_s: 0, startedAt: Date.now(), host: m[2] ?? null });
      su.building = false;
      return;
    }
    if ((m = line.match(/^\s*\[(PASS|WARN|FAIL|SKIP)\]\s+([A-Za-z0-9_]+)\s*(.*)$/)) && su.tests[m[2]]) {
      const t = su.tests[m[2]];
      const detail = m[3].replace(/^\d+ s\s*/, '').replace(/\s*\(\d+\/\d+\)\s*$/, '').trim();
      Object.assign(t, { state: 'done', verdict: m[1], detail, t_s: t.len_s, endedAt: Date.now() });
    }
  }

  function poll(r) {
    for (const su of Object.values(r.suites))
      for (const [name, t] of Object.entries(su.tests))
        if (t.state === 'running') t.t_s = Math.min(t.len_s, logTimeMs(join(su.dir, `${name}.log`)) / 1000);
  }

  function stop() {
    if (!proc) return false;
    run.stopping = true;
    try {
      if (process.platform === 'win32') spawnSync('taskkill', ['/pid', String(proc.pid), '/T', '/F']);
      else process.kill(-proc.pid, 'SIGTERM');
    } catch { try { proc.kill('SIGTERM'); } catch { /* already gone */ } }
    return true;
  }

  // What the panel shows: per test and per suite the simulated seconds
  // done of the total, and for the run as a whole an estimate of the
  // time left from the simulated seconds per wall second so far
  function view() {
    if (!run) return null;
    const now = run.endedAt ?? Date.now();
    let done = 0, total = 0;
    const suites = {};
    for (const [k, su] of Object.entries(run.suites)) {
      let d = 0, tot = 0;
      const counts = { queued: 0, running: 0, done: 0, stopped: 0, PASS: 0, WARN: 0, FAIL: 0 };
      for (const t of Object.values(su.tests)) {
        tot += t.len_s;
        d += t.state === 'done' ? t.len_s : t.t_s;
        counts[t.state]++;
        if (t.verdict && counts[t.verdict] != null) counts[t.verdict]++;
      }
      done += d; total += tot;
      suites[k] = { label: su.label, building: su.building, done_s: d, total_s: tot, counts, tests: su.tests };
    }
    const firstStart = Math.min(...Object.values(run.suites).flatMap(su => Object.values(su.tests).map(t => t.startedAt ?? Infinity)));
    const wall = isFinite(firstStart) ? (now - firstStart) / 1000 : 0;
    const rate = wall > 30 && done > 0 ? done / wall : null;   // simulated s per wall s
    // A suite's step takes its worst test verdict when it printed none
    const steps = run.steps.map(s => {
      const su = s.suite && suites[s.suite];
      if (s.verdict || s.state !== 'done' || !su || !(su.counts.PASS + su.counts.WARN + su.counts.FAIL)) return s;
      return { ...s, verdict: su.counts.FAIL ? 'FAIL' : su.counts.WARN ? 'WARN' : 'PASS' };
    });
    return {
      id: run.id, mode: run.mode, command: run.command, opts: run.opts,
      startedAt: run.startedAt, endedAt: run.endedAt, exit: run.exit, stopping: run.stopping, running: !!proc,
      elapsed_s: (now - run.startedAt) / 1000, done_s: done, total_s: total,
      eta_s: proc && rate ? (total - done) / rate : null,
      steps, cur: run.cur, suites, out: run.out,
    };
  }

  function handle(req, res, url, CORS) {
    const json = (code, body) => { res.writeHead(code, { ...CORS, 'Content-Type': 'application/json' }); res.end(JSON.stringify(body)); };
    const text = (code, body) => { res.writeHead(code, CORS); res.end(body); };
    if (req.method === 'GET' && url.pathname === '/runall') {
      let groups = [];
      try { groups = MODE ? getCatalog().groups : []; } catch (e) { console.error(`bridge: RUN REGRESSIONS test list: ${e.message}`); }
      const imgs = {};
      for (const cpu of ['dme', 'klr']) {
        try { imgs[cpu] = romImages(cpu).map(({ name, src }) => ({ name, src })); } catch { imgs[cpu] = []; }
      }
      const has = (cpu, n) => imgs[cpu].some(i => i.name === n);
      const presets = ROM_PRESETS.filter(p => has('dme', p.dme) && has('klr', p.klr));
      // each group's MANUAL button: <manual>#<anchor> (the package's manual
      // in the lite package, the developer one here)
      const manual = MODE === 'lite' ? 'docs/USER_MANUAL.md' : 'docs/DEVELOPER_MANUAL.md';
      return json(200, { mode: MODE, platform: process.platform, tart, cpus: cpus().length, groups, manual,
                         roms: { images: imgs, presets, default: DEFAULT_ROM }, run: view() }), true;
    }
    if (req.method === 'POST' && url.pathname === '/runall/stop') return text(stop() ? 204 : 409, ''), true;
    if (url.pathname === '/runall/hosts') {
      if (req.method === 'GET') { hostsView(url.searchParams.has('probe')).then(v => json(200, v), e => text(500, e.message)); return true; }
      if (req.method === 'DELETE') {
        const id = url.searchParams.get('id');
        hosts = hosts.filter(h => h.id !== id);
        hostStatus.delete(id);
        saveHosts();
        return text(204, ''), true;
      }
      if (req.method === 'POST') {
        const chunks = [];
        req.on('data', d => { chunks.push(d); if (chunks.length > 100) req.destroy(); });
        req.on('end', () => {
          let o;
          try { o = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { return text(400, 'body is not JSON'); }
          const [code, msg] = setHost(o);
          if (code !== 200) return text(code, msg);
          hostsView(false).then(v => json(200, v), e => text(500, e.message));
        });
        return true;
      }
    }
    if (req.method === 'POST' && url.pathname === '/runall/start') {
      const chunks = [];
      let size = 0;
      req.on('data', d => { chunks.push(d); size += d.length; if (size > 1e5) req.destroy(); });
      req.on('end', () => {
        let body;
        try { body = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { return text(400, 'body is not JSON'); }
        start(body).then(([code, msg]) => text(code, msg), e => text(500, e.message));
      });
      return true;
    }
    return false;
  }

  return { handle, stop, mode: MODE };
}
