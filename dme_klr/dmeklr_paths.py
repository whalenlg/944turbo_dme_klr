"""Where the repo is and where its output goes (the Python side of paths.sh).

    REPO      this checkout
    TMP       DMEKLR_TMP if set, else a "tmp" folder beside the checkout
    IV_LOGS   TMP/dme_klr/dash_logs    (run_dashboard_tests.sh, iverilog)
    VL_LOGS   TMP/dme_klr/v_dash_logs  (v_run_dashboard_tests.sh, Verilator)
"""
import os
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TMP = Path(os.environ.get('DMEKLR_TMP') or (REPO.parent / 'tmp')).expanduser().resolve()
IV_LOGS = TMP / 'dme_klr' / 'dash_logs'
VL_LOGS = TMP / 'dme_klr' / 'v_dash_logs'
