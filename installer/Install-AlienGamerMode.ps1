param([switch]$NoLaunch,[string]$Language = 'es-MX')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Language `"$Language`""
    if ($NoLaunch) { $arguments += ' -NoLaunch' }
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments
    exit
}

$packageRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $packageRoot 'src'
Import-Module (Join-Path $sourceRoot 'AlienGamer.Localization.psm1') -Force
$Language = Resolve-AGLanguage $Language
$ui = Get-AGTranslations -Language $Language -LocalesRoot (Join-Path $sourceRoot 'locales')
function T([string]$Path) { return Get-AGText -Translations $ui -Path $Path }
$assetRoot = Join-Path $packageRoot 'assets'
$docRoot = Join-Path $packageRoot 'docs'
$defaultConfig = Join-Path $packageRoot 'config\AlienGamerMode.default.json'
$installRoot = Join-Path $env:ProgramData 'AlienGamerMode\App'
$dataRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
$discoveryTemp = Join-Path $env:TEMP 'AlienGamerMode-install-discovery.json'
$rainmeterPath = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
$hwinfoPath = "$env:ProgramFiles\HWiNFO64\HWiNFO64.exe"
$iconPath = Join-Path $assetRoot 'AlienGamerMode.ico'
$script:launchAfterClose = $false
$script:launchProgram = $null
$script:launchArguments = $null
$script:openLayoutAfterClose = $false

function Get-MajorMinorVersion([string]$Path) {
    if (-not (Test-Path $Path)) { return [version]'0.0' }
    $raw = (Get-Item $Path).VersionInfo.ProductVersion
    if ($raw -match '(\d+)\.(\d+)') { return [version]("$($Matches[1]).$($Matches[2])") }
    return [version]'0.0'
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sourceRoot 'Discover-AlienGamerHardware.ps1') -OutputPath $discoveryTemp -AllowMissingHWiNFO | Out-Null
$discovery = Get-Content $discoveryTemp -Raw | ConvertFrom-Json

function Set-IniSetting([string]$Path, [string]$Key, [string]$Value) {
    $content = if (Test-Path $Path) { Get-Content $Path -Raw } else { "[Settings]`r`n" }
    if ($content -match "(?m)^$([regex]::Escape($Key))=") {
        $content = [regex]::Replace($content, "(?m)^$([regex]::Escape($Key))=.*$", "$Key=$Value")
    } else {
        $content = $content -replace '(?m)^\[Settings\]\s*$', "[Settings]`r`n$Key=$Value"
    }
    # HWiNFO no interpreta correctamente su INI cuando contiene BOM UTF-8.
    $content | Set-Content -LiteralPath $Path -Encoding ASCII
}

function Merge-MissingConfiguration($Target, $Defaults) {
    foreach ($property in $Defaults.PSObject.Properties) {
        $existing = $Target.PSObject.Properties[$property.Name]
        if (-not $existing) {
            $Target | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
            continue
        }
        if ($existing.Value -is [Management.Automation.PSCustomObject] -and $property.Value -is [Management.Automation.PSCustomObject]) {
            Merge-MissingConfiguration $existing.Value $property.Value
        }
    }
}

function New-Shortcut([string]$Path, [string]$Target, [string]$Arguments, [string]$Icon) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $Target
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = Split-Path -Parent $Target
    $shortcut.IconLocation = "$Icon,0"
    $shortcut.Description = 'ALIENGAMER MODE · by Alienmau'
    $shortcut.Save()
}

