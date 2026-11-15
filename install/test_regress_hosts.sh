#!/usr/bin/env bash
# ============================================================
#  test_regress_hosts.sh — test RUN REGRESSIONS' regression hosts across
#  two machines: this developer install and a second machine on the LAN
#
#  By default the second machine is a macOS VM (Tart, on this Apple Silicon
#  Mac), set up by install/test_macos_vm.sh --keep:
#    lite (default)  the lite package built here (lite/make_lite.sh) runs
#                    as the host: quick (about 10 minutes the first time
#                    the image is there), Verilator tests only
#    --dev           a developer install of this checkout runs as the host
#                    (install_macos.sh in the VM: 20-40 minutes), so the
#                    iverilog suite and its waveforms are tested too
#  or, with --host, any machine already running
#      node dme_klr/live/bridge.mjs --listen 0.0.0.0 --token <secret>
#  (or ./run_lite.sh --listen ...), with this machine's software.
#
#  Then, from this machine:
#    1. the host answers /regress/info with the same software (srchash),
#       and refuses no token, a wrong token, and a different srchash
#    2. a Verilator run (run_dashboard_parallel.sh, 1 worker here + the
#       host's threads) sends tests to the host; every test comes back
#       here with its dash.log and log and is validated here; the host's
#       job folders ($DMEKLR_TMP/dme_klr/remote_jobs) are gone afterwards
#    3. (--dev) the same with iverilog: the remote tests' waveforms come
#       back into dash_logs/fst/
#    4. a run whose host's bridge is stopped mid-run: its tests go back in
#       the queue, run here, and the run completes
#  then prints PASS/FAIL for each check and deletes the VM.
#
#  Usage:  install/test_regress_hosts.sh [options]
#    --dev            the VM runs a developer install (see above)
#    --lite ARCHIVE   the VM runs this lite package (macOS .tar.gz) instead
#                     of one built here
#    --host URL       use this running host instead of a VM (e.g.
#                     http://192.168.1.20:8951); needs --token; step 4 is
#                     skipped (it would stop that bridge)
#    --token T        the host's token (with --host; a VM gets a random one;
#                     default $DMEKLR_REGRESS_TOKEN)
#    --threads N      the host's threads (default 2)
#    --tests "A B"    the tests (default six 5-second ones)
#    --name NAME      VM name (default dmeklr-regress-host)
#    --image IMAGE    VM image (test_macos_vm.sh's default)
#    --reuse          use the VM NAME left running by an earlier --keep run
#                     (skips the setup)
#    --keep           leave the VM running at the end (with its bridge)
#    --out DIR        logs (default $DMEKLR_TMP/regress_hosts_test/<date-time>)
#    -h, --help       this text
#
#  The dashboard's RUN REGRESSIONS panel runs it too (REGRESSION HOSTS, TEST
#  THE NETWORK RUN), with these switches.
#
#  Exit: 0 when every check passed, 1 when any failed, 2 on a usage or
#  setup problem.
# ============================================================

for _arg in "$@"; do
    case "$_arg" in
        -h|--help)
            sed -n '2,/^[^#]/{ /^[^#]/d; /^# ===/d; s/^# \{0,2\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
    esac
done

set -uo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$INSTALL_DIR/.." && pwd)"
# shellcheck source=../paths.sh
source "$REPO_DIR/paths.sh"

DEV=0; LITE=""; HOST_URL=""; TOKEN="${DMEKLR_REGRESS_TOKEN:-}"; THREADS=2; KEEP=0; REUSE=0; OUT=""
VM="dmeklr-regress-host"; IMAGE=""
TESTS="warm_idle_5s idle_battery_low idle_high_alt idle_poor_fuel coolant_fail airtemp_fail"
while [ $# -gt 0 ]; do
    case "$1" in
        --dev)     DEV=1 ;;
        --lite)    LITE="${2:?--lite needs a package}"; shift ;;
        --host)    HOST_URL="${2:?--host needs a URL}"; shift ;;
        --token)   TOKEN="${2:?--token needs a value}"; shift ;;
        --threads) THREADS="${2:?}"; shift ;;
        --tests)   TESTS="${2:?}"; shift ;;
        --name)    VM="${2:?}"; shift ;;
        --image)   IMAGE="${2:?}"; shift ;;
        --reuse)   REUSE=1 ;;
        --keep)    KEEP=1 ;;
        --out)     OUT="${2:?}"; shift ;;
        *) echo "test_regress_hosts.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done

