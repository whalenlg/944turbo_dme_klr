#!/usr/bin/env node
// ============================================================
//  bridge.mjs — HTTP bridge between the live simulator and the
//  web dashboard. No npm dependencies (Node 18+).
//
//  Starts obj/dme_klr_live and exposes:
//    GET  /events     Server-Sent Events: every line the sim prints,
//                     replaying the whole run first so a page that
//                     (re)connects gets the full history
//    POST /cmd        text body, one sim command per line
//                     (run, pause, step dme 1, set rpm 3000, bp add dme 024E ...
//                      — see sim_main.cpp)
//    POST /restart    kill the sim and start a fresh one at t=0 (with
//                     the ROM images currently loaded)
//    POST /rom?cpu=dme|klr&name=<file.mem>[&reset=1]
//                     body = a $readmemh .mem image. Only while the sim is
//                     paused. Saved under obj/roms/<cpu>/, then loaded into
//                     the running sim (CPU keeps its PC and RAM), or with
//                     reset=1 the sim restarts at t=0 on the new image.
//                     The sim reports the result as SIM: [ROM] / [ERROR].
//    GET  /snapshots  JSON list of saved snapshots, newest first (see
//                     Snapshots below)
//    GET  /snapshots/<id>         everything in it: sim.json + manifest.json
//    GET  /snapshots/<id>/bundle  one-file download (.dmesnap: gzip'd JSON
//                                 holding every file of the snapshot)
//    POST /snapshots/<id>/load    restart the sim from that snapshot
//    POST /snapshots/upload       body = a .dmesnap; unpacked as a new snapshot
//    DELETE /snapshots/<id>
//    GET  /asm/dme    JSON disassembly listing (same data as the vcd.v /
//    GET  /asm/klr    klr_vcd.v asm_debug group): [{a,label,instr,ops,bytes}]
//                     (dme rows also carry num: operands as raw addresses;
//                     rows may carry desc from asm_full.json)
//
//  Each listing follows the image in that CPU's EPROM: whenever the sim
//  reports SIM: [ROM] dme|klr <path>, the image is matched (by content, then
//  by file name) to one with its own workbook, that workbook's tables are
//  brought up to date (dme_klr/asm_select.sh) and the listing is swapped.
//  The bridge then sends
//    SIM: [ASM] dme|klr <workbook> match=content|name|none
//  and the dashboard fetches /asm/<cpu> again. --dme-asm / --klr-asm pin a
//  listing.
//
//  Snapshots: the sim saves one on every warning (and on "save" via
//  /cmd) into <snapdir>/<id>/ and prints SIM: [SNAP] saved ... dir=.
//  The bridge then adds manifest.json (each EPROM image's SHA-256, file
//  name and disassembly workbook) and history.log.gz (the run's recent
//  output, so the charts show the lead-up after a load), and sends
//    SIM: [SNAP] ready id=<id> t_ns=<n> reason=warn|manual
//  Loading restarts the sim with +load=<dir> on the snapshot's own EPROM
//  images, replaying history.log.gz to the dashboard first.
//
//  Only listens on 127.0.0.1, and only pages from whalenlg.github.io,
//  localhost or 127.0.0.1 may use it (see ALLOWED below).
//
//  Usage:  node bridge.mjs [--port 8951] [--sim obj/dme_klr_live] [--snapdir <dir>]
//                          [--dme-asm <dir>] [--klr-asm <dir>]
//                          [--allow-origin <https://other.origin>]
// ============================================================
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, readdirSync, existsSync, mkdirSync, writeFileSync, rmSync, statSync, renameSync, cpSync, rmdirSync, watch } from 'node:fs';
import { createHash } from 'node:crypto';
import { gzipSync, gunzipSync } from 'node:zlib';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createInterface } from 'node:readline';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');

const arg = (name, dflt) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
};
const PORT    = +arg('port', 8951);
const SIM     = resolve(arg('sim', join(HERE, 'obj', 'dme_klr_live')));
const DME_ASM_PIN = arg('dme-asm', null);   // fixed DME listing; otherwise it follows the ROM
const DME_ASM = resolve(DME_ASM_PIN ?? join(REPO, 'dme', 'disassemble'));
const KLR_ASM_PIN = arg('klr-asm', null);
const KLR_ASM = resolve(KLR_ASM_PIN ?? join(REPO, 'klr', 'disassemble'));
const MAX_HISTORY = 500_000;   // lines kept for replay

