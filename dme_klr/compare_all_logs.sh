#!/bin/bash
# ============================================================
#  compare_all_logs.sh
#
#  Compares all iverilog vs Verilator dashboard (.dash.log)
#  simulation logs using compare_sim_logs.py.
#
#  Usage:
#    ./compare_all_logs.sh [--variant 86|89|carpokes]
#                          [--iv-dir DIR] [--vl-dir DIR] [test1 test2 ...]
#
#  By default compares all known tests in tmp/dme_klr/dash_logs
#  (iverilog) against tmp/dme_klr/v_dash_logs (Verilator).  Pass
#  test names to compare a subset.
#
#  --variant V   compare the results compare_rom_variants.sh archived
#                for variant V: tmp/dme_klr/rom_compare/V/dash_logs vs
#                tmp/dme_klr/rom_compare/V/v_dash_logs
#  --iv-dir DIR  iverilog log directory (overrides the default/--variant)
#  --vl-dir DIR  Verilator log directory (overrides the default/--variant)
#
#  Output:
#    Prints MATCH/NEAR-MATCH/NOTE/DIFF/ROM-MISMATCH/SKIP per test.
#    NOTE = the differences start with iverilog's KLR X branches
#    (expected, not a DIFF). ROM-MISMATCH = the two logs' [ROM] lines
#    name different DME or KLR images (e.g. the shared log folders hold
#    different variants after compare_rom_variants.sh), so they are
#    not compared.
#    Writes summary to <Verilator log dir>/compare_all.log
#    Exit code 0 if all MATCH/NEAR-MATCH/NOTE, 1 if any DIFF or
#    ROM-MISMATCH.
# ============================================================

# -h / --help: print the header comment above and exit before anything runs.
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPARE="$SCRIPT_DIR/compare_sim_logs.py"

# ── Log directories (mirror v_run_dashboard_tests.sh) ────────
BASE="$(cd "$SCRIPT_DIR" && cd ../../tmp/dme_klr 2>/dev/null || \
        { mkdir -p ../../tmp/dme_klr && cd ../../tmp/dme_klr; } && pwd)"

IV_DASH_DIR="$BASE/dash_logs"
VL_DASH_DIR="$BASE/v_dash_logs"

# ── Options: --variant / --iv-dir / --vl-dir; the rest are test names ──
VARIANT=""; IV_OVERRIDE=""; VL_OVERRIDE=""
_names=()
while [ $# -gt 0 ]; do
    case "$1" in
        --variant)   VARIANT="${2:?--variant needs 86, 89 or carpokes}"; shift 2 ;;
        --variant=*) VARIANT="${1#*=}"; shift ;;
        --iv-dir)    IV_OVERRIDE="${2:?--iv-dir needs a directory}"; shift 2 ;;
        --iv-dir=*)  IV_OVERRIDE="${1#*=}"; shift ;;
        --vl-dir)    VL_OVERRIDE="${2:?--vl-dir needs a directory}"; shift 2 ;;
        --vl-dir=*)  VL_OVERRIDE="${1#*=}"; shift ;;
        -*)          echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
        *)           _names+=("$1"); shift ;;
    esac
done
set -- ${_names[@]+"${_names[@]}"}

if [ -n "$VARIANT" ]; then
    IV_DASH_DIR="$BASE/rom_compare/$VARIANT/dash_logs"
    VL_DASH_DIR="$BASE/rom_compare/$VARIANT/v_dash_logs"
fi
[ -n "$IV_OVERRIDE" ] && IV_DASH_DIR="$IV_OVERRIDE"
[ -n "$VL_OVERRIDE" ] && VL_DASH_DIR="$VL_OVERRIDE"
for _d in "$IV_DASH_DIR" "$VL_DASH_DIR"; do
    [ -d "$_d" ] || { echo "No such log directory: $_d" >&2; exit 2; }
done

# Prints "<DME rom> <sha> | <KLR rom> <sha>" from a log's [ROM] lines
# (empty for older logs written before the [ROM] line existed).
rom_id() {
    local dme klr
    dme=$(grep -m1 '^DME: \[ROM\]' "$1" 2>/dev/null | awk '{print $3, $4}')
    klr=$(grep -m1 '^KLR: \[ROM\]' "$1" 2>/dev/null | awk '{print $3, $4}')
    [ -n "$dme$klr" ] && echo "$dme | $klr"
}

