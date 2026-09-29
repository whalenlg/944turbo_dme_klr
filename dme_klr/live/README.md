# Live DME+KLR simulator

Runs the combined `dme_klr_dashboard_tb` as an interactive process that the
web dashboard (whalenlg/dme-dashboard, LIVE mode) can drive: run, pause,
step instructions, PC breakpoints, and live inputs.

```sh
./build_live.sh          # Verilator >= 5.03x; builds obj/dme_klr_live
node bridge.mjs          # starts the sim, serves http://127.0.0.1:8951
```

Then open the dashboard and press **LIVE**.

## Inputs (`set <name> <value>`)

| name | drives | default |
|---|---|---|
| `rpm`, `rpm_slew` | crank generator target RPM, and RPM change per ms | 840, 1 |
| `afm` | DME ADC ch0 (`auto` = follow the RPM model) | auto |
| `tps` | KLR TPS angle input (`auto` = follow AFM, as in the test runs) | auto |
| `coolant`, `airtemp`, `battery`, `altitude`, `fuel_qual` | DME ADC ch3, ch2, ch1, ch4, ch7 raw bytes | warm-idle values |
| `boost` | KLR MAP ADC ch4 raw byte | 0x85 |

## Commands

The sim takes one command per line on stdin, so it also works straight from
a terminal (`obj/dme_klr_live +vcd=/dev/null`). See the header of
`sim_main.cpp` for the full list: `run`, `pause`, `step dme|klr [N]`,
`until <ms>`, `set`, `bp add|del dme|klr <hex>`, `bp clear`, `snap`,
`trace dme|klr [N]`, `status`, `quit`.

The build uses `-DLIVE`, which swaps the compile-time `TEST_*` stimulus for
registers in `dme_klr_dashboard_tb.v`. Without `-DLIVE` the testbenches are
unchanged, so `v_run_dashboard_tests.sh` behaves as before.

Speed: about 20 simulated ms per wall-clock second (~50x slower than real
time) on a 4-core cloud container.