// Lines the dashboard uses; the rest ($dumpvar notices, readmem
// warnings) stay on this terminal.
const FORWARD = /^(DME: |KLR: |SIM: |\[DS\]|\[PHASE\]|\[STATUS\])/;

let sim = null;
let history = [];
let simState = 'paused';                // from the sim's SIM: [STATE] lines
const roms = { dme: null, klr: null };  // from its SIM: [ROM] lines; kept across restarts
const clients = new Set();

function broadcast(line) {
  history.push(line);
  if (history.length > MAX_HISTORY) history = history.slice(-MAX_HISTORY / 2);
  const msg = `data: ${line}\n\n`;
  for (const res of clients) res.write(msg);
}

// load: { dir, history } to start from a snapshot (see loadSnapshot), or
// { test: { bin, runTo, id } } to run a regression test's build to the
// moment it warned (see loadTest)
function startSim(load = null) {
  if (!existsSync(SIM)) {
    console.error(`Simulator not found: ${SIM}\nBuild it with ./build_live.sh`);
    process.exit(1);
  }
  history = [];
  broadcast('SIM: [RESTART]');
  // The run up to the snapshot, so the charts show the lead-up. Sent
  // once the sim says the load worked; if it fails, the page shows the
  // error over a fresh t=0 run instead of the old run's numbers.
  let pending = load ? load.history : null;
  simState = 'paused';
  const test = load?.test;
  // A test build keeps the ROMs it was compiled with
  const romArgs = test ? [] : Object.entries(roms).filter(([, p]) => p).map(([cpu, p]) => `+${cpu}_rom=${p}`);
  const snapArgs = test ? ['+autosnap=0', `+runto=${test.runTo}`, `+runlabel=${test.id}`]
                        : [`+snapdir=${SNAP_DIR}`, ...(snapCfg.auto ? [] : ['+autosnap=0']), ...(snapCfg.break ? ['+breakonwarn=1'] : []),
                           ...(load ? [`+load=${load.dir}`] : [])];
  const bin = test?.bin ?? SIM;
  // Run from obj/ so the testbench's $writememh / sim.vcd land there
  sim = spawn(bin, ['+vcd=/dev/null', ...romArgs, ...snapArgs], { cwd: dirname(bin), stdio: ['pipe', 'pipe', 'pipe'] });
  const proc = sim;
  const onLine = line => {
    if (pending && /^SIM: \[SNAP\] loaded /.test(line)) {
      for (const h of pending) broadcast(h);
      pending = null;
    } else if (pending && /^SIM: \[ERROR\] load/.test(line)) {
      pending = null;
    }
    const st = line.match(/^SIM: \[STATE\] (\w+)/);
    if (st) simState = st[1];
    const rom = line.match(/^SIM: \[ROM\] (dme|klr) (.+)$/);
    if (rom) roms[rom[1]] = rom[2];
    const cfg = line.match(/^SIM: \[SNAPCFG\] auto=(\w+) break=(\w+)/);
    if (cfg) Object.assign(snapCfg, { auto: cfg[1] === 'on', break: cfg[2] === 'on' });
    const saved = line.match(/^SIM: \[SNAP\] saved t_ns=(\d+) reason=(\S+) dir=(.+)$/);
    if (saved) {
      if (FORWARD.test(line)) broadcast(line);
      finishSnapshot(saved[3], saved[1], saved[2]);
      return;
    }
    if (FORWARD.test(line)) broadcast(line);
    else if (!line.startsWith('-Info')) console.log(line);
    if (rom) followRom(rom[1], rom[2]);
  };
  createInterface({ input: proc.stdout }).on('line', onLine);
  createInterface({ input: proc.stderr }).on('line', onLine);
  proc.on('exit', code => {
    if (sim === proc) {
      sim = null;
      simState = 'exited';
      broadcast(`SIM: [EXIT] code=${code}`);
    }
  });
}

function restartSim(load = null) {
  if (sim) { const old = sim; sim = null; old.kill(); }
  startSim(load);
}

// Uploaded images live next to the sim so a restart can load them again
const ROM_DIR = join(dirname(SIM), 'roms');
const ROM_MAX = 1 << 20;   // a full 8 KB image is ~24 KB of text

