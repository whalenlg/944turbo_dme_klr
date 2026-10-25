#!/usr/bin/env python3
"""Export full-length operands (and descriptions) for the live debugger.

The asm_*.hex tables the bridge reads hold 20-character fields, which cuts
off long symbol names (e.g. "jb FUELCUT_REACT_MODE, label37"). This reads
the same ASM sheets the hex tables are generated from and writes
asm_full.json next to this script:

    {"dme": {"<addr>": {"label": ..., "ops": ..., "num": ..., "desc": ...}}, "klr": {...}}

bridge.mjs uses it when present. Re-run after editing the spreadsheets:

    python3 dme_klr/live/asm_full.py

With --dme <xlsx> --out <json> it writes only the DME rows of that workbook
({"dme": {...}}); dme_klr/dme_asm_select.sh uses this to put an asm_full.json
in each disassemble/asm_<image>/ directory, which the bridge prefers for
whichever DME image is loaded.
"""
import json
import os
import sys

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
SOURCES = {
    # cpu: (xlsx, operand column, numeric operand column)
    'dme': (os.path.join(REPO, 'disassemble', 'disassembleperformance.xlsx'), 'operand_mapped', 'operands numeric'),
    'klr': (os.path.join(REPO, 'bin_images', 'klr', '87KLR951.xlsx'), 'operands', None),
}


def text(v):
    return '' if pd.isna(v) else str(v).strip()


def addr(v):
    try:
        return int(str(v).lower().replace('0x', '').replace(':', '').strip(), 16)
    except ValueError:
        return None


def main():
    sources, dest = SOURCES, os.path.join(HERE, 'asm_full.json')
    if '--dme' in sys.argv:
        args = dict(zip(sys.argv[1::2], sys.argv[2::2]))
        if '--out' not in args:
            print('usage: asm_full.py [--dme <xlsx> --out <json>]')
            return 2
        sources = {'dme': (os.path.abspath(args['--dme']),) + SOURCES['dme'][1:]}
        dest = args['--out']
    out = {}
    for cpu, (path, ops_col, num_col) in sources.items():
        df = pd.read_excel(path, sheet_name='ASM')
        rows = {}
        for _, r in df.iterrows():
            a = addr(r['Addr'])
            if a is None or not text(r['instr']):
                continue
            e = {'ops': text(r[ops_col]), 'label': text(r['labels']).rstrip(':')}
            if num_col:
                e['num'] = text(r[num_col])
            if text(r.get('long_description')):
                e['desc'] = text(r['long_description'])
            rows[str(a)] = e
        out[cpu] = rows
        print(f'{cpu}: {len(rows)} rows from {os.path.relpath(path, REPO)}')
    with open(dest, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
