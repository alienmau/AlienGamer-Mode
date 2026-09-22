param([switch]$Activate,[switch]$OpenLayoutEditor)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.Localization.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.MultiDisplay.psm1') -Force

$appRoot = $PSScriptRoot
$dataRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
$configPath = Join-Path $dataRoot 'AlienGamerMode.json'
$statePath = Join-Path $dataRoot 'agent-state.json'
$logPath = Join-Path $dataRoot 'agent.log'
$profilePath = Join-Path $dataRoot 'profile.json'
$discoveryPath = Join-Path $dataRoot 'discovery.json'
$generatedSkin = Join-Path $dataRoot 'GeneratedSkin\AlienGamerMode'
$profilesDirectory = Join-Path $dataRoot 'DisplayProfiles'
$displayManifestPath = Join-Path $dataRoot 'display-manifest.json'
$hwinfoStopSignal = Join-Path $dataRoot 'stop-hwinfo.signal'
$stopRequestPath = Join-Path $dataRoot 'stop-monitor.request.json'
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

function Write-AgentDiagnostic([string]$Message) {
    try {
        $path=Join-Path $dataRoot 'agent-diagnostic.log'
        $line=(Get-Date).ToString('o')+' '+$Message+"`r`n"
        [IO.File]::AppendAllText($path,$line,(New-Object Text.UTF8Encoding($false)))
    } catch { }
}

function Set-AgentConfigProperty($Object,[string]$Name,$Value) {
    if($Object.PSObject.Properties[$Name]){$Object.$Name=$Value}else{$Object|Add-Member NoteProperty $Name $Value}
}

function Initialize-MultiDisplayConfiguration {
    if(-not(Test-Path -LiteralPath $configPath)){return}
    try{
        $config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
        $schema=if($config.PSObject.Properties['schemaVersion']){[int]$config.schemaVersion}else{1}
        if($schema -ge 3 -and $config.PSObject.Properties['displayViews'] -and @($config.displayViews).Count){return}
        $monitorDevice=if($config.display -and $config.display.PSObject.Properties['targetMonitor']){[string]$config.display.targetMonitor}else{'auto'}
        $monitorId=if($config.display -and $config.display.PSObject.Properties['targetMonitorId']){[string]$config.display.targetMonitorId}else{'auto'}
        $view=New-AGDisplayView -Id 'principal' -Name 'AlienGamer Mode' -MonitorId $monitorId -MonitorDeviceName $monitorDevice -Preset 'full-horizontal' -Enabled $true
        if($config.appearance -and $config.appearance.backgroundEffect){
            $effect=$config.appearance.backgroundEffect
            if($effect.PSObject.Properties['enabled']){$view.background.enabled=[bool]$effect.enabled}
            if($effect.PSObject.Properties['mode'] -and [string]$effect.mode -in @('manual','thermal')){$view.background.mode=[string]$effect.mode}
        }
        Set-AgentConfigProperty $config 'displayViews' @($view)
        Set-AgentConfigProperty $config 'schemaVersion' 3
        if(-not $config.features){Set-AgentConfigProperty $config 'features' ([pscustomobject]@{})}
        Set-AgentConfigProperty $config.features 'processorPanelVisible' $true
        Set-AgentConfigProperty $config.features 'performancePanelVisible' $true
        Set-AgentConfigProperty $config.features 'clock' $true
        Set-AgentConfigProperty $config.features 'compactOverlay' $false
        $config|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $configPath -Encoding UTF8
        Write-AgentLog "Configuración visual migrada del esquema $schema al esquema multidisplay 3 con valores limpios."
    }catch{
        Write-AgentLog "No se pudo migrar la configuración multidisplay: $($_.Exception.Message)"
    }
}

Initialize-MultiDisplayConfiguration

function Read-AgentState {
    if (-not (Test-Path $statePath)) { return [pscustomobject]@{} }
    try { return Get-Content $statePath -Raw | ConvertFrom-Json } catch { return [pscustomobject]@{} }
}

function Save-AgentState($State) { $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8 }

function Get-ConfiguredLanguage {
    try {
        if (Test-Path -LiteralPath $configPath) {
            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            return Resolve-AGLanguage ([string]$config.language)
        }
    } catch { }
    return 'es-MX'
}

$script:language = Get-ConfiguredLanguage
$script:ui = Get-AGTranslations -Language $script:language
$script:lastPositionCheck = [DateTime]::MinValue
function T([string]$Path) { return Get-AGText -Translations $script:ui -Path $Path }