// POST /rom: check, save, then load into the sim. Returns [status, text].
function loadRom(url, body) {
  const cpu = url.searchParams.get('cpu');
  const name = basename(url.searchParams.get('name') ?? '');
  if (cpu !== 'dme' && cpu !== 'klr') return [400, 'cpu must be dme or klr'];
  if (!/^[\w.+ -]+\.mem$/i.test(name)) return [400, 'ROM image must be a .mem file'];
  if (simState === 'running') return [409, 'pause the simulation before loading a ROM'];
  if (cpu === 'dme') {
    const klr = klrImageName(name, body);
    if (klr) return [400, `${name} is ${klr === name ? 'a KLR image' : `the KLR image ${klr}`}, not a DME image. `
                        + `Load it with the KLR LOAD .mem button, and pick a DME image (e.g. 28PIN_86DME.mem) for the DME.`];
  }
  const dir = join(ROM_DIR, cpu);
  mkdirSync(dir, { recursive: true });
  const path = join(dir, name);
  writeFileSync(path, body);
  console.log(`bridge: ${cpu} ROM ${name} -> ${path}${url.searchParams.get('reset') === '1' ? ' (restart)' : ''}`);
  if (url.searchParams.get('reset') === '1') {
    roms[cpu] = path;
    restartSim();
  } else if (!send(`rom ${cpu} ${path}`)) {
    return [409, 'simulator not running'];
  }
  return [204, ''];
}

function send(text) {
  if (!sim) return false;
  for (const line of text.split('\n').map(l => l.trim()).filter(Boolean)) sim.stdin.write(line + '\n');
  return true;
}

// ── Disassembly from the asm_debug hex tables ───────────────
// One line per address, each a 20-char ASCII field hex-encoded.
function hexStrings(file) {
  if (!existsSync(file)) return [];
  return readFileSync(file, 'utf8').split('\n').map(l => {
    const h = l.trim();
    let s = '';
    for (let i = 0; i + 1 < h.length; i += 2) s += String.fromCharCode(parseInt(h.slice(i, i + 2), 16));
    return s.trim();
  });
}
function listing(dir, opsFile, numFile) {
  const label = hexStrings(join(dir, 'test_sim.hex'));
  const instr = hexStrings(join(dir, 'asm_instr.hex'));
  const ops   = hexStrings(join(dir, opsFile));
  const bytes = hexStrings(join(dir, 'asm_opcode_ins.hex'));
  // DME operands with symbols replaced by raw addresses (0x35, 0x23.2)
  const num   = numFile ? hexStrings(join(dir, numFile)) : [];
  const out = [];
  for (let a = 0; a < instr.length; a++)
    if (instr[a]) out.push({ a, label: label[a] || '', instr: instr[a], ops: ops[a] || '', bytes: bytes[a] || '',
                                ...(numFile ? { num: num[a] || '' } : {}) });
  return out;
}
// The hex tables cut labels and operands at 20 characters; asm_full.json (written by
// asm_full.py from the same spreadsheets) has them in full, plus the
// spreadsheet's descriptions. Used only where it agrees with the hex table.
const FULL = join(HERE, 'asm_full.json');
const readJson = f => { try { return JSON.parse(readFileSync(f, 'utf8')); } catch { return null; } };
function withFull(rows, full) {
  if (full) for (const r of rows) {
    const e = full[r.a];
    if (!e || e.ops.slice(0, 20).trim() !== r.ops) continue;
    r.ops = e.ops;
    if (e.label && e.label.slice(0, 20).trim() === r.label) r.label = e.label;
    if (e.num != null && 'num' in r) r.num = e.num;
    if (e.desc) r.desc = e.desc;
  }
  return rows;
}
// A table directory made by asm_select.sh carries its own asm_full.json
const CPU_ASM = {
  dme: { pin: DME_ASM_PIN, dir: DME_ASM, ops: 'asm_operand_mapped.hex', num: 'asm_operands_numeric.hex' },
  klr: { pin: KLR_ASM_PIN, dir: KLR_ASM, ops: 'asm_operands.hex' },
};
const cpuListing = (cpu, dir) => withFull(listing(dir, CPU_ASM[cpu].ops, CPU_ASM[cpu].num),
                                          (readJson(join(dir, 'asm_full.json')) ?? readJson(FULL))?.[cpu]);
const ASM = { dme: cpuListing('dme', DME_ASM), klr: cpuListing('klr', KLR_ASM) };

