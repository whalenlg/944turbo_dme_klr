#!/usr/bin/env bash
# ============================================================
#  test_arch_install.sh — test install_arch.sh on a clean Arch Linux
#
#  Starts a fresh archlinux:latest container (Docker or Podman, x86_64),
#  copies this checkout's tracked files into it as a new user's clone,
#  and as that user (with sudo, as on a normal Arch system):
#    1. runs install/install_arch.sh -y  (plus --venv when asked)
#    2. in a new login shell: source setup, install/check_toolchain.sh
#    3. iverilog smoke test:   klr/run_klr_regression
#    4. Verilator smoke test:  dme_klr/v_run_dashboard_tests.sh warm_idle_5s
#    5. live simulator build:  dme_klr/live/build_live.sh
#    6. GTKWave: reads the KLR regression's .fst (fst2vcd) and opens it
#       in gtkwave on a virtual display (Xvfb)
#  then prints a PASS/FAIL line per step. Exits 0 only when all pass.
#
#  Usage:  install/test_arch_install.sh [options]
#    --venv             test install_arch.sh --venv (Python packages from pip)
#    --quick            stop after check_toolchain (skip steps 3-6)
#    --no-gtkwave       test install_arch.sh --no-gtkwave (skips step 6)
#    --engine NAME      docker or podman (default: whichever is found)
#    --image NAME       base image (default: archlinux:latest)
#    --keep             leave the container for a look afterwards
#    --in-container     run the steps here, in an Arch system that is
#                       already running (as root); used by the container
#                       run above and by .github/workflows/arch-install.yml
#    -h, --help         this text
#
#  The Arch mirrors and github.com must be reachable from the container.
#  Logs go to <checkout>/../tmp/arch-install-test/ (in-container: the
#  test user's ~/tmp/arch-install-test/).
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

VENV=0; GTKWAVE=1; QUICK=0; ENGINE=""; IMAGE="archlinux:latest"; KEEP=0; IN_CONTAINER=0
while [ $# -gt 0 ]; do
    case "$1" in
        --venv)         VENV=1 ;;
        --quick)        QUICK=1 ;;
        --no-gtkwave)   GTKWAVE=0 ;;
        --engine)       ENGINE="${2:?--engine needs a name}"; shift ;;
        --image)        IMAGE="${2:?--image needs a name}"; shift ;;
        --keep)         KEEP=1 ;;
        --in-container) IN_CONTAINER=1 ;;
        *) echo "test_arch_install.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ═══ Host side: start a clean container and run this script inside it ═══
if [ "$IN_CONTAINER" = 0 ]; then
    if [ -z "$ENGINE" ]; then
        if command -v docker >/dev/null 2>&1; then ENGINE=docker
        elif command -v podman >/dev/null 2>&1; then ENGINE=podman
        else die "needs docker or podman"; fi
    fi
    command -v git >/dev/null 2>&1 || die "needs git (to list the checkout's files)"

    LOGDIR="$REPO_DIR/../tmp/arch-install-test"
    mkdir -p "$LOGDIR"
    LOG="$LOGDIR/arch-install-$(date +%Y%m%d-%H%M%S)$([ "$VENV" = 1 ] && echo -venv).log"
    NAME="dmeklr-arch-test-$$"

    ARGS=(--in-container)
    [ "$VENV" = 1 ] && ARGS+=(--venv)
    [ "$QUICK" = 1 ] && ARGS+=(--quick)
    [ "$GTKWAVE" = 0 ] && ARGS+=(--no-gtkwave)

    RUNOPTS=(--name "$NAME" -i --platform linux/amd64)
    [ "$KEEP" = 1 ] || RUNOPTS+=(--rm)
    # Pass a proxy through when this machine uses one
    for _v in https_proxy HTTPS_PROXY http_proxy HTTP_PROXY no_proxy NO_PROXY; do
        [ -n "${!_v:-}" ] && RUNOPTS+=(-e "$_v")
    done

    step "Pulling $IMAGE ($ENGINE)"
    "$ENGINE" pull --platform linux/amd64 "$IMAGE" || die "can't pull $IMAGE"

    step "Running the test in a fresh container ($NAME); log: $LOG"
    # The checkout's files (tracked, and new ones not ignored) go in on stdin as a
    # tar, so the container starts from what a fresh clone would hold.
    (cd "$REPO_DIR" && git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf -) \
        | "$ENGINE" run "${RUNOPTS[@]}" "$IMAGE" bash -c '
            mkdir -p /src && tar -xf - -C /src && exec bash /src/install/test_arch_install.sh "$@"
          ' _ "${ARGS[@]}" 2>&1 | tee "$LOG"
    rc=${PIPESTATUS[1]}
    [ "$KEEP" = 1 ] && echo "Container kept: $ENGINE start -ai $NAME   (remove: $ENGINE rm $NAME)"
    echo "Log: $LOG"
    exit "$rc"
