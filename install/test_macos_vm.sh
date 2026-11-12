#!/usr/bin/env bash
# ============================================================
#  test_macos_vm.sh — test install_macos.sh on a clean macOS VM (Tart)
#
#  Runs on an Apple Silicon Mac with Tart:
#      brew tap openai/tools && brew install openai/tools/tart
#  (and brew trust openai/tools first if Homebrew's tap trust is on).
#  Clones a fresh macOS VM from a Cirrus Labs "vanilla" image (no
#  Homebrew; recent images do come with the Command Line Tools), copies
#  this checkout into it, and then:
#    1. removes the Command Line Tools if the image has them, runs
#       install_macos.sh, and checks it stops and asks for them (it can't
#       click the macOS dialog itself)
#    2. installs the Command Line Tools headlessly (softwareupdate), as a
#       user clicking "Install" in that dialog would
#    3. runs install_macos.sh -y again: Homebrew, the formulae, the venv,
#       then check_toolchain.sh
#    4. in a new zsh login shell (the macOS default), sources setup and runs
#       check_toolchain.sh, the KLR CPU regression (Icarus Verilog + the
#       venv's Python), the warm_idle_5s dashboard test (Verilator), the
#       live simulator build (build_live.sh, run to 200 ms), and opens the
#       KLR waveform in GTKWave
#  then prints PASS/FAIL for each step, copies the VM's logs back and
#  deletes the VM.
#
#  The first run downloads the image (about 25 GB) into ~/.tart; later
#  runs clone it in seconds. Each VM takes up to 50 GB while it runs.
#  A full run takes about 20-40 minutes, mostly Homebrew downloads and the
#  Verilator compile.
#
#  Usage:  install/test_macos_vm.sh [options]
#    --image IMAGE    VM image (default ghcr.io/cirruslabs/macos-sequoia-vanilla:latest)
#    --name NAME      VM name (default dmeklr-install-test)
#    --ref REF        git ref of this checkout to copy in (default HEAD)
#    --worktree       copy the working tree as it is, uncommitted changes
#                     included (tracked + untracked, not ignored files)
#    --cpu N          VM CPUs (default: the image's)
#    --memory MB      VM memory in MB (default: the image's)
#    --skip-clt-check skip step 1 (and keep the image's Command Line Tools)
#    --skip-tests     stop after the install (skip step 4's simulations;
#                     check_toolchain.sh still runs)
#    --keep           leave the VM running at the end, to look around
#                     (ssh admin@$(tart ip NAME), password admin)
#    --replace        delete an existing VM of the same name first
#    --out DIR        where to put the logs (default
#                     $DMEKLR_TMP/macos_vm_test/<date-time>)
#    -h, --help       this text
#
#  Exit: 0 when every step passed, 1 when any failed, 2 on a usage or
#  host problem (no Tart, not Apple Silicon, ...).
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

IMAGE="ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
VM="dmeklr-install-test"
REF="HEAD"; WORKTREE=0; CPU=""; MEM=""
CLT_CHECK=1; TESTS=1; KEEP=0; REPLACE=0; OUT=""
VM_USER="admin"; VM_PASS="admin"             # the Cirrus Labs images' login
VM_REPO='$HOME/944/944turbo_dme_klr'      # checkout path inside the VM

while [ $# -gt 0 ]; do
    case "$1" in
        --image)          IMAGE="$2"; shift ;;
        --name)           VM="$2"; shift ;;
        --ref)            REF="$2"; shift ;;
        --worktree)       WORKTREE=1 ;;
        --cpu)            CPU="$2"; shift ;;
        --memory)         MEM="$2"; shift ;;
        --skip-clt-check) CLT_CHECK=0 ;;
        --skip-tests)     TESTS=0 ;;
        --keep)           KEEP=1 ;;
        --replace)        REPLACE=1 ;;
        --out)            OUT="$2"; shift ;;
        *) echo "test_macos_vm.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done

