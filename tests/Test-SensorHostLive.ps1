param([string]$ResultPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$taskName = 'AlienGamerMode-SensorHost-Validation'
$registered = $false
$result = [ordered]@{ passed=$false; started=$false; sharedMemory=$false; stopped=$false; error=$null }
$signal = Join-Path $env:LOCALAPPDATA 'AlienGamerMode\stop-hwinfo.signal'
try {
    if (Get-Process HWiNFO64 -ErrorAction SilentlyContinue) { throw 'HWiNFO esta activo: no se interrumpe una sesion ajena a la prueba.' }
    $installAssets = Join-Path $env:ProgramData 'AlienGamerMode\App\assets'
    New-Item -ItemType Directory -Path $installAssets -Force | Out-Null
    $hostPath = Join-Path $installAssets 'AlienGamerSensorHost.exe'
    Copy-Item -LiteralPath (Join-Path $root 'assets\AlienGamerSensorHost.exe') -Destination $hostPath -Force
    # Use precisely the same task construction as the real installer.
    $installer = Get-Content (Join-Path $root 'installer\Install-AlienGamerMode.ps1') -Raw
    $block = [regex]::Match($installer,'(?s)        \$powershell = .*?(?=        \[void\]\$taskFolder.RegisterTaskDefinition)')
    if (-not $block.Success) { throw 'No se encontro la definicion real de la tarea.' }
    $installRoot = Join-Path $env:ProgramData 'AlienGamerMode\App'
    $hwinfoPath = Join-Path $env:ProgramFiles 'HWiNFO64\HWiNFO64.exe'
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $setup = & ([scriptblock]::Create($block.Value+"`nreturn @(`$taskFolder,`$taskDefinition)"))
    [void]$setup[0].RegisterTaskDefinition($taskName,$setup[1],6,$null,$null,3,$null)
    $registered=$true
    Start-ScheduledTask -TaskName $taskName
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    do { Start-Sleep -Milliseconds 250; $sensor=Get-Process HWiNFO64 -ErrorAction SilentlyContinue } while (-not $sensor -and [DateTime]::UtcNow -lt $deadline)
    if (-not $sensor) { throw ('No inicio HWiNFO: 0x{0:X8}' -f (Get-ScheduledTaskInfo $taskName).LastTaskResult) }
    $result.started=$true
    $deadline=[DateTime]::UtcNow.AddSeconds(25)
    do {
        try {
            $map=[IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting('Global\HWiNFO_SENS_SM2',[IO.MemoryMappedFiles.MemoryMappedFileRights]::Read)
            $map.Dispose(); $result.sharedMemory=$true
        } catch { Start-Sleep -Milliseconds 300 }
    } while (-not $result.sharedMemory -and [DateTime]::UtcNow -lt $deadline)
    if (-not $result.sharedMemory) { throw 'No se publico memoria compartida de sensores.' }
    $result.signal=$signal
    'stop' | Set-Content -LiteralPath $signal -Encoding ASCII
    $result.signalExists=Test-Path -LiteralPath $signal
    $deadline=[DateTime]::UtcNow.AddSeconds(8)
    do { Start-Sleep -Milliseconds 200; $alive=Get-Process HWiNFO64,AlienGamerSensorHost -ErrorAction SilentlyContinue } while ($alive -and [DateTime]::UtcNow -lt $deadline)
    $result.stopped= -not [bool]$alive
    if (-not $result.stopped) { throw 'La senal de cierre no termino sensores y host.' }
    $result.taskExit=(Get-ScheduledTaskInfo $taskName).LastTaskResult
    $result.passed=($result.taskExit -eq 0)
} catch { $result.error=$_.Exception.ToString() }
finally {
    if ($registered) {
        'stop' | Set-Content -LiteralPath $signal -Encoding ASCII
        Start-Sleep -Milliseconds 2000
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($sensor) { $sensor | Stop-Process -Force -ErrorAction SilentlyContinue }
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $signal -Force -ErrorAction SilentlyContinue
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
}