// ── Listings that follow the loaded images ──────────────────
// The images that have a workbook (dme_klr/asm_select.sh's table)
const IMAGES = { dme: join(REPO, 'bin_images', 'dme'), klr: join(REPO, 'bin_images', 'klr') };
const WORKBOOK = {
  dme: {
    '28PIN_DME_PERFORMANCE.mem': 'disassembleperformance.xlsx',
    '28PIN_86DME.mem':           'disassemble1986.xlsx',
    '89DME_951pin.mem':          'disassemble1989.xlsx',
  },
  klr: {
    '87KLR_951.mem': '87KLR951.xlsx',
    '86KLR_951.mem': '86KLR951.xlsx',
    '89KLR_951.mem': '89KLR951.xlsx',
  },
};
const ASM_SELECT = join(HERE, '..', 'asm_select.sh');

// Bytes of a .mem image as the sim loads it (see sim_main.cpp loadRom)
function memBytes(file) {
  try { return parseMem(readFileSync(file, 'utf8')); } catch { return null; }
}
function parseMem(text) {
  text = text.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*$/gm, ' ');
  const img = Buffer.alloc(8192, 0xFF);
  let addr = 0;
  for (const tok of text.split(/\s+/).filter(Boolean)) {
    const v = parseInt(tok.replace(/^@/, '').replace(/_/g, ''), 16);
    if (Number.isNaN(v)) return null;
    if (tok[0] === '@') addr = v;
    else if (addr < img.length) img[addr++] = v;
  }
  return img;
}
const knownBytes = new Map();
function knownImage(cpu, path) {
  const img = memBytes(path);
  const known = Object.keys(WORKBOOK[cpu]);
  if (img) for (const name of known) {
    const k = `${cpu}/${name}`;
    if (!knownBytes.has(k)) knownBytes.set(k, memBytes(join(IMAGES[cpu], name)));
    if (knownBytes.get(k)?.equals(img)) return { name, match: 'content' };
  }
  const name = known.find(n => n.toLowerCase() === basename(path).toLowerCase());
  return name ? { name, match: 'name' } : null;
}

// The KLR images in bin_images/klr. A DME upload that is one of them (by
// content or by file name) is refused: the 8051 would run 8048 code.
const KLR_IMAGES = join(REPO, 'bin_images', 'klr');
let klrKnown = null;
function klrImageName(name, text) {
  klrKnown ??= (() => { try { return readdirSync(KLR_IMAGES).filter(f => /\.mem$/i.test(f)); } catch { return []; } })()
    .map(f => ({ f, img: memBytes(join(KLR_IMAGES, f)) }));
  const byName = klrKnown.find(k => k.f.toLowerCase() === name.toLowerCase());
  if (byName) return byName.f;
  const img = parseMem(text);
  return img ? klrKnown.find(k => k.img?.equals(img))?.f ?? null : null;
}

// Runs on every SIM: [ROM] line (start, restart, rom command), so an upload
// that reuses a file name with new contents is caught too.
function followRom(cpu, path) {
  const { pin, dir: dflt } = CPU_ASM[cpu];
  if (pin) return;
  const CPU = cpu.toUpperCase();
  const img = knownImage(cpu, path);
  let dir = dflt, workbook = '-';
  if (img) {
    // Same helper as the run scripts: regenerates stale workbooks/tables
    const r = spawnSync('bash', ['-c', `source "$1" && ${cpu}_asm_select _arr >&2 && printf %s "$${CPU}_ASM_SEL"`, '_', ASM_SELECT],
                        { env: { ...process.env, [`${CPU}_ROM_FILE`]: img.name, [`${CPU}_ASM_DIR`]: '' }, encoding: 'utf8',
                          stdio: ['ignore', 'pipe', 'inherit'] });
    if (r.status === 0 && r.stdout.trim()) {
      dir = resolve(r.stdout.trim());
      workbook = WORKBOOK[cpu][img.name];
    } else {
      console.error(`bridge: couldn't prepare the ${CPU} tables for ${img.name}; keeping ${dflt}`);
    }
  }
  ASM[cpu] = cpuListing(cpu, dir);
  console.log(`bridge: ${CPU} listing for ${basename(path)}: ${dir} (${img ? `${img.name}, matched by ${img.match}` : 'unknown image'}, ${ASM[cpu].length} lines)`);
  broadcast(`SIM: [ASM] ${cpu} ${workbook} match=${img?.match ?? 'none'}`);
}

