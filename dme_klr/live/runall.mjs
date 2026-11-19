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
//    GET  /runall         {mode, platform, tart, cpus, groups, manual, ivDisk, roms,
//                         romFolders, run}
//                         romFolders: the ROM pairs' log folders there are
//                         ($DMEKLR_TMP/dme_klr/<rom>: 89, 86, carpokes,
//                         the DME image's name; logdirs.mjs); run.rom / run.logs:
//                         the folder the run writes in (its ROM pair's)
//                         groups: the tests in the manuals' Appendix A
//                         groups (test_groups.json), each with its
//                         simulated length and the anchor of its section
//                         in manual; ivDisk: dme_klr/iv_disk_rates.json
//                         (iv_disk_usage.sh; null in the lite package),
//                         the iverilog debug runs' MB per simulated
//                         second; run: the current or last run
//    POST /runall/start   JSON body: {sims: ['verilator','iverilog'],
//                         workers, perTestBuild, installTests, pull,
//                         (installTests: the ids of step 6's install tests,
//                         ['macos-install', 'windows-lite', ...]; none by
//                         default; macosTest: install|lite|both|none, the
//                         older form for the two macOS ones)
//                         debug: {<test>: ['DME_DEBUG'|'DME_DEEP_DEBUG'|
//                         'KLR_DEBUG']} (that test in the iverilog suite,
//                         built on its own, always here),
//                         useHosts (false: no regression hosts),
//                         plot (false: run_all.sh --no-plot, no step 5
//                         difference plots),
//                         interval_ms, sim_ms (lite), tests: [names]
//                         (none or every test = the whole suite),
//                         roms: {dme: <file.mem>, klr: <file.mem>},
//                         pairs: ['89', '86', 'carpokes'] (developer
//                         install; two or more: run_all.sh --roms, each
//                         pair in its own folder, in place of roms)}
//                         With pairs the suites are 'vl:<rom>' /
//                         'iv:<rom>' (one per pair and simulator) and the
//                         lines [VL:<rom>] / [IV:<rom>]; run.roms lists them.
//                         roms: the images every test runs on, as
//                         DME_ROM_DIR / DME_ROM_FILE and the KLR_ ones
//                         (run86.sh, run_carpokes.sh); default the 1989
//                         ones. GET /runall lists them (bin_images/<cpu>
//                         and the uploaded ones) and the named pairs
//    GET  /runall/fqs[?rom=<folder>|?dme=<image>&klr=<image>]
//                         {exit, at, rom, iv_dir, vl_dir, text}: fqs_analysis.py
//                         (run_all.sh step 5) on one ROM pair's dash logs as
//                         they are now (default the 1989 pair's), iverilog
//                         and Verilator (developer install)
//    GET  /runall/romdiff?roms=<folder>,<folder>[,...][&sim=verilator|iverilog|both]
//                         [&test=<name>][&all=1]
//                         two to six ROM pairs' dashboard tests side by side
//                         (rom_variant_diff.py --json, developer install):
//                         {roms, sides: [{sim, roms, missing, images,
//                         tests: [{test, verdicts: {<rom>: {verdict, detail}},
//                         verdict_differs, ref, values: {<rom>: {DME|KLR:
//                         {count, fields: [{field, ref, val, ref_last, last,
//                         rel}]}}}}], differing, total}]}; only the tests
//                         that differ unless all=1
//    POST /runall/stop    stop the run and every test it started
//    POST /runall/threads JSON {host: 'local' | <host id>, threads}: while
//                         the run goes, how many tests at a time here
//                         (1 up to maxLocal) or on that regression host (0
//                         up to 64; 0: no more tests there). It applies as
//                         tests start: a test already running ends as it
//                         would have. run.threads: {local, maxLocal,
//                         hosts: {<id>: n}}
//    POST /runall/cancel  JSON {sim: 'vl' | 'iv' (default both), rom: <folder>
//                         (default every pair), tests: [names] (default
//                         all)}: the matching tests not started yet never
//                         start (state 'cancelled'; not in the verdicts);
//                         running ones end as they would have. Answers
//                         {cancelled: <tests marked>}. run.cancels lists them.
//  Both go to the runners through $DMEKLR_RUN_CONTROL, a folder of two
//  files they read before starting each test (run_dashboard_parallel.sh,
//  run_tests.py): threads ("local <n>", "host <id> <n>") and cancel
//  ("<vl|iv|*> <rom|*> <test|*>" lines).
//    GET  /runall/diff?rom=<folder>&test=<name>&ecu=DME|KLR
//                         the run's step 5 plot of where that test's
//                         iverilog and Verilator logs differ
//                         (compare_sim_logs.py --plot, a JPEG in that
//                         pair's iverilog dash_logs); run.diffs lists them as
//                         {<rom>: {<test>: ['DME', 'KLR']}}
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
//                                     local: {version, srchash (the files
//                                     here), running (what this bridge
//                                     started with), restart}; a host whose
//                                     info says restart (pulled, its bridge
//                                     not restarted) isn't used
//    POST   /runall/hosts            JSON {host, port, threads, token,
//                                     enabled}: add, or change (same
//                                     host:port; a blank token keeps it)
//    DELETE /runall/hosts?id=<host:port>
//    POST /runall/hosttest   JSON {dev, hostId, keep, reuse, threads, tests}:
//                            run install/test_regress_hosts.sh (developer
//                            install; a VM needs macOS + Tart, hostId uses
//                            a saved host and its token); GET /runall has
//                            its state as hosttest {step, results, out, ...}
//    POST /runall/hosttest/stop
//  A run uses the enabled hosts whose software is the same as here
//  (srchash) and that answer; the runners get them as
//  $DMEKLR_REGRESS_HOSTS (a JSON file) and run their tests through
//  remote_test.mjs, putting a test back in the queue if its host drops.
// ============================================================

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync, renameSync, rmSync, openSync, readSync, fstatSync, closeSync } from 'node:fs';
import { cpus } from 'node:os';
import { dirname, join } from 'node:path';
import { softwareVersion } from './regress_host.mjs';
import { createInterface } from 'node:readline';
import { romVariant, romVariants, logsDir } from './logdirs.mjs';

