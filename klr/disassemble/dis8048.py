"""Minimal 8048 (MCS-48) disassembler producing structured operands.

Operand kinds:
  ('reg', 'a')          literal operand text (registers, ports, flags, @r0 ...)
  ('imm', 0x43)         #imm8
  ('code', 0x0F32)      code address (jmp/call/conditional jump/djnz target)

Mnemonics and operand text follow 87KLR951.xlsx: lowercase, operands joined
with "," and no space.
"""

# op -> (mnemonic, length, operand spec); spec items are literal text or
# 'imm' / 'a11' (jmp/call) / 'page' (conditional jumps, djnz)
def _tbl():
    t = {}
    R = lambda n: 'r%d' % n
    for p in range(8):
        t[(p << 5) | 0x04] = ('jmp', 2, ['a11'])
        t[(p << 5) | 0x14] = ('call', 2, ['a11'])
    simple = {
        0x00: ('nop', 1, []), 0x02: ('outl', 1, ['bus', 'a']), 0x03: ('add', 2, ['a', 'imm']),
        0x05: ('en', 1, ['i']), 0x07: ('dec', 1, ['a']), 0x08: ('ins', 1, ['a', 'bus']),
        0x09: ('in', 1, ['a', 'p1']), 0x0A: ('in', 1, ['a', 'p2']),
        0x0C: ('movd', 1, ['a', 'p4']), 0x0D: ('movd', 1, ['a', 'p5']),
        0x0E: ('movd', 1, ['a', 'p6']), 0x0F: ('movd', 1, ['a', 'p7']),
        0x12: ('jb0', 2, ['page']), 0x13: ('addc', 2, ['a', 'imm']), 0x15: ('dis', 1, ['i']),
        0x16: ('jtf', 2, ['page']), 0x17: ('inc', 1, ['a']),
        0x23: ('mov', 2, ['a', 'imm']), 0x25: ('en', 1, ['tcnti']), 0x26: ('jnt0', 2, ['page']),
        0x27: ('clr', 1, ['a']),
        0x32: ('jb1', 2, ['page']), 0x35: ('dis', 1, ['tcnti']), 0x36: ('jt0', 2, ['page']),
        0x37: ('cpl', 1, ['a']), 0x39: ('outl', 1, ['p1', 'a']), 0x3A: ('outl', 1, ['p2', 'a']),
        0x3C: ('movd', 1, ['p4', 'a']), 0x3D: ('movd', 1, ['p5', 'a']),
        0x3E: ('movd', 1, ['p6', 'a']), 0x3F: ('movd', 1, ['p7', 'a']),
        0x42: ('mov', 1, ['a', 't']), 0x43: ('orl', 2, ['a', 'imm']), 0x45: ('strt', 1, ['cnt']),
        0x46: ('jnt1', 2, ['page']), 0x47: ('swap', 1, ['a']),
        0x52: ('jb2', 2, ['page']), 0x53: ('anl', 2, ['a', 'imm']), 0x55: ('strt', 1, ['t']),
        0x56: ('jt1', 2, ['page']), 0x57: ('da', 1, ['a']),
        0x62: ('mov', 1, ['t', 'a']), 0x65: ('stop', 1, ['tcnt']), 0x67: ('rrc', 1, ['a']),
        0x72: ('jb3', 2, ['page']), 0x75: ('ent0', 1, ['clk']), 0x76: ('jf1', 2, ['page']),
        0x77: ('rr', 1, ['a']),
        0x83: ('ret', 1, []), 0x85: ('clr', 1, ['f0']), 0x86: ('jni', 2, ['page']),
        0x88: ('orl', 2, ['bus', 'imm']), 0x89: ('orl', 2, ['p1', 'imm']), 0x8A: ('orl', 2, ['p2', 'imm']),
        0x8C: ('orld', 1, ['p4', 'a']), 0x8D: ('orld', 1, ['p5', 'a']),
        0x8E: ('orld', 1, ['p6', 'a']), 0x8F: ('orld', 1, ['p7', 'a']),
        0x92: ('jb4', 2, ['page']), 0x93: ('retr', 1, []), 0x95: ('cpl', 1, ['f0']),
        0x96: ('jnz', 2, ['page']), 0x97: ('clr', 1, ['c']),
        0x98: ('anl', 2, ['bus', 'imm']), 0x99: ('anl', 2, ['p1', 'imm']), 0x9A: ('anl', 2, ['p2', 'imm']),
        0x9C: ('anld', 1, ['p4', 'a']), 0x9D: ('anld', 1, ['p5', 'a']),
        0x9E: ('anld', 1, ['p6', 'a']), 0x9F: ('anld', 1, ['p7', 'a']),
        0xA3: ('movp', 1, ['a', '@a']), 0xA5: ('clr', 1, ['f1']), 0xA7: ('cpl', 1, ['c']),
        0xB2: ('jb5', 2, ['page']), 0xB3: ('jmpp', 1, ['@a']), 0xB5: ('cpl', 1, ['f1']),
        0xB6: ('jf0', 2, ['page']),
        0xC5: ('sel', 1, ['rb0']), 0xC6: ('jz', 2, ['page']), 0xC7: ('mov', 1, ['a', 'psw']),
        0xD2: ('jb6', 2, ['page']), 0xD3: ('xrl', 2, ['a', 'imm']), 0xD5: ('sel', 1, ['rb1']),
        0xD7: ('mov', 1, ['psw', 'a']),
        0xE3: ('movp3', 1, ['a', '@a']), 0xE5: ('sel', 1, ['mb0']), 0xE6: ('jnc', 2, ['page']),
        0xE7: ('rl', 1, ['a']),
        0xF2: ('jb7', 2, ['page']), 0xF5: ('sel', 1, ['mb1']), 0xF6: ('jc', 2, ['page']),
        0xF7: ('rlc', 1, ['a']),
    }
    t.update(simple)
    for i in range(2):
        ri = '@r%d' % i
        t[0x10 + i] = ('inc', 1, [ri]); t[0x20 + i] = ('xch', 1, ['a', ri])
        t[0x30 + i] = ('xchd', 1, ['a', ri]); t[0x40 + i] = ('orl', 1, ['a', ri])
        t[0x50 + i] = ('anl', 1, ['a', ri]); t[0x60 + i] = ('add', 1, ['a', ri])
        t[0x70 + i] = ('addc', 1, ['a', ri]); t[0x80 + i] = ('movx', 1, ['a', ri])
        t[0x90 + i] = ('movx', 1, [ri, 'a']); t[0xA0 + i] = ('mov', 1, [ri, 'a'])
        t[0xB0 + i] = ('mov', 2, [ri, 'imm']); t[0xD0 + i] = ('xrl', 1, ['a', ri])
        t[0xF0 + i] = ('mov', 1, ['a', ri])
    for n in range(8):
        t[0x18 + n] = ('inc', 1, [R(n)]); t[0x28 + n] = ('xch', 1, ['a', R(n)])
        t[0x48 + n] = ('orl', 1, ['a', R(n)]); t[0x58 + n] = ('anl', 1, ['a', R(n)])
        t[0x68 + n] = ('add', 1, ['a', R(n)]); t[0x78 + n] = ('addc', 1, ['a', R(n)])
        t[0xA8 + n] = ('mov', 1, [R(n), 'a']); t[0xB8 + n] = ('mov', 2, [R(n), 'imm'])
        t[0xC8 + n] = ('dec', 1, [R(n)]); t[0xD8 + n] = ('xrl', 1, ['a', R(n)])
        t[0xE8 + n] = ('djnz', 2, [R(n), 'page']); t[0xF8 + n] = ('mov', 1, ['a', R(n)])
    return t

