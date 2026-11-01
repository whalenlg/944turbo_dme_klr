# Live DME+KLR simulator

Runs the combined `dme_klr_dashboard_tb` as an interactive process that the
web dashboard (whalenlg/dme-dashboard, LIVE mode) can drive: run, pause,
step instructions, PC breakpoints, and live inputs.

```sh
./build_live.sh          # Verilator >= 5.03x; builds obj/dme_klr_live
node bridge.mjs          # starts the sim, serves http://127.0.0.1:8951 (this Mac only;
                         # pages from whalenlg.github.io and localhost only)
```

Then open the dashboard and press **LIVE**.

## ROM images

`build_live.sh` compiles in the default images (`DME_ROM_FILE` /
`KLR_ROM_FILE`), but another `.mem` image can be loaded without a rebuild
while the sim is paused: the dashboard's **ROM IMAGES** row shows the image
in each EPROM and has a **LOAD .mem** button per CPU. With **RESTART AFTER
LOAD** ticked (the default) the sim restarts at t=0 on the new image, so the
firmware boots from its reset vector; unticked, the image is swapped in
place and the CPU carries on from its current PC and RAM.

The bridge saves uploaded images under `obj/roms/<cpu>/` and passes them to
every later restart (`+dme_rom=<path>` / `+klr_rom=<path>`), until another
image is loaded or the bridge itself is restarted. From a terminal:
`rom dme|klr <path>` while paused. The bridge refuses a KLR image (any
`bin_images/klr/*.mem`, matched by content or file name) loaded into the DME.

Each debugger listing follows the image in that CPU's EPROM. Each time the
sim reports an image (start, restart, load), the bridge matches it, by
content and then by file name, against the images that have a workbook:

| image | listing from |
|---|---|
| `28PIN_DME_PERFORMANCE.mem` | `dme/disassemble/disassembleperformance.xlsx` |
| `28PIN_86DME.mem` | `dme/disassemble/disassemble1986.xlsx` |
| `89DME_951pin.mem` | `dme/disassemble/disassemble1989.xlsx` |
| `87KLR_951.mem` | `klr/disassemble/87KLR951.xlsx` |
| `86KLR_951.mem` | `klr/disassemble/86KLR951.xlsx` |
| `89KLR_951.mem` | `klr/disassemble/89KLR951.xlsx` |