function Test-StopRequest {
    if (-not (Test-Path -LiteralPath $stopRequestPath)) { return $false }
    try {
        $request = Get-Content -LiteralPath $stopRequestPath -Raw | ConvertFrom-Json
        $requestedAt = [DateTime]::Parse([string]$request.requestedAtUtc).ToUniversalTime()
        if (([DateTime]::UtcNow - $requestedAt).TotalSeconds -le 90) { return $true }
        Remove-Item -LiteralPath $stopRequestPath -Force -ErrorAction SilentlyContinue
    } catch {
        Remove-Item -LiteralPath $stopRequestPath -Force -ErrorAction SilentlyContinue
    }
    return $false
}

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

function Get-DisplayManifest {
    if(-not(Test-Path -LiteralPath $displayManifestPath)){return @()}
    try{return @(Get-Content -LiteralPath $displayManifestPath -Raw|ConvertFrom-Json)}catch{return @()}
}

function Get-ActiveRainmeterConfigs {
    $configs=@(Get-DisplayManifest|ForEach-Object{[string]$_.configName}|Where-Object{$_})
    if(-not $configs.Count){$configs=@('AlienGamerMode')}
    $configs
}

function Invoke-BuildDisplaySkins([switch]$ReuseValidatedProfile) {
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $appRoot 'Build-MultiDisplaySkins.ps1'),'-DiscoveryPath',$discoveryPath,'-ConfigPath',$configPath,'-ProfilesDirectory',$profilesDirectory,'-OutputDirectory',$generatedSkin,'-PrimaryProfilePath',$profilePath,'-InstallRoot',$appRoot)
    if($ReuseValidatedProfile){$arguments+='-ReuseValidatedProfile'}
    & powershell.exe @arguments | Out-Null
    if($LASTEXITCODE-ne 0){throw "Build-MultiDisplaySkins termino con codigo $LASTEXITCODE."}
}

function Install-GeneratedSkins {
    $skinTarget=Join-Path (Get-SkinsPath) 'AlienGamerMode'
    if(-not(Test-Path -LiteralPath $skinTarget)){New-Item -ItemType Directory -Path $skinTarget -Force|Out-Null}
    $targetViews=Join-Path $skinTarget 'Views'
    if(Test-Path -LiteralPath $targetViews){Remove-Item -LiteralPath $targetViews -Recurse -Force}
    Copy-Item -Path (Join-Path $generatedSkin '*') -Destination $skinTarget -Recurse -Force
}

function Activate-DisplaySkins {
    foreach($view in @(Get-DisplayManifest)){
        & $rainmeter '!ActivateConfig' ([string]$view.configName) ([string]$view.ini)
        Start-Sleep -Milliseconds 120
        & $rainmeter '!Move' ([string][int]$view.monitor.x) ([string][int]$view.monitor.y) ([string]$view.configName)
    }
}

function Deactivate-DisplaySkins {
    foreach($configName in @(Get-ActiveRainmeterConfigs)){& $rainmeter '!DeactivateConfig' $configName}
    & $rainmeter '!DeactivateConfig' 'AlienGamerMode'
}

function Refresh-DisplaySkins([switch]$ReuseValidatedProfile) {
    $wasActive=Test-MonitorActive
    $oldConfigs=@(Get-ActiveRainmeterConfigs)
    Write-AgentDiagnostic 'APPLY stage=build begin'
    Remove-Item -LiteralPath $displayManifestPath -Force -ErrorAction SilentlyContinue
    Invoke-BuildDisplaySkins -ReuseValidatedProfile:$ReuseValidatedProfile
    if(-not(Test-Path -LiteralPath $displayManifestPath)){throw 'La reconstruccion no genero el manifiesto de pantallas.'}
    Write-AgentDiagnostic 'APPLY stage=build complete'
    if($wasActive -and (Test-Path -LiteralPath $rainmeter)){
        Write-AgentDiagnostic 'APPLY stage=deactivate begin'
        foreach($name in $oldConfigs){& $rainmeter '!DeactivateConfig' $name}
        Write-AgentDiagnostic 'APPLY stage=install begin'
        Install-GeneratedSkins
        Write-AgentDiagnostic 'APPLY stage=activate begin'
        Activate-DisplaySkins
        $script:lastRecordingVisual=$null
        Write-AgentDiagnostic 'APPLY stage=activate complete'
    }
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
    $rainmeterConfig = @(Get-ActiveRainmeterConfigs)[0]
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$recorder`" -Toggle -BridgeUrl `"http://127.0.0.1:$port/v2/status`" -RainmeterConfig `"$rainmeterConfig`""
}

function Invoke-RecorderCommand([string]$Command) {
    $port=27843;try{if(Test-Path $profilePath){$port=[int](Get-Content $profilePath -Raw|ConvertFrom-Json).bridgePort}}catch{}
    $recorder=Join-Path $appRoot 'AlienGamerEventRecorder.ps1'
    $rainmeterConfig = @(Get-ActiveRainmeterConfigs)[0]
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$recorder`" $Command -BridgeUrl `"http://127.0.0.1:$port/v2/status`" -RainmeterConfig `"$rainmeterConfig`"" | Out-Null
}