# ── All known tests ───────────────────────────────────────────
DASH_TESTS=(
    ac_on_idle
    afm_open_circuit
    afm_short_to_ground
    airtemp_fail
    airtemp_open_circuit
    altitude_disconnected
    battery_disconnected
    cl_ac_halfway
    cl_cold_start
    cl_condition_cycle
    cl_condition_cycle_idle
    cl_ramp_to_3000
    cl_ramp_to_3000_BOOST
    cl_ramp_to_3000_BOOST_OPEN_CIRCUIT
    cl_ramp_to_3000_KLR_BATT_DISCONNECTED
    cl_ramp_to_3000_KLR_BATT_LOW
    cl_ramp_to_3000_KLR_FULL_LOAD_STUCK_HIGH
    cl_ramp_to_3000_KLR_IGN_IN_STUCK_HIGH
    cl_ramp_to_3000_KLR_IGN_IN_STUCK_LOW
    cl_ramp_to_3000_KLR_KNOCK_BLOCKED
    cl_ramp_to_3000_KLR_TPS_SUPPLY_LOST
    cl_ramp_to_3000_KLR_TPS_SUPPLY_LOW
    cl_ramp_to_3000_KLR_TRIGGER_STUCK_HIGH
    cl_ramp_to_3000_KLR_TRIGGER_STUCK_LOW
    cl_ramp_to_3000_TPS0
    cl_ramp_to_4500
    cl_ramp_to_5000_BOOST_LOW
    cl_ramp_to_6000
    cl_ramp_to_6000_BOOST
    cl_ramp_to_6000_BOOST_LOW
    cl_wot_3000_BOOST_ZERO
    cl_ramp_to_6000_FQS0
    cl_ramp_to_6000_FQS1
    cl_ramp_to_6000_FQS2
    cl_ramp_to_6000_FQS3
    cl_ramp_to_6000_FQS4
    cl_ramp_to_6000_FQS5
    cl_ramp_to_6000_FQS6
    cl_ramp_to_6000_FQS7
    cl_ramp_to_6000_KLR_ADC0_NOISE_HIGH
    cl_ramp_to_6000_KLR_ADC0_NOISE_LOW
    cl_ramp_to_6000_KLR_FULL_LOAD_STUCK_LOW
    cl_ramp_to_redline
    cl_tippy_in
    cl_warm_idle
    cold_start
    coolant_fail
    coolant_open_circuit
    dme_klr_warm_idle
    dwell_scaling
    fuel_qual_disconnected
    hot_idle
    idle_battery_low
    idle_high_alt
    idle_poor_fuel
    ignition_timing
    isv_cold_idle
    isv_load_droop
    knock_sensor_defect
    knock_sensor_short_to_ground
    o2_baseline
    o2_disconnected
    o2_lean_stuck
    o2_rich_stuck
    overrun_cutoff
    ramp_6k_hold
    ramp_to_3000
    ramp_to_6000
    ramp_to_6000_FQS0
    ramp_to_6000_FQS1
    ramp_to_6000_FQS2
    ramp_to_6000_FQS3
    ramp_to_6000_FQS4
    ramp_to_6000_FQS5
    ramp_to_6000_FQS6
    ramp_to_6000_FQS7
    ramp_to_6000_knock
    ramp_to_6300
    ramp_to_redline
    ramp_to_redline_KLR_TPS_HIGH
    ref_sensor_loss
    ref_sensor_missing_at_start
    ref_sensor_stuck_low
    speed_sensor_loss
    speed_sensor_stuck_low
    tps_ch6_open_circuit
    tps_ch6_short_to_ground
    tps_fail
    tps_open_circuit
    warm_idle
    warm_idle_5s
    warmup_enrichment
)

# ── Parse arguments ───────────────────────────────────────────
MODE="--dash"

if [ $# -gt 0 ]; then
    TESTS=("$@")
else
    TESTS=("${DASH_TESTS[@]}")
    # Also pick up any test run_dashboard_tests.sh defines (its single-test
    # case labels) that isn't listed above, e.g. one added later or the
    # replay tests, so the list going stale can't silently drop a test.
    # Logs left over from tests that no longer exist are not compared.
    for _n in $(sed -n 's/^        \([A-Za-z0-9_]*\))[[:space:]]*run_\(replay_\)\{0,1\}test .*/\1/p' \
                    "$SCRIPT_DIR/run_dashboard_tests.sh"); do
        case " ${TESTS[*]} " in *" $_n "*) ;; *) TESTS+=("$_n") ;; esac
    done
fi

IV_DIR="$IV_DASH_DIR"
VL_DIR="$VL_DASH_DIR"
SUFFIX=".dash.log"
OUT_LOG="$VL_DASH_DIR/compare_all.log"

mkdir -p "$(dirname "$OUT_LOG")"
> "$OUT_LOG"

START_TIME=$(date +%s)
echo ""
echo "============================================================"
printf "  Log comparison  [mode: %s]\n" "${MODE#--}"
printf "  IV  : %s\n" "$IV_DIR"
printf "  VL  : %s\n" "$VL_DIR"
printf "  Tests: %d\n" "${#TESTS[@]}"
echo "============================================================"
echo ""

