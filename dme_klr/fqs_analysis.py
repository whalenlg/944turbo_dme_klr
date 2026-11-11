#!/usr/bin/env python3
"""
fqs_analysis.py — Compare fuel injection pulse width across FQS sweep tests.

Reads DME: [STATUS] lines from both iverilog and Verilator dash logs,
extracts fuel_hb/fuel_lb, and shows how _FUEL_QUAL affects steady-state
injection pulse width.

Usage:
    python3 fqs_analysis.py [log_dir_iv] [log_dir_vl]
    python3 fqs_analysis.py --verilator          # Verilator logs only
    python3 fqs_analysis.py --iverilog           # iverilog logs only
    python3 fqs_analysis.py --iv-dir DIR --vl-dir DIR

Defaults:
    iv: $DMEKLR_TMP/dme_klr/dash_logs
    vl: $DMEKLR_TMP/dme_klr/v_dash_logs

The RPM / ign / load / WOT / FQS-gate columns come from the iverilog log
when it has steady-state data, otherwise from the Verilator log (marked
with a trailing '*').
"""

import argparse
import re
import os
import sys
from pathlib import Path
from dmeklr_paths import IV_LOGS, VL_LOGS  # DMEKLR_TMP (see paths.sh)

# FQS test definitions
FQS_TESTS = [
    ('cl_ramp_to_6000_FQS0', '0x00',   0),   # sw pos 0: 0.000V
    ('cl_ramp_to_6000_FQS1', '0x3B',  59),   # sw pos 1: 1.143V
    ('cl_ramp_to_6000_FQS2', '0x5A',  90),   # sw pos 2: 1.754V
    ('cl_ramp_to_6000_FQS3', '0x75', 117),   # sw pos 3: 2.281V
    ('cl_ramp_to_6000_FQS4', '0x81', 129),   # sw pos 4: 2.516V
    ('cl_ramp_to_6000_FQS5', '0x91', 145),   # sw pos 5: 2.839V
    ('cl_ramp_to_6000_FQS6', '0x9C', 156),   # sw pos 6: 3.048V
    ('cl_ramp_to_6000_FQS7', '0xA7', 167),   # sw pos 7: 3.254V
    # Reference: base cl_ramp_to_6000 (no FQS override)
    ('cl_ramp_to_6000',      'N/A',   -1),
    # --- non-CL (open-loop) sweeps: RPM is scripted via STEP_CLOCKS, not
    # fuel-derived, so there's no RPM-convergence confound the way there
    # is for the cl_ramp_to_* families above — all 8 positions per base
    # share the identical RPM trajectory. ---
    ('ramp_to_6000_FQS0', '0x00',   0),
    ('ramp_to_6000_FQS1', '0x3B',  59),
    ('ramp_to_6000_FQS2', '0x5A',  90),
    ('ramp_to_6000_FQS3', '0x75', 117),
    ('ramp_to_6000_FQS4', '0x81', 129),
    ('ramp_to_6000_FQS5', '0x91', 145),
    ('ramp_to_6000_FQS6', '0x9C', 156),
    ('ramp_to_6000_FQS7', '0xA7', 167),
    # Reference: base ramp_to_6000 (no FQS override)
    ('ramp_to_6000',      'N/A',   -1),
]

# FQS timing retard gate (DME 1C24, see jhnbyrn 951-KLR-PAGES ignition
# timing overview): FQS bit 2 set (positions 4-7), RPM > 1600, and either
# WOT (flags 23h.1) or load_idx (iram 0x49) > 0x50 (80).
FQS_LOAD_MIN = 0x50

# Also check RPM range to find steady-state
RPM_STEADY = 5000  # prpm threshold for 6000RPM tests


def parse_ign_delays(path, t_start=15000, t_end=25000, min_delay=100):
    """Parse KLR IGN_OUT asserted events, return delay_from_ign_in values.
    
    delay_from_ign_in is the crank-to-spark delay in microseconds.
    Shorter delay = more retard (spark fires closer to crank reference).
    Filter to t_start-t_end ms window for stable steady-state comparison.
    """
    delays = []
    try:
        with open(path) as f:
            for line in f:
                if 'IGN_OUT asserted' not in line: continue
                mt = re.search(r't=(\d+)', line)
                md = re.search(r'delay_from_ign_in=([\d.]+)', line)
                if mt and md:
                    t = int(mt.group(1))
                    d = float(md.group(1))
                    if t_start <= t <= t_end and d > min_delay:
                        delays.append(d)
    except FileNotFoundError:
        pass
    return delays


def steady_state_timing(delays):
    """Return timing stats from IGN delay list."""
    if not delays: return None
    return {'avg': sum(delays)/len(delays), 'n': len(delays),
            'min': min(delays), 'max': max(delays)}