function Mark-Incident { if((Get-RecordingStatus)-eq 'recording'){Invoke-RecorderCommand '-MarkIncident'} }

function Sync-RainmeterRecordingState([string]$Status) {
    if (-not (Test-Path -LiteralPath $rainmeter) -or -not (Test-MonitorActive)) { return }
    $isRecording = $Status -eq 'recording'
    $visualState = if ($isRecording) { '1' } else { '0' }
    if ($script:lastRecordingVisual -eq $visualState) { return }
    foreach($rainmeterConfig in @(Get-ActiveRainmeterConfigs)){
        & $rainmeter '!SetVariable' 'RecordingActive' $visualState $rainmeterConfig
        & $rainmeter '!SetOption' 'MeterRecordLabel' 'Text' $(if ($isRecording) { T 'skin.finishRecording' } else { T 'skin.recordEvent' }) $rainmeterConfig
        if ($isRecording) { & $rainmeter '!ShowMeter' 'MeterRecordingDot' $rainmeterConfig }
        else { & $rainmeter '!HideMeter' 'MeterRecordingDot' $rainmeterConfig }
        & $rainmeter '!UpdateMeter' 'MeterRecordLabel' $rainmeterConfig
        & $rainmeter '!UpdateMeter' 'MeterRecordingDot' $rainmeterConfig
        & $rainmeter '!Redraw' $rainmeterConfig
    }
    $script:lastRecordingVisual = $visualState
}