bold=$'\033[1m'; red=$'\033[0;31m'; green=$'\033[0;32m'; yellow=$'\033[1;33m'; nc=$'\033[0m'
[ -t 1 ] || { bold=''; red=''; green=''; yellow=''; nc=''; }
step() { printf '\n%s==> %s%s\n' "$bold" "$*" "$nc"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '%serror:%s %s\n' "$red" "$nc" "$*" >&2; exit 2; }

[[ "$THREADS" =~ ^[1-9][0-9]?$ ]] || die "--threads wants 1-64"
command -v node >/dev/null 2>&1 || die "Node.js isn't on the PATH (source setup first?)"
command -v curl >/dev/null 2>&1 || die "curl isn't on the PATH"
if [ -n "$HOST_URL" ]; then
    [ -n "$TOKEN" ] || die "--host needs --token"
    HOST_URL="${HOST_URL%/}"
else
    [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || die "the VM needs an Apple Silicon Mac; on another machine use --host"
    command -v tart >/dev/null 2>&1 || die "Tart isn't installed: brew tap openai/tools && brew install openai/tools/tart"
    [ -z "$TOKEN" ] && TOKEN="$(node -e 'console.log(require("crypto").randomBytes(12).toString("hex"))')"
fi

[ -z "$OUT" ] && OUT="$DMEKLR_TMP/regress_hosts_test/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT" || die "can't make $OUT"
OUT="$(cd "$OUT" && pwd)"
LTMP="$OUT/tmp"   # this machine's DMEKLR_TMP for the runs, so they leave its own logs alone
ROMV="$(dmeklr_rom_variant)"   # the runs' ROM pair's log folder under it (paths.sh)

RESULTS=(); FAILED=0
result() {  # result PASS|FAIL|SKIP "name" "detail"
    local s="$1" c="$green"
    [ "$s" = FAIL ] && { c="$red"; FAILED=1; }
    [ "$s" = SKIP ] && c="$yellow"
    RESULTS+=("$(printf '%s%-4s%s  %-40s %s' "$c" "$s" "$nc" "$2" "$3")")
    printf '    %s%s%s  %s: %s\n' "$c" "$s" "$nc" "$2" "$3"   # (the RUN REGRESSIONS panel reads these)
}
check() { if [ "$1" = 0 ]; then result PASS "$2" "$3"; else result FAIL "$2" "$3"; fi; }

LOCAL="$(cd "$REPO_DIR" && node -e "import('./dme_klr/live/regress_host.mjs').then(m=>console.log(JSON.stringify(m.softwareVersion(process.cwd()))))")"
SRCHASH="$(printf '%s' "$LOCAL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).srchash||""))')"
[ -n "$SRCHASH" ] || die "this checkout's software version is unknown (not a git checkout?)"

echo "${bold}Regression hosts test${nc}"
info "this machine: $(printf '%s' "$LOCAL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s);console.log(`${v.version} (srchash ${v.srchash})`)})')"
info "logs: $OUT"

# ── The VM ────────────────────────────────────────────────────────────────
VM_USER="admin"; VM_PASS="admin"
ASKPASS="$OUT/.askpass"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
          -o PubkeyAuthentication=no -o "PreferredAuthentications=password,keyboard-interactive"
          -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o ConnectTimeout=10)
IP=""
vm_ssh() { SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}" \
           ssh "${SSH_OPTS[@]}" "$VM_USER@$IP" "$@"; }
