#!/usr/bin/env python3
"""
klr_map_graphs.py: draw the KLR's maps and tables in a ROM image (the KLR
counterpart of map_graphs.py; the decoding is klr/disassemble/klr_maps.py).

One PNG per table the KLR MAPS tab charts, named T<addr>.png:
  T0C00 target boost map, T0B00 CV open-loop map: surface + raw grid
  T0992 boost PID gain: grid (hex)
  T0A00 rpm axis: 44h against 24h ticks (and ~rpm)
  T0925, T092E, ... the rpm constants: value by rpm bracket

The graphs go in <cache>/<sha>/ with an index.json, where <sha> is the same
key map_graphs.py / rom_stamp.py use (the first 16 hex digits of the SHA-256
of the image padded to 8 KB with FFh), so the bridge can find a log's KLR
image by the hash on its KLR: [ROM] line. A directory that already has an
index.json from this GEN_VERSION is left as it is.

    python3 klr_map_graphs.py <image.mem|image.bin> [...] [--cache DIR] [--force]

Prints one line per image: "<sha> <dir> cached|generated". The bridge runs
it for the KLR image the sim has loaded and serves /maps/klr. Needs matplotlib.
"""
import argparse, hashlib, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'klr', 'disassemble'))
import klr_maps as K  # noqa: E402

GEN_VERSION = 2   # bump to redraw every cached image
DEFAULT_CACHE = os.path.abspath(os.path.join(REPO, '..', 'tmp', 'dme_klr', 'map_graphs'))


def image_key(img):
    return hashlib.sha256(img + b'\xff' * (8192 - len(img))).hexdigest()[:16]


def col_rpm(axis, k, per):
    """~rpm at the middle of the 44h bracket k (per = 4 for the maps, 8 for the constants)"""
    s = K.rpm_span(axis, per * k, per * k + per - 1)
    if s is None:
        return 0.0
    lo, hi = s
    return lo if hi > 20000 else (lo + hi) / 2


def draw_grid_map(plt, np, img, base, title, unit, conv, path, axis):
    g = np.array(K.grid(img, base), float)          # [throttle row][rpm column]
    z = conv(g)
    rpm = [col_rpm(axis, k, 4) for k in range(K.COLS)]
    deg = [53 + 4 * r for r in range(K.ROWS)]
    fig = plt.figure(figsize=(16, 7.5), dpi=100)
    a3 = fig.add_subplot(1, 2, 1, projection='3d')
    X, Y = np.meshgrid(rpm, deg)
    s = a3.plot_surface(X, Y, z, cmap='viridis', edgecolor='k', linewidth=0.4)
    a3.set_xlabel('~rpm (44h/4 column)')
    a3.set_ylabel('throttle 3Ah, deg (43h/4 row)')
    a3.set_zlabel(unit)
    a3.view_init(elev=28, azim=-130)
    a3.set_title(title, fontsize=11)
    fig.colorbar(s, ax=a3, shrink=0.6, pad=0.1, label=unit)
    a2 = fig.add_subplot(1, 2, 2)
    a2.imshow(g, cmap='viridis', aspect='auto', origin='lower')
    for i in range(g.shape[0]):
        for j in range(g.shape[1]):
            raw = int(g[i, j])
            a2.text(j, i, f'{raw}\n{z[i, j]:.0f}', ha='center', va='center', fontsize=7,
                    color='white' if raw < (g.min() + g.max()) / 2 else 'black')
    a2.set_xticks(range(K.COLS))
    a2.set_xticklabels([f'{4 * k}\n{rpm[k]:.0f}' for k in range(K.COLS)], fontsize=7.5)
    a2.set_yticks(range(K.ROWS))
    a2.set_yticklabels([f'{4 * r} ({deg[r]}°)' for r in range(K.ROWS)], fontsize=8)
    a2.set_xlabel('44h rpm index / ~rpm (column 0 = highest rpm)')
    a2.set_ylabel('43h throttle index (3Ah deg)')
    a2.set_title(f'Raw values (decimal) and {unit}', fontsize=11)
    fig.text(0.5, 0.01, 'Interpolated by 0C80h in quarter steps of 43h and 44h (4 x 4 samples / 16). '
             'rpm from 24h ticks, ~343800 / (ticks + 3.16).', ha='center', fontsize=8.5, color='#555')
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(path)
    plt.close(fig)


