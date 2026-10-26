# Open-loop log replay testbench

Replays a recorded car data log through the combined DME+KLR model with no
engine model in the loop: every input comes straight from the log, row by
row, and the model's outputs are compared against what the car's DME and
KLR actually did.

```sh
./run_replay.sh                    # first WOT pull of 10_9_evening_WOT_Run.xlsx (t=0-14 s)
./run_replay.sh --list-segments    # the log's fill-colour segments (green = 2nd, yellow = 3rd gear)
./run_replay.sh --segment 5        # second 3rd-gear pull
./run_replay.sh --map-offset 10    # take 10 off the MAP byte (default 0)
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

## In the dashboard test suites

`replay_wot_60s` replays the first 60 s of the log (both 2nd/3rd-gear pulls
and the coast-down into the first knock events) as an ordinary suite test:

```sh
./run_dashboard_tests.sh replay_wot_60s          # iverilog, → dash_logs/ (+ fst/)
./v_run_dashboard_tests.sh replay_wot_60s        # Verilator, → v_dash_logs/
./run_dashboard_parallel.sh 2 Replay             # group name; --verilator for Verilator
```

Results land in the suite's own `dash_logs/` or `v_dash_logs/` beside the
other tests (`run_replay.sh --out-dir`). It takes no debug flags. The
parallel runner's validation reads `<name>.report.txt`: PASS when every channel
meets its pass rate, WARN naming the channels that don't (currently ign_adv,
klr_retard and inj_ms), FAIL only if the replay didn't finish. Expect
about an hour under Verilator and several hours under iverilog.

## Pieces

| file | does |
|---|---|
| `xlsx_to_stim.py` | log → `<name>.stim.csv` (raw input bytes per row) and `<name>.expect.csv` (logged outputs) |
| `replay_driver.v` | the same driver as a second Verilog top, for iverilog |
| `replay_main.cpp` | Verilator driver: holds the first row for `WARMUP_MS` (3000) so the firmware syncs, then applies each row at its timestamp and takes a DS snapshot there |
| `check_replay.py` | pairs each snapshot with its log row, applies tolerances, prints pass rates per channel and per segment, writes every miss to `<name>.mismatches.csv`; exits 1 if a channel passes on fewer than `--min-pass` (90 %) of rows |
| `expect_to_dash.py` | places each played log row's expected outputs at its sim time (from the `SIM: [ROW]` lines) as `REPLAY: [EXPECT]` lines, which `run_replay.sh` appends to `<name>.dash.log` |
| `run_replay.sh` | build if stale, convert, run, check |

Outputs land in `../../tmp/dme_klr/replay/dash_logs/` for iverilog runs and
`../../tmp/dme_klr/replay/v_dash_logs/` for Verilator runs (the same split as
`run_dashboard_tests.sh` / `v_run_dashboard_tests.sh`), so the two can run at
the same time. Each run's `.dash.log` loads into the dashboard like any other,
and carries the log's outputs too: the dashboard draws them as dashed
"LOG (expected)" traces over the matching DME and KLR charts (ignition advance,
injector pulse, dwell, RPM; KLR retard, coil pulse, knock output and count,
boost, full load). For a `.dash.log` from before this, append them by hand:
`./expect_to_dash.py <name>.log <name>.expect.csv >> <name>.dash.log`.

`--iverilog` runs also write `fst/<name>.fst`, made the same way as
`run_dashboard_tests.sh`'s: `vcd.v` / `klr_vcd.v` dump their chosen signals to
`sim.vcd` and `vcd2fst` (from GTKWave) converts it. `--no-fst` skips it and
`--vcd` keeps the VCD too. The VCD runs about 80 MB per simulated second
before conversion. The waveform also carries the log itself, as signals in the
`replay_driver` top, all stepping at each row's time:

| signals | are |
|---|---|
| `row_idx`, `log_t_ms`, `log_segment` | the log row playing (time in log ms) and its fill-colour segment |
| `pin_*` | the raw bytes driven into the model, plus `pin_knock` (`<name>.stim.csv`) |
| `log_rpm`, `log_afm_v`, `log_map_psi`, `log_ect_f`, `log_iat_v`, `log_batt_v`, `log_alt_v`, `log_tps_v`, `log_nbo2_v`, `log_fqs`, `log_tps_status` | the log's input columns in its own units (`log_tps_status` 0 Idle, 1 Off Idle, 2 Full Load) |
| `exp_ign_adv`, `exp_klr_retard`, `exp_inj_ms`, `exp_dwell_ms`, `exp_icv_pct`, `exp_full_load`, `exp_knocking` (1 = knock), `exp_knock_cnt` | the log's outputs: what the model should produce |

The `log_*`/`exp_*` values are real-valued, so set GTKWave's data format
to Analog or Real for them. `xlsx_to_stim.py` writes them to
`<name>.trace.csv`, which the driver finds next to the stim file (or
`+trace=`). Verilator runs make no waveform, because Verilator's
tracing ignores the `$dumpvars` scopes and would dump the whole design.

## Inputs

The replay pins these through the `live_*` registers in
`dme_klr_dashboard_tb.v` (`dme_tps`, `klr_tps` and `o2` were added for the
replay; the live debugger can `set` them too).

| input | from log column | conversion |
|---|---|---|
| `rpm` | RPM | pinned engine RPM |
| `afm` | AFM (V) | DME ch0, V × 51 |
| `airtemp` | IAT (V) | DME ch2, V × 51. The logger's volts are the sensor pin: they fall as IAT (F) rises (157 → 160 counts = 75 → 72 °F), and 3.10 V through the ROM's NTC map reads 20 °C on the `ntc_celsius()` scale (log: 24 °C) |
| `dme_tps` | Throttle Switch (Volts) | DME ch6, V × 51 |
| `altitude` | Altimeter (Volts) | DME ch4, V × 51 |
| `battery` | DME Voltage (V) | DME ch1, **assumed** 0xD8 = 13.8 V, linear |
| `coolant` | ECT (F) | DME ch3: °C → linearised value by the testbench's `ntc_celsius()` scale (lin × 165/255 − 40), then the ROM's NTC map inverted; ≈0x2E at 190 °F |
| `boost` | MAP Absolute (PSI) | KLR ch4, Bosch 200 kPa sensor × 0.945 divider (KLR memory map, Units Notes), capped at 0xF0 (≈31 psi abs) so the firmware's +10 into ram[52h] can't wrap. The log comes from an f9tech DME with its own 3-bar MAP sensor, so its psi is real pressure: the 33.5 psi peaks (231 kPa) are past what the KLR's stock 200 kPa sensor reads, and sit at the cap. `--map-offset N` (on `run_replay.sh` or `xlsx_to_stim.py`, default 0) takes N counts off, for a log that dumps ram[52h] instead |
| `o2` | NBO2 (V) | ≥ 0.6 V rich, ≤ 0.3 V lean, else crossover |
| `klr_tps` | Throttle Switch (Status) | **assumed**: the log has no throttle angle, so Idle 0x28, Off Idle 0x60, Full Load 0xD8 (afm_wiper units) |
| `fuel_qual` | FQS | position 0 → 0x00 |
| `knock` | KLR Knock Cnt. | 1 on a row where the count goes up (see below): the KLR knock_sensor gets the `TEST_KNOCK_PULSE` drop (32 teeth after TDC, held 107 teeth or until the next TDC) on every TDC (once per revolution), in `klr_knock_gen.v`'s `-DLIVE` branch; 0 leaves it at the nominal 110 |

## Compared outputs

| channel | log column | model side | default tolerance |
|---|---|---|---|
| `ign_adv` | Ignition Advance | DME iram[31h] × 360/264 ° | ±1.5 ° |
| `klr_retard` | KLR Ign. Retard | DME spark command (rising edge of tach A_1, low during dwell) → KLR spark (falling edge of its coil output), in crank ° at the log RPM | ±1.5 ° |
| `inj_ms` | Inj. Pulse (ms) | measured injector pulse: P1.0 low time of the latest pulse (`SIM: [INJ]`); n/a when none ended in the last two revolutions (held open or not firing, counted in the summary) | ±0.3 ms |
| `inj_ms_ram` | Inj. Pulse (ms) | ({4Bh,4Ah} + 5 × 54h) × 2 µs: the computed width plus the injector dead time the firmware adds before loading the timer; informational, never fails the run | ±0.3 ms |
| `dwell_ms` | Ign. Dwell (ms) | last KLR coil-output pulse width | ±0.5 ms |
| `icv_pct` | ICV (%) | ISV P1.4-high share of the timer-1 reloads {41h,40h} / {45h,44h} | ±5 % |
| `rpm` | RPM | iram[37h] × 40 (sanity check that the pin took) | ±80 |
| `full_load` | Throttle Switch (Status) = Full Load | KLR full_load output | exact |
| `knock_cnt` | KLR Knock Cnt. (increase since the first compared row) | the model's KNOCK_OUT pulses (`KLR: [PHASE] ... KNOCK_OUT cleared`) over the same span | ±1 count |

The log has no knock-sensor waveform, only the KLR's own bookkeeping, so the
replay injects the existing knock test's sensor drop (the `knock` input above)
on each row where "KLR Knock Cnt." goes up: one knock the KLR counted. The
log's "KLR Knocking" flag isn't used: it reads "Yes" on about 73 % of the rows,
exactly those where "KLR Ign. Retard" is above 0.5 deg, i.e. while the KLR is
still pulling timing after a knock, so replaying it as the knock signal knocked
far more than the engine did. The report also prints the knock totals for the
window. The first WOT pull has
no knock events in the log; they're all between 55 s and 113 s
(`--start-s 55 --end-s 113`).
