#!/usr/bin/env python3
"""
map_graphs.py: draw every DME calibration map and table in a ROM image.

One PNG per numbered map (map_lookup, 051Dh) and per directly addressed
table, read straight from the image, so the graphs always match the ROM:
2D maps as a curve over their axis, 3D maps as a surface plus a grid of
the raw values, linear_lookup tables as steps and MOVC tables as bars.

The graphs for an image go in <cache>/<sha>/, where <sha> is the first 16
hex digits of the SHA-256 of the 8 KB image (the bytes, not the file name).
A directory that already has an index.json from this GEN_VERSION is left
as it is, so graphs are only drawn for a new image or new contents.

    python3 map_graphs.py <image.mem|image.bin> [...] [--cache DIR] [--force]

Prints one line per image: "<sha> <dir> cached|generated". The bridge
(bridge.mjs) runs it for the DME image the sim has loaded and serves the
result at /maps/dme; the DME MAPS tab shows a graph when its title is
clicked. Needs matplotlib (pip3 install matplotlib).

Decoding (performance ROM addresses; the 1986 and 1989 images match):
  code[1090h + R2]: FFh = no map; bit 0 = 3D; (byte AND FEh) indexes the
  address table at 11E0h (high byte first).
  2D: [axis iram addr, n, n breakpoint increments, n values]
  3D: [axis 1 addr, n1, n1 increments, axis 2 addr, n2, n2 increments,
       n1 x n2 values, axis 1 major]
  Get_Map_Addr adds the increments to the input from the last one back
  until the sum carries, so cell k (0-based) starts at
  x_k = 256 - sum(incr[k:]); below x_0 the first value holds.
"""
import argparse, hashlib, json, os, re, sys

GEN_VERSION = 2   # bump to redraw every cached image
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
DEFAULT_CACHE = os.path.abspath(os.path.join(REPO, '..', 'tmp', 'dme_klr', 'map_graphs'))

MAP_INDEX, MAP_ADDRS, N_MAPS = 0x1090, 0x11E0, 100

# Directly addressed tables: (address, kind, length for MOVC tables)
TABLES = [
    (0x10F4, 'movc', 8), (0x10FC, 'movc', 8), (0x1104, 'movc', 32),
    (0x1124, 'linear', None), (0x112E, 'linear', None),
    (0x1140, 'movc', 16), (0x1150, 'movc', 16), (0x1296, 'linear', None),
]

# Engineering units for known iram inputs (as on the dashboard)
IRAM = {
    0x37: ('Engine speed', 'rpm', lambda r: r * 40),
    0x11: ('Battery voltage', 'V', lambda r: r * 0.05263 + 2.132),
    0x12: ('Air temp', '°C', lambda r: r * 165 / 255 - 40),
    0x13: ('Coolant temp', '°C', lambda r: r * 165 / 255 - 40),
    0x49: ('Load index', 'raw', None),
    0x10: ('AFM', 'raw', None),
    0x14: ('Altitude / region ADC', 'raw', None),
    0x16: ('TPS ADC', 'raw', None),
    0x17: ('FQS ADC', 'raw', None),
    0x4D: ('Injection event count', 'raw', None),
    0x03: ('R3 (set by the caller)', 'raw', None),
    0x04: ('R4 (set by the caller)', 'raw', None),
}
# Output units for maps whose result is understood
OUT = {24: ('Dwell', '° crank', lambda v: v * 360 / 264)}


def load_image(path):
    data = open(path, 'rb').read()
    if path.lower().endswith('.mem'):
        text = re.sub(r'/\*.*?\*/', ' ', data.decode('ascii', 'replace'), flags=re.S)
        text = re.sub(r'//.*', ' ', text)
        img = bytearray(b'\xff' * 8192)
        addr = 0
        for tok in text.split():
            v = int(tok.lstrip('@').replace('_', ''), 16)
            if tok[0] == '@':
                addr = v
            elif addr < 8192:
                img[addr] = v
                addr += 1
        return bytes(img)
    return (data + b'\xff' * 8192)[:8192]


def axis_points(incr):
    return [256 - sum(incr[k:]) for k in range(len(incr))]


def axis_info(addr, pts):
    name, unit, f = IRAM.get(addr, (f'iram {addr:02X}h', 'raw', None))
    eng = [f(p) for p in pts] if f else list(pts)
    return {'addr': addr, 'name': name, 'unit': unit, 'raw': pts, 'eng': eng}


def axis_label(a):
    return f"{a['name']} ({a['unit']})  [{a['addr']:02X}h]"


def tick(a, i):
    e, r = a['eng'][i], a['raw'][i]
    if a['unit'] == 'raw':
        return f'{r:02X}h'
    return f"{e:.1f} {a['unit']}\n({r:02X}h)" if isinstance(e, float) and a['unit'] == 'V' else f"{e:.0f} {a['unit']}\n({r:02X}h)"


