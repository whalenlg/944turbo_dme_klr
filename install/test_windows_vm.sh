#!/usr/bin/env bash
# ============================================================
#  test_windows_vm.sh — test the Windows installers on a clean Windows VM
#  (Parallels Desktop on a Mac)
#
#  Makes a linked clone of a Windows VM from one of its snapshots (a clean
#  Windows taken before anything of this project was installed), starts
#  it, runs an installer in it as a new user would, checks the result,
#  copies the logs back and deletes the clone. The VM you clone from and
#  its snapshot are left as they are.
#
#  Lite (default): the one-line installer from the manual
#  (install/install_lite_windows.ps1, from GitHub at --ref), which
#  installs Node.js and Python with winget and the lite package from the
#  release; then checks that
#    L1. the installer finished, with the package, its venv and the
#        desktop shortcut in place
#    L2. run_lite.cmd's bridge serves the dashboard at
#        http://127.0.0.1:8951/?live
#    L3. the bridge offers RUN REGRESSIONS (/runall answers mode "lite")
#    L4. one regression test passes (run_tests.py <--test>)
#
#  --dev: the developer install, install/install_windows.ps1 -Clone
#  C:\dmeklr\944turbo_dme_klr -Ref <--ref> -Yes (MSYS2, the toolchain, the
#  smoke tests); then
#    D1. the installer finished
#    D2. the checkout is clean (the tests changed no tracked file)
#    D3. install/test_windows_install.sh (setup, check_toolchain, the live
#        build, the bridge) in the UCRT64 environment
#
#  Needs (on the Mac):
#    - Parallels Desktop Pro or Business edition (for the prlctl command)
#    - a Windows VM with Parallels Tools installed, set to sign its user in
#      automatically (Settings > Accounts, or netplwiz), and a snapshot of
#      it taken in that clean state. Commands run in the VM as that
#      signed-in user (prlctl exec --current-user), so winget works as it
#      does for a person.
#
#  A lite run takes about 10 minutes, a --dev run 30 to 60 (MSYS2's
#  packages and the Verilator build). The linked clone shares the
#  snapshot's disk, so it needs only the space the install writes.
#
#  Usage:  install/test_windows_vm.sh --vm NAME [options]
#    --vm NAME          the Windows VM to clone (prlctl list -a shows them)
#    --snapshot S       its snapshot to clone from, by name or ID (default:
#                       its current snapshot; prlctl snapshot-list NAME)
#    --dev              test the developer install instead of the lite one
#    --ref REF          branch or tag of this repo the installer comes from
#                       (lite: the script; --dev: the checkout) (default main)
#    --version TAG      lite: the release to install (default: the latest)
#    --test NAME        lite: the regression test for L4 (default warm_idle_5s)
#    --name NAME        the clone's name (default dmeklr-win-test)
#    --keep             leave the clone running at the end, to look around
#                       (delete it later: prlctl stop NAME --kill; prlctl delete NAME)
#    --replace          delete an existing VM of the clone's name first
#    --out DIR          where to put the logs (default
#                       $DMEKLR_TMP/windows_vm_test/<date-time>)
#    -h, --help         this text
#
#  Exit: 0 when every check passed, 1 when any failed, 2 on a usage or
#  host problem (no prlctl, no such VM or snapshot, the VM never became
#  reachable).
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
GH_REPO="whalenlg/944turbo_dme_klr"

SRC=""; SNAP=""; DEV=0; REF="main"; VERSION="latest"; TEST="warm_idle_5s"
VM="dmeklr-win-test"; KEEP=0; REPLACE=0; OUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --vm)       SRC="${2:?--vm needs a VM name}"; shift ;;
        --snapshot) SNAP="${2:?--snapshot needs a name or ID}"; shift ;;
        --dev)      DEV=1 ;;
        --ref)      REF="${2:?--ref needs a branch or tag}"; shift ;;
        --version)  VERSION="${2:?--version needs a tag}"; shift ;;
        --test)     TEST="${2:?--test needs a test name}"; shift ;;
        --name)     VM="${2:?--name needs a name}"; shift ;;
        --keep)     KEEP=1 ;;
        --replace)  REPLACE=1 ;;
        --out)      OUT="${2:?--out needs a folder}"; shift ;;
        *) echo "test_windows_vm.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done

