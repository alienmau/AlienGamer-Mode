param([switch]$Activate)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$appRoot = $PSScriptRoot
$dataRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
$configPath = Join-Path $dataRoot 'AlienGamerMode.json'
$statePath = Join-Path $dataRoot 'agent-state.json'
$logPath = Join-Path $dataRoot 'agent.log'
$profilePath = Join-Path $dataRoot 'profile.json'
$discoveryPath = Join-Path $dataRoot 'discovery.json'
$generatedSkin = Join-Path $dataRoot 'GeneratedSkin\AlienGamerMode'
$hwinfoStopSignal = Join-Path $dataRoot 'stop-hwinfo.signal'
$recordingStatePath = Join-Path $dataRoot 'recording-state.json'
$iconPath = Join-Path $appRoot 'assets\AlienGamerMode.ico'
$rainmeter = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
$hwinfo = "$env:ProgramFiles\HWiNFO64\HWiNFO64.exe"
$createdEvent = $false
$createdNew = $false
$activateEvent = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset, 'Local\AlienGamerMode.Activate', [ref]$createdEvent)
$stopEvent = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset, 'Local\AlienGamerMode.Stop')
$mutex = [Threading.Mutex]::new($true, 'Local\AlienGamerMode.Agent', [ref]$createdNew)
if (-not $createdNew) {
    if ($Activate) { [void]$activateEvent.Set() }
    $activateEvent.Dispose()
    $stopEvent.Dispose()
    exit 0
}
if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null }

function Write-AgentLog([string]$Message) {
    "$(Get-Date -Format o) $Message" | Add-Content -LiteralPath $logPath -Encoding UTF8
}

function Read-AgentState {
    if (-not (Test-Path $statePath)) { return [pscustomobject]@{} }
    try { return Get-Content $statePath -Raw | ConvertFrom-Json } catch { return [pscustomobject]@{} }
}

function Save-AgentState($State) { $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8 }