function Get-RainmeterSkinRoot {
    $rainmeterIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
    if (Test-Path -LiteralPath $rainmeterIni) {
        $skinLine = Get-Content -LiteralPath $rainmeterIni | Where-Object { $_ -like 'SkinPath=*' } | Select-Object -First 1
        if ($skinLine) { return $skinLine.Substring(9).TrimEnd('\') }
    }
    return Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
}

function Backup-And-RemovePreviousEditions {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupRoot = Join-Path $env:LOCALAPPDATA "AlienGamerModeLegacyBackup\$stamp"
    $previewData = Join-Path $env:LOCALAPPDATA 'AlienGamerModeUniversal'
    $previewApp = Join-Path $env:ProgramData 'AlienGamerModeUniversal'
    $skinRoot = Get-RainmeterSkinRoot
    $officialSkin = Join-Path $skinRoot 'AlienGamerMode'
    $previewSkin = Join-Path $skinRoot 'AlienGamerModeUniversal'

    # Solicita primero un cierre cooperativo del agente. Esto funciona incluso
    # cuando WMI no puede leer la línea de comandos de un proceso anterior.
    try {
        $createdStopEvent=$false
        $agentStopEvent=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,'Local\AlienGamerMode.Stop',[ref]$createdStopEvent)
        if(-not $createdStopEvent){[void]$agentStopEvent.Set();Start-Sleep -Milliseconds 1200}
        $agentStopEvent.Dispose()
    } catch { }
    # Detiene agentes, puentes y tareas anteriores antes de sustituir archivos.
    foreach ($root in @($dataRoot,$previewData)) {
        $pidFile = Join-Path $root 'bridge.pid'
        if (Test-Path -LiteralPath $pidFile) {
            try { Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue } catch { }
        }
        try { 'stop' | Set-Content -LiteralPath (Join-Path $root 'stop-hwinfo.signal') -Encoding ASCII } catch { }
    }
    try {
        Get-CimInstance Win32_Process | Where-Object {
            $_.Name -match 'powershell' -and $_.CommandLine -match 'AlienGamerMode(?:Universal)?Agent\.ps1|AlienGamerEventRecorder\.ps1'
        } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch { }
    # Una grabación iniciada antes de actualizar conserva el script viejo en
    # memoria. Se detiene sin finalizarla: el CSV queda intacto para recuperación
    # y se eliminan únicamente los archivos de control de la sesión interrumpida.
    Remove-Item -LiteralPath (Join-Path $dataRoot 'recording-state.json'),(Join-Path $dataRoot 'recording.stop'),(Join-Path $dataRoot 'event-prebuffer-state.json'),(Join-Path $dataRoot 'event-prebuffer.stop') -Force -ErrorAction SilentlyContinue
    foreach ($taskName in @('AlienGamerMode-On','AlienGamerMode-Off','AlienGamerModeUniversal-HWiNFO','AlienGamerMode-HWiNFO')) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $rainmeterPath) {
        & $rainmeterPath '!DeactivateConfig' 'AlienGamerMode'
        & $rainmeterPath '!DeactivateConfig' 'AlienGamerModeUniversal'
    }

    $itemsToArchive = @(
        @{ Path=(Join-Path $dataRoot 'AlienGamerMode.json'); Name='Configuracion-Anterior.json' },
        @{ Path=$previewData; Name='Datos-Universal' },
        @{ Path=$previewApp; Name='Programa-Universal' },
        @{ Path=$officialSkin; Name='Skin-Anterior' },
        @{ Path=$previewSkin; Name='Skin-Universal' }
    )
    if ($itemsToArchive | Where-Object { Test-Path -LiteralPath $_.Path }) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        foreach ($item in $itemsToArchive) {
            if (Test-Path -LiteralPath $item.Path) {
                Copy-Item -LiteralPath $item.Path -Destination (Join-Path $backupRoot $item.Name) -Recurse -Force
            }
        }
    }

    # Conserva la selección de monitor, GPU y unidad de la prueba Universal.
    $previewConfig = Join-Path $previewData 'AlienGamerMode.json'
    $officialConfig = Join-Path $dataRoot 'AlienGamerMode.json'
    if (-not (Test-Path -LiteralPath $officialConfig) -and (Test-Path -LiteralPath $previewConfig)) {
        New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
        Copy-Item -LiteralPath $previewConfig -Destination $officialConfig -Force
    }

    # Los destinos son nombres fijos y exclusivos del producto.
    foreach ($obsoletePath in @($previewData,$previewApp,$officialSkin,$previewSkin,$installRoot)) {
        if (Test-Path -LiteralPath $obsoletePath) { Remove-Item -LiteralPath $obsoletePath -Recurse -Force }
    }
    foreach ($shortcut in @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Activar AlienGamer Mode Universal.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Activar AlienGamer Mode.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Desactivar AlienGamer Mode.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Instalar AlienGamer Mode (Administrador).lnk'),
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\AlienGamer Mode Universal.lnk')
    )) { Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue }
    foreach ($folder in @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AlienGamer Mode Universal'),
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AlienGamer Mode')
    )) { if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force } }

    return $(if (Test-Path -LiteralPath $backupRoot) { $backupRoot } else { $null })
}