bold=$'\033[1m'; red=$'\033[0;31m'; green=$'\033[0;32m'; yellow=$'\033[1;33m'; nc=$'\033[0m'
[ -t 1 ] || { bold=''; red=''; green=''; yellow=''; nc=''; }
step() { printf '\n%s==> %s%s\n' "$bold" "$*" "$nc"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '%serror:%s %s\n' "$red" "$nc" "$*" >&2; exit 2; }

# ── Host checks ───────────────────────────────────────────────────────────
[ -n "$SRC" ] || die "say which VM to clone: --vm NAME (prlctl list -a lists them)"
command -v prlctl >/dev/null 2>&1 \
    || die "prlctl not found: it comes with Parallels Desktop Pro or Business edition"
prlctl list -a -o name 2>/dev/null | tail -n +2 | sed 's/ *$//' | grep -qxF "$SRC" \
    || die "no VM called '$SRC' (prlctl list -a)"

# The snapshot's ID: given as an ID, found by name, or the current one
# (snapshot-list marks it with *)
snap_ids() { prlctl snapshot-list "$SRC" 2>/dev/null | tail -n +2 | grep -o '{[0-9a-fA-F-]*}'; }
if [ -z "$SNAP" ]; then
    SNAP_ID="$(prlctl snapshot-list "$SRC" 2>/dev/null | grep '\*' | grep -o '{[0-9a-fA-F-]*}' | tail -1)"
    [ -n "$SNAP_ID" ] || die "$SRC has no current snapshot; take one of the clean VM, or pass --snapshot"
elif [[ "$SNAP" =~ ^\{?[0-9a-fA-F-]{36}\}?$ ]]; then
    SNAP_ID="{${SNAP//[\{\}]/}}"
else
    SNAP_ID=""
    for _id in $(snap_ids); do
        _n="$(prlctl snapshot-list "$SRC" -i "$_id" 2>/dev/null | sed -n 's/^ *Name: *//p' | head -1)"
        # (names match ignoring case: "clean" finds "Clean")
        [ "$(printf %s "$_n" | tr A-Z a-z)" = "$(printf %s "$SNAP" | tr A-Z a-z)" ] && { SNAP_ID="$_id"; break; }
    done
    [ -n "$SNAP_ID" ] || die "$SRC has no snapshot named '$SNAP' (prlctl snapshot-list $SRC)"
fi
snap_ids | grep -qxF "$SNAP_ID" || die "$SRC has no snapshot $SNAP_ID (prlctl snapshot-list $SRC)"

if [ -z "$OUT" ]; then
    # shellcheck source=../paths.sh
    source "$REPO_DIR/paths.sh"
    OUT="$DMEKLR_TMP/windows_vm_test/$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT" || die "can't make $OUT"
OUT="$(cd "$OUT" && pwd)"

if prlctl list -a -o name 2>/dev/null | tail -n +2 | sed 's/ *$//' | grep -qxF "$VM"; then
    [ "$REPLACE" = 1 ] || die "a VM called $VM already exists (prlctl delete $VM, or pass --replace)"
    prlctl stop "$VM" --kill >/dev/null 2>&1 || true
    prlctl delete "$VM" >/dev/null || die "couldn't delete the old $VM"
fi

# ── Cleanup: stop and delete the clone unless --keep ──────────────────────
CLONED=0
cleanup() {
    [ "$CLONED" = 1 ] || return
    if [ "$KEEP" = 1 ]; then
        printf '\nThe clone %s is still running (--keep).\nWhen done: prlctl stop %s --kill; prlctl delete %s\n' "$VM" "$VM" "$VM"
        return
    fi
    echo; echo "Deleting the clone $VM"
    prlctl stop "$VM" --kill >/dev/null 2>&1 || true
    prlctl delete "$VM" >/dev/null || echo "couldn't delete $VM; run: prlctl delete $VM" >&2
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ── Results ───────────────────────────────────────────────────────────────
RESULTS=(); FAILED=0
result() {  # result PASS|FAIL|SKIP "name" "detail" seconds
    local s="$1" c="$green"
    [ "$s" = FAIL ] && { c="$red"; FAILED=1; }
    [ "$s" = SKIP ] && c="$yellow"
    RESULTS+=("$(printf '%s%-4s%s  %-36s %6ss  %s' "$c" "$s" "$nc" "$2" "$4" "$3")")
    printf '    %s%s%s  %s\n' "$c" "$s" "$nc" "$3"
}
T0=0; tic() { T0=$SECONDS; }; toc() { echo $((SECONDS - T0)); }

# Runs PowerShell (the script on stdin) in the VM as the signed-in user,
# logging to $OUT/<log>; returns its exit code. -EncodedCommand (base64 of
# UTF-16LE) carries the script through prlctl without any quoting.
vm_ps() {  # vm_ps <log> <<'PS' ... PS
    local log="$OUT/$1" enc
    enc="$( { printf '$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"\n'; cat; } \
            | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')"
    prlctl exec "$VM" --current-user powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -EncodedCommand "$enc" 2>&1 | tr -d '\r' | tee "$log"
    return "${PIPESTATUS[0]}"
}