bold=$'\033[1m'; red=$'\033[0;31m'; green=$'\033[0;32m'; yellow=$'\033[1;33m'; nc=$'\033[0m'
[ -t 1 ] || { bold=''; red=''; green=''; yellow=''; nc=''; }
step() { printf '\n%s==> %s%s\n' "$bold" "$*" "$nc"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '%serror:%s %s\n' "$red" "$nc" "$*" >&2; exit 2; }

# ── Host checks ───────────────────────────────────────────────────────────
[ "$(uname -s)" = Darwin ] || die "run this on a Mac (it drives Tart, which needs macOS on Apple Silicon)"
[ "$(uname -m)" = arm64 ]  || die "Tart's macOS VMs need an Apple Silicon Mac"
command -v tart >/dev/null 2>&1 || die "Tart isn't installed: brew tap openai/tools && brew install openai/tools/tart"
git -C "$REPO_DIR" rev-parse --verify --quiet "$REF^{commit}" >/dev/null || die "'$REF' isn't a commit in $REPO_DIR"

if [ -z "$OUT" ]; then
    # shellcheck source=../paths.sh
    source "$REPO_DIR/paths.sh"
    OUT="$DMEKLR_TMP/macos_vm_test/$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT" || die "can't make $OUT"
OUT="$(cd "$OUT" && pwd)"

if tart get "$VM" >/dev/null 2>&1; then
    [ "$REPLACE" = 1 ] || die "a VM called $VM already exists (tart delete $VM, or pass --replace)"
    tart stop "$VM" >/dev/null 2>&1 || true
    tart delete "$VM" || die "couldn't delete the old $VM"
fi

# ── ssh into the VM with the image's password, no key or sshpass needed ──
ASKPASS="$OUT/.askpass"
printf '#!/bin/sh\necho %s\n' "$VM_PASS" > "$ASKPASS"; chmod 700 "$ASKPASS"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
          -o PubkeyAuthentication=no -o "PreferredAuthentications=password,keyboard-interactive"
          -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o ConnectTimeout=10)
IP=""
vm_ssh() { SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}" \
           ssh "${SSH_OPTS[@]}" "$VM_USER@$IP" "$@"; }