$form = New-Object Windows.Forms.Form
$form.Text = T 'installer.windowTitle'
$form.Size = New-Object Drawing.Size(690,650)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.TopMost = $true
$form.ShowInTaskbar = $true
if (Test-Path $iconPath) { $form.Icon = New-Object Drawing.Icon($iconPath) }

$title = New-Object Windows.Forms.Label
$title.Text = 'ALIENGAMER MODE'
$title.Font = New-Object Drawing.Font('Segoe UI Semibold',18)
$title.SetBounds(28,20,610,36)
$form.Controls.Add($title)
$signature = New-Object Windows.Forms.Label
$signature.Text = 'by Alienmau'
$signature.Font = New-Object Drawing.Font('Segoe Script',11,[Drawing.FontStyle]::Italic)
$signature.SetBounds(432,29,180,28)
$form.Controls.Add($signature)

$requirements = New-Object Windows.Forms.Label
$rainVersion = Get-MajorMinorVersion $rainmeterPath
$hwVersion = Get-MajorMinorVersion $hwinfoPath
$rainOk = (Test-Path $rainmeterPath) -and $rainVersion -ge [version]'4.5'
$hwOk = (Test-Path $hwinfoPath) -and $hwVersion -ge [version]'7.34'
$requirements.Text = "$(T 'installer.requirements')`r`nRainmeter ${rainVersion}: $(if($rainOk){'OK'}else{((T 'installer.requiresOrLater') -f '4.5')})`r`nHWiNFO64 ${hwVersion}: $(if($hwOk){'OK'}else{((T 'installer.requiresOrLater') -f '7.34')})"
$requirements.SetBounds(30,72,350,62)
$form.Controls.Add($requirements)
$links = New-Object Windows.Forms.LinkLabel
$links.Text = T 'installer.officialDownloads'
$links.SetBounds(385,91,270,28)
$links.Add_LinkClicked({ Start-Process 'https://www.rainmeter.net/'; Start-Process 'https://www.hwinfo.com/download/' })
$form.Controls.Add($links)

function Add-Label([string]$Text,[int]$Y) { $l=New-Object Windows.Forms.Label; $l.Text=$Text; $l.SetBounds(30,$Y,625,22); $form.Controls.Add($l); return $l }
[void](Add-Label (T 'installer.monitor') 155)
$monitorBox = New-Object Windows.Forms.ComboBox
$monitorBox.DropDownStyle = 'DropDownList'; $monitorBox.SetBounds(30,178,625,29)
foreach ($m in @($discovery.monitors)) { [void]$monitorBox.Items.Add("$($m.friendlyName) · $($m.deviceName) · $($m.width)x$($m.height) · $(if($m.primary){T 'installer.primary'}else{T 'installer.secondary'})") }
if ($monitorBox.Items.Count) { $monitorBox.SelectedIndex = if ($monitorBox.Items.Count -gt 1) { 1 } else { 0 } }
$form.Controls.Add($monitorBox)

[void](Add-Label (T 'installer.gpu') 220)
$gpuBox = New-Object Windows.Forms.ComboBox
$gpuBox.DropDownStyle='DropDownList'; $gpuBox.SetBounds(30,243,625,29)
foreach ($g in @($discovery.gpus)) { [void]$gpuBox.Items.Add($g.name) }
if ($gpuBox.Items.Count) { $gpuBox.SelectedIndex=0 }; $form.Controls.Add($gpuBox)

