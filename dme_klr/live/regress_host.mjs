// ============================================================
//  regress_host.mjs — this bridge as a regression host for another
//
//  The dashboard's RUN REGRESSIONS panel can spread a run's dashboard
//  tests over other machines on the LAN, each running this bridge with
//    node bridge.mjs --listen 0.0.0.0 --token <secret>
//  (lite package: ./run_lite.sh --listen 0.0.0.0 --token <secret>).
//  The machine that runs the regression sends one test at a time to a
//  host (live/remote_test.mjs), follows its progress, and fetches its
//  logs; validation, snapshots and the summary stay on that machine.
//
//    GET    /regress/info          {mode, version, srchash, commit, sims,
//                                   verilator, cpus, jobs}
//    POST   /regress/run           JSON {test, sim: verilator|iverilog,
//                                   interval_ms, sim_ms, per_test_build,
//                                   srchash, roms: {dme|klr: {name, mem}}}
//                                   → {id}; 409 when srchash isn't ours,
//                                   422 when this host can't run it
//    GET    /regress/run/<id>      {state: building|running|done, exit,
//                                   t_ms, out: [last lines]}
//    GET    /regress/run/<id>/dash the test's .dash.log
//    GET    /regress/run/<id>/log  its whole log, gzipped
//    DELETE /regress/run/<id>      stop it (if running) and forget it
//
//  Requests from another machine reach only /regress/*, need the token
//  (Authorization: Bearer <token>) and must come from a private (LAN)
//  address; see bridge.mjs. "Same software" is srchash: a hash of the
//  simulator's sources (dme, klr, dme_klr, bin_images, paths.sh) as git
//  sees them, uncommitted changes included; the lite package carries
//  the hash of the tree it was built from (VERSION.txt).
// ============================================================

import { spawn, spawnSync } from 'node:child_process';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, createReadStream, openSync, readSync, fstatSync, closeSync } from 'node:fs';
import { cpus } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createGzip } from 'node:zlib';
import { createInterface } from 'node:readline';

