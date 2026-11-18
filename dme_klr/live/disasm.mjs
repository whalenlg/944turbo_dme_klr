// ============================================================
//  disasm.mjs — 8051 (DME) and 8048 (KLR) instruction decoders, and
//  the debugger listing redone where the bytes of an image were edited.
//
//  The decoders are dme/disassemble/dis8051.py and
//  klr/disassemble/dis8048.py in JavaScript (same tables, same operand
//  kinds). patchListing() takes the listing made from a workbook for
//  the unedited image and decodes again from the instruction holding each
//  edited byte until the code lines up with the listing again, so a
//  changed opcode, operand or address shows its new mnemonic and
//  operands, and an instruction that got longer or shorter re-flows the
//  lines after it. Labels, register names and descriptions come from the
//  listing wherever it still applies.
// ============================================================

// ── 8051 ────────────────────────────────────────────────────
// op -> [mnemonic, length, operand spec]; a spec item is literal text
// (a register) or one of a11 a16 rel dir bit nbit imm imm16 dirdir
const T51 = (() => {
  const t = {};
  const R = n => `R${n}`, IR = n => `@R${n}`;
  for (let i = 0; i < 8; i++) {
    t[i * 0x20 + 0x01] = ['ajmp', 2, ['a11']];
    t[i * 0x20 + 0x11] = ['acall', 2, ['a11']];
  }
  Object.assign(t, {
    0x00: ['nop', 1, []], 0x02: ['ljmp', 3, ['a16']], 0x03: ['rr', 1, ['A']],
    0x04: ['inc', 1, ['A']], 0x05: ['inc', 2, ['dir']],
    0x10: ['jbc', 3, ['bit', 'rel']], 0x12: ['lcall', 3, ['a16']], 0x13: ['rrc', 1, ['A']],
    0x14: ['dec', 1, ['A']], 0x15: ['dec', 2, ['dir']],
    0x20: ['jb', 3, ['bit', 'rel']], 0x22: ['ret', 1, []], 0x23: ['rl', 1, ['A']],
    0x24: ['add', 2, ['A', 'imm']], 0x25: ['add', 2, ['A', 'dir']],
    0x30: ['jnb', 3, ['bit', 'rel']], 0x32: ['reti', 1, []], 0x33: ['rlc', 1, ['A']],
    0x34: ['addc', 2, ['A', 'imm']], 0x35: ['addc', 2, ['A', 'dir']],
    0x40: ['jc', 2, ['rel']], 0x42: ['orl', 2, ['dir', 'A']], 0x43: ['orl', 3, ['dir', 'imm']],
    0x44: ['orl', 2, ['A', 'imm']], 0x45: ['orl', 2, ['A', 'dir']],
    0x50: ['jnc', 2, ['rel']], 0x52: ['anl', 2, ['dir', 'A']], 0x53: ['anl', 3, ['dir', 'imm']],
    0x54: ['anl', 2, ['A', 'imm']], 0x55: ['anl', 2, ['A', 'dir']],
    0x60: ['jz', 2, ['rel']], 0x62: ['xrl', 2, ['dir', 'A']], 0x63: ['xrl', 3, ['dir', 'imm']],
    0x64: ['xrl', 2, ['A', 'imm']], 0x65: ['xrl', 2, ['A', 'dir']],
    0x70: ['jnz', 2, ['rel']], 0x72: ['orl', 2, ['C', 'bit']],
    0x73: ['jmp', 1, ['@A+DPTR']], 0x74: ['mov', 2, ['A', 'imm']], 0x75: ['mov', 3, ['dir', 'imm']],
    0x80: ['sjmp', 2, ['rel']], 0x82: ['anl', 2, ['C', 'bit']],
    0x83: ['movc', 1, ['A', '@A+PC']], 0x84: ['div', 1, ['AB']],
    0x85: ['mov', 3, ['dirdir']],
    0x90: ['mov', 3, ['DPTR', 'imm16']], 0x92: ['mov', 2, ['bit', 'C']],
    0x93: ['movc', 1, ['A', '@A+DPTR']], 0x94: ['subb', 2, ['A', 'imm']], 0x95: ['subb', 2, ['A', 'dir']],
    0xA0: ['orl', 2, ['C', 'nbit']], 0xA2: ['mov', 2, ['C', 'bit']],
    0xA3: ['inc', 1, ['DPTR']], 0xA4: ['mul', 1, ['AB']], 0xA5: ['???', 1, []],
    0xB0: ['anl', 2, ['C', 'nbit']], 0xB2: ['cpl', 2, ['bit']], 0xB3: ['cpl', 1, ['C']],
    0xB4: ['cjne', 3, ['A', 'imm', 'rel']], 0xB5: ['cjne', 3, ['A', 'dir', 'rel']],
    0xC0: ['push', 2, ['dir']], 0xC2: ['clr', 2, ['bit']], 0xC3: ['clr', 1, ['C']],
    0xC4: ['swap', 1, ['A']], 0xC5: ['xch', 2, ['A', 'dir']],
    0xD0: ['pop', 2, ['dir']], 0xD2: ['setb', 2, ['bit']], 0xD3: ['setb', 1, ['C']],
    0xD4: ['da', 1, ['A']], 0xD5: ['djnz', 3, ['dir', 'rel']],
    0xE0: ['movx', 1, ['A', '@DPTR']], 0xE4: ['clr', 1, ['A']], 0xE5: ['mov', 2, ['A', 'dir']],
    0xF0: ['movx', 1, ['@DPTR', 'A']], 0xF4: ['cpl', 1, ['A']], 0xF5: ['mov', 2, ['dir', 'A']],
  });
  for (let i = 0; i < 2; i++) {
    const r = IR(i);
    Object.assign(t, {
      [0x06 + i]: ['inc', 1, [r]], [0x16 + i]: ['dec', 1, [r]],
      [0x26 + i]: ['add', 1, ['A', r]], [0x36 + i]: ['addc', 1, ['A', r]],
      [0x46 + i]: ['orl', 1, ['A', r]], [0x56 + i]: ['anl', 1, ['A', r]],
      [0x66 + i]: ['xrl', 1, ['A', r]], [0x76 + i]: ['mov', 2, [r, 'imm']],
      [0x86 + i]: ['mov', 2, ['dir', r]], [0x96 + i]: ['subb', 1, ['A', r]],
      [0xA6 + i]: ['mov', 2, [r, 'dir']], [0xB6 + i]: ['cjne', 3, [r, 'imm', 'rel']],
      [0xC6 + i]: ['xch', 1, ['A', r]], [0xD6 + i]: ['xchd', 1, ['A', r]],
      [0xE2 + i]: ['movx', 1, ['A', r]], [0xE6 + i]: ['mov', 1, ['A', r]],
      [0xF2 + i]: ['movx', 1, [r, 'A']], [0xF6 + i]: ['mov', 1, [r, 'A']],
    });
  }
  for (let n = 0; n < 8; n++) {
    const r = R(n);
    Object.assign(t, {
      [0x08 + n]: ['inc', 1, [r]], [0x18 + n]: ['dec', 1, [r]],
      [0x28 + n]: ['add', 1, ['A', r]], [0x38 + n]: ['addc', 1, ['A', r]],
      [0x48 + n]: ['orl', 1, ['A', r]], [0x58 + n]: ['anl', 1, ['A', r]],
      [0x68 + n]: ['xrl', 1, ['A', r]], [0x78 + n]: ['mov', 2, [r, 'imm']],
      [0x88 + n]: ['mov', 2, ['dir', r]], [0x98 + n]: ['subb', 1, ['A', r]],
      [0xA8 + n]: ['mov', 2, [r, 'dir']], [0xB8 + n]: ['cjne', 3, [r, 'imm', 'rel']],
      [0xC8 + n]: ['xch', 1, ['A', r]], [0xD8 + n]: ['djnz', 2, [r, 'rel']],
      [0xE8 + n]: ['mov', 1, ['A', r]], [0xF8 + n]: ['mov', 1, [r, 'A']],
    });
  }
  return t;
})();

