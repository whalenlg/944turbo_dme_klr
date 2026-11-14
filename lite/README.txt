DME + KLR Simulation Debug Console: lite package
Version @VERSION@ for @PLATFORM@

This is the 944 Turbo DME (Intel 8051) + KLR (Intel 8048) live simulator,
prebuilt, with its own copy of the web dashboard, so it runs with no
internet connection. It gives you the dashboard's live mode: run, pause and step both CPUs, breakpoints, RAM and port views, engine
inputs, snapshots, and swapping ROM images. The model's Verilog source is
not included, and Verilator, iverilog and GTKWave are not needed; the
developer install (the 944turbo_dme_klr repository) has the source and
also runs the regression tests.

The disassembly workbooks (dme/disassemble, klr/disassemble *.xlsx) and the
scripts that turn them into the debugger's listings are included: edit a
workbook and the listing is rebuilt the next time that ROM loads.

NEEDS
  Node.js 18 or newer             https://nodejs.org (the installer)
  Python 3 with pandas, openpyxl, for listings from edited workbooks and
  matplotlib and numpy            the graphs on the MAPS tabs (SETTING UP)
  bash                            to rebuild listings (on Windows, Git Bash
                                  or MSYS2); without it the packaged
                                  listings are used

SETTING UP (once)
  1. Unpack the download and open a terminal in the folder it makes,
     dmeklr-lite-<version>-<platform> (this README's folder; on Windows a
     Command Prompt):
       tar -xzf dmeklr-lite-<version>-<platform>.tar.gz
       cd dmeklr-lite-<version>-<platform>
     (macOS may already have unpacked it, or left a .tar: tar -xf works
     for that. On Windows: right-click the .zip, Extract All.)
  2. Install Node.js 18 or newer from https://nodejs.org.
  3. Install the Python packages, from this folder:
       macOS / Linux:   python3 -m pip install --user -r requirements.txt
       Windows:         py -m pip install --user -r requirements.txt
       Arch Linux:      sudo pacman -S nodejs python-pandas python-openpyxl
                        python-matplotlib python-numpy
     (Use "python3 -m pip", not "pip": macOS has no "pip" command. If pip
     refuses with "externally-managed-environment", make a virtual
     environment here instead: python3 -m venv .venv, then
     .venv/bin/pip install -r requirements.txt; run_lite.sh uses .venv
     when it is there.)

START
  1. In a terminal in this folder (on Windows you can also double-click
     run_lite.cmd), start it. This starts Node.js with the bridge, which
     starts the simulator:
       macOS / Linux:   ./run_lite.sh
       Windows:         run_lite.cmd
  2. Open http://127.0.0.1:8951/?live in a browser. The dashboard comes
     from this folder (dashboard/) and connects in live mode; no internet
     is needed. Ctrl+C in the terminal stops it.
  The bridge listens only on 127.0.0.1:8951 (--port changes it, and the
  address it prints). The hosted dashboard,
  https://whalenlg.github.io/dme-dashboard/, also works with it: press LIVE.

  On macOS, run_lite.sh clears the "downloaded from the internet" flag on
  this folder so the unsigned simulator may run.

NEW VERSIONS
  Releases: https://github.com/whalenlg/944turbo_dme_klr/releases
  Latest build: that repository's Actions tab, Lite package workflow,
  latest run on main, Artifacts (signed in to GitHub). The user manual
  (docs/USER_MANUAL.md there, "The lite package") has the details.

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
  dme_klr/live/bridge.mjs         connects it to the dashboard, and
                                  serves dashboard/
  dashboard/                      the web dashboard, built for offline use
  bin_images/                     DME and KLR ROM images (.mem, .bin)
  dme/, klr/disassemble/          disassembly workbooks, scripts and tables
  NOTICE.txt                      third-party notices

BUILDING THIS PACKAGE (developers)
  The package is made from the developer install (the 944turbo_dme_klr
  repository, set up by its install/ scripts):
    lite/make_lite.sh               builds the simulators, fetches the
                                    dashboard from GitHub
                                    (whalenlg/dme-dashboard, main; or
                                    --dashboard-ref <branch or tag>),
                                    builds it with npm, and writes the
                                    package and its archive to
                                    $DMEKLR_TMP/lite
    lite/test_lite.sh <archive>     checks a package on this machine
                                    (run in the folder holding one
                                    package, it finds it by itself)
  dashboard/VERSION.txt names the dme-dashboard commit it was built from.
  To package dashboard changes not yet on GitHub: --dashboard <checkout>.
  The dashboard alone: in a dme-dashboard checkout, npm ci once, then
  npm run dev (a development server), npm run build (the hosted site) or
  npm run build:lite (this package's copy, into dist-lite/).
