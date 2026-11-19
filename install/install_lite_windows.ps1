<#
============================================================
 install_lite_windows.ps1 - install and start the DME+KLR lite package on Windows

 One command on a clean PC: installs Node.js and Python with winget if
 they are missing, downloads the lite package from the GitHub release,
 unpacks it, makes its Python venv, puts a "DME+KLR lite" shortcut on the
 desktop and starts it, opening http://127.0.0.1:8951/?live in the browser.
 Running it again updates to the release asked for and keeps data\.

 Usage (PowerShell; a normal window, not "Run as administrator"):
     irm https://raw.githubusercontent.com/whalenlg/944turbo_dme_klr/main/install/install_lite_windows.ps1 | iex
 or, with options, from a downloaded copy:
     powershell -ExecutionPolicy Bypass -File install_lite_windows.ps1 [options]

   -Version TAG   release to install, e.g. v1.0.1 (default: the latest)
   -Dir DIR       folder to unpack it in (default: your home folder)
   -NoPython      skip Python and the venv (only the MAPS tabs' graphs need it)
   -NoStart       don't start it at the end
   -Help          this text
============================================================
#>
param(
    [string]$Version = 'latest',
    [string]$Dir = $HOME,
    [switch]$NoPython,
    [switch]$NoStart,
    [switch]$Help
)

# Everything runs in a child scope (& { }), so that run through iex the
# settings below don't stay changed in your PowerShell window
& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with it
$Repo = 'whalenlg/944turbo_dme_klr'

if ($Help) {
    if ($PSCommandPath) {
        $lines = Get-Content $PSCommandPath
        $lines[2..($lines.IndexOf('#>') - 2)] | ForEach-Object { $_ -replace '^ ', '' }
    } else { Write-Host "See https://github.com/$Repo/blob/main/install/install_lite_windows.ps1" }
    return
}

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor White }
function Warn($msg) { Write-Host "warning: $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "error: $msg" -ForegroundColor Red; throw $msg }

# A winget install also updates PATH in the registry, but not in this
# window: read it again from there
function Update-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-WithWinget([string]$id, [string]$what, [string]$url) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Die "$what is needed and winget isn't available to install it; install it from $url, then run this again"
    }
    Write-Host "+ winget install $id"
    & winget install $id --source winget --accept-source-agreements --accept-package-agreements --silent
    Update-Path
}

function Get-NodeMajor {
    $n = Get-Command node -ErrorAction SilentlyContinue
    if (-not $n) { return 0 }
    $v = (& $n.Source --version) -replace '^v', ''
    return [int]($v.Split('.')[0])
}

# Python: the py launcher, or python.exe, but not the Microsoft Store alias
# in WindowsApps (it opens the Store instead of running Python)
function Find-Python {
    foreach ($c in 'py', 'python') {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -notmatch 'WindowsApps') {
            # (the leading comma keeps a one-item array an array)
            if ($c -eq 'py') { return ,@($cmd.Source, '-3') }
            return ,@($cmd.Source)
        }
    }
    return $null
}

if ((Get-Location).Path -like "$env:windir*") {
    Write-Host "(installing into $Dir, not $((Get-Location).Path))"
}

# -- Node.js ----------------------------------------------------------------
Step 'Node.js (18 or newer)'
if ((Get-NodeMajor) -ge 18) {
    Write-Host "found $(& node --version)"
} else {
    Install-WithWinget 'OpenJS.NodeJS.LTS' 'Node.js 18 or newer' 'https://nodejs.org'
    if ((Get-NodeMajor) -lt 18) { Die 'Node.js still not found; open a new PowerShell window and run this again' }
    Write-Host "installed $(& node --version)"
}

# -- Python -----------------------------------------------------------------
$Py = $null
if (-not $NoPython) {
    Step 'Python 3'
    $Py = Find-Python
    if (-not $Py) {
        Install-WithWinget 'Python.Python.3.12' 'Python 3' 'https://www.python.org/downloads/'
        $Py = Find-Python
    }
    if ($Py) {
        Write-Host "found $(& $Py[0] $Py[1..9] --version 2>&1)"
    } else {
        Warn "Python not found; going on without it (only the MAPS tabs' graphs need it)"
    }
}

# -- The package ------------------------------------------------------------
if ($Version -eq 'latest') {
    Step 'Looking up the latest release'
    $Version = (Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest").tag_name
    Write-Host $Version
}
$name = "dmeklr-lite-$Version-windows-x86_64"
$zip = Join-Path $Dir "$name.zip"
$Pkg = Join-Path $Dir $name
Step "Downloading $name.zip into $Dir"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$url = "https://github.com/$Repo/releases/download/$Version/$name.zip"
Write-Host "+ $url"
Invoke-WebRequest $url -OutFile $zip -UseBasicParsing
Expand-Archive $zip -DestinationPath $Dir -Force
Remove-Item $zip -Force -ErrorAction SilentlyContinue
if (-not (Test-Path (Join-Path $Pkg 'run_lite.cmd'))) { Die "the archive didn't unpack to $Pkg" }

# -- Python venv --------------------------------------------------------------
if ($Py) {
    Step 'Python packages (.venv in the package folder)'
    $venvPy = Join-Path $Pkg '.venv\Scripts\python.exe'
    if (-not (Test-Path $venvPy)) {
        & $Py[0] $Py[1..9] -m venv (Join-Path $Pkg '.venv')
        if ($LASTEXITCODE -ne 0) { Warn 'making the venv failed; going on without it' }
    }
    if (Test-Path $venvPy) {
        & $venvPy -m pip install --disable-pip-version-check -q -r (Join-Path $Pkg 'requirements.txt')
        if ($LASTEXITCODE -ne 0) {
            # On Windows on ARM a package may have no ARM64 build
            Warn "pip couldn't install every package; the MAPS tabs' graphs may be missing, the rest works"
        }
    }
}

# -- Desktop shortcut -----------------------------------------------------------
try {
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DME+KLR lite.lnk'
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $s.TargetPath = Join-Path $Pkg 'run_lite.cmd'
    $s.WorkingDirectory = $Pkg
    $s.Save()
    Write-Host "`nDesktop shortcut: $lnk"
} catch { }

Write-Host ''
Write-Host "Installed in $Pkg. To start it later: double-click 'DME+KLR lite' on the desktop,"
Write-Host "or run $Pkg\run_lite.cmd; then open http://127.0.0.1:8951/?live"

if (-not $NoStart) {
    Step 'Starting (Ctrl+C stops it)'
    # Open the page once the bridge has had a few seconds to start
    Start-Process cmd -ArgumentList '/c', 'timeout /t 6 >nul & start "" "http://127.0.0.1:8951/?live"' -WindowStyle Hidden
    Push-Location $Pkg
    try { & (Join-Path $Pkg 'run_lite.cmd') } finally { Pop-Location }
}
}
