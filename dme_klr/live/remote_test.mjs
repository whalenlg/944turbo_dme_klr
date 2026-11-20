#!/usr/bin/env node
// ============================================================
//  remote_test.mjs — run one dashboard test on a regression host
//
//  Used by run_dashboard_parallel.sh and run_tests.py for the slots of
//  the hosts in $DMEKLR_REGRESS_HOSTS (see regress_host.mjs): sends the
//  test to that host's bridge, writes its progress to <out>/<test>.log
//  as "t=<ms> ms" lines (so the RUN REGRESSIONS panel's bars move), and
//  when it ends fetches <test>.dash.log and the whole log into <out>
//  (and, for iverilog, the waveform into <out>/fst/<test>.fst; for a
//  log replay, its <test>.report.txt and <test>.mismatches.xlsx),
//  where the runner validates it as if it had run here.
//
//  Usage:
//    node remote_test.mjs --host <url> [--token <t>] --test <name>
//         --out <dir> [--sim verilator|iverilog] [--interval <ms>]
//         [--sim-ms <n>] [--per-test-build] [--log gz|raw]
//  --log gz (the developer runners): <test>.log.gz; raw (run_tests.py):
//  <test>.log. The ROM images are DME_ROM_DIR / DME_ROM_FILE and the
//  KLR_ ones (default the 1989 pair), sent with the request.
//
//  Exit 0 the test ran (its verdict is the validator's), 1 it ran and
//  failed there, 75 the host can't take it (unreachable, different
//  software, no such simulator, missing Python packages, no dash.log,
//  dropped mid-run): the runner puts the
//  test back in the queue and stops using that host. 76: the test ran
//  there but its logs wouldn't come back (every try stalled): the test
//  goes back in the queue, and the host keeps getting tests (the runner
//  stops using it after a few of these).
//
//  The logs come back in 64 KB pieces (Range requests), each over a
//  new connection (node:http, no keep-alive): between two Macs on a LAN
//  one transfer stopped for good after ~150 KB while short requests went
//  through, so whole-file downloads held tests at 99%. A piece that
//  receives nothing for STALL_MS is dropped and asked for again.
//
//  A connection the host doesn't answer is given up after CONNECT_MS
//  (the OS would wait 40-75 s). When this machine has more than one
//  address on the host's subnet (wired and Wi-Fi both up), a failed try
//  goes out from the next one, and the address that last worked is kept:
//  a Mac on both saw most connections from its wired address go
//  unanswered while every one from its Wi-Fi address got through, and its
//  tests sat at 99% for half an hour fetching logs 64 KB at a time.
// ============================================================

