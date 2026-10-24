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
//    GET  /asm/dme    JSON disassembly listing (same data as the vcd.v /
//    GET  /asm/klr    klr_vcd.v asm_debug group): [{a,label,instr,ops,bytes}]
//                     (dme rows also carry num: operands as raw addresses;
//                     rows may carry desc from asm_full.json)
//
//  Only listens on 127.0.0.1, and only pages from whalenlg.github.io,
//  localhost or 127.0.0.1 may use it (see ALLOWED below).
//
//  Usage:  node bridge.mjs [--port 8951] [--sim obj/dme_klr_live]
//                          [--dme-asm <dir>] [--klr-asm <dir>]
//                          [--allow-origin <https://other.origin>]
// ============================================================
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
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
const DME_ASM = resolve(arg('dme-asm', join(REPO, 'disassemble')));
const KLR_ASM = resolve(arg('klr-asm', join(REPO, 'bin_images', 'klr')));
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

function startSim() {
  if (!existsSync(SIM)) {
    console.error(`Simulator not found: ${SIM}\nBuild it with ./build_live.sh`);
    process.exit(1);
  }
  history = [];
  broadcast('SIM: [RESTART]');
  simState = 'paused';
  const romArgs = Object.entries(roms).filter(([, p]) => p).map(([cpu, p]) => `+${cpu}_rom=${p}`);
  // Run from obj/ so the testbench's $writememh / sim.vcd land there
  sim = spawn(SIM, ['+vcd=/dev/null', ...romArgs], { cwd: dirname(SIM), stdio: ['pipe', 'pipe', 'pipe'] });
  const proc = sim;
  const onLine = line => {
    const st = line.match(/^SIM: \[STATE\] (\w+)/);
    if (st) simState = st[1];
    const rom = line.match(/^SIM: \[ROM\] (dme|klr) (.+)$/);
    if (rom) roms[rom[1]] = rom[2];
    if (FORWARD.test(line)) broadcast(line);
    else if (!line.startsWith('-Info')) console.log(line);
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

function restartSim() {
  if (sim) { const old = sim; sim = null; old.kill(); }
  startSim();
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
const ASM = {
  dme: listing(DME_ASM, 'asm_operand_mapped.hex', 'asm_operands_numeric.hex'),
  klr: listing(KLR_ASM, 'asm_operands.hex'),
};
// The hex tables cut labels and operands at 20 characters; asm_full.json (written by
// asm_full.py from the same spreadsheets) has them in full, plus the
// spreadsheet's descriptions. Used only where it agrees with the hex table.
const FULL = join(HERE, 'asm_full.json');
if (existsSync(FULL)) {
  const full = JSON.parse(readFileSync(FULL, 'utf8'));
  for (const cpu of ['dme', 'klr'])
    for (const r of ASM[cpu]) {
      const e = full[cpu]?.[r.a];
      if (!e || e.ops.slice(0, 20).trim() !== r.ops) continue;
      r.ops = e.ops;
      if (e.label && e.label.slice(0, 20).trim() === r.label) r.label = e.label;
      if (e.num != null && 'num' in r) r.num = e.num;
      if (e.desc) r.desc = e.desc;
    }
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
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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
