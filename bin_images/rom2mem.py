#!/usr/bin/env python3
"""
Convert an EPROM image to the .mem form the simulator loads ($readmemh: one
two-digit hex byte per line, upper case), like bin_images/*/*.mem.

Usage: python3 rom2mem.py <image> [<out.mem>] [--cpu dme|klr]

  <image>      a raw binary (.bin, any other extension), an Intel HEX file
               (.hex/.ihx, recognised by its ':' records), or a .mem
               (copied through, normalised)
  <out.mem>    default: <image> with the extension changed to .mem
  --cpu        check the size against that CPU's EPROM: dme 8192 bytes
               (2764), klr 4096 bytes (2732); larger images are refused,
               smaller ones are written as they are (the simulator fills
               the rest with FF)

The run scripts (DME_ROM_FILE / KLR_ROM_FILE naming a .bin or .hex, see
paths.sh dmeklr_rom_mem) and the live bridge's ROM upload use this, so a
plain binary can be used anywhere a .mem is.
"""

import os
import sys

SIZES = {'dme': 8192, 'klr': 4096}


def read_intel_hex(text):
    data = {}
    base = 0
    for n, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        if not line.startswith(':'):
            raise ValueError(f'line {n}: not an Intel HEX record')
        rec = bytes.fromhex(line[1:])
        count, addr, kind = rec[0], (rec[1] << 8) | rec[2], rec[3]
        if (sum(rec) & 0xFF) != 0:
            raise ValueError(f'line {n}: bad checksum')
        if kind == 0:
            for i, b in enumerate(rec[4:4 + count]):
                data[base + addr + i] = b
        elif kind == 1:
            break
        elif kind == 2:
            base = ((rec[4] << 8) | rec[5]) << 4
        elif kind == 4:
            base = ((rec[4] << 8) | rec[5]) << 16
    if not data:
        return b''
    out = bytearray([0xFF] * (max(data) + 1))
    for a, b in data.items():
        out[a] = b
    return bytes(out)


def read_mem(text):
    out = bytearray()
    for line in text.splitlines():
        line = line.split('//')[0].strip()
        for tok in line.split():
            if tok.startswith('@'):
                addr = int(tok[1:], 16)
                if addr > len(out):
                    out.extend([0xFF] * (addr - len(out)))
                del out[addr:]
            else:
                out.append(int(tok.replace('_', ''), 16))
    return bytes(out)


def load_image(path):
    raw = open(path, 'rb').read()
    ext = os.path.splitext(path)[1].lower()
    head = raw.lstrip()[:1]
    if ext == '.mem':
        return read_mem(raw.decode('ascii'))
    if ext in ('.hex', '.ihx') or head == b':':
        try:
            return read_intel_hex(raw.decode('ascii'))
        except (UnicodeDecodeError, ValueError):
            if ext in ('.hex', '.ihx'):
                raise
    return raw


def main(argv):
    if any(a in ('-h', '--help') for a in argv) or not argv:
        print(__doc__.strip())
        return 0 if argv else 2
    cpu = None
    if '--cpu' in argv:
        i = argv.index('--cpu')
        cpu = argv[i + 1].lower() if i + 1 < len(argv) else ''
        del argv[i:i + 2]
        if cpu not in SIZES:
            print('rom2mem.py: --cpu must be dme or klr', file=sys.stderr)
            return 2
    src = argv[0]
    out = argv[1] if len(argv) > 1 else os.path.splitext(src)[0] + '.mem'
    try:
        img = load_image(src)
    except (OSError, ValueError) as e:
        print(f'rom2mem.py: {src}: {e}', file=sys.stderr)
        return 1
    if not img:
        print(f'rom2mem.py: {src} is empty', file=sys.stderr)
        return 1
    if cpu and len(img) > SIZES[cpu]:
        print(f'rom2mem.py: {src} is {len(img)} bytes, more than the {cpu.upper()} '
              f'EPROM\'s {SIZES[cpu]}', file=sys.stderr)
        return 1
    tmp = out + '.tmp'
    with open(tmp, 'w', newline='\n') as f:
        f.write(''.join(f'{b:02X}\n' for b in img))
    os.replace(tmp, out)
    print(f'rom2mem.py: {src} -> {out} ({len(img)} bytes)')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
