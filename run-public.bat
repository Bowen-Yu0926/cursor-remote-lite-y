@echo off
setlocal enabledelayedexpansion
title Cursor Remote - Start
cd /d "%~dp0"

set CDP_PORT=9223
set CDP_URL=http://127.0.0.1:9223

echo ============================================
echo  Cursor Remote - one-click start
echo ============================================
echo.

echo [0/2] Stopping old service (port 3939) if running...
powershell -NoProfile -Command "$c = Get-NetTCPConnection -LocalPort 3939 -State Listen -ErrorAction SilentlyContinue; if ($c) { $c | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue; Write-Output ('      Stopped old service PID ' + $_) } } else { Write-Output '      No old service running.' }"
timeout /t 1 /nobreak >nul

echo.
echo [1/2] Checking Cursor (port 9223)...
powershell -NoProfile -Command "try { Invoke-RestMethod 'http://127.0.0.1:9223/json/version' -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }"
if not errorlevel 1 (
  echo       Cursor already running on 9223.
) else (
  echo       Starting Cursor with debug port...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-cursor.ps1"
)

echo       Waiting for Cursor...
set tries=0
:waitloop
powershell -NoProfile -Command "try { Invoke-RestMethod 'http://127.0.0.1:9223/json/version' -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }"
if not errorlevel 1 goto ready
timeout /t 2 /nobreak >nul
set /a tries+=1
if !tries! lss 40 goto waitloop
echo       WARNING: Cursor not detected. Starting anyway...

:ready
echo       Cursor ready.
echo.

echo [2/2] Starting service (tunnel + GitHub Pages)...
echo       Keep this window open. Ctrl+C to stop.
echo.

npm run public

echo.
echo Service stopped.
pause
