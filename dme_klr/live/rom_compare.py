#!/usr/bin/env python3
"""
rom_compare.py: what differs between two DME or two KLR EPROM images,
before anything is simulated.

    python3 rom_compare.py dme|klr <a> <b> [--asm-a DIR] [--asm-b DIR] [--all]

<a>, <b>: .mem, .bin or Intel HEX images. Prints one JSON object:

  a, b         {name, sha, size}: sha is the key map_graphs.py and
               rom_stamp.py use (first 16 hex digits of the SHA-256 of the
               image padded to 8 KB with FFh)
  identical    true when every byte is the same
  diff_bytes   how many bytes differ
  calib        the calibration maps and tables, decoded from each image the
               way the firmware reads them (DME: map_graphs.py, the numbered
               maps through 1090h/11E0h and the directly addressed tables;
               KLR: klr/disassemble/klr_maps.py). One entry per map:
                 {id, name, kind, changed, moved, addr_a, addr_b, size,
                  x_a, x_b, y_a, y_b (axes: {addr, name, unit, raw}),
                  values_a, values_b (a list, or rows of a grid), cells}
               cells = how many values differ. Only the changed ones unless
               --all.
  code         the other runs of differing bytes (code, constants, the map
               index and address tables), merged when less than 4 bytes
               apart: {start, end, bytes_a, bytes_b, at_a, at_b, rows_a,
               rows_b}. at_* is the nearest label at or before the run
               (from that image's disassembly tables, "label+offset"),
               rows_* the listing rows that overlap it.
  listing_a, listing_b   whether the disassembly tables were given

--asm-a / --asm-b: that image's table directory from asm_select.sh (the
same tables the live listing and the testbench use). Without one the runs
have bytes but no labels.

The bridge serves this at GET /compare/<cpu>?a=..&b=.. for the dashboard's
COMPARE button. Needs only the Python standard library.
"""
import argparse, hashlib, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, 'klr', 'disassemble'))
sys.path.insert(0, os.path.join(REPO, 'bin_images'))

SIZE = {'dme': 8192, 'klr': 4096}
GAP = 4          # runs closer than this are merged
MAX_ROWS = 60    # listing rows per run and side


def load(path, cpu):
    from rom2mem import load_image
    img = load_image(path)
    if len(img) > SIZE[cpu]:
        raise ValueError(f'{os.path.basename(path)} is {len(img)} bytes, more than the '
                         f'{cpu.upper()} EPROM\'s {SIZE[cpu]}')
    return (img + b'\xff' * SIZE[cpu])[:SIZE[cpu]]


def sha(img):
    return hashlib.sha256((img + b'\xff' * 8192)[:8192]).hexdigest()[:16]


# ── calibration: one entry per map, keyed so the two images line up ──
def axis(a):
    return a and {k: a[k] for k in ('addr', 'name', 'unit', 'raw')}


def dme_calib(img):
    import map_graphs as G
    out = {}
    for n in range(G.N_MAPS):
        m = G.decode_map(img, n)
        if m:
            out[f'M{n}'] = {'name': f'map {n}', 'kind': f'map{m["dim"]}d', 'addr': m['addr'],
                            'size': m['bytes'], 'x': axis(m['x']), 'y': axis(m.get('y')),
                            'values': m['values']}
    for addr, kind, length in G.TABLES:
        t = G.decode_table(img, addr, kind, length)
        out[f'T{addr:04X}'] = {'name': f'table {addr:04X}h', 'kind': kind, 'addr': addr,
                               'size': t['bytes'], 'x': axis(t.get('x')), 'y': None,
                               'values': t['values']}
    return out


def klr_calib(img):
    import klr_maps as K
    out = {}
    g, _ = K.gain(img)
    for d in K.defs(img):
        a, size = d['addr'], d['size']
        if a in (K.BOOST, K.CV):
            vals, kind = K.grid(img, a), 'map3d'
        elif a == g:
            vals, kind = [list(img[a + 8 * r:a + 8 * r + 8]) for r in range(4)], 'grid'
        elif d['axes'] == '44h':                       # 925h constants: [dest, 8 values]
            vals, kind = list(img[a + 1:a + 9]), 'const'
        else:
            vals, kind = list(img[a:a + size]), 'table'
        # the constants and the gain move with the 925h list, so match them by name
        key = d['id'] if a in (K.BOOST, K.CV, K.RPM_AXIS) else d['name']
        out[key] = {'id': d['id'], 'name': d['name'], 'kind': kind, 'addr': a, 'size': size,
                    'x': None, 'y': None, 'values': vals, 'out': d['out'], 'purpose': d['purpose']}
    return out


def flat(v):
    return [x for r in v for x in (r if isinstance(r, list) else [r])]


