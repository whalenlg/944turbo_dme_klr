#!/usr/bin/env python3
"""
klr_maps.py: the KLR (8048) calibration maps and tables, read from a ROM image.

Every address and axis below was checked against the code of the 1987 image
(87KLR_951.mem); the 1986 and 1989 images run the same code at the same
addresses (only the 89 boost map and one row of the 925h constants differ).
The values always come from the image passed in, so a sheet or graph matches
that ROM.

  A00h  rpm axis (rpm_axis_lookup, 0A57h): 24h (timer ticks per 180 deg,
        complemented on read) -> 44h, 0 (>= ~6070 rpm) .. 60 (<= ~1830 rpm).
        Bank 0 R7 is the timer reload: FCh below ~1500 rpm, which gives
        44h = 60, FEh above. Then r4 = R7 + 38h + ~24h
        (carry: 44h = 0); then r6 counts up, adding the increment
        code[A00h + r6/4] to r4 each step, until r4 carries; 44h = min(r6, 60).
  43h   throttle axis (tps_calc, 0A0Fh): 43h = 3Ah - 53 for 3Ah (throttle,
        degrees) >= 53, else 0; at most 28.
  C00h  target boost map (boost_target_map_read, 0A8Dh -> 2D interpolation
        at 0C80h with F1 set): 8 throttle rows (43h/4) x 16 rpm columns
        (44h/4, column 0 = highest rpm), 16 bytes a row. 51h = result - 57h
        (the knock boost reduction).
  B00h  cycling valve open-loop (feed-forward) duty map
        (cv_open_loop_map_read, 0A82h -> 0C80h with F1 clear): same layout
        and axes; result to 68h.
        The interpolation reads the cell, the next rpm column and the next
        throttle row in quarter steps: 4 x 4 samples, (43h & 3) of the four
        row passes on row + 1 and (44h & 3) of the four samples in each
        pass on column + 1, summed and divided by 16 (truncated).
  925h  rpm constants (load_axis_hi_read, 0900h): entries of 9 bytes,
        [destination RAM address, 8 values by 44h/8], ended by a 00h byte;
        each value goes to its destination.
  992h  boost PID gain (load_axis_lo_read, 0919h), right after the 925h
        list's terminator: 4 throttle rows (43h & 18h) x 8 rpm columns (44h/8),
        no interpolation, result to 6Bh.

    python3 klr_maps.py <image.mem|image.bin>                 print the tables
    python3 klr_maps.py <image.mem> --xlsx <workbook.xlsx>    (re)write the map sheets
"""
import argparse, os, re, sys

SIZE = 4096
BOOST, CV, RPM_AXIS, CONSTS = 0xC00, 0xB00, 0xA00, 0x925
ROWS, COLS = 8, 16

# Approximate engine speed for a 24h tick count: rpm = RPM_K / (ticks + RPM_C).
# Fitted to the rpm / 24h ranges on jhnbyrn's KLR memory map page (54 ticks
# ~6068 rpm, 181-184 ticks ~1832-1872 rpm); the axis indices themselves are
# exact (emulated from the ROM).
RPM_K, RPM_C = 343800.0, 3.16

# Destination RAM of the 925h constants: (name, purpose), from the workbook's
# consrtants sheet and the KLR memory map page
CONST_NAMES = {
    0x2A: ('RPM_K_ADC_START_ANGLE', 'angle to start the ADC routine (x 24h -> 22h)'),
    0x2B: ('RPM_K_ADC_READ_ANGLE', 'angle for the ADC read (x 24h, - 8 -> 23h)'),
    0x47: ('RPM_K_KNOCK_THRESH_COEF', 'knock threshold coefficient (compared with 46h)'),
    0x4A: ('RPM_K_TIMING_RESTORE_CNT', 'cycle count before restoring 0.3 deg of timing (49h)'),
    0x50: ('RPM_K_BOOST_RESTORE_CNT', 'cycle count before restoring boost'),
    0x4E: ('RPM_K_BOOST_PULL_CNT', 'cycle count before pulling boost'),
    0x4B: ('RPM_K_MAX_TIMING_RETARD', 'max timing retard'),
    0x48: ('RPM_K_KNOCK_TPS_THRESH', 'throttle position threshold for knock control'),
    0x4C: ('RPM_K_BOOST_PULL_THRESH', 'threshold for pulling boost'),
    0x3E: ('RPM_K_WOT_ANGLE', 'angle for WOT'),
    0x45: ('RPM_K_MIN_KNOCK_THRESH', 'minimum knock threshold'),
    0x69: ('RPM_K_CNT_FOR_6A', 'counter for 6Ah'),
}


