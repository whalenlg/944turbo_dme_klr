#!/usr/bin/env python3
"""
xlsx_to_stim.py — turn a recorded DME/KLR data log (.xlsx) into the
open-loop replay testbench's stimulus and expected-output files.

    xlsx_to_stim.py <log.xlsx> <out_prefix> [--start-s S] [--end-s E]
                    [--segment N] [--list-segments]

Writes
    <out_prefix>.stim.csv      t_ms + raw input values, read by replay_main.cpp
    <out_prefix>.expect.csv    t_ms + the log's measured outputs and
                               segment label, read by check_replay.py

Times are seconds from the log's first row. --segment picks one run of
rows sharing a fill colour (the log marks gear pulls that way:
green = 2nd gear, yellow = 3rd); --list-segments prints them.

Input conversions (log value -> raw ADC byte the model reads)
-------------------------------------------------------------
  rpm       ' RPM'                     pinned engine RPM (live_rpm)
  afm       'AFM (V)'                  DME ch0, V * 255/5
  airtemp   'IAT  (V)'                 DME ch2. The logger's "volts" are the
                                       firmware's linearised value
                                       (iram[12h]) * 5/255, not the pin:
                                       the raw byte is found by inverting
                                       the ROM's NTC map (map 1) - raw 0x50
                                       gives 0x9E = 3.10 "V" = 75 F.
  dme_tps   'Throttle Switch (Volts)'  DME ch6, V * 255/5 (idle 2.6 V,
                                       off-idle 4.75 V, WOT 4.0 V)
  altitude  'Altimeter (Volts)'        DME ch4, V * 255/5
  battery   'DME Voltage (V)'          DME ch1, V * 0xD8/13.8 (ASSUMED:
                                       the testbench's nominal 0xD8 taken
                                       as 13.8 V, linear through 0)
  coolant   ' ECT (F)'                 DME ch3. deg C -> linearised value
                                       by the testbench's ntc_celsius()
                                       scale (10 + (lin-143)*70/79, which
                                       also matches the log's IAT pair),
                                       then the ROM's NTC map (map 2)
                                       inverted to the raw byte.
  boost     'MAP Absolute (PSI)'       KLR ch4, Bosch 200 kPa sensor
                                       (4.55*kPa/180 - 0.256) V, x0.945
                                       divider, * 255/5 (see the KLR
                                       memory map's Units Notes), minus
                                       --map-offset (10: the logged MAP
                                       is taken to be ram[52h], which has
                                       the firmware's +10 in it), capped
                                       at 0xF0 so ram[52h] can't wrap
  o2        ' NBO2 (V)'                DME P1.7:6 comparators: >= 0.6 V
                                       rich (3), <= 0.3 V lean (0), else
                                       crossover (1)
  klr_tps   'Throttle Switch (Status)' KLR TPS angle in afm_wiper units.
                                       The log has no throttle angle, so
                                       (ASSUMED) Idle 0x28, Off Idle 0x60,
                                       Full Load 0xD8 (the cl_ramp tests'
                                       WOT command)
  fuel_qual ' FQS'                     DME ch7, position 0 -> 0x00
  knock     'KLR Knocking'             1 while it reads 'No' (the KLR's
                                       knock line is active low): the
                                       KLR knock_sensor gets the
                                       TEST_KNOCK_PULSE drop on every 4th
                                       TDC (klr_knock_gen.v), else 0

Expected outputs (compared by check_replay.py)
----------------------------------------------
  ign_adv     'Ignition Advance'   deg
  klr_adv     'KLR Ign. Advance'   deg
  klr_retard  'KLR Ign. Retard'    deg
  inj_ms      'Inj. Pulse (ms)'
  dwell_ms    'Ign. Dwell (ms)'
  icv_pct     ' ICV (%)'
  rpm         ' RPM'               (readback sanity check)
  full_load   'Throttle Switch (Status)' == 'Full Load'
  knocking    'KLR Knocking' == 'No' (the KLR's P1.6 knock line is
              active low; each 'No' run ends with one Knock Cnt.)
"""
import argparse
import csv
import os
import sys

import openpyxl

COL = {
    'time': 'Time Stamp',
    'rpm': ' RPM',
    'afm_v': 'AFM (V)',
    'iat_v': 'IAT  (V)',
    'iat_f': 'IAT (F)',
    'ect_f': ' ECT (F)',
    'batt_v': 'DME Voltage (V)',
    'alt_v': 'Altimeter (Volts)',
    'map_psi': 'MAP Absolute (PSI)',
    'nbo2_v': ' NBO2 (V)',
    'tps_v': 'Throttle Switch (Volts)',
    'tps_status': 'Throttle Switch (Status)',
    'fqs': ' FQS',
    'ign_adv': 'Ignition Advance',
    'klr_adv': 'KLR Ign. Advance',
    'klr_retard': 'KLR Ign. Retard',
    'knocking': 'KLR Knocking',
    'knock_cnt': 'KLR Knock Cnt.',
    'inj_ms': 'Inj. Pulse (ms)',
    'dwell_ms': 'Ign. Dwell (ms)',
    'icv_pct': ' ICV (%)',
}