const SPEC51 = new Set(['a11', 'a16', 'rel', 'dir', 'bit', 'nbit', 'imm', 'imm16', 'dirdir']);

// { mn, len, b: [bytes], args: [[kind, value]] }, as dis8051.decode
export function decode8051(mem, pc) {
  const op = mem[pc];
  const [mn, len, spec] = T51[op];
  const b = Array.from({ length: len }, (_, i) => mem[pc + i] ?? 0);
  const args = [];
  let idx = 1;
  for (const s of spec) {
    if (!SPEC51.has(s)) args.push(['reg', s]);
    else if (s === 'a11') { args.push(['code', ((pc + 2) & 0xF800) | ((op & 0xE0) << 3) | b[1]]); idx++; }
    else if (s === 'a16') { args.push(['code', (b[1] << 8) | b[2]]); idx += 2; }
    else if (s === 'rel') { const r = b[idx] > 127 ? b[idx] - 256 : b[idx]; args.push(['code', (pc + len + r) & 0xFFFF]); idx++; }
    else if (s === 'dirdir') { args.push(['dir', b[2]], ['dir', b[1]]); idx += 2; }   // 85 src dst -> mov dst, src
    else if (s === 'imm16') { args.push(['imm16', (b[idx] << 8) | b[idx + 1]]); idx += 2; }
    else { args.push([s, b[idx]]); idx++; }
  }
  return { mn, len, b, args };
}