[void](Add-Label (T 'installer.storage') 285)
$storageBox = New-Object Windows.Forms.ComboBox
$storageBox.DropDownStyle='DropDownList'; $storageBox.SetBounds(30,308,625,29)
foreach ($d in @($discovery.storage)) { [void]$storageBox.Items.Add("$($d.friendlyName) · $($d.busType) · $([Math]::Round($d.sizeBytes/1GB)) GB") }
if ($storageBox.Items.Count) { $storageBox.SelectedIndex=0 }; $form.Controls.Add($storageBox)

$desktopCheck = New-Object Windows.Forms.CheckBox; $desktopCheck.Text=T 'installer.desktopShortcut'; $desktopCheck.Checked=$true; $desktopCheck.SetBounds(30,365,280,25); $form.Controls.Add($desktopCheck)
$startMenuCheck = New-Object Windows.Forms.CheckBox; $startMenuCheck.Text=T 'installer.startMenu'; $startMenuCheck.Checked=$true; $startMenuCheck.SetBounds(330,365,280,25); $form.Controls.Add($startMenuCheck)
$startupCheck = New-Object Windows.Forms.CheckBox; $startupCheck.Text=T 'installer.startWindows'; $startupCheck.SetBounds(30,398,280,25); $form.Controls.Add($startupCheck)
$taskbarCheck = New-Object Windows.Forms.CheckBox; $taskbarCheck.Text=T 'installer.pinTaskbar'; $taskbarCheck.SetBounds(330,398,320,25); $form.Controls.Add($taskbarCheck)

$note = New-Object Windows.Forms.Label
$note.Text = (T 'installer.note').Replace('\r\n',"`r`n")
$note.ForeColor = [Drawing.Color]::DimGray; $note.SetBounds(30,445,625,48); $form.Controls.Add($note)

$installButton = New-Object Windows.Forms.Button
$installButton.Text = T 'installer.install'; $installButton.SetBounds(350,525,205,42); $installButton.Enabled=($rainOk -and $hwOk); $form.Controls.Add($installButton)
$cancelButton = New-Object Windows.Forms.Button
$cancelButton.Text = T 'installer.cancel'; $cancelButton.SetBounds(565,525,90,42); $cancelButton.Add_Click({$form.Close()}); $form.Controls.Add($cancelButton)
$status = New-Object Windows.Forms.Label; $status.Text=''; $status.SetBounds(30,505,300,65); $form.Controls.Add($status)