def decode_map(img, n):
    idx = img[MAP_INDEX + n]
    if idx == 0xFF:
        return None
    p = MAP_ADDRS + (idx & 0xFE)
    ma = (img[p] << 8) | img[p + 1]
    if ma + 2 >= len(img):
        return None
    ax, cnt = img[ma], img[ma + 1]
    inc = list(img[ma + 2:ma + 2 + cnt])
    m = {'n': n, 'addr': ma, 'x': axis_info(ax, axis_points(inc))}
    if idx & 1:
        b = ma + 2 + cnt
        ay, cnt2 = img[b], img[b + 1]
        inc2 = list(img[b + 2:b + 2 + cnt2])
        v0 = b + 2 + cnt2
        m.update(dim=3, y=axis_info(ay, axis_points(inc2)),
                 values=[list(img[v0 + i * cnt2:v0 + (i + 1) * cnt2]) for i in range(cnt)],
                 bytes=4 + cnt + cnt2 + cnt * cnt2)
    else:
        m.update(dim=2, values=list(img[ma + 2 + cnt:ma + 2 + 2 * cnt]), bytes=2 + 2 * cnt)
    return m


def decode_table(img, addr, kind, length):
    if kind == 'movc':
        return {'addr': addr, 'kind': kind, 'values': list(img[addr:addr + length]), 'bytes': length}
    ax, cnt = img[addr], img[addr + 1]
    inc = list(img[addr + 2:addr + 2 + cnt])
    return {'addr': addr, 'kind': kind, 'x': axis_info(ax, axis_points(inc)),
            'values': list(img[addr + 2 + cnt:addr + 2 + 2 * cnt]), 'bytes': 2 + 2 * cnt}


def out_scale(n):
    return OUT.get(n, ('Result', 'raw', None))


def draw_map(plt, np, m, title, path):
    oname, ounit, of = out_scale(m['n'])
    conv = (lambda v: of(np.asarray(v, float))) if of else (lambda v: np.asarray(v, float))
    zlabel = f'{oname} ({ounit})' if of else 'Result (raw)'
    if m['dim'] == 2:
        x = m['x']
        fig, ax = plt.subplots(figsize=(9, 5.2), dpi=100)
        xs = x['eng']
        ys = conv(m['values'])
        lo, hi = (0, 255) if not x['raw'] else (min(0, x['raw'][0]), 255)
        f = IRAM.get(x['addr'], (0, 0, None))[2]
        xl = [f(lo) if f else lo] + list(xs) + [f(hi) if f else hi]
        yl = [ys[0]] + list(ys) + [ys[-1]]
        ax.plot(xl, yl, color='#2a7', lw=1.6)
        ax.plot(xs, ys, 'o', color='#063', ms=5)
        for xv, yv, raw in zip(xs, ys, m['values']):
            ax.annotate(f'{raw:02X}', (xv, yv), textcoords='offset points', xytext=(0, 7), ha='center', fontsize=8)
        ax.set_xlabel(axis_label(x))
        ax.set_ylabel(zlabel)
        ax.set_ylim(bottom=0)
        ax.grid(alpha=0.3)
        ax.set_title(title, fontsize=11)
        fig.text(0.5, 0.01, 'Breakpoints: ' + '  '.join(f'{r:02X}h' for r in x['raw'])
                 + '   (linear between points, held at the ends)', ha='center', fontsize=8, color='#555')
        fig.tight_layout(rect=(0, 0.04, 1, 1))
    else:
        x, y = m['x'], m['y']
        v = np.array(m['values'], float)
        z = conv(v)
        fig = plt.figure(figsize=(16, 7.5), dpi=100)
        a3 = fig.add_subplot(1, 2, 1, projection='3d')
        X, Y = np.meshgrid(x['eng'], y['eng'])
        s = a3.plot_surface(X, Y, z.T, cmap='viridis', edgecolor='k', linewidth=0.4)
        ye = y['eng']
        pad = (max(ye) - min(ye)) * 0.02 or 1
        a3.set_ylim(max(ye) + pad, min(ye) - pad)   # second axis high-to-low, front to back
        a3.set_xlabel(axis_label(x))
        a3.set_ylabel(axis_label(y))
        a3.set_zlabel(zlabel)
        a3.set_zlim(bottom=0)
        a3.view_init(elev=28, azim=-130)
        a3.set_title(title, fontsize=11)
        fig.colorbar(s, ax=a3, shrink=0.6, pad=0.1, label=zlabel)
        a2 = fig.add_subplot(1, 2, 2)
        a2.imshow(v, cmap='viridis', aspect='auto', origin='lower')
        for i in range(v.shape[0]):
            for j in range(v.shape[1]):
                raw = int(v[i, j])
                txt = f'{raw:02X}' + (f'\n{z[i, j]:.0f}' if of else '')
                a2.text(j, i, txt, ha='center', va='center', fontsize=7.5,
                        color='white' if raw < (v.min() + v.max()) / 2 else 'black')
        a2.set_xticks(range(len(y['raw'])))
        a2.set_xticklabels([tick(y, j) for j in range(len(y['raw']))], fontsize=8)
        a2.set_yticks(range(len(x['raw'])))
        a2.set_yticklabels([tick(x, i).replace('\n', ' ') for i in range(len(x['raw']))], fontsize=8)
        a2.set_xlabel(axis_label(y))
        a2.set_ylabel(axis_label(x))
        a2.set_title('Raw values' + (f' and {ounit}' if of else ''), fontsize=11)
        fig.text(0.5, 0.01, 'Breakpoints decoded from the increment bytes as Get_Map_Addr uses them; '
                 'bilinear between cells, held at the edges.', ha='center', fontsize=8.5, color='#555')
        fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(path)
    plt.close(fig)