function Show-HardwareSettings {
    $temporaryDiscovery = Join-Path $dataRoot 'hardware-settings.discovery.json'
    $form = $null
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $appRoot 'Discover-AlienGamerHardware.ps1') -OutputPath $temporaryDiscovery -AllowMissingHWiNFO | Out-Null
        $discovery = Get-Content -LiteralPath $temporaryDiscovery -Raw | ConvertFrom-Json
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $monitors = @($discovery.monitors)
        $gpus = @($discovery.gpus)
        $storage = @($discovery.storage)
        if (-not $monitors.Count) { throw (T 'dialog.noMonitors') }

        $form = New-Object Windows.Forms.Form
        $form.Text = T 'dialog.hardwareTitle'
        $form.FormBorderStyle = 'FixedDialog'; $form.StartPosition = 'CenterScreen'
        $form.ClientSize = New-Object Drawing.Size(650,345); $form.MaximizeBox=$false; $form.MinimizeBox=$false; $form.TopMost=$true

        $monitorLabel=New-Object Windows.Forms.Label; $monitorLabel.Text=T 'installer.monitor'; $monitorLabel.SetBounds(24,22,600,22); $form.Controls.Add($monitorLabel)
        $monitorBox=New-Object Windows.Forms.ComboBox; $monitorBox.DropDownStyle='DropDownList'; $monitorBox.SetBounds(24,47,602,29)
        foreach($monitor in $monitors){[void]$monitorBox.Items.Add("$($monitor.friendlyName) · $($monitor.deviceName) · $($monitor.width)x$($monitor.height) · $(if($monitor.primary){T 'installer.primary'}else{T 'installer.secondary'})")}
        $monitorIndex=0
        for($i=0;$i -lt $monitors.Count;$i++){
            if (($config.display.targetMonitorId -and $config.display.targetMonitorId -ne 'auto' -and $monitors[$i].pnpDeviceId -eq $config.display.targetMonitorId) -or
                ($config.display.targetMonitor -and $monitors[$i].deviceName -eq $config.display.targetMonitor)) { $monitorIndex=$i; break }
        }
        $monitorBox.SelectedIndex=$monitorIndex; $form.Controls.Add($monitorBox)

        $gpuLabel=New-Object Windows.Forms.Label; $gpuLabel.Text=T 'installer.gpu'; $gpuLabel.SetBounds(24,94,600,22); $form.Controls.Add($gpuLabel)
        $gpuBox=New-Object Windows.Forms.ComboBox; $gpuBox.DropDownStyle='DropDownList'; $gpuBox.SetBounds(24,119,602,29)
        foreach($gpu in $gpus){[void]$gpuBox.Items.Add($gpu.name)}
        if($gpuBox.Items.Count){$gpuBox.SelectedIndex=0;for($i=0;$i -lt $gpus.Count;$i++){if($gpus[$i].name -eq $config.hardware.preferredGpu){$gpuBox.SelectedIndex=$i;break}}}; $form.Controls.Add($gpuBox)

        $storageLabel=New-Object Windows.Forms.Label; $storageLabel.Text=T 'installer.storage'; $storageLabel.SetBounds(24,166,600,22); $form.Controls.Add($storageLabel)
        $storageBox=New-Object Windows.Forms.ComboBox; $storageBox.DropDownStyle='DropDownList'; $storageBox.SetBounds(24,191,602,29)
        foreach($drive in $storage){[void]$storageBox.Items.Add("$($drive.friendlyName) · $($drive.busType) · $([Math]::Round($drive.sizeBytes/1GB)) GB")}
        if($storageBox.Items.Count){$storageBox.SelectedIndex=0;for($i=0;$i -lt $storage.Count;$i++){if($storage[$i].friendlyName -eq $config.hardware.preferredStorage){$storageBox.SelectedIndex=$i;break}}}; $form.Controls.Add($storageBox)

        $note=New-Object Windows.Forms.Label; $note.Text=T 'dialog.hardwareNote'; $note.ForeColor=[Drawing.Color]::DimGray; $note.SetBounds(24,235,602,42); $form.Controls.Add($note)
        $apply=New-Object Windows.Forms.Button; $apply.Text=T 'dialog.apply'; $apply.DialogResult='OK'; $apply.SetBounds(440,292,88,32); $form.Controls.Add($apply)
        $cancel=New-Object Windows.Forms.Button; $cancel.Text=T 'dialog.cancel'; $cancel.DialogResult='Cancel'; $cancel.SetBounds(538,292,88,32); $form.Controls.Add($cancel)
        $form.AcceptButton=$apply; $form.CancelButton=$cancel
        if($form.ShowDialog() -ne 'OK'){return}

        $selectedMonitor=$monitors[$monitorBox.SelectedIndex]
        $config.display.targetMonitor=[string]$selectedMonitor.deviceName
        if($config.display.PSObject.Properties['targetMonitorId']){$config.display.targetMonitorId=[string]$selectedMonitor.pnpDeviceId}else{$config.display|Add-Member NoteProperty targetMonitorId ([string]$selectedMonitor.pnpDeviceId)}
        if($config.PSObject.Properties['displayViews'] -and @($config.displayViews).Count){
            $firstView=@($config.displayViews|Where-Object enabled|Select-Object -First 1)[0]
            if($firstView){$firstView.monitorId=[string]$selectedMonitor.pnpDeviceId;$firstView.monitorDeviceName=[string]$selectedMonitor.deviceName;$firstView.name=[string]$selectedMonitor.friendlyName}
        }
        if($gpuBox.SelectedIndex -ge 0){$config.hardware.preferredGpu=[string]$gpus[$gpuBox.SelectedIndex].name}
        if($storageBox.SelectedIndex -ge 0){$config.hardware.preferredStorage=[string]$storage[$storageBox.SelectedIndex].friendlyName}
        $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $wasActive=Test-MonitorActive
        if($wasActive){
            Stop-Monitor
            Start-Monitor
        }
        Write-AgentLog ('Hardware actualizado: monitor={0}; id={1}; GPU={2}; unidad={3}.' -f $config.display.targetMonitor,$config.display.targetMonitorId,$config.hardware.preferredGpu,$config.hardware.preferredStorage)
        $script:tray.ShowBalloonTip(2500,'AlienGamer Mode',(T 'dialog.hardwareApplied'),[Windows.Forms.ToolTipIcon]::Info)
    } catch {
        Write-AgentLog "No se pudo cambiar la configuración del equipo: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'AlienGamer Mode','OK','Error') | Out-Null
    } finally {
        if($form){$form.Dispose()}
        Remove-Item -LiteralPath $temporaryDiscovery -Force -ErrorAction SilentlyContinue
    }
}

function Show-DisplayLayoutEditor {
    try{
        if($script:layoutEditorProcess -and -not $script:layoutEditorProcess.HasExited){
            $script:tray.ShowBalloonTip(2200,'AlienGamer Mode',$(if($script:language-eq'en-US'){'The display editor is already open.'}else{'El editor de pantallas ya está abierto.'}),[Windows.Forms.ToolTipIcon]::Info)
            return
        }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $appRoot 'Discover-AlienGamerHardware.ps1') -OutputPath $discoveryPath -AllowMissingHWiNFO|Out-Null
        $arguments="-NoProfile -STA -ExecutionPolicy Bypass -File `"$(Join-Path $appRoot 'Show-AlienGamerLayoutEditor.ps1')`" -ConfigPath `"$configPath`" -DiscoveryPath `"$discoveryPath`" -HideConsole"
        $script:layoutEditorErrorPath=Join-Path $dataRoot 'layout-editor.error.log'
        ''|Set-Content -LiteralPath $script:layoutEditorErrorPath -Encoding UTF8
        $script:layoutEditorProcess=Start-Process powershell.exe -WindowStyle Minimized -ArgumentList $arguments -RedirectStandardError $script:layoutEditorErrorPath -PassThru
        $script:layoutEditorStartedAt=Get-Date
        $script:displayLayoutItem.Enabled=$false
        Write-AgentLog 'Editor multidisplay abierto sin bloquear la bandeja.'
    }catch{
        Write-AgentLog "No se pudo abrir el editor multidisplay: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'AlienGamer Mode','OK','Error')|Out-Null
    }
}

