#!/usr/bin/env bash
# ============================================================
#  run_install_test.sh — run one of the OS installer tests by its id
#
#  The one place that turns an installer test's id into its command, for
#  run_all.sh (step 6, --install-tests) and the dashboard's INSTALLER
#  TESTS page (dme_klr/live/runall.mjs):
#    macos-install  developer install, clean macOS VM (test_macos_vm.sh; Tart)
#    macos-lite     lite package built here, clean macOS VM (Tart)
#    windows-lite   install_lite_windows.ps1, clean Windows VM (test_windows_vm.sh;
#                   Parallels: the VM $DMEKLR_WIN_VM, default
#                   "Windows 11 951 Install Test", snapshot $DMEKLR_WIN_SNAPSHOT,
#                   default "Clean")
#    windows-dev    install_windows.ps1, the same Windows VM
#    arch-install   developer install, clean Arch container
#                   (test_arch_install.sh; Docker or Podman)
#
#  Usage:  install/run_install_test.sh TEST [--out DIR] [--ref REF] [--check]
#    --out DIR   where the test puts its logs (the VM tests' --out)
#    --ref REF   the Windows tests' branch or tag (default: this checkout's
#                branch, or main)
#    --check     only say whether this machine can run it
#
#  Prints "==> Running TEST: <command>" before it starts. Exit: the test's
#  own (0 all passed, 1 some failed, 2 a usage or host problem), or 3 with
#  "skipped: <why>" when this machine can't run it (the tool isn't here).
# ============================================================
set -uo pipefail

# Run from the dashboard or a short-PATH shell on macOS: find Homebrew's and
# Parallels' tools (tart, prlctl, docker)
if [ "$(uname -s)" = Darwin ]; then
    for _d in /opt/homebrew/bin /usr/local/bin \
              "/Applications/Parallels Desktop.app/Contents/MacOS" \
              /Applications/Docker.app/Contents/Resources/bin; do
        case ":$PATH:" in *":$_d:"*) ;; *) [ -d "$_d" ] && PATH="$PATH:$_d" ;; esac
    done
    export PATH
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

T=""; OUT=""; REF=""; CHECK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --out)   OUT="${2:?--out needs a folder}"; shift ;;
        --ref)   REF="${2:?--ref needs a branch or tag}"; shift ;;
        --check) CHECK=1 ;;
        -h|--help) sed -n '3,/^# =====/{ /^# =====/d; s/^# \{0,2\}//; p; }' "$0"; exit 0 ;;
        -*) echo "run_install_test.sh: unknown option $1" >&2; exit 2 ;;
        *) [ -z "$T" ] || { echo "run_install_test.sh: one test at a time" >&2; exit 2; }; T="$1" ;;
    esac
    shift
done

WIN_VM="${DMEKLR_WIN_VM:-Windows 11 951 Install Test}"
WIN_SNAP="${DMEKLR_WIN_SNAPSHOT:-Clean}"
if [ -z "$REF" ]; then
    REF="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    { [ -z "$REF" ] || [ "$REF" = HEAD ]; } && REF=main
fi

why=""; CMD=()
case "$T" in
    macos-install|macos-lite)
        if [ "$(uname -s)" != Darwin ] || ! command -v tart >/dev/null 2>&1; then
            why="needs macOS with Tart (brew tap openai/tools && brew install openai/tools/tart)"
        fi
        CMD=(bash "$HERE/test_macos_vm.sh" --name "dmeklr-runall-${T#macos-}" --replace)
        [ "$T" = macos-lite ] && CMD+=(--lite build) ;;
    windows-lite|windows-dev)
        if ! command -v prlctl >/dev/null 2>&1; then
            why="needs Parallels Desktop Pro or Business (prlctl)"
        elif ! prlctl list -a -o name 2>/dev/null | tail -n +2 | sed 's/ *$//' | grep -qxF "$WIN_VM"; then
            why="no Parallels VM called '$WIN_VM' (set DMEKLR_WIN_VM; see install/test_windows_vm.sh --help)"
        elif printf '%s' "$(prlctl snapshot-list "$WIN_VM" 2>&1)" | grep -Eqi 'only in Parallels Desktop.*(Pro|Business)'; then
            # Standard edition: its prlctl lists VMs but can't snapshot, clone or exec
            why="needs Parallels Desktop Pro or Business (this is the Standard edition)"
        fi
        CMD=(bash "$HERE/test_windows_vm.sh" --vm "$WIN_VM" --snapshot "$WIN_SNAP"
             --name "dmeklr-runall-$T" --replace --ref "$REF")
        [ "$T" = windows-dev ] && CMD+=(--dev) ;;
    arch-install)
        if ! command -v docker >/dev/null 2>&1 && ! command -v podman >/dev/null 2>&1; then
            why="needs Docker or Podman"
        fi
        CMD=(bash "$HERE/test_arch_install.sh") ;;
    "") echo "run_install_test.sh: name a test (macos-install macos-lite windows-lite windows-dev arch-install)" >&2; exit 2 ;;
    *)  echo "run_install_test.sh: no installer test '$T' (macos-install macos-lite windows-lite windows-dev arch-install)" >&2; exit 2 ;;
esac
# the VM tests write their logs in --out; the Arch one in ../tmp/arch-install-test
if [ -n "$OUT" ] && [ "$T" != arch-install ]; then CMD+=(--out "$OUT"); fi

if [ -n "$why" ]; then echo "skipped: $why"; exit 3; fi
[ "$CHECK" = 1 ] && { echo "can run: ${CMD[*]}"; exit 0; }
[ -n "$OUT" ] && mkdir -p "$OUT"
echo "==> Running $T: ${CMD[*]}"
exec "${CMD[@]}"