def draw_gain(plt, np, img, title, path, axis):
    ga, gg = K.gain(img)
    g = np.array(gg, float)
    fig = plt.figure(figsize=(16, 7.5), dpi=100)
    # 3D: one bar per cell (no interpolation, so steps rather than a surface)
    a3 = fig.add_subplot(1, 2, 1, projection='3d')
    rpm = [col_rpm(axis, k, 8) for k in range(8)]
    xs, ys = np.meshgrid(range(8), range(4))
    xs, ys, zs = xs.ravel(), ys.ravel(), g.ravel()
    cm = plt.get_cmap('viridis')
    norm = (zs - zs.min()) / ((zs.max() - zs.min()) or 1)
    a3.bar3d(xs - 0.4, ys - 0.4, np.zeros_like(zs), 0.8, 0.8, zs, color=cm(norm), edgecolor='k', linewidth=0.3, shade=True)
    a3.set_xticks(range(8))
    a3.set_xticklabels([f'{r:.0f}' for r in rpm], fontsize=7)
    a3.set_yticks(range(4))
    a3.set_yticklabels([f'{53 + 8 * r}°' for r in range(4)], fontsize=8)
    a3.set_xlabel('~rpm (44h/8 column)')
    a3.set_ylabel('throttle 3Ah (43h/8 row)')
    a3.set_zlabel('6Bh gain (raw)')
    a3.view_init(elev=32, azim=50)   # high-gain low-throttle row at the back, so it hides nothing
    a3.set_title(title, fontsize=11)
    ax = fig.add_subplot(1, 2, 2)
    ax.imshow(g, cmap='viridis', aspect='auto', origin='lower')
    for i in range(g.shape[0]):
        for j in range(g.shape[1]):
            raw = int(g[i, j])
            ax.text(j, i, f'{raw:02X}\n{raw:08b}', ha='center', va='center', fontsize=8,
                    color='white' if raw < (g.min() + g.max()) / 2 else 'black')
    ax.set_xticks(range(8))
    ax.set_xticklabels([f'{8 * k}-{min(8 * k + 7, 60)}\n{K.fmt_span(K.rpm_span(axis, 8 * k, 8 * k + 7))}' for k in range(8)], fontsize=8)
    ax.set_yticks(range(4))
    ax.set_yticklabels([f'{8 * r}-{min(8 * r + 7, 28)} ({53 + 8 * r}-{min(60 + 8 * r, 81)}°)' for r in range(4)], fontsize=8)
    ax.set_xlabel('44h rpm index / ~rpm')
    ax.set_ylabel('43h throttle index (3Ah deg)')
    ax.set_title('Raw values (hex and bits)', fontsize=11)
    fig.text(0.5, 0.01, f'code[{ga:04X}h + (43h & 18h) + 44h/8] -> 6Bh, no interpolation; bit-packed.',
             ha='center', fontsize=8.5, color='#555')
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(path)
    plt.close(fig)


def draw_axis(plt, img, title, path):
    ticks = list(range(256))
    idx = [K.rpm_index(img, t) for t in ticks]
    fig, ax = plt.subplots(figsize=(10, 5.2), dpi=100)
    ax.step(ticks, idx, where='post', color='#2a7', lw=1.6)
    ax.set_xlabel('24h ENGINE_SPEED_TICKS (timer ticks per 180°)')
    ax.set_ylabel('44h rpm index')
    ax.set_ylim(bottom=0, top=62)
    ax.grid(alpha=0.3)
    ax.set_xlim(40, 200)
    top = ax.twiny()
    top.set_xlim(ax.get_xlim())
    rpms = [1800, 2000, 2500, 3000, 3500, 4000, 5000, 6000]
    top.set_xticks([K.RPM_K / r - K.RPM_C for r in rpms])
    top.set_xticklabels([str(r) for r in rpms], fontsize=8)
    top.set_xlabel('~rpm')
    ax.set_title(title, fontsize=11)
    inc = ' '.join(f'{v:02X}' for v in img[K.RPM_AXIS:K.RPM_AXIS + 16])
    fig.text(0.5, 0.01, f'Increments at A00h: {inc}   (bank 0 R7 = FEh; below ~1500 rpm R7 = FCh and 44h = 60)',
             ha='center', fontsize=8, color='#555')
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(path)
    plt.close(fig)