$installButton.Add_Click({
    try {
        $installButton.Enabled=$false; $status.Text=T 'installer.copying'; $form.Refresh()
        $legacyBackup = Backup-And-RemovePreviousEditions
        New-Item -ItemType Directory -Path $installRoot,$dataRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $installRoot -Recurse -Force
        $installedAssets = Join-Path $installRoot 'assets'
        New-Item -ItemType Directory -Path $installedAssets -Force | Out-Null
        Copy-Item -Path (Join-Path $assetRoot '*') -Destination $installedAssets -Recurse -Force
        $installedDocs = Join-Path $installRoot 'docs'
        New-Item -ItemType Directory -Path $installedDocs -Force | Out-Null
        Copy-Item -Path (Join-Path $docRoot '*') -Destination $installedDocs -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $packageRoot 'README.md') -Destination (Join-Path $installRoot 'README.md') -Force
        Copy-Item -LiteralPath (Join-Path $packageRoot 'README.en.md') -Destination (Join-Path $installRoot 'README.en.md') -Force
        Copy-Item -LiteralPath $defaultConfig -Destination (Join-Path $installRoot 'AlienGamerMode.default.json') -Force
        $configPath = Join-Path $dataRoot 'AlienGamerMode.json'
        # Durante la estabilizacion del editor 1.5 cada instalacion empieza con
        # una configuracion visual limpia. El respaldo anterior queda fuera del
        # directorio activo; grabaciones y reportes del usuario no se eliminan.
        Copy-Item -LiteralPath $defaultConfig -Destination $configPath -Force
        foreach($generatedPath in @(
            (Join-Path $dataRoot 'DisplayProfiles'),
            (Join-Path $dataRoot 'GeneratedSkin'),
            (Join-Path $dataRoot 'display-manifest.json'),
            (Join-Path $dataRoot 'profile.json'),
            (Join-Path $dataRoot 'layout-editor.error.log'),
            (Join-Path $dataRoot 'layout-editor.trace.log')
        )){Remove-Item -LiteralPath $generatedPath -Recurse -Force -ErrorAction SilentlyContinue}
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $config.language = $Language
        $selectedMonitor = @($discovery.monitors)[$monitorBox.SelectedIndex]
        $selectedGpu = @($discovery.gpus)[$gpuBox.SelectedIndex]
        $selectedStorage = @($discovery.storage)[$storageBox.SelectedIndex]
        $config.display.targetMonitor = $selectedMonitor.deviceName
        if ($config.display.PSObject.Properties['targetMonitorId']) { $config.display.targetMonitorId = $selectedMonitor.pnpDeviceId }
        else { $config.display | Add-Member NoteProperty targetMonitorId ([string]$selectedMonitor.pnpDeviceId) }
        if (@($config.displayViews).Count -gt 0) {
            $primaryView = @($config.displayViews)[0]
            $primaryView.monitorId = [string]$selectedMonitor.pnpDeviceId
            $primaryView.monitorDeviceName = [string]$selectedMonitor.deviceName
            $primaryView.name = [string]$selectedMonitor.friendlyName
            $primaryView.enabled = $true
            $primaryView.layoutPreset = 'full-horizontal'
            foreach($moduleProperty in $primaryView.modules.PSObject.Properties){$moduleProperty.Value.visible=$true}
        }
        $config.schemaVersion = 3
        $config.hardware.preferredGpu = $selectedGpu.name
        $config.hardware.preferredStorage = $selectedStorage.friendlyName
        $config.installation.desktopShortcut = $desktopCheck.Checked
        $config.installation.startMenuShortcut = $startMenuCheck.Checked
        $config.installation.startWithWindows = $startupCheck.Checked
        $config | ConvertTo-Json -Depth 20 | Set-Content $configPath -Encoding UTF8

        $hwinfoIni = Join-Path (Split-Path $hwinfoPath -Parent) 'HWiNFO64.INI'
        if (Get-Process HWiNFO64 -ErrorAction SilentlyContinue) {
            $answer = [Windows.Forms.MessageBox]::Show($form,(T 'installer.hwinfoOpen'),(T 'installer.prepareHWiNFO'),[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -ne [Windows.Forms.DialogResult]::Yes) { throw (T 'installer.installCancelled') }
            Stop-Process -Name HWiNFO64 -Force
            Start-Sleep -Milliseconds 600
        }
        if (Test-Path $hwinfoIni) { Copy-Item $hwinfoIni "$hwinfoIni.AlienGamerMode.bak" -Force }
        foreach ($pair in @(@('SensorsOnly','1'),@('SensorsSM','1'),@('OpenSystemSummary','0'),@('OpenSensors','1'),@('MinimalizeMainWnd','1'),@('MinimalizeSensors','1'),@('ShowWelcomeAndProgress','0'),@('MinimalizeSensorsClose','1'))) { Set-IniSetting $hwinfoIni $pair[0] $pair[1] }

        $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $hwinfoLauncher = Join-Path $installRoot 'Start-AlienGamerHWiNFO.ps1'
        # No se define WorkingDirectory: algunos equipos devuelven ERROR_DIRECTORY
        # al iniciar una tarea elevada dentro de AppData aunque la carpeta exista.
        $taskArguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$hwinfoLauncher`""
        $scheduler = New-Object -ComObject 'Schedule.Service'
        $scheduler.Connect()
        $taskFolder = $scheduler.GetFolder('\')
        $taskDefinition = $scheduler.NewTask(0)
        $taskDefinition.RegistrationInfo.Description = 'Inicia HWiNFO64 con sensores y memoria compartida para AlienGamer Mode.'
        $taskDefinition.Principal.UserId = $identity.Name
        $taskDefinition.Principal.LogonType = 3
        $taskDefinition.Principal.RunLevel = 1
        # Compatibility=2 (Vista) usa el motor clasico. No se debe tocar
        # UseUnifiedSchedulingEngine: hacerlo actualiza la tarea a Win7 y lo reactiva.
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
        [void]$taskFolder.RegisterTaskDefinition('AlienGamerMode-HWiNFO',$taskDefinition,6,$null,$null,3,$null)

        # Verifica la tarea durante la instalacion para no reportar exito si
        # Windows no puede iniciar HWiNFO con elevacion.
        Start-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO'
        $taskDeadline = [DateTime]::UtcNow.AddSeconds(10)
        while (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $taskDeadline) {
            Start-Sleep -Milliseconds 250
        }
        if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) {
            $taskResult = (Get-ScheduledTaskInfo -TaskName 'AlienGamerMode-HWiNFO').LastTaskResult
            throw ('{0} (0x{1:X8}).' -f (T 'installer.hwinfoTaskFailed'),$taskResult)
        }
        Stop-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue
        Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        $launcher = Join-Path $installRoot 'AlienGamerModeLauncher.vbs'
        $wscript = "$env:SystemRoot\System32\wscript.exe"
        $args = "//B //NoLogo `"$launcher`" activate"
        $desktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Activar AlienGamer Mode.lnk'
        if ($desktopCheck.Checked) { New-Shortcut $desktopLink $wscript $args (Join-Path $installRoot 'assets\AlienGamerMode.ico') }
        $startFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AlienGamer Mode'
        if ($startMenuCheck.Checked) {
            New-Item -ItemType Directory -Path $startFolder -Force | Out-Null
            New-Shortcut (Join-Path $startFolder 'AlienGamer Mode.lnk') $wscript $args (Join-Path $installRoot 'assets\AlienGamerMode.ico')
            $uninstallScript = Join-Path $installRoot 'Uninstall-AlienGamerMode.ps1'
            New-Shortcut (Join-Path $startFolder ((T 'installer.uninstallShortcut') + '.lnk')) $powershell "-NoProfile -ExecutionPolicy Bypass -File `"$uninstallScript`"" (Join-Path $installRoot 'assets\AlienGamerMode.ico')
        }
        $startupLink = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\AlienGamer Mode.lnk'
        if ($startupCheck.Checked) { New-Shortcut $startupLink $wscript "//B //NoLogo `"$launcher`" agent" (Join-Path $installRoot 'assets\AlienGamerMode.ico') } elseif (Test-Path $startupLink) { Remove-Item $startupLink -Force }

        $status.Text=T 'installer.finished'; $form.Refresh()
        $completion = T 'installer.complete'
        if (-not $NoLaunch) { $completion += "`r`n`r`n$(T 'installer.launchNotice')" }
        if ($taskbarCheck.Checked) { $completion += "`r`n`r`n$(T 'installer.pinNotice')" }
        if ($legacyBackup) { $completion += "`r`n`r`n$(T 'installer.backup')`r`n$legacyBackup" }
        [Windows.Forms.MessageBox]::Show($form,$completion,(T 'installer.completeTitle'),[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        # Toda instalacion termina en el editor visual con el diseno completo y
        # limpio; el usuario puede conservarlo o personalizarlo antes de aplicar.
        $script:openLayoutAfterClose = $true
        $script:launchAfterClose = -not $NoLaunch
        $script:launchProgram = $wscript
        $script:launchArguments = if($script:openLayoutAfterClose){"//B //NoLogo `"$launcher`" activate-layout"}else{$args}
        $form.Close()
    } catch {
        $installButton.Enabled=$true; $status.Text=T 'installer.notCompleted'
        [Windows.Forms.MessageBox]::Show($form,$_.Exception.ToString(),(T 'installer.errorTitle'),[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
})

[void]$form.ShowDialog()

# El agente se inicia únicamente cuando ya no existen diálogos del instalador.
# Un segundo pulso de activación evita perder la orden durante la creación inicial
# del mutex o del evento local del agente.
if ($script:launchAfterClose) {
    Start-Process $script:launchProgram -WindowStyle Hidden -ArgumentList $script:launchArguments | Out-Null
    Start-Sleep -Milliseconds 1500
    Start-Process $script:launchProgram -WindowStyle Hidden -ArgumentList $script:launchArguments | Out-Null
}