// ── Snapshots ────────────────────────────────────────────────
// Next to the other run output (run_dashboard_tests.sh's dash_logs), out
// of the repo and safe from a clean of obj/: ../tmp/dme_klr/snapshots
// beside the checkout. --snapdir <dir> puts them elsewhere.
const SNAP_DIR = resolve(arg('snapdir', join(REPO, '..', 'tmp', 'dme_klr', 'snapshots')));
mkdirSync(SNAP_DIR, { recursive: true });
// Snapshots from before they moved out of obj/
{
  const old = join(dirname(SIM), 'snapshots');
  let ids = [];
  try { ids = readdirSync(old); } catch { /* none */ }
  for (const id of ids) {
    const to = join(SNAP_DIR, id);
    if (existsSync(to)) continue;
    try { renameSync(join(old, id), to); }
    catch { cpSync(join(old, id), to, { recursive: true }); rmSync(join(old, id), { recursive: true, force: true }); }
  }
  if (ids.length) { try { rmdirSync(old); } catch { /* not empty: left as it is */ } }
}
const SNAP_HISTORY = 60_000;        // lines of the run kept with each snapshot
const SNAP_UPLOAD_MAX = 64 << 20;
const snapCfg = { auto: true, break: false };   // from SIM: [SNAPCFG]; kept across restarts
const ROM_BYTES = { dme: 8192, klr: 4096 };
const snapId = id => /^[\w.+-]+$/.test(id ?? '') && !id.startsWith('.') ? id : null;
const snapPath = id => join(SNAP_DIR, id);

// The .mem image the sim wrote for each CPU (rom/<cpu>/<name>.mem)
function snapRoms(dir) {
  const out = {};
  for (const cpu of ['dme', 'klr']) {
    try {
      const f = readdirSync(join(dir, 'rom', cpu)).find(n => /\.mem$/i.test(n));
      if (f) out[cpu] = join(dir, 'rom', cpu, f);
    } catch { /* none */ }
  }
  return out;
}

// After the sim writes a snapshot: identify the ROMs and keep the run so far
function finishSnapshot(dir, tNs, reason) {
  const id = basename(dir);
  try {
    const romInfo = {};
    for (const [cpu, file] of Object.entries(snapRoms(dir))) {
      const img = memBytes(file)?.subarray(0, ROM_BYTES[cpu]);
      const known = knownImage(cpu, file);
      romInfo[cpu] = {
        name: basename(file),
        sha256: img ? createHash('sha256').update(img).digest('hex') : null,
        workbook: known ? WORKBOOK[cpu][known.name] : null,
        image: known?.name ?? null,
        match: known?.match ?? 'none',
      };
    }
    const lines = history.slice(-SNAP_HISTORY).filter(l => !l.startsWith('SIM: [RESTART]'));
    writeFileSync(join(dir, 'history.log.gz'), gzipSync(lines.join('\n') + '\n'));
    writeFileSync(join(dir, 'manifest.json'), JSON.stringify({ id, roms: romInfo, history_lines: lines.length }, null, 1));
  } catch (e) {
    console.error(`bridge: snapshot ${id}: ${e.message}`);
  }
  broadcast(`SIM: [SNAP] ready id=${id} t_ns=${tNs} reason=${reason}`);
}

function snapInfo(id, full = false) {
  const dir = snapPath(id);
  const req = readJson(join(dir, 'request.json'));
  if (req?.format === 'dme-klr-test-snapshot' && !existsSync(join(dir, 'state.bin'))) {
    if (full) return { id, kind: 'test', ...req, built: testBuilt(req) };
    const roms = {};
    for (const cpu of ['dme', 'klr']) roms[cpu] = { name: basename(req.roms?.[cpu] ?? ''), sha256: null, workbook: null };
    return { id, kind: 'test', test: req.test, t_ns: (req.t_ms ?? 0) * 1e6, created: req.created, reason: req.reason === 'fail' ? 'fail' : 'test',
             label: req.test, trigger: `${req.test}: ${req.trigger}`, pc: null, inputs: null, roms, bytes: 0 };
  }
  const sj = readJson(join(dir, 'sim.json'));
  if (!sj || !existsSync(join(dir, 'state.bin'))) return null;
  const man = readJson(join(dir, 'manifest.json')) ?? {};
  if (full) return { id, ...sj, manifest: man };
  const roms = {};
  for (const cpu of ['dme', 'klr'])
    roms[cpu] = { name: man.roms?.[cpu]?.name ?? basename(sj.roms?.[cpu]?.path ?? ''), sha256: man.roms?.[cpu]?.sha256 ?? null,
                  workbook: man.roms?.[cpu]?.workbook ?? null, crc32: sj.roms?.[cpu]?.crc32 ?? null };
  return { id, t_ns: sj.t_ns, created: sj.created, reason: sj.reason, label: sj.label, trigger: sj.trigger,
           pc: sj.pc, inputs: sj.inputs, roms, bytes: statSync(join(dir, 'state.bin')).size };
}