def load_image(path):
    data = open(path, 'rb').read()
    if path.lower().endswith('.mem'):
        text = re.sub(r'/\*.*?\*/', ' ', data.decode('ascii', 'replace'), flags=re.S)
        text = re.sub(r'//.*', ' ', text)
        img = bytearray(b'\xff' * SIZE)
        addr = 0
        for tok in text.split():
            if tok[0] == '@':
                addr = int(tok[1:], 16)
            elif addr < SIZE:
                img[addr] = int(tok, 16)
                addr += 1
        return bytes(img)
    return (data + b'\xff' * SIZE)[:SIZE]


# ── axes ─────────────────────────────────────────────────────────
def rpm_index(img, ticks):
    """44h for a 24h value, as rpm_axis_lookup works it out, with bank 0 R7
    (the timer reload) = FEh as it is above ~1500 rpm. With R7 = FCh (below)
    the routine skips the table: 44h = 60."""
    r4 = (~ticks & 0xFF) + ((0xFE + 0x38) & 0xFF)
    if r4 > 0xFF:
        return 0
    r6 = 0
    while True:
        r6 += 1
        r4 += img[RPM_AXIS + ((r6 >> 2) & 0x3F)]
        if r4 > 0xFF:
            break
        r4 &= 0xFF
        if r6 > 255:
            break
    return min(r6, 60)


def ticks_to_rpm(t):
    return RPM_K / (t + RPM_C)


def rpm_axis(img):
    """[(44h, lo ticks, hi ticks, rpm at hi ticks, rpm at lo ticks)] for 44h 0..60"""
    by = {}
    for t in range(256):
        by.setdefault(rpm_index(img, t), []).append(t)
    out = []
    for i in range(61):
        ts = by.get(i)
        if ts:
            out.append((i, ts[0], ts[-1], ticks_to_rpm(ts[-1] + 0.5), ticks_to_rpm(max(ts[0] - 0.5, 0))))
        else:
            out.append((i, None, None, None, None))
    return out


def rpm_span(axis, lo_idx, hi_idx):
    """rpm range covered by the 44h values lo_idx..hi_idx (higher index = lower rpm)"""
    rows = [a for a in axis if lo_idx <= a[0] <= hi_idx and a[1] is not None]
    if not rows:
        return None
    return (min(r[3] for r in rows), max(r[4] for r in rows))


def fmt_span(s):
    if s is None:
        return '-'
    lo, hi = s
    if hi > 20000:
        return f'{lo:.0f}+'
    return f'<{hi:.0f}' if lo < 1400 else f'{lo:.0f}-{hi:.0f}'


def throttle_index(deg):
    return 0 if deg < 53 else min(deg - 53, 28)


# ── maps ─────────────────────────────────────────────────────────
def grid(img, base):
    return [list(img[base + COLS * r: base + COLS * r + COLS]) for r in range(ROWS)]


def interp(img, base, i43, i44):
    """The 0C80h interpolation: the value the firmware returns for 43h, 44h"""
    r2 = (((i43 << 2) & 0xF0) + ((i44 >> 2) & 0x0F)) & 0xFF
    ft, b0, b1 = (i43 & 3), i44 & 1, (i44 >> 1) & 1
    s = 0
    for r4 in (4, 3, 2, 1):
        r3 = (r2 + 16) & 0xFF if ft >= r4 else r2
        s += img[base + r3]
        s += img[base + ((r3 + b0) & 0xFF)]
        r3b = (r3 + b1) & 0xFF
        s += img[base + r3b] + img[base + r3b]
    return (s >> 4) & 0xFF