# ── Cleanup: stop and delete the VM unless --keep ─────────────────────────
RUN_PID=""
cleanup() {
    rm -f "$ASKPASS"
    if [ "$KEEP" = 1 ] && [ -n "$IP" ]; then
        printf '\nThe VM is still running (--keep). ssh %s@%s (password %s);\nwhen done: tart stop %s && tart delete %s\n' \
            "$VM_USER" "$IP" "$VM_PASS" "$VM" "$VM"
        return
    fi
    if tart get "$VM" >/dev/null 2>&1; then
        echo; echo "Deleting the VM $VM"
        tart stop "$VM" >/dev/null 2>&1 || true
        [ -n "$RUN_PID" ] && wait "$RUN_PID" 2>/dev/null
        tart delete "$VM" || echo "couldn't delete $VM; run: tart delete $VM" >&2
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ── Results ───────────────────────────────────────────────────────────────
RESULTS=(); FAILED=0
result() {  # result PASS|FAIL|SKIP "name" "detail" seconds
    local s="$1" c="$green"
    [ "$s" = FAIL ] && { c="$red"; FAILED=1; }
    [ "$s" = SKIP ] && c="$yellow"
    RESULTS+=("$(printf '%s%-4s%s  %-34s %6ss  %s' "$c" "$s" "$nc" "$2" "$4" "$3")")
    printf '    %s%s%s  %s\n' "$c" "$s" "$nc" "$3"
}
T0=0; tic() { T0=$SECONDS; }; toc() { echo $((SECONDS - T0)); }

# run a script in the VM with bash (or zsh -l), logging to $OUT/<log>
vm_run() {  # vm_run <log> <shell...> <<'EOF' ... EOF
    local log="$OUT/$1"; shift
    vm_ssh "$@" 2>&1 | tee "$log"
    return "${PIPESTATUS[0]}"
}

echo "${bold}Clean-VM test of install_macos.sh${nc}"
info "image:  $IMAGE"
info "VM:     $VM"
if [ "$WORKTREE" = 1 ]; then info "source: $REPO_DIR (working tree)"
else info "source: $REPO_DIR @ $REF ($(git -C "$REPO_DIR" rev-parse --short "$REF"))"
     [ -z "$(git -C "$REPO_DIR" status --porcelain --untracked-files=no)" ] || \
         info "${yellow}note:${nc} uncommitted changes aren't copied (use --worktree to include them)"
fi
info "logs:   $OUT"

# ── VM up ─────────────────────────────────────────────────────────────────
step "Cloning $IMAGE (downloads it the first time)"
tic
tart clone "$IMAGE" "$VM" || die "tart clone failed"
[ -n "$CPU" ] && { tart set "$VM" --cpu "$CPU" || die "tart set --cpu failed"; }
[ -n "$MEM" ] && { tart set "$VM" --memory "$MEM" || die "tart set --memory failed"; }
info "done in $(toc)s"

step "Booting the VM"
tic
tart run --no-graphics "$VM" > "$OUT/tart_run.log" 2>&1 &
RUN_PID=$!
IP="$(tart ip "$VM" --wait 180 2>/dev/null)" || die "the VM didn't get an IP address (see $OUT/tart_run.log)"
info "IP $IP"
for _i in $(seq 1 60); do
    vm_ssh true </dev/null 2>/dev/null && break
    [ "$_i" = 60 ] && die "ssh to $IP didn't come up"
    sleep 5
done
SW="$(vm_ssh 'echo "$(sw_vers -productVersion) $(uname -m)"' </dev/null)"
info "macOS $SW, ssh up after $(toc)s"
vm_ssh 'xcode-select -p >/dev/null 2>&1 && echo "Command Line Tools: present" || echo "Command Line Tools: none";
        command -v brew >/dev/null 2>&1 || [ -x /opt/homebrew/bin/brew ] && echo "Homebrew: present" || echo "Homebrew: none"' \
    </dev/null | sed 's/^/    /'

# Homebrew's installer needs sudo without a terminal to type into.
# The Cirrus images allow that already; if this one doesn't, allow it.
if ! vm_ssh 'sudo -n true' </dev/null 2>/dev/null; then
    info "enabling passwordless sudo for $VM_USER in the VM (Homebrew's installer needs it over ssh)"
    vm_ssh "echo '$VM_PASS' | sudo -S sh -c \"echo '$VM_USER ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/zz-install-test\"" \
        </dev/null >/dev/null 2>&1 || die "couldn't set up sudo in the VM"
fi

# ── Copy the checkout in ──────────────────────────────────────────────────
step "Copying the checkout to ~/944/944turbo_dme_klr in the VM"
tic
if [ "$WORKTREE" = 1 ]; then
    ( cd "$REPO_DIR" && git ls-files -z --cached --others --exclude-standard \
        | while IFS= read -r -d '' f; do [ -e "$f" ] && printf '%s\0' "$f"; done \
        | COPYFILE_DISABLE=1 tar --null -T - -cf - )
else
    git -C "$REPO_DIR" archive --format=tar "$REF"
fi | vm_ssh "mkdir -p $VM_REPO && tar -xf - -C $VM_REPO && du -sh $VM_REPO | cut -f1"
if [ "${PIPESTATUS[1]}" = 0 ]; then
    info "copied in $(toc)s"
else
    die "copying the checkout into the VM failed"
fi

# ── 1. install_macos.sh with no Command Line Tools ───────────────────────
step "1. install_macos.sh with no Command Line Tools: it should stop and ask for them"
if [ "$CLT_CHECK" = 0 ]; then
    result SKIP "1. stops without CLT" "--skip-clt-check" 0
else
    tic
    # Recent vanilla images ship the Command Line Tools. Take them out
    # (files, selected path and package receipts, so softwareupdate offers
    # them again in step 2) to get the clean machine a new user has.
    if vm_ssh 'xcode-select -p' </dev/null >/dev/null 2>&1; then
        info "the image has the Command Line Tools; removing them"
        vm_run 1_remove_clt.log bash -s <<'EOF'
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --reset 2>/dev/null || true
for p in $(pkgutil --pkgs | grep -i CLTools); do sudo pkgutil --forget "$p" >/dev/null; done
if xcode-select -p >/dev/null 2>&1; then echo "still installed"; exit 1; fi
echo "Command Line Tools removed"
EOF
    fi
    vm_run 1_install_no_clt.log bash -s <<EOF
cd $VM_REPO && install/install_macos.sh -y
EOF
    rc=$?
    if [ "$rc" != 0 ] && grep -q "finish the Command Line Tools install" "$OUT/1_install_no_clt.log"; then
        result PASS "1. stops without CLT" "exited $rc, asking for the Command Line Tools install" "$(toc)"
    else
        result FAIL "1. stops without CLT" "exit $rc without the Command Line Tools message (1_install_no_clt.log)" "$(toc)"
    fi
fi

# ── 2. Command Line Tools, headless ──────────────────────────────────────
step "2. Installing the Command Line Tools (softwareupdate, as the dialog would)"
tic
vm_run 2_clt.log bash -s <<'EOF'
set -e
if xcode-select -p >/dev/null 2>&1; then echo "already installed"; exit 0; fi
flag=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
touch "$flag"
label="$(softwareupdate -l 2>/dev/null | grep -E '^[[:space:]]*\* .*Command Line Tools' \
         | sed -E 's/^[[:space:]]*\*[[:space:]]*(Label:[[:space:]]*)?//' | sort -V | tail -1)"
[ -n "$label" ] || { echo "softwareupdate lists no Command Line Tools"; rm -f "$flag"; exit 1; }
echo "installing: $label"
sudo softwareupdate -i "$label" --verbose
rm -f "$flag"
xcode-select -p
EOF
if [ $? = 0 ]; then result PASS "2. Command Line Tools" "$(tail -1 "$OUT/2_clt.log")" "$(toc)"
else result FAIL "2. Command Line Tools" "see 2_clt.log" "$(toc)"; fi

# ── 3. install_macos.sh, full run ────────────────────────────────────────
step "3. install_macos.sh -y"
tic
vm_run 3_install.log bash -s <<EOF
export NONINTERACTIVE=1   # what Homebrew's installer assumes without a terminal anyway
cd $VM_REPO && install/install_macos.sh -y
EOF
rc=$?
if [ "$rc" = 0 ]; then result PASS "3. install_macos.sh -y" "exit 0" "$(toc)"
else result FAIL "3. install_macos.sh -y" "exit $rc (3_install.log)" "$(toc)"; fi

# ── 4. A new terminal: zsh login shell, source setup, tests ──────────────
# A user's new terminal is a zsh login shell; Homebrew's "Next steps" put
# its shellenv line in ~/.zprofile, so do the same here.
vm_ssh 'grep -q "brew shellenv" ~/.zprofile 2>/dev/null ||
        echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile' </dev/null

step "4a. New zsh terminal: source setup; install/check_toolchain.sh"
tic
vm_run 4a_check_toolchain.log zsh -l -s <<EOF
source $VM_REPO/setup || exit 3
echo "DMEKLR_REPO=\$DMEKLR_REPO"; echo "DMEKLR_TMP=\$DMEKLR_TMP"; echo "VIRTUAL_ENV=\$VIRTUAL_ENV"
echo "python3 -> \$(command -v python3)"
\$DMEKLR_REPO/install/check_toolchain.sh
EOF
rc=$?
if [ "$rc" = 0 ] && grep -q "Everything required is installed" "$OUT/4a_check_toolchain.log" \
   && ! grep -q "not active in this shell" "$OUT/4a_check_toolchain.log"; then
    result PASS "4a. source setup + check" "all required tools found, 944venv active" "$(toc)"
else
    result FAIL "4a. source setup + check" "exit $rc (4a_check_toolchain.log)" "$(toc)"
fi

if [ "$TESTS" = 0 ]; then
    result SKIP "4b. KLR regression (iverilog)" "--skip-tests" 0
    result SKIP "4c. warm_idle_5s (Verilator)" "--skip-tests" 0
    result SKIP "4d. live build + run (Verilator)" "--skip-tests" 0
    result SKIP "4e. GTKWave (optional)" "--skip-tests" 0
else
    step "4b. KLR CPU regression (Icarus Verilog + Python venv)"
    tic
    vm_run 4b_klr_regression.log zsh -l -s <<EOF
source $VM_REPO/setup && cd \$DMEKLR_REPO/klr && ./run_klr_regression
EOF
    rc=$?
    _pass=$(grep -c 'PASS \[' "$OUT/4b_klr_regression.log")
    _fail=$(grep -c 'FAIL \[' "$OUT/4b_klr_regression.log")
    if [ "$rc" = 0 ] && [ "$_pass" -gt 0 ] && [ "$_fail" = 0 ] \
       && ! grep -q 'Traceback' "$OUT/4b_klr_regression.log"; then
        result PASS "4b. KLR regression (iverilog)" "$_pass checks passed" "$(toc)"
    else
        result FAIL "4b. KLR regression (iverilog)" "exit $rc, $_pass passed, $_fail failed (4b_klr_regression.log)" "$(toc)"
    fi

    step "4c. warm_idle_5s dashboard test (Verilator compile + 5 s simulated)"
    tic
    vm_run 4c_warm_idle_5s.log zsh -l -s <<EOF
source $VM_REPO/setup && cd \$DMEKLR_REPO/dme_klr && ./v_run_dashboard_tests.sh warm_idle_5s
_rc=\$?
_d=\$DMEKLR_TMP/dme_klr/v_dash_logs/warm_idle_5s.dash.log
echo "dash log: \$(wc -l < \$_d 2>/dev/null || echo missing) lines, \$(grep -c '\[DS\]' \$_d 2>/dev/null || echo 0) snapshots"
exit \$_rc
EOF
    rc=$?
    _snaps=$(sed -n 's/.*lines, \([0-9]*\) snapshots.*/\1/p' "$OUT/4c_warm_idle_5s.log" | tail -1)
    if [ "$rc" = 0 ] && [ "${_snaps:-0}" -gt 0 ] \
       && ! grep -qE 'COMPILE FAILED|SIM FAILED' "$OUT/4c_warm_idle_5s.log"; then
        result PASS "4c. warm_idle_5s (Verilator)" "$_snaps dashboard snapshots" "$(toc)"
    else
        result FAIL "4c. warm_idle_5s (Verilator)" "exit $rc, ${_snaps:-0} snapshots (4c_warm_idle_5s.log)" "$(toc)"
    fi
    # bring the dashboard log back too, so it can be opened on the host
    vm_ssh "cat $VM_REPO/../tmp/dme_klr/v_dash_logs/warm_idle_5s.dash.log" </dev/null \
        > "$OUT/warm_idle_5s.dash.log" 2>/dev/null || rm -f "$OUT/warm_idle_5s.dash.log"

    step "4d. Live simulator: build_live.sh (Verilator) and run to 200 ms"
    tic
    vm_run 4d_live_build.log zsh -l -s <<'EOF'
source "$HOME/944/944turbo_dme_klr/setup" && cd "$DMEKLR_REPO/dme_klr/live" || exit 3
./build_live.sh || { echo "build_live.sh failed"; exit 1; }
ls -l obj/dme_klr_live || exit 1
# Drive it as the bridge does, one command at a time on stdin, and check
# it pauses at 200 ms. (Python, not bash: macOS's bash 3.2 has no coproc.)
python3 - obj/dme_klr_live <<'PY'
import subprocess, sys, os, queue, threading, time
p = subprocess.Popen([sys.argv[1], '+snapdir=' + os.environ['DMEKLR_TMP'] + '/macos-test-snaps'],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
# Read lines on a thread (select() on a buffered pipe misses lines that
# are already in Python's buffer)
lines = queue.Queue()
def pump():
    for l in p.stdout:
        lines.put(l)
    lines.put(None)
threading.Thread(target=pump, daemon=True).start()
p.stdin.write('until 200\n'); p.stdin.flush()
ok, end = False, time.time() + 120
while time.time() < end:
    try:
        line = lines.get(timeout=max(0.1, end - time.time()))
    except queue.Empty:
        break
    if line is None:
        break
    if line.startswith('SIM:'):
        print(line.rstrip())
    if '[STATE] paused' in line and 'reason=until' in line:
        ok = True
        break
try:
    p.stdin.write('quit\n'); p.stdin.flush()
except Exception:
    pass
try:
    p.wait(10)
except subprocess.TimeoutExpired:
    p.kill()
print('live sim ran to 200 ms' if ok else "live sim didn't reach 200 ms")
sys.exit(0 if ok else 1)
PY
EOF
    rc=$?
    if [ "$rc" = 0 ] && grep -q 'live sim ran to 200 ms' "$OUT/4d_live_build.log"; then
        result PASS "4d. live build + run (Verilator)" "built and paused at 200 ms" "$(toc)"
    else
        result FAIL "4d. live build + run (Verilator)" "exit $rc (4d_live_build.log)" "$(toc)"
    fi

    step "4e. GTKWave: read and open the KLR regression's waveform"
    tic
    vm_run 4e_gtkwave.log zsh -l -s <<'EOF'
source "$HOME/944/944turbo_dme_klr/setup" || exit 3
f="$DMEKLR_TMP/klr/fst/i8048_regression_tb.fst"
ls -l "$f" || exit 1
if command -v gtkwave >/dev/null 2>&1; then echo "gtkwave: $(command -v gtkwave)"
elif [ -d /Applications/gtkwave.app ]; then echo "gtkwave: /Applications/gtkwave.app"
else echo "gtkwave: not installed"; exit 4; fi
if command -v fst2vcd >/dev/null 2>&1; then
    fst2vcd "$f" | grep -m1 -q enddefinitions && echo "fst2vcd: reads OK" || { echo "fst2vcd: can't read $f"; exit 1; }
fi
# Open it in the VM's logged-in desktop session; still running after 15 s
# means it loaded the file and stayed up.
if command -v gtkwave >/dev/null 2>&1; then gtkwave "$f" >/tmp/gtkwave.out 2>&1 &
else open -a /Applications/gtkwave.app --args "$f"; fi
sleep 15
if pgrep -if gtkwave >/dev/null; then
    echo "gtkwave still running after 15 s"; pkill -if gtkwave; exit 0
fi
echo "gtkwave exited within 15 s:"; cat /tmp/gtkwave.out 2>/dev/null; exit 1
EOF
    rc=$?
    if [ "$rc" = 0 ]; then
        result PASS "4e. GTKWave (optional)" "$(grep -q 'reads OK' "$OUT/4e_gtkwave.log" && echo 'fst2vcd reads the FST, ')opened and stayed up" "$(toc)"
    elif [ "$rc" = 4 ]; then
        result SKIP "4e. GTKWave (optional)" "GTKWave isn't installed (install_macos.sh treats it as optional)" "$(toc)"
    else
        result FAIL "4e. GTKWave (optional)" "exit $rc (4e_gtkwave.log)" "$(toc)"
    fi
fi

# What got installed, for the record
vm_ssh 'eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null; sw_vers; echo;
        brew list --versions 2>/dev/null; echo; '"$VM_REPO"'/944venv/bin/pip list 2>/dev/null' \
    </dev/null > "$OUT/versions.txt" 2>&1

# ── Summary ───────────────────────────────────────────────────────────────
{
    echo
    echo "${bold}Summary${nc}  (macOS $SW, $IMAGE)"
    for r in "${RESULTS[@]}"; do echo "  $r"; done
    echo
    if [ "$FAILED" = 0 ]; then echo "${green}All steps passed.${nc}"
    else echo "${red}Some steps failed.${nc} Logs: $OUT"; fi
    echo "Logs: $OUT"
} | tee "$OUT/summary.txt"
# keep the colour codes out of the saved summary
sed -i '' $'s/\033\\[[0-9;]*m//g' "$OUT/summary.txt" 2>/dev/null || true

exit "$FAILED"
