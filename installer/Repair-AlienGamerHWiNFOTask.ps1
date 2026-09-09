$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$packageRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $packageRoot 'src'
$assetRoot = Join-Path $packageRoot 'assets'
$sourceLauncher = Join-Path $packageRoot 'src\Start-AlienGamerHWiNFO.ps1'
$installRoot = Join-Path $env:ProgramData 'AlienGamerMode\App'
$installedLauncher = Join-Path $installRoot 'Start-AlienGamerHWiNFO.ps1'
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$taskName = 'AlienGamerMode-HWiNFO'

function Set-IniSetting([string]$Path,[string]$Key,[string]$Value) {
    $content = if (Test-Path $Path) { Get-Content $Path -Raw } else { "[Settings]`r`n" }
    if ($content -match "(?m)^$([regex]::Escape($Key))=") {
        $content = [regex]::Replace($content,"(?m)^$([regex]::Escape($Key))=.*$","$Key=$Value")
    } else {
        $content = $content -replace '(?m)^\[Settings\]\s*$',"[Settings]`r`n$Key=$Value"
    }
    $content | Set-Content -LiteralPath $Path -Encoding ASCII
}

try {
    if (-not (Test-Path -LiteralPath $installRoot)) { New-Item -ItemType Directory -Path $installRoot -Force | Out-Null }
    Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $installRoot -Recurse -Force
    $installedAssets = Join-Path $installRoot 'assets'
    if (-not (Test-Path -LiteralPath $installedAssets)) { New-Item -ItemType Directory -Path $installedAssets -Force | Out-Null }
    Copy-Item -Path (Join-Path $assetRoot '*') -Destination $installedAssets -Recurse -Force

    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    $hwinfoIni = Join-Path $env:ProgramFiles 'HWiNFO64\HWiNFO64.INI'
    foreach ($pair in @(@('SensorsOnly','1'),@('SensorsSM','1'),@('OpenSystemSummary','0'),@('OpenSensors','1'),@('MinimalizeMainWnd','1'),@('MinimalizeSensors','1'),@('ShowWelcomeAndProgress','0'),@('MinimalizeSensorsClose','1'))) {
        Set-IniSetting $hwinfoIni $pair[0] $pair[1]
    }

    $taskArguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installedLauncher`""
    $scheduler = New-Object -ComObject 'Schedule.Service'
    $scheduler.Connect()
    $taskFolder = $scheduler.GetFolder('\')
    $taskDefinition = $scheduler.NewTask(0)
    $taskDefinition.RegistrationInfo.Description = 'Inicia HWiNFO64 con sensores y memoria compartida para AlienGamer Mode.'
    $taskDefinition.Principal.UserId = $identity.Name
    $taskDefinition.Principal.LogonType = 3
    $taskDefinition.Principal.RunLevel = 1
    $taskDefinition.Settings.Compatibility = 2
    $taskDefinition.Settings.Enabled = $true
    $taskDefinition.Settings.AllowDemandStart = $true
    $taskDefinition.Settings.StartWhenAvailable = $true
    $taskDefinition.Settings.DisallowStartIfOnBatteries = $false
    $taskDefinition.Settings.StopIfGoingOnBatteries = $false
    $taskDefinition.Settings.ExecutionTimeLimit = 'PT0S'
    $taskExec = $taskDefinition.Actions.Create(0)
    $taskExec.Path = $powershell
    $taskExec.Arguments = $taskArguments
    [void]$taskFolder.RegisterTaskDefinition($taskName,$taskDefinition,6,$null,$null,3,$null)

    Start-ScheduledTask -TaskName $taskName
    $processDeadline = [DateTime]::UtcNow.AddSeconds(12)
    do {
        Start-Sleep -Milliseconds 250
        $hwinfoProcess = Get-Process HWiNFO64 -ErrorAction SilentlyContinue
    } while (-not $hwinfoProcess -and [DateTime]::UtcNow -lt $processDeadline)
    if (-not $hwinfoProcess) {
        $result = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
        throw ('HWiNFO no pudo iniciar (0x{0:X8}).' -f $result)
    }

    $sharedMemoryReady = $false
    $memoryDeadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        $map = $null
        try {
            $map = [IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting('Global\HWiNFO_SENS_SM2',[IO.MemoryMappedFiles.MemoryMappedFileRights]::Read)
            $sharedMemoryReady = $true
        } catch {
            Start-Sleep -Milliseconds 300
        } finally {
            if ($map) { $map.Dispose() }
        }
    } while (-not $sharedMemoryReady -and [DateTime]::UtcNow -lt $memoryDeadline)
    if (-not $sharedMemoryReady) { throw 'HWiNFO inicio, pero no publico la memoria compartida de sensores.' }

    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 600

    $command = Join-Path $installRoot 'AlienGamerModeCommand.ps1'
    Start-Process $powershell -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$command`" -Activate"
    [Windows.Forms.MessageBox]::Show('La tarea de sensores fue reparada y validada. AlienGamer Mode se está iniciando.','Reparación completada','OK','Information') | Out-Null
} catch {
    [Windows.Forms.MessageBox]::Show($_.Exception.Message,'No se completó la reparación','OK','Error') | Out-Null
    exit 1
}
