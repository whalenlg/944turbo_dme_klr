<#
============================================================
 install_windows.ps1 — install the DME+KLR toolchain on Windows

 Installs MSYS2 (if it isn't there) and runs install/install_msys2.sh in
 its UCRT64 environment, which installs gcc, make, git, Verilator, Icarus
 Verilog, GTKWave, Node.js and Python with its packages, then checks the
 toolchain and runs the smoke tests (KLR regression on Icarus Verilog,
 warm_idle_5s on Verilator).

 Usage (PowerShell, from the checkout):
     powershell -ExecutionPolicy Bypass -File install\install_windows.ps1 [options]

   -MsysRoot DIR    where MSYS2 is or goes (default C:\msys64)
   -Clone DIR       no checkout yet: clone the repo into DIR first (with
                    MSYS2's git) and install from there
   -Venv            also make a Python venv at <repo>\944venv
   -WithDashboard   also clone whalenlg/dme-dashboard and npm install it
   -NoGtkwave       skip GTKWave
   -SkipTests       don't run the smoke tests at the end
   -Yes             don't ask pacman to confirm
   -Help            this text

 Afterwards, open "MSYS2 UCRT64" from the Start menu (or run
 <MsysRoot>\ucrt64.exe), then:   cd <checkout>; source setup
============================================================
#>
[CmdletBinding()]
param(
    [string]$MsysRoot = 'C:\msys64',
    [string]$Clone = '',
    [switch]$Venv,
    [switch]$WithDashboard,
    [switch]$NoGtkwave,
    [switch]$SkipTests,
    [switch]$Yes,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$RepoUrl = 'https://github.com/whalenlg/944turbo_dme_klr.git'
# The MSYS2 base archive (a self-extracting 7z); "latest" follows releases
$MsysSfx = 'https://repo.msys2.org/distrib/msys2-x86_64-latest.sfx.exe'

if ($Help) {
    $lines = Get-Content $PSCommandPath
    $lines[2..($lines.IndexOf('#>') - 2)] | ForEach-Object { $_ -replace '^ ', '' }
    exit 0
}

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor White }
function Die($msg)  { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

if (-not [Environment]::Is64BitOperatingSystem) { Die 'needs 64-bit Windows' }

$Bash = Join-Path $MsysRoot 'usr\bin\bash.exe'

# Runs a command in an MSYS2 login shell. UCRT64 puts its native tools
# (gcc, verilator, ...) first on PATH; CHERE_INVOKING keeps the current folder.
function Invoke-Msys([string]$cmd, [string]$dir = (Get-Location).Path) {
    $env:MSYSTEM = 'UCRT64'
    $env:CHERE_INVOKING = '1'
    $env:MSYS2_PATH_TYPE = 'minimal'
    Push-Location $dir
    try { & $Bash -lc $cmd | Out-Host; return $LASTEXITCODE } finally { Pop-Location }
}

# ── MSYS2 ─────────────────────────────────────────────────────────────────
if (Test-Path $Bash) {
    Step "MSYS2 found at $MsysRoot"
} else {
    Step "Installing MSYS2 into $MsysRoot"
    $parent = Split-Path $MsysRoot -Parent
    $leaf   = Split-Path $MsysRoot -Leaf
    if (Test-Path $MsysRoot) { Die "$MsysRoot exists but has no usr\bin\bash.exe; remove it or pick another -MsysRoot" }
    $sfx = Join-Path $env:TEMP 'msys2-base-x86_64.sfx.exe'
    Write-Host "+ download $MsysSfx"
    $ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with it
    Invoke-WebRequest -Uri $MsysSfx -OutFile $sfx -UseBasicParsing
    # It unpacks a folder called msys64 into the -o folder
    $tmpOut = Join-Path $parent ("msys2-unpack-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Write-Host "+ $sfx -y -o$tmpOut"
    & $sfx -y "-o$tmpOut" | Out-Null
    if ($LASTEXITCODE -ne 0) { Die "unpacking MSYS2 failed (exit $LASTEXITCODE)" }
    Move-Item (Join-Path $tmpOut 'msys64') $MsysRoot
    Remove-Item $tmpOut -Recurse -Force
    Remove-Item $sfx -Force

    Step 'MSYS2 first start (sets up the keyring) and core update'
    # The first login shell initialises /etc and pacman's keys
    $null = Invoke-Msys 'echo MSYS2 initialised'
    # The first -Syuu updates MSYS2's core (and may end the shell); the second the rest
    $null = Invoke-Msys 'pacman -Syuu --noconfirm'
    $null = Invoke-Msys 'pacman -Syuu --noconfirm'

    # Start-menu-like shortcut for the UCRT64 terminal on the desktop
    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'MSYS2 UCRT64.lnk'
        $ws = New-Object -ComObject WScript.Shell
        $s = $ws.CreateShortcut($lnk)
        $s.TargetPath = Join-Path $MsysRoot 'ucrt64.exe'
        $s.WorkingDirectory = $MsysRoot
        $s.Save()
        Write-Host "Desktop shortcut: $lnk"
    } catch { }
}

# ── The checkout ──────────────────────────────────────────────────────────
if ($Clone) {
    $Repo = [IO.Path]::GetFullPath($Clone)
    if (Test-Path (Join-Path $Repo '.git')) {
        Step "Checkout already at $Repo"
    } else {
        Step "Cloning $RepoUrl into $Repo"
        $null = Invoke-Msys 'pacman -S --needed --noconfirm git'
        $unixRepo = (& (Join-Path $MsysRoot 'usr\bin\cygpath.exe') -u $Repo)
        $rc = Invoke-Msys "git clone '$RepoUrl' '$unixRepo'"
        if ($rc -ne 0) { Die "git clone failed (exit $rc)" }
    }
} else {
    $Repo = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path (Join-Path $Repo 'install\install_msys2.sh'))) {
        Die "run this from a checkout of the repo, or pass -Clone <folder>"
    }
}
if ($Repo -match ' ') {
    Write-Host "warning: '$Repo' has a space in it; Verilator's builds fail in such folders." -ForegroundColor Yellow
}

# ── Toolchain (install_msys2.sh) ─────────────────────────────────────────
$opts = @()
if ($Venv)          { $opts += '--venv' }
if ($WithDashboard) { $opts += '--with-dashboard' }
if ($NoGtkwave)     { $opts += '--no-gtkwave' }
if ($SkipTests)     { $opts += '--skip-tests' }
if ($Yes)           { $opts += '--yes' }
Step "install/install_msys2.sh $($opts -join ' ')"
$rc = Invoke-Msys ("./install/install_msys2.sh " + ($opts -join ' ')) $Repo
if ($rc -ne 0) { Die "install_msys2.sh failed (exit $rc)" }

Write-Host ''
Write-Host 'Installed. To use it, open "MSYS2 UCRT64" (Start menu, or' (Join-Path $MsysRoot 'ucrt64.exe') ') and run:'
$u = (& (Join-Path $MsysRoot 'usr\bin\cygpath.exe') -u $Repo)
Write-Host "    cd '$u' && source setup"
