"""Minimal 8051 linear disassembler producing structured operands.

Operand kinds:
  ('reg', 'A')          literal register/token text
  ('dir', 0x36)         direct byte address
  ('bit', 0x1c)         bit address
  ('nbit', 0x1c)        /bit (complemented)
  ('imm', 0x5c)         #imm8
  ('imm16', 0x1234)     #imm16
  ('code', 0x005c)      code address (ajmp/ljmp/acall/lcall/rel targets)
"""

def _tbl():
    t = {}
    R = lambda n: ('reg', 'R%d' % n)
    IR = lambda n: ('reg', '@R%d' % n)
    A = ('reg', 'A')
    for i in range(8):
        base = i * 0x20
        t[base + 0x01] = ('ajmp', 2, ['a11'])
        t[base + 0x11] = ('acall', 2, ['a11'])
    simple = {
        0x00: ('nop', 1, []), 0x02: ('ljmp', 3, ['a16']), 0x03: ('rr', 1, [A]),
        0x04: ('inc', 1, [A]), 0x05: ('inc', 2, ['dir']),
        0x10: ('jbc', 3, ['bit', 'rel']), 0x12: ('lcall', 3, ['a16']), 0x13: ('rrc', 1, [A]),
        0x14: ('dec', 1, [A]), 0x15: ('dec', 2, ['dir']),
        0x20: ('jb', 3, ['bit', 'rel']), 0x22: ('ret', 1, []), 0x23: ('rl', 1, [A]),
        0x24: ('add', 2, [A, 'imm']), 0x25: ('add', 2, [A, 'dir']),
        0x30: ('jnb', 3, ['bit', 'rel']), 0x32: ('reti', 1, []), 0x33: ('rlc', 1, [A]),
        0x34: ('addc', 2, [A, 'imm']), 0x35: ('addc', 2, [A, 'dir']),
        0x40: ('jc', 2, ['rel']), 0x42: ('orl', 2, ['dir', A]), 0x43: ('orl', 3, ['dir', 'imm']),
        0x44: ('orl', 2, [A, 'imm']), 0x45: ('orl', 2, [A, 'dir']),
        0x50: ('jnc', 2, ['rel']), 0x52: ('anl', 2, ['dir', A]), 0x53: ('anl', 3, ['dir', 'imm']),
        0x54: ('anl', 2, [A, 'imm']), 0x55: ('anl', 2, [A, 'dir']),
        0x60: ('jz', 2, ['rel']), 0x62: ('xrl', 2, ['dir', A]), 0x63: ('xrl', 3, ['dir', 'imm']),
        0x64: ('xrl', 2, [A, 'imm']), 0x65: ('xrl', 2, [A, 'dir']),
        0x70: ('jnz', 2, ['rel']), 0x72: ('orl', 2, [('reg', 'C'), 'bit']),
        0x73: ('jmp', 1, [('reg', '@A+DPTR')]), 0x74: ('mov', 2, [A, 'imm']), 0x75: ('mov', 3, ['dir', 'imm']),
        0x80: ('sjmp', 2, ['rel']), 0x82: ('anl', 2, [('reg', 'C'), 'bit']),
        0x83: ('movc', 1, [A, ('reg', '@A+PC')]), 0x84: ('div', 1, [('reg', 'AB')]),
        0x85: ('mov', 3, ['dirdir']),
        0x90: ('mov', 3, [('reg', 'DPTR'), 'imm16']), 0x92: ('mov', 2, ['bit', ('reg', 'C')]),
        0x93: ('movc', 1, [A, ('reg', '@A+DPTR')]), 0x94: ('subb', 2, [A, 'imm']), 0x95: ('subb', 2, [A, 'dir']),
        0xA0: ('orl', 2, [('reg', 'C'), 'nbit']), 0xA2: ('mov', 2, [('reg', 'C'), 'bit']),
        0xA3: ('inc', 1, [('reg', 'DPTR')]), 0xA4: ('mul', 1, [('reg', 'AB')]), 0xA5: ('???', 1, []),
        0xB0: ('anl', 2, [('reg', 'C'), 'nbit']), 0xB2: ('cpl', 2, ['bit']), 0xB3: ('cpl', 1, [('reg', 'C')]),
        0xB4: ('cjne', 3, [A, 'imm', 'rel']), 0xB5: ('cjne', 3, [A, 'dir', 'rel']),
        0xC0: ('push', 2, ['dir']), 0xC2: ('clr', 2, ['bit']), 0xC3: ('clr', 1, [('reg', 'C')]),
        0xC4: ('swap', 1, [A]), 0xC5: ('xch', 2, [A, 'dir']),
        0xD0: ('pop', 2, ['dir']), 0xD2: ('setb', 2, ['bit']), 0xD3: ('setb', 1, [('reg', 'C')]),
        0xD4: ('da', 1, [A]), 0xD5: ('djnz', 3, ['dir', 'rel']),
        0xE0: ('movx', 1, [A, ('reg', '@DPTR')]), 0xE4: ('clr', 1, [A]), 0xE5: ('mov', 2, [A, 'dir']),
        0xF0: ('movx', 1, [('reg', '@DPTR'), A]), 0xF4: ('cpl', 1, [A]), 0xF5: ('mov', 2, ['dir', A]),
    }
    t.update(simple)
    for i in range(2):
        t[0x06 + i] = ('inc', 1, [IR(i)]); t[0x16 + i] = ('dec', 1, [IR(i)])
        t[0x26 + i] = ('add', 1, [A, IR(i)]); t[0x36 + i] = ('addc', 1, [A, IR(i)])
        t[0x46 + i] = ('orl', 1, [A, IR(i)]); t[0x56 + i] = ('anl', 1, [A, IR(i)])
        t[0x66 + i] = ('xrl', 1, [A, IR(i)]); t[0x76 + i] = ('mov', 2, [IR(i), 'imm'])
        t[0x86 + i] = ('mov', 2, ['dir', IR(i)]); t[0x96 + i] = ('subb', 1, [A, IR(i)])
        t[0xA6 + i] = ('mov', 2, [IR(i), 'dir']); t[0xB6 + i] = ('cjne', 3, [IR(i), 'imm', 'rel'])
        t[0xC6 + i] = ('xch', 1, [A, IR(i)]); t[0xD6 + i] = ('xchd', 1, [A, IR(i)])
        t[0xE2 + i] = ('movx', 1, [A, IR(i)]); t[0xE6 + i] = ('mov', 1, [A, IR(i)])
        t[0xF2 + i] = ('movx', 1, [IR(i), A]); t[0xF6 + i] = ('mov', 1, [IR(i), A])
    for n in range(8):
        t[0x08 + n] = ('inc', 1, [R(n)]); t[0x18 + n] = ('dec', 1, [R(n)])
        t[0x28 + n] = ('add', 1, [A, R(n)]); t[0x38 + n] = ('addc', 1, [A, R(n)])
        t[0x48 + n] = ('orl', 1, [A, R(n)]); t[0x58 + n] = ('anl', 1, [A, R(n)])
        t[0x68 + n] = ('xrl', 1, [A, R(n)]); t[0x78 + n] = ('mov', 2, [R(n), 'imm'])
        t[0x88 + n] = ('mov', 2, ['dir', R(n)]); t[0x98 + n] = ('subb', 1, [A, R(n)])
        t[0xA8 + n] = ('mov', 2, [R(n), 'dir']); t[0xB8 + n] = ('cjne', 3, [R(n), 'imm', 'rel'])
        t[0xC8 + n] = ('xch', 1, [A, R(n)]); t[0xD8 + n] = ('djnz', 2, [R(n), 'rel'])
        t[0xE8 + n] = ('mov', 1, [A, R(n)]); t[0xF8 + n] = ('mov', 1, [R(n), A])
    assert len(t) == 256, len(t)
    return t

