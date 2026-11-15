"""Where the repo is and where its output goes (the Python side of paths.sh).

    REPO      this checkout
    TMP       DMEKLR_TMP if set, else a "tmp" folder beside the checkout
    LOGS      TMP/dme_klr/<rom>: the ROM pair's log folder (paths.sh's
              DMEKLR_LOGS), <rom> from DME_ROM_FILE / KLR_ROM_FILE
              (rom_variant(): 89, 86, carpokes or the DME image's name)
    IV_LOGS   LOGS/dash_logs    (run_dashboard_tests.sh, iverilog)
    VL_LOGS   LOGS/v_dash_logs  (v_run_dashboard_tests.sh, Verilator)
    rom_logs(variant)  TMP/dme_klr/<variant>, e.g. rom_logs('86')
"""
import os
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TMP = Path(os.environ.get('DMEKLR_TMP') or (REPO.parent / 'tmp')).expanduser().resolve()

# The three named pairs (run89.sh, run86.sh, run_carpokes.sh); paths.sh's
# dmeklr_rom_variant and live/logdirs.mjs name them the same way
_NAMED = {('89DME_951pin', '89KLR_951'): '89', ('28PIN_86DME', '86KLR_951'): '86',
          ('28PIN_DME_PERFORMANCE', '87KLR_951'): 'carpokes'}


def rom_variant(dme=None, klr=None):
    """The log folder name of a ROM pair (default: DME_ROM_FILE / KLR_ROM_FILE)."""
    stem = lambda f: os.path.splitext(os.path.basename(f.replace('\\', '/')))[0]
    d = stem(dme or os.environ.get('DME_ROM_FILE') or '89DME_951pin.mem')
    k = stem(klr or os.environ.get('KLR_ROM_FILE') or '89KLR_951.mem')
    return _NAMED.get((d, k)) or re.sub(r'[^A-Za-z0-9_.+-]', '_', d)


def rom_logs(variant):
    return TMP / 'dme_klr' / variant


LOGS = rom_logs(rom_variant())
IV_LOGS = LOGS / 'dash_logs'
VL_LOGS = LOGS / 'v_dash_logs'