It brings that workbook's tables in `<cpu>/disassemble/asm_<image>/` up to
date (`dme_klr/asm_select.sh`, the same helper the run scripts use, so a
changed `disassembleperformance.xlsx` or `87KLR951.xlsx` regenerates the
other years' workbooks too), swaps the listing, and sends
`SIM: [ASM] dme|klr <workbook> match=...`; the dashboard then fetches the
listing again and shows the workbook in the ROM IMAGES row. An image that
matches none of them keeps the default `<cpu>/disassemble/` listing and
shows **ASM: no workbook**. `--dme-asm <dir>` / `--klr-asm <dir>` pin a
listing to one directory instead.

## Snapshots

Whenever the model prints a warning or error (a line with `[WARN]`,
`WARNING` or `ERROR`, e.g. `DME: [WARN] ... INJ PW ... > one rev`, a dead-code
entry, `ERROR: Unimplemented Opcode`), the sim saves a snapshot of the whole
model into `../tmp/dme_klr/snapshots/<date>-t<ms>ms-<warning>/` (beside the
checkout, with `run_dashboard_tests.sh`'s `dash_logs`; `node bridge.mjs
--snapdir <dir>` picks another place), and the run carries on.
**SAVE NOW** in the dashboard (or `save [label]`) takes one by hand. The
dashboard's **SNAPSHOTS** row lists them; **LOAD** restarts the sim from that
moment, so you can set breakpoints, step and change inputs from there.
Breakpoints you've set before LOAD are kept, added to any the snapshot
saved; for a regression TEST snapshot they take effect from its time on, so
the run up to it doesn't stop on them.
After a load the sim is paused at the snapshot's time, the live stats and
the DME / KLR IRAM views show the restored RAM straight away, and any of
RPM, AFM and boost that were on **auto** are pinned to the values they had
at that moment (auto unticked), so the engine holds that operating point
while you step; tick **auto** to let the models take over again
(`+loadpin=0` keeps them on auto). The other inputs (throttle, coolant,
FQS, switches...) are restored as they were.

A snapshot holds:

| file | contents |
|---|---|
| `state.bin` | every variable of the Verilated model: both CPUs' registers, internal RAM and pipeline state, the EPROM arrays, ADCs, timers, the engine/AFM/O2/knock models, testbench pins and Verilator's own edge-detect state; plus the clock and delay timing, inputs, breakpoints and the last 512 instructions of each CPU |
| `sim.json` | the same for reading: the warning line, time, PCs, inputs, CPU registers, DME iram / KLR RAM, testbench signals, the `[DS]` / `[REGS]` lines of that moment, the trace |
| `rom/dme/*.mem`, `rom/klr/*.mem` | the EPROM contents at that moment, as `.mem` images |
| `manifest.json` | (bridge) each image's SHA-256, file name and disassembly workbook |
| `history.log.gz` | (bridge) the last 60,000 lines of the run, replayed to the charts on load |

Loading gives the same run as the original from that time on (checked line
for line, including through a throttle change still inside its 250 ms AFM
lag). It needs the same build of the simulator: `state.bin` lists the model's
variables, and a build from different Verilog or another Verilator version
is refused with a red message under the snapshot list (the sim then stays
at t=0, nothing loaded). A snapshot from someone else's machine only loads
if both simulators were built the same way; otherwise reproduce it from its
**INFO** (inputs, ROMs) and save your own.
After a rebuild of the same Verilog the variables still match, but if the
simulator's code moved (any change to `sim_main.cpp`, another compiler) each
clock keeps its period while its phase is approximated, a shift of well under
a microsecond, and the sim says so (`SIM: [SNAP] loaded ... exact=0`).

Automatic snapshots are taken at most once a sim second per kind of warning
and 25 per run (`autosnap max <n>`). **AUTO ON WARNING** / `autosnap on|off`
turns them off; **PAUSE ON WARNING** / `breakonwarn on` also pauses the sim
after each one. **⬇** downloads a snapshot as one `.dmesnap` file and
**UPLOAD .dmesnap** adds it back, e.g. on another machine with the same build.

How it works: Verilator's own `--savable` refuses `--timing`, so
`build_live.sh` runs `gen_state.py` on the generated headers to list every
member variable (`obj/live_fields.cpp`), and `snapshot.h` saves and restores
those bytes. Processes waiting on a `#delay` are C++ coroutines, which can't
be saved; a restore starts a fresh process, whose coroutines already exist,
and gives each the wake-up time it had when saved. A snapshot is taken at a
moment when no coroutine is part way through a block (the KLR core's `#10`
display delay, for instance), at most a few ns after it was asked for. This
reads `VlDelayScheduler`'s private queue, checked with Verilator 5.038 and
5.048 (5.050 builds).

### Regression-test warnings

The regression runs (`run_dashboard_tests.sh`, `v_run_dashboard_tests.sh`,
`run_dashboard_parallel.sh`) use their own builds with each test's scripted
stimulus, so they can't save a `state.bin`. Instead, after each test
`test_snap.py` scans its log, and for the first warning or error of each
kind (at most 5; or, for a FAIL in `run_dashboard_parallel.sh` with no
warning, the end of the run) writes a folder with `request.json` into the
snapshot directory: the test, its `-D` flags, ROM images, the time and the
line. A rerun of the test replaces its old ones.

They show in the dashboard's SNAPSHOTS list as **TEST** rows. **LOAD**
builds that test with the debugger's hooks (`build_live.sh --test <name>`:
the testbench's `LIVE_DEBUG` without `LIVE`, so its own stimulus stays; in
`obj/tests/<name>/`, a few minutes the first time and reused after) and runs
it to just after that moment, paused, so breakpoints, stepping and the RAM
views work from there. Getting there takes as long as the sim needs to reach
that time. The input controls do nothing in a test run (its inputs follow
the script), it can't be saved, and **RESTART** goes back to the live
simulator.

To open a test at a moment of your choosing without running the
regression, type the test's name and a time in the **TEST … at … ms** row
under the snapshot list (or run `live/test_snap.py add <test> <ms>
[label]`), then LOAD the row it adds.

## Inputs (`set <name> <value>`)

The engine runs on the closed-loop model (`CL_MODE`, `AFM_CL_RAMP`, `BOOST`,
filelist `files_cl`). The throttle is the input: it slews at the same rate
as the `cl_ramp_*` tests, AFM follows it about 250 ms later, the firmware
fuels for that airflow, and RPM comes out of the torque balance in
`var_interrupt_gen_cl.v`. MAP (KLR ch4) is modeled from throttle and RPM
(MAP ~ throttle area / RPM): -17 inHg (~42 kPa abs) at warm idle, deeper
on a closed-throttle overrun (down to -22 inHg), up to ambient as the
throttle opens, and the KLR boost-target table takes over from boost onset
(AFM 0x77).

| name | drives | default |
|---|---|---|
| `tps` | throttle command (0x28 = idle; the cl tests use 0x72 for ~3000 rpm, 0xD8 for ~6400) | 0x28 |
| `rpm` | pin engine RPM instead of the torque balance (`auto` = model) | auto |
| `afm` | pin DME ADC ch0 instead of following the throttle (`auto` = model) | auto |
| `boost` | pin KLR MAP ADC ch4 instead of the MAP-table model (`auto` = model); values above 0xF5 are held at 0xF5 (~+16 psi), since the KLR adds 10 to the reading and anything higher wraps ram[52h] to near-zero (deep vacuum) | auto |
| `fuel_qual` | DME ADC ch7 (FQS); also sets the model's fuel energy like the `*_FQS0..7` tests | 0x00 |
| `coolant`, `airtemp`, `battery`, `altitude` | DME ADC ch3, ch2, ch1, ch4 raw bytes | warm-idle values |

RPM is held at 840 until the firmware first reports EngineSync, as in the
closed-loop tests.

## Commands

The sim takes one command per line on stdin, so it also works straight from
a terminal (`obj/dme_klr_live +vcd=/dev/null`). See the header of
`sim_main.cpp` for the full list: `run`, `pause`, `step dme|klr [N]`,
`until <ms>`, `set`, `bp add|del dme|klr <hex>`, `bp clear`, `snap`, `rom`,
`trace dme|klr [N]`, `save [label]`, `load <dir>`, `autosnap on|off|max <n>`,
`breakonwarn on|off`, `status`, `quit`. From a terminal, `+snapdir=<dir>`
picks where snapshots go and `+load=<dir>` starts from one.

The build uses `-DLIVE`, which swaps the compile-time `TEST_*` stimulus for
registers in `dme_klr_dashboard_tb.v`. Without `-DLIVE` the testbenches are
unchanged, so `v_run_dashboard_tests.sh` behaves as before.

Speed: about 20 simulated ms per wall-clock second (~50x slower than real
time) on a 4-core cloud container.

## Full-length operands

The asm_*.hex tables cut labels and operands at 20 characters. `asm_full.json`
holds them in full (plus the spreadsheets' descriptions, shown as row tooltips)
and the bridge uses it where it agrees with the hex tables. After editing
`dme/disassemble/disassembleperformance.xlsx` or `klr/disassemble/87KLR951.xlsx`, regenerate it
(the per-image copies in `dme/disassemble/asm_*/` and `klr/disassemble/asm_*/` are regenerated automatically)
(needs pandas and openpyxl):

    python3 dme_klr/live/asm_full.py
