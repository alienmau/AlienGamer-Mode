param([switch]$Activate)

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

function Invoke-BuildDisplaySkins {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $appRoot 'Build-MultiDisplaySkins.ps1') -DiscoveryPath $discoveryPath -ConfigPath $configPath -ProfilesDirectory $profilesDirectory -OutputDirectory $generatedSkin -PrimaryProfilePath $profilePath -InstallRoot $appRoot | Out-Null
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

function Refresh-DisplaySkins {
    $wasActive=Test-MonitorActive
    $oldConfigs=@(Get-ActiveRainmeterConfigs)
    Invoke-BuildDisplaySkins
    if($wasActive -and (Test-Path -LiteralPath $rainmeter)){
        foreach($name in $oldConfigs){& $rainmeter '!DeactivateConfig' $name}
        Install-GeneratedSkins
        Activate-DisplaySkins
        $script:lastRecordingVisual=$null
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

function Get-BackgroundSettings {
    $settings = [ordered]@{ enabled=$true; mode='manual'; particleCount=26; speed=0.65; sizeScale=1.0; color='255,112,20' }
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $effect = $config.appearance.backgroundEffect
        if ($effect) {
            if ($null -ne $effect.enabled) { $settings.enabled = [bool]$effect.enabled }
            if ([string]$effect.mode -in @('manual','thermal')) { $settings.mode = [string]$effect.mode }
            if ($null -ne $effect.particleCount) { $settings.particleCount = [Math]::Max(8,[Math]::Min(48,[int]$effect.particleCount)) }
            if ($null -ne $effect.speed) { $settings.speed = [Math]::Max(0.2,[Math]::Min(1.5,[double]$effect.speed)) }
            if ($null -ne $effect.sizeScale) { $settings.sizeScale = [Math]::Max(0.7,[Math]::Min(1.6,[double]$effect.sizeScale)) }
            if ([string]$effect.color -match '^\d{1,3},\d{1,3},\d{1,3}$') { $settings.color = [string]$effect.color }
        }
    } catch { Write-AgentLog "No se pudo leer el fondo dinámico: $($_.Exception.Message)" }
    return [pscustomobject]$settings
}

function Set-BackgroundSettings($Settings) {
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if (-not $config.appearance) { $config | Add-Member NoteProperty appearance ([pscustomobject]@{}) }
        if (-not $config.appearance.backgroundEffect) { $config.appearance | Add-Member NoteProperty backgroundEffect ([pscustomobject]@{}) }
        foreach ($entry in ([ordered]@{
            enabled=[bool]$Settings.enabled
            mode=$(if ([string]$Settings.mode -eq 'thermal') { 'thermal' } else { 'manual' })
            particleCount=[int]$Settings.particleCount
            speed=[double]$Settings.speed
            sizeScale=[double]$Settings.sizeScale
            color=[string]$Settings.color
            updateFps=10
            minimumParticles=8
            maximumParticles=48
            gpuProtectionThreshold=88
            thermalMinimumParticles=8
            thermalMaximumParticles=32
            thermalBaseSpeed=0.75
            thermalSizeScale=1.0
        }).GetEnumerator()) {
            if ($config.appearance.backgroundEffect.PSObject.Properties[$entry.Key]) { $config.appearance.backgroundEffect.($entry.Key) = $entry.Value }
            else { $config.appearance.backgroundEffect | Add-Member NoteProperty $entry.Key $entry.Value }
        }
        if($config.PSObject.Properties['displayViews']){
            foreach($view in @($config.displayViews)){
                if(-not $view.background){$view|Add-Member NoteProperty background ([pscustomobject]@{})}
                if($view.background.PSObject.Properties['enabled']){$view.background.enabled=[bool]$Settings.enabled}else{$view.background|Add-Member NoteProperty enabled ([bool]$Settings.enabled)}
                if($view.background.PSObject.Properties['mode']){$view.background.mode=$(if([string]$Settings.mode-eq'thermal'){'thermal'}else{'manual'})}else{$view.background|Add-Member NoteProperty mode $(if([string]$Settings.mode-eq'thermal'){'thermal'}else{'manual'})}
            }
        }
        $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $script:backgroundSettings = $Settings
        if ((Test-Path -LiteralPath $rainmeter) -and (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
            foreach($rainmeterConfig in @(Get-ActiveRainmeterConfigs)){
                & $rainmeter '!SetVariable' 'BackgroundEffectEnabled' $(if ($Settings.enabled) { '1' } else { '0' }) $rainmeterConfig
                & $rainmeter '!SetVariable' 'BackgroundEffectMode' $(if ([string]$Settings.mode -eq 'thermal') { 'thermal' } else { 'manual' }) $rainmeterConfig
                & $rainmeter '!SetVariable' 'BackgroundParticleCount' ([string][int]$Settings.particleCount) $rainmeterConfig
                & $rainmeter '!SetVariable' 'BackgroundParticleSpeed' ([double]$Settings.speed).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture) $rainmeterConfig
                & $rainmeter '!SetVariable' 'BackgroundParticleSize' ([double]$Settings.sizeScale).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture) $rainmeterConfig
                & $rainmeter '!SetVariable' 'BackgroundParticleColor' ([string]$Settings.color) $rainmeterConfig
                & $rainmeter '!EnableMeasure' 'BackgroundScript' $rainmeterConfig
                & $rainmeter '!UpdateMeasure' 'BackgroundScript' $rainmeterConfig
                & $rainmeter '!UpdateMeterGroup' 'AmbientParticles' $rainmeterConfig
                & $rainmeter '!Redraw' $rainmeterConfig
            }
        }
        Write-AgentLog ('Fondo actualizado: activo={0}, modo={1}, partículas={2}, velocidad={3}, tamaño={4}, color={5}.' -f $Settings.enabled,$Settings.mode,$Settings.particleCount,$Settings.speed,$Settings.sizeScale,$Settings.color)
    } catch {
        Write-AgentLog "No se pudo cambiar el fondo dinámico: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show((T 'dialog.saveBackgroundError'), 'AlienGamer Mode', 'OK', 'Error') | Out-Null
    }
}

