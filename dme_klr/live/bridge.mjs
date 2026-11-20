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
//    POST /rom?cpu=dme|klr&name=<file.mem|.bin|.hex>[&reset=1]
//                     body = a $readmemh .mem image, a raw binary (.bin) or
//                     an Intel HEX file (saved as <name>.mem). Only while the sim is
//                     paused. Saved under obj/roms/<cpu>/, then loaded into
//                     the running sim (CPU keeps its PC and RAM), or with
//                     reset=1 the sim restarts at t=0 on the new image.
//                     The sim reports the result as SIM: [ROM] / [ERROR].
//    POST /patch?cpu=dme|klr   body {"addr": n, "bytes": [n, ...]} or {"revert": true}:
//                     edit bytes of the image in that EPROM (the code windows'
//                     hex column), or put back the image as it was loaded.
//                     Only while paused. See Byte edits below.
//    GET  /edits/dme|klr[?name=<file>]  what an edited image changed (the
//                     loaded one, or one by file name): {name, base, bytes,
//                     places, text}; text lists each place's code before and after
//    POST /edits/dme|klr/save  {name, from?, use?}: keep an edited image in
//                     bin_images/<cpu>/edited/<name>/: <name>.mem, <name>.bin and
//                     its own workbook <name>.xlsx (see saveEdited)
//    GET  /image/dme|klr.bin[?name=<file>]  an image as a raw binary for an
//                     EPROM programmer (8192 / 4096 bytes; default the loaded one)
//    GET|POST /setups, DELETE /setups/<name>, POST /setups/<name>/load[?reset=1]
//                     image setups: named DME + KLR pairs (see Image setups);
//                     a change is sent as SIM: [SETUPS] changed
//    GET  /snapshots  JSON list of saved snapshots, newest first (see
//                     Snapshots below)
//    GET  /snapshots/<id>         everything in it: sim.json + manifest.json
//    GET  /snapshots/<id>/bundle  one-file download (.dmesnap: gzip'd JSON
//                                 holding every file of the snapshot)
//    POST /snapshots/<id>/load    restart the sim from that snapshot
//    POST /snapshots/upload       body = a .dmesnap; unpacked as a new snapshot
//    POST /snapshots/test         body = {test, ms, label}: a regression test's run to that time
//    DELETE /snapshots/<id>
//    GET  /asm/dme    JSON disassembly listing (same data as the vcd.v /
//    GET  /asm/klr    klr_vcd.v asm_debug group): [{a,label,instr,ops,bytes}]
//                     (dme rows also carry num: operands as raw addresses;
//                     rows may carry desc from asm_full.json)
//    GET  /maps/dme[?sha=<hash>|?name=<file>]  graphs of a DME image's maps
//                     and tables: the loaded image's, or the one with that
//                     content hash (a dash.log's DME: [ROM] line, see
//                     rom_stamp.py) or file name (a full sim log's "DME: ROM
//                     loaded from" line); found in bin_images/dme or the
//                     uploaded images, drawn if new
//                     {status: none|generating|ready|error|unknown, sha, loaded,
//                      rom, error, maps: {<n>: {file, addr, dim, bytes}}, tables: {<addr>: {...}}}
//    GET  /maps/dme/<sha>/<file>.png   one graph
//    GET  /runall, POST /runall/start, POST /runall/stop
//                     the dashboard's RUN REGRESSIONS panel: runs dme_klr/run_all.sh
//                     (lite package: run_tests.py) with the page's options
//                     and reports each test's progress (runall.mjs)
//    GET  /maps/klr[?sha=<hash>|?name=<file>], /maps/klr/<sha>/<file>.png   the same for
//                     the KLR image (klr_map_graphs.py; tables only, keyed
//                     by address: 0C00, 0B00, 0992, 0A00, 0925, ...)
//    GET  /logs       the .dash.log files in each ROM pair's folder,
//                     $DMEKLR_TMP/dme_klr/<rom>/v_dash_logs and dash_logs
//                     (the regression runs' output; logdirs.mjs), and in
//                     the folders from before those (rom: null), newest
//                     first: [{rom, dir, name, size, mtime}] (the
//                     dashboard's LOAD LOG list)
//    GET  /logs/<rom>/<dir>/<name>.dash.log   one of them, as text
//    GET  /logs/<dir>/<name>.dash.log         one in the older folders
//
//  Map graphs: map_graphs.py draws every numbered map and directly
//  addressed table of the DME image into <mapcache>/<sha>/, keyed by the
//  SHA-256 of the image's contents, so they are drawn once per image and
//  again only when its contents change. It runs on every SIM: [ROM] dme
//  line; a cached image takes a fraction of a second. When the graphs are
//  ready the bridge sends SIM: [MAPS] dme ready <sha>. Needs python3 with
//  matplotlib.
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
//  Byte edits: POST /patch writes the loaded image with the edits applied to
//  obj/roms/<cpu>/patched/<name>.patch-<hash>.mem (named by its contents)
//  and swaps it in with the sim's rom command, so the CPU keeps its PC and
//  RAM and runs the edited code from the next instruction. Edits add up
//  (each one is applied over the earlier ones), stay through RESTART and
//  are dropped when another image is loaded. The listing stays the one for
//  the image as loaded, decoded again where bytes were edited (disasm.mjs):
//  edited rows carry patched: true and orig (the bytes as loaded). The
//  bridge then sends SIM: [ASM] ... patched=<bytes edited>, with saved=<name>.mem
//  once those edits are kept with SAVE AS.
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
//  Listens only on 127.0.0.1 (unless --listen, below), and only pages
//  from whalenlg.github.io, localhost or 127.0.0.1 may use it (see
//  ALLOWED below).
//
//  Regression host: with --listen <addr> (e.g. 0.0.0.0) and --token <secret>
//  another machine's RUN REGRESSIONS panel can send tests here
//  (regress_host.mjs: /regress/*). Requests from other machines reach
//  only those, need the token, and must come from a LAN address.
//
//  Usage:  node bridge.mjs [--port 8951] [--sim obj/dme_klr_live] [--snapdir <dir>]
//                          [--listen <addr> --token <secret>]
//                          [--dme-asm <dir>] [--klr-asm <dir>] [--mapcache <dir>]
//                          [--allow-origin <https://other.origin>]
// ============================================================

// -h / --help: print the header comment above and exit before anything runs.
if (process.argv.slice(2).some(a => a === '-h' || a === '--help')) {
  // (readFileSync is imported below; import declarations are hoisted.)
  const lines = readFileSync(new URL(import.meta.url), 'utf8').split('\n').slice(1);
  const end = lines.findIndex(l => !l.startsWith('//'));
  console.log(lines.slice(0, end).filter(l => !l.startsWith('// ===='))
    .map(l => l.replace(/^\/\/ {0,2}/, '')).join('\n').trimEnd());
  process.exit(0);
}

import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, readdirSync, existsSync, mkdirSync, writeFileSync, rmSync, statSync, renameSync, cpSync, rmdirSync, watch } from 'node:fs';
import { createHash } from 'node:crypto';
import { gzipSync, gunzipSync } from 'node:zlib';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createInterface } from 'node:readline';
import { makeRunAll } from './runall.mjs';
import { makeRegressHost, tokenOk, lanAddress, loopback } from './regress_host.mjs';
import { romVariants } from './logdirs.mjs';
import { patchListing, rowBytes } from './disasm.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');