function Wait-SharedMemory([int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $map = $null
        try {
            $map = [IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting('Global\HWiNFO_SENS_SM2', [IO.MemoryMappedFiles.MemoryMappedFileRights]::Read)
            return $true
        } catch { Start-Sleep -Milliseconds 300 } finally { if ($map) { $map.Dispose() } }
    }
    return $false
}

function Stop-Bridge {
    $pidFile = Join-Path $dataRoot 'bridge.pid'
    if (Test-Path $pidFile) {
        try { Stop-Process -Id ([int](Get-Content $pidFile -Raw)) -Force -ErrorAction SilentlyContinue } catch { }
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }
}

function Stop-OwnedHWiNFOTask {
    'stop' | Set-Content -LiteralPath $hwinfoStopSignal -Encoding ASCII
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((Get-Process HWiNFO64 -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 250 }
    Stop-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $hwinfoStopSignal -Force -ErrorAction SilentlyContinue
}

function Get-SkinsPath {
    $ini = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
    if (Test-Path $ini) {
        $line = Get-Content $ini | Where-Object { $_ -like 'SkinPath=*' } | Select-Object -First 1
        if ($line) { return $line.Substring(9).TrimEnd('\') }
    }
    return Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
}

function Test-MonitorActive {
    $bridgePidPath = Join-Path $dataRoot 'bridge.pid'
    if (-not (Test-Path -LiteralPath $bridgePidPath)) { return $false }
    try {
        $bridgePid = [int](Get-Content -LiteralPath $bridgePidPath -Raw)
        return $null -ne (Get-Process -Id $bridgePid -ErrorAction SilentlyContinue)
    } catch { return $false }
}

function Get-RecordingStatus {
    if (-not (Test-Path -LiteralPath $recordingStatePath)) { return 'inactive' }
    try {
        $recordingState = Get-Content -LiteralPath $recordingStatePath -Raw | ConvertFrom-Json
        if (-not $recordingState.WorkerPid -or -not (Get-Process -Id ([int]$recordingState.WorkerPid) -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $recordingStatePath -Force -ErrorAction SilentlyContinue
            return 'inactive'
        }
        if ($recordingState.Status -eq 'finalizing') { return 'finalizing' }
        return 'recording'
    } catch { return 'inactive' }
}

function Invoke-RecordingToggle {
    $recordingStatus = Get-RecordingStatus
    if ($recordingStatus -eq 'finalizing') { return }
    if ($recordingStatus -eq 'inactive' -and -not (Test-MonitorActive)) { return }
    $port = 27843
    try { if (Test-Path $profilePath) { $port = [int](Get-Content $profilePath -Raw | ConvertFrom-Json).bridgePort } } catch { }
    $recorder = Join-Path $appRoot 'AlienGamerEventRecorder.ps1'
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$recorder`" -Toggle -BridgeUrl `"http://127.0.0.1:$port/v2/status`" -RainmeterConfig `"AlienGamerMode`""
}

function Sync-RainmeterRecordingState([string]$Status) {
    if (-not (Test-Path -LiteralPath $rainmeter) -or -not (Test-MonitorActive)) { return }
    $isRecording = $Status -eq 'recording'
    $visualState = if ($isRecording) { '1' } else { '0' }
    if ($script:lastRecordingVisual -eq $visualState) { return }
    & $rainmeter '!SetVariable' 'RecordingActive' $visualState 'AlienGamerMode'
    & $rainmeter '!SetOption' 'MeterRecordLabel' 'Text' $(if ($isRecording) { 'FINALIZAR GRABACIÓN' } else { 'GRABAR EVENTO' }) 'AlienGamerMode'
    if ($isRecording) { & $rainmeter '!ShowMeter' 'MeterRecordingDot' 'AlienGamerMode' }
    else { & $rainmeter '!HideMeter' 'MeterRecordingDot' 'AlienGamerMode' }
    & $rainmeter '!UpdateMeter' 'MeterRecordLabel' 'AlienGamerMode'
    & $rainmeter '!UpdateMeter' 'MeterRecordingDot' 'AlienGamerMode'
    & $rainmeter '!Redraw' 'AlienGamerMode'
    $script:lastRecordingVisual = $visualState
}

function Update-TrayMenuState {
    if (-not $script:monitorItem -or -not $script:recordItem) { return }
    $monitorActive = Test-MonitorActive
    $recordingStatus = Get-RecordingStatus
    Sync-RainmeterRecordingState $recordingStatus
    $script:monitorItem.Text = if ($monitorActive) { 'Detener monitor' } else { 'Activar monitor' }
    $script:monitorItem.Checked = $monitorActive
    switch ($recordingStatus) {
        'recording' {
            $script:recordItem.Text = 'Finalizar grabación'
            $script:recordItem.Checked = $true
            $script:recordItem.Enabled = $true
        }
        'finalizing' {
            $script:recordItem.Text = 'Finalizando reporte...'
            $script:recordItem.Checked = $false
            $script:recordItem.Enabled = $false
        }
        default {
            $script:recordItem.Text = 'Grabar evento'
            $script:recordItem.Checked = $false
            $script:recordItem.Enabled = $monitorActive
        }
    }
    $script:tray.Text = if ($monitorActive) { 'AlienGamer Mode - activo' } else { 'AlienGamer Mode - detenido' }
}

function Set-RainmeterSkinPosition([int]$X, [int]$Y) {
    $iniPath = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
    if (-not (Test-Path -LiteralPath $iniPath)) { return }
    $content = [IO.File]::ReadAllText($iniPath, [Text.Encoding]::Unicode)
    $sectionPattern = '(?ms)(^\[AlienGamerMode\]\r?\n)(.*?)(?=^\[|\z)'
    $match = [regex]::Match($content, $sectionPattern)
    if (-not $match.Success) { return }
    $body = $match.Groups[2].Value
    $body = [regex]::Replace($body, '(?m)^=\r?\n?', '')
    foreach ($entry in ([ordered]@{ WindowX=$X; WindowY=$Y; AnchorX=0; AnchorY=0; KeepOnScreen=0 }).GetEnumerator()) {
        $keyPattern = '(?m)^' + [regex]::Escape([string]$entry.Key) + '=.*$'
        $line = '{0}={1}' -f $entry.Key, $entry.Value
        if ($body -match $keyPattern) { $body = [regex]::Replace($body, $keyPattern, $line, 1) }
        else { $body = $body.TrimEnd("`r","`n") + "`r`n$line`r`n" }
    }
    $updated = $content.Substring(0, $match.Index) + $match.Groups[1].Value + $body + $content.Substring($match.Index + $match.Length)
    [IO.File]::WriteAllText($iniPath, $updated, [Text.Encoding]::Unicode)
}

function Show-Loading([string]$Text) {
    $form = New-Object Windows.Forms.Form
    $form.Text = 'AlienGamer Mode'
    $form.FormBorderStyle = 'FixedDialog'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object Drawing.Size(430,135)
    $form.TopMost = $true
    $form.ControlBox = $false
    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.AutoSize = $false
    $label.TextAlign = 'MiddleCenter'
    $label.Dock = 'Fill'
    $label.Font = New-Object Drawing.Font('Segoe UI',11)
    $form.Controls.Add($label)
    $form.Show()
    $form.Refresh()
    return $form
}

function Start-Monitor {
    if ($script:starting) { return }
    if (Test-MonitorActive) { Update-TrayMenuState; return }
    $script:starting = $true
    $loading = Show-Loading 'Preparando sensores y adaptando el monitor...'
    $ownedHWiNFO = $false
    $ownedHWiNFOTask = $false
    $ownedRainmeter = $false
    try {
        if (-not (Test-Path $configPath)) { throw 'Falta AlienGamerMode.json. Ejecuta primero el instalador oficial.' }
        if (-not (Test-Path $hwinfo)) { throw 'HWiNFO64 no está instalado.' }
        if (-not (Test-Path $rainmeter)) { throw 'Rainmeter no está instalado.' }
        if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) {
            if (Get-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue) {
                Remove-Item -LiteralPath $hwinfoStopSignal -Force -ErrorAction SilentlyContinue
                Start-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO'
                $ownedHWiNFOTask = $true
            } else {
                Start-Process -FilePath $hwinfo -WindowStyle Minimized | Out-Null
            }
            $ownedHWiNFO = $true
        }
        if (-not (Wait-SharedMemory 30)) { throw 'HWiNFO no publicó la memoria compartida. Activa Shared Memory Support en sus ajustes.' }

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $appRoot 'Discover-AlienGamerHardware.ps1') -OutputPath $discoveryPath | Out-Null
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $appRoot 'Resolve-AlienGamerProfile.ps1') -DiscoveryPath $discoveryPath -ConfigPath $configPath -OutputPath $profilePath | Out-Null
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $appRoot 'Build-AdaptiveSkin.ps1') -ProfilePath $profilePath -TemplatePath (Join-Path $appRoot 'skin\AlienGamerMode.Template.ini') -OutputDirectory $generatedSkin -InstallRoot $appRoot | Out-Null

        $profile = Get-Content $profilePath -Raw | ConvertFrom-Json
        if (-not $profile.validation) { throw 'El perfil de sensores no contiene una validación previa.' }
        if (@($profile.validation.issues).Count) { Write-AgentLog ('Sensores descartados por validación: ' + (@($profile.validation.issues) -join '; ')) }
        $skinTarget = Join-Path (Get-SkinsPath) 'AlienGamerMode'
        if (-not (Test-Path $skinTarget)) { New-Item -ItemType Directory -Path $skinTarget -Force | Out-Null }
        Copy-Item -Path (Join-Path $generatedSkin '*') -Destination $skinTarget -Recurse -Force

        Stop-Bridge
        $bridgeArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $appRoot 'AlienGamerBridge.ps1')`" -ProfilePath `"$profilePath`" -StateDirectory `"$dataRoot`""
        Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList $bridgeArgs | Out-Null
        $deadline = [DateTime]::UtcNow.AddSeconds(8)
        do {
            try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:$($profile.bridgePort)/health" -TimeoutSec 1 } catch { $health = $null }
            if ($health.ok) { break }
            Start-Sleep -Milliseconds 250
        } while ([DateTime]::UtcNow -lt $deadline)
        if (-not $health.ok) { throw 'El puente AlienGamer no respondió.' }

        Set-RainmeterSkinPosition -X ([int]$profile.monitor.x) -Y ([int]$profile.monitor.y)
        if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath $rainmeter | Out-Null
            $ownedRainmeter = $true
            Start-Sleep -Seconds 2
        }
        foreach ($name in @('illustro\Clock','illustro\Disk','illustro\System','illustro\Welcome','HWiNFO')) { & $rainmeter '!DeactivateConfig' $name }
        & $rainmeter '!ActivateConfig' 'AlienGamerMode' 'AlienGamerMode.ini'
        Start-Sleep -Milliseconds 900
        & $rainmeter '!Move' ([string][int]$profile.monitor.x) ([string][int]$profile.monitor.y) 'AlienGamerMode'
        & $rainmeter '!Refresh' 'AlienGamerMode'
        $script:lastRecordingVisual = $null
        Start-Sleep -Milliseconds 350
        & $rainmeter '!Move' ([string][int]$profile.monitor.x) ([string][int]$profile.monitor.y) 'AlienGamerMode'
        Save-AgentState ([ordered]@{ active=$true; ownedHWiNFO=$ownedHWiNFO; ownedHWiNFOTask=$ownedHWiNFOTask; ownedRainmeter=$ownedRainmeter; activatedAt=(Get-Date).ToString('o') })
        Write-AgentLog "Monitor activado; $(@($profile.cores).Count) procesadores lógicos monitorizados."
        $script:tray.Text = 'AlienGamer Mode - activo'
        Update-TrayMenuState
        $script:tray.ShowBalloonTip(2500, 'AlienGamer Mode', 'Monitor activado correctamente.', [Windows.Forms.ToolTipIcon]::Info)
    } catch {
        Write-AgentLog "ERROR: $($_.Exception.Message)"
        Stop-Bridge
        if ($ownedHWiNFOTask) {
            Stop-OwnedHWiNFOTask
        }
        elseif ($ownedHWiNFO) { Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue }
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AlienGamer Mode', 'OK', 'Error') | Out-Null
    } finally { $loading.Close(); $loading.Dispose(); $script:starting = $false }
}