function Complete-DisplayLayoutEditor {
    $process=$script:layoutEditorProcess
    if($null-eq$process){return}
    $stage='inspect-process'
    try{
        if(-not $process.HasExited){
            $process.Refresh()
            # Una ventana que no logra publicarse nunca debe poder bloquear el menu.
            # La revision normal tarda menos de un segundo; se deja margen para equipos lentos.
            if($script:layoutEditorStartedAt -and ((Get-Date)-$script:layoutEditorStartedAt).TotalSeconds -gt 12 -and $process.MainWindowHandle -eq 0){
                Write-AgentLog 'El editor multidisplay no publico una ventana; se libero el menu para reintentar.'
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                [void]$process.WaitForExit(2000)
            }else{return}
        }
        $stage='read-exit-code'
        $exitCode=[int]$process.ExitCode
        $script:layoutEditorProcess=$null
        $script:layoutEditorStartedAt=$null
        if($script:displayLayoutItem){$script:displayLayoutItem.Enabled=$true}
        $stage='dispose-process'
        if($process){$process.Dispose()}
        if($exitCode -eq 0){
            $stage='refresh-display-skins'
            $applyOverlays=@()
            try{
                if(Test-MonitorActive){
                    $applyOverlays=@(Show-DisplayApplyOverlays)
                    [Windows.Forms.Application]::DoEvents()
                    Refresh-DisplaySkins -ReuseValidatedProfile
                }
            }finally{
                foreach($overlay in @($applyOverlays)){try{$overlay.Close();$overlay.Dispose()}catch{}}
            }
            Write-AgentLog 'Distribución multidisplay actualizada.'
            Write-AgentDiagnostic 'APPLY complete'
            # Una notificación no es parte crítica de la aplicación. Si el
            # icono se está recreando, no debe convertir un guardado válido en error.
            if($script:tray -is [Windows.Forms.NotifyIcon]){
                try{$script:tray.ShowBalloonTip(2500,'AlienGamer Mode',$(if($script:language-eq'en-US'){'Display layout applied.'}else{'Distribución de pantallas aplicada.'}),[Windows.Forms.ToolTipIcon]::Info)}catch{Write-AgentDiagnostic ('APPLY notification skipped: '+$_.Exception.Message)}
            }
        }elseif($exitCode -notin @(1,2)){
            $details=if($script:layoutEditorErrorPath-and(Test-Path -LiteralPath $script:layoutEditorErrorPath)){(Get-Content -LiteralPath $script:layoutEditorErrorPath -Raw).Trim()}else{''}
            if(-not $details){$details=if($script:language-eq'en-US'){'The display editor could not be opened.'}else{'No se pudo abrir el editor de pantallas.'}}
            Write-AgentLog "El editor multidisplay termino con codigo ${exitCode}: $details"
            [Windows.Forms.MessageBox]::Show($details,'AlienGamer Mode','OK','Error')|Out-Null
        }
    }catch{
        $detail=$_.Exception.ToString()
        Write-AgentDiagnostic "APPLY failed stage=${stage}: $detail"
        try{Write-AgentLog "No se pudo completar el editor multidisplay en ${stage}: $detail"}catch{}
        if($script:displayLayoutItem){$script:displayLayoutItem.Enabled=$true}
        $script:layoutEditorProcess=$null
        $script:layoutEditorStartedAt=$null
        try{$process.Dispose()}catch{}
        [Windows.Forms.MessageBox]::Show("$($_.Exception.Message)`r`n`r`nEtapa: $stage",'AlienGamer Mode','OK','Error')|Out-Null
    }
}

function Apply-AgentLanguage {
    if (-not $script:monitorItem) { return }
    $script:markIncidentItem.Text = T 'tray.markIncident'
    $script:languageItem.Text = T 'tray.language'
    $script:spanishItem.Text = T 'tray.spanish'
    $script:englishItem.Text = T 'tray.english'
    $script:hardwareConfigItem.Text = T 'tray.hardwareConfiguration'
    $script:displayLayoutItem.Text = T 'tray.displayLayout'
    $script:configItem.Text = T 'tray.advancedConfiguration'
    $script:logsItem.Text = T 'tray.openLogs'
    $script:exitItem.Text = T 'tray.closeApp'
    $script:spanishItem.Checked = $script:language -eq 'es-MX'
    $script:englishItem.Checked = $script:language -eq 'en-US'
}

