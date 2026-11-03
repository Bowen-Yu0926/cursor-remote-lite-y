@echo off
setlocal enabledelayedexpansion
title Cursor ^& opencode Remote
cd /d "%~dp0"

REM ============================================================
REM  Cursor Remote one-click start (universal)
REM  Project dir = this script's own folder
REM  Cursor port = auto-detected (scan 9222-9225 for Cursor)
REM ============================================================

REM ---- auto-detect Cursor debug port ----
set "CDP_PORT="
for %%P in (9222 9223 9224 9225) do if not defined CDP_PORT call :checkPort %%P
if not defined CDP_PORT set "CDP_PORT=9223"
set "CDP_URL=http://127.0.0.1:!CDP_PORT!"
goto :main

:checkPort
powershell -NoProfile -Command "try { $v = Invoke-RestMethod 'http://127.0.0.1:%1/json/version' -TimeoutSec 1; if ($v.'User-Agent' -match 'Cursor') { exit 0 } else { exit 1 } } catch { exit 1 }"
if not errorlevel 1 set "CDP_PORT=%1"
exit /b

:main
echo ============================================
echo  Cursor Remote - one-click start
echo  Project dir : %~dp0
echo  Cursor port : !CDP_PORT!
echo ============================================
echo.

REM ---- 0. stop old service (port 3939) ----
echo [0/3] Stopping old service (port 3939) if running...
powershell -NoProfile -Command "$c = Get-NetTCPConnection -LocalPort 3939 -State Listen -ErrorAction SilentlyContinue; if ($c) { $c | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue; Write-Output ('      Stopped old service PID ' + $_) } } else { Write-Output '      No old service running.' }"
timeout /t 1 /nobreak >nul

echo.
REM ---- 1. ensure Cursor is running (with debug port) ----
echo [1/3] Ensuring Cursor is running (port !CDP_PORT!)...
powershell -NoProfile -Command "try { Invoke-RestMethod 'http://127.0.0.1:!CDP_PORT!/json/version' -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }"
if not errorlevel 1 (
  echo       Cursor already running on !CDP_PORT!.
) else (
  echo       Starting Cursor with debug port...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-cursor.ps1"
)

echo       Waiting for Cursor...
set tries=0
:waitloop
powershell -NoProfile -Command "try { Invoke-RestMethod 'http://127.0.0.1:!CDP_PORT!/json/version' -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }"
if not errorlevel 1 goto ready
timeout /t 2 /nobreak >nul
set /a tries+=1
if !tries! lss 40 goto waitloop
echo       WARNING: Cursor not detected. Starting anyway...

:ready
echo       Cursor ready.
echo.

REM ---- 2. ensure opencode is running (debug port 9222) ----
echo [2/3] Ensuring opencode is running (port 9222)...
powershell -NoProfile -Command "try { $v = Invoke-RestMethod 'http://127.0.0.1:9222/json/version' -TimeoutSec 1; if ($v.'User-Agent' -match 'OpenCode') { exit 0 } else { exit 1 } } catch { exit 1 }"
if not errorlevel 1 (
  echo       opencode already running on 9222.
) else (
  echo       Starting opencode with debug port...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-opencode.ps1"
)
echo.

REM ---- 3. start service (tunnel + GitHub Pages) ----
echo [3/3] Starting service (tunnel + GitHub Pages)...
echo       Keep this window open. Ctrl+C to stop.
echo.

npm run public

echo.
echo Service stopped.
pause