function Stop-Monitor {
    $state = Read-AgentState
    if ((Get-RecordingStatus) -eq 'recording') {
        Invoke-RecordingToggle
        Start-Sleep -Milliseconds 250
    }
    if (Test-Path $rainmeter) { & $rainmeter '!DeactivateConfig' 'AlienGamerMode' }
    Stop-Bridge
    $sensorTask = Get-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue
    if ($state.ownedHWiNFOTask -or ($sensorTask -and $sensorTask.State -eq 'Running')) {
        Stop-OwnedHWiNFOTask
    }
    elseif ($state.ownedHWiNFO) { Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue }
    if ($state.ownedRainmeter) { Stop-Process -Name Rainmeter -Force -ErrorAction SilentlyContinue }
    Save-AgentState ([ordered]@{active=$false; stoppedAt=(Get-Date).ToString('o')})
    $script:tray.Text = 'AlienGamer Mode - detenido'
    Write-AgentLog 'Monitor detenido.'
    Update-TrayMenuState
}

$menu = New-Object Windows.Forms.ContextMenuStrip
$monitorItem = $menu.Items.Add('Activar monitor')
$recordItem = $menu.Items.Add('Grabar evento')
[void]$menu.Items.Add('-')
$configItem = $menu.Items.Add('Configuración avanzada')
$logsItem = $menu.Items.Add('Abrir registros y reportes')
[void]$menu.Items.Add('-')
$exitItem = $menu.Items.Add('Cerrar AlienGamer Mode')