TABLE = _tbl()


def decode(mem, pc):
    """Return (mnemonic, length, bytes, [operands])."""
    op = mem[pc]
    mn, ln, spec = TABLE[op]
    b = list(mem[pc:pc + ln])
    while len(b) < ln:
        b.append(0)
    args = []
    idx = 1
    for s in spec:
        if isinstance(s, tuple):
            args.append(s)
        elif s == 'a11':
            tgt = ((pc + 2) & 0xF800) | ((op & 0xE0) << 3) | b[1]
            args.append(('code', tgt)); idx += 1
        elif s == 'a16':
            args.append(('code', (b[1] << 8) | b[2])); idx += 2
        elif s == 'rel':
            r = b[idx]; r = r - 256 if r > 127 else r
            args.append(('code', (pc + ln + r) & 0xFFFF)); idx += 1
        elif s == 'dirdir':
            # 85 src dst -> mov dst, src
            args.append(('dir', b[2])); args.append(('dir', b[1])); idx += 2
        elif s == 'imm16':
            args.append(('imm16', (b[idx] << 8) | b[idx + 1])); idx += 2
        else:
            args.append((s, b[idx])); idx += 1
    return mn, ln, b, args


def bit_byte(bit):
    return 0x20 + bit // 8 if bit < 0x80 else bit & 0xF8


def fmt_numeric(arg):
    k, v = arg
    if k == 'reg':
        return v
    if k == 'dir':
        return '0x%02x' % v
    if k in ('bit', 'nbit'):
        s = '0x%02x.%d [0x%02x]' % (bit_byte(v), v & 7, v)
        return '/' + s if k == 'nbit' else s
    if k == 'imm':
        return '#0x%02x' % v
    if k == 'imm16':
        return '#0x%04x' % v
    if k == 'code':
        return '0x%04x' % v
    raise ValueError(k)


def hexh(v, width=2):
    s = '%0*Xh' % (width, v)
    return s