# the host's folder in the VM, and how its bridge starts there
if [ "$DEV" = 1 ]; then
    VM_DIR='$HOME/944/944turbo_dme_klr'
    VM_START='source ./setup >/dev/null; S=dme_klr/live/obj/dme_klr_live; [ -x "$S" ] || S=/bin/cat
              nohup node dme_klr/live/bridge.mjs --sim "$S" --listen 0.0.0.0 --token "$TOK"'
else
    VM_DIR='$(ls -d $HOME/lite-test/dmeklr-lite-*/ | head -1)'
    VM_START='export PATH="/usr/local/bin:$PATH"; nohup ./run_lite.sh --listen 0.0.0.0 --token "$TOK"'
fi
vm_bridge() {  # start|stop the host's bridge in the VM
    if [ "$1" = start ]; then
        vm_ssh "cd $VM_DIR && TOK='$TOKEN' DMEKLR_TMP=\$HOME/regress-host-tmp; export TOK DMEKLR_TMP; mkdir -p \$DMEKLR_TMP
                pkill -f 'bridge.mjs.*--listen' 2>/dev/null; sleep 1
                $VM_START > \$HOME/regress-host-bridge.log 2>&1 < /dev/null &
                echo started" </dev/null
    else
        vm_ssh "pkill -f 'bridge.mjs.*--listen'" </dev/null
    fi
}
cleanup() {
    rm -f "$ASKPASS"
    [ -n "$HOST_URL" ] && [ -z "$IP" ] && return
    if [ -n "$IP" ]; then vm_ssh 'cat $HOME/regress-host-bridge.log' </dev/null > "$OUT/vm_bridge.log" 2>/dev/null; fi
    if [ "$KEEP" = 1 ]; then
        printf '\nThe VM %s is still running with its bridge (--keep): %s, token %s\nssh %s@%s (password %s); when done: tart stop %s && tart delete %s\n' \
            "$VM" "$HOST_URL" "$TOKEN" "$VM_USER" "$IP" "$VM_PASS" "$VM" "$VM"
        return
    fi
    if [ -n "$IP" ]; then
        echo; echo "Deleting the VM $VM"
        tart stop "$VM" >/dev/null 2>&1 || true
        tart delete "$VM" >/dev/null 2>&1 || echo "couldn't delete $VM; run: tart delete $VM" >&2
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if [ -z "$HOST_URL" ]; then
    printf '#!/bin/sh\necho %s\n' "$VM_PASS" > "$ASKPASS"; chmod 700 "$ASKPASS"
    if [ "$REUSE" = 1 ]; then
        step "Using the running VM $VM"
        IP="$(tart ip "$VM" --wait 60 2>/dev/null)" || die "no running VM $VM (start it, or drop --reuse)"
    else
        step "Setting up the VM with install/test_macos_vm.sh --keep (log: setup.log)"
        _args=(--name "$VM" --keep --replace --out "$OUT/vm_setup")
        [ -n "$IMAGE" ] && _args+=(--image "$IMAGE")
        if [ "$DEV" = 1 ]; then _args+=(--worktree --skip-clt-check --skip-tests)
        else _args+=(--lite "${LITE:-build}"); fi
        "$INSTALL_DIR/test_macos_vm.sh" "${_args[@]}" > "$OUT/setup.log" 2>&1
        _rc=$?
        IP="$(tart ip "$VM" --wait 60 2>/dev/null)" || die "the VM isn't running after the setup (see $OUT/setup.log)"
        [ "$_rc" = 0 ] || info "${yellow}note:${nc} test_macos_vm.sh reported failures (setup.log); going on with the VM"
        if [ "$DEV" = 1 ]; then
            # the VM's copy isn't a git checkout: it gets this checkout's
            # software version as VERSION.txt
            node "$REPO_DIR/dme_klr/live/regress_host.mjs" version-txt "$REPO_DIR" \
                | vm_ssh "cat > $VM_DIR/VERSION.txt" || die "couldn't write VERSION.txt in the VM"
        fi
    fi
    info "VM $VM at $IP"
    HOST_URL="http://$IP:8951"
    step "Starting the host's bridge in the VM (--listen 0.0.0.0 --token ...)"
    vm_bridge start | sed 's/^/    /'
fi

hcurl() { curl -s -m 20 "$@"; }
for _i in $(seq 1 60); do
    [ "$(hcurl -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$HOST_URL/regress/info")" = 200 ] && break
    [ "$_i" = 60 ] && die "$HOST_URL doesn't answer /regress/info (see vm_bridge.log)"
    sleep 2
done

# ── 1. The host's answers ────────────────────────────────────────────────
step "1. The host: same software, and the refusals"
INFO="$(hcurl -H "Authorization: Bearer $TOKEN" "$HOST_URL/regress/info")"
echo "$INFO" > "$OUT/host_info.json"; info "$INFO"
case "$INFO" in *"\"srchash\":\"$SRCHASH\""*) r=0 ;; *) r=1 ;; esac
check $r "1a. same software (srchash)" "$SRCHASH"
case "$INFO" in *'"iverilog":true'*) HOST_IV=1 ;; *) HOST_IV=0 ;; esac
c1="$(hcurl -o /dev/null -w '%{http_code}' "$HOST_URL/regress/info")"
c2="$(hcurl -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer not-the-token' "$HOST_URL/regress/info")"
c3="$(hcurl -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$HOST_URL/runall")"
[ "$c1" = 403 ] && [ "$c2" = 403 ] && [ "$c3" = 403 ]
check $? "1b. refuses no/wrong token, other pages" "no token $c1, wrong token $c2, /runall $c3"
c4="$(hcurl -o "$OUT/mismatch.txt" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
      -d '{"test":"warm_idle_5s","sim":"verilator","srchash":"0000000000"}' "$HOST_URL/regress/run")"