$tray = New-Object Windows.Forms.NotifyIcon
$script:tray = $tray
$script:monitorItem = $monitorItem
$script:recordItem = $recordItem
$tray.Icon = New-Object Drawing.Icon($iconPath)
$tray.Text = 'AlienGamer Mode'
$tray.ContextMenuStrip = $menu
$tray.Visible = $true
$monitorItem.Add_Click({ if (Test-MonitorActive) { Stop-Monitor } else { Start-Monitor } })
$tray.Add_DoubleClick({ if (Test-MonitorActive) { Stop-Monitor } else { Start-Monitor } })
$recordItem.Add_Click({ Invoke-RecordingToggle })
$configItem.Add_Click({ Start-Process notepad.exe -ArgumentList "`"$configPath`"" })
$logsItem.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$dataRoot`"" })
$exitItem.Add_Click({ Stop-Monitor; $tray.Visible=$false; [Windows.Forms.Application]::Exit() })

$eventTimer = New-Object Windows.Forms.Timer
$eventTimer.Interval = 500
$eventTimer.Add_Tick({
    if ($activateEvent.WaitOne(0)) { Start-Monitor }
    if ($stopEvent.WaitOne(0)) { Stop-Monitor }
    Update-TrayMenuState
})
$eventTimer.Start()
Update-TrayMenuState
if ($Activate) { $timer = New-Object Windows.Forms.Timer; $timer.Interval=400; $timer.Add_Tick({$timer.Stop(); Start-Monitor}); $timer.Start() }
[Windows.Forms.Application]::Run()
$tray.Dispose()
$activateEvent.Dispose()
$stopEvent.Dispose()
$mutex.ReleaseMutex()
$mutex.Dispose()
