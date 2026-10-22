# Open-loop log replay testbench

Replays a recorded car data log through the combined DME+KLR model with no
engine model in the loop: every input comes straight from the log, row by
row, and the model's outputs are compared against what the car's DME and
KLR actually did.

```sh
./run_replay.sh                    # first WOT pull of 10_9_evening_WOT_Run.xlsx (t=0-14 s)
./run_replay.sh --list-segments    # the log's fill-colour segments (green = 2nd, yellow = 3rd gear)
./run_replay.sh --segment 5        # second 3rd-gear pull
./run_replay.sh --all              # whole log, ~152 s of engine time (about 2 hours)
./run_replay.sh -- --lag-rows 2 --tol ign_adv=2.8   # options after -- go to check_replay.py
./run_replay.sh --iverilog --segment 1              # Icarus instead of Verilator
```

Needs Verilator ≥ 5.038 (5.036 rejects the 8051 core's mixed blocking /
non-blocking assignments), or Icarus Verilog 12 with `--iverilog`, and
Python 3 with openpyxl. `xlsx_to_stim.py` reads the DME ROM image
(`--dme-rom`, default `28PIN_DME_PERFORMANCE.mem`) for the NTC maps. The build is
`dme_klr_dashboard_tb` with `-DLIVE`, like the live debugger, but with its
own driver in `obj/`: `replay_main.cpp` for Verilator, or the
`replay_driver.v` top module for iverilog (elaborated with
`-s dme_klr_dashboard_tb -s replay_driver`). Both read the same stimulus file
and print the same output. Verilator runs at about 20 simulated ms per
wall-clock second, iverilog at about 4.

## Pieces

| file | does |
|---|---|
| `xlsx_to_stim.py` | log → `<name>.stim.csv` (raw input bytes per row) and `<name>.expect.csv` (logged outputs) |
| `replay_driver.v` | the same driver as a second Verilog top, for iverilog |
| `replay_main.cpp` | Verilator driver: holds the first row for `WARMUP_MS` (3000) so the firmware syncs, then applies each row at its timestamp and takes a DS snapshot there |
| `check_replay.py` | pairs each snapshot with its log row, applies tolerances, prints pass rates per channel and per segment, writes every miss to `<name>.mismatches.csv`; exits 1 if a channel passes on fewer than `--min-pass` (90 %) of rows |
| `run_replay.sh` | build if stale, convert, run, check |

Outputs land in `../../tmp/dme_klr/replay/` (beside `dash_logs/`); the
`.dash.log` loads into the dashboard like any other run.

## Inputs

The replay pins these through the `live_*` registers in
`dme_klr_dashboard_tb.v` (`dme_tps`, `klr_tps` and `o2` were added for the
replay; the live debugger can `set` them too).

| input | from log column | conversion |
|---|---|---|
| `rpm` | RPM | pinned engine RPM |
| `afm` | AFM (V) | DME ch0, V × 51 |
| `airtemp` | IAT (V) | DME ch2. The logger's "volts" are the firmware's linearised value (iram[12h]) × 5/255, so the raw byte comes from inverting the ROM's NTC map (raw 0x50 → 0x9E = 3.10 V = 75 °F, which the log agrees with) |
| `dme_tps` | Throttle Switch (Volts) | DME ch6, V × 51 |
| `altitude` | Altimeter (Volts) | DME ch4, V × 51 |
| `battery` | DME Voltage (V) | DME ch1, **assumed** 0xD8 = 13.8 V, linear |
| `coolant` | ECT (F) | DME ch3: °C → linearised value by the testbench's `ntc_celsius()` scale (which also fits the log's IAT pair), then the ROM's NTC map inverted; ≈0x1C at 190 °F |
| `boost` | MAP Absolute (PSI) | KLR ch4, Bosch 200 kPa sensor × 0.945 divider (KLR memory map, Units Notes) |
| `o2` | NBO2 (V) | ≥ 0.6 V rich, ≤ 0.3 V lean, else crossover |
| `klr_tps` | Throttle Switch (Status) | **assumed**: the log has no throttle angle, so Idle 0x28, Off Idle 0x60, Full Load 0xD8 (afm_wiper units) |
| `fuel_qual` | FQS | position 0 → 0x00 |

## Compared outputs

| channel | log column | model side | default tolerance |
|---|---|---|---|
| `ign_adv` | Ignition Advance | DME iram[31h] × 360/264 ° | ±1.5 ° |
| `klr_retard` | KLR Ign. Retard | DME spark command (rising edge of tach A_1, low during dwell) → KLR spark (falling edge of its coil output), in crank ° at the log RPM | ±1.5 ° |
| `klr_adv` | KLR Ign. Advance | `ign_adv − klr_retard` | ±1.5 ° |
| `inj_ms` | Inj. Pulse (ms) | DME iram[4Bh:4Ah] × 2 µs | ±0.3 ms |
| `dwell_ms` | Ign. Dwell (ms) | last KLR coil-output pulse width | ±0.5 ms |
| `icv_pct` | ICV (%) | ISV P1.4-high share of the timer-1 reloads {41h,40h} / {45h,44h} | ±5 % |
| `rpm` | RPM | iram[37h] × 40 (sanity check that the pin took) | ±80 |
| `full_load` | Throttle Switch (Status) = Full Load | KLR full_load output | exact |

The log's knock flag and knock count are carried into `expect.csv` but not
compared: the model's knock sensor is synthetic.