const arg = (name, dflt) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
};
const PORT    = +arg('port', 8951);
// Windows (MSYS2) builds are dme_klr_live.exe; --sim may leave the .exe off
const EXE = process.platform === 'win32' ? '.exe' : '';
const withExe = p => (EXE && !p.toLowerCase().endsWith(EXE) && !existsSync(p) ? p + EXE : p);
const SIM     = withExe(resolve(arg('sim', join(HERE, 'obj', 'dme_klr_live'))));
const DME_ASM_PIN = arg('dme-asm', null);   // fixed DME listing; otherwise it follows the ROM
const DME_ASM = resolve(DME_ASM_PIN ?? join(REPO, 'dme', 'disassemble'));
const KLR_ASM_PIN = arg('klr-asm', null);
const KLR_ASM = resolve(KLR_ASM_PIN ?? join(REPO, 'klr', 'disassemble'));
// No VCD: the sim gets the null device as its file (NUL on Windows)
const DEVNULL = process.platform === 'win32' ? 'NUL' : '/dev/null';
// The Python to run the helper scripts with: $PYTHON, else the first of
// python3 / python / py that runs. (On Windows a python.org install has
// python and py but no python3, and "python3" may be the Microsoft Store
// stub, which only prints a message.)
const PY = (() => {
  if (process.env.PYTHON) return process.env.PYTHON;
  for (const c of ['python3', 'python', 'py']) {
    const r = spawnSync(c, ['-c', 'import sys; print(sys.version_info[0])'], { encoding: 'utf8' });
    if (r.status === 0 && r.stdout.trim() === '3') return c;
  }
  return 'python3';
})();
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
// { test: { bin, runTo, id, args } } to run a regression test's build to
// the moment it warned (see loadTest)
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
  // (a shared test build gets them, and the test's options, as test.args)
  const romArgs = test ? (test.args ?? []) : Object.entries(roms).filter(([, p]) => p).map(([cpu, p]) => `+${cpu}_rom=${p}`);
  const snapArgs = test ? ['+autosnap=0', `+runto=${test.runTo}`, `+runlabel=${test.id}`]
                        : [`+snapdir=${SNAP_DIR}`, ...(snapCfg.auto ? [] : ['+autosnap=0']), ...(snapCfg.break ? ['+breakonwarn=1'] : []),
                           ...(load ? [`+load=${load.dir}`] : [])];
  if (dashMs) snapArgs.push(`+dash_ms=${dashMs}`);
  if (!test && serCfg.tester) snapArgs.push(`+ser_tester=${serCfg.tester}`);
  if (!test && serCfg.peek !== 0x37) snapArgs.push(`+ser_peek=${serCfg.peek.toString(16)}`);
  // 26h / 28h writes (ser_tester bit 1): +ser_w26 / +ser_w28 turn that bit on
  if (!test && (serCfg.tester & 2)) snapArgs.push(`+ser_w26=${serCfg.w26.toString(16)}`, `+ser_w28=${serCfg.w28.toString(16)}`);
  // The breakpoints set before a LOAD carry over (sim_main adds them once
  // the snapshot is in place)
  const keep = [...bpNow.dme.map(a => `dme:${a}`), ...bpNow.klr.map(a => `klr:${a}`)];
  if (load && keep.length) snapArgs.push(`+bps=${keep.join(',')}`);
  if (!load) bpNow = { dme: [], klr: [] };   // a plain restart starts without any
  const bin = test?.bin ?? SIM;
  // Run from obj/ so the testbench's $writememh / sim.vcd land there
  sim = spawn(bin, [`+vcd=${DEVNULL}`, ...romArgs, ...snapArgs], { cwd: dirname(bin), stdio: ['pipe', 'pipe', 'pipe'] });
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
    // A relative path (the lite package's build) is from the sim's folder
    if (rom) { rom[2] = resolve(dirname(bin), rom[2]); roms[rom[1]] = rom[2]; }
    const bp = line.match(/^SIM: \[BP\] dme=(\S*) klr=(\S*)/);
    if (bp && proc === sim) bpNow = { dme: bp[1].split(',').filter(Boolean), klr: bp[2].split(',').filter(Boolean) };
    const cfg = line.match(/^SIM: \[SNAPCFG\] auto=(\w+) break=(\w+)/);
    if (cfg) Object.assign(snapCfg, { auto: cfg[1] === 'on', break: cfg[2] === 'on' });
    const iv = line.match(/^SIM: \[INTERVAL\] ms=(\d+) default=(\d+)/);
    if (iv && proc === sim) dashMs = iv[1] === iv[2] ? 0 : +iv[1];
    // The serial diag tester's switch and address, kept across restarts
    // (the stock ROM only listens for the tester at boot)
    const ser = /^SIM: \[(INPUTS|READY)\] /.test(line) && proc === sim && !load?.test
      ? line.match(/ser_tester=(\d+),ser_peek=(\d+)(?:,ser_w26=(\d+),ser_w28=(\d+))?/) : null;
    if (ser) serCfg = { tester: +ser[1], peek: +ser[2], w26: ser[3] == null ? 0x00 : +ser[3], w28: ser[4] == null ? 0x80 : +ser[4] };
    const saved = line.match(/^SIM: \[SNAP\] saved t_ns=(\d+) reason=(\S+) dir=(.+)$/);
    if (saved) {
      if (FORWARD.test(line)) broadcast(line);
      finishSnapshot(saved[3], saved[1], saved[2]);
      return;
    }
    if (FORWARD.test(line)) broadcast(line);
    else if (!line.startsWith('-Info')) console.log(line);
    if (rom) followRom(rom[1], rom[2]);
    if (rom && (rom[1] === 'dme' || rom[1] === 'klr')) { loadedSha[rom[1]] = imageSha(rom[2]); drawMaps(rom[2], loadedSha[rom[1]], rom[1], true); }
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
// Bytes of an Intel HEX file (data records 00, extended addresses 02/04)
function parseIntelHex(text) {
  const data = new Map();
  let base = 0;
  for (const [n, raw] of text.split(/\r?\n/).entries()) {
    const line = raw.trim();
    if (!line) continue;
    if (line[0] !== ':' || !/^:[0-9A-Fa-f]+$/.test(line)) throw new Error(`line ${n + 1}: not an Intel HEX record`);
    const rec = Buffer.from(line.slice(1), 'hex');
    if (rec.reduce((a, b) => a + b, 0) & 0xFF) throw new Error(`line ${n + 1}: bad checksum`);
    const [count, hi, lo, kind] = rec;
    if (kind === 0) for (let i = 0; i < count; i++) data.set(base + (hi << 8 | lo) + i, rec[4 + i]);
    else if (kind === 1) break;
    else if (kind === 2) base = (rec[4] << 8 | rec[5]) << 4;
    else if (kind === 4) base = (rec[4] << 8 | rec[5]) << 16;
  }
  const out = Buffer.alloc(data.size ? Math.max(...data.keys()) + 1 : 0, 0xFF);
  for (const [a, b] of data) out[a] = b;
  return out;
}

