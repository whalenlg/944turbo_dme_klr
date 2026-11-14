@echo off
rem Start the lite package's live simulator for the dashboard.
rem   run_lite.cmd [bridge options, e.g. --port 8951]
rem Then open the dashboard it serves, http://127.0.0.1:8951/?live (no internet needed).
setlocal
if "%DMEKLR_TMP%"=="" set "DMEKLR_TMP=%~dp0data"
if not exist "%DMEKLR_TMP%" mkdir "%DMEKLR_TMP%"
where node >nul 2>nul || (echo run_lite.cmd: Node.js 18 or newer is needed ^(https://nodejs.org^) & exit /b 1)
echo Starting; then open the dashboard address the bridge prints (http://127.0.0.1:8951/?live).
node "%~dp0dme_klr\live\bridge.mjs" %*