const NAME = /^[A-Za-z0-9_]+$/;
const ROM_NAME = /^[A-Za-z0-9_.-]+\.mem$/i;
const ANSI = /\x1b\[[0-9;]*[A-Za-z]/g;
const SRC_PATHS = ['dme', 'klr', 'dme_klr', 'bin_images', 'paths.sh'];

// The newest simulated time in a log (as runall.mjs reads it), in ms
export function logTimeMs(file, tail = 64 * 1024) {
  let fd;
  try {
    fd = openSync(file, 'r');
    const size = fstatSync(fd).size;
    const len = Math.min(size, tail);
    const buf = Buffer.alloc(len);
    readSync(fd, buf, 0, len, size - len);
    let best = 0;
    for (const m of buf.toString('latin1').matchAll(/\[DS\] (\d+),|\bt=(\d+) ms/g)) best = Math.max(best, +(m[1] ?? m[2]));
    return best;
  } catch { return 0; } finally { if (fd !== undefined) closeSync(fd); }
}

// This install's software version: {mode, version, commit, srchash}
export function softwareVersion(REPO) {
  const vfile = join(REPO, 'VERSION.txt');
  if (existsSync(join(REPO, 'run_tests.py')) && existsSync(vfile)) {
    const kv = Object.fromEntries(readFileSync(vfile, 'utf8').split(/\r?\n/).map(l => l.split(/\s+/, 2)).filter(p => p[1]));
    return { mode: 'lite', version: kv.version ?? '?', commit: kv.commit ?? null, srchash: kv.srchash ?? null };
  }
  const git = (...a) => spawnSync('git', ['-C', REPO, ...a], { encoding: 'buffer', maxBuffer: 1 << 28 });
  const head = git('rev-parse', 'HEAD');
  if (head.status !== 0) return { mode: 'dev', version: '?', commit: null, srchash: null };
  const h = createHash('sha256');
  h.update(git('ls-files', '-s', '--', ...SRC_PATHS).stdout ?? '');
  h.update(git('diff', 'HEAD', '--binary', '--', ...SRC_PATHS).stdout ?? '');
  const dirty = (git('status', '--porcelain', '--untracked-files=no', '--', ...SRC_PATHS).stdout ?? '').length > 0;
  const commit = head.stdout.toString().trim();
  return { mode: 'dev', version: commit.slice(0, 10) + (dirty ? '+changes' : ''), commit, dirty, srchash: h.digest('hex').slice(0, 20) };
}

export const tokenOk = (given, want) => {
  if (!want || typeof given !== 'string') return false;
  const a = Buffer.from(given), b = Buffer.from(want);
  return a.length === b.length && timingSafeEqual(a, b);
};

// Private, loopback and link-local addresses (IPv4, IPv6, v4-mapped v6)
export function lanAddress(addr) {
  const a = String(addr ?? '').replace(/^::ffff:/i, '');
  if (/^127\.|^10\.|^192\.168\.|^169\.254\./.test(a)) return true;
  const m = a.match(/^172\.(\d+)\./);
  if (m && +m[1] >= 16 && +m[1] <= 31) return true;
  return /^(::1$|f[cd][0-9a-f]{2}:|fe[89ab][0-9a-f]:)/i.test(a);
}
export const loopback = addr => /^(127\.|::1$|::ffff:127\.)/.test(String(addr ?? ''));

export function makeRegressHost({ REPO, TMP_ROOT, PY }) {
  const DMEKLR = join(REPO, 'dme_klr');
  const MODE = existsSync(join(DMEKLR, 'run_all.sh')) ? 'dev' : existsSync(join(REPO, 'run_tests.py')) ? 'lite' : null;
  const has = c => spawnSync('sh', ['-c', `command -v ${c}`]).status === 0;
  let ver = null, verAt = 0;
  const version = () => {
    if (!ver || Date.now() - verAt > 30000) { ver = softwareVersion(REPO); verAt = Date.now(); }
    return ver;
  };
  const verilator = (() => {
    const r = spawnSync('verilator', ['--version'], { encoding: 'utf8' });
    return r.status === 0 ? r.stdout.trim() : MODE === 'lite' ? 'prebuilt (lite package)' : null;
  })();
  const sims = { verilator: MODE === 'lite' || !!verilator, iverilog: MODE === 'dev' && has('iverilog') && has('vvp') };

  const jobs = new Map();
  const builds = {};   // sim → Promise of the shared runtime dir (developer install)

  function info() {
    return { ...version(), sims, verilator, cpus: cpus().length,
             jobs: [...jobs.values()].filter(j => j.state !== 'done').length };
  }

  // The shared testbench, built once per bridge run (run_dashboard_parallel.sh does the same)
  function runtime(sim, job) {
    if (!builds[sim]) {
      const dir = join(TMP_ROOT, 'dme_klr', sim === 'iverilog' ? 'runtime_iv' : 'runtime');
      builds[sim] = new Promise((res, rej) => {
        const p = spawn('bash', [join(DMEKLR, 'build_runtime.sh'), '--out', dir, ...(sim === 'iverilog' ? ['--iverilog'] : [])],
                        { cwd: DMEKLR, env: { ...process.env, DMEKLR_TMP: TMP_ROOT }, stdio: ['ignore', 'pipe', 'pipe'] });
        const tail = [];
        const keep = l => { tail.push(l); if (tail.length > 20) tail.shift(); };
        createInterface({ input: p.stdout }).on('line', keep);
        createInterface({ input: p.stderr }).on('line', keep);
        p.on('exit', code => code === 0 ? res(dir) : rej(new Error(`shared build failed: ${tail.slice(-3).join(' | ')}`)));
      });
      builds[sim].catch(() => { delete builds[sim]; });
      console.log(`bridge: regression host: building the shared ${sim} testbench`);
    }
    job.state = 'building';
    return builds[sim];
  }

  function start(o) {
    if (!MODE) return [422, 'no runners here'];
    if (!NAME.test(o.test ?? '')) return [400, 'bad test name'];
    const sim = o.sim === 'iverilog' ? 'iverilog' : 'verilator';
    if (!sims[sim]) return [422, `this host has no ${sim}`];
    const v = version();
    if (!o.srchash || o.srchash !== v.srchash) return [409, `different software here: ${v.version} (srchash ${v.srchash})`];
    const id = randomBytes(6).toString('hex');
    // The ROM images, sent with the request: kept by content hash
    const env = { ...process.env, DMEKLR_TMP: TMP_ROOT, PYTHONUNBUFFERED: '1',
                  DASH_INTERVAL_MS: String(Math.min(10000, Math.max(1, +o.interval_ms || 100))) };
    for (const cpu of ['dme', 'klr']) {
      const r = o.roms?.[cpu];
      if (!r) continue;
      if (!ROM_NAME.test(r.name ?? '') || typeof r.mem !== 'string' || r.mem.length > 1e6) return [400, `bad ${cpu} image`];
      const dir = join(TMP_ROOT, 'regress_roms', createHash('sha256').update(r.mem).digest('hex').slice(0, 16));
      mkdirSync(dir, { recursive: true });
      const f = join(dir, r.name);
      if (!existsSync(f)) writeFileSync(f, r.mem);
      env[`${cpu.toUpperCase()}_ROM_DIR`] = dir.replace(/\\/g, '/') + '/';
      env[`${cpu.toUpperCase()}_ROM_FILE`] = r.name;
    }
    const logdir = join(TMP_ROOT, 'dme_klr', sim === 'iverilog' ? 'dash_logs' : 'v_dash_logs');
    const job = { id, test: o.test, sim, logdir, state: 'starting', exit: null, out: [], proc: null, startedAt: Date.now(), killed: false };
    jobs.set(id, job);
    const keep = l => { job.out.push(l.replace(ANSI, '')); if (job.out.length > 40) job.out.shift(); };
    const launch = rtDir => {
      if (job.killed) return;
      let cmd, args, cwd;
      if (MODE === 'dev') {
        cmd = 'bash'; cwd = DMEKLR;
        args = [join(DMEKLR, sim === 'iverilog' ? 'run_dashboard_tests.sh' : 'v_run_dashboard_tests.sh'), o.test];
        if (rtDir) env.DMEKLR_RUNTIME_DIR = rtDir; else delete env.DMEKLR_RUNTIME_DIR;
      } else {
        cmd = PY; cwd = REPO;
        args = [join(REPO, 'run_tests.py'), '-j', '1', '--interval', env.DASH_INTERVAL_MS,
                ...(+o.sim_ms > 0 ? ['--sim-ms', String(Math.floor(+o.sim_ms))] : []), o.test];
      }
      job.state = 'running';
      job.proc = spawn(cmd, args, { cwd, env, detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'] });
      createInterface({ input: job.proc.stdout }).on('line', keep);
      createInterface({ input: job.proc.stderr }).on('line', keep);
      job.proc.on('error', e => keep(`couldn't start: ${e.message}`));
      job.proc.on('exit', (code, sig) => { job.state = 'done'; job.exit = sig ?? code; job.proc = null; job.endedAt = Date.now(); });
    };
    console.log(`bridge: regression host: ${o.test} (${sim}) for a remote run, job ${id}`);
    if (MODE === 'dev' && !o.per_test_build) {
      runtime(sim, job).then(launch, e => { keep(e.message); job.state = 'done'; job.exit = 'build'; });
    } else launch(null);
    return [202, JSON.stringify({ id })];
  }

  function kill(job) {
    job.killed = true;
    if (!job.proc) return;
    try {
      if (process.platform === 'win32') spawnSync('taskkill', ['/pid', String(job.proc.pid), '/T', '/F']);
      else process.kill(-job.proc.pid, 'SIGTERM');
    } catch { try { job.proc.kill('SIGTERM'); } catch { /* gone */ } }
  }

  // Finished jobs nobody fetched are dropped after a day
  setInterval(() => {
    for (const [id, j] of jobs) if (j.state === 'done' && Date.now() - j.endedAt > 864e5) jobs.delete(id);
  }, 36e5).unref();

  function handle(req, res, url) {
    const send = (code, body, type = 'application/json') => { res.writeHead(code, { 'Content-Type': type }); res.end(body); };
    if (req.method === 'GET' && url.pathname === '/regress/info') return send(200, JSON.stringify(info())), true;
    if (req.method === 'POST' && url.pathname === '/regress/run') {
      const chunks = [];
      let size = 0;
      req.on('data', d => { chunks.push(d); size += d.length; if (size > 4e6) req.destroy(); });
      req.on('end', () => {
        let o;
        try { o = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return send(400, 'body is not JSON', 'text/plain'); }
        const [code, body] = start(o);
        send(code, body, code < 300 ? 'application/json' : 'text/plain');
      });
      return true;
    }
    const m = url.pathname.match(/^\/regress\/run\/([0-9a-f]{12})(?:\/(dash|log))?$/);
    if (!m) return false;
    const job = jobs.get(m[1]);
    if (!job) return send(404, 'no such job', 'text/plain'), true;
    if (req.method === 'DELETE' && !m[2]) { kill(job); jobs.delete(job.id); return send(204, ''), true; }
    if (req.method !== 'GET') return false;
    if (!m[2]) {
      const t = job.state === 'running' ? logTimeMs(join(job.logdir, `${job.test}.log`)) : null;
      return send(200, JSON.stringify({ state: job.state, exit: job.exit, t_ms: t, out: job.out.slice(-30) })), true;
    }
    if (job.state !== 'done') return send(409, 'still running', 'text/plain'), true;
    if (m[2] === 'dash') {
      const f = join(job.logdir, `${job.test}.dash.log`);
      if (!existsSync(f)) return send(404, 'no dash.log', 'text/plain'), true;
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      createReadStream(f).pipe(res);
      return true;
    }
    // the whole log, gzipped: the developer runners keep <test>.log.gz,
    // run_tests.py the plain <test>.log
    const gz = join(job.logdir, `${job.test}.log.gz`), raw = join(job.logdir, `${job.test}.log`);
    if (existsSync(gz)) { res.writeHead(200, { 'Content-Type': 'application/gzip' }); createReadStream(gz).pipe(res); return true; }
    if (existsSync(raw)) { res.writeHead(200, { 'Content-Type': 'application/gzip' }); createReadStream(raw).pipe(createGzip()).pipe(res); return true; }
    return send(404, 'no log', 'text/plain'), true;
  }

  return { handle, info, mode: MODE, stopAll: () => { for (const j of jobs.values()) kill(j); } };
}


// node regress_host.mjs version-txt <repo> <version>: the lite package's
// VERSION.txt (make_lite.sh)
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url) && process.argv[2] === 'version-txt') {
  const v = softwareVersion(resolve(process.argv[3] ?? '.'));
  if (!v.srchash) { console.error('regress_host.mjs: not a git checkout'); process.exit(1); }
  console.log(`version ${process.argv[4] ?? v.version}\ncommit ${v.commit}\nsrchash ${v.srchash}`);
}
