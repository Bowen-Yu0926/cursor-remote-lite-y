# Relaunch the OpenCode desktop app with the Chrome DevTools Protocol enabled (required for remote control).
# WARNING: this quits the running OpenCode first; the current session may be lost.
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File .\start-opencode.ps1
param([switch]$Worker)
$ErrorActionPreference = 'Stop'

$Port = if ($env:OPENCODE_PORT) { $env:OPENCODE_PORT } else { 9222 }

function Test-Cdp {
  try { Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 1 | Out-Null; $true } catch { $false }
}

function Find-OpenCode {
  $running = Get-Process -Name OpenCode -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
  if ($running) { return $running.Path }
  foreach ($p in @("$env:LOCALAPPDATA\Programs\OpenCode\OpenCode.exe", "$env:ProgramFiles\OpenCode\OpenCode.exe", "E:\soft\OpenCode\OpenCode.exe")) {
    if (Test-Path $p) { return $p }
  }
  $null
}

if (-not $Worker) {
  if (Test-Cdp) {
    Write-Host "opencode already exposes CDP on port $Port. Nothing to do."
    exit 0
  }
  $exe = Find-OpenCode
  if (-not $exe) { Write-Host 'OpenCode.exe not found. Run it yourself: <OpenCode install dir>\OpenCode.exe --remote-debugging-port=9222'; exit 1 }
  # Detached so it survives when launched from the launcher window.
  Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Worker')
  Write-Host "OpenCode will quit and reopen with the debugging port on $Port"
  exit 0
}

$exe = Find-OpenCode
if (-not $exe) { exit 1 }
$procs = Get-Process -Name OpenCode -ErrorAction SilentlyContinue
if ($procs) {
  $procs | ForEach-Object { $_.CloseMainWindow() | Out-Null }
  for ($i = 0; $i -lt 30 -and (Get-Process -Name OpenCode -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
  if (Get-Process -Name OpenCode -ErrorAction SilentlyContinue) {
    Stop-Process -Name OpenCode -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 60 -and (Get-Process -Name OpenCode -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
  }
  if (Get-Process -Name OpenCode -ErrorAction SilentlyContinue) { exit 1 }
  Start-Sleep -Seconds 1
}

Start-Process -FilePath $exe -ArgumentList "--remote-debugging-port=$Port"
for ($i = 0; $i -lt 30; $i++) {
  if (Test-Cdp) { exit 0 }
  Start-Sleep -Seconds 1
}