TABLE = _tbl()


def decode(mem, pc):
    """Return (mnemonic, length, bytes, [operands]). Unused opcodes decode as
    a one-byte '.db', as in 87KLR951.xlsx."""
    op = mem[pc]
    if op not in TABLE:
        return '.db', 1, [op], [('reg', '0x%02x' % op)]
    mn, ln, spec = TABLE[op]
    b = list(mem[pc:pc + ln])
    while len(b) < ln:
        b.append(0)
    args = []
    for s in spec:
        if s == 'imm':
            args.append(('imm', b[1]))
        elif s == 'a11':
            # 11-bit target in the current 2K bank (the code here runs with
            # the bank it sits in selected)
            args.append(('code', (pc & 0x800) | ((op & 0xE0) << 3) | b[1]))
        elif s == 'page':
            # target is in the page of the operand byte
            args.append(('code', ((pc + 1) & 0xF00) | b[1]))
        else:
            args.append(('reg', s))
    return mn, ln, b, args


def fmt_arg(arg, label_for=None):
    k, v = arg
    if k == 'reg':
        return v
    if k == 'imm':
        return '#%X' % v
    if k == 'code':
        return label_for(v) if label_for else 'label%04X' % v
    raise ValueError(k)


def fmt_ops(args, label_for=None):
    return ','.join(fmt_arg(a, label_for) for a in args)