def parse_status_lines(path):
    """Parse DME: [STATUS] lines, return list of dicts."""
    results = []
    try:
        with open(path) as f:
            for line in f:
                if not line.startswith('DME: [STATUS]'):
                    continue
                d = {}
                m = re.search(r't=(\d+)', line)
                if m:
                    d['t'] = int(m.group(1))
                for field, pat in [
                    ('fuel_hb', r'fuel_hb\(4B\)=0x([0-9a-fA-F]+)'),
                    ('fuel_lb', r'fuel_lb\(4A\)=0x([0-9a-fA-F]+)'),
                    ('prpm',    r'prpm\(37\)=0x([0-9a-fA-F]+)'),
                    ('load',    r'load\(46:47\)=0x([0-9a-fA-F]+)'),
                    ('dwell',      r'dwell\(2F\)=0x([0-9a-fA-F]+)'),
                    ('timing_adv', r'timing_adv\(31\)=0x([0-9a-fA-F]+)'),
                    ('wu',         r'wu\(58:59\)=0x([0-9a-fA-F]+)'),
                    ('load_idx',   r'load_idx\(49\)=0x([0-9a-fA-F]+)'),
                    ('flags23',    r'\(23\)=0x([0-9a-fA-F]+)'),
                ]:
                    mm = re.search(pat, line)
                    if mm:
                        d[field] = int(mm.group(1), 16)
                if 'fuel_hb' in d and 'fuel_lb' in d:
                    hb, lb = d['fuel_hb'], d['fuel_lb']
                    d['fuel_ms'] = ((hb << 8) | lb) * 2 / 1000
                if 'prpm' in d:
                    d['rpm'] = d['prpm'] * 40
                results.append(d)
    except FileNotFoundError:
        pass
    return results


def steady_state_stats(snapshots, rpm_min=RPM_STEADY):
    """Return stats for snapshots where RPM >= rpm_min."""
    ss = [s for s in snapshots if s.get('rpm', 0) >= rpm_min and s.get('fuel_ms', 0) > 0]
    if not ss:
        return None
    fuels = [s['fuel_ms'] for s in ss]
    rpms  = [s['rpm'] for s in ss]
    loads = [s['load_idx'] for s in ss if 'load_idx' in s]
    wots  = [(s['flags23'] >> 1) & 1 for s in ss if 'flags23' in s]
    return {
        'load_avg': (sum(loads) / len(loads)) if loads else None,
        'wot_frac': (sum(wots) / len(wots)) if wots else None,
        'n':        len(ss),
        'fuel_min': min(fuels),
        'fuel_max': max(fuels),
        'fuel_avg': sum(fuels) / len(fuels),
        'rpm_avg':  sum(rpms) / len(rpms),
        't_start':  ss[0]['t'],
        't_end':    ss[-1]['t'],
    }


DEFAULT_IV = IV_LOGS
DEFAULT_VL = VL_LOGS


def parse_args(argv=None):
    ap = argparse.ArgumentParser(
        description="FQS sweep injection pulse width analysis (iverilog vs Verilator dash logs).")
    ap.add_argument('iv_pos', nargs='?', metavar='log_dir_iv',
                    help=f"iverilog dash_logs dir (default {DEFAULT_IV})")
    ap.add_argument('vl_pos', nargs='?', metavar='log_dir_vl',
                    help=f"Verilator dash_logs dir (default {DEFAULT_VL})")
    ap.add_argument('--iv-dir', help="iverilog dash_logs dir (same as first positional)")
    ap.add_argument('--vl-dir', help="Verilator dash_logs dir (same as second positional)")
    sim = ap.add_mutually_exclusive_group()
    sim.add_argument('--verilator', '-V', action='store_true',
                     help="Verilator logs only; skip iverilog")
    sim.add_argument('--iverilog', '-I', action='store_true',
                     help="iverilog logs only; skip Verilator")
    a = ap.parse_args(argv)
    iv = a.iv_dir or a.iv_pos
    vl = a.vl_dir or a.vl_pos
    iv_dir = None if a.verilator else (Path(iv).expanduser() if iv else DEFAULT_IV)
    vl_dir = None if a.iverilog else (Path(vl).expanduser() if vl else DEFAULT_VL)
    for name, d in (('iverilog', iv_dir), ('Verilator', vl_dir)):
        if d is not None and not d.is_dir():
            print(f"warning: {name} log dir not found: {d}", file=sys.stderr)
    return iv_dir, vl_dir