N_MATCH=0; N_NEAR=0; N_NOTE=0; N_DIFF=0; N_ROM=0; N_SKIP=0

for name in "${TESTS[@]}"; do
    iv_log="$IV_DIR/${name}${SUFFIX}"
    vl_log="$VL_DIR/${name}${SUFFIX}"

    # Skip infra logs that aren't test logs
    case "$name" in
        compare|parallel_summary|summary|validation) continue ;;
    esac

    if [ ! -f "$iv_log" ] && [ ! -f "$vl_log" ]; then
        printf "  %-10s %-26s %s\n" "SKIP" "$name" "neither log exists"
        printf "SKIP\t%s\tneither log exists\n" "$name" >> "$OUT_LOG"
        N_SKIP=$(( N_SKIP + 1 ))
        continue
    fi

    if [ ! -f "$iv_log" ]; then
        printf "  %-10s %-26s %s\n" "SKIP" "$name" "no iverilog reference"
        printf "SKIP\t%s\tno iverilog reference\n" "$name" >> "$OUT_LOG"
        N_SKIP=$(( N_SKIP + 1 ))
        continue
    fi

    if [ ! -f "$vl_log" ]; then
        printf "  %-10s %-26s %s\n" "SKIP" "$name" "no verilator log"
        printf "SKIP\t%s\tno verilator log\n" "$name" >> "$OUT_LOG"
        N_SKIP=$(( N_SKIP + 1 ))
        continue
    fi

    # Only compare logs that ran the same ROM images.
    iv_rom=$(rom_id "$iv_log"); vl_rom=$(rom_id "$vl_log")
    if [ -n "$iv_rom" ] && [ -n "$vl_rom" ] && [ "$iv_rom" != "$vl_rom" ]; then
        detail="iv: $iv_rom   vl: $vl_rom"
        printf "  \033[35m%-10s\033[0m %-26s %s\n" "ROM-MISMATCH" "$name" "$detail"
        printf "ROM-MISMATCH\t%s\t%s\n" "$name" "$detail" >> "$OUT_LOG"
        N_ROM=$(( N_ROM + 1 ))
        continue
    fi

    result=$(python3 "$COMPARE" "$MODE" "$iv_log" "$vl_log" "$name" 2>&1)
    rc=$?
    verdict=$(echo "$result" | cut -f1)
    detail=$(echo "$result"  | cut -f3-)

    colour=""; reset="\033[0m"
    case "$verdict" in
        MATCH)      colour="\033[32m"; N_MATCH=$(( N_MATCH + 1 )) ;;
        NEAR-MATCH) colour="\033[33m"; N_NEAR=$(( N_NEAR + 1 )) ;;
        NOTE)       colour="\033[36m"; N_NOTE=$(( N_NOTE + 1 )) ;;
        DIFF)       colour="\033[31m"; N_DIFF=$(( N_DIFF + 1 )) ;;
        ERROR)      colour="\033[31m"; N_DIFF=$(( N_DIFF + 1 )) ;;
        *)          colour="";         N_SKIP=$(( N_SKIP + 1 )) ;;
    esac

    printf "  ${colour}%-10s${reset} %-26s %s\n" "$verdict" "$name" "$detail"
    printf "%s\t%s\t%s\n" "$verdict" "$name" "$detail" >> "$OUT_LOG"
done

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo "============================================================"
printf "  Complete — %dm%ds   MATCH=%d  NEAR=%d  NOTE=%d  DIFF=%d  ROM-MISMATCH=%d  SKIP=%d\n" \
       "$MINS" "$SECS" "$N_MATCH" "$N_NEAR" "$N_NOTE" "$N_DIFF" "$N_ROM" "$N_SKIP"
echo "============================================================"
if [ "$N_ROM" -gt 0 ]; then
    echo ""
    echo "  $N_ROM test(s) ran different ROM images in iverilog and Verilator,"
    echo "  so they were not compared. Re-run the stale side, or compare an"
    echo "  archived variant: ./compare_all_logs.sh --variant 86|89|carpokes"
fi
echo ""

# ── Sorted summary: DIFF first, then NOTE, NEAR-MATCH, MATCH ──
if [ -f "$OUT_LOG" ]; then
    for prefix in DIFF ERROR ROM-MISMATCH NOTE NEAR-MATCH MATCH SKIP; do
        grep "^${prefix}" "$OUT_LOG" 2>/dev/null | \
            awk -F'\t' -v p="$prefix" '{printf "  %-12s %-26s %s\n", p, $2, $3}'
    done
fi

echo ""
echo "  Full results: $OUT_LOG"
echo ""

[ $(( N_DIFF + N_ROM )) -gt 0 ] && exit 1 || exit 0
