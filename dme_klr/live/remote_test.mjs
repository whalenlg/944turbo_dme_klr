#!/usr/bin/env node
// ============================================================
//  remote_test.mjs — run one dashboard test on a regression host
//
//  Used by run_dashboard_parallel.sh and run_tests.py for the slots of
//  the hosts in $DMEKLR_REGRESS_HOSTS (see regress_host.mjs): sends the
//  test to that host's bridge, writes its progress to <out>/<test>.log
//  as "t=<ms> ms" lines (so the RUN REGRESSIONS panel's bars move), and
//  when it ends fetches <test>.dash.log and the whole log into <out>
//  (and, for iverilog, the waveform into <out>/fst/<test>.fst),
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
//  test back in the queue and stops using that host.
// ============================================================

import { readFileSync, writeFileSync, appendFileSync, rmSync, mkdirSync } from 'node:fs';
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
  for (const f of [progress, `${progress}.gz`, join(OUT, `${TEST}.dash.log`)]) rmSync(f, { force: true });
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
  say(`started, job ${jobId}`);
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
  try {
    const d = await call('GET', `/regress/run/${jobId}/dash`, null, 300_000);
    // no dash.log: the host couldn't run it (its setup, not the test); run it elsewhere
    if (!d.ok) { say('the host made no dash.log; giving the test back'); await forget(); return TEMPFAIL; }
    writeFileSync(join(OUT, `${TEST}.dash.log`), Buffer.from(await d.arrayBuffer()));
    const l = await call('GET', `/regress/run/${jobId}/log`, null, 300_000);
    rmSync(progress, { force: true });
    if (l.ok) {
      const gz = Buffer.from(await l.arrayBuffer());
      if (LOGMODE === 'raw') writeFileSync(progress, gunzipSync(gz)); else writeFileSync(`${progress}.gz`, gz);
    }
    // iverilog's waveform, where run_dashboard_tests.sh leaves it here
    // (a test whose waveform doesn't arrive still counts)
    if (SIM === 'iverilog') {
      try {
        const w = await call('GET', `/regress/run/${jobId}/fst`, null, 600_000);
        if (w.ok) {
          mkdirSync(join(OUT, 'fst'), { recursive: true });
          writeFileSync(join(OUT, 'fst', `${TEST}.fst`), Buffer.from(await w.arrayBuffer()));
        }
      } catch (e) { say(`no waveform (${e.cause?.code ?? e.message})`); }
    }
  } catch (e) {
    say(`dropped while sending the logs (${e.cause?.code ?? e.message})`);
    return TEMPFAIL;
  }
  await forget();
  say(`done, exit ${st.exit}`);
  return st.exit === 0 ? 0 : 1;
}

main().then(code => process.exit(code), e => { console.error(e); process.exit(TEMPFAIL); });
