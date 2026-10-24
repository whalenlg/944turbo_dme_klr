#!/usr/bin/env python3
"""
expect_to_dash.py — put the log's expected outputs on the replay's
simulation timeline, as lines the dashboard overlays on its charts.

    expect_to_dash.py <sim.log> <expect.csv> >> <name>.dash.log

<sim.log> is the replay's stdout (replay_main.cpp or replay_driver.v),
<expect.csv> comes from xlsx_to_stim.py. Each "SIM: [ROW] idx=i ... t_ns=T"
line places expected row i at simulated time T, and one line per played
row is printed:

    REPLAY: [EXPECT] t=<sim ms> row=<i> seg=<segment> ign_adv=.. klr_adv=..
            klr_retard=.. inj_ms=.. dwell_ms=.. icv_pct=.. rpm=.. full_load=0|1
            knocking=0|1 knock_cnt=.. map_psi=..

(on one line). Rows the run didn't reach are left out, and so is any
field the log left empty. run_replay.sh appends them to <name>.dash.log;
for a replay run before this existed, run it by hand on that run's
<name>.log and <name>.expect.csv.
"""
import csv
import re
import sys

ROW_RE = re.compile(r'^SIM: \[ROW\] idx=(\d+) log_ms=([\d.]+) t_ns=(\d+)')
FIELDS = ['ign_adv', 'klr_adv', 'klr_retard', 'inj_ms', 'dwell_ms', 'icv_pct',
          'rpm', 'full_load', 'knocking', 'knock_cnt', 'map_psi']


def main():
    if len(sys.argv) != 3:
        sys.exit('usage: expect_to_dash.py <sim.log> <expect.csv>')
    sim_log, expect_csv = sys.argv[1:]
    t_ns = {}
    with open(sim_log, errors='replace') as f:
        for line in f:
            m = ROW_RE.match(line)
            if m:
                t_ns[int(m.group(1))] = int(m.group(3))
    with open(expect_csv) as f:
        expect = list(csv.DictReader(f))
    out = sys.stdout
    for i, row in enumerate(expect):
        if i not in t_ns:
            continue
        vals = ' '.join(f'{k}={row[k]}' for k in FIELDS if row.get(k) not in (None, ''))
        out.write(f"REPLAY: [EXPECT] t={t_ns[i] / 1e6:.3f} row={i} seg={row.get('segment') or 0} {vals}\n")
    print(f"  {len(t_ns)} expected rows on the sim timeline", file=sys.stderr)


if __name__ == '__main__':
    main()