function Set-BackgroundMode([string]$Mode) {
    $settings = Get-BackgroundSettings
    switch ($Mode) {
        'off' { $settings.enabled = $false }
        'thermal' { $settings.enabled = $true; $settings.mode = 'thermal' }
        default { $settings.enabled = $true; $settings.mode = 'manual' }
    }
    Set-BackgroundSettings $settings
    Update-TrayMenuState
}

function Get-ModuleVisibilitySettings {
    $settings = [ordered]@{ processorPanelVisible=$true; performancePanelVisible=$true; clock=$true; compactOverlay=$false }
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if ($config.features) {
            if ($null -ne $config.features.processorPanelVisible) { $settings.processorPanelVisible = [bool]$config.features.processorPanelVisible }
            if ($null -ne $config.features.performancePanelVisible) { $settings.performancePanelVisible = [bool]$config.features.performancePanelVisible }
            if ($null -ne $config.features.clock) { $settings.clock = [bool]$config.features.clock }
            if ($null -ne $config.features.compactOverlay) { $settings.compactOverlay = [bool]$config.features.compactOverlay }
        }
        if($config.PSObject.Properties['displayViews'] -and @($config.displayViews).Count){
            $firstView=@($config.displayViews|Where-Object enabled|Select-Object -First 1)[0]
            if($firstView -and $firstView.modules){
                if($firstView.modules.PSObject.Properties['processors']){$settings.processorPanelVisible=[bool]$firstView.modules.processors.visible}
                if($firstView.modules.PSObject.Properties['performance']){$settings.performancePanelVisible=[bool]$firstView.modules.performance.visible}
                if($firstView.modules.PSObject.Properties['clock']){$settings.clock=[bool]$firstView.modules.clock.visible}
            }
        }
    } catch { Write-AgentLog "No se pudo leer la visibilidad de módulos: $($_.Exception.Message)" }
    return [pscustomobject]$settings
}