def main():
    iv_dir, vl_dir = parse_args()

    print(f"\n{'='*80}")
    print(f"  FQS Fuel Quality Sweep — Injection Pulse Width Analysis")
    print(f"  Steady-state = RPM ≥ {RPM_STEADY}")
    print(f"  IV : {iv_dir if iv_dir else '(skipped)'}")
    print(f"  VL : {vl_dir if vl_dir else '(skipped)'}")
    print(f"  FQS timing gate: FQS pos 4-7, RPM > 1600, and WOT or load_idx(49) > {FQS_LOAD_MIN}")
    print(f"  RPM/ign/load/WOT/gate from IV; '*' = taken from VL (no IV data)")
    print(f"{'='*80}\n")

    print(f"{'Test':<30} {'FQ_VAL':>6} {'Dec':>4}  "
          f"{'IV fuel_ms':>17}  {'VL fuel_ms':>17}  {'Diff%':>6}  {'RPM':>7}  {'ign(mid)':>14}  {'Load(49)':>8}  {'WOT%':>4}  FQS gate")
    print(f"{'-'*30} {'-'*6} {'-'*4}  {'-'*17}  {'-'*17}  {'-'*6}  {'-'*7}  {'-'*14}  {'-'*8}  {'-'*4}  {'-'*8}")

    results = []
    for test, fq_hex, fq_dec in FQS_TESTS:
        iv_snaps = parse_status_lines(iv_dir / f'{test}.dash.log') if iv_dir else []
        vl_snaps = parse_status_lines(vl_dir / f'{test}.dash.log') if vl_dir else []
        HALF_TEETH_DEG = 360.0 / 264.0
        rpm_thresh = RPM_STEADY

        iv_ss = steady_state_stats(iv_snaps, rpm_thresh)
        vl_ss = steady_state_stats(vl_snaps, rpm_thresh)

        # Reference sim for the RPM/ign/load/WOT/gate columns: iverilog when
        # it has steady-state data, else Verilator (marked '*').
        if iv_ss or not vl_ss:
            ref_snaps, ref_ss, mark = iv_snaps, iv_ss, ''
        else:
            ref_snaps, ref_ss, mark = vl_snaps, vl_ss, '*'
        # Extract steady-state timing_adv (iram[0x31]) from STATUS lines
        # This is the clean half-teeth measurement — no IGN delay noise
        ss_adv = [s['timing_adv'] for s in ref_snaps
                  if s.get('rpm',0) >= rpm_thresh and 'timing_adv' in s]
        ref_timing_adv = (sum(ss_adv)/len(ss_adv)) if ss_adv else None

        iv_str = f"{iv_ss['fuel_avg']:.3f}ms ({iv_ss['n']}pts)" if iv_ss else "  no data"
        vl_str = f"{vl_ss['fuel_avg']:.3f}ms ({vl_ss['n']}pts)" if vl_ss else "  no data"

        if iv_ss and vl_ss and iv_ss['fuel_avg'] > 0:
            diff_pct = (vl_ss['fuel_avg'] - iv_ss['fuel_avg']) / iv_ss['fuel_avg'] * 100
            diff_str = f"{diff_pct:+.1f}%"
        else:
            diff_pct = None
            diff_str = "   N/A"

        rpm_str = f"{ref_ss['rpm_avg']:.0f}{mark}" if ref_ss else "N/A"

        if ref_timing_adv is not None:
            adv_deg = ref_timing_adv * HALF_TEETH_DEG
            timing_str = f"{ref_timing_adv:.1f}ht ({adv_deg:.1f}°){mark}"
        else:
            timing_str = "  N/A"
        load = ref_ss['load_avg'] if ref_ss else None
        wot = ref_ss['wot_frac'] if ref_ss else None
        load_str = f"{load:.0f}{mark}" if load is not None else "N/A"
        wot_str = f"{wot*100:.0f}{mark}" if wot is not None else "N/A"
        if load is None and wot is None:
            gate_str = "?"
        elif (wot or 0) >= 0.5:
            gate_str = "open WOT"
        elif load is not None and load > FQS_LOAD_MIN:
            gate_str = "open"
        else:
            gate_str = "closed"
        if gate_str != "?":
            gate_str += mark
        # Suppress VL column if diff is implausibly large (>50%) — VL test not run yet
        if diff_pct is not None and abs(diff_pct) > 50:
            vl_str = "  (not run)"
            diff_str = "   N/A"
        print(f"{test:<30} {fq_hex:>6} {fq_dec:>4}  {iv_str:>17}  {vl_str:>17}  {diff_str:>6}  {rpm_str:>7}  {timing_str:>14}  {load_str:>8}  {wot_str:>4}  {gate_str}")

        results.append((test, fq_dec, iv_ss, vl_ss, diff_pct, ref_timing_adv))

    # ── FQS effect analysis ───────────────────────────────────────────────────
    # The helper takes an exact base_name and fqs_prefix (str.startswith,
    # not "in"): a loose substring match ('ramp_to_6000' in test) would sweep
    # the non-CL ramp_to_6000_FQS* entries into the CL cl_ramp_to_6000_FQS*
    # table, comparing fuel against the wrong family's baseline.

    def print_fqs_effect_detailed(title, base_name, fqs_prefix, results):
        """6000-style section: IV+VL fuel, plus IGN timing_adv comparison."""
        print(f"\n{'='*80}")
        print(f"  {title}")
        print(f"{'='*80}")

        base = next((r for r in results if r[0] == base_name), None)
        base_iv = base[2]['fuel_avg'] if base and base[2] else None
        base_vl = base[3]['fuel_avg'] if base and base[3] else None
        fqs_results = [(r[0], r[1], r[2], r[3], r[5] if len(r) > 5 else None)
                        for r in results if r[0].startswith(fqs_prefix)]

        if not fqs_results:
            print(f"\n  (no data for {fqs_prefix}*)")
            return

        if base_iv or base_vl:
            b_iv = f"IV {base_iv:.3f}ms" if base_iv else "IV N/A"
            b_vl = f"VL {base_vl:.3f}ms" if base_vl else "VL N/A"
            print(f"\n  Base ({base_name}, no FQS override): {b_iv}, {b_vl}\n")

        print(f"  {'FQS':<5} {'Dec':>4}  {'IV fuel_ms':>10}  {'vs base':>8}  {'VL fuel_ms':>10}  {'vs base':>8}  {'IGN delay':>10}  {'vs FQS0':>18}")
        print(f"  {'-'*5} {'-'*4}  {'-'*10}  {'-'*8}  {'-'*10}  {'-'*8}  {'-'*10}  {'-'*18}")
        base_timing = None
        HALF_TEETH_DEG = 360.0 / 264.0

        for test, fq_dec, iv_ss, vl_ss, iv_t in fqs_results:
            fqs_num = test.split('FQS')[1] if 'FQS' in test else '?'
            iv_f = iv_ss['fuel_avg'] if iv_ss else None
            vl_f = vl_ss['fuel_avg'] if vl_ss else None
            iv_base = f"{(iv_f-base_iv)/base_iv*100:+.1f}%" if iv_f and base_iv else "  N/A"
            vl_base = f"{(vl_f-base_vl)/base_vl*100:+.1f}%" if vl_f and base_vl else "  N/A"
            iv_str = f"{iv_f:.3f}ms" if iv_f else "  N/A"
            vl_str = f"{vl_f:.3f}ms" if vl_f else "  N/A"
            t_avg = iv_t
            if t_avg is not None and base_timing is None and fqs_num == "0":
                base_timing = t_avg
            t_str = f"{t_avg:.1f}ht" if t_avg is not None else "  N/A"
            if t_avg is not None and base_timing is not None:
                diff_ht = t_avg - base_timing
                t_vs_deg = f"{diff_ht*HALF_TEETH_DEG:+.2f}°"
                t_vs = f"{diff_ht:+.1f}ht ({t_vs_deg})"
            else:
                t_vs = "  N/A"
            print(f"  FQS{fqs_num:<2} {fq_dec:>4}  {iv_str:>10}  {iv_base:>8}  {vl_str:>10}  {vl_base:>8}  {t_str:>10}  {t_vs:>18}")

        sim, fuels = 'IV', [r[2]['fuel_avg'] for r in fqs_results if r[2]]
        if not fuels:
            sim, fuels = 'VL', [r[3]['fuel_avg'] for r in fqs_results if r[3]]
        if fuels:
            fuel_range = max(fuels) - min(fuels)
            print(f"\n  {sim} fuel range across FQS sweep: {min(fuels):.3f} – {max(fuels):.3f}ms")
            print(f"  Range: {fuel_range:.3f}ms ({fuel_range/min(fuels)*100:.1f}%)")
            if fuel_range < 0.05:
                print(f"\n  ⚠  WARNING: FQS has almost NO effect on fuel pulse width!")
                print(f"     _FUEL_QUAL may not be connected to the fuel calculation.")
            else:
                print(f"\n  ✓  FQS is affecting fuel — range of {fuel_range:.3f}ms seen.")

    print_fqs_effect_detailed(
        "FQS Effect on Fuel (CL, cl_ramp_to_6000)",
        'cl_ramp_to_6000', 'cl_ramp_to_6000_FQS', results)

    print_fqs_effect_detailed(
        "FQS Effect on Fuel (non-CL, ramp_to_6000)",
        'ramp_to_6000', 'ramp_to_6000_FQS', results)

    print()


if __name__ == '__main__':
    main()