function Set-AppLanguage([string]$Language) {
    $loading = $null
    try {
        $resolved = Resolve-AGLanguage $Language
        $monitorWasActive = Test-MonitorActive
        $script:language = $resolved
        $script:ui = Get-AGTranslations -Language $resolved
        if ($monitorWasActive) {
            $loading = Show-Loading (T 'dialog.waitApply')
            [Windows.Forms.Application]::DoEvents()
        }

        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if ($config.PSObject.Properties['language']) { $config.language = $resolved }
        else { $config | Add-Member NoteProperty language $resolved }
        $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8

        if ($monitorWasActive -and (Test-Path -LiteralPath $profilePath)) { Refresh-DisplaySkins -ReuseValidatedProfile }
        Apply-AgentLanguage
        Update-TrayMenuState
        Write-AgentLog "Idioma actualizado: $resolved."
    } catch {
        Write-AgentLog "No se pudo cambiar el idioma: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AlienGamer Mode', 'OK', 'Error') | Out-Null
    } finally {
        if ($loading) { $loading.Close(); $loading.Dispose() }
    }
}

function Update-TrayMenuState {
    if (-not $script:monitorItem -or -not $script:recordItem -or -not $script:markIncidentItem) { return }
    $monitorActive = Test-MonitorActive
    $recordingStatus = Get-RecordingStatus
    Sync-RainmeterRecordingState $recordingStatus
    $script:monitorItem.Text = if ($monitorActive) { T 'tray.stopMonitor' } else { T 'tray.activateMonitor' }
    $script:monitorItem.Checked = $monitorActive
    switch ($recordingStatus) {
        'recording' {
            $script:recordItem.Text = T 'tray.finishRecording'
            $script:recordItem.Checked = $true
            $script:recordItem.Enabled = $true
        }
        'finalizing' {
            $script:recordItem.Text = T 'tray.finalizingReport'
            $script:recordItem.Checked = $false
            $script:recordItem.Enabled = $false
        }
        default {
            $script:recordItem.Text = T 'tray.recordEvent'
            $script:recordItem.Checked = $false
            $script:recordItem.Enabled = $monitorActive
        }
    }
    $script:markIncidentItem.Enabled = $recordingStatus -eq 'recording'
    $script:tray.Text = if ($monitorActive) { T 'tray.active' } else { T 'tray.stopped' }
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

function Ensure-MonitorPosition {
    if (-not (Test-MonitorActive) -or -not (Test-Path -LiteralPath $displayManifestPath) -or -not (Test-Path -LiteralPath $rainmeter)) { return }
    if (((Get-Date) - $script:lastPositionCheck).TotalSeconds -lt 5) { return }
    $script:lastPositionCheck = Get-Date
    try {
        foreach($view in @(Get-DisplayManifest)){
            & $rainmeter '!Move' ([string][int]$view.monitor.x) ([string][int]$view.monitor.y) ([string]$view.configName)
        }
    } catch {
        Write-AgentLog "No se pudo reafirmar la posición del monitor: $($_.Exception.Message)"
    }
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

function Show-DisplayApplyOverlays {
    $forms=New-Object 'System.Collections.Generic.List[System.Windows.Forms.Form]'
    $targets=@(Get-DisplayManifest)
    if(-not $targets.Count){$targets=@([pscustomobject]@{monitor=[pscustomobject]@{x=[Windows.Forms.Screen]::PrimaryScreen.Bounds.X;y=[Windows.Forms.Screen]::PrimaryScreen.Bounds.Y;width=[Windows.Forms.Screen]::PrimaryScreen.Bounds.Width;height=[Windows.Forms.Screen]::PrimaryScreen.Bounds.Height}})}
    foreach($target in $targets){
        $bounds=$target.monitor
        $form=New-Object Windows.Forms.Form
        $form.FormBorderStyle='None';$form.ShowInTaskbar=$false;$form.TopMost=$true;$form.ControlBox=$false
        $form.BackColor=[Drawing.Color]::FromArgb(18,22,31)
        $width=390;$height=118
        $form.StartPosition='Manual'
        $form.Bounds=New-Object Drawing.Rectangle([int]($bounds.x+($bounds.width-$width)/2),[int]($bounds.y+($bounds.height-$height)/2),$width,$height)
        $panel=New-Object Windows.Forms.Panel;$panel.Dock='Fill';$panel.Padding=New-Object Windows.Forms.Padding(2);$panel.BackColor=[Drawing.Color]::FromArgb(80,36,120);$form.Controls.Add($panel)
        $inner=New-Object Windows.Forms.Panel;$inner.Dock='Fill';$inner.BackColor=[Drawing.Color]::FromArgb(18,22,31);$panel.Controls.Add($inner)
        $label=New-Object Windows.Forms.Label;$label.Dock='Fill';$label.TextAlign='MiddleCenter';$label.ForeColor=[Drawing.Color]::White;$label.Font=New-Object Drawing.Font('Segoe UI Semibold',13);$label.Text=(T 'dialog.applyingLayout');$inner.Controls.Add($label)
        $form.Show();$form.Refresh();$forms.Add($form)
    }
    $forms.ToArray()
}

function Start-Monitor {
    if ($script:starting) { return }
    if (Test-MonitorActive) { Update-TrayMenuState; return }
    $script:starting = $true
    $loading = Show-Loading (T 'dialog.preparing')
    $ownedHWiNFO = $false
    $ownedHWiNFOTask = $false
    $ownedRainmeter = $false
    try {
        if (-not (Test-Path $configPath)) { throw (T 'dialog.missingConfig') }
        if (-not (Test-Path $hwinfo)) { throw (T 'dialog.missingHWiNFO') }
        if (-not (Test-Path $rainmeter)) { throw (T 'dialog.missingRainmeter') }
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
        if (-not (Wait-SharedMemory 30)) { throw (T 'dialog.sharedMemory') }

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $appRoot 'Discover-AlienGamerHardware.ps1') -OutputPath $discoveryPath | Out-Null
        Invoke-BuildDisplaySkins

        $profile = Get-Content $profilePath -Raw | ConvertFrom-Json
        if (-not $profile.validation) { throw (T 'dialog.invalidProfile') }
        if (@($profile.validation.issues).Count) { Write-AgentLog ('Sensores descartados por validación: ' + (@($profile.validation.issues) -join '; ')) }
        Install-GeneratedSkins

        Stop-Bridge
        $bridgeArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $appRoot 'AlienGamerBridge.ps1')`" -ProfilePath `"$profilePath`" -StateDirectory `"$dataRoot`""
        Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList $bridgeArgs | Out-Null
        $deadline = [DateTime]::UtcNow.AddSeconds(8)
        do {
            try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:$($profile.bridgePort)/health" -TimeoutSec 1 } catch { $health = $null }
            if ($health.ok) { break }
            Start-Sleep -Milliseconds 250
        } while ([DateTime]::UtcNow -lt $deadline)
        if (-not $health.ok) { throw (T 'dialog.bridgeError') }
        Invoke-RecorderCommand '-StartBuffer'

        if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath $rainmeter | Out-Null
            $ownedRainmeter = $true
            Start-Sleep -Seconds 2
        }
        foreach ($name in @('illustro\Clock','illustro\Disk','illustro\System','illustro\Welcome','HWiNFO')) { & $rainmeter '!DeactivateConfig' $name }
        Activate-DisplaySkins
        Start-Sleep -Milliseconds 900
        $script:lastPositionCheck = Get-Date
        foreach($rainmeterConfig in @(Get-ActiveRainmeterConfigs)){& $rainmeter '!Refresh' $rainmeterConfig}
        $script:lastRecordingVisual = $null
        Start-Sleep -Milliseconds 350
        Ensure-MonitorPosition
        Save-AgentState ([ordered]@{ active=$true; ownedHWiNFO=$ownedHWiNFO; ownedHWiNFOTask=$ownedHWiNFOTask; ownedRainmeter=$ownedRainmeter; activatedAt=(Get-Date).ToString('o') })
        Write-AgentLog "Monitor activado en $(@(Get-DisplayManifest).Count) pantalla(s); $(@($profile.cores).Count) procesadores lógicos monitorizados."
        $script:tray.Text = T 'tray.active'
        Update-TrayMenuState
        $script:tray.ShowBalloonTip(2500, 'AlienGamer Mode', (T 'dialog.monitorActivated'), [Windows.Forms.ToolTipIcon]::Info)
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
    if ($script:stopping) { return }
    $script:stopping = $true
    try {
        $state = Read-AgentState
        if ((Get-RecordingStatus) -eq 'recording') {
            Invoke-RecordingToggle
            Start-Sleep -Milliseconds 250
        }
        if (Test-Path $rainmeter) { Deactivate-DisplaySkins }
        Invoke-RecorderCommand '-StopBuffer'
        Stop-Bridge
        $sensorTask = Get-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue
        if ($state.ownedHWiNFOTask -or ($sensorTask -and $sensorTask.State -eq 'Running')) {
            Stop-OwnedHWiNFOTask
        }
        elseif ($state.ownedHWiNFO) { Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue }
        # AlienGamer Mode usa Rainmeter como su proceso de presentación. OFF
        # debe cerrar el conjunto completo aun si una ejecución anterior dejó
        # el indicador de propiedad obsoleto al cerrarse su consola.
        Stop-Process -Name Rainmeter -Force -ErrorAction SilentlyContinue
        Save-AgentState ([ordered]@{active=$false; stoppedAt=(Get-Date).ToString('o')})
        $script:tray.Text = T 'tray.stopped'
        Write-AgentLog 'Monitor detenido.'
        Update-TrayMenuState
    } finally {
        # Confirma al comando de la skin que terminó el cierre coordinado.
        Remove-Item -LiteralPath $stopRequestPath -Force -ErrorAction SilentlyContinue
        $script:stopping = $false
    }
}

