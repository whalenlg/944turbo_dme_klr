#!/usr/bin/env bash
# ============================================================
#  test_arch_install.sh — test install_arch.sh on a clean Arch Linux
#
#  Starts a fresh archlinux:latest container (Docker or Podman, x86_64),
#  copies this checkout's tracked files into it as a new user's clone,
#  and as that user (with sudo, as on a normal Arch system):
#    1. runs install/install_arch.sh -y  (plus --venv when asked), which
#       ends with its smoke tests (install/smoke_test.sh): the KLR
#       regression on iverilog and warm_idle_5s on Verilator
#    2. in a new login shell: source setup, install/check_toolchain.sh
#    3. iverilog smoke test:   checks the KLR regression's output from 1
#    4. Verilator smoke test:  checks warm_idle_5s's dashboard log from 1
#    5. live simulator build:  dme_klr/live/build_live.sh
#    6. GTKWave: reads the KLR regression's .fst (fst2vcd) and opens it
#       in gtkwave on a virtual display (Xvfb)
#  then prints a PASS/FAIL line per step. Exits 0 only when all pass.
#
#  With --lite it tests the lite package instead: no checkout goes into
#  the container, only the package archive and lite/test_lite.sh. It
#  installs Node.js and the Python packages from pacman, as a user would,
#  and runs test_lite.sh --clean as the test user (bridge, listings, live
#  sim, run_tests.py, TEST LOAD, and that the container has no Verilog
#  source, Verilator or iverilog).
#
#  Usage:  install/test_arch_install.sh [options]
#    --venv             test install_arch.sh --venv (Python packages from pip)
#    --quick            install with --skip-tests and stop after
#                       check_toolchain (skip steps 3-6)
#    --no-gtkwave       test install_arch.sh --no-gtkwave (skips step 6)
#    --engine NAME      docker or podman (default: whichever is found)
#    --image NAME       base image (default: archlinux:latest)
#    --lite ARCHIVE     test this lite package (dmeklr-lite-*-linux-x86_64.tar.gz,
#                       e.g. the lite-Linux artifact of the Lite package
#                       workflow, or a release) instead of the developer
#                       install
#    --keep             leave the container for a look afterwards (with
#                       --lite: the package is unpacked in
#                       /home/tester/lite-test/dmeklr-lite-*/)
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

VENV=0; GTKWAVE=1; QUICK=0; ENGINE=""; IMAGE="archlinux:latest"; KEEP=0; IN_CONTAINER=0; LITE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --venv)         VENV=1 ;;
        --quick)        QUICK=1 ;;
        --no-gtkwave)   GTKWAVE=0 ;;
        --engine)       ENGINE="${2:?--engine needs a name}"; shift ;;
        --image)        IMAGE="${2:?--image needs a name}"; shift ;;
        --keep)         KEEP=1 ;;
        --lite)         LITE="${2:?--lite needs a package archive}"; shift ;;
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
    if [ -n "$LITE" ]; then
        [ -f "$LITE" ] || die "no lite package at $LITE"
        case "$LITE" in *linux-x86_64.tar.gz) ;; *) die "--lite wants the Linux x86_64 .tar.gz package" ;; esac
    fi

    LOGDIR="$REPO_DIR/../tmp/arch-install-test"
    mkdir -p "$LOGDIR"
    LOG="$LOGDIR/arch-install-$(date +%Y%m%d-%H%M%S)$([ "$VENV" = 1 ] && echo -venv)$([ -n "$LITE" ] && echo -lite).log"
    NAME="dmeklr-arch-test-$$"

    ARGS=(--in-container)
    [ "$VENV" = 1 ] && ARGS+=(--venv)
    [ "$QUICK" = 1 ] && ARGS+=(--quick)
    [ "$GTKWAVE" = 0 ] && ARGS+=(--no-gtkwave)
    [ -n "$LITE" ] && ARGS+=(--lite "/src/pkg/$(basename "$LITE")")

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
    # tar, so the container starts from what a fresh clone would hold. With
    # --lite only this script, test_lite.sh and the package go in.
    send_files() {
        if [ -n "$LITE" ]; then
            local st; st="$(mktemp -d)"
            mkdir -p "$st/install" "$st/lite" "$st/pkg"
            cp "$INSTALL_DIR/test_arch_install.sh" "$st/install/"
            cp "$REPO_DIR/lite/test_lite.sh" "$st/lite/"
            cp "$LITE" "$st/pkg/"
            tar -C "$st" -cf - . && rm -rf "$st"
        else
            (cd "$REPO_DIR" && git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf -)
        fi
    }
    send_files \
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