// ── 8048 ────────────────────────────────────────────────────
const T48 = (() => {
  const t = {};
  for (let p = 0; p < 8; p++) {
    t[(p << 5) | 0x04] = ['jmp', 2, ['a11']];
    t[(p << 5) | 0x14] = ['call', 2, ['a11']];
  }
  Object.assign(t, {
    0x00: ['nop', 1, []], 0x02: ['outl', 1, ['bus', 'a']], 0x03: ['add', 2, ['a', 'imm']],
    0x05: ['en', 1, ['i']], 0x07: ['dec', 1, ['a']], 0x08: ['ins', 1, ['a', 'bus']],
    0x09: ['in', 1, ['a', 'p1']], 0x0A: ['in', 1, ['a', 'p2']],
    0x0C: ['movd', 1, ['a', 'p4']], 0x0D: ['movd', 1, ['a', 'p5']],
    0x0E: ['movd', 1, ['a', 'p6']], 0x0F: ['movd', 1, ['a', 'p7']],
    0x12: ['jb0', 2, ['page']], 0x13: ['addc', 2, ['a', 'imm']], 0x15: ['dis', 1, ['i']],
    0x16: ['jtf', 2, ['page']], 0x17: ['inc', 1, ['a']],
    0x23: ['mov', 2, ['a', 'imm']], 0x25: ['en', 1, ['tcnti']], 0x26: ['jnt0', 2, ['page']],
    0x27: ['clr', 1, ['a']],
    0x32: ['jb1', 2, ['page']], 0x35: ['dis', 1, ['tcnti']], 0x36: ['jt0', 2, ['page']],
    0x37: ['cpl', 1, ['a']], 0x39: ['outl', 1, ['p1', 'a']], 0x3A: ['outl', 1, ['p2', 'a']],
    0x3C: ['movd', 1, ['p4', 'a']], 0x3D: ['movd', 1, ['p5', 'a']],
    0x3E: ['movd', 1, ['p6', 'a']], 0x3F: ['movd', 1, ['p7', 'a']],
    0x42: ['mov', 1, ['a', 't']], 0x43: ['orl', 2, ['a', 'imm']], 0x45: ['strt', 1, ['cnt']],
    0x46: ['jnt1', 2, ['page']], 0x47: ['swap', 1, ['a']],
    0x52: ['jb2', 2, ['page']], 0x53: ['anl', 2, ['a', 'imm']], 0x55: ['strt', 1, ['t']],
    0x56: ['jt1', 2, ['page']], 0x57: ['da', 1, ['a']],
    0x62: ['mov', 1, ['t', 'a']], 0x65: ['stop', 1, ['tcnt']], 0x67: ['rrc', 1, ['a']],
    0x72: ['jb3', 2, ['page']], 0x75: ['ent0', 1, ['clk']], 0x76: ['jf1', 2, ['page']],
    0x77: ['rr', 1, ['a']],
    0x83: ['ret', 1, []], 0x85: ['clr', 1, ['f0']], 0x86: ['jni', 2, ['page']],
    0x88: ['orl', 2, ['bus', 'imm']], 0x89: ['orl', 2, ['p1', 'imm']], 0x8A: ['orl', 2, ['p2', 'imm']],
    0x8C: ['orld', 1, ['p4', 'a']], 0x8D: ['orld', 1, ['p5', 'a']],
    0x8E: ['orld', 1, ['p6', 'a']], 0x8F: ['orld', 1, ['p7', 'a']],
    0x92: ['jb4', 2, ['page']], 0x93: ['retr', 1, []], 0x95: ['cpl', 1, ['f0']],
    0x96: ['jnz', 2, ['page']], 0x97: ['clr', 1, ['c']],
    0x98: ['anl', 2, ['bus', 'imm']], 0x99: ['anl', 2, ['p1', 'imm']], 0x9A: ['anl', 2, ['p2', 'imm']],
    0x9C: ['anld', 1, ['p4', 'a']], 0x9D: ['anld', 1, ['p5', 'a']],
    0x9E: ['anld', 1, ['p6', 'a']], 0x9F: ['anld', 1, ['p7', 'a']],
    0xA3: ['movp', 1, ['a', '@a']], 0xA5: ['clr', 1, ['f1']], 0xA7: ['cpl', 1, ['c']],
    0xB2: ['jb5', 2, ['page']], 0xB3: ['jmpp', 1, ['@a']], 0xB5: ['cpl', 1, ['f1']],
    0xB6: ['jf0', 2, ['page']],
    0xC5: ['sel', 1, ['rb0']], 0xC6: ['jz', 2, ['page']], 0xC7: ['mov', 1, ['a', 'psw']],
    0xD2: ['jb6', 2, ['page']], 0xD3: ['xrl', 2, ['a', 'imm']], 0xD5: ['sel', 1, ['rb1']],
    0xD7: ['mov', 1, ['psw', 'a']],
    0xE3: ['movp3', 1, ['a', '@a']], 0xE5: ['sel', 1, ['mb0']], 0xE6: ['jnc', 2, ['page']],
    0xE7: ['rl', 1, ['a']],
    0xF2: ['jb7', 2, ['page']], 0xF5: ['sel', 1, ['mb1']], 0xF6: ['jc', 2, ['page']],
    0xF7: ['rlc', 1, ['a']],
  });
  for (let i = 0; i < 2; i++) {
    const r = `@r${i}`;
    Object.assign(t, {
      [0x10 + i]: ['inc', 1, [r]], [0x20 + i]: ['xch', 1, ['a', r]],
      [0x30 + i]: ['xchd', 1, ['a', r]], [0x40 + i]: ['orl', 1, ['a', r]],
      [0x50 + i]: ['anl', 1, ['a', r]], [0x60 + i]: ['add', 1, ['a', r]],
      [0x70 + i]: ['addc', 1, ['a', r]], [0x80 + i]: ['movx', 1, ['a', r]],
      [0x90 + i]: ['movx', 1, [r, 'a']], [0xA0 + i]: ['mov', 1, [r, 'a']],
      [0xB0 + i]: ['mov', 2, [r, 'imm']], [0xD0 + i]: ['xrl', 1, ['a', r]],
      [0xF0 + i]: ['mov', 1, ['a', r]],
    });
  }
  for (let n = 0; n < 8; n++) {
    const r = `r${n}`;
    Object.assign(t, {
      [0x18 + n]: ['inc', 1, [r]], [0x28 + n]: ['xch', 1, ['a', r]],
      [0x48 + n]: ['orl', 1, ['a', r]], [0x58 + n]: ['anl', 1, ['a', r]],
      [0x68 + n]: ['add', 1, ['a', r]], [0x78 + n]: ['addc', 1, ['a', r]],
      [0xA8 + n]: ['mov', 1, [r, 'a']], [0xB8 + n]: ['mov', 2, [r, 'imm']],
      [0xC8 + n]: ['dec', 1, [r]], [0xD8 + n]: ['xrl', 1, ['a', r]],
      [0xE8 + n]: ['djnz', 2, [r, 'page']], [0xF8 + n]: ['mov', 1, ['a', r]],
    });
  }
  return t;
})();