[ "$c4" = 409 ]; check $? "1c. refuses different software" "HTTP $c4: $(head -c 120 "$OUT/mismatch.txt")"

HOSTS="$OUT/hosts.json"
printf '[{"name":"host","url":"%s","token":"%s","threads":%s}]\n' "$HOST_URL" "$TOKEN" "$THREADS" > "$HOSTS"
chmod 600 "$HOSTS"

# run_suite <log> <sim flag or ""> : 1 worker here, the host's threads there
run_suite() {
    local log="$OUT/$1"; shift
    # shellcheck disable=SC2086
    ( cd "$REPO_DIR/dme_klr" && DMEKLR_TMP="$LTMP" DMEKLR_REGRESS_HOSTS="$HOSTS" \
        bash run_dashboard_parallel.sh "$@" 1 $TESTS ) > "$log" 2>&1
}
host_jobs_left() {  # job folders left on the host (VM only)
    [ -n "$IP" ] || { echo "?"; return; }
    vm_ssh 'ls -A $HOME/regress-host-tmp/dme_klr/remote_jobs 2>/dev/null | wc -l | tr -d " "' </dev/null
}
# check_run <name> <log> <logdir> : every test validated here, some on the host
check_run() {
    local name="$1" log="$2" dir="$3" n_tests n_done n_remote missing="" t
    n_tests=$(echo $TESTS | wc -w | tr -d ' ')
    n_done=$(grep -cE $'^(PASS|WARN|FAIL)\t' "$dir/validation.log" 2>/dev/null); n_done=${n_done:-0}
    n_remote=$(grep -c '\[START\].*@host' "$log")
    for t in $TESTS; do
        [ -s "$dir/$t.dash.log" ] && [ -s "$dir/$t.log.gz" ] || missing="$missing $t"
    done
    [ "$n_done" = "$n_tests" ] && [ "$n_remote" -gt 0 ] && [ -z "$missing" ]
    check $? "$name" "$n_done/$n_tests validated here, $n_remote ran on the host${missing:+; no logs:$missing}"
    grep -E '^\s+\[START\]|^\s+\[REQUEUE\]|Complete' "$log" | sed 's/^/      /'
}