# ── Clone and start ───────────────────────────────────────────────────────
step "Cloning $SRC (snapshot $SNAP_ID) as $VM"
tic
prlctl clone "$SRC" --name "$VM" --linked --id "$SNAP_ID" > "$OUT/clone.log" 2>&1 \
    || { cat "$OUT/clone.log"; die "prlctl clone failed (see $OUT/clone.log)"; }
CLONED=1
prlctl start "$VM" >> "$OUT/clone.log" 2>&1 || die "couldn't start $VM (see $OUT/clone.log)"
info "waiting for Windows to start and sign its user in"
ready=0
for _ in $(seq 120); do      # up to 10 minutes
    if prlctl exec "$VM" --current-user cmd.exe /c echo ready 2>/dev/null | grep -q ready; then ready=1; break; fi
    sleep 5
done
[ "$ready" = 1 ] || die "the VM never answered as a signed-in user: is Parallels Tools installed and automatic sign-in set up in the snapshot? (--keep leaves it running to look)"
result PASS "0. clone + start" "$VM from $SRC" "$(toc)"
RAW="https://raw.githubusercontent.com/$GH_REPO/$REF/install"

if [ "$DEV" = 0 ]; then
    # ── Lite ──────────────────────────────────────────────────────────────
    step "L1. install_lite_windows.ps1 ($REF; release $VERSION)"
    tic
    vm_ps L1_install.log <<PS
\$v = '$VERSION'
\$args2 = @{ NoStart = \$true }
if (\$v -ne 'latest') { \$args2.Version = \$v }
& ([scriptblock]::Create((Invoke-RestMethod '$RAW/install_lite_windows.ps1'))) @args2
\$pkg = Get-ChildItem \$HOME -Directory -Filter 'dmeklr-lite-*-windows-x86_64' | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not \$pkg) { throw 'no package folder in the home folder' }
foreach (\$f in 'run_lite.cmd', '.venv\Scripts\python.exe') {
    if (-not (Test-Path (Join-Path \$pkg.FullName \$f))) { throw "missing \$f" }
}
if (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'DME+KLR lite.lnk'))) { throw 'no desktop shortcut' }
"PACKAGE=\$(\$pkg.FullName)"
"node \$(& node --version)"
PS
    if [ $? = 0 ]; then result PASS "L1. lite installer" "$(sed -n 's/^PACKAGE=//p' "$OUT/L1_install.log" | head -1)" "$(toc)"
    else result FAIL "L1. lite installer" "see L1_install.log" "$(toc)"; fi

    step "L2-L4. bridge, RUN REGRESSIONS, one regression test ($TEST)"
    tic
    vm_ps L2_bridge.log <<PS