function Set-ModuleVisibility([string]$Name, [bool]$Visible) {
    $loading = $null
    try {
        if ($Name -notin @('processorPanelVisible','performancePanelVisible','clock','compactOverlay')) { throw 'Módulo desconocido.' }
        $monitorWasActive = Test-MonitorActive
        if ($monitorWasActive) {
            $loading = Show-Loading (T 'dialog.waitApply')
            [Windows.Forms.Application]::DoEvents()
            if (-not $Visible) {
                $group = if ($Name -eq 'processorPanelVisible') { 'ProcessorPanel' } elseif ($Name -eq 'performancePanelVisible') { 'PerformancePanel' } elseif($Name -eq 'clock') { 'ClockPanel' } else { 'CompactOnly' }
                foreach($rainmeterConfig in @(Get-ActiveRainmeterConfigs)){
                    & $rainmeter '!HideMeterGroup' $group $rainmeterConfig
                    & $rainmeter '!Redraw' $rainmeterConfig
                }
            }
        }
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if (-not $config.features) { $config | Add-Member NoteProperty features ([pscustomobject]@{}) }
        if ($config.features.PSObject.Properties[$Name]) { $config.features.$Name = $Visible }
        else { $config.features | Add-Member NoteProperty $Name $Visible }
        if($config.PSObject.Properties['displayViews'] -and @($config.displayViews).Count){
            $firstView=@($config.displayViews|Where-Object enabled|Select-Object -First 1)[0]
            if($firstView -and $firstView.modules){
                $viewModule=if($Name-eq'processorPanelVisible'){'processors'}elseif($Name-eq'performancePanelVisible'){'performance'}elseif($Name-eq'clock'){'clock'}else{$null}
                if($viewModule -and $firstView.modules.PSObject.Properties[$viewModule]){$firstView.modules.$viewModule.visible=$Visible}
            }
        }
        $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8

        if ($monitorWasActive -and (Test-Path -LiteralPath $profilePath)) { Refresh-DisplaySkins }
        Write-AgentLog ("Visibilidad de módulo actualizada: {0}={1}." -f $Name,$Visible)
    } catch {
        Write-AgentLog "No se pudo cambiar la visibilidad del módulo: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show((T 'dialog.saveVisibilityError'), 'AlienGamer Mode', 'OK', 'Error') | Out-Null
    } finally {
        if ($loading) { $loading.Close(); $loading.Dispose() }
    }
}