STIM_COLS = ['rpm', 'afm', 'boost', 'coolant', 'airtemp', 'battery', 'altitude',
             'fuel_qual', 'dme_tps', 'klr_tps', 'o2', 'knock']
EXPECT_COLS = ['ign_adv', 'klr_adv', 'klr_retard', 'inj_ms', 'dwell_ms', 'icv_pct',
               'rpm', 'full_load', 'knocking', 'knock_cnt', 'map_psi', 'tps_status']

# <name>.trace.csv: the log's own values for every row, all numeric, which
# replay_driver.v shows as log_* (inputs, in log units) and exp_* (expected
# outputs) signals in the waveform. Order matters: replay_driver.v reads
# them positionally and checks this header.
TRACE_COLS = ['segment',
              'rpm', 'afm_v', 'map_psi', 'ect_f', 'iat_v', 'batt_v', 'alt_v', 'tps_v',
              'nbo2_v', 'tps_status', 'fqs',
              'ign_adv', 'klr_adv', 'klr_retard', 'inj_ms', 'dwell_ms', 'icv_pct',
              'knocking', 'knock_cnt']
TPS_STATUS_CODE = {'Idle': 0, 'Off Idle': 1, 'Full Load': 2}

KLR_TPS_BY_STATUS = {'Idle': 0x28, 'Off Idle': 0x60, 'Full Load': 0xD8}

DEFAULT_ROM = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           '..', '..', 'bin_images', 'dme', '28PIN_DME_PERFORMANCE.mem')


def clamp8(x):
    return max(0, min(255, int(round(x))))


def volts(v):
    return clamp8(v * 255.0 / 5.0)


class NtcMap:
    """The DME's NTC linearisation (maps 1 and 2, read from the ROM image):
    raw ADC byte -> linearised value, as map_lookup at 051Dh computes it
    for iram[12h]/[13h], and its inverse."""

    def __init__(self, rom_path, map_no=2):
        rom = [int(l, 16) for l in open(rom_path) if l.strip()]
        e = rom[0x1090 + map_no] & 0xFE
        addr = (rom[0x11E0 + e] << 8) | rom[0x11E0 + e + 1]
        n = rom[addr + 1]
        self.axis = rom[addr + 2:addr + 2 + n]
        self.vals = rom[addr + 2 + n:addr + 2 + 2 * n]
        self.table = [self._lin(raw) for raw in range(256)]

    def _lin(self, raw):
        n, r0 = len(self.axis), (~raw) & 0xFF      # firmware complements first
        for r1 in range(n, 0, -1):
            s = r0 + self.axis[r1 - 1]
            r0 = s & 0xFF
            if s > 255:
                if r1 == n:
                    return self.vals[n - 1]
                lo, hi = self.vals[r1 - 1], self.vals[r1]
                return lo + round((hi - lo) * r0 / self.axis[r1 - 1])
        return self.vals[0]

    def raw_for(self, lin):
        return min(range(256), key=lambda raw: (abs(self.table[raw] - lin), raw))


def lin_for_f(temp_f):
    """Linearised NTC value for temp_f (inverse of ntc_celsius() in
    i8051_dashboard_tb.v)."""
    c = (temp_f - 32.0) * 5.0 / 9.0
    return 143 + (c - 10.0) * 79.0 / 70.0


def map_raw(psi, offset=10):
    """KLR ch4 byte for a logged absolute MAP: the Bosch 200 kPa sensor
    curve, minus offset, capped at 0xF0 as klr_tb.v caps its own model
    (the firmware's +10 into ram[52h] wraps above 0xF5).

    The offset defaults to 10 because the logger probably reads the KLR's
    ram[52h], which already holds the ADC byte + 10 (KLR 049Bh), so the
    pin gets the byte the ADC must have read."""
    kpa = psi * 6.894757
    v = ((4.55 * kpa / 180.0) - 0.256) * 0.945 * 255.0 / 5.0 - offset
    return min(0xF0, clamp8(v))


def o2_code(v):
    if v >= 0.6:
        return 3
    if v <= 0.3:
        return 0
    return 1


def parse_time(s):
    h, m, sec, us = str(s).split(':')
    return int(h) * 3600 + int(m) * 60 + int(sec) + int(us) / 1e6


def read_log(path):
    wb = openpyxl.load_workbook(path)
    ws = wb.worksheets[0]
    it = ws.iter_rows()
    hdr = [c.value for c in next(it)]
    idx = {}
    for key, name in COL.items():
        if name not in hdr:
            sys.exit(f"column {name!r} not found in {path}")
        idx[key] = hdr.index(name)
    rows = []
    t0 = None
    last_t = None
    for cells in it:
        if cells[0].value is None:
            continue
        t = parse_time(cells[0].value)
        if t0 is None:
            t0 = t
        if last_t is not None and t <= last_t:
            continue          # the logger repeats some rows verbatim
        last_t = t
        fill = cells[0].fill.fgColor.rgb if cells[0].fill.fill_type else None
        r = {k: cells[i].value for k, i in idx.items()}
        r['t_s'] = t - t0
        r['fill'] = fill if isinstance(fill, str) else None
        rows.append(r)
    return rows