\$pkg = (Get-ChildItem \$HOME -Directory -Filter 'dmeklr-lite-*-windows-x86_64' | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
\$p = Start-Process cmd -ArgumentList '/c', 'run_lite.cmd > bridge.log 2>&1' -WorkingDirectory \$pkg -PassThru -WindowStyle Hidden
try {
    \$ok = \$false
    foreach (\$i in 1..90) {
        try { if ((Invoke-WebRequest 'http://127.0.0.1:8951/?live' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) { \$ok = \$true; break } } catch { }
        Start-Sleep 1
    }
    "L2=\$ok"
    \$ra = \$null
    try { \$ra = Invoke-RestMethod 'http://127.0.0.1:8951/runall' -TimeoutSec 10 } catch { "runall: \$_" }
    "L3=\$(\$ra.mode)"
} finally {
    taskkill /F /T /PID \$p.Id | Out-Null
    Get-Content (Join-Path \$pkg 'bridge.log') -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { "bridge| \$_" }
}
Push-Location \$pkg
\$ErrorActionPreference = 'Continue'
& .\.venv\Scripts\python.exe run_tests.py '$TEST' 2>&1 | ForEach-Object { "\$_" }
"L4=\$LASTEXITCODE"
Pop-Location
PS
    t=$(toc)
    if grep -q '^L2=True' "$OUT/L2_bridge.log"; then result PASS "L2. bridge serves ?live" "http://127.0.0.1:8951/?live" "$t"
    else result FAIL "L2. bridge serves ?live" "see L2_bridge.log" "$t"; fi
    if grep -q '^L3=lite' "$OUT/L2_bridge.log"; then result PASS "L3. RUN REGRESSIONS offered" "/runall mode lite" "$t"
    else result FAIL "L3. RUN REGRESSIONS offered" "/runall: $(sed -n 's/^L3=//p' "$OUT/L2_bridge.log") (an old release?)" "$t"; fi
    if grep -q '^L4=0' "$OUT/L2_bridge.log"; then result PASS "L4. run_tests.py $TEST" "passed" "$t"
    else result FAIL "L4. run_tests.py $TEST" "exit $(sed -n 's/^L4=//p' "$OUT/L2_bridge.log"), see L2_bridge.log" "$t"; fi
else
    # ── Developer install ─────────────────────────────────────────────────
    step "D1. install_windows.ps1 -Clone C:\\dmeklr\\944turbo_dme_klr -Ref $REF -Yes"
    tic
    vm_ps D1_install.log <<PS
\$f = Join-Path \$env:TEMP 'install_windows.ps1'
Invoke-WebRequest '$RAW/install_windows.ps1' -OutFile \$f -UseBasicParsing
\$ErrorActionPreference = 'Continue'
& powershell -NoProfile -ExecutionPolicy Bypass -File \$f -Clone C:\dmeklr\944turbo_dme_klr -Ref '$REF' -Yes
exit \$LASTEXITCODE
PS
    if [ $? = 0 ] && grep -q '^Installed' "$OUT/D1_install.log"; then result PASS "D1. developer installer" "MSYS2 + toolchain + smoke tests" "$(toc)"
    else result FAIL "D1. developer installer" "see D1_install.log" "$(toc)"; fi

    step "D2-D3. clean checkout, test_windows_install.sh"
    tic
    vm_ps D2_checks.log <<'PS'
$env:MSYSTEM = 'UCRT64'; $env:CHERE_INVOKING = '1'; $env:MSYS2_PATH_TYPE = 'minimal'
Set-Location C:\dmeklr\944turbo_dme_klr
$ErrorActionPreference = 'Continue'
$st = & C:\msys64\usr\bin\bash.exe -lc 'git status --porcelain'
$st | ForEach-Object { "status| $_" }
"D2=$(@($st | Where-Object { $_ }).Count)"
& C:\msys64\usr\bin\bash.exe -lc 'install/test_windows_install.sh --logdir ../tmp/windows-install-test' 2>&1 | ForEach-Object { "$_" }
"D3=$LASTEXITCODE"
PS
    t=$(toc)
    if grep -q '^D2=0' "$OUT/D2_checks.log"; then result PASS "D2. checkout clean" "git status empty" "$t"
    else result FAIL "D2. checkout clean" "$(grep -c '^status| ' "$OUT/D2_checks.log") changed file(s), see D2_checks.log" "$t"; fi
    if grep -q '^D3=0' "$OUT/D2_checks.log"; then result PASS "D3. test_windows_install.sh" "passed" "$t"
    else result FAIL "D3. test_windows_install.sh" "see D2_checks.log" "$t"; fi
fi

# ── Summary ───────────────────────────────────────────────────────────────
step "Results ($([ "$DEV" = 1 ] && echo developer install || echo lite package), $SRC, ref $REF)"
printf '  %s\n' "${RESULTS[@]}"
echo
echo "Logs: $OUT"
[ "$FAILED" = 0 ] && { echo "${green}ALL PASSED${nc}"; exit 0; }
echo "${red}SOME FAILED${nc}"; exit 1