// As dis8048.decode: an unused opcode is a one-byte .db
export function decode8048(mem, pc) {
  const op = mem[pc];
  if (!T48[op]) return { mn: '.db', len: 1, b: [op], args: [['reg', `0x${h2(op).toLowerCase()}`]] };
  const [mn, len, spec] = T48[op];
  const b = Array.from({ length: len }, (_, i) => mem[pc + i] ?? 0);
  const args = spec.map(s =>
    s === 'imm'  ? ['imm', b[1]]
    // 11-bit target in the current 2K bank
  : s === 'a11'  ? ['code', (pc & 0x800) | ((op & 0xE0) << 3) | b[1]]
    // target in the page of the operand byte
  : s === 'page' ? ['code', ((pc + 1) & 0xF00) | b[1]]
  : ['reg', s]);
  return { mn, len, b, args };
}

// ── Formatting, in the listing's own style ──────────────────
const h2 = v => v.toString(16).toUpperCase().padStart(2, '0');
const h4 = v => v.toString(16).toUpperCase().padStart(4, '0');
// Assembler hex as the workbooks write it: 0EAh, 36h (immediates unpadded: #3h)
const asmHex = (v, w = 2) => { const s = v.toString(16).toUpperCase().padStart(w, '0'); return `${/^[A-F]/.test(s) ? '0' : ''}${s}h`; };
const bitByte = bit => bit < 0x80 ? 0x20 + (bit >> 3) : bit & 0xF8;
const x2 = v => `0x${v.toString(16).padStart(2, '0')}`;