# ── 2. Verilator ─────────────────────────────────────────────────────────
step "2. Verilator run: 1 worker here + $THREADS on the host ($TESTS)"
run_suite 2_verilator.log --verilator
check_run "2a. Verilator tests shared" "$OUT/2_verilator.log" "$LTMP/dme_klr/$ROMV/v_dash_logs"
if [ -z "$IP" ]; then
    result SKIP "2b. host's job folders cleaned up" "--host: can't look on that machine"
else
    left="$(host_jobs_left)"
    [ "$left" = 0 ]; check $? "2b. host's job folders cleaned up" "$left left in remote_jobs"
fi

# ── 3. iverilog (developer host) ─────────────────────────────────────────
step "3. iverilog run: the waveforms come back"
if [ "$HOST_IV" != 1 ]; then
    result SKIP "3. iverilog + waveforms" "the host has no iverilog (use --dev)"
elif ! command -v iverilog >/dev/null 2>&1; then
    result SKIP "3. iverilog + waveforms" "no iverilog here"
else
    run_suite 3_iverilog.log
    check_run "3a. iverilog tests shared" "$OUT/3_iverilog.log" "$LTMP/dme_klr/$ROMV/dash_logs"
    nofst=""; nr=0
    for t in $(grep '\[START\].*@host' "$OUT/3_iverilog.log" | awk '{print $2}'); do
        nr=$((nr + 1)); [ -s "$LTMP/dme_klr/$ROMV/dash_logs/fst/$t.fst" ] || nofst="$nofst $t"
    done
    [ "$nr" -gt 0 ] && [ -z "$nofst" ]
    check $? "3b. remote waveforms (fst/) here" "$((nr - $(echo $nofst | wc -w))) of $nr remote tests' fst/<test>.fst${nofst:+; missing:$nofst}"
fi

# ── 4. The host drops out mid-run ────────────────────────────────────────
step "4. The host's bridge stops mid-run: its tests go back in the queue"
if [ -z "$IP" ]; then
    result SKIP "4. host drops out" "--host: not stopping someone's bridge"
else
    run_suite 4_drop.log --verilator &
    _pid=$!
    for _i in $(seq 1 120); do grep -q '\[START\].*@host' "$OUT/4_drop.log" 2>/dev/null && break; sleep 1; done
    sleep 10
    info "stopping the host's bridge"
    vm_bridge stop
    wait "$_pid"
    nq=$(grep -c '\[REQUEUE\]' "$OUT/4_drop.log")
    n_tests=$(echo $TESTS | wc -w | tr -d ' ')
    n_done=$(grep -cE $'^(PASS|WARN|FAIL)\t' "$LTMP/dme_klr/$ROMV/v_dash_logs/validation.log" 2>/dev/null)
    [ "$nq" -gt 0 ] && [ "${n_done:-0}" = "$n_tests" ]
    check $? "4. host drops out" "$nq requeued, ${n_done:-0}/$n_tests validated"
    grep -E '\[START\]|\[REQUEUE\]|Complete' "$OUT/4_drop.log" | sed 's/^/      /'
    [ "$KEEP" = 1 ] && vm_bridge start >/dev/null
fi

{
    echo
    echo "${bold}Summary${nc}  (host $HOST_URL$([ -n "$IP" ] && echo ", VM $VM, $([ "$DEV" = 1 ] && echo developer install || echo lite package)"))"
    for r in "${RESULTS[@]}"; do echo "  $r"; done
    echo
    if [ "$FAILED" = 0 ]; then echo "${green}All checks passed.${nc}"
    else echo "${red}Some checks failed.${nc}"; fi
    echo "Logs: $OUT"
} | tee "$OUT/summary.txt"
sed -i.bak $'s/\033\\[[0-9;]*m//g' "$OUT/summary.txt" 2>/dev/null && rm -f "$OUT/summary.txt.bak"
exit "$FAILED"
