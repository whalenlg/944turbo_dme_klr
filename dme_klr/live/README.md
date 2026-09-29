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

## Inputs (`set <name> <value>`)

The engine runs on the closed-loop model (`CL_MODE`, `AFM_CL_RAMP`, `BOOST`,
filelist `files_cl`). The throttle is the input: it slews at the same rate
as the `cl_ramp_*` tests, AFM follows it about 250 ms later, the firmware
fuels for that airflow, and RPM comes out of the torque balance in
`var_interrupt_gen_cl.v`. Boost comes from the KLR MAP-table model.

| name | drives | default |
|---|---|---|
| `tps` | throttle command (0x28 = idle; the cl tests use 0x72 for ~3000 rpm, 0xD8 for ~6400) | 0x28 |
| `rpm` | pin engine RPM instead of the torque balance (`auto` = model) | auto |
| `afm` | pin DME ADC ch0 instead of following the throttle (`auto` = model) | auto |
| `boost` | pin KLR MAP ADC ch4 instead of the MAP-table model (`auto` = model) | auto |
| `fuel_qual` | DME ADC ch7 (FQS); also sets the model's fuel energy like the `*_FQS0..7` tests | 0x00 |
| `coolant`, `airtemp`, `battery`, `altitude` | DME ADC ch3, ch2, ch1, ch4 raw bytes | warm-idle values |

RPM is held at 840 until the firmware first reports EngineSync, as in the
closed-loop tests.

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