// dis8051.fmt_numeric: the listing's num column
function numeric51([k, v]) {
  if (k === 'reg') return v;
  if (k === 'dir') return x2(v);
  if (k === 'bit' || k === 'nbit') return `${k === 'nbit' ? '/' : ''}${x2(bitByte(v))}.${v & 7} [${x2(v)}]`;
  if (k === 'imm') return `#${x2(v)}`;
  if (k === 'imm16') return `#0x${v.toString(16).padStart(4, '0')}`;
  return `0x${v.toString(16).padStart(4, '0')}`;
}

export const hexBytes = (cpu, bytes) => bytes.map(b => cpu === 'dme' ? b.toString(16).padStart(2, '0') : h2(b)).join(' ');
// The bytes a listing row stands for (its hex column; at least one)
export const rowBytes = r => (r.bytes ?? '').split(/\s+/).filter(t => /^[0-9a-f]{2}$/i.test(t)).length || 1;

// Names the listing gives each direct address and bit (DME), learned from
// its rows where the image decodes to what the row says, and its labels.
// Kept per listing.
const learned = new WeakMap();
function names(cpu, rows, img) {
  let n = learned.get(rows);
  if (n) return n;
  n = { label: new Map(), sym: new Map() };
  const tally = new Map();
  for (const r of rows) {
    if (r.label) n.label.set(r.a, r.label);
    if (cpu !== 'dme' || !r.ops) continue;
    // The hex tables cut operands at 20 characters: a cut row's last name may be cut short
    const cut = r.ops.length === 20;
    const d = decode8051(img, r.a);
    if (d.mn !== r.instr || d.len !== rowBytes(r)) continue;
    const toks = r.ops.split(',').map(s => s.trim());
    if (toks.length !== d.args.length && !(cut && toks.length < d.args.length)) continue;
    d.args.forEach(([k, v], i) => {
      if (k !== 'dir' && k !== 'bit' && k !== 'nbit') return;
      if (cut && i >= toks.length - 1) return;
      const key = `${k === 'nbit' ? 'bit' : k}:${v}`;
      const name = toks[i].replace(/^\//, '');
      if (!name) return;
      const c = tally.get(key) ?? new Map();
      c.set(name, (c.get(name) ?? 0) + 1);
      tally.set(key, c);
    });
  }
  for (const [key, c] of tally) n.sym.set(key, [...c].sort((p, q) => q[1] - p[1])[0][0]);
  learned.set(rows, n);
  return n;
}

function formatRow(cpu, a, d, nm) {
  const code = t => cpu === 'dme' && t === a ? '$'
    : nm.label.get(t) ?? (cpu === 'dme' ? `0x${t.toString(16).padStart(4, '0')}` : `0x${h4(t).slice(1)}`);
  if (cpu === 'dme') {
    const sym = (k, v) => nm.sym.get(`${k}:${v}`) ?? asmHex(v);
    const ops = d.args.map(([k, v]) =>
      k === 'reg' ? v : k === 'dir' ? sym('dir', v) : k === 'bit' ? sym('bit', v) : k === 'nbit' ? `/${sym('bit', v)}`
    : k === 'imm' ? `#${asmHex(v, 1)}` : k === 'imm16' ? `#${asmHex(v, 3)}` : code(v)).join(', ');
    // The num column shows mov dir,dir (85 src dst) in byte order, as the workbooks do
    const nargs = d.b[0] === 0x85 ? [d.args[1], d.args[0]] : d.args;
    return { instr: d.mn, ops, num: nargs.map(numeric51).join(', ') };
  }
  const ops = d.args.map(([k, v]) => k === 'reg' ? v : k === 'imm' ? `#${v.toString(16).toUpperCase()}` : code(v)).join(',');
  return { instr: d.mn, ops };
}

// The listing for an edited image. rows: the listing of the unedited
// image (orig); img: the edited bytes. Each run of edited bytes is decoded
// again from the start of the row holding its first byte until the
// decode reaches a byte past the edits that starts a listing row (or lies
// outside every row: a table the listing doesn't show). New rows carry
// patched: true and orig (the unedited bytes they cover, in the listing's
// hex style). Rows outside those runs are kept as they are.
export function patchListing(cpu, rows, orig, img) {
  const size = cpu === 'dme' ? 8192 : 4096;
  const diffs = [];
  for (let a = 0; a < size; a++) if (orig[a] !== img[a]) diffs.push(a);
  if (!diffs.length || !rows.length) return rows;
  const decode = cpu === 'dme' ? decode8051 : decode8048;
  const nm = names(cpu, rows, orig);
  // owner[a]: index of the row whose bytes cover address a (-1 for none)
  const owner = new Int32Array(size).fill(-1);
  const startAt = new Map();
  rows.forEach((r, i) => {
    startAt.set(r.a, i);
    const end = Math.min(size, r.a + rowBytes(r), rows[i + 1]?.a ?? size);
    for (let a = r.a; a < end; a++) owner[a] = i;
  });
  // The checksum word at the end of the DME image stays one row
  const tail = cpu === 'dme' ? 0x1FFE : size;

  const out = [];
  let next = 0;    // rows[] index not yet copied
  let k = 0;       // diffs[] index not yet covered
  while (k < diffs.length) {
    const d = diffs[k];
    const own = owner[d];
    let pc = own >= 0 ? rows[own].a : d;
    // copy the rows before this run
    while (next < rows.length && rows[next].a < pc) out.push(rows[next++]);
    for (;;) {
      if (pc >= tail) {
        // edits in the checksum word: one row of raw bytes
        const b = [...img.subarray(pc, size)];
        out.push({ a: pc, label: nm.label.get(pc) ?? '', instr: rows[startAt.get(pc)]?.instr ?? 'db', ops: '', bytes: hexBytes(cpu, b),
                   ...(cpu === 'dme' ? { num: '' } : {}), patched: true, orig: hexBytes(cpu, [...orig.subarray(pc, size)]) });
        pc = size;
        k = diffs.length;
        break;
      }
      let dec = decode(img, pc);
      if (pc + dec.len > tail) dec = { mn: 'db', len: tail - pc, b: [...img.subarray(pc, tail)], args: [] };
      const end = pc + dec.len;
      const same = orig.subarray(pc, end).equals?.(img.subarray(pc, end))
        ?? orig.subarray(pc, end).every((v, i) => v === img[pc + i]);
      const base = startAt.has(pc) ? rows[startAt.get(pc)] : null;
      if (same && base && rowBytes(base) === dec.len) out.push(base);   // an untouched instruction, as listed
      else out.push({ a: pc, label: nm.label.get(pc) ?? '', ...formatRow(cpu, pc, dec, nm), bytes: hexBytes(cpu, dec.b),
                      ...(base?.desc && same ? { desc: base.desc } : {}),
                      patched: true, orig: hexBytes(cpu, [...orig.subarray(pc, end)]) });
      pc = end;
      while (k < diffs.length && diffs[k] < pc) k++;
      const edited = k < diffs.length && diffs[k] === pc;
      if (pc >= size) break;
      // back in step with the listing (or out of the listed code), and no edit here
      if (!edited && (startAt.has(pc) || owner[pc] < 0)) break;
    }
    while (next < rows.length && rows[next].a < pc) next++;   // rows the run replaced
  }
  while (next < rows.length) out.push(rows[next++]);
  return out;
}