def draw_table(plt, np, t, title, path):
    fig, ax = plt.subplots(figsize=(9, 5.2), dpi=100)
    vals = t['values']
    if t['kind'] == 'movc':
        ax.bar(range(len(vals)), vals, color='#2a7')
        for i, v in enumerate(vals):
            ax.annotate(f'{v:02X}', (i, v), textcoords='offset points', xytext=(0, 3), ha='center', fontsize=7.5)
        ax.set_xlabel('Index (A when the MOVC runs)')
        ax.set_xticks(range(len(vals)))
        note = 'One byte read with MOVC A,@A+DPTR at the index the caller works out.'
    else:
        x = t['x']
        xs = x['eng']
        f = IRAM.get(x['addr'], (0, 0, None))[2]
        lo, hi = (f(0), f(255)) if f else (0, 255)
        ax.step([lo] + list(xs) + [hi], [vals[0]] + list(vals) + [vals[-1]], where='post', color='#2a7', lw=1.6)
        ax.plot(xs, vals, 'o', color='#063', ms=5)
        for xv, v in zip(xs, vals):
            ax.annotate(f'{v:02X}', (xv, v), textcoords='offset points', xytext=(4, 5), fontsize=8)
        ax.set_xlabel(axis_label(x))
        note = 'linear_lookup: the value of the bracket the input falls in (no interpolation). Breakpoints: ' \
               + '  '.join(f'{r:02X}h' for r in x['raw'])
    ax.set_ylabel('Result (raw)')
    ax.set_ylim(bottom=0)
    ax.grid(alpha=0.3)
    ax.set_title(title, fontsize=11)
    fig.text(0.5, 0.01, note, ha='center', fontsize=8, color='#555')
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(path)
    plt.close(fig)


def generate(path, cache, force=False):
    img = load_image(path)
    sha = hashlib.sha256(img).hexdigest()[:16]
    out = os.path.join(cache, sha)
    idx_path = os.path.join(out, 'index.json')
    if not force and os.path.exists(idx_path):
        try:
            if json.load(open(idx_path)).get('version') == GEN_VERSION:
                return sha, out, 'cached'
        except (OSError, ValueError):
            pass
    try:
        import matplotlib
    except ImportError:
        sys.exit('map_graphs.py needs matplotlib: pip3 install matplotlib')
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import numpy as np
    tmp = out + '.tmp'
    os.makedirs(tmp, exist_ok=True)
    rom = os.path.basename(path)
    index = {'version': GEN_VERSION, 'sha': sha, 'rom': rom, 'maps': {}, 'tables': {}}
    for n in range(N_MAPS):
        m = decode_map(img, n)
        if not m:
            continue
        f = f'M{n}.png'
        kind = '3D' if m['dim'] == 3 else '2D'
        draw_map(plt, np, m, f'Map {n} (R2={n:02X}h) at {m["addr"]:04X}h, {kind}   {rom}', os.path.join(tmp, f))
        index['maps'][str(n)] = {'file': f, 'addr': f'{m["addr"]:04X}', 'dim': m['dim'], 'bytes': m['bytes']}
    for addr, kind, length in TABLES:
        t = decode_table(img, addr, kind, length)
        f = f'T{addr:04X}.png'
        draw_table(plt, np, t, f'Table {addr:04X}h ({"linear_lookup" if kind == "linear" else "MOVC"})   {rom}',
                   os.path.join(tmp, f))
        index['tables'][f'{addr:04X}'] = {'file': f, 'kind': kind, 'bytes': t['bytes']}
    json.dump(index, open(os.path.join(tmp, 'index.json'), 'w', newline='\n'), indent=1)
    if os.path.exists(out):
        import shutil
        shutil.rmtree(out)
    os.rename(tmp, out)
    return sha, out, 'generated'


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('images', nargs='+')
    ap.add_argument('--cache', default=DEFAULT_CACHE)
    ap.add_argument('--force', action='store_true', help='draw again even if cached')
    a = ap.parse_args()
    for p in a.images:
        sha, out, how = generate(p, a.cache, a.force)
        print(sha, out, how, flush=True)


if __name__ == '__main__':
    main()
