# KLR full-load output (P1.5) floats high during reset

The KLR's full-load signal (KLR pin 18, CPU port P1.5) goes high briefly on
every crank trigger, whatever the throttle position. The cause is the hardware
itself, not a decision by the KLR firmware.

## Why it happens

- The KLR's crank trigger drives the CPU's /RESET (an Intel 8049, 8048 family). The CPU is held in reset
  for each trigger pulse, once per cylinder at 80° bTDC (see the
  `var_timing_generator` comment in `klr/bench/verilog/klr_tb.v`).
- The 8049's quasi-bidirectional ports float high while in reset. They stay
  high after release until the firmware rewrites P1.
- So P1.5 reads "full load" for the reset pulse, plus the short time until the
  firmware's first P1 write after it.

Each excursion lasts the reset pulse plus that run-in. (An earlier note put it
at "about 11 ms"; that was the spacing of the old phase monitor's log lines,
one trigger period at ~2700 rpm, not a measured width: the monitor sampled the
pin on the first reset clock and so logged the float itself. It now logs the
level from the clock before each reset.) The KLR's own throttle state stays at
ordinary part throttle throughout: in cl_ramp_to_3000_FQS2, 3Ah
held at 0x26, far below the 0x43 WOT threshold. In that run a probe counted 123
DME ch6 samples that saw full_load high. 76 were taken while the KLR was in
reset, and 47 just after release, before the first P1 write.

## Why the car doesn't care

The DME reads the full-load line on its throttle-switch ADC channel (ch6)
through its input network: R762 (47 kΩ) into the ADC pin's 100 nF capacitor,
so τ ≈ 4.7 ms. That RC averages the reset pulses away. A real WOT signal,
which holds steady, still charges the node up into the firmware's WOT bucket
(table 0x1124: 0xB8–0xE6, sim value 0xCC).

## In the sim

- `klr/rtl/verilog/klr_top.v` documents the same in its header
  ("full_load (P1.5) during reset").

- `dme/bench/verilog/i8051_dashboard_tb.v` models that RC as `full_load_rc`,
  with its time constant set by `FULL_LOAD_TAU_US` (default 4700). ch6 moves
  continuously from off-idle 0xF2 towards WOT 0xCC along it.
- Before that RC existed, the full-load line went straight into the ADC. The
  DME could then catch a pulse, and cl_ramp_to_3000_FQS2 read ch6 = 0xCC at
  part throttle. That run's DME timing happened to line its ADC samples up with
  the pulses (fixed in #125).
- `validate_dash_log.py` classifies ch6 by the firmware's own buckets, not by
  exact bytes.

## What this means on a bench or scope

When probing KLR pin 18 directly, expect narrow high pulses once per crank
trigger at any throttle position. They're normal. Judge the full-load signal
after the DME's RC, or by its duty/average, not by single edges.