function listSnapshots() {
  let ids = [];
  try { ids = readdirSync(SNAP_DIR).filter(snapId); } catch { return []; }
  return ids.map(id => snapInfo(id)).filter(Boolean).sort((a, b) => (b.created ?? '').localeCompare(a.created ?? '') || b.id.localeCompare(a.id));
}

// Restart the sim from a snapshot, on its own EPROM images
function loadSnapshot(id) {
  const dir = snapPath(id);
  if (!existsSync(join(dir, 'state.bin')) && existsSync(join(dir, 'request.json'))) return loadTest(id);
  if (!existsSync(join(dir, 'state.bin'))) return [404, `no snapshot ${id}`];
  // Its EPROM images become the loaded ones (copied next to uploaded
  // images, so later restarts still find them if the snapshot is deleted)
  for (const [cpu, file] of Object.entries(snapRoms(dir))) {
    mkdirSync(join(ROM_DIR, cpu), { recursive: true });
    roms[cpu] = join(ROM_DIR, cpu, basename(file));
    writeFileSync(roms[cpu], readFileSync(file));
  }
  let lines = [];
  try { lines = gunzipSync(readFileSync(join(dir, 'history.log.gz'))).toString('utf8').split('\n').filter(Boolean); } catch { /* none */ }
  console.log(`bridge: loading snapshot ${id} (${lines.length} history lines)`);
  restartSim({ dir, history: lines });
  return [204, ''];
}

// ── Regression-test snapshots (test_snap.py) ─────────────────
// A test's warning is a request.json: which test, its -D flags and ROMs,
// and the time. LOAD builds the test with the debugger's hooks
// (build_live.sh --test, in obj/tests/<test>/, kept for next time) and
// runs it there, paused. Progress goes out as SIM: [SNAP] building lines.
const TEST_SOURCES = [join(HERE, 'sim_main.cpp'), join(HERE, 'snapshot.h'), join(HERE, 'build_live.sh'),
                      join(REPO, 'dme_klr', 'bench', 'verilog', 'dme_klr_dashboard_tb.v')];
const testDir = req => join(dirname(SIM), 'tests', req.test);
const testStamp = req => JSON.stringify({ defines: req.defines, roms: req.roms, interval: req.interval_ms, script: req.script });
function testBuilt(req) {
  const bin = join(testDir(req), 'dme_klr_live');
  try {
    if (readFileSync(join(testDir(req), 'build.stamp'), 'utf8') !== testStamp(req)) return false;
    const t = statSync(bin).mtimeMs;
    return TEST_SOURCES.every(f => { try { return statSync(f).mtimeMs <= t; } catch { return true; } });
  } catch { return false; }
}
let testBuild = null;   // the build in progress: { id, proc }
// Regression runs add requests while the page is open: tell it to refetch
try {
  let t = null;
  watch(SNAP_DIR, () => { clearTimeout(t); t = setTimeout(() => broadcast('SIM: [SNAP] ready id=- t_ns=0 reason=scan'), 500); });
} catch { /* no fs.watch here: the list refreshes on the next snapshot */ }
function loadTest(id) {
  const req = readJson(join(snapPath(id), 'request.json'));
  if (!snapId(req?.test ?? '') || !Array.isArray(req.defines)) return [400, `snapshot ${id}: bad request.json`];
  if (testBuild) return [409, `already building ${testBuild.id}`];
  const run = () => {
    console.log(`bridge: running test ${req.test} to ${req.t_ns / 1e6} ms`);
    restartSim({ test: { bin: join(testDir(req), 'dme_klr_live'), runTo: req.t_ns, id } });
  };
  if (testBuilt(req)) { run(); return [204, '']; }
  // ROM images as the test ran them; the script finds its own -D flags
  const env = { ...process.env, DASH_INTERVAL_MS: String(req.interval_ms ?? 100) };
  for (const cpu of ['dme', 'klr']) {
    const p = req.roms?.[cpu];
    if (p) { env[`${cpu.toUpperCase()}_ROM_DIR`] = dirname(p) + '/'; env[`${cpu.toUpperCase()}_ROM_FILE`] = basename(p); }
  }
  const args = [join(HERE, 'build_live.sh'), '--test', req.test, ...(req.script && existsSync(req.script) ? ['--script', req.script] : [])];
  broadcast(`SIM: [SNAP] building id=${id} test=${req.test} starting (a few minutes the first time)`);
  const proc = spawn('bash', args, { env, stdio: ['ignore', 'pipe', 'pipe'] });
  testBuild = { id, proc };
  const tail = [];
  const onLine = line => {
    tail.push(line); if (tail.length > 20) tail.shift();
    if (/^(gen_state|Built|- V|%Error|  [DK][MK][ER]|.*error:)/.test(line))
      broadcast(`SIM: [SNAP] building id=${id} test=${req.test} ${line.trim().slice(0, 200)}`);
  };
  createInterface({ input: proc.stdout }).on('line', onLine);
  createInterface({ input: proc.stderr }).on('line', onLine);
  proc.on('exit', code => {
    testBuild = null;
    if (code === 0) {
      writeFileSync(join(testDir(req), 'build.stamp'), testStamp(req));
      broadcast(`SIM: [SNAP] building id=${id} test=${req.test} done`);
      run();
    } else {
      const why = tail.filter(l => /error/i.test(l)).slice(-2).join(' | ') || tail.slice(-1)[0] || `exit ${code}`;
      broadcast(`SIM: [SNAP] building id=${id} test=${req.test} failed`);
      broadcast(`SIM: [ERROR] building test ${req.test} failed: ${why.slice(0, 300)}`);
    }
  });
  return [202, ''];
}

