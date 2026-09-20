param(
    [switch]$Quiet,
    [string]$StateDirectory,
    [switch]$SkipExternalProcesses
)

$ErrorActionPreference = 'SilentlyContinue'
$dataRoot = if ($StateDirectory) { $StateDirectory } else { Join-Path $env:LOCALAPPDATA 'AlienGamerMode' }
$statePath = Join-Path $dataRoot 'agent-state.json'
$stopRequestPath = Join-Path $dataRoot 'stop-monitor.request.json'
$hwinfoStopSignal = Join-Path $dataRoot 'stop-hwinfo.signal'
$rainmeter = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"

if (-not $SkipExternalProcesses -and (Test-Path -LiteralPath $rainmeter)) {
    & $rainmeter '!DeactivateConfig' 'AlienGamerMode' | Out-Null
}

$recorder = Join-Path $PSScriptRoot 'AlienGamerEventRecorder.ps1'
if (-not $SkipExternalProcesses -and (Test-Path -LiteralPath $recorder)) {
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File $recorder -StopBuffer -RainmeterConfig 'AlienGamerMode' | Out-Null
}

$bridgePidPath = Join-Path $dataRoot 'bridge.pid'
if (Test-Path -LiteralPath $bridgePidPath) {
    try { Stop-Process -Id ([int](Get-Content -LiteralPath $bridgePidPath -Raw)) -Force } catch { }
    Remove-Item -LiteralPath $bridgePidPath -Force
}

if (-not (Test-Path -LiteralPath $dataRoot)) {
    New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
}
if (-not $SkipExternalProcesses) {
    'stop' | Set-Content -LiteralPath $hwinfoStopSignal -Encoding ASCII
    $sensorTask = Get-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue
    if ($sensorTask) { Stop-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue }
    Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue
    Stop-Process -Name Rainmeter -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $hwinfoStopSignal -Force -ErrorAction SilentlyContinue
}

[ordered]@{
    active = $false
    stoppedAt = (Get-Date).ToString('o')
    stopMode = 'fallback'
} | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
Remove-Item -LiteralPath $stopRequestPath -Force -ErrorAction SilentlyContinue

if (-not $Quiet) { Write-Output 'AlienGamer Mode detenido.' }