def calib(cpu, A, B, every):
    ca, cb = (dme_calib if cpu == 'dme' else klr_calib)(A), (dme_calib if cpu == 'dme' else klr_calib)(B)
    out, covered = [], set()
    for key in list(ca) + [k for k in cb if k not in ca]:
        a, b = ca.get(key), cb.get(key)
        for e, img in ((a, A), (b, B)):
            if e:
                covered.update((id(img), i) for i in range(e['addr'], e['addr'] + e['size']))
        va, vb = (a or {}).get('values'), (b or {}).get('values')
        fa, fb = flat(va or []), flat(vb or [])
        cells = sum(x != y for x, y in zip(fa, fb)) + abs(len(fa) - len(fb))
        xa, xb = (a or {}).get('x'), (b or {}).get('x')
        ya, yb = (a or {}).get('y'), (b or {}).get('y')
        changed = a is None or b is None or cells > 0 or xa != xb or ya != yb
        if not (changed or every):
            continue
        e = a or b
        out.append({'id': e.get('id', key), 'key': key, 'name': e['name'], 'kind': e['kind'],
                    'changed': changed, 'moved': bool(a and b and a['addr'] != b['addr']),
                    'only': None if a and b else ('a' if a else 'b'),
                    'addr_a': a and a['addr'], 'addr_b': b and b['addr'], 'size': e['size'],
                    'x_a': xa, 'x_b': xb, 'y_a': ya, 'y_b': yb, 'values_a': va, 'values_b': vb,
                    'cells': cells, 'axis_changed': xa != xb or ya != yb,
                    **({'out': e['out'], 'purpose': e['purpose']} if 'out' in e else {})})
    # bytes in a map of either image
    cov = {i for (_, i) in covered}
    return out, cov


# ── the listing from an asm_select.sh table directory ──
def hex_strings(path):
    try:
        with open(path) as f:
            return [bytes.fromhex(l.strip()).decode('latin1').strip() for l in f]
    except (OSError, ValueError):
        return None


def listing(d, cpu):
    if not d:
        return None
    ops = 'asm_operand_mapped.hex' if cpu == 'dme' else 'asm_operands.hex'
    t = {k: hex_strings(os.path.join(d, f)) for k, f in
         (('label', 'test_sim.hex'), ('instr', 'asm_instr.hex'), ('ops', ops), ('bytes', 'asm_opcode_ins.hex'))}
    if any(v is None for v in t.values()):
        return None
    full = None
    try:
        with open(os.path.join(d, 'asm_full.json')) as f:
            full = json.load(f).get(cpu)
    except (OSError, ValueError, AttributeError):
        pass
    n = len(t['instr'])

    def row(a):
        r = {'a': a, 'label': t['label'][a], 'instr': t['instr'][a], 'ops': t['ops'][a]}
        e = full and full.get(str(a))
        if e and e.get('ops', '')[:20].strip() == r['ops']:
            r['ops'] = e['ops']
            if e.get('label') and e['label'][:20].strip() == r['label']:
                r['label'] = e['label']
        return r
    return {'n': n, 'label': t['label'], 'instr': t['instr'], 'row': row}


def near_label(L, a):
    if not L:
        return None
    for p in range(min(a, L['n'] - 1), -1, -1):
        if L['label'][p]:
            return L['label'][p] + (f'+{a - p:X}h' if a > p else '')
    return None


def rows(L, s, e):
    if not L:
        return None
    # start at the instruction holding byte s
    p = s
    while p > 0 and p < L['n'] and not L['instr'][p] and s - p < 4:
        p -= 1
    out = []
    for a in range(p, min(e + 1, L['n'])):
        if L['instr'][a] or L['label'][a]:
            out.append(L['row'](a))
            if len(out) >= MAX_ROWS:
                break
    return out


def code_runs(A, B, cov, La, Lb):
    d = [i for i in range(len(A)) if A[i] != B[i] and i not in cov]
    runs = []
    for i in d:
        if runs and i - runs[-1][1] < GAP:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    return [{'start': s, 'end': e, 'bytes_a': A[s:e + 1].hex(' ').upper(), 'bytes_b': B[s:e + 1].hex(' ').upper(),
             'at_a': near_label(La, s), 'at_b': near_label(Lb, s), 'rows_a': rows(La, s, e), 'rows_b': rows(Lb, s, e)}
            for s, e in runs]


def compare(cpu, pa, pb, asm_a=None, asm_b=None, every=False, name_a=None, name_b=None):
    A, B = load(pa, cpu), load(pb, cpu)
    cal, cov = calib(cpu, A, B, every)
    La, Lb = listing(asm_a, cpu), listing(asm_b, cpu)
    return {
        'cpu': cpu,
        'a': {'name': name_a or os.path.basename(pa), 'sha': sha(A), 'size': SIZE[cpu]},
        'b': {'name': name_b or os.path.basename(pb), 'sha': sha(B), 'size': SIZE[cpu]},
        'identical': A == B,
        'diff_bytes': sum(x != y for x, y in zip(A, B)),
        'calib': cal,
        'code': code_runs(A, B, cov, La, Lb),
        'listing_a': La is not None, 'listing_b': Lb is not None,
    }


def main():
    p = argparse.ArgumentParser(description='Compare two DME or KLR EPROM images (JSON on stdout).')
    p.add_argument('cpu', choices=('dme', 'klr'))
    p.add_argument('a')
    p.add_argument('b')
    p.add_argument('--asm-a')
    p.add_argument('--asm-b')
    p.add_argument('--name-a')
    p.add_argument('--name-b')
    p.add_argument('--all', action='store_true', help='list every map, not only the changed ones')
    o = p.parse_args()
    try:
        r = compare(o.cpu, o.a, o.b, o.asm_a, o.asm_b, o.all, o.name_a, o.name_b)
    except (OSError, ValueError) as e:
        print(f'rom_compare.py: {e}', file=sys.stderr)
        return 1
    json.dump(r, sys.stdout, separators=(',', ':'))
    print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