$menu = New-Object Windows.Forms.ContextMenuStrip
$monitorItem = $menu.Items.Add((T 'tray.activateMonitor'))
$recordItem = $menu.Items.Add((T 'tray.recordEvent'))
$markIncidentItem = $menu.Items.Add((T 'tray.markIncident'))
$languageItem = New-Object Windows.Forms.ToolStripMenuItem((T 'tray.language'))
$spanishItem = $languageItem.DropDownItems.Add((T 'tray.spanish'))
$englishItem = $languageItem.DropDownItems.Add((T 'tray.english'))
[void]$menu.Items.Add($languageItem)
[void]$menu.Items.Add('-')
$hardwareConfigItem = $menu.Items.Add((T 'tray.hardwareConfiguration'))
$displayLayoutItem = $menu.Items.Add((T 'tray.displayLayout'))
$configItem = $menu.Items.Add((T 'tray.advancedConfiguration'))
$logsItem = $menu.Items.Add((T 'tray.openLogs'))
[void]$menu.Items.Add('-')
$exitItem = $menu.Items.Add((T 'tray.closeApp'))

$tray = New-Object Windows.Forms.NotifyIcon
$script:tray = $tray
$script:monitorItem = $monitorItem
$script:recordItem = $recordItem
$script:markIncidentItem = $markIncidentItem
$script:languageItem = $languageItem
$script:spanishItem = $spanishItem
$script:englishItem = $englishItem
$script:hardwareConfigItem = $hardwareConfigItem
$script:displayLayoutItem = $displayLayoutItem
$script:configItem = $configItem
$script:logsItem = $logsItem
$script:exitItem = $exitItem
$script:layoutEditorProcess = $null
$script:layoutEditorStartedAt = $null
$script:layoutEditorErrorPath = $null
$tray.Icon = New-Object Drawing.Icon($iconPath)
$tray.Text = 'AlienGamer Mode'
$tray.ContextMenuStrip = $menu
$tray.Visible = $true
$monitorItem.Add_Click({ if (Test-MonitorActive) { Stop-Monitor } else { Start-Monitor } })
$tray.Add_DoubleClick({ if (Test-MonitorActive) { Stop-Monitor } else { Start-Monitor } })
$recordItem.Add_Click({ Invoke-RecordingToggle })
$markIncidentItem.Add_Click({ Mark-Incident })
$spanishItem.Add_Click({ Set-AppLanguage 'es-MX' })
$englishItem.Add_Click({ Set-AppLanguage 'en-US' })
$hardwareConfigItem.Add_Click({ Show-HardwareSettings; Update-TrayMenuState })
$displayLayoutItem.Add_Click({ Show-DisplayLayoutEditor; Update-TrayMenuState })
$configItem.Add_Click({ Start-Process notepad.exe -ArgumentList "`"$configPath`"" })
$logsItem.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$dataRoot`"" })
$exitItem.Add_Click({ Stop-Monitor; $tray.Visible=$false; [Windows.Forms.Application]::Exit() })

$eventTimer = New-Object Windows.Forms.Timer
$eventTimer.Interval = 500
$eventTimer.Add_Tick({
    try{
        Complete-DisplayLayoutEditor
        if ($activateEvent.WaitOne(0)) { Start-Monitor }
        if ($stopEvent.WaitOne(0) -or (Test-StopRequest)) { Stop-Monitor }
        Update-TrayMenuState
        Ensure-MonitorPosition
    }catch{
        Write-AgentLog "Error controlado en el ciclo de bandeja: $($_.Exception.ToString())"
    }
})
$eventTimer.Start()
Apply-AgentLanguage
Update-TrayMenuState
if ($Activate -or $OpenLayoutEditor) {
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval=500
    $timer.Add_Tick({
        $timer.Stop()
        if($Activate){Start-Monitor}
        if($OpenLayoutEditor){Show-DisplayLayoutEditor}
    })
    $timer.Start()
}
[Windows.Forms.Application]::Run()
$tray.Dispose()
$activateEvent.Dispose()
$stopEvent.Dispose()
$mutex.ReleaseMutex()
$mutex.Dispose()