def segments(rows):
    """Runs of rows sharing a fill colour: (n, fill, first, last)."""
    out = []
    for i, r in enumerate(rows):
        if not out or out[-1][1] != r['fill']:
            out.append([len(out), r['fill'], i, i])
        else:
            out[-1][3] = i
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('xlsx')
    ap.add_argument('out_prefix', nargs='?')
    ap.add_argument('--start-s', type=float)
    ap.add_argument('--end-s', type=float)
    ap.add_argument('--segment', type=int, action='append',
                    help='fill-colour segment number (repeatable; spans first..last)')
    ap.add_argument('--list-segments', action='store_true')
    ap.add_argument('--map-offset', type=float, default=10,
                    help='raw counts taken off the MAP byte (default 10: the '
                         "log's MAP is the KLR's ram[52h], ADC + 10); 0 drives the sensor curve as is")
    ap.add_argument('--dme-rom', default=os.environ.get('DME_ROM') or DEFAULT_ROM,
                    help='DME ROM .mem for the NTC maps (default: 28PIN_DME_PERFORMANCE.mem)')
    a = ap.parse_args()

    rows = read_log(a.xlsx)
    segs = segments(rows)
    seg_of = {}
    for n, fill, i0, i1 in segs:
        for i in range(i0, i1 + 1):
            seg_of[i] = n
    if a.list_segments or not a.out_prefix:
        for n, fill, i0, i1 in segs:
            print(f"segment {n}: fill={fill or 'none':8s} rows {i0}-{i1}  "
                  f"t={rows[i0]['t_s']:.2f}-{rows[i1]['t_s']:.2f}s  "
                  f"rpm {min(r['rpm'] for r in rows[i0:i1+1]):.0f}-{max(r['rpm'] for r in rows[i0:i1+1]):.0f}")
        return

    start, end = a.start_s, a.end_s
    if a.segment:
        chosen = [s for s in segs if s[0] in a.segment]
        if not chosen:
            sys.exit(f"no segment {a.segment}; see --list-segments")
        start = rows[min(s[2] for s in chosen)]['t_s'] if start is None else start
        end = rows[max(s[3] for s in chosen)]['t_s'] if end is None else end
    sel = [(i, r) for i, r in enumerate(rows)
           if (start is None or r['t_s'] >= start) and (end is None or r['t_s'] <= end)]
    if not sel:
        sys.exit("no rows in the selected window")

    air_map, cool_map = NtcMap(a.dme_rom, 1), NtcMap(a.dme_rom, 2)
    with open(a.out_prefix + '.stim.csv', 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['t_ms'] + STIM_COLS)
        for _, r in sel:
            w.writerow([f"{r['t_s'] * 1000:.3f}",
                        int(round(r['rpm'])),
                        volts(r['afm_v']),
                        map_raw(r['map_psi'], a.map_offset),
                        cool_map.raw_for(lin_for_f(r['ect_f'])),
                        air_map.raw_for(r['iat_v'] * 255.0 / 5.0),
                        clamp8(r['batt_v'] * 0xD8 / 13.8),
                        volts(r['alt_v']),
                        0 if not r['fqs'] else clamp8(r['fqs']),
                        volts(r['tps_v']),
                        KLR_TPS_BY_STATUS.get(r['tps_status'], 0x60),
                        o2_code(r['nbo2_v']),
                        int(r['knocking'] == 'No')])
    with open(a.out_prefix + '.expect.csv', 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['t_ms', 'segment', 'fill'] + EXPECT_COLS)
        for i, r in sel:
            w.writerow([f"{r['t_s'] * 1000:.3f}", seg_of[i], r['fill'] or ''] +
                       [r['ign_adv'], r['klr_adv'], r['klr_retard'], r['inj_ms'], r['dwell_ms'],
                        r['icv_pct'], r['rpm'], int(r['tps_status'] == 'Full Load'),
                        int(r['knocking'] == 'No'), r['knock_cnt'], r['map_psi'], r['tps_status']])
    with open(a.out_prefix + '.trace.csv', 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['t_ms'] + TRACE_COLS)
        for i, r in sel:
            vals = {'segment': seg_of[i],
                    'tps_status': TPS_STATUS_CODE.get(r['tps_status'], 3),
                    'knocking': int(r['knocking'] == 'No')}
            w.writerow([f"{r['t_s'] * 1000:.3f}"] +
                       [vals[c] if c in vals else (r[c] or 0) for c in TRACE_COLS])
    print(f"{len(sel)} rows, t={sel[0][1]['t_s']:.2f}-{sel[-1][1]['t_s']:.2f}s -> "
          f"{a.out_prefix}.stim.csv, .expect.csv, .trace.csv")


if __name__ == '__main__':
    main()