def consts(img):
    """[(entry address, dest, [8 values])], and the address after the 00h terminator"""
    out, p = [], CONSTS & 0xFF
    while img[0x900 + p] and len(out) < 20:
        a = 0x900 + p
        out.append((a, img[a], list(img[a + 1:a + 9])))
        p += 9
    return out, 0x900 + p + 1


def gain(img):
    _, g = consts(img)
    return g, [list(img[g + 8 * r: g + 8 * r + 8]) for r in range(4)]


# ── the map list (the dashboard's KLR MAPS tab uses the same ids) ──
def defs(img):
    c, g = consts(img)
    d = [
        {'id': 'T0C00', 'name': 'BOOST_TARGET_MAP', 'addr': BOOST, 'size': 128, 'axes': '43h, 44h',
         'out': '51h (= result - 57h)', 'routine': 'boost_target_map_read (0A8Dh) -> interpolation 0C80h, F1 set',
         'purpose': 'target boost (MAP ADC units, ~1.22 x kPa - 4) by throttle and rpm, interpolated'},
        {'id': 'T0B00', 'name': 'CV_OPEN_LOOP_MAP', 'addr': CV, 'size': 128, 'axes': '43h, 44h',
         'out': '68h', 'routine': 'cv_open_loop_map_read (0A82h) -> interpolation 0C80h, F1 clear',
         'purpose': 'cycling valve open-loop (feed-forward) duty, counts of 193 (PWM period), interpolated'},
        {'id': 'T0A00', 'name': 'RPM_AXIS_TABLE', 'addr': RPM_AXIS, 'size': 16, 'axes': '24h',
         'out': '44h', 'routine': 'rpm_axis_lookup (0A57h)',
         'purpose': 'rpm axis: engine speed (24h, ticks per 180 deg) to the map rpm index 0-60 (0 = highest rpm)'},
    ]
    for a, dest, _ in c:
        n, p = CONST_NAMES.get(dest, (f'RPM_K_{dest:02X}', 'unknown'))
        d.append({'id': f'T{a:04X}', 'name': n, 'addr': a, 'size': 9, 'axes': '44h', 'out': f'{dest:02X}h',
                  'routine': 'load_axis_hi_read (0900h)', 'purpose': f'{p}; by 44h/8, no interpolation'})
    d.append({'id': f'T{g:04X}', 'name': 'BOOST_PID_GAIN', 'addr': g, 'size': 32, 'axes': '43h, 44h',
              'out': '6Bh', 'routine': 'load_axis_lo_read (0919h)',
              'purpose': 'boost PID gain (bit-packed) by throttle (43h & 18h) and rpm (44h/8), no interpolation'})
    return d


# ── workbook sheets ──────────────────────────────────────────────
SHEETS = ['maps_index', 'boost_map_C00', 'cv_map_B00', 'rpm_axis_A00', 'rpm_consts_925', 'pid_gain_992']