const ANSI = /\x1b\[[0-9;]*[A-Za-z]/g;
const NAME = /^[A-Za-z0-9_]+$/;
const MAX_OUT = 400;           // output lines kept for the panel
const POLL_MS = 2000;          // read the running tests' logs this often
const RANK = { PASS: 0, SKIP: 0, WARN: 1, FAIL: 2 };

const readJson = f => { try { return JSON.parse(readFileSync(f, 'utf8')); } catch { return null; } };

// Newest simulated time in a log, in ms (DS lines start with it, the
// PHASE / STATUS lines carry t=<ms> ms). Read forward from where the last
// poll stopped (at most READ_MAX new bytes a poll), so the time only goes
// up: a debug run (--test-debug) prints megabytes of trace between two DS
// lines, and a look at just the end of the log often found none and sent
// the test's bar back to 0.
const READ_MAX = 8 * 1024 * 1024;
const logPos = new Map();   // file → {pos, best}
function logTimeMs(file) {
  let fd;
  let st = logPos.get(file);
  try {
    fd = openSync(file, 'r');
    const size = fstatSync(fd).size;
    if (!st || size < st.pos) st = { pos: 0, best: 0 };    // new or rewritten log
    let from = Math.max(st.pos - 64, 0);                    // a line cut at the last read
    if (size - from > READ_MAX) from = size - READ_MAX;
    if (size > from) {
      const buf = Buffer.alloc(size - from);
      readSync(fd, buf, 0, buf.length, from);
      for (const m of buf.toString('latin1').matchAll(/\[DS\] (\d+),|\bt=(\d+) ms/g)) st.best = Math.max(st.best, +(m[1] ?? m[2]));
      st.pos = size;
    }
    logPos.set(file, st);
    return st.best;
  } catch { return st?.best ?? 0; } finally { if (fd !== undefined) closeSync(fd); }
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
export function makeRunAll({ REPO, HERE, TMP_ROOT, PY, romImages = () => [], setups = () => [] }) {
  const DMEKLR = join(REPO, 'dme_klr');
  const RUN_ALL = join(DMEKLR, 'run_all.sh');
  const RUN_TESTS = join(REPO, 'run_tests.py');
  const MODE = existsSync(RUN_ALL) ? 'dev' : existsSync(RUN_TESTS) ? 'lite' : null;
  const tart = process.platform === 'darwin' && spawnSync('sh', ['-c', 'command -v tart'], { encoding: 'utf8' }).status === 0;

  // ── Step 6's install tests (run_all.sh --install-tests) ──────
  // Each with whether this machine can run it, and why not; looked up
  // again at most once a minute (a VM made or Parallels installed meanwhile)
  const have = c => process.platform !== 'win32' && spawnSync('sh', ['-c', `command -v ${c}`], { encoding: 'utf8' }).status === 0;
  const WIN_VM = process.env.DMEKLR_WIN_VM || 'Windows 11 951 Install Test';
  const WIN_SNAP = process.env.DMEKLR_WIN_SNAPSHOT || 'clean';
  let itCache = null, itAt = 0;
  function installTests() {
    if (itCache && Date.now() - itAt < 60000) return itCache;
    const mac = tart ? '' : 'needs macOS with Tart';
    let win = '';
    if (!have('prlctl')) win = 'needs Parallels Desktop Pro or Business (prlctl)';
    else {
      const r = spawnSync('prlctl', ['list', '-a', '-o', 'name'], { encoding: 'utf8' });
      const names = (r.stdout ?? '').split('\n').slice(1).map(x => x.trim());
      if (!names.includes(WIN_VM)) win = `no Parallels VM called "${WIN_VM}" (DMEKLR_WIN_VM; snapshot DMEKLR_WIN_SNAPSHOT, now "${WIN_SNAP}")`;
    }
    const arch = have('docker') || have('podman') ? '' : 'needs Docker or Podman';
    itCache = [
      { id: 'macos-install', label: 'macOS, developer install (clean VM)', why: mac },
      { id: 'macos-lite',    label: 'macOS, lite package built here (clean VM)', why: mac },
      { id: 'windows-lite',  label: `Windows, lite one-liner (Parallels: ${WIN_VM})`, why: win },
      { id: 'windows-dev',   label: `Windows, developer install (Parallels: ${WIN_VM})`, why: win },
      { id: 'arch-install',  label: 'Arch Linux, developer install (container)', why: arch },
    ].map(t => ({ ...t, available: !t.why }));
    itAt = Date.now();
    return itCache;
  }
  const INSTALL_IDS = ['macos-install', 'macos-lite', 'windows-lite', 'windows-dev', 'arch-install'];

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
  // what this bridge started with: its own code is that, whatever the files are now
  const startedAs = softwareVersion(REPO);
  async function probe(h) {
    let st;
    try {
      const r = await fetch(`${hostUrl(h)}/regress/info`, { headers: { Authorization: `Bearer ${h.token}` }, signal: AbortSignal.timeout(5000) });
      if (r.status === 403) st = { ok: false, why: 'refused: wrong token, or this machine is not on its LAN' };
      else if (!r.ok) st = { ok: false, why: `answered ${r.status}: an older bridge, or not started with --listen` };
      else {
        const info = await r.json();
        const same = !!info.srchash && info.srchash === local().srchash;
        const pyBad = info.python && info.python !== 'ok';
        // info.restart: its files were updated (git pull) but its bridge
        // still runs the old ones (an older bridge doesn't say)
        st = { ok: same && !pyBad && !info.restart, info,
               why: info.restart ? `its bridge is out of date: it runs ${info.version} but its files are ${info.ondisk?.version ?? 'newer'} (pulled, not restarted): restart its bridge`
                  : !same ? `different software: ${info.version} there, ${local().version} here`
                  : pyBad ? `its Python packages aren't installed (${info.python}); run its installer or pip install -r requirements.txt` : '' };
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
    return { local: { version: v.version, mode: v.mode, cpus: cpus().length, srchash: v.srchash,
                      running: startedAs.version, restart: startedAs.srchash !== v.srchash }, hosts: hosts.map(hostView) };
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
    if (htProc) return [409, 'the network run test is going; stop it or wait for it'];
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
    // Several of the named pairs at once (developer install): run_all.sh
    // --roms, each pair in its own folder
    const PAIRS = ['89', '86', 'carpokes'];
    const pairs = MODE === 'dev' && Array.isArray(o.pairs) ? PAIRS.filter(p => o.pairs.includes(p)) : [];
    if (Array.isArray(o.pairs) && MODE === 'dev' && !pairs.length) return [400, 'no ROM pair picked'];
    if (pairs.length === 1) {
      const pr = ROM_PRESETS.find(x => romVariant(x.dme, x.klr) === pairs[0]);
      o.roms = { dme: pr.dme, klr: pr.klr };
    }
    const multi = pairs.length > 1;
    for (const pr of multi ? ROM_PRESETS.filter(x => pairs.includes(romVariant(x.dme, x.klr))) : []) {
      for (const cpu of ['dme', 'klr']) if (!romImages(cpu).some(i => i.name === pr[cpu])) return [400, `no ${cpu.toUpperCase()} image ${pr[cpu]} (${pr.name})`];
    }
    // The ROM images: by name, from the bridge's list only
    const roms = {};
    for (const cpu of ['dme', 'klr']) {
      const name = o.roms?.[cpu] || DEFAULT_ROM[cpu];
      const img = romImages(cpu).find(i => i.name === name);
      if (!img) return [400, `no ${cpu.toUpperCase()} image ${name}`];
      roms[cpu] = img;
    }
    // the runs write in that pair's folder, $DMEKLR_TMP/dme_klr/<rom> (paths.sh)
    const rom = multi ? pairs[0] : romVariant(roms.dme.name, roms.klr.name);
    const romList = multi ? pairs : [rom];
    const logs = d => join(logsDir(TMP_ROOT, rom), d);
    let cmd, args, cwd, steps, suites;
    const env = { ...process.env, DASH_INTERVAL_MS: String(interval), DMEKLR_TMP: TMP_ROOT, PYTHONUNBUFFERED: '1' };
    for (const cpu of ['dme', 'klr']) {
      const CPU = cpu.toUpperCase();
      if (multi) { delete env[`${CPU}_ROM_DIR`]; delete env[`${CPU}_ROM_FILE`]; continue; }   // run_all.sh sets each pair's
      env[`${CPU}_ROM_DIR`] = roms[cpu].dir.replace(/\\/g, '/').replace(/\/?$/, '/');
      env[`${CPU}_ROM_FILE`] = roms[cpu].name;
    }
    if (MODE === 'dev') {
      const sims = (Array.isArray(o.sims) ? o.sims : ['verilator', 'iverilog']).filter(s => s === 'verilator' || s === 'iverilog');
      if (!sims.length) return [400, 'pick Verilator, iverilog or both'];
      // step 6: installTests, or the older macosTest
      let itests = Array.isArray(o.installTests) ? INSTALL_IDS.filter(t => o.installTests.includes(t)) : [];
      if (!Array.isArray(o.installTests)) {
        const m = o.macosTest;
        if (m === 'install' || m === 'both') itests.push('macos-install');
        if (m === 'lite' || m === 'both') itests.push('macos-lite');
      }
      args = [RUN_ALL];
      if (sims.length === 1) args.push(`--${sims[0]}`);
      if (o.perTestBuild) args.push('--per-test-build');
      if (itests.length) args.push('--install-tests', itests.join(' '));
      if (o.pull === false) args.push('--no-pull');
      if (o.plot === false) args.push('--no-plot');
      // iverilog debug output, per test (step 4 only; each builds on its
      // own and stays on this machine): {test: ['DME_DEBUG', ...]}
      if (sims.includes('iverilog') && o.debug && typeof o.debug === 'object' && !Array.isArray(o.debug)) {
        const pickedSet = new Set(subset ?? cat.all);
        for (const [t, fl] of Object.entries(o.debug)) {
          if (!NAME.test(t) || !pickedSet.has(t) || !Array.isArray(fl)) continue;
          const f = [...new Set(fl)].filter(d => ['DME_DEBUG', 'DME_DEEP_DEBUG', 'KLR_DEBUG'].includes(d));
          if (f.length) args.push(`--test-debug=${t}:${f.join('+')}`);
        }
      }
      if (subset) args.push('--tests', subset.join(' '));
      if (multi) args.push('--roms', pairs.join(' '));
      args.push(String(workers));
      cmd = 'bash'; cwd = DMEKLR;
      suites = {};
      const key = (k, r) => multi ? `${k}:${r}` : k;
      for (const r of romList) {
        const dir = d => join(logsDir(TMP_ROOT, r), d);
        if (sims.includes('verilator')) suites[key('vl', r)] = { ...suite('Verilator', dir('v_dash_logs'), names, simS), sim: 'vl', rom: r };
        if (sims.includes('iverilog')) suites[key('iv', r)] = { ...suite('iverilog', dir('dash_logs'), names, simS), sim: 'iv', rom: r };
      }
      const of = k => Object.keys(suites).filter(x => suites[x].sim === k);
      steps = [
        { label: 'i8048 KLR regression' }, { label: 'i8051 DME regression' },
        { label: `Verilator dashboard suite${multi ? 's' : ''}`, suite: multi ? null : 'vl', suites: of('vl') },
        { label: `iverilog dashboard suite${multi ? 's' : ''}`, suite: multi ? null : 'iv', suites: of('iv') },
        { label: 'iverilog vs Verilator comparison + FQS analysis' }, { label: itests.length ? `Install tests (${itests.join(', ')})` : 'Install tests (none picked)' },
      ];
    } else {
      args = [RUN_TESTS, '-j', String(workers), '--interval', String(interval)];
      if (simMs) args.push('--sim-ms', String(simMs));
      if (subset) args.push(...subset);
      cmd = PY; cwd = REPO;
      suites = { vl: { ...suite('Verilator', logs('v_dash_logs'), names, simS), sim: 'vl', rom } };
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
    // RUN CONTROL: the thread counts and cancels the panel changes as the
    // run goes, in a folder the runners read before starting each test
    const control = join(TMP_ROOT, 'run_all', 'control');
    rmSync(control, { recursive: true, force: true });
    mkdirSync(control, { recursive: true });
    env.DMEKLR_RUN_CONTROL = control;
    run = {
      id: Date.now().toString(36), mode: MODE, rom, roms: romList, logs: logsDir(TMP_ROOT, rom),
      startedAt: Date.now(), endedAt: null, exit: null, stopping: false,
      command: [MODE === 'dev' ? 'run_all.sh' : 'run_tests.py', ...args.slice(1)].join(' '),
      opts: { workers, interval_ms: interval, sim_ms: simMs, tests: subset ? subset.length : 'all',
              roms: multi ? { pairs } : { dme: roms.dme.name, klr: roms.klr.name },
              hosts: useHosts.map(h => ({ name: h.id, threads: h.threads })) },
      steps, suites, cur: MODE === 'lite' ? 1 : 0, out: [...hostNotes], diffs: {},
      control, threads: { local: workers, maxLocal: MODE === 'dev' ? Math.max(8, cpus().length) : 64,
                          hosts: Object.fromEntries(useHosts.map(h => [h.id, h.threads])) },
      cancels: [],
    };
    writeControl(run);
    if (MODE === 'lite') { steps[0].state = 'running'; suites.vl.startedAt = Date.now(); }
    console.log(`bridge: RUN REGRESSIONS: ${run.command}  (${multi ? `ROM pairs ${pairs.join(', ')}` : `DME ${roms.dme.name}, KLR ${roms.klr.name}`})`);
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

  // ── RUN CONTROL ($DMEKLR_RUN_CONTROL) ────────────────────────
  // Whole files, written to a temporary name and renamed, so a runner
  // never reads half a line
  function writeCtl(r, name, text) {
    const f = join(r.control, name);
    writeFileSync(`${f}.tmp`, text);
    renameSync(`${f}.tmp`, f);
  }
  function writeControl(r) {
    writeCtl(r, 'threads', [`local ${r.threads.local}`, ...Object.entries(r.threads.hosts).map(([id, n]) => `host ${id} ${n}`)].join('\n') + '\n');
    writeCtl(r, 'cancel', r.cancels.flatMap(c => (c.tests ?? ['*']).map(t => `${c.sim ?? '*'} ${c.rom ?? '*'} ${t}`)).join('\n') + '\n');
  }
  // a cancel that names this suite's test
  const cancelled = (r, su, name) => r.cancels.some(c => (!c.sim || c.sim === su.sim) && (!c.rom || c.rom === su.rom)
                                                       && (!c.tests || c.tests.includes(name)));
  function setThreads(o) {
    if (!proc || !run) return [409, 'no run is going'];
    const n = Math.floor(+o.threads);
    if (!Number.isFinite(n)) return [400, 'threads: a number'];
    if (o.host === 'local' || o.host == null) {
      if (n < 1 || n > run.threads.maxLocal) return [400, `here: 1 to ${run.threads.maxLocal}`];
      run.threads.local = n;
    } else {
      if (!Object.hasOwn(run.threads.hosts, o.host)) return [404, `${o.host} isn't in this run`];
      if (n < 0 || n > 64) return [400, 'a host: 0 to 64'];
      run.threads.hosts[o.host] = n;
    }
    writeControl(run);
    onLine(run, `RUN REGRESSIONS: ${o.host && o.host !== 'local' ? o.host : 'here'}: ${n} test${n === 1 ? '' : 's'} at a time from now on`);
    return [200, ''];
  }
  function cancel(o) {
    if (!proc || !run) return [409, 'no run is going'];
    const sim = o.sim == null || o.sim === '*' ? null : o.sim;
    if (sim && sim !== 'vl' && sim !== 'iv') return [400, "sim: 'vl' or 'iv'"];
    const rom = o.rom == null || o.rom === '*' ? null : String(o.rom);
    if (rom && (!/^[\w.+-]+$/.test(rom) || rom.startsWith('.'))) return [400, 'not a ROM folder'];
    let tests = null;
    if (o.tests != null) {
      if (!Array.isArray(o.tests) || !o.tests.length || o.tests.some(t => typeof t !== 'string' || !NAME.test(t))) return [400, 'tests: test names'];
      tests = [...new Set(o.tests)];
    }
    // with one ROM pair the suites' folder is the run's: no need to name it
    const c = { sim, rom: (run.roms?.length ?? 1) > 1 ? rom : null, tests };
    run.cancels.push(c);
    writeControl(run);
    let k = 0;
    for (const su of Object.values(run.suites))
      for (const [name, t] of Object.entries(su.tests))
        if (t.state === 'queued' && cancelled(run, su, name)) { t.state = 'cancelled'; k++; }
    onLine(run, `RUN REGRESSIONS: cancelled ${k} test${k === 1 ? '' : 's'} not started yet (${sim ? sim.toUpperCase() : 'both simulators'}`
                + `${rom && c.rom ? `, ROM pair ${rom}` : ''}${tests ? `, ${tests.length > 3 ? `${tests.length} tests` : tests.join(' ')}` : ', every test'})`);
    return [200, k];
  }

  function curSuite(r) {
    const s = r.steps[r.cur - 1];
    return s?.suite ? r.suites[s.suite] : null;
  }

  function onLine(r, raw) {
    let line = raw.replace(ANSI, '').replace(/\r/g, '');
    r.out.push(line);
    if (r.out.length > MAX_OUT) r.out.splice(0, r.out.length - MAX_OUT);
    let m;
    // run_all.sh runs every suite at the same time (both simulators, several
    // ROM pairs), sharing the workers: "3+4/6" starts both steps, and each
    // suite's lines (and its verdict) then start with [VL] / [IV], or
    // [VL:<rom>] / [IV:<rom>]
    if (r.mode === 'dev' && /^\s*3\+4\/6\s+\S/.test(line)) {
      for (const s of r.steps) if (s.state === 'running') s.state = 'done';
      r.cur = 3;
      for (const s of [r.steps[2], r.steps[3]]) {
        s.state = 'running';
        for (const k of s.suites ?? [s.suite]) if (r.suites[k]) r.suites[k].startedAt = Date.now();
      }
      return;
    }
    let tagged = null, tagSuite = null;
    if (r.mode === 'dev' && (m = line.match(/^\[(VL|IV)(?::([\w.+-]+))?\] ?(.*)$/))) {
      tagged = m[1] === 'VL' ? 3 : 4;
      tagSuite = m[1].toLowerCase() + (m[2] ? `:${m[2]}` : '');
      line = m[3];
    }
    if (r.mode === 'dev' && (m = line.match(/^\s*([1-6])\/6\s+\S/))) {
      for (const s of r.steps) if (s.state === 'running') s.state = 'done';
      r.cur = +m[1];
      const s = r.steps[r.cur - 1];
      s.state = 'running';
      for (const k of s.suites ?? [s.suite]) if (k && r.suites[k]) r.suites[k].startedAt = Date.now();
      return;
    }
    if (r.mode === 'dev' && /^\s*SUMMARY\s*$/.test(line)) {
      for (const s of r.steps) if (s.state === 'running') s.state = 'done';
      r.cur = 0;
      return;
    }
    // step 5's difference plots (compare_sim_logs.py --plot)
    // (in its ROM pair's dash_logs: .../dme_klr/<rom>/dash_logs/<test>_DME_diff.jpg)
    if (r.mode === 'dev' && (m = line.match(/^(DME|KLR) plot written to (.*?)([A-Za-z0-9_]+)_(DME|KLR)_diff\.jpg\b/)) && m[1] === m[4]) {
      const rom = m[2].replace(/\\/g, '/').match(/([^/]+)\/dash_logs\/$/)?.[1] ?? r.rom;
      const l = ((r.diffs[rom] ??= {})[m[3]] ??= []);
      if (!l.includes(m[1])) l.push(m[1]);
      return;
    }
    const step = r.steps[(tagged ?? r.cur) - 1];
    if (step && /\[run_all\] (Skipped|.*Skipped)/.test(line)) { step.state = 'skipped'; step.note = line.replace(/^.*\[run_all\]\s*/, ''); return; }
    if (step && (m = line.match(/^\s*[✓⚠✗] (PASS|WARN|FAIL)\s+(.*)$/))) {
      if (step.verdict == null || RANK[m[1]] > RANK[step.verdict]) step.verdict = m[1];
      step.note = step.note ? `${step.note}; ${m[2]}` : m[2];
      return;
    }
    const su = tagged ? r.suites[tagSuite] : curSuite(r);
    if (!su) return;
    if (/Building the shared testbench/.test(line)) { su.building = true; return; }
    if (/^\s*built in \d+ s/.test(line) || /Shared build FAILED/.test(line)) { su.building = false; return; }
    if ((m = line.match(/^\s*\[REQUEUE\]\s+([A-Za-z0-9_]+)/)) && su.tests[m[1]]) {
      // (a cancel since it started: the runner drops it from its queue)
      Object.assign(su.tests[m[1]], { state: cancelled(r, su, m[1]) ? 'cancelled' : 'queued', t_s: 0, host: null });
      return;
    }
    if ((m = line.match(/^\s*\[CANCEL\]\s+([A-Za-z0-9_]+)/)) && su.tests[m[1]]) {
      Object.assign(su.tests[m[1]], { state: 'cancelled', t_s: 0 });
      return;
    }
    if ((m = line.match(/^\s*\[START\]\s+([A-Za-z0-9_]+)(?:\s+@(\S+))?/)) && su.tests[m[1]]) {
      Object.assign(su.tests[m[1]], { state: 'running', t_s: 0, startedAt: Date.now(), host: m[2] ?? null });
      logPos.delete(join(su.dir, `${m[1]}.log`));   // a new log: read it from the start
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
        if (t.state === 'running') t.t_s = Math.max(t.t_s, Math.min(t.len_s, logTimeMs(join(su.dir, `${name}.log`)) / 1000));
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

  // ── The network run test (install/test_regress_hosts.sh) ─────
  // One at a time, and not during a run: {dev, hostId (a saved host
  // instead of a VM), keep, reuse, threads, tests}. Its PASS / FAIL /
  // SKIP lines and its step headers are what the panel shows.
  const HOSTTEST = join(REPO, 'install', 'test_regress_hosts.sh');
  let ht = null, htProc = null;
  function hostTestStart(o) {
    if (MODE !== 'dev' || !existsSync(HOSTTEST)) return [422, 'the network run test needs the developer install (install/test_regress_hosts.sh)'];
    if (htProc) return [409, 'the network run test is already going'];
    if (proc || starting) return [409, 'a regression run is going; try again when it ends'];
    const args = [HOSTTEST];
    const env = { ...process.env, DMEKLR_TMP: TMP_ROOT };
    delete env.DMEKLR_REGRESS_TOKEN;
    let target;
    if (o.hostId) {
      const h = hosts.find(x => x.id === o.hostId);
      if (!h) return [404, `no regression host ${o.hostId}`];
      args.push('--host', hostUrl(h));
      env.DMEKLR_REGRESS_TOKEN = h.token;       // not on the command line
      target = h.id;
    } else {
      if (!tart) return [422, 'a VM needs macOS on Apple Silicon with Tart; pick a host from the list instead'];
      if (o.dev) args.push('--dev');
      if (o.reuse) args.push('--reuse');
      if (o.keep) args.push('--keep');
      target = `macOS VM (${o.dev ? 'developer install' : 'lite package'})`;
    }
    const th = Math.floor(+o.threads);
    if (th >= 1 && th <= 64) args.push('--threads', String(th));
    if (Array.isArray(o.tests) && o.tests.length) {
      const t = o.tests.filter(x => NAME.test(x));
      if (t.length) args.push('--tests', t.join(' '));
    }
    ht = { target, command: ['install/test_regress_hosts.sh', ...args.slice(1)].join(' '), startedAt: Date.now(),
           endedAt: null, exit: null, stopping: false, step: 'starting', results: [], out: [], logs: null };
    const mine = ht;
    console.log(`bridge: RUN REGRESSIONS: ${ht.command}`);
    htProc = spawn('bash', args, { cwd: REPO, env, detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'] });
    const line = raw => {
      const l = raw.replace(ANSI, '');
      mine.out.push(l); if (mine.out.length > 2000) mine.out.shift();
      let m;
      if ((m = l.match(/^==> (.*)/))) mine.step = m[1];
      else if ((m = l.match(/^\s{4}(PASS|FAIL|SKIP)\s+(\d+[a-z]?\.[^:]*): ?(.*)$/))) mine.results.push({ status: m[1], name: m[2], detail: m[3] });
      else if ((m = l.match(/^Logs: (.*)/))) mine.logs = m[1];
    };
    createInterface({ input: htProc.stdout }).on('line', line);
    createInterface({ input: htProc.stderr }).on('line', line);
    htProc.on('error', e => line(`couldn't start: ${e.message}`));
    htProc.on('exit', (code, sig) => {
      htProc = null; mine.endedAt = Date.now(); mine.exit = sig ?? code;
      mine.step = mine.stopping ? 'stopped' : code === 0 ? 'all checks passed' : code === 1 ? 'some checks failed' : `ended (exit ${mine.exit})`;
    });
    return [202, ''];
  }
  function hostTestStop() {
    if (!htProc) return false;
    ht.stopping = true;
    try { process.kill(-htProc.pid, 'SIGTERM'); } catch { try { htProc.kill('SIGTERM'); } catch { /* gone */ } }
    return true;
  }
  const hostTestView = () => ht && { ...ht, running: !!htProc, elapsed_s: ((ht.endedAt ?? Date.now()) - ht.startedAt) / 1000,
                                     out: ht.out.slice(-400) };

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
      const counts = { queued: 0, running: 0, done: 0, stopped: 0, cancelled: 0, PASS: 0, WARN: 0, FAIL: 0 };
      for (const t of Object.values(su.tests)) {
        counts[t.state]++;
        if (t.state === 'cancelled') continue;   // not in the run's total any more
        tot += t.len_s;
        d += t.state === 'done' ? t.len_s : t.t_s;
        if (t.verdict && counts[t.verdict] != null) counts[t.verdict]++;
      }
      done += d; total += tot;
      suites[k] = { label: su.label, sim: su.sim, rom: su.rom, building: su.building, done_s: d, total_s: tot, counts, tests: su.tests };
    }
    const firstStart = Math.min(...Object.values(run.suites).flatMap(su => Object.values(su.tests).map(t => t.startedAt ?? Infinity)));
    const wall = isFinite(firstStart) ? (now - firstStart) / 1000 : 0;
    const rate = wall > 30 && done > 0 ? done / wall : null;   // simulated s per wall s
    // A suite's step takes its worst test verdict when it printed none
    const steps = run.steps.map(s => {
      const sus = (s.suites ?? [s.suite]).map(k => k && suites[k]).filter(Boolean);
      const c = k => sus.reduce((a, su) => a + su.counts[k], 0);
      if (s.verdict || s.state !== 'done' || !sus.length || !(c('PASS') + c('WARN') + c('FAIL'))) return s;
      return { ...s, verdict: c('FAIL') ? 'FAIL' : c('WARN') ? 'WARN' : 'PASS' };
    });
    return {
      id: run.id, mode: run.mode, rom: run.rom, roms: run.roms, logs: run.logs, command: run.command, opts: run.opts,
      startedAt: run.startedAt, endedAt: run.endedAt, exit: run.exit, stopping: run.stopping, running: !!proc,
      elapsed_s: (now - run.startedAt) / 1000, done_s: done, total_s: total,
      eta_s: proc && rate ? (total - done) / rate : null,
      steps, cur: run.cur, suites, out: run.out, diffs: run.diffs,
      threads: run.threads, cancels: run.cancels,
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
      const presets = ROM_PRESETS.filter(p => has('dme', p.dme) && has('klr', p.klr)).map(p => ({ ...p, folder: romVariant(p.dme, p.klr) }));
      // image setups saved from the dashboard: a pair to pick (run as roms, not --roms)
      for (const x of setups()) if (has('dme', x.dme) && has('klr', x.klr))
        presets.push({ name: `${x.name} (setup)`, dme: x.dme, klr: x.klr, folder: romVariant(x.dme, x.klr), custom: true });
      // each group's MANUAL button: <manual>#<anchor> (the package's manual
      // in the lite package, the developer one here)
      const manual = MODE === 'lite' ? 'docs/USER_MANUAL.md' : 'docs/DEVELOPER_MANUAL.md';
      // the iverilog debug runs' disk use per simulated second, measured by
      // iv_disk_usage.sh (the panel estimates each picked test's from it)
      const ivDisk = MODE === 'dev' ? readJson(join(DMEKLR, 'iv_disk_rates.json')) : null;
      return json(200, { mode: MODE, platform: process.platform, tart, cpus: cpus().length, groups, manual, ivDisk,
                         roms: { images: imgs, presets, default: DEFAULT_ROM }, romFolders: romVariants(TMP_ROOT), run: view(),
                         hosttest: hostTestView(), hosttestAvailable: MODE === 'dev' && existsSync(HOSTTEST),
                         installTests: MODE === 'dev' ? installTests() : [] }), true;
    }
    if (req.method === 'GET' && url.pathname === '/runall/fqs') {
      // The FQS analysis (fqs_analysis.py, run_all.sh's step 5) of the
      // dash logs as they are now, iverilog and Verilator, for the panel's
      // FQS ANALYSIS view
      if (MODE !== 'dev') return text(404, 'the FQS analysis is in the developer install only'), true;
      // of one ROM pair's folder: ?rom=<folder> (GET /runall's romFolders),
      // or ?dme=<image>&klr=<image>; default the 1989 pair's
      const q = url.searchParams;
      const rom = q.get('rom') ?? romVariant(q.get('dme'), q.get('klr'));
      if (!/^[\w.+-]+$/.test(rom) || rom.startsWith('.')) return text(400, 'not a ROM folder'), true;
      const iv = join(logsDir(TMP_ROOT, rom), 'dash_logs'), vl = join(logsDir(TMP_ROOT, rom), 'v_dash_logs');
      const p = spawn(PY, [join(DMEKLR, 'fqs_analysis.py'), '--iv-dir', iv, '--vl-dir', vl],
                      { cwd: DMEKLR, env: { ...process.env, DMEKLR_TMP: TMP_ROOT, PYTHONIOENCODING: 'utf-8' } });
      const out = [];
      const timer = setTimeout(() => p.kill(), 120000);
      p.stdout.on('data', d => out.push(d));
      p.stderr.on('data', d => out.push(d));
      p.on('error', e => { clearTimeout(timer); json(500, { error: `couldn't run fqs_analysis.py: ${e.message}` }); });
      p.on('close', code => {
        clearTimeout(timer);
        json(200, { exit: code, at: Date.now(), rom, iv_dir: iv, vl_dir: vl,
                    text: Buffer.concat(out).toString('utf8').replace(ANSI, '') });
      });
      return true;
    }
    if (req.method === 'GET' && url.pathname === '/runall/romdiff') {
      // The panel's ROM VARIANTS view: two or more ROM pairs' dashboard
      // tests side by side (rom_variant_diff.py --json)
      if (MODE !== 'dev') return text(404, 'the ROM variant comparison is in the developer install only'), true;
      const q = url.searchParams;
      const roms = [...new Set((q.get('roms') ?? '').split(',').map(s => s.trim()).filter(Boolean))];
      if (roms.length < 2 || roms.length > 6 || roms.some(r => !/^[\w.+-]+$/.test(r) || r.startsWith('.')))
        return text(400, 'roms: two to six ROM folders, comma-separated'), true;
      const sim = q.get('sim') ?? 'both';
      if (!['verilator', 'iverilog', 'both'].includes(sim)) return text(400, 'sim: verilator, iverilog or both'), true;
      const args = [join(DMEKLR, 'rom_variant_diff.py'), '--json', '--sim', sim, '--base', join(TMP_ROOT, 'dme_klr'),
                    ...(q.get('all') === '1' ? ['--all'] : [])];
      const t = q.get('test');
      if (t) { if (!/^\w+$/.test(t)) return text(400, 'bad test name'), true; args.push('--test', t); }
      const p = spawn(PY, [...args, ...roms],
                      { cwd: DMEKLR, env: { ...process.env, DMEKLR_TMP: TMP_ROOT, PYTHONIOENCODING: 'utf-8' } });
      const out = [], err = [];
      const timer = setTimeout(() => p.kill(), 120000);
      p.stdout.on('data', d => out.push(d));
      p.stderr.on('data', d => err.push(d));
      p.on('error', e => { clearTimeout(timer); json(500, { error: `couldn't run rom_variant_diff.py: ${e.message}` }); });
      p.on('close', code => {
        clearTimeout(timer);
        let body;
        try { body = JSON.parse(Buffer.concat(out).toString('utf8')); }
        catch { return json(500, { error: `rom_variant_diff.py exit ${code}: ${Buffer.concat(err).toString('utf8').slice(-500)}` }); }
        json(200, { ...body, at: Date.now() });
      });
      return true;
    }
    if (req.method === 'GET' && url.pathname === '/runall/diff') {
      // a step 5 plot this run made (only those: the name comes from run.diffs)
      const t = url.searchParams.get('test') ?? '', ecu = url.searchParams.get('ecu') ?? '';
      const rom = url.searchParams.get('rom') ?? run?.rom;
      if (!Object.hasOwn(run?.diffs ?? {}, rom) || !run.diffs[rom][t]?.includes(ecu)) return text(404, 'no such plot in this run'), true;
      const f = join(logsDir(TMP_ROOT, rom), 'dash_logs', `${t}_${ecu}_diff.jpg`);
      let data;
      try { data = readFileSync(f); } catch { return text(404, `${f} is gone`), true; }
      res.writeHead(200, { ...CORS, 'Content-Type': 'image/jpeg', 'Cache-Control': 'no-store' });
      res.end(data);
      return true;
    }
    if (req.method === 'POST' && url.pathname === '/runall/stop') return text(stop() ? 204 : 409, ''), true;
    if (req.method === 'POST' && (url.pathname === '/runall/threads' || url.pathname === '/runall/cancel')) {
      const chunks = [];
      let size = 0;
      req.on('data', d => { chunks.push(d); size += d.length; if (size > 1e5) req.destroy(); });
      req.on('end', () => {
        let o;
        try { o = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { return text(400, 'body is not JSON'); }
        try {
          if (url.pathname === '/runall/threads') { const [code, msg] = setThreads(o); return text(code, msg); }
          const [code, k] = cancel(o);
          return code === 200 ? json(200, { cancelled: k }) : text(code, k);
        } catch (e) { return text(500, e.message); }
      });
      return true;
    }
    if (req.method === 'POST' && url.pathname === '/runall/hosttest/stop') return text(hostTestStop() ? 204 : 409, ''), true;
    if (req.method === 'POST' && url.pathname === '/runall/hosttest') {
      const chunks = [];
      req.on('data', d => { chunks.push(d); if (chunks.length > 100) req.destroy(); });
      req.on('end', () => {
        let o;
        try { o = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { return text(400, 'body is not JSON'); }
        const [code, msg] = hostTestStart(o);
        text(code, msg);
      });
      return true;
    }
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