def draw_const(plt, img, entry, dest, vals, title, path, axis):
    name, purpose = K.CONST_NAMES.get(dest, (f'RPM_K_{dest:02X}', 'unknown'))
    fig, ax = plt.subplots(figsize=(10, 5.2), dpi=100)
    ax.bar(range(8), vals, color='#2a7')
    for i, v in enumerate(vals):
        ax.annotate(f'{v} ({v:02X}h)', (i, v), textcoords='offset points', xytext=(0, 3), ha='center', fontsize=8)
    ax.set_xticks(range(8))
    ax.set_xticklabels([f'44h {8 * k}-{min(8 * k + 7, 60)}\n{K.fmt_span(K.rpm_span(axis, 8 * k, 8 * k + 7))}' for k in range(8)], fontsize=8)
    ax.set_xlabel('rpm bracket (44h/8; left = highest rpm)')
    ax.set_ylabel(f'{dest:02X}h {name}')
    ax.set_ylim(bottom=0, top=max(vals) * 1.15 + 1)
    ax.grid(alpha=0.3, axis='y')
    ax.set_title(title, fontsize=11)
    fig.text(0.5, 0.01, f'{purpose}. Entry at {entry:04X}h: destination {dest:02X}h then 8 values; no interpolation.',
             ha='center', fontsize=8, color='#555')
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(path)
    plt.close(fig)


def generate(path, cache, force=False):
    img = K.load_image(path)
    sha = image_key(img)
    out = os.path.join(cache, sha)
    idx_path = os.path.join(out, 'index.json')
    if not force and os.path.exists(idx_path):
        try:
            j = json.load(open(idx_path))
            if j.get('version') == GEN_VERSION and j.get('cpu') == 'klr':
                return sha, out, 'cached'
        except (OSError, ValueError):
            pass
    try:
        import matplotlib
    except ImportError:
        sys.exit('klr_map_graphs.py needs matplotlib: pip3 install matplotlib')
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import numpy as np
    tmp = out + '.tmp'
    os.makedirs(tmp, exist_ok=True)
    rom = os.path.basename(path)
    axis = K.rpm_axis(img)
    index = {'version': GEN_VERSION, 'cpu': 'klr', 'sha': sha, 'rom': rom, 'maps': {}, 'tables': {}}

    def add(addr, size, draw):
        f = f'T{addr:04X}.png'
        draw(os.path.join(tmp, f))
        index['tables'][f'{addr:04X}'] = {'file': f, 'addr': f'{addr:04X}', 'bytes': size}

    add(K.BOOST, 128, lambda p: draw_grid_map(plt, np, img, K.BOOST, f'Target boost map C00h   {rom}',
                                              '~kPa abs ((x + 4) / 1.22)', lambda v: (v + 4) / 1.22, p, axis))
    add(K.CV, 128, lambda p: draw_grid_map(plt, np, img, K.CV, f'CV open-loop duty map B00h   {rom}',
                                           'duty % (x / 193)', lambda v: 100 * v / 193, p, axis))
    ga, _ = K.gain(img)
    add(ga, 32, lambda p: draw_gain(plt, np, img, f'Boost PID gain {ga:04X}h   {rom}', p, axis))
    add(K.RPM_AXIS, 16, lambda p: draw_axis(plt, img, f'RPM axis A00h (24h -> 44h)   {rom}', p))
    for entry, dest, vals in K.consts(img)[0]:
        add(entry, 9, lambda p, e=entry, d=dest, v=vals:
            draw_const(plt, img, e, d, v, f'RPM constant {e:04X}h -> {d:02X}h   {rom}', p, axis))
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
