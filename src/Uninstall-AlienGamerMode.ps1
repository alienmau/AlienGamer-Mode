param([switch]$RemoveUserConfiguration)

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($RemoveUserConfiguration) { $arguments += ' -RemoveUserConfiguration' }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

$ErrorActionPreference = 'SilentlyContinue'
$dataRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
$appRoot = Join-Path $env:ProgramData 'AlienGamerMode\App'
$legacyAppRoot = Join-Path $dataRoot 'App'
$rainmeter = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
if (Test-Path $rainmeter) { & $rainmeter '!DeactivateConfig' 'AlienGamerMode' }
'stop' | Set-Content -LiteralPath (Join-Path $dataRoot 'stop-hwinfo.signal') -Encoding ASCII
Start-Sleep -Milliseconds 700
Stop-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO'
Stop-Process -Name HWiNFO64 -Force
Unregister-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -Confirm:$false
$pidFile = Join-Path $dataRoot 'bridge.pid'
if (Test-Path $pidFile) { Stop-Process -Id ([int](Get-Content $pidFile -Raw)) -Force }
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'powershell' -and $_.CommandLine -like '*AlienGamerModeAgent.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$desktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Activar AlienGamer Mode.lnk'
$startFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AlienGamer Mode'
$startupLink = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\AlienGamer Mode.lnk'
Remove-Item $desktopLink,$startupLink -Force
Remove-Item $startFolder -Recurse -Force
$rainmeterIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
$skinRoot = $null
if (Test-Path $rainmeterIni) {
    $skinLine = Get-Content $rainmeterIni | Where-Object { $_ -like 'SkinPath=*' } | Select-Object -First 1
    if ($skinLine) { $skinRoot = $skinLine.Substring(9).TrimEnd('\') }
}
if (-not $skinRoot) { $skinRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins' }
$skinPath = Join-Path $skinRoot 'AlienGamerMode'
if (Test-Path $skinPath) { Remove-Item $skinPath -Recurse -Force }
Remove-Item $appRoot,$legacyAppRoot -Recurse -Force
if ($RemoveUserConfiguration) { Remove-Item $dataRoot -Recurse -Force }
