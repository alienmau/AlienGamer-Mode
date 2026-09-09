param([switch]$NoLaunch)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($NoLaunch) { $arguments += ' -NoLaunch' }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

$packageRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $packageRoot 'src'
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
$script:launchPowerShell = $null
$script:launchArguments = $null

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
            $_.Name -match 'powershell' -and $_.CommandLine -match 'AlienGamerMode(?:Universal)?Agent\.ps1'
        } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch { }
    foreach ($taskName in @('AlienGamerMode-On','AlienGamerMode-Off','AlienGamerModeUniversal-HWiNFO','AlienGamerMode-HWiNFO')) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $rainmeterPath) {
        & $rainmeterPath '!DeactivateConfig' 'AlienGamerMode'
        & $rainmeterPath '!DeactivateConfig' 'AlienGamerModeUniversal'
    }

    $itemsToArchive = @(
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
$form.Text = 'Instalar AlienGamer Mode · by Alienmau'
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
$requirements.Text = "Requisitos detectados:`r`nRainmeter ${rainVersion}: $(if($rainOk){'OK'}else{'REQUIERE 4.5 O POSTERIOR'})`r`nHWiNFO64 ${hwVersion}: $(if($hwOk){'OK'}else{'REQUIERE 7.34 O POSTERIOR'})"
$requirements.SetBounds(30,72,350,62)
$form.Controls.Add($requirements)
$links = New-Object Windows.Forms.LinkLabel
$links.Text = 'Abrir descargas oficiales de Rainmeter y HWiNFO'
$links.SetBounds(385,91,270,28)
$links.Add_LinkClicked({ Start-Process 'https://www.rainmeter.net/'; Start-Process 'https://www.hwinfo.com/download/' })
$form.Controls.Add($links)

function Add-Label([string]$Text,[int]$Y) { $l=New-Object Windows.Forms.Label; $l.Text=$Text; $l.SetBounds(30,$Y,625,22); $form.Controls.Add($l); return $l }
[void](Add-Label 'Monitor donde aparecerá el panel:' 155)
$monitorBox = New-Object Windows.Forms.ComboBox
$monitorBox.DropDownStyle = 'DropDownList'; $monitorBox.SetBounds(30,178,625,29)
foreach ($m in @($discovery.monitors)) { [void]$monitorBox.Items.Add("$($m.deviceName) · $($m.width)x$($m.height) · $(if($m.primary){'principal'}else{'secundario'})") }
if ($monitorBox.Items.Count) { $monitorBox.SelectedIndex = if ($monitorBox.Items.Count -gt 1) { 1 } else { 0 } }
$form.Controls.Add($monitorBox)

[void](Add-Label 'GPU que se monitorizará:' 220)
$gpuBox = New-Object Windows.Forms.ComboBox
$gpuBox.DropDownStyle='DropDownList'; $gpuBox.SetBounds(30,243,625,29)
foreach ($g in @($discovery.gpus)) { [void]$gpuBox.Items.Add($g.name) }
if ($gpuBox.Items.Count) { $gpuBox.SelectedIndex=0 }; $form.Controls.Add($gpuBox)

[void](Add-Label 'Unidad principal que se mostrará:' 285)
$storageBox = New-Object Windows.Forms.ComboBox
$storageBox.DropDownStyle='DropDownList'; $storageBox.SetBounds(30,308,625,29)
foreach ($d in @($discovery.storage)) { [void]$storageBox.Items.Add("$($d.friendlyName) · $($d.busType) · $([Math]::Round($d.sizeBytes/1GB)) GB") }
if ($storageBox.Items.Count) { $storageBox.SelectedIndex=0 }; $form.Controls.Add($storageBox)

$desktopCheck = New-Object Windows.Forms.CheckBox; $desktopCheck.Text='Crear acceso en el Escritorio'; $desktopCheck.Checked=$true; $desktopCheck.SetBounds(30,365,280,25); $form.Controls.Add($desktopCheck)
$startMenuCheck = New-Object Windows.Forms.CheckBox; $startMenuCheck.Text='Agregar al menú Inicio'; $startMenuCheck.Checked=$true; $startMenuCheck.SetBounds(330,365,280,25); $form.Controls.Add($startMenuCheck)
$startupCheck = New-Object Windows.Forms.CheckBox; $startupCheck.Text='Iniciar el agente con Windows'; $startupCheck.SetBounds(30,398,280,25); $form.Controls.Add($startupCheck)
$taskbarCheck = New-Object Windows.Forms.CheckBox; $taskbarCheck.Text='Quiero fijarlo a la barra de tareas (paso manual)'; $taskbarCheck.SetBounds(330,398,320,25); $form.Controls.Add($taskbarCheck)

$note = New-Object Windows.Forms.Label
$note.Text = "Esta edición oficial reemplaza instalaciones anteriores y conserva un respaldo local.`r`nLos sensores ausentes se ocultan o muestran N/D; nunca se inventan como cero."
$note.ForeColor = [Drawing.Color]::DimGray; $note.SetBounds(30,445,625,48); $form.Controls.Add($note)

$installButton = New-Object Windows.Forms.Button
$installButton.Text = 'INSTALAR Y CONFIGURAR'; $installButton.SetBounds(350,525,205,42); $installButton.Enabled=($rainOk -and $hwOk); $form.Controls.Add($installButton)
$cancelButton = New-Object Windows.Forms.Button
$cancelButton.Text = 'Cancelar'; $cancelButton.SetBounds(565,525,90,42); $cancelButton.Add_Click({$form.Close()}); $form.Controls.Add($cancelButton)
$status = New-Object Windows.Forms.Label; $status.Text=''; $status.SetBounds(30,505,300,65); $form.Controls.Add($status)

$installButton.Add_Click({
    try {
        $installButton.Enabled=$false; $status.Text='Copiando y configurando...'; $form.Refresh()
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
        $configPath = Join-Path $dataRoot 'AlienGamerMode.json'
        if (-not (Test-Path $configPath)) { Copy-Item $defaultConfig $configPath }
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $selectedMonitor = @($discovery.monitors)[$monitorBox.SelectedIndex]
        $selectedGpu = @($discovery.gpus)[$gpuBox.SelectedIndex]
        $selectedStorage = @($discovery.storage)[$storageBox.SelectedIndex]
        $config.display.targetMonitor = $selectedMonitor.deviceName
        $config.hardware.preferredGpu = $selectedGpu.name
        $config.hardware.preferredStorage = $selectedStorage.friendlyName
        $config.installation.desktopShortcut = $desktopCheck.Checked
        $config.installation.startMenuShortcut = $startMenuCheck.Checked
        $config.installation.startWithWindows = $startupCheck.Checked
        $config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8

        $hwinfoIni = Join-Path (Split-Path $hwinfoPath -Parent) 'HWiNFO64.INI'
        if (Get-Process HWiNFO64 -ErrorAction SilentlyContinue) {
            $answer = [Windows.Forms.MessageBox]::Show($form,'HWiNFO está abierto. Es necesario cerrarlo brevemente para guardar la configuración de sensores. ¿Continuar?','Preparar HWiNFO',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -ne [Windows.Forms.DialogResult]::Yes) { throw 'Instalación cancelada: HWiNFO debe estar cerrado durante su configuración.' }
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
            throw ('La tarea elevada de HWiNFO no pudo iniciar (0x{0:X8}).' -f $taskResult)
        }
        Stop-ScheduledTask -TaskName 'AlienGamerMode-HWiNFO' -ErrorAction SilentlyContinue
        Stop-Process -Name HWiNFO64 -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        $agent = Join-Path $installRoot 'AlienGamerModeAgent.ps1'
        $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$agent`" -Activate"
        $desktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Activar AlienGamer Mode.lnk'
        if ($desktopCheck.Checked) { New-Shortcut $desktopLink $powershell $args (Join-Path $installRoot 'assets\AlienGamerMode.ico') }
        $startFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AlienGamer Mode'
        if ($startMenuCheck.Checked) {
            New-Item -ItemType Directory -Path $startFolder -Force | Out-Null
            New-Shortcut (Join-Path $startFolder 'AlienGamer Mode.lnk') $powershell $args (Join-Path $installRoot 'assets\AlienGamerMode.ico')
            $uninstallScript = Join-Path $installRoot 'Uninstall-AlienGamerMode.ps1'
            New-Shortcut (Join-Path $startFolder 'Desinstalar AlienGamer Mode.lnk') $powershell "-NoProfile -ExecutionPolicy Bypass -File `"$uninstallScript`"" (Join-Path $installRoot 'assets\AlienGamerMode.ico')
        }
        $startupLink = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\AlienGamer Mode.lnk'
        if ($startupCheck.Checked) { New-Shortcut $startupLink $powershell "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$agent`"" (Join-Path $installRoot 'assets\AlienGamerMode.ico') } elseif (Test-Path $startupLink) { Remove-Item $startupLink -Force }

        $status.Text='Instalación terminada.'; $form.Refresh()
        $completion = 'AlienGamer Mode quedó instalado correctamente.'
        if (-not $NoLaunch) { $completion += "`r`n`r`nAl aceptar se iniciará y mostrará el monitor. El primer arranque puede tardar mientras descubre y valida los sensores." }
        if ($taskbarCheck.Checked) { $completion += "`r`n`r`nPara fijarlo: abre Inicio, busca AlienGamer Mode, haz clic derecho y elige Fijar a la barra de tareas." }
        if ($legacyBackup) { $completion += "`r`n`r`nRespaldo de la edición anterior:`r`n$legacyBackup" }
        [Windows.Forms.MessageBox]::Show($form,$completion,'Instalación completa',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        $script:launchAfterClose = -not $NoLaunch
        $script:launchPowerShell = $powershell
        $script:launchArguments = $args
        $form.Close()
    } catch {
        $installButton.Enabled=$true; $status.Text='No se completó la instalación.'
        [Windows.Forms.MessageBox]::Show($form,$_.Exception.ToString(),'Error de instalación',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
})

[void]$form.ShowDialog()

# El agente se inicia únicamente cuando ya no existen diálogos del instalador.
# Un segundo pulso de activación evita perder la orden durante la creación inicial
# del mutex o del evento local del agente.
if ($script:launchAfterClose) {
    Start-Process $script:launchPowerShell -WindowStyle Hidden -ArgumentList $script:launchArguments | Out-Null
    Start-Sleep -Milliseconds 1500
    Start-Process $script:launchPowerShell -WindowStyle Hidden -ArgumentList $script:launchArguments | Out-Null
}