function loadRom(url, body) {
  const cpu = url.searchParams.get('cpu');
  let name = basename(url.searchParams.get('name') ?? '');
  if (cpu !== 'dme' && cpu !== 'klr') return [400, 'cpu must be dme or klr'];
  if (!/^[\w.+ -]+\.(mem|bin|hex|ihx)$/i.test(name)) return [400, 'ROM image must be a .mem, .bin or Intel HEX (.hex) file'];
  if (simState === 'running') return [409, 'pause the simulation before loading a ROM'];
  // A raw binary or Intel HEX image is saved as the .mem the sim loads
  if (!/\.mem$/i.test(name)) {
    const size = cpu === 'dme' ? 8192 : 4096;
    let bytes;
    try { bytes = /\.(hex|ihx)$/i.test(name) ? parseIntelHex(body.toString('latin1')) : body; }
    catch (e) { return [400, `${name}: ${e.message}`]; }
    if (!bytes.length) return [400, `${name} is empty`];
    if (bytes.length > size) return [400, `${name} is ${bytes.length} bytes, more than the ${cpu.toUpperCase()} EPROM's ${size}`];
    body = Buffer.from(Array.from(bytes, b => b.toString(16).toUpperCase().padStart(2, '0') + '\n').join(''));
    name = name.replace(/\.[^.]+$/, '.mem');
  }
  if (cpu === 'dme') {
    const klr = klrImageName(name, body.toString('latin1'));
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
// Edited images kept with SAVE AS, a folder each (see saveEdited)
const SAVED = { dme: join(IMAGES.dme, 'edited'), klr: join(IMAGES.klr, 'edited') };
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
// The lite package also ships the tables already made from the workbooks,
// for when asm_select.sh can't run (no bash, or no pandas/openpyxl):
// lite/make_lite.sh writes which directory goes with which image
//   {"dme": {"89DME_951pin.mem": "asm_1989", ...}, "klr": {...}}
const LITE_TABLES = readJson(join(HERE, 'asm_tables.json'));

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

// The disassembly tables for an image: asm_select.sh's (the same helper
// as the run scripts: regenerates stale workbooks/tables; an image without
// a workbook of its own gets one made from the reference workbook,
// <cpu>/disassemble/variants/<name>.xlsx), else the lite package's prebuilt
// ones. { dir (null: none found), workbook, img (knownImage) }
function asmTables(cpu, path) {
  const { dir: dflt } = CPU_ASM[cpu];
  const CPU = cpu.toUpperCase();
  const img = knownImage(cpu, path);
  const env = img ? { [`${CPU}_ROM_FILE`]: img.name }
                  : { [`${CPU}_ROM_DIR`]: dirname(path).replace(/\\/g, '/') + '/', [`${CPU}_ROM_FILE`]: basename(path) };
  const r = existsSync(ASM_SELECT) && /\.mem$/i.test(path)
    ? spawnSync('bash', ['-c', `source "$1" && ${cpu}_asm_select _arr >&2 && printf %s "$${CPU}_ASM_SEL"`, '_', ASM_SELECT],
                { env: { ...process.env, ...env, [`${CPU}_ASM_DIR`]: '' }, encoding: 'utf8',
                  stdio: ['ignore', 'pipe', 'inherit'] })
    : { status: -1, stdout: '' };
  const sel = r.status === 0 && r.stdout.trim() ? resolve(r.stdout.trim()) : null;
  if (!img) return { dir: sel, workbook: sel ? `variants/${basename(sel).replace(/^asm_/, '')}.xlsx` : '-', img };
  if (sel) return { dir: sel, workbook: WORKBOOK[cpu][img.name], img };
  const sub = LITE_TABLES?.[cpu]?.[img.name];
  if (sub && existsSync(join(dflt, sub))) {
    console.error(`bridge: couldn't run asm_select.sh for ${img.name}; using the packaged ${sub} tables`);
    return { dir: join(dflt, sub), workbook: WORKBOOK[cpu][img.name], img };
  }
  return { dir: null, workbook: '-', img };
}

// Runs on every SIM: [ROM] line (start, restart, rom command), so an upload
// that reuses a file name with new contents is caught too. An image made by
// editing bytes (a POST /patch scratch image, or one kept with SAVE AS) is
// listed from the image it was made from (listingOf).
function followRom(cpu, path) {
  // The sim reports both EPROMs after a rom command: the other one didn't change
  const same = unchanged[cpu] === resolve(path);
  unchanged[cpu] = null;
  if (same) return;
  if (patches[cpu] && resolve(path) !== patches[cpu].path) patches[cpu] = null;   // another image: live edits dropped
  const p = patches[cpu];
  // A live edit doesn't change the image underneath: its listing is reused
  const { rows, workbook, match } = listingOf(cpu, path, !p);
  if (!rows) return;   // a pinned listing (--dme-asm / --klr-asm) on an unedited image
  ASM[cpu] = rows;
  asmLine(cpu, workbook, match);
}
// SIM: [ASM] <cpu> <workbook> match=... [patched=<bytes edited> [saved=<name>.mem]]:
// saved names the image the loaded edits were kept as with SAVE AS (the
// page's download button is only for edits not yet saved)
const asmSaid = { dme: null, klr: null };   // the last line's workbook and match
const savedAs = { dme: null, klr: null };   // { path: edited image loaded, name: saved as }
function asmLine(cpu, workbook = asmSaid[cpu]?.workbook, match = asmSaid[cpu]?.match) {
  asmSaid[cpu] = { workbook, match };
  const p = patches[cpu];
  const n = p ? p.orig.reduce((c, v, i) => c + (v !== p.img[i]), 0) : 0;
  const saved = n && savedAs[cpu]?.path === p.path ? ` saved=${savedAs[cpu].name}` : '';
  broadcast(`SIM: [ASM] ${cpu} ${workbook} match=${match}${n ? ` patched=${n}${saved}` : ''}`);
}

// ── Byte edits (POST /patch) ─────────────────────────────────
const ROM_SIZE = { dme: 8192, klr: 4096 };
const patches = { dme: null, klr: null };   // { base: image edited, path: edited image, orig, img }
const PATCH_DIR = join(ROM_DIR, 'patched');
const unchanged = { dme: null, klr: null };   // the image in the EPROM a patch didn't touch
// An image made by editing bytes names the image it was made from in
// <file>.base (one line, a path); following those leads to the root image,
// whose workbook lists it
const baseOf = path => { try { return readFileSync(`${path}.base`, 'utf8').split('\n')[0].trim() || null; } catch { return null; } };
function rootOf(path) {
  for (let i = 0, p = path; i < 16; i++) {
    const b = baseOf(p);
    if (!b || !existsSync(b)) return p;
    p = b;
  }
  return path;
}
const imgBytes = (cpu, path) => memBytes(path)?.subarray(0, ROM_SIZE[cpu]) ?? null;
// listingOf(cpu, path, fresh): { rows, workbook, match } for an image: its
// root image's listing (asm_select.sh / the pin), decoded again where the
// image differs from the root. Root listings are kept per path; fresh
// prepares the root's tables again (as every [ROM] of an unedited image does).
const rootAsm = { dme: null, klr: null };   // { src, rows, workbook, match }
function listingOf(cpu, path, fresh = false) {
  const { pin, dir: dflt } = CPU_ASM[cpu];
  const root = rootOf(path);
  const derived = resolve(root) !== resolve(path);
  if (fresh || rootAsm[cpu]?.src !== root) {
    if (pin) {
      if (!derived && !rootAsm[cpu]?.derived && rootAsm[cpu]) return {};
      rootAsm[cpu] = { src: root, rows: cpuListing(cpu, dflt), workbook: basename(dflt), match: 'pinned' };
    } else {
      const CPU = cpu.toUpperCase();
      const t = asmTables(cpu, root);
      const dir = t.dir ?? dflt, img = t.img;
      if (!t.dir && img) console.error(`bridge: couldn't prepare the ${CPU} tables for ${img.name}; keeping ${dflt}`);
      rootAsm[cpu] = { src: root, rows: cpuListing(cpu, dir), workbook: t.dir ? t.workbook : '-', match: img?.match ?? 'none' };
      console.log(`bridge: ${CPU} listing for ${basename(root)}: ${dir} (${img ? `${img.name}, matched by ${img.match}` : 'unknown image'}, ${rootAsm[cpu].rows.length} lines)`);
    }
  }
  const r = rootAsm[cpu];
  r.derived = derived;
  if (!derived) return r;
  const orig = imgBytes(cpu, root), img = imgBytes(cpu, path);
  return { ...r, rows: orig && img ? patchListing(cpu, r.rows, orig, img) : r.rows };
}
// The listing of another image (GET /edits, compare): the loaded one's
// root listing is reused when it is the same root
function listingFor(cpu, path) {
  const root = rootOf(path);
  if (rootAsm[cpu]?.src === root) return listingOf(cpu, path).rows;
  const rows = cpuListing(cpu, tablesFor(cpu, root) ?? CPU_ASM[cpu].dir);
  if (resolve(root) === resolve(path)) return rows;
  const orig = imgBytes(cpu, root), img = imgBytes(cpu, path);
  return orig && img ? patchListing(cpu, rows, orig, img) : rows;
}
function patchRom(cpu, body) {
  if (cpu !== 'dme' && cpu !== 'klr') return [400, 'cpu must be dme or klr'];
  let b;
  try { b = JSON.parse(body); } catch { return [400, 'body must be JSON {addr, bytes} or {revert: true}']; }
  if (!sim) return [409, 'simulator not running'];
  if (simState !== 'paused') return [409, 'pause the simulation before editing the ROM'];
  const size = ROM_SIZE[cpu];
  const base = patches[cpu]?.base ?? roms[cpu];
  if (!base) return [409, `no ${cpu.toUpperCase()} image reported by the sim yet`];
  const orig = patches[cpu]?.orig ?? imgBytes(cpu, base);
  if (!orig) return [500, `can't read ${base}`];
  const img = Buffer.from(patches[cpu]?.img ?? orig);
  if (!b?.revert) {
    const addr = b?.addr, bytes = b?.bytes;
    if (!Number.isInteger(addr) || addr < 0 || addr >= size) return [400, `addr must be 0..${(size - 1).toString(16)}h`];
    if (!Array.isArray(bytes) || !bytes.length || bytes.length > 16 || !bytes.every(v => Number.isInteger(v) && v >= 0 && v <= 255))
      return [400, 'bytes must be 1 to 16 values 0..255'];
    if (addr + bytes.length > size) return [400, `edit runs past the end of the ${size}-byte EPROM`];
    img.set(bytes, addr);
  }
  let path;
  if (b?.revert || img.equals(orig)) {
    path = base;   // back to the image as loaded
    patches[cpu] = null;
  } else {
    const sha = createHash('sha256').update(img).digest('hex').slice(0, 8);
    path = join(PATCH_DIR, cpu, `${basename(base).replace(/\.mem$/i, '')}.patch-${sha}.mem`);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, Array.from(img, v => v.toString(16).toUpperCase().padStart(2, '0') + '\n').join(''));
    writeFileSync(`${path}.base`, `${resolve(base)}\n`);   // what it was made from
    patches[cpu] = { base, path, orig, img };
  }
  console.log(`bridge: ${cpu} ROM ${b?.revert ? 'edits reverted' : `edit at ${b.addr.toString(16)}h`} -> ${basename(path)}`);
  if (!send(`rom ${cpu} ${path}`)) return [409, 'simulator not running'];
  const other = cpu === 'dme' ? 'klr' : 'dme';
  unchanged[other] = roms[other] && resolve(roms[other]);
  return [204, ''];
}

// GET /edits/<cpu>[?name=<file>]: what an edited image changed, against the
// image it was made from: the loaded one, or an edited image by file name
// (a snapshot's, an earlier one). { name, base, bytes, places, text }; text is
// the list as plain text, for copying: each place's listing before and after.
const isPatched = name => /\.patch-[0-9a-f]{8}\.mem$/i.test(name ?? '');
function editsFor(cpu, name) {
  const p = patches[cpu];
  const path = !name || (p && basename(p.path) === name) ? p?.path : findImageByName(basename(name), cpu);
  if (!path) return [200, { name: roms[cpu] ? basename(roms[cpu]) : null, base: null, bytes: 0, places: 0, text: '' }];
  const base = p?.path === path ? p.base : baseOf(path);
  if (!base || !path || !existsSync(path)) return [404, `no record of the edits in ${basename(name ?? path ?? '')}`];
  const orig = imgBytes(cpu, base), img = imgBytes(cpu, path);
  if (!orig || !img) return [404, `can't read ${basename(orig ? path : base)}`];
  const rows = listingFor(cpu, base);
  const now = patchListing(cpu, rows, orig, img);
  // runs of edited rows, each with the rows it replaced
  const runs = [];
  for (const r of now) {
    if (!r.patched) continue;
    const last = runs.at(-1);
    if (last && last.end === r.a) { last.now.push(r); last.end = r.a + rowBytes(r); }
    else runs.push({ start: r.a, end: r.a + rowBytes(r), now: [r] });
  }
  // (rows of an image that was itself edited are marked too: only places this image changes)
  for (let i = runs.length - 1; i >= 0; i--) {
    let n = 0;
    for (let a = runs[i].start; a < runs[i].end; a++) n += orig[a] !== img[a];
    if (!n) runs.splice(i, 1);
  }
  const w = cpu === 'dme' ? 4 : 3;
  const ax = a => a.toString(16).toUpperCase().padStart(w, '0');
  const bx = v => v.toString(16).toUpperCase().padStart(2, '0');
  const lw = Math.max(8, ...now.filter(r => r.patched).map(r => r.label.length), ...rows.map(r => r.label.length).filter(n => n < 24));
  const line = r => `    ${ax(r.a)}  ${r.label.padEnd(lw)}  ${r.bytes.padEnd(9)}  ${r.instr.padEnd(5)} ${r.ops}`.trimEnd();
  let bytes = 0;
  const blocks = runs.map(run => {
    const was = rows.filter(r => r.a >= run.start && r.a < run.end);
    const changed = [];
    for (let a = run.start; a < run.end; a++) if (orig[a] !== img[a]) changed.push(`${ax(a)}: ${bx(orig[a])} -> ${bx(img[a])}`);
    bytes += changed.length;
    return [`${ax(run.start)}-${ax(run.end - 1)}  ${changed.length} byte${changed.length !== 1 ? 's' : ''} changed: ${changed.join(', ')}`,
            '  was:', ...was.map(line), '  now:', ...run.now.map(line)].join('\n');
  });
  const CPU = cpu.toUpperCase();
  const text = [`${CPU} ROM ${basename(base)} (modified): ${bytes} byte${bytes !== 1 ? 's' : ''} changed in ${runs.length} place${runs.length !== 1 ? 's' : ''}`,
                `edited image: ${path}`, '', ...blocks.flatMap(b => [b, ''])].join('\n');
  return [200, { name: basename(path), base: basename(base), bytes, places: runs.length, text }];
}

// POST /edits/<cpu>/save  {name, from?, use?}: keep an edited image (the
// loaded one, or one by file name) as an image of its own, in a folder of
// its own beside the repo's images, bin_images/<cpu>/edited/<name>/:
//   <name>.mem             the image
//   <name>.bin             the EPROM's bytes in order, for programming a chip
//   <name>.mem.base        the image it was made from (a path): it is listed
//                          from that image's workbook (asm_select.sh, the
//                          validator and the bridge follow it)
//   <name>.mem.edits.txt   its list of edits
//   <name>.xlsx            its own disassembly workbook, made from the base
//                          image's workbook (build_variant.py /
//                          build_klr_variant.py): the base's rows and
//                          annotations, the edited code decoded again and
//                          highlighted, a diff sheet of the bytes changed.
//                          Written in the background, a few seconds later.
// It is then in every image list (LOAD, COMPARE, RUN REGRESSIONS, setups).
// use: true also swaps it into the EPROM in place of the edited image
// (paused only). Images saved before this (obj/roms/<cpu>/) are still found.
const IMAGE_NAME = /^[\w.+-]{1,64}$/;
// The folders of saved images: bin_images/<cpu>/edited/<name>/
function savedDirs(cpu) {
  try {
    return readdirSync(SAVED[cpu], { withFileTypes: true }).filter(e => e.isDirectory())
      .map(e => join(SAVED[cpu], e.name)).sort();
  } catch { return []; }
}
const DISASM = { dme: join(REPO, 'dme', 'disassemble'), klr: join(REPO, 'klr', 'disassemble') };
const VARIANT_GEN = { dme: 'build_variant.py', klr: 'build_klr_variant.py' };
// The hand-annotated workbook and the image it describes, for a base with
// no workbook found
const REF_WORKBOOK = { dme: ['disassembleperformance.xlsx', join(IMAGES.dme, '28PIN_DME_PERFORMANCE.mem')],
                       klr: ['87KLR951.xlsx', join(IMAGES.klr, '87KLR_951.mem')] };
// <name>.xlsx for a saved image: build_variant.py / build_klr_variant.py with
// the base image's workbook as the source (in the background)
function savedWorkbook(cpu, root, path, out) {
  const t = asmTables(cpu, root);   // brings the base's workbook up to date
  let src = t.dir && t.workbook !== '-' ? join(DISASM[cpu], t.workbook) : null, ref = root;
  if (!src || !existsSync(src)) [src, ref] = [join(DISASM[cpu], REF_WORKBOOK[cpu][0]), REF_WORKBOOK[cpu][1]];
  const bytes = imgBytes(cpu, ref);
  if (!bytes) return console.error(`bridge: no workbook for ${basename(path)}: can't read ${ref}`);
  // build_variant.py takes the reference as a raw binary, build_klr_variant.py as a .mem
  const refArg = `${out}.ref.${cpu === 'dme' ? 'bin' : 'mem'}`;
  writeFileSync(refArg, cpu === 'dme' ? bytes : Array.from(bytes, v => v.toString(16).toUpperCase().padStart(2, '0') + '\n').join(''));
  const tag = n => basename(n).replace(/\.[^.]+$/, '').replace(/[^\w.-]/g, '_');
  const tmp = `${out}.tmp.xlsx`;
  const proc = spawn(PY, [join(DISASM[cpu], VARIANT_GEN[cpu]), src, path, refArg, tmp, tag(path), tag(ref)],
                     { cwd: DISASM[cpu], stdio: ['ignore', 'ignore', 'pipe'] });
  const err = [];
  proc.stderr.on('data', d => err.push(d));
  const done = ok => {
    rmSync(refArg, { force: true });
    if (ok) { renameSync(tmp, out); console.log(`bridge: ${cpu} saved image workbook ${out} (from ${basename(src)})`); }
    else {
      rmSync(tmp, { force: true });
      console.error(`bridge: couldn't make ${basename(out)} from ${basename(src)}: ${Buffer.concat(err).toString('utf8').trim().split('\n').slice(-3).join(' | ')}`);
    }
  };
  proc.on('error', e => { err.push(Buffer.from(e.message)); done(false); });
  proc.on('close', code => { if (code !== null) done(code === 0 && existsSync(tmp)); });
}
function saveEdited(cpu, body) {
  let b;
  try { b = JSON.parse(body); } catch { return [400, 'body must be JSON {name, from, use}']; }
  const name = String(b?.name ?? '').trim().replace(/\.mem$/i, '');
  if (!IMAGE_NAME.test(name) || isPatched(`${name}.mem`) || /^\.+$/.test(name)) return [400, 'name: letters, digits, _ . + - (up to 64)'];
  const file = `${name}.mem`;
  const dir = join(SAVED[cpu], name);
  if (findImageByName(file, cpu) || findImageByName(`${name}.bin`, cpu) || existsSync(dir))
    return [409, `there is already a ${cpu.toUpperCase()} image named ${name}`];
  const [code, edits] = editsFor(cpu, b?.from || null);
  if (code !== 200) return [code, edits];
  if (!edits.bytes) return [400, 'that image has no edits to save'];
  const src = findImageByName(edits.name, cpu);
  if (!src) return [404, `no image ${edits.name}`];
  if (b?.use && simState !== 'paused') return [409, 'pause the simulation to switch the sim to the saved image'];
  mkdirSync(dir, { recursive: true });
  const path = join(dir, file);
  writeFileSync(path, readFileSync(src));
  // and as a raw binary, the EPROM's bytes in order, for programming a chip
  const bin = `${name}.bin`;
  writeFileSync(join(dir, bin), imgBytes(cpu, src));
  writeFileSync(`${path}.edits.txt`, `${file}: ${edits.text}`);
  const root = resolve(rootOf(findImageByName(edits.base, cpu) ?? src));
  writeFileSync(`${path}.base`, `${root}\n`);   // listed from that image's workbook
  console.log(`bridge: ${cpu} edited image ${edits.name} saved as ${path}`);
  const xlsx = `${name}.xlsx`;
  savedWorkbook(cpu, root, path, join(dir, xlsx));
  // the edits in the EPROM are on disk now
  if (patches[cpu] && basename(patches[cpu].path) === edits.name) {
    savedAs[cpu] = { path: patches[cpu].path, name: file };
    if (!b?.use && asmSaid[cpu]) asmLine(cpu);
  }
  if (b?.use && !send(`rom ${cpu} ${path}`)) return [409, 'simulator not running'];
  return [200, { name: file, bin, xlsx, dir: resolve(dir) }];
}

// GET /image/<cpu>.bin?name=<file>: an image (any the bridge knows, an edited
// one too; default: the loaded one) as a raw binary for an EPROM programmer:
// the whole EPROM (8192 bytes DME, 4096 KLR), unset bytes FF
function imageBin(cpu, name) {
  const path = name ? findImageByName(basename(name), cpu) : roms[cpu];
  if (!path) return [404, `no ${cpu.toUpperCase()} image ${name ?? ''}`];
  const img = /\.mem$/i.test(path) ? imgBytes(cpu, path)
    : Buffer.concat([readFileSync(path), Buffer.alloc(ROM_SIZE[cpu], 0xFF)]).subarray(0, ROM_SIZE[cpu]);
  if (!img) return [500, `can't read ${basename(path)}`];
  const file = basename(path).replace(/\.patch-([0-9a-f]{8})\.mem$/i, '_modified_$1.mem').replace(/\.[^.]+$/, '.bin');
  return [200, img, file];
}

// ── Image setups: a named DME + KLR pair ──────────────────────
// Kept in obj/roms/setups.json, [{name, dme, klr}] (image file names). The
// developer scripts' three pairs are built in. The live ROM IMAGES row loads
// one into both EPROMs; RUN REGRESSIONS lists them as ROM pairs.
//   GET /setups                     [{name, dme, klr, builtin, ok}] (ok: both images found)
//   POST /setups                    {name, dme, klr}: add or replace one
//   DELETE /setups/<name>
//   POST /setups/<name>/load[?reset=1]  load both images (paused only); reset: restart at t=0
const SETUPS = join(ROM_DIR, 'setups.json');
const BUILTIN_SETUPS = [
  { name: '1989 stock', dme: '89DME_951pin.mem', klr: '89KLR_951.mem' },
  { name: '1986', dme: '28PIN_86DME.mem', klr: '86KLR_951.mem' },
  { name: 'CarPokes performance', dme: '28PIN_DME_PERFORMANCE.mem', klr: '87KLR_951.mem' },
];
const customSetups = () => (readJson(SETUPS) ?? []).filter(x => x && IMAGE_NAME.test(x.dme ?? '') && IMAGE_NAME.test(x.klr ?? ''));
const listSetups = () => [...BUILTIN_SETUPS.map(x => ({ ...x, builtin: true })), ...customSetups()]
  .map(x => ({ ...x, ok: !!findImageByName(x.dme, 'dme') && !!findImageByName(x.klr, 'klr') }));
function saveSetup(body) {
  let b;
  try { b = JSON.parse(body); } catch { return [400, 'body must be JSON {name, dme, klr}']; }
  const name = String(b?.name ?? '').trim();
  if (!/^[\w .+-]{1,64}$/.test(name)) return [400, 'name: letters, digits, spaces, _ . + - (up to 64)'];
  if (BUILTIN_SETUPS.some(x => x.name === name)) return [409, `${name} is a built-in setup`];
  for (const cpu of ['dme', 'klr'])
    if (!IMAGE_NAME.test(b?.[cpu] ?? '') || !findImageByName(b[cpu], cpu)) return [400, `no ${cpu.toUpperCase()} image ${b?.[cpu] ?? ''}`];
  const list = customSetups().filter(x => x.name !== name);
  list.push({ name, dme: b.dme, klr: b.klr });
  mkdirSync(ROM_DIR, { recursive: true });
  writeFileSync(SETUPS, JSON.stringify(list, null, 2));
  broadcast('SIM: [SETUPS] changed');
  return [200, listSetups()];
}
function deleteSetup(name) {
  const list = customSetups();
  if (!list.some(x => x.name === name)) return [404, `no setup ${name}`];
  writeFileSync(SETUPS, JSON.stringify(list.filter(x => x.name !== name), null, 2));
  broadcast('SIM: [SETUPS] changed');
  return [200, listSetups()];
}
function loadSetup(name, reset) {
  const x = listSetups().find(y => y.name === name);
  if (!x) return [404, `no setup ${name}`];
  const paths = { dme: findImageByName(x.dme, 'dme'), klr: findImageByName(x.klr, 'klr') };
  for (const cpu of ['dme', 'klr']) if (!paths[cpu]) return [404, `no ${cpu.toUpperCase()} image ${x[cpu]}`];
  if (simState === 'running') return [409, 'pause the simulation before loading a setup'];
  console.log(`bridge: setup ${name}: ${x.dme} + ${x.klr}${reset ? ' (restart)' : ''}`);
  if (reset) { Object.assign(roms, paths); restartSim(); return [204, '']; }
  if (!send(`rom dme ${paths.dme}\nrom klr ${paths.klr}`)) return [409, 'simulator not running'];
  return [204, ''];
}

// ── ROM image compare ────────────────────────────────────────
// GET /compare/<cpu>/images: the images it can compare (bin_images/<cpu>
// and the uploads), [{name, src: repo|upload, sha}]
// GET /compare/<cpu>/variants[?ref=<name>]: every image against the
// reference (default: the first .mem), map by map (rom_compare.py
// --variants); images with the same contents are listed once
// GET /compare/<cpu>?a=<name>&b=<name>[&all=1]: rom_compare.py's JSON for
// the two (maps and tables decoded from each, the other differing bytes
// with the listing around them). A name is a file name, never a path.
const ROM_COMPARE = join(HERE, 'rom_compare.py');
function compareImages(cpu) {
  const out = [];
  // (images saved from edits, bin_images/<cpu>/edited/<name>/, are listed
  // with the uploads, as the ones saved before were)
  for (const [dir, src] of [[IMAGES[cpu], 'repo'], [join(ROM_DIR, cpu), 'upload'],
                            ...savedDirs(cpu).map(d => [d, 'upload']), [join(PATCH_DIR, cpu), 'edited']]) {
    let names = [];
    try { names = readdirSync(dir); } catch { continue; }
    for (const n of names.sort()) {
      if (!/\.(mem|bin)$/i.test(n)) continue;
      const p = join(dir, n);
      // a .bin that is only part of an EPROM (a 4 KB half, a short dump)
      // isn't a whole image
      // nor a .mem that fills only part of it (lower_4k_..., upper_4k_...)
      if (/\.mem$/i.test(n) && memWords(p) <= ROM_BYTES[cpu] / 2) continue;
      if (/\.bin$/i.test(n)) {
        let size = 0;
        try { size = statSync(p).size; } catch { continue; }
        if (size !== ROM_BYTES[cpu] && size !== 8192) continue;
      }
      out.push({ name: n, src, sha: imageSha(p), dir });
    }
  }
  return out;
}
// How many bytes a .mem file sets (its data words, not @addresses)
function memWords(file) {
  try {
    return readFileSync(file, 'utf8').replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*$/gm, ' ')
      .split(/\s+/).filter(t => t && t[0] !== '@').length;
  } catch { return 0; }
}
const tablesCache = new Map();   // `${cpu}:${path}:${mtime}` -> dir
function tablesFor(cpu, path) {
  if (!/\.mem$/i.test(path)) return null;
  // an edited image is listed with the tables of the image it was made from
  path = rootOf(path);
  let k;
  try { k = `${cpu}:${path}:${statSync(path).mtimeMs}`; } catch { return null; }
  if (!tablesCache.has(k)) tablesCache.set(k, asmTables(cpu, path).dir);
  return tablesCache.get(k);
}
function runCompare(args, done) {
  const proc = spawn(PY, [ROM_COMPARE, ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
  const out = [], err = [];
  proc.stdout.on('data', d => out.push(d));
  proc.stderr.on('data', d => err.push(d));
  proc.on('error', e => done(500, `rom_compare.py: ${e.message}`));
  proc.on('close', code => code === 0
    ? done(200, Buffer.concat(out).toString('utf8'), 'application/json')
    : done(500, Buffer.concat(err).toString('utf8').trim() || `rom_compare.py exited ${code}`));
}
function compareVariants(cpu, ref, done) {
  const seen = new Set(), list = [];
  // .mem first, so a .bin with the same bytes is the one left out
  const all = compareImages(cpu).sort((x, y) => /\.mem$/i.test(y.name) - /\.mem$/i.test(x.name));
  for (const i of all) {
    if (!i.sha || seen.has(i.sha)) continue;
    seen.add(i.sha);
    list.push(i.name);
  }
  if (!list.length) return done(404, `no ${cpu.toUpperCase()} images`);
  if (ref && !list.includes(ref)) {
    if (!findImageByName(ref, cpu)) return done(404, `no ${cpu.toUpperCase()} image named ${ref}`);
    list.unshift(ref);
  } else if (ref) {
    list.splice(list.indexOf(ref), 1);
    list.unshift(ref);
  }
  const paths = list.map(n => findImageByName(n, cpu));
  runCompare([cpu, '--variants', ...paths, '--names', ...list], done);
}
function compareRoms(cpu, a, b, all, done) {
  const pa = findImageByName(a, cpu), pb = findImageByName(b, cpu);
  if (!pa || !pb) return done(404, `no ${cpu.toUpperCase()} image named ${!pa ? a : b}`);
  const args = [ROM_COMPARE, cpu, pa, pb, '--name-a', a, '--name-b', b];
  const ta = tablesFor(cpu, pa), tb = tablesFor(cpu, pb);
  if (ta) args.push('--asm-a', ta);
  if (tb) args.push('--asm-b', tb);
  if (all) args.push('--all');
  runCompare(args.slice(1), done);
}

// ── Logs ─────────────────────────────────────────────────────
// The regression runs' .dash.logs (v_run_dashboard_tests.sh: v_dash_logs,
// run_dashboard_tests.sh: dash_logs) in each ROM pair's folder
// (dme_klr/<rom>, logdirs.mjs), and in the shared folders runs used before
// those (rom null), for LOAD LOG. Only these folders and only
// <name>.dash.log in them: a request never names a path.
const LOG_DIRS = ['v_dash_logs', 'dash_logs'];
const logNameOk = n => /^[\w.+-]+\.dash\.log$/.test(n) && !n.startsWith('.');
const logFolder = (rom, dir) => (rom == null || romVariants(TMP_ROOT).includes(rom)) && LOG_DIRS.includes(dir)
  && join(TMP_ROOT, 'dme_klr', ...(rom == null ? [] : [rom]), dir);
function listLogs() {
  const out = [];
  for (const rom of [...romVariants(TMP_ROOT), null]) {
    for (const dir of LOG_DIRS) {
      const folder = logFolder(rom, dir);
      let names = [];
      try { names = readdirSync(folder); } catch { continue; }
      for (const name of names) {
        if (!logNameOk(name)) continue;
        try {
          const st = statSync(join(folder, name));
          if (st.isFile()) out.push({ rom, dir, name, size: st.size, mtime: st.mtimeMs });
        } catch { /* gone since the listing */ }
      }
    }
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}

// ── Snapshots ────────────────────────────────────────────────
// Next to the other run output (run_dashboard_tests.sh's dash_logs), out
// of the repo and safe from a clean of obj/: $DMEKLR_TMP/dme_klr/snapshots,
// by default ../tmp/dme_klr/snapshots beside the checkout (see paths.sh).
// --snapdir <dir> puts them elsewhere.
const TMP_ROOT = resolve(process.env.DMEKLR_TMP || join(REPO, '..', 'tmp'));
const SNAP_DIR = resolve(arg('snapdir', join(TMP_ROOT, 'dme_klr', 'snapshots')));
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
let bpNow = { dme: [], klr: [] };   // the running sim's breakpoints, from SIM: [BP]
const snapCfg = { auto: true, break: false };   // from SIM: [SNAPCFG]; kept across restarts
let serCfg = { tester: 0, peek: 0x37, w26: 0x00, w28: 0x80 };   // serial diag tester, from SIM: [INPUTS]; kept across restarts (+ser_tester / +ser_peek / +ser_w26 / +ser_w28)
let dashMs = 0;   // DS snapshot interval the dashboard set, from SIM: [INTERVAL] (0 = the build's); kept across restarts
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
    // t_ns is where LOAD stops: a warning's or failure's opens before it
    const early = req.t_ns < (req.t_ms ?? 0) * 1e6 ? `opens ${((req.t_ms * 1e6 - req.t_ns) / 1e6).toFixed(0)} ms before the event at ${req.t_ms} ms · ` : '';
    return { id, kind: 'test', test: req.test, t_ns: req.t_ns ?? (req.t_ms ?? 0) * 1e6, created: req.created, reason: req.reason === 'fail' ? 'fail' : 'test',
             label: req.test, trigger: `${early}${req.test}: ${req.trigger}`, pc: null, inputs: null, roms, bytes: 0 };
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
const TEST_SOURCES = [join(HERE, 'sim_main.cpp'), join(HERE, 'stdin_ready.cpp'), join(HERE, 'snapshot.h'), join(HERE, 'build_live.sh'),
                      join(REPO, 'dme_klr', 'bench', 'verilog', 'dme_klr_dashboard_tb.v')];
const testDir = req => join(dirname(SIM), 'tests', req.test);
const testStamp = req => JSON.stringify({ defines: req.defines, roms: req.roms, interval: req.interval_ms, script: req.script });
function testBuilt(req) {
  const bin = join(testDir(req), 'dme_klr_live' + EXE);
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
// The shared test builds (build_live.sh --tests): every test from two
// binaries, its options as +X=<n>. The lite package ships them with
// tests.json (test_opts.py tests-json); the developer install makes them
// the first time a test is loaded, and again when a source is newer.
const TESTS_RT = join(dirname(SIM), 'tests_rt');
const TESTS_JSON = join(HERE, 'tests.json');
const TEST_OPTS = join(REPO, 'dme_klr', 'test_opts.py');
const rtBin = cl => join(TESTS_RT, cl ? 'cl' : 'open', 'dme_klr_live' + EXE);
const RT_SOURCES = [...TEST_SOURCES, join(REPO, 'dme', 'bench', 'verilog', 'test_opts_gen.vh'),
                    join(REPO, 'dme', 'bench', 'verilog', 'test_opts.vh')];
function rtBuilt() {
  return [false, true].every(cl => {
    try {
      const t = statSync(rtBin(cl)).mtimeMs;
      return !existsSync(join(HERE, 'build_live.sh'))   // the lite package: as shipped
          || RT_SOURCES.every(f => { try { return statSync(f).mtimeMs <= t; } catch { return true; } });
    } catch { return false; }
  });
}
// A test's +X=<n> and file list: test_opts.py from its -D flags (developer
// install), else tests.json by name (lite package)
function testOptions(req) {
  const interval = req.interval_ms ?? 100;
  if (existsSync(TEST_OPTS)) {
    const r = spawnSync(PY, [TEST_OPTS, 'resolve', '--interval', String(interval), ...req.defines], { encoding: 'utf8' });
    if (r.status === 0) {
      const lines = r.stdout.split(/\r?\n/);
      return { cl: lines.includes('files: files_cl'), args: lines.filter(l => l.startsWith('+')) };
    }
    console.error(`bridge: test_opts.py resolve failed: ${r.stderr?.trim()}`);
  }
  const t = readJson(TESTS_JSON)?.tests?.[req.test];
  return t ? { cl: t.files === 'files_cl', args: [...t.plusargs, `+DASH_INTERVAL_MS=${interval}`] } : null;
}
// The ROM images and their disassembly tables as +NAME=<path>
function pathArgs(req) {
  const repo = REPO.replace(/\\/g, '/') + '/';
  const out = [`+DMEKLR_REPO=${repo}`];
  for (const cpu of ['dme', 'klr']) {
    const CPU = cpu.toUpperCase();
    const p = req.roms?.[cpu] && existsSync(req.roms[cpu]) ? resolve(req.roms[cpu])
            : join(IMAGES[cpu], cpu === 'dme' ? '89DME_951pin.mem' : '89KLR_951.mem');
    out.push(`+${CPU}_ROM_DIR=${dirname(p).replace(/\\/g, '/')}/`, `+${CPU}_ROM_FILE=${basename(p)}`);
    const t = tablesFor(cpu, p);
    if (t) out.push(`+${CPU}_ASM_DIR=${t.replace(/\\/g, '/')}/`);
  }
  return out;
}
let rtBuild = null;   // build_live.sh --tests in progress
function buildTestsRt(id, test, then) {
  const proc = spawn('bash', [join(HERE, 'build_live.sh'), '--tests'], { stdio: ['ignore', 'pipe', 'pipe'] });
  rtBuild = proc;
  testBuild = { id, proc };
  broadcast(`SIM: [SNAP] building id=${id} test=${test} starting (the shared test builds, once: a few minutes)`);
  const tail = [];
  const onLine = line => {
    tail.push(line); if (tail.length > 20) tail.shift();
    if (/^(gen_state|Built|- V|%Error|.*error:)/.test(line))
      broadcast(`SIM: [SNAP] building id=${id} test=${test} ${line.trim().slice(0, 200)}`);
  };
  createInterface({ input: proc.stdout }).on('line', onLine);
  createInterface({ input: proc.stderr }).on('line', onLine);
  proc.on('exit', code => {
    rtBuild = null;
    testBuild = null;
    if (code === 0) { broadcast(`SIM: [SNAP] building id=${id} test=${test} done`); then(); }
    else {
      const why = tail.filter(l => /error/i.test(l)).slice(-2).join(' | ') || tail.slice(-1)[0] || `exit ${code}`;
      broadcast(`SIM: [SNAP] building id=${id} test=${test} failed`);
      broadcast(`SIM: [ERROR] building the shared test builds failed: ${why.slice(0, 300)}`);
    }
  });
}
function loadTestRt(id, req) {
  const run = () => {
    const o = testOptions(req);
    if (!o) return broadcast(`SIM: [ERROR] no options for test ${req.test} (no test_opts.py, and not in tests.json)`);
    console.log(`bridge: running test ${req.test} to ${req.t_ns / 1e6} ms on the shared ${o.cl ? 'closed-loop' : 'open-loop'} build`);
    restartSim({ test: { bin: rtBin(o.cl), runTo: req.t_ns, id, args: [...o.args, ...pathArgs(req)] } });
  };
  if (rtBuilt()) { run(); return [204, '']; }
  buildTestsRt(id, req.test, run);
  return [202, ''];
}

// ── Log-replay tests (replay_wot_60s ...) ────────────────────
// No build of their own: the live simulator plays the log's stimulus file
// (sim_main.cpp +stim=), made here by replay/xlsx_to_stim.py with the
// test's run_replay.sh window args (request.json "replay", test_snap.py)
// and kept in obj/replay/ for next time.
const REPLAY_DIR = join(REPO, 'dme_klr', 'replay');
function replayStimArgs(args) {
  let xlsx = join(REPO, 'dme_klr', 'bench', 'verilog', '10_9_evening_WOT_Run.xlsx');
  let win = [];
  const stim = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--xlsx') xlsx = args[++i];
    else if (a === '--segment') win = ['--segment', args[++i]];
    else if (a === '--start-s' || a === '--end-s') win.push(a, args[++i]);
    else if (a === '--all') win = ['--start-s', '0'];
    else if (['--map-offset', '--afm-vref', '--afm-offset'].includes(a)) stim.push(a, args[++i]);
    else if (a === '--o2-from-log') stim.push(a);
    else if (a === '--') break;
    // --name, --out-dir, --iverilog ...: how run_replay.sh runs, not what it plays
    else if (['--name', '--out-dir'].includes(a)) i++;
  }
  if (!win.length) win = ['--end-s', '14'];   // run_replay.sh's default: the first WOT pull
  return { xlsx: resolve(join(REPO, 'dme_klr'), xlsx), args: [...win, ...stim] };
}
function loadReplay(id, req) {
  if (!existsSync(join(REPLAY_DIR, 'xlsx_to_stim.py')))
    return [501, `${req.test} is a log replay, which needs dme_klr/replay/ (not in this package)`];
  const { xlsx, args } = replayStimArgs(req.replay.args ?? []);
  if (!existsSync(xlsx)) return [400, `${req.test}: no log ${xlsx}`];
  const romOf = cpu => req.roms?.[cpu] && existsSync(req.roms[cpu]) ? resolve(req.roms[cpu]) : null;
  const dmeRom = romOf('dme') ?? join(IMAGES.dme, '89DME_951pin.mem');
  const out = join(dirname(SIM), 'replay', req.test);
  const stimFile = out + '.stim.csv';
  const stamp = JSON.stringify({ args, xlsx, xlsxT: statSync(xlsx).mtimeMs, dmeRom,
                                 py: statSync(join(REPLAY_DIR, 'xlsx_to_stim.py')).mtimeMs });
  const run = () => {
    console.log(`bridge: replaying ${req.test} to ${req.t_ns / 1e6} ms on the live build`);
    const romArgs = ['dme', 'klr'].filter(romOf).map(cpu => `+${cpu}_rom=${romOf(cpu)}`);
    restartSim({ test: { bin: SIM, runTo: req.t_ns, id,
                         args: [`+stim=${stimFile}`, `+warmup_ms=${req.replay.warmup_ms ?? 3000}`, ...romArgs] } });
  };
  let fresh = false;
  try { fresh = existsSync(stimFile) && readFileSync(out + '.stamp', 'utf8') === stamp; } catch { /* make it */ }
  if (fresh) { run(); return [204, '']; }
  mkdirSync(dirname(out), { recursive: true });
  broadcast(`SIM: [SNAP] building id=${id} test=${req.test} starting (the stimulus from the log, once: under a minute)`);
  const proc = spawn(PY, [join(REPLAY_DIR, 'xlsx_to_stim.py'), xlsx, out, ...args, '--dme-rom', dmeRom],
                     { stdio: ['ignore', 'pipe', 'pipe'] });
  testBuild = { id, proc };
  const tail = [];
  const onLine = line => { tail.push(line); if (tail.length > 20) tail.shift(); };
  createInterface({ input: proc.stdout }).on('line', onLine);
  createInterface({ input: proc.stderr }).on('line', onLine);
  proc.on('exit', code => {
    testBuild = null;
    if (code === 0 && existsSync(stimFile)) {
      writeFileSync(out + '.stamp', stamp);
      broadcast(`SIM: [SNAP] building id=${id} test=${req.test} done`);
      run();
    } else {
      broadcast(`SIM: [SNAP] building id=${id} test=${req.test} failed`);
      broadcast(`SIM: [ERROR] making ${req.test}'s stimulus failed: ${(tail.slice(-2).join(' | ') || `exit ${code}`).slice(0, 300)}`);
    }
  });
  return [202, ''];
}

function loadTest(id) {
  const req = readJson(join(snapPath(id), 'request.json'));
  if (!snapId(req?.test ?? '') || !Array.isArray(req.defines)) return [400, `snapshot ${id}: bad request.json`];
  if (testBuild) return [409, `already building ${testBuild.id}`];
  if (req.replay) return loadReplay(id, req);
  const dev = existsSync(join(HERE, 'build_live.sh'));
  // The shared builds: shipped (lite), or made once (developer install,
  // unless the test's runner script is not the usual one: then it may
  // have flags test_opts.py doesn't know, so it gets a build of its own)
  const usual = !req.script || /[\\/](v_)?run_dashboard_tests\.sh$/.test(req.script);
  if ((!dev && rtBuilt()) || (dev && usual && existsSync(TEST_OPTS) && process.env.DMEKLR_TEST_BUILD !== 'per-test'))
    return loadTestRt(id, req);
  if (!dev)
    return [501, 'opening a regression test at a chosen time needs the shared test builds (dme_klr/live/obj/tests_rt), which this package doesn\'t have'];
  const run = () => {
    console.log(`bridge: running test ${req.test} to ${req.t_ns / 1e6} ms`);
    restartSim({ test: { bin: join(testDir(req), 'dme_klr_live' + EXE), runTo: req.t_ns, id } });
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

// ── Map graphs ───────────────────────────────────────────────
// Beside the snapshots, out of the repo: $DMEKLR_TMP/dme_klr/map_graphs
const MAP_CACHE = resolve(arg('mapcache', join(TMP_ROOT, 'dme_klr', 'map_graphs')));
const MAP_GRAPHS = { dme: join(HERE, 'map_graphs.py'), klr: join(HERE, 'klr_map_graphs.py') };

// An image's key: the start of the SHA-256 of its 8 KB as loaded (the
// same as map_graphs.py and rom_stamp.py), so a renamed file keeps its key
function imageSha(path) {
  try {
    const img = /\.mem$/i.test(path) ? parseMem(readFileSync(path, 'utf8'))
                                     : Buffer.concat([readFileSync(path), Buffer.alloc(8192, 0xFF)]).subarray(0, 8192);
    return img ? createHash('sha256').update(img).digest('hex').slice(0, 16) : null;
  } catch { return null; }
}
// Images the bridge can draw for a log that names one by hash: the repo's
// bin_images/<cpu> and the ones uploaded through /rom
function findImage(sha, cpu) {
  for (const dir of [IMAGES[cpu], join(ROM_DIR, cpu), ...savedDirs(cpu)]) {
    let names = [];
    try { names = readdirSync(dir); } catch { continue; }
    for (const n of names) {
      if (!/\.(mem|bin)$/i.test(n)) continue;
      const p = join(dir, n);
      if (imageSha(p) === sha) return p;
    }
  }
  return null;
}

// The same by file name, for a log that names its image but has no hash
// (a saved edited image: bin_images/<cpu>/edited/<name>/<name>.mem|.bin)
function findImageByName(name, cpu) {
  if (!name || name !== basename(name)) return null;
  const saved = join(SAVED[cpu], name.replace(/\.(mem|bin)$/i, ''));
  for (const dir of [IMAGES[cpu], join(ROM_DIR, cpu), join(PATCH_DIR, cpu), saved]) {
    const p = join(dir, name);
    if (existsSync(p)) return p;
  }
  return null;
}

// One entry per CPU and image hash ('dme:<sha>' / 'klr:<sha>'):
// { cpu, status: generating|ready|error, rom, path, error, index }.
// map_graphs.py (DME) / klr_map_graphs.py (KLR) run one image at a time;
// the rest wait in mapQueue. Both draw into MAP_CACHE/<sha>/ (the images
// differ, so their hashes do).
const mapJobs = new Map();
const mapQueue = [];
let mapBusy = false;
const loadedSha = { dme: null, klr: null };   // the images the sim has loaded

// recheck: run the generator again even for an image drawn before (each time
// the sim reports its ROM), so graphs from an older map_graphs.py /
// klr_map_graphs.py (GEN_VERSION) are redrawn after a pull without a bridge
// restart; an up-to-date image comes back "cached" in a fraction of a second.
function drawMaps(path, sha = imageSha(path), cpu = 'dme', recheck = false) {
  if (!path || !sha) return null;
  const key = `${cpu}:${sha}`;
  const job = mapJobs.get(key);
  if (job && job.status === 'generating') return job;
  if (job && job.status === 'ready' && !recheck) return job;
  if (job && job.status === 'ready') {
    if (!mapQueue.includes(key)) { mapQueue.push(key); runMapQueue(); }
    return job;
  }
  const j = { cpu, status: 'generating', rom: basename(path), path, error: null, index: null };
  mapJobs.set(key, j);
  mapQueue.push(key);
  runMapQueue();
  return j;
}

function runMapQueue() {
  if (mapBusy || !mapQueue.length) return;
  const key = mapQueue.shift();
  const job = mapJobs.get(key);
  const sha = key.slice(4);
  mapBusy = true;
  console.log(`bridge: ${job.cpu} map graphs for ${job.rom} (${sha}) -> ${MAP_CACHE}`);
  const proc = spawn(PY, [MAP_GRAPHS[job.cpu], job.path, '--cache', MAP_CACHE], { stdio: ['ignore', 'pipe', 'pipe'] });
  let out = '', err = '', finished = false;
  proc.stdout.on('data', d => { out += d; });
  proc.stderr.on('data', d => { err += d; });
  const done = (error) => {
    if (finished) return;
    finished = true;
    const m = out.trim().split('\n').pop()?.match(/^([0-9a-f]{16}) (.+) (cached|generated)$/);
    if (!error && m) {
      try {
        job.index = JSON.parse(readFileSync(join(m[2], 'index.json'), 'utf8'));
        job.status = 'ready';
        console.log(`bridge: map graphs ${m[3]} for ${job.rom} (${m[1]})`);
        broadcast(`SIM: [MAPS] ${job.cpu} ready ${m[1]}`);
      } catch (e) { error = `couldn't read the graph index: ${e.message}`; }
    }
    if (error || !m) {
      job.status = 'error';
      job.error = (error || err.trim() || out.trim() || 'map_graphs.py failed').slice(-2000);
      console.error(`bridge: map graphs failed: ${job.error}`);
    }
    mapBusy = false;
    runMapQueue();
  };
  proc.on('error', e => done(`couldn't run python3: ${e.message}`));
  proc.on('exit', code => { if (code !== null) done(code === 0 ? null : (err.trim() || `map_graphs.py exited with ${code}`)); });
}

// GET /maps/<cpu>[?sha=<hash>|?name=<file>]: the graphs of that image, or of the loaded one
function mapsInfo(sha, cpu = 'dme', name = null) {
  if (!sha && name) {
    const path = findImageByName(name, cpu);
    const s = path && imageSha(path);
    if (!s) return { status: 'unknown', sha: null, name, loaded: loadedSha[cpu], rom: name, error: null,
                     version: null, maps: {}, tables: {} };
    sha = s;
    if (!mapJobs.get(`${cpu}:${sha}`)) drawMaps(path, sha, cpu);
  }
  const want = sha ?? loadedSha[cpu];
  const reply = (status, job = {}) => ({ status, sha: want, loaded: loadedSha[cpu], rom: job.rom ?? null, error: job.error ?? null,
                                         version: job.index?.version ?? null,
                                         maps: job.index?.maps ?? {}, tables: job.index?.tables ?? {} });
  if (!want) return reply('none');
  let job = mapJobs.get(`${cpu}:${want}`);
  if (!job && sha) {
    const path = findImage(sha, cpu);
    if (path) job = drawMaps(path, sha, cpu);
    else {
      // Not on this machine any more, but drawn before
      try {
        const index = JSON.parse(readFileSync(join(MAP_CACHE, sha, 'index.json'), 'utf8'));
        return reply('ready', { rom: index.rom, index });
      } catch { return reply('unknown'); }
    }
  }
  return job ? reply(job.status, job) : reply('none');
}

// ── The dashboard, offline ───────────────────────────────────
// The lite package carries a build of the dashboard (dme-dashboard's
// npm run build:lite) in dashboard/; the bridge serves it at its root, so
// the package needs no network. --dashboard DIR serves another build. In
// the developer install, dashboard/ is the dme-dashboard checkout: its
// dist-lite/ is served once built (npm run build:lite), never its source.
const DASH = (() => {
  const d = resolve(arg('dashboard', join(REPO, 'dashboard')));
  for (const c of [d, join(d, 'dist-lite')]) {
    if (existsSync(join(c, 'index.html')) && !existsSync(join(c, 'package.json'))) return c;
  }
  return null;
})();
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.woff2': 'font/woff2', '.txt': 'text/plain; charset=utf-8',
  '.ico': 'image/x-icon',
};
function serveDashboard(pathname, res) {
  let rel;
  try { rel = decodeURIComponent(pathname); } catch { return false; }
  if (rel === '/' || rel === '') rel = '/index.html';
  const file = resolve(DASH, '.' + rel);
  if (file !== DASH && !file.startsWith(DASH + (process.platform === 'win32' ? '\\' : '/'))) return false;
  let st;
  try { st = statSync(file); } catch { return false; }
  if (!st.isFile()) return false;
  const ext = (file.match(/\.[^./\\]+$/) || [''])[0].toLowerCase();
  res.writeHead(200, {
    'Content-Type': MIME[ext] || 'application/octet-stream',
    // the hashed assets never change; index.html is checked each time
    'Cache-Control': rel === '/index.html' ? 'no-cache' : 'max-age=31536000, immutable',
  });
  res.end(readFileSync(file));
  return true;
}

// ── HTTP ─────────────────────────────────────────────────────
// Only these page origins may use the bridge: the published dashboard
// and a dev server on this machine (--allow-origin adds more). Requests
// from any other page are refused with 403 *before* doing anything,
// since a plain-text POST from another site would otherwise still run
// its command even though the browser hides the response. Requests
// without an Origin header (curl, a terminal) are allowed.
// The dashboard's RUN REGRESSIONS panel: run_all.sh / run_tests.py (runall.mjs)
// This bridge as a regression host for another machine's runs
// (regress_host.mjs): --listen <addr> opens it to the LAN, --token (or
// $DMEKLR_REGRESS_TOKEN) is the secret the other machine must send
const LISTEN = arg('listen', '127.0.0.1');
const TOKEN = arg('token', process.env.DMEKLR_REGRESS_TOKEN || '');
if (!loopback(LISTEN) && LISTEN !== 'localhost' && TOKEN.length < 8) {
  console.error(`bridge: --listen ${LISTEN} opens this bridge to other machines: give it --token <secret> (8 characters or more)`);
  process.exit(1);
}
const regressHost = makeRegressHost({ REPO, TMP_ROOT, PY });
const runAll = makeRunAll({
  REPO, HERE, TMP_ROOT, PY,
  // the whole .mem images, from bin_images/<cpu> and the uploads
  // (not the scratch images of byte edits: SAVE AS in the list of edits keeps one)
  romImages: cpu => compareImages(cpu).filter(i => /\.mem$/i.test(i.name) && i.src !== 'edited')
    .map(i => ({ name: i.name, src: i.src, dir: i.dir })),
  // the image setups saved from the dashboard, offered as ROM pairs
  setups: customSetups,
});

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
  // Another machine (with --listen): only the regression-host requests,
  // with the token, from a LAN address
  const peer = req.socket.remoteAddress;
  if (!loopback(peer)) {
    const auth = (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '');
    if (!url.pathname.startsWith('/regress/') || !lanAddress(peer) || !tokenOk(auth, TOKEN)) {
      console.log(`bridge: refused ${req.method} ${url.pathname} from ${peer}`);
      res.writeHead(403);
      return res.end('not allowed from another machine');
    }
    return regressHost.handle(req, res, url) || (res.writeHead(404), res.end());
  }
  if (url.pathname.startsWith('/regress/') && regressHost.handle(req, res, url)) return;
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
    // POST /snapshots/test  body {"test": name, "ms": time, "label": text, "roms": {dme, klr}}:
    // a regression-test snapshot at a moment picked by hand (test_snap.py add).
    // It runs on the images in roms (file names, as in the image lists), else
    // on the ones loaded in the sim now (a custom image or setup loaded from
    // the ROM IMAGES row), not the bridge's DME_ROM_FILE defaults
    if (req.method === 'POST' && rawId === 'test' && !action) {
      let body = '';
      req.on('data', d => { body += d; if (body.length > 4096) req.destroy(); });
      req.on('end', () => {
        let b;
        try { b = JSON.parse(body); } catch { return text(400, 'body must be JSON {test, ms, label}'); }
        if (!snapId(b?.test ?? '') || !(+b.ms >= 0)) return text(400, 'need a test name and a time in ms');
        const env = { ...process.env, DMEKLR_SNAPDIR: SNAP_DIR };
        for (const cpu of ['dme', 'klr']) {
          const want = b.roms?.[cpu];
          const p = want ? findImageByName(basename(String(want)), cpu) : roms[cpu];
          if (want && !p) return text(400, `no ${cpu.toUpperCase()} image ${want}`);
          if (p && existsSync(p)) {
            env[`${cpu.toUpperCase()}_ROM_DIR`] = dirname(resolve(p)) + '/';
            env[`${cpu.toUpperCase()}_ROM_FILE`] = basename(p);
          }
        }
        const r = spawnSync(PY, [join(HERE, 'test_snap.py'), 'add', b.test, String(+b.ms),
                                        ...String(b.label ?? '').split(/\s+/).filter(Boolean)],
                            { env, encoding: 'utf8' });
        if (r.status !== 0) return text(400, (r.stderr || r.stdout || 'test_snap.py failed').trim());
        broadcast('SIM: [SNAP] ready id=- t_ns=0 reason=test');
        return text(204, '');
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
  // ── /logs ──────────────────────────────────────────────────
  if (req.method === 'GET' && url.pathname === '/logs') {
    res.writeHead(200, { ...CORS, 'Content-Type': 'application/json', 'Cache-Control': 'no-cache' });
    return res.end(JSON.stringify(listLogs()));
  }
  const log = url.pathname.match(/^\/logs\/(?:([^/]+)\/)?([^/]+)\/([^/]+)$/);
  if (req.method === 'GET' && log) {
    let rom, name;
    try { rom = log[1] == null ? null : decodeURIComponent(log[1]); name = decodeURIComponent(log[3]); } catch { name = ''; }
    const folder = logFolder(rom, log[2]);
    const file = folder && logNameOk(name) && join(folder, name);
    if (!file || !existsSync(file)) { res.writeHead(404, CORS); return res.end(`no log ${url.pathname.slice(6)}`); }
    res.writeHead(200, { ...CORS, 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-cache' });
    return res.end(readFileSync(file));
  }
  const cmp = url.pathname.match(/^\/compare\/(dme|klr)(\/images|\/variants)?$/);
  if (req.method === 'GET' && cmp) {
    const send = (code, body, type = 'text/plain') => {
      res.writeHead(code, { ...CORS, 'Content-Type': type, 'Cache-Control': 'no-cache' });
      res.end(body);
    };
    const nameOk = n => n && /^[\w.+-]+\.(mem|bin)$/i.test(n);
    if (cmp[2] === '/images') return send(200, JSON.stringify(compareImages(cmp[1]).map(({ dir, ...i }) => i)), 'application/json');
    if (cmp[2] === '/variants') {
      const ref = url.searchParams.get('ref');
      if (ref !== null && !nameOk(ref)) return send(400, 'ref must be an image file name');
      return compareVariants(cmp[1], ref, send);
    }
    const a = url.searchParams.get('a'), b = url.searchParams.get('b');
    const ok = n => n && /^[\w.+-]+\.(mem|bin)$/i.test(n);
    if (!ok(a) || !ok(b)) return send(400, 'a and b must be image file names');
    return compareRoms(cmp[1], a, b, url.searchParams.get('all') === '1', send);
  }
  const mapsCpu = url.pathname.match(/^\/maps\/(dme|klr)$/);
  if (req.method === 'GET' && mapsCpu) {
    const sha = url.searchParams.get('sha');
    if (sha !== null && !/^[0-9a-f]{16}$/.test(sha)) { res.writeHead(400, CORS); return res.end('sha must be 16 hex digits'); }
    // A file name only, never a path: looked up in bin_images/<cpu> and the uploads
    const name = url.searchParams.get('name');
    if (name !== null && !/^[\w.+-]+\.(mem|bin)$/i.test(name)) { res.writeHead(400, CORS); return res.end('name must be an image file name'); }
    res.writeHead(200, { ...CORS, 'Content-Type': 'application/json', 'Cache-Control': 'no-cache' });
    return res.end(JSON.stringify(mapsInfo(sha, mapsCpu[1], name)));
  }
  const graph = url.pathname.match(/^\/maps\/(?:dme|klr)\/([0-9a-f]{16})\/([MT][0-9A-F]{1,4}\.png)$/);
  if (req.method === 'GET' && graph) {
    const file = join(MAP_CACHE, graph[1], graph[2]);
    if (!existsSync(file)) { res.writeHead(404, CORS); return res.end(); }
    // Named by the image's hash, so a graph never changes
    res.writeHead(200, { ...CORS, 'Content-Type': 'image/png', 'Cache-Control': 'max-age=31536000, immutable' });
    return res.end(readFileSync(file));
  }
  if (req.method === 'GET' && url.pathname.startsWith('/asm/')) {
    const cpu = url.pathname.slice(5);
    if (!ASM[cpu]) { res.writeHead(404, CORS); return res.end(); }
    res.writeHead(200, { ...CORS, 'Content-Type': 'application/json' });
    return res.end(JSON.stringify(ASM[cpu]));
  }
  const readBody = (max, done) => {
    let body = '';
    req.on('data', d => { body += d; if (body.length > max) req.destroy(); });
    req.on('end', () => done(body));
  };
  const reply = ([code, body]) => {
    const isJson = code === 200 && typeof body !== 'string';
    res.writeHead(code, { ...CORS, 'Content-Type': isJson ? 'application/json' : 'text/plain', 'Cache-Control': 'no-cache' });
    res.end(isJson ? JSON.stringify(body) : body);
  };
  const saveAs = url.pathname.match(/^\/edits\/(dme|klr)\/save$/);
  if (req.method === 'POST' && saveAs) return readBody(4096, b => reply(saveEdited(saveAs[1], b)));
  if (url.pathname === '/setups') {
    if (req.method === 'GET') return reply([200, listSetups()]);
    if (req.method === 'POST') return readBody(4096, b => reply(saveSetup(b)));
  }
  const setup = url.pathname.match(/^\/setups\/([^/]+)(\/load)?$/);
  if (setup) {
    let name;
    try { name = decodeURIComponent(setup[1]); } catch { return reply([400, 'bad setup name']); }
    if (req.method === 'DELETE' && !setup[2]) return reply(deleteSetup(name));
    if (req.method === 'POST' && setup[2]) return reply(loadSetup(name, url.searchParams.get('reset') === '1'));
  }
  const bin = url.pathname.match(/^\/image\/(dme|klr)\.bin$/);
  if (req.method === 'GET' && bin) {
    const [code, body, file] = imageBin(bin[1], url.searchParams.get('name'));
    if (code !== 200) return reply([code, body]);
    res.writeHead(200, { ...CORS, 'Content-Type': 'application/octet-stream', 'Cache-Control': 'no-cache',
                         'Content-Disposition': `attachment; filename="${file}"`, 'Access-Control-Expose-Headers': 'Content-Disposition' });
    return res.end(body);
  }
  const edits = url.pathname.match(/^\/edits\/(dme|klr)$/);
  if (req.method === 'GET' && edits) {
    const [code, body] = editsFor(edits[1], url.searchParams.get('name'));
    res.writeHead(code, { ...CORS, 'Content-Type': code === 200 ? 'application/json' : 'text/plain', 'Cache-Control': 'no-cache' });
    return res.end(code === 200 ? JSON.stringify(body) : body);
  }
  if (req.method === 'POST' && url.pathname === '/patch') {
    let body = '';
    req.on('data', d => { body += d; if (body.length > 4096) req.destroy(); });
    req.on('end', () => {
      const [code, text] = patchRom(url.searchParams.get('cpu'), body);
      res.writeHead(code, CORS);
      res.end(text);
    });
    return;
  }
  if (req.method === 'POST' && (url.pathname === '/cmd' || url.pathname === '/restart' || url.pathname === '/rom')) {
    const chunks = [];
    let size = 0;
    const max = url.pathname === '/rom' ? ROM_MAX : 1e5;
    req.on('data', d => { chunks.push(d); size += d.length; if (size > max) req.destroy(); });
    req.on('end', () => {
      // a ROM may be a raw binary, so it stays bytes; the rest is text
      const raw = Buffer.concat(chunks);
      const body = raw.toString('utf8');
      if (url.pathname === '/rom') {
        const [code, text] = loadRom(url, raw);
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
  if (url.pathname.startsWith('/runall') && runAll.handle(req, res, url, CORS)) return;
  if (req.method === 'GET' && DASH && serveDashboard(url.pathname, res)) return;
  res.writeHead(404, CORS);
  res.end();
}).listen(PORT, LISTEN, () => {
  console.log(`bridge: http://127.0.0.1:${PORT}  sim=${SIM}`);
  if (!loopback(LISTEN) && LISTEN !== 'localhost')
    console.log(`bridge: regression host for other machines on the LAN at ${LISTEN}:${PORT} (token required), software ${regressHost.running.version} (srchash ${regressHost.running.srchash})`);
  if (DASH) console.log(`bridge: dashboard (offline copy) at http://127.0.0.1:${PORT}/?live`);
  console.log(`bridge: asm listings dme=${ASM.dme.length} klr=${ASM.klr.length} lines`);
  startSim();
});

process.on('SIGINT', () => { runAll.stop(); runAll.stopInstallTests(); regressHost.stopAll(); if (sim) sim.kill(); process.exit(0); });