import { readFileSync, writeFileSync, appendFileSync, rmSync, mkdirSync, renameSync } from 'node:fs';
import { request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';
import { networkInterfaces } from 'node:os';
import { gunzipSync } from 'node:zlib';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { softwareVersion } from './regress_host.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const arg = (n, d) => { const i = process.argv.indexOf(`--${n}`); return i > 0 && process.argv[i + 1] != null ? process.argv[i + 1] : d; };
const flag = n => process.argv.includes(`--${n}`);
const HOST = (arg('host', '') || '').replace(/\/+$/, '');
const TOKEN = arg('token', process.env.DMEKLR_REGRESS_TOKEN || '');
const TEST = arg('test', '');
const OUT = arg('out', '');
const SIM = arg('sim', 'verilator');
const LOGMODE = arg('log', 'gz');
const TEMPFAIL = 75;
const GIVEBACK = 76;       // ran there, but its logs wouldn't come back
const STALL_MS = +process.env.DMEKLR_REMOTE_STALL_MS || 15_000;   // a piece of a download that receives nothing this long is tried again
const CHUNK = +process.env.DMEKLR_REMOTE_CHUNK || 65536;          // bytes per download request
const CONNECT_MS = +process.env.DMEKLR_REMOTE_CONNECT_MS || 5_000; // a connection not answered this long is tried again
const TRIES = 5;
const DROP_MS = 90_000;    // no answer this long: the host has dropped
const REFUSED_MS = 15_000; // refused this long: the bridge has stopped
const POLL_MS = 2000;

if (!HOST || !/^[A-Za-z0-9_]+$/.test(TEST) || !OUT) {
  console.error('usage: remote_test.mjs --host <url> --token <t> --test <name> --out <dir> [--sim verilator|iverilog]');
  process.exit(2);
}
const who = HOST.replace(/^https?:\/\//, '');
const say = s => console.log(`remote ${who}: ${TEST}: ${s}`);
const H = TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {};
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function call(method, path, body, ms = 30_000) {
  const r = await fetch(HOST + path, { method, headers: { ...H, ...(body ? { 'Content-Type': 'application/json' } : {}) },
                                       body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(ms) });
  return r;
}

// This machine's addresses on the host's subnet (IPv4 host given by
// address only), so a try that fails can go out from another interface.
// [] when there's only one, or the host is a name: the OS picks.
function sourceAddresses() {
  const h = new URL(HOST).hostname;
  const n = a => a.split('.').reduce((v, x) => (v * 256 + +x), 0);
  if (!/^\d+\.\d+\.\d+\.\d+$/.test(h)) return [];
  const out = [];
  for (const list of Object.values(networkInterfaces()))
    for (const i of list ?? []) {
      if (i.family !== 'IPv4' || i.internal || !i.netmask) continue;
      const m = n(i.netmask);
      if (m && (n(i.address) & m) >>> 0 === (n(h) & m) >>> 0 && !out.includes(i.address)) out.push(i.address);
    }
  return out.length > 1 ? out : [];
}
const SRC = sourceAddresses();
let srcAt = 0;   // SRC[srcAt]: the one the next try uses (the last that worked)

// GET <path> of the job, bytes a..b, on a connection of its own:
// {status, body, total} (body null unless 200/206; total from
// Content-Range, or the body's length for a whole-file 200 from an older
// host). Rejects when the connection drops or nothing moves for STALL_MS.
function getOnce(path, a, b) {
  return new Promise((res, rej) => {
    const u = new URL(HOST + path);
    // how far a try got, for the message when it stalls
    let stage = 'no answer', got = 0;
    const src = SRC.length ? { localAddress: SRC[srcAt] } : {};
    const req = (u.protocol === 'https:' ? httpsRequest : httpRequest)(u, { method: 'GET', headers: { ...H, Connection: 'close', Range: `bytes=${a}-${b}` }, agent: false, ...src }, r => {
      if (r.statusCode !== 200 && r.statusCode !== 206) { r.resume(); return res({ status: r.statusCode, body: null }); }
      stage = 'headers';
      const parts = [];
      r.on('data', d => { parts.push(d); got += d.length; stage = `${got} bytes`; });
      r.on('end', () => {
        if (!r.complete) return rej(new Error('connection closed mid-transfer'));
        const body = Buffer.concat(parts);
        const total = r.statusCode === 206 ? +(/\/(\d+)$/.exec(r.headers['content-range'] ?? '')?.[1] ?? NaN) : body.length;
        res({ status: r.statusCode, body, total });
      });
      r.on('error', rej);
      r.on('aborted', () => rej(new Error('connection closed mid-transfer')));
    });
    // no bytes either way for STALL_MS: give this try up. (Node starts
    // that clock only once connected, so the connect has its own.)
    req.setTimeout(STALL_MS, () => req.destroy(new Error(`stalled ${STALL_MS / 1000} s after ${stage}`)));
    const conn = setTimeout(() => req.destroy(new Error(`no answer to connect in ${CONNECT_MS / 1000} s${src.localAddress ? ` from ${src.localAddress}` : ''}`)), CONNECT_MS);
    req.on('socket', s => { if (!s.connecting) clearTimeout(conn); else s.once('connect', () => clearTimeout(conn)); });
    req.on('close', () => clearTimeout(conn));
    req.on('error', rej);
    req.end();
  });
}
// The whole file at <path>, CHUNK bytes per request: between some Macs
// on a LAN a transfer stops for good after ~150 KB on one connection
// (short requests go through), so a large dash.log never arrived in one
// response. Each piece is tried up to TRIES times. {status, body}, body
// null when the host has no such file; throws when a piece never came.
async function download(what, path) {
  const t0 = Date.now(), parts = [];
  let off = 0, total = Infinity, retried = 0;
  while (off < total) {
    let r, last;
    for (let i = 1; i <= TRIES; i++) {
      const t1 = Date.now();
      try { r = await getOnce(path, off, off + CHUNK - 1); break; } catch (e) {
        last = e;
        retried++;
        say(`${what}: bytes ${off}+ try ${i} of ${TRIES} failed after ${((Date.now() - t1) / 1000).toFixed(0)} s (${e.code ?? e.message})`);
        // next try from this machine's next address on the host's subnet
        if (SRC.length) { srcAt = (srcAt + 1) % SRC.length; say(`${what}: next try from ${SRC[srcAt]}`); }
        if (i < TRIES) await sleep(1000 * 2 ** (i - 1));
      }
    }
    if (!r) throw last;
    if (r.status === 416 && off === 0) { total = 0; break; }   // an empty file
    if (!r.body) return { status: r.status, body: null };
    if (r.status === 200) { parts.length = 0; parts.push(r.body); total = r.body.length; break; }   // an older host: the whole file
    if (!Number.isFinite(r.total) || r.body.length === 0) throw new Error(`bad piece at ${off} (${r.body.length} bytes of ${r.total})`);
    total = r.total;
    parts.push(r.body);
    off += r.body.length;
  }
  const body = Buffer.concat(parts);
  say(`${what}: ${body.length} bytes in ${((Date.now() - t0) / 1000).toFixed(1)} s${retried ? ` (${retried} piece${retried > 1 ? 's' : ''} tried again)` : ''}`);
  return { status: 200, body };
}
// write via a temporary name, so a half file never stands for the real one
function save(file, buf) {
  writeFileSync(`${file}.part`, buf);
  renameSync(`${file}.part`, file);
}

let jobId = null;
async function forget() {
  if (jobId) { try { await call('DELETE', `/regress/run/${jobId}`); } catch { /* host gone */ } }
}
for (const s of ['SIGTERM', 'SIGINT']) process.on(s, async () => { await forget(); process.exit(143); });

function rom(cpu) {
  const CPU = cpu.toUpperCase();
  const dir = process.env[`${CPU}_ROM_DIR`] || join(REPO, 'bin_images', cpu) + '/';
  const name = process.env[`${CPU}_ROM_FILE`] || (cpu === 'dme' ? '89DME_951pin.mem' : '89KLR_951.mem');
  return { name, mem: readFileSync(join(dir, name), 'utf8') };
}

async function main() {
  mkdirSync(OUT, { recursive: true });
  const progress = join(OUT, `${TEST}.log`);
  // (a replay's report too: an old one here would stand for this run's)
  for (const f of [progress, `${progress}.gz`, join(OUT, `${TEST}.dash.log`),
                   join(OUT, `${TEST}.report.txt`), join(OUT, `${TEST}.mismatches.xlsx`)]) rmSync(f, { force: true });
  let r;
  try {
    r = await call('POST', '/regress/run', {
      test: TEST, sim: SIM, interval_ms: +(arg('interval', process.env.DASH_INTERVAL_MS || 100)),
      sim_ms: +arg('sim-ms', 0) || null, per_test_build: flag('per-test-build'),
      srchash: softwareVersion(REPO).srchash, roms: { dme: rom('dme'), klr: rom('klr') },
    });
  } catch (e) { say(`unreachable (${e.cause?.code ?? e.message})`); return TEMPFAIL; }
  if (!r.ok) { say(`refused: ${r.status} ${(await r.text()).slice(0, 200)}`); return TEMPFAIL; }
  jobId = (await r.json()).id;
  say(`started, job ${jobId}${SRC.length ? ` (logs come back from ${SRC.join(' or ')})` : ''}`);
  writeFileSync(progress, `remote ${who}: started\n`);
  let lastOk = Date.now(), lastT = -1, st;
  for (;;) {
    await sleep(POLL_MS);
    try {
      const s = await call('GET', `/regress/run/${jobId}`);
      if (s.status === 404) { say('the host forgot the job (restarted?)'); return TEMPFAIL; }
      if (!s.ok) throw new Error(`status ${s.status}`);
      st = await s.json();
      lastOk = Date.now();
    } catch (e) {
      // a bridge that's gone (connection refused) is dropped sooner than a
      // slow or briefly unreachable one
      const gone = e.cause?.code === 'ECONNREFUSED' && Date.now() - lastOk > REFUSED_MS;
      if (gone || Date.now() - lastOk > DROP_MS) { say(`no answer for ${Math.round((Date.now() - lastOk) / 1000)} s: dropped (${e.cause?.code ?? e.message})`); return TEMPFAIL; }
      continue;
    }
    if (st.t_ms != null && st.t_ms !== lastT) { appendFileSync(progress, `t=${st.t_ms} ms (on ${who})\n`); lastT = st.t_ms; }
    if (st.state === 'done') break;
  }
  for (const l of st.out ?? []) console.log(`  [${who}] ${l}`);
  if (st.exit === 'build') { say('the host could not build the testbench'); await forget(); return TEMPFAIL; }
  // Its logs, here, where the runner looks for them
  writeFileSync(progress, `remote ${who}: fetching the logs\n`, { flag: 'a' });
  try {
    const d = await download('dash.log', `/regress/run/${jobId}/dash`);
    // no dash.log: the host couldn't run it (its setup, not the test); run it elsewhere
    if (!d.body) { say(`the host made no dash.log (${d.status}); giving the test back`); await forget(); return TEMPFAIL; }
    save(join(OUT, `${TEST}.dash.log`), d.body);
    const l = await download('log', `/regress/run/${jobId}/log`);
    rmSync(progress, { force: true });
    if (l.body) {
      if (LOGMODE === 'raw') save(progress, gunzipSync(l.body)); else save(`${progress}.gz`, l.body);
    }
    // A log replay's report (replay/run_replay.sh): the validator's verdict
    // comes from it, so without it the test fails as "did not finish".
    // Other tests have none (404). Its mismatches workbook is a nicety
    if (/^replay_/.test(TEST)) {
      const rep = await download('report', `/regress/run/${jobId}/report`);
      if (rep.body) save(join(OUT, `${TEST}.report.txt`), rep.body);
      else say(`no replay report (${rep.status})`);
      try {
        const mm = await download('mismatches', `/regress/run/${jobId}/mismatches`);
        if (mm.body) save(join(OUT, `${TEST}.mismatches.xlsx`), mm.body);
      } catch (e) { say(`no mismatches workbook (${e.code ?? e.message})`); }
    }
    // iverilog's waveform, where run_dashboard_tests.sh leaves it here
    // (a test whose waveform doesn't arrive still counts)
    if (SIM === 'iverilog') {
      try {
        const w = await download('waveform', `/regress/run/${jobId}/fst`);
        if (w.body) {
          mkdirSync(join(OUT, 'fst'), { recursive: true });
          save(join(OUT, 'fst', `${TEST}.fst`), w.body);
        }
      } catch (e) { say(`no waveform (${e.code ?? e.message})`); }
    }
  } catch (e) {
    // the test ran; only its logs didn't come back: run it again
    // elsewhere, but the host itself may be fine (the runner decides)
    say(`its logs wouldn't come back (${e.code ?? e.message}); giving the test back`);
    rmSync(join(OUT, `${TEST}.dash.log`), { force: true });
    await forget();
    return GIVEBACK;
  }
  await forget();
  say(`done, exit ${st.exit}`);
  return st.exit === 0 ? 0 : 1;
}

main().then(code => process.exit(code), e => { console.error(e); process.exit(TEMPFAIL); });