fi

# ═══ Container side (root, inside a clean Arch system) ═══════════════════
[ "$(id -u)" -eq 0 ] || die "--in-container runs as root"
command -v pacman >/dev/null 2>&1 || die "pacman not found; not an Arch system"

TUSER=tester
THOME="/home/$TUSER"
TREPO="$THOME/944turbo_dme_klr"
TLOG="$THOME/tmp/arch-install-test"

step "System: $(. /etc/os-release && echo "$PRETTY_NAME"), $(uname -m)"

# A normal Arch install has sudo and a user in wheel; the container doesn't.
step "Bootstrap: sudo and a test user"
# xorg-server-xvfb + xorg-xauth: a virtual display for the GTKWave launch test
pacman -Syu --needed --noconfirm sudo xorg-server-xvfb xorg-xauth >/dev/null \
    || die "pacman couldn't install sudo (no network?)"
id "$TUSER" >/dev/null 2>&1 || useradd -m -G wheel "$TUSER"
echo "$TUSER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-test-user
chmod 440 /etc/sudoers.d/90-test-user

rm -rf "$TREPO"
cp -a "$REPO_DIR" "$TREPO"
chown -R "$TUSER:$TUSER" "$TREPO"
sudo -u "$TUSER" mkdir -p "$TLOG"

declare -a RESULTS=()
FAILS=0
# check NAME COMMAND: run COMMAND as the test user in a new login shell
check() {
    local name="$1"; shift
    local log="$TLOG/$(echo "$name" | tr -cs 'A-Za-z0-9._-' '_').log"
    local t0=$SECONDS
    step "$name"
    echo "+ $*"
    # sudo -u (not -i): -i hands the command to a second shell, which
    # would expand the step's $VARS before setup has set them
    sudo -u "$TUSER" -H bash -lc "cd '$TREPO' && $*" > "$log" 2>&1
    local rc=$?
    tail -n 40 "$log"
    local dt=$((SECONDS - t0))
    if [ $rc -eq 0 ]; then
        RESULTS+=("PASS  ${name}  (${dt}s)")
    else
        RESULTS+=("FAIL  ${name}  (exit $rc, ${dt}s; log: $log)")
        FAILS=$((FAILS + 1))
    fi
    return $rc
}

INST=(install/install_arch.sh -y)
[ "$VENV" = 1 ] && INST+=(--venv)
[ "$GTKWAVE" = 0 ] && INST+=(--no-gtkwave)

if check "${INST[*]}" "${INST[*]}"; then
    check "source setup + check_toolchain" \
        'source ./setup && echo "DMEKLR_REPO=$DMEKLR_REPO DMEKLR_TMP=$DMEKLR_TMP" && which python3 && install/check_toolchain.sh'
    if [ "$QUICK" = 0 ]; then
        check "iverilog: KLR regression" \
            'source ./setup && klr/run_klr_regression && ls -l "$DMEKLR_TMP/klr/fst/"'
        check "verilator: warm_idle_5s" \
            'source ./setup && verilator --version && cd dme_klr && ./v_run_dashboard_tests.sh warm_idle_5s \
             && f="$DMEKLR_TMP/dme_klr/v_dash_logs/warm_idle_5s.dash.log" && ls -l "$f" \
             && n=$(grep -c "\[DS\]" "$f") && echo "$n [DS] snapshot lines" && [ "$n" -gt 10 ]'
        check "verilator: live build" \
            'source ./setup && cd dme_klr/live && ./build_live.sh && ls -l obj/dme_klr_live'
        if [ "$GTKWAVE" = 1 ]; then
            # Opens the KLR regression's FST in GTKWave on a virtual display:
            # still running after 15 s (timeout's 124) means it loaded and
            # stayed up. fst2vcd (part of GTKWave) checks the file reads.
            check "gtkwave: open the KLR waveform" \
                'source ./setup && f="$DMEKLR_TMP/klr/fst/i8048_regression_tb.fst" && ls -l "$f" \
                 && pacman -Q gtkwave && command -v gtkwave \
                 && fst2vcd "$f" | grep -m1 -q "enddefinitions" && echo "fst2vcd: reads OK" \
                 && { xvfb-run -a timeout 15 gtkwave "$f"; rc=$?; echo "gtkwave exit $rc (124 = still running at 15 s)"; [ $rc -eq 124 ]; }'
        fi
    fi
else
    echo "install_arch.sh failed; skipping the remaining steps"
fi

echo
echo "════════ Arch install test: $(date -u +%Y-%m-%dT%H:%MZ) ════════"
pacman -Q verilator iverilog gtkwave nodejs python gcc 2>/dev/null | sed 's/^/  /'
for r in "${RESULTS[@]}"; do echo "  $r"; done
if [ "$FAILS" -eq 0 ]; then echo "All steps passed."; exit 0; fi
echo "$FAILS step(s) failed."
exit 1