def write_sheets(wb, img, image_name):
    from openpyxl.styles import Font, PatternFill, Alignment
    from openpyxl.formatting.rule import ColorScaleRule
    from openpyxl.utils import get_column_letter
    bold = Font(bold=True)
    hdr = PatternFill('solid', fgColor='DDEBF7')
    for s in SHEETS:
        if s in wb.sheetnames:
            del wb[s]
    axis = rpm_axis(img)
    col_span = [fmt_span(rpm_span(axis, 4 * k, 4 * k + 3)) for k in range(COLS)]
    col8_span = [fmt_span(rpm_span(axis, 8 * k, 8 * k + 7)) for k in range(8)]
    note = (f'Read from {image_name}. Regenerate with klr_maps.py <image> --xlsx <workbook> '
            '(build_klr_variant.py does it for the 86/89 workbooks).')

    def widths(ws, w):
        for i, x in enumerate(w, 1):
            ws.column_dimensions[get_column_letter(i)].width = x

    def heading(ws, title, lines):
        ws.append([title]); ws['A1'].font = Font(bold=True, size=13)
        for l in lines:
            ws.append([l])
        ws.append([])

    def map_grid(ws, g, row0, label, fmt=None):
        """one 8 x 16 grid at row0: header row, then rows by 43h/4"""
        ws.cell(row0, 1, label).font = bold
        ws.cell(row0 + 1, 1, '43h (throttle) \\ 44h (rpm)').font = bold
        ws.cell(row0 + 2, 1, '3Ah throttle deg \\ ~rpm').font = bold
        for k in range(COLS):
            c = ws.cell(row0 + 1, 2 + k, f'{4 * k}'); c.font = bold; c.fill = hdr
            c = ws.cell(row0 + 2, 2 + k, col_span[k]); c.fill = hdr
            c.alignment = Alignment(wrap_text=True)
        for r in range(ROWS):
            c = ws.cell(row0 + 3 + r, 1, f'{4 * r}  ({53 + 4 * r} deg)'); c.font = bold; c.fill = hdr
            for k in range(COLS):
                v = g[r][k]
                ws.cell(row0 + 3 + r, 2 + k, fmt(v) if fmt else v)
        rng = f'B{row0 + 3}:{get_column_letter(1 + COLS)}{row0 + 2 + ROWS}'
        ws.conditional_formatting.add(rng, ColorScaleRule(start_type='min', start_color='63BE7B',
                                                          mid_type='percentile', mid_value=50, mid_color='FFEB84',
                                                          end_type='max', end_color='F8696B'))
        return row0 + 3 + ROWS + 1

    # index
    ws = wb.create_sheet('maps_index')
    heading(ws, 'KLR maps and tables', [
        note,
        'Axes: 43h = throttle index, 3Ah (deg) - 53, 0-28. 44h = rpm index from 24h through the A00h table, '
        '0 (highest rpm) - 60 (lowest). The 2D maps use 43h/4 (rows) and 44h/4 (columns) and interpolate in quarter '
        'steps; the 925h constants and the 992h gain use 44h/8 (and 43h/8) without interpolation.',
        'Order in the housekeeping list (0800h): boost map, rpm axis, CV map, ADC angles, rpm constants + gain.',
        'The dashboard testbench logs each lookup as KLR: [LKUP] <ms>,<id>,<result>,<input>=<value>,... '
        '(ids below); the dashboard\'s KLR MAPS tab charts them.',
    ])
    ws.append(['id', 'name', 'address', 'bytes', 'inputs', 'result to', 'routine', 'purpose'])
    for c in ws[ws.max_row]:
        c.font = bold; c.fill = hdr
    for d in defs(img):
        ws.append([d['id'], d['name'], f"{d['addr']:04X}h", d['size'], d['axes'], d['out'], d['routine'], d['purpose']])
    widths(ws, [8, 26, 9, 6, 9, 20, 52, 90])

    # boost
    ws = wb.create_sheet('boost_map_C00')
    heading(ws, 'Target boost map, C00h (8 x 16)', [
        note, 'boost_target_map_read (0A8Dh): interpolated by 0C80h on 43h and 44h; 51h = result - 57h (knock reduction).',
        'Units: MAP ADC counts as 52h (~1.22 x kPa absolute - 4). Columns are 44h/4: column 0 = highest rpm.'])
    g = grid(img, BOOST)
    r = map_grid(ws, g, ws.max_row + 1, 'raw (decimal)')
    map_grid(ws, g, r + 1, '~kPa absolute ((x + 4) / 1.22)', lambda v: round((v + 4) / 1.22, 1))
    widths(ws, [24] + [9] * COLS)

    # cv
    ws = wb.create_sheet('cv_map_B00')
    heading(ws, 'Cycling valve open-loop duty map, B00h (8 x 16)', [
        note, 'cv_open_loop_map_read (0A82h): interpolated by 0C80h on 43h and 44h; result to 68h (boost feed-forward).',
        'Units: on-time counts of the 193-count CV PWM period (final on-time is capped at 177). Columns are 44h/4: column 0 = highest rpm.'])
    g = grid(img, CV)
    r = map_grid(ws, g, ws.max_row + 1, 'raw (decimal)')
    map_grid(ws, g, r + 1, 'duty % (x / 193)', lambda v: round(100 * v / 193, 1))
    widths(ws, [24] + [9] * COLS)

    # rpm axis
    ws = wb.create_sheet('rpm_axis_A00')
    heading(ws, 'RPM axis, A00h', [
        note, 'rpm_axis_lookup (0A57h): r4 = ~24h + 38h; r6 counts up adding code[A00h + r6/4] to r4 until it '
        'carries; 44h = min(r6, 60). Ticks are 24h as stored.',
        f'rpm ~ {RPM_K:.0f} / (ticks + {RPM_C}) (fitted to the KLR memory map page; the tick ranges are exact).'])
    ws.append(['offset', 'address', 'increment', '44h covered'])
    for c in ws[ws.max_row]:
        c.font = bold; c.fill = hdr
    for k in range(16):
        ws.append([k, f'{RPM_AXIS + k:04X}h', img[RPM_AXIS + k], f'{4 * k}-{4 * k + 3}'])
    ws.append([])
    ws.append(['44h', '24h ticks', '~rpm', 'map column (44h/4)', 'constants column (44h/8)'])
    for c in ws[ws.max_row]:
        c.font = bold; c.fill = hdr
    for i, lo, hi, rlo, rhi in axis:
        ws.append([i, '-' if lo is None else (f'{lo}' if lo == hi else f'{lo}-{hi}'),
                   fmt_span(None if lo is None else (rlo, rhi)), i // 4, i // 8])
    widths(ws, [8, 12, 14, 20, 24])

    # constants
    ws = wb.create_sheet('rpm_consts_925')
    c, g0 = consts(img)
    heading(ws, 'RPM-dependent constants, 925h', [
        note, 'load_axis_hi_read (0900h): 9-byte entries [destination, 8 values by 44h/8], ended by 00h '
        f'(at {g0 - 1:04X}h). No interpolation.'])
    ws.append(['entry', 'dest', 'name', 'purpose'] + [f'44h {8 * k}-{min(8 * k + 7, 60)}' for k in range(8)])
    for cc in ws[ws.max_row]:
        cc.font = bold; cc.fill = hdr
    ws.append(['', '', '', '~rpm'] + col8_span)
    for cc in ws[ws.max_row]:
        cc.fill = hdr
    for a, dest, vals in c:
        n, p = CONST_NAMES.get(dest, (f'RPM_K_{dest:02X}', 'unknown'))
        ws.append([f'{a:04X}h', f'{dest:02X}h', n, p] + vals)
    widths(ws, [8, 6, 28, 52] + [11] * 8)

    # gain
    ws = wb.create_sheet('pid_gain_992')
    ga, gg = gain(img)
    heading(ws, f'Boost PID gain, {ga:04X}h (4 x 8)', [
        note, f'load_axis_lo_read (0919h): code[{ga:04X}h + (43h & 18h) + 44h/8] -> 6Bh, no interpolation. '
        'Bit-packed (see jhnbyrn klr_boost_control_gain). Values in hex.'])
    ws.append(['43h \\ 44h'] + [f'{8 * k}-{min(8 * k + 7, 60)}' for k in range(8)])
    for cc in ws[ws.max_row]:
        cc.font = bold; cc.fill = hdr
    ws.append(['~rpm'] + col8_span)
    for cc in ws[ws.max_row]:
        cc.fill = hdr
    for r in range(4):
        ws.append([f'{8 * r}-{min(8 * r + 7, 28)}  ({53 + 8 * r}-{min(60 + 8 * r, 81)} deg)'] + [f'{v:02X}' for v in gg[r]])
    widths(ws, [24] + [11] * 8)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('image')
    ap.add_argument('--xlsx', help='workbook to add / replace the map sheets in')
    a = ap.parse_args()
    img = load_image(a.image)
    if a.xlsx:
        import openpyxl
        wb = openpyxl.load_workbook(a.xlsx)
        write_sheets(wb, img, os.path.basename(a.image))
        wb.save(a.xlsx)
        print(f'{a.xlsx}: wrote {", ".join(SHEETS)} from {a.image}')
        return
    for d in defs(img):
        print(f"{d['id']}  {d['name']:<26} {d['addr']:04X}h  in {d['axes']:<9} -> {d['out']}")
    for i, lo, hi, rlo, rhi in rpm_axis(img):
        print(f'44h={i:2d}  ticks {lo}-{hi}  {fmt_span(None if lo is None else (rlo, rhi))}')


if __name__ == '__main__':
    main()