function Show-BackgroundSettings {
    $current = Get-BackgroundSettings
    $rgb = @([int[]]([string]$current.color -split ','))
    $selectedColor = [Drawing.Color]::FromArgb($rgb[0],$rgb[1],$rgb[2])
    $form = New-Object Windows.Forms.Form
    $form.Text = T 'dialog.backgroundTitle'
    $form.FormBorderStyle = 'FixedDialog'; $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object Drawing.Size(470,405); $form.MaximizeBox=$false; $form.MinimizeBox=$false; $form.TopMost=$true

    $enabledCheck = New-Object Windows.Forms.CheckBox
    $enabledCheck.Text=T 'dialog.enableBackground'; $enabledCheck.Checked=[bool]$current.enabled; $enabledCheck.SetBounds(28,22,220,28)
    $form.Controls.Add($enabledCheck)

    $countLabel = New-Object Windows.Forms.Label
    $countLabel.Text=T 'dialog.fireflyCount'; $countLabel.SetBounds(28,68,250,22); $form.Controls.Add($countLabel)
    $countValue = New-Object Windows.Forms.Label
    $countValue.Text=[string]$current.particleCount; $countValue.TextAlign='MiddleRight'; $countValue.SetBounds(375,68,55,22); $form.Controls.Add($countValue)
    $countBar = New-Object Windows.Forms.TrackBar
    $countBar.Minimum=8; $countBar.Maximum=48; $countBar.TickFrequency=5; $countBar.Value=[int]$current.particleCount; $countBar.SetBounds(24,91,410,45); $form.Controls.Add($countBar)
    $countBar.Add_ValueChanged({$countValue.Text=[string]$countBar.Value})

    $speedLabel = New-Object Windows.Forms.Label
    $speedLabel.Text=T 'dialog.riseSpeed'; $speedLabel.SetBounds(28,147,250,22); $form.Controls.Add($speedLabel)
    $speedValue = New-Object Windows.Forms.Label
    $speedValue.Text=([double]$current.speed).ToString('0.00'); $speedValue.TextAlign='MiddleRight'; $speedValue.SetBounds(375,147,55,22); $form.Controls.Add($speedValue)
    $speedBar = New-Object Windows.Forms.TrackBar
    $speedBar.Minimum=20; $speedBar.Maximum=150; $speedBar.TickFrequency=10; $speedBar.Value=[int]([double]$current.speed*100); $speedBar.SetBounds(24,170,410,45); $form.Controls.Add($speedBar)
    $speedBar.Add_ValueChanged({$speedValue.Text=($speedBar.Value/100.0).ToString('0.00')})

    $sizeLabel = New-Object Windows.Forms.Label
    $sizeLabel.Text=T 'dialog.generalSize'; $sizeLabel.SetBounds(28,226,250,22); $form.Controls.Add($sizeLabel)
    $sizeValue = New-Object Windows.Forms.Label
    $sizeValue.Text=([double]$current.sizeScale).ToString('0%'); $sizeValue.TextAlign='MiddleRight'; $sizeValue.SetBounds(365,226,65,22); $form.Controls.Add($sizeValue)
    $sizeBar = New-Object Windows.Forms.TrackBar
    $sizeBar.Minimum=70; $sizeBar.Maximum=160; $sizeBar.TickFrequency=10; $sizeBar.Value=[int]([double]$current.sizeScale*100); $sizeBar.SetBounds(24,249,410,45); $form.Controls.Add($sizeBar)
    $sizeBar.Add_ValueChanged({
        $sizeValue.Text=($sizeBar.Value/100.0).ToString('0%')
        if((Test-Path -LiteralPath $rainmeter) -and (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
                foreach($rainmeterConfig in @(Get-ActiveRainmeterConfigs)){& $rainmeter '!SetVariable' 'BackgroundParticleSize' ($sizeBar.Value/100.0).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture) $rainmeterConfig}
        }
    })

    $colorLabel = New-Object Windows.Forms.Label
    $colorLabel.Text=T 'dialog.fireflyColor'; $colorLabel.SetBounds(28,307,210,24); $form.Controls.Add($colorLabel)
    $colorButton = New-Object Windows.Forms.Button
    $colorButton.Text=T 'dialog.chooseColor'; $colorButton.BackColor=$selectedColor; $colorButton.ForeColor=if(($selectedColor.R+$selectedColor.G+$selectedColor.B)-gt 420){[Drawing.Color]::Black}else{[Drawing.Color]::White}; $colorButton.SetBounds(260,300,170,35); $form.Controls.Add($colorButton)
    $colorButton.Add_Click({
        $picker=New-Object Windows.Forms.ColorDialog; $picker.FullOpen=$true; $picker.Color=$script:selectedParticleColor
        if($picker.ShowDialog($form)-eq 'OK'){$script:selectedParticleColor=$picker.Color; $colorButton.BackColor=$picker.Color; $colorButton.ForeColor=if(($picker.Color.R+$picker.Color.G+$picker.Color.B)-gt 420){[Drawing.Color]::Black}else{[Drawing.Color]::White}}
        $picker.Dispose()
    })
    $script:selectedParticleColor=$selectedColor

    $saveButton=New-Object Windows.Forms.Button; $saveButton.Text=T 'dialog.apply'; $saveButton.DialogResult='OK'; $saveButton.SetBounds(250,357,85,32); $form.Controls.Add($saveButton)
    $cancelButton=New-Object Windows.Forms.Button; $cancelButton.Text=T 'dialog.cancel'; $cancelButton.DialogResult='Cancel'; $cancelButton.SetBounds(345,357,85,32); $form.Controls.Add($cancelButton)
    $form.AcceptButton=$saveButton; $form.CancelButton=$cancelButton
    $dialogResult=$form.ShowDialog()
    if($dialogResult -eq 'OK'){
        $color=$script:selectedParticleColor
        Set-BackgroundSettings ([pscustomobject]@{enabled=$enabledCheck.Checked;mode=$current.mode;particleCount=$countBar.Value;speed=$speedBar.Value/100.0;sizeScale=$sizeBar.Value/100.0;color=('{0},{1},{2}' -f $color.R,$color.G,$color.B)})
    } elseif((Test-Path -LiteralPath $rainmeter) -and (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
            foreach($rainmeterConfig in @(Get-ActiveRainmeterConfigs)){& $rainmeter '!SetVariable' 'BackgroundParticleSize' ([double]$current.sizeScale).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture) $rainmeterConfig}
    }
    $form.Dispose()
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
        $arguments="-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $appRoot 'Show-AlienGamerLayoutEditor.ps1')`" -ConfigPath `"$configPath`" -DiscoveryPath `"$discoveryPath`""
        $script:layoutEditorErrorPath=Join-Path $dataRoot 'layout-editor.error.log'
        ''|Set-Content -LiteralPath $script:layoutEditorErrorPath -Encoding UTF8
        $script:layoutEditorProcess=Start-Process powershell.exe -WindowStyle Hidden -ArgumentList $arguments -RedirectStandardError $script:layoutEditorErrorPath -PassThru
        $script:displayLayoutItem.Enabled=$false
        Write-AgentLog 'Editor multidisplay abierto sin bloquear la bandeja.'
    }catch{
        Write-AgentLog "No se pudo abrir el editor multidisplay: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'AlienGamer Mode','OK','Error')|Out-Null
    }
}

function Complete-DisplayLayoutEditor {
    if(-not $script:layoutEditorProcess -or -not $script:layoutEditorProcess.HasExited){return}
    $process=$script:layoutEditorProcess
    $script:layoutEditorProcess=$null
    $script:displayLayoutItem.Enabled=$true
    $exitCode=$process.ExitCode
    $process.Dispose()
    if($exitCode -eq 0){
        try{
            if(Test-MonitorActive){Refresh-DisplaySkins}
            Write-AgentLog 'Distribución multidisplay actualizada.'
            $script:tray.ShowBalloonTip(2500,'AlienGamer Mode',$(if($script:language-eq'en-US'){'Display layout applied.'}else{'Distribución de pantallas aplicada.'}),[Windows.Forms.ToolTipIcon]::Info)
        }catch{
            Write-AgentLog "No se pudo aplicar la distribución multidisplay: $($_.Exception.Message)"
            [Windows.Forms.MessageBox]::Show($_.Exception.Message,'AlienGamer Mode','OK','Error')|Out-Null
        }
    }elseif($exitCode -notin @(1,2)){
        $details=if(Test-Path -LiteralPath $script:layoutEditorErrorPath){(Get-Content -LiteralPath $script:layoutEditorErrorPath -Raw).Trim()}else{''}
        if(-not $details){$details=if($script:language-eq'en-US'){'The display editor could not be opened.'}else{'No se pudo abrir el editor de pantallas.'}}
        Write-AgentLog "El editor multidisplay terminó con código ${exitCode}: $details"
        [Windows.Forms.MessageBox]::Show($details,'AlienGamer Mode','OK','Error')|Out-Null
    }
}

function Apply-AgentLanguage {
    if (-not $script:monitorItem) { return }
    $script:backgroundConfigItem.Text = T 'tray.configureFireflies'
    $script:backgroundMenu.Text = T 'tray.background'
    $script:backgroundOffItem.Text = T 'tray.backgroundOff'
    $script:backgroundManualItem.Text = T 'tray.backgroundManual'
    $script:backgroundThermalItem.Text = T 'tray.backgroundThermal'
    $script:modulesItem.Text = T 'tray.visibleModules'
    $script:processorPanelItem.Text = T 'tray.processorsLoad'
    $script:performancePanelItem.Text = T 'tray.performanceAlerts'
    $script:clockItem.Text = T 'tray.clock'
    $script:compactItem.Text = T 'tray.compactOverlay'
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

        if ($monitorWasActive -and (Test-Path -LiteralPath $profilePath)) { Refresh-DisplaySkins }
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
    if (-not $script:monitorItem -or -not $script:recordItem -or -not $script:backgroundMenu -or -not $script:processorPanelItem -or -not $script:performancePanelItem -or -not $script:clockItem -or -not $script:compactItem -or -not $script:markIncidentItem) { return }
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
    $script:backgroundSettings = Get-BackgroundSettings
    $script:backgroundOffItem.Checked = -not [bool]$script:backgroundSettings.enabled
    $script:backgroundManualItem.Checked = [bool]$script:backgroundSettings.enabled -and $script:backgroundSettings.mode -eq 'manual'
    $script:backgroundThermalItem.Checked = [bool]$script:backgroundSettings.enabled -and $script:backgroundSettings.mode -eq 'thermal'
    $script:backgroundConfigItem.Enabled = [bool]$script:backgroundSettings.enabled -and $script:backgroundSettings.mode -eq 'manual'
    $moduleSettings = Get-ModuleVisibilitySettings
    $script:processorPanelItem.Checked = [bool]$moduleSettings.processorPanelVisible
    $script:performancePanelItem.Checked = [bool]$moduleSettings.performancePanelVisible
    $script:clockItem.Checked = [bool]$moduleSettings.clock
    $script:compactItem.Checked = [bool]$moduleSettings.compactOverlay
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
$backgroundMenu = New-Object Windows.Forms.ToolStripMenuItem((T 'tray.background'))
$backgroundOffItem = $backgroundMenu.DropDownItems.Add((T 'tray.backgroundOff'))
$backgroundManualItem = $backgroundMenu.DropDownItems.Add((T 'tray.backgroundManual'))
$backgroundThermalItem = $backgroundMenu.DropDownItems.Add((T 'tray.backgroundThermal'))
[void]$backgroundMenu.DropDownItems.Add('-')
$backgroundConfigItem = $backgroundMenu.DropDownItems.Add((T 'tray.configureFireflies'))
[void]$menu.Items.Add($backgroundMenu)
$modulesItem = New-Object Windows.Forms.ToolStripMenuItem((T 'tray.visibleModules'))
$processorPanelItem = $modulesItem.DropDownItems.Add((T 'tray.processorsLoad'))
$performancePanelItem = $modulesItem.DropDownItems.Add((T 'tray.performanceAlerts'))
$clockItem = $modulesItem.DropDownItems.Add((T 'tray.clock'))
$compactItem = $modulesItem.DropDownItems.Add((T 'tray.compactOverlay'))
[void]$menu.Items.Add($modulesItem)
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
$script:backgroundMenu = $backgroundMenu
$script:backgroundOffItem = $backgroundOffItem
$script:backgroundManualItem = $backgroundManualItem
$script:backgroundThermalItem = $backgroundThermalItem
$script:processorPanelItem = $processorPanelItem
$script:performancePanelItem = $performancePanelItem
$script:clockItem = $clockItem
$script:compactItem = $compactItem
$script:markIncidentItem = $markIncidentItem
$script:backgroundConfigItem = $backgroundConfigItem
$script:modulesItem = $modulesItem
$script:languageItem = $languageItem
$script:spanishItem = $spanishItem
$script:englishItem = $englishItem
$script:hardwareConfigItem = $hardwareConfigItem
$script:displayLayoutItem = $displayLayoutItem
$script:configItem = $configItem
$script:logsItem = $logsItem
$script:exitItem = $exitItem
$script:backgroundSettings = Get-BackgroundSettings
$script:layoutEditorProcess = $null
$script:layoutEditorErrorPath = $null
$tray.Icon = New-Object Drawing.Icon($iconPath)
$tray.Text = 'AlienGamer Mode'
$tray.ContextMenuStrip = $menu
$tray.Visible = $true
$monitorItem.Add_Click({ if (Test-MonitorActive) { Stop-Monitor } else { Start-Monitor } })
$tray.Add_DoubleClick({ if (Test-MonitorActive) { Stop-Monitor } else { Start-Monitor } })
$recordItem.Add_Click({ Invoke-RecordingToggle })
$markIncidentItem.Add_Click({ Mark-Incident })
$backgroundOffItem.Add_Click({ Set-BackgroundMode 'off' })
$backgroundManualItem.Add_Click({ Set-BackgroundMode 'manual' })
$backgroundThermalItem.Add_Click({ Set-BackgroundMode 'thermal' })
$backgroundConfigItem.Add_Click({ Show-BackgroundSettings; Update-TrayMenuState })
$processorPanelItem.Add_Click({
    $settings=Get-ModuleVisibilitySettings
    Set-ModuleVisibility 'processorPanelVisible' (-not [bool]$settings.processorPanelVisible)
    Update-TrayMenuState
})
$performancePanelItem.Add_Click({
    $settings=Get-ModuleVisibilitySettings
    Set-ModuleVisibility 'performancePanelVisible' (-not [bool]$settings.performancePanelVisible)
    Update-TrayMenuState
})
$clockItem.Add_Click({
    $settings=Get-ModuleVisibilitySettings
    Set-ModuleVisibility 'clock' (-not [bool]$settings.clock)
    Update-TrayMenuState
})
$compactItem.Add_Click({
    $settings=Get-ModuleVisibilitySettings
    Set-ModuleVisibility 'compactOverlay' (-not [bool]$settings.compactOverlay)
    Update-TrayMenuState
})
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
    Complete-DisplayLayoutEditor
    if ($activateEvent.WaitOne(0)) { Start-Monitor }
    if ($stopEvent.WaitOne(0) -or (Test-StopRequest)) { Stop-Monitor }
    Update-TrayMenuState
    Ensure-MonitorPosition
})
$eventTimer.Start()
Apply-AgentLanguage
Update-TrayMenuState
if ($Activate) { $timer = New-Object Windows.Forms.Timer; $timer.Interval=400; $timer.Add_Tick({$timer.Stop(); Start-Monitor}); $timer.Start() }
[Windows.Forms.Application]::Run()
$tray.Dispose()
$activateEvent.Dispose()
$stopEvent.Dispose()
$mutex.ReleaseMutex()
$mutex.Dispose()
