DME + KLR Simulation Debug Console: lite package
Version @VERSION@ for @PLATFORM@

This is the 944 Turbo DME (Intel 8051) + KLR (Intel 8048) live simulator,
prebuilt, for use with the web dashboard. It gives you the dashboard's live
mode: run, pause and step both CPUs, breakpoints, RAM and port views, engine
inputs, snapshots, and swapping ROM images. The model's Verilog source is
not included, and Verilator, iverilog and GTKWave are not needed; the
developer install (the 944turbo_dme_klr repository) has the source and
also runs the regression tests.

The disassembly workbooks (dme/disassemble, klr/disassemble *.xlsx) and the
scripts that turn them into the debugger's listings are included: edit a
workbook and the listing is rebuilt the next time that ROM loads.

NEEDS
  Node.js 18 or newer             https://nodejs.org
  Python 3 with pandas, openpyxl, pip install -r requirements.txt
  matplotlib and numpy            (listings from edited workbooks, and the
                                  graphs on the MAPS tabs)
  bash                            to rebuild listings (on Windows, Git Bash
                                  or MSYS2); without it the packaged
                                  listings are used

START
  macOS / Linux:   ./run_lite.sh
  Windows:         run_lite.cmd
  Then open https://whalenlg.github.io/dme-dashboard/ and press LIVE.
  The bridge listens only on 127.0.0.1:8951 (--port changes it).

  On macOS, run_lite.sh clears the "downloaded from the internet" flag on
  this folder so the unsigned simulator may run.

WHERE THINGS GO
  Snapshots and the map-graph cache go to data/ in this folder. Set
  DMEKLR_TMP to put them elsewhere.

REGRESSION TESTS
  python3 run_tests.py            all of them (python3 run_tests.py --help)
  python3 run_tests.py -j 4 cl_ramp_*      some, 4 at a time
  They run on the prebuilt testbench in dme_klr/runtime/ and are checked as
  in the developer install (PASS / WARN / FAIL). The logs go to
  data/dme_klr/v_dash_logs/: open a <test>.dash.log in the dashboard. A
  WARN or FAIL adds a TEST row to the live page's SNAPSHOTS list; LOAD
  runs that test to the moment it warned, paused in the debugger.
  DME_ROM_FILE / KLR_ROM_FILE pick other ROM images, as for run_lite.sh.

CONTENTS
  dme_klr/live/obj/dme_klr_live   the simulator
  dme_klr/live/obj/tests_rt/      the simulator for TEST rows (any test)
  dme_klr/runtime/                the regression testbench (run_tests.py)
  run_tests.py                    runs and checks the regression tests
  dme_klr/live/bridge.mjs         connects it to the dashboard
  bin_images/                     DME and KLR ROM images (.mem)
  dme/, klr/disassemble/          disassembly workbooks, scripts and tables
  NOTICE.txt                      third-party notices