// Every file of a snapshot, base64, in one gzip'd JSON
function walk(dir, rel = '') {
  return readdirSync(join(dir, rel), { withFileTypes: true }).flatMap(e =>
    e.isDirectory() ? walk(dir, join(rel, e.name)) : [join(rel, e.name)]);
}
function snapBundle(id) {
  const dir = snapPath(id);
  const files = {};
  for (const f of walk(dir)) files[f.split(/[\\/]/).join('/')] = readFileSync(join(dir, f)).toString('base64');
  return gzipSync(JSON.stringify({ format: 'dme-klr-live-snapshot-bundle', version: 1, id, files }));
}
function unpackBundle(buf) {
  let b;
  try { b = JSON.parse(gunzipSync(buf).toString('utf8')); } catch { return [400, 'not a .dmesnap file'] }
  if (b?.format !== 'dme-klr-live-snapshot-bundle' || !((b.files?.['state.bin'] && b.files?.['sim.json']) || b.files?.['request.json']))
    return [400, 'not a .dmesnap file'];
  const base = snapId(b.id) ?? 'uploaded';
  let id = base;
  for (let n = 2; existsSync(snapPath(id)); n++) id = `${base}-${n}`;
  const dir = snapPath(id);
  for (const [rel, data] of Object.entries(b.files)) {
    const parts = rel.split('/');
    if (parts.some(p => !p || p === '.' || p === '..') || !parts.every(p => /^[\w.+ -]+$/.test(p))) return [400, `bad file name in bundle: ${rel}`];
  }
  for (const [rel, data] of Object.entries(b.files)) {
    mkdirSync(dirname(join(dir, rel)), { recursive: true });
    writeFileSync(join(dir, rel), Buffer.from(data, 'base64'));
  }
  console.log(`bridge: uploaded snapshot -> ${dir}`);
  broadcast(`SIM: [SNAP] ready id=${id} t_ns=${readJson(join(dir, 'sim.json'))?.t_ns ?? readJson(join(dir, 'request.json'))?.t_ns ?? 0} reason=upload`);
  return [200, JSON.stringify({ id })];
}

// ── HTTP ─────────────────────────────────────────────────────
// Only these page origins may use the bridge: the published dashboard
// and a dev server on this machine (--allow-origin adds more). Requests
// from any other page are refused with 403 *before* doing anything,
// since a plain-text POST from another site would otherwise still run
// its command even though the browser hides the response. Requests
// without an Origin header (curl, a terminal) are allowed.
const ALLOWED = [
  /^https:\/\/whalenlg\.github\.io$/,
  /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
  ...process.argv.flatMap((a, i) => a === '--allow-origin' && process.argv[i + 1] ? [process.argv[i + 1]] : []),
];
const originOk = o => !o || ALLOWED.some(a => typeof a === 'string' ? a === o : a.test(o));
const cors = o => o ? {
  'Access-Control-Allow-Origin': o,
  'Vary': 'Origin',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  // Lets the https gh-pages dashboard reach this local server in Chrome
  'Access-Control-Allow-Private-Network': 'true',
} : {};

createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  const origin = req.headers.origin;
  if (!originOk(origin)) {
    console.log(`bridge: refused ${req.method} ${url.pathname} from ${origin}`);
    res.writeHead(403);
    return res.end('origin not allowed');
  }
  const CORS = cors(origin);
  if (req.method === 'OPTIONS') { res.writeHead(204, CORS); return res.end(); }

  if (req.method === 'GET' && url.pathname === '/events') {
    res.writeHead(200, { ...CORS, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
    res.write(history.map(l => `data: ${l}\n\n`).join(''));
    clients.add(res);
    req.on('close', () => clients.delete(res));
    return;
  }
  // ── /snapshots ─────────────────────────────────────────────
  const snap = url.pathname.match(/^\/snapshots(?:\/([^/]+))?(?:\/(bundle|load))?$/);
  if (snap) {
    const [, rawId, action] = snap;
    const json = (code, body) => { res.writeHead(code, { ...CORS, 'Content-Type': 'application/json' }); res.end(JSON.stringify(body)); };
    const text = (code, body) => { res.writeHead(code, CORS); res.end(body); };
    if (req.method === 'GET' && !rawId) return json(200, listSnapshots());
    if (req.method === 'POST' && rawId === 'upload' && !action) {
      const chunks = [];
      let size = 0;
      req.on('data', d => { chunks.push(d); size += d.length; if (size > SNAP_UPLOAD_MAX) req.destroy(); });
      req.on('end', () => {
        const [code, body] = unpackBundle(Buffer.concat(chunks));
        res.writeHead(code, { ...CORS, 'Content-Type': code === 200 ? 'application/json' : 'text/plain' });
        res.end(body);
      });
      return;
    }
    const id = snapId(rawId && decodeURIComponent(rawId));
    if (!id || !existsSync(snapPath(id))) return text(404, `no snapshot ${rawId}`);
    if (req.method === 'GET' && !action) {
      const info = snapInfo(id, true);
      return info ? json(200, info) : text(404, `snapshot ${id} is incomplete`);
    }
    if (req.method === 'GET' && action === 'bundle') {
      res.writeHead(200, { ...CORS, 'Content-Type': 'application/octet-stream',
                           'Content-Disposition': `attachment; filename="${id}.dmesnap"` });
      return res.end(snapBundle(id));
    }
    if (req.method === 'POST' && action === 'load') {
      const [code, body] = loadSnapshot(id);
      return text(code, body);
    }
    if (req.method === 'DELETE' && !action) {
      rmSync(snapPath(id), { recursive: true, force: true });
      broadcast(`SIM: [SNAP] deleted id=${id}`);
      return text(204, '');
    }
    return text(405, 'method not allowed');
  }
  if (req.method === 'GET' && url.pathname.startsWith('/asm/')) {
    const cpu = url.pathname.slice(5);
    if (!ASM[cpu]) { res.writeHead(404, CORS); return res.end(); }
    res.writeHead(200, { ...CORS, 'Content-Type': 'application/json' });
    return res.end(JSON.stringify(ASM[cpu]));
  }
  if (req.method === 'POST' && (url.pathname === '/cmd' || url.pathname === '/restart' || url.pathname === '/rom')) {
    let body = '';
    const max = url.pathname === '/rom' ? ROM_MAX : 1e5;
    req.on('data', d => { body += d; if (body.length > max) req.destroy(); });
    req.on('end', () => {
      if (url.pathname === '/rom') {
        const [code, text] = loadRom(url, body);
        res.writeHead(code, CORS);
        return res.end(text);
      }
      if (url.pathname === '/restart') {
        restartSim();
      } else if (!send(body)) {
        res.writeHead(409, CORS);
        return res.end('simulator not running');
      }
      res.writeHead(204, CORS);
      res.end();
    });
    return;
  }
  res.writeHead(404, CORS);
  res.end();
}).listen(PORT, '127.0.0.1', () => {
  console.log(`bridge: http://127.0.0.1:${PORT}  sim=${SIM}`);
  console.log(`bridge: asm listings dme=${ASM.dme.length} klr=${ASM.klr.length} lines`);
  startSim();
});

process.on('SIGINT', () => { if (sim) sim.kill(); process.exit(0); });