# ── --lite: the package only, with Node.js and Python from pacman ────────
if [ -n "$LITE" ]; then
    [ -f "$LITE" ] || die "no lite package at $LITE"
    step "Bootstrap: a test user, Node.js and the Python packages (pacman)"
    pacman -Syu --needed --noconfirm sudo curl nodejs python python-pandas python-openpyxl \
        python-matplotlib python-numpy >/dev/null || die "pacman failed (no network?)"
    id "$TUSER" >/dev/null 2>&1 || useradd -m "$TUSER"
    LDIR="$THOME/lite-test"
    rm -rf "$LDIR"; mkdir -p "$LDIR" "$TLOG"
    cp "$LITE" "$LDIR/"
    cp "$REPO_DIR/lite/test_lite.sh" "$LDIR/" || die "no lite/test_lite.sh"
    chmod +x "$LDIR/test_lite.sh"
    chown -R "$TUSER:$TUSER" "$THOME"
    step "test_lite.sh --clean as $TUSER ($(node --version), $(python --version 2>&1))"
    sudo -u "$TUSER" -H bash -lc "cd '$LDIR' && ./test_lite.sh '$LDIR/$(basename "$LITE")' --clean" 2>&1 \
        | tee "$TLOG/test_lite.log"
    rc=${PIPESTATUS[0]}
    # Unpacked where a user would put it, to look around in (--keep)
    sudo -u "$TUSER" -H bash -c "cd '$LDIR' && tar -xzf ./*.tar.gz && ls -d '$LDIR'/dmeklr-lite-*/" \
        | sed 's/^/  unpacked: /'
    echo
    echo "════════ Arch lite package test: $(date -u +%Y-%m-%dT%H:%MZ) ════════"
    echo "  package: $(basename "$LITE")"
    pacman -Q nodejs python python-pandas 2>/dev/null | sed 's/^/  /'
    if [ "$rc" = 0 ]; then echo "  PASS  lite package checks ($(grep -c '  PASS  ' "$TLOG/test_lite.log") passed)"; echo "All steps passed."; exit 0; fi
    echo "  FAIL  lite package checks ($(grep -c '  FAIL  ' "$TLOG/test_lite.log") failed; log: $TLOG/test_lite.log)"
    exit 1
fi

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

# Runs the live simulator to 200 ms (as the dashboard would, one command
# at a time on stdin) and checks it pauses there
cat > "$THOME/live_smoke.sh" <<'SMOKE'
exe="$1"
coproc SIM { "$exe" +snapdir="$DMEKLR_TMP/arch-test-snaps" 2>&1; }
echo "until 200" >&"${SIM[1]}"
ok=0
while IFS= read -t 120 -r line <&"${SIM[0]}"; do
    case "$line" in SIM:*) echo "$line" ;; esac
    case "$line" in *"[STATE] paused"*"reason=until"*) ok=1; break ;; esac
done
echo quit >&"${SIM[1]}" 2>/dev/null
wait "$SIM_PID" 2>/dev/null
[ "$ok" = 1 ] && echo "live sim ran to 200 ms" || { echo "live sim didn't reach 200 ms"; exit 1; }
SMOKE
chown "$TUSER:$TUSER" "$THOME/live_smoke.sh"

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
[ "$QUICK" = 1 ] && INST+=(--skip-tests)

if check "${INST[*]}" "${INST[*]}"; then
    check "source setup + check_toolchain" \
        'source ./setup && echo "DMEKLR_REPO=$DMEKLR_REPO DMEKLR_TMP=$DMEKLR_TMP" && which python3 && install/check_toolchain.sh'
    if [ "$QUICK" = 0 ]; then
        # install_arch.sh ran both smoke tests (install/smoke_test.sh) as
        # its last step; check what they left rather than run them again
        check "iverilog: KLR regression" \
            'source ./setup && l="$DMEKLR_TMP/install_smoke/klr.log" && ls -l "$l" "$DMEKLR_TMP/klr/fst/" \
             && n=$(grep -c "PASS \[" "$l") && echo "$n checks passed" && [ "$n" -gt 0 ] \
             && ! grep -q "FAIL \[" "$l"'
        check "verilator: warm_idle_5s" \
            'source ./setup && verilator --version && ls -l "$DMEKLR_TMP/install_smoke/warm_idle_5s.log" \
             && f="$DMEKLR_TMP/dme_klr/v_dash_logs/warm_idle_5s.dash.log" && ls -l "$f" \
             && n=$(grep -c "\[DS\]" "$f") && echo "$n [DS] snapshot lines" && [ "$n" -gt 10 ]'
        check "verilator: live build" \
            'source ./setup && cd dme_klr/live && ./build_live.sh && ls -l obj/dme_klr_live \
             && bash ~/live_smoke.sh obj/dme_klr_live'
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
