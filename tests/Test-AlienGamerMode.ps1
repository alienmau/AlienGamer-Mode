$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object 'System.Collections.Generic.List[string]'
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { $failures.Add($Message) } }

foreach ($file in Get-ChildItem $root -Recurse -Include *.ps1,*.psm1) {
    $tokens=$null; $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    Assert ($errors.Count -eq 0) "Error de sintaxis en $($file.Name): $($errors.Message -join '; ')"
}

$config = Get-Content (Join-Path $root 'config\AlienGamerMode.default.json') -Raw | ConvertFrom-Json
Assert ($config.schemaVersion -eq 3) 'La configuración no usa schemaVersion 3.'
Assert (@($config.displayViews).Count -ge 1 -and $config.displayViews[0].modules.ram.visible -eq $true) 'La configuración no contiene una vista inicial multidisplay válida.'
Assert ($config.language -eq 'es-MX') 'El idioma predeterminado debe ser español de México.'
Assert ((Test-Path (Join-Path $root 'src\locales\es-MX.json')) -and (Test-Path (Join-Path $root 'src\locales\en-US.json')) -and (Test-Path (Join-Path $root 'src\AlienGamer.Localization.psm1'))) 'Faltan los recursos centrales de idioma.'
Assert (Test-Path (Join-Path $root 'README.en.md')) 'Falta la documentación principal en inglés.'
$spanishLocale = Get-Content (Join-Path $root 'src\locales\es-MX.json') -Raw | ConvertFrom-Json
$englishLocale = Get-Content (Join-Path $root 'src\locales\en-US.json') -Raw | ConvertFrom-Json
function Get-LocalePaths($Object,[string]$Prefix='') {
    $paths = @()
    foreach ($property in $Object.PSObject.Properties) {
        $path = if ($Prefix) { "$Prefix.$($property.Name)" } else { $property.Name }
        if ($property.Value -is [Management.Automation.PSCustomObject]) { $paths += Get-LocalePaths $property.Value $path }
        else { $paths += $path }
    }
    return $paths
}
Assert (@(Compare-Object (Get-LocalePaths $spanishLocale) (Get-LocalePaths $englishLocale)).Count -eq 0) 'Los archivos de idioma no contienen el mismo conjunto de claves.'
Assert ($config.dataSource.bridgePort -eq 27843) 'La edición oficial debe usar el puerto local 27843.'
Assert ($config.appearance.backgroundEffect.enabled -eq $true -and $config.appearance.backgroundEffect.updateFps -le 10) 'El fondo ambiental no tiene una configuración equilibrada y personalizable.'
Assert ($config.appearance.backgroundEffect.particleCount -ge 8 -and $config.appearance.backgroundEffect.particleCount -le 48 -and $config.appearance.backgroundEffect.speed -ge 0.2 -and $config.appearance.backgroundEffect.sizeScale -ge 0.7 -and $config.appearance.backgroundEffect.sizeScale -le 1.6 -and $config.appearance.backgroundEffect.color -match '^\d+,\d+,\d+$') 'Las luciérnagas no tienen cantidad, velocidad, tamaño y color configurables dentro de límites seguros.'
Assert ($config.appearance.backgroundEffect.mode -eq 'manual') 'El fondo no define un modo inicial compatible y persistente.'
Assert ($config.display.targetMonitorId -eq 'auto') 'La configuración no contempla una identidad física estable para el monitor.'
Assert ($config.appearance.backgroundEffect.thermalMinimumParticles -ge 4 -and $config.appearance.backgroundEffect.thermalMaximumParticles -le 40 -and $config.appearance.backgroundEffect.thermalMaximumParticles -gt $config.appearance.backgroundEffect.thermalMinimumParticles) 'El modo térmico no tiene límites propios y conservadores.'
Assert ($config.features.processorPanelVisible -eq $true -and $config.features.performancePanelVisible -eq $true) 'Los módulos opcionales deben iniciar visibles en una instalación nueva.'
Assert ($config.features.compactOverlay -eq $false -and $config.eventIntelligence.preEventBufferSeconds -eq 60 -and $config.eventIntelligence.privacyAssistant -eq $true -and $config.eventIntelligence.saveVisualReportBesideReport -eq $true) 'La configuración no define modo compacto, búfer, privacidad y reporte visual con valores seguros.'
Assert (Test-Path (Join-Path $root 'src\Start-AlienGamerHWiNFO.ps1')) 'Falta el iniciador elevado de HWiNFO.'
$hwinfoLauncherSource = Get-Content (Join-Path $root 'src\Start-AlienGamerHWiNFO.ps1') -Raw
$installerSource = Get-Content (Join-Path $root 'installer\Install-AlienGamerMode.ps1') -Raw
$innoSource = Get-Content (Join-Path $root 'installer\AlienGamerMode.iss') -Raw
$uninstallerSource = Get-Content (Join-Path $root 'src\Uninstall-AlienGamerMode.ps1') -Raw
$agentSource = Get-Content (Join-Path $root 'src\AlienGamerModeAgent.ps1') -Raw
$discoverySource = Get-Content (Join-Path $root 'src\Discover-AlienGamerHardware.ps1') -Raw
$bridgeSource = Get-Content (Join-Path $root 'src\AlienGamerBridge.ps1') -Raw
$recorderSource = Get-Content (Join-Path $root 'src\AlienGamerEventRecorder.ps1') -Raw
$commandSource = Get-Content (Join-Path $root 'src\AlienGamerModeCommand.ps1') -Raw
$launcherSource = Get-Content (Join-Path $root 'src\AlienGamerModeLauncher.vbs') -Raw
$fallbackStopSource = Get-Content (Join-Path $root 'src\Stop-AlienGamerMode.ps1') -Raw
$layoutEditorSource = Get-Content (Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1') -Raw
$multiDisplayBuildSource = Get-Content (Join-Path $root 'src\Build-MultiDisplaySkins.ps1') -Raw
Assert ($installerSource -notmatch 'New-ScheduledTaskAction[^\r\n]+-WorkingDirectory') 'La tarea elevada no debe depender de WorkingDirectory.'
Assert ($installerSource -match 'Settings\.Compatibility\s*=\s*2') 'La tarea debe usar compatibilidad Vista y el motor clasico.'
Assert ($installerSource -notmatch 'UseUnifiedSchedulingEngine\s*=') 'No se debe tocar UseUnifiedSchedulingEngine porque actualiza la tarea a Win7.'
Assert ($installerSource -match 'Set-Content -LiteralPath \$Path -Encoding ASCII') 'El INI de HWiNFO debe guardarse como ASCII sin BOM.'
Assert ($installerSource -notmatch 'Merge-MissingConfiguration \$config \$configDefaults') 'La instalación limpia todavía mezcla opciones heredadas con la configuración oficial.'
Assert ($installerSource -match '\$config\.language = \$Language' -and $innoSource -match 'Name: "english"' -and $innoSource -match 'Name: "spanish"' -and $innoSource -match 'ShowLanguageDialog=yes' -and $innoSource -match '-Language ""\{language\}""') 'El instalador no permite seleccionar y guardar español o inglés.'
Assert ($innoSource -match '#define MyAppVersion "1\.5\.9"' -and $innoSource -match 'AlienGamerMode-Setup-1\.5\.9') 'El instalador no está versionado como 1.5.9.'
Assert ($installerSource -match "Configuracion-Anterior\.json" -and $installerSource -match 'Copy-Item -LiteralPath \$defaultConfig -Destination \$configPath -Force' -and $installerSource -match "layoutPreset = 'full-horizontal'" -and $installerSource -match 'moduleProperty\.Value\.visible=\$true') 'La instalación no garantiza un diseño completo y limpio o no respalda la configuración anterior.'
Assert ($installerSource -match 'Join-Path \$dataRoot ''DisplayProfiles''' -and $installerSource -match 'Join-Path \$dataRoot ''GeneratedSkin''' -and $installerSource -match 'Join-Path \$dataRoot ''display-manifest\.json''') 'La instalación limpia conserva artefactos visuales generados por una versión anterior.'
Assert ($installerSource -match 'AlienGamerEventRecorder\\\.ps1' -and $installerSource -match 'recording-state\.json' -and $installerSource -match 'event-prebuffer-state\.json') 'La actualización no detiene grabadores antiguos ni limpia su estado de control.'
Assert ($installerSource -match 'installer\.uninstallShortcut' -and $installerSource -match 'installedDocs') 'El paquete no instala documentación o acceso de desinstalación.'
Assert ($installerSource -match '(?s)\$form\.ShowDialog\(\).*?if \(\$script:launchAfterClose\)' -and $installerSource -notmatch '\$taskbarCheck\.Checked\) \{ \[Windows\.Forms\.MessageBox\]::Show\(''Windows 11') 'El agente o los avisos todavía pueden superponerse al instalador.'
Assert ($innoSource -match '-WindowStyle Hidden' -and $innoSource -notmatch 'Flags:[^\r\n]*runhidden' -and $installerSource -match '\$form\.TopMost\s*=\s*\$true') 'El empaquetador puede ocultar nuevamente el formulario de configuración.'
Assert ($uninstallerSource -match "ProgramData 'AlienGamerMode\\App'" -and $uninstallerSource -match 'SkinPath=') 'El desinstalador no apunta a las rutas reales de programa y skin.'
Assert ($agentSource -match '\.GetEnumerator\(\)') 'La escritura de posición de Rainmeter debe enumerar claves sin crear líneas vacías.'
Assert ($agentSource -match "'!Move'.*view\.monitor\.x.*view\.monitor\.y") 'El agente no fuerza cada vista al monitor elegido después de activarla.'
Assert ($discoverySource -match 'NativeDisplays' -and $discoverySource -match 'pnpDeviceId') 'La detección no conserva una identidad física estable del monitor.'
Assert ($agentSource -match 'function Ensure-MonitorPosition' -and $agentSource -match 'TotalSeconds -lt 5') 'El agente no reafirma periódicamente el monitor elegido.'
Assert ($discoverySource -notmatch 'SetProcessDpiAwareness\s*\(\s*2\s*\)') 'La detección no debe entregar píxeles físicos que Rainmeter escalará por segunda vez.'
Assert ($bridgeSource -match 'ToString\(''0\.0'', \$culture\)' -and $bridgeSource -notmatch '0\.0###') 'Los valores visuales deben limitarse a un decimal.'
Assert ($bridgeSource -match '1000\.0 / \$fps' -and $bridgeSource -match 'Limit-Reading') 'El puente no valida rangos y coherencia FPS/frame time en tiempo real.'
Assert ($bridgeSource -match 'Cliente desconectado antes de recibir la respuesta' -and $bridgeSource -match 'Solicitud interrumpida:' -and $bridgeSource -match 'if \(\$client\) \{ \$client\.Dispose\(\) \}') 'Una consulta cancelada por Rainmeter todavía puede cerrar el puente de sensores.'
Assert ($agentSource -match 'profile\.validation') 'El agente puede mostrar una skin sin perfil validado.'
Assert ($agentSource -match 'Stop-OwnedHWiNFOTask' -and $hwinfoLauncherSource -match 'stop-hwinfo\.signal') 'OFF no garantiza el cierre cooperativo del HWiNFO elevado.'
$clockSourcePath = Join-Path $root 'src\skin\MatrixClock.lua'
$clockSourceBytes = [IO.File]::ReadAllBytes($clockSourcePath)
Assert (-not ($clockSourceBytes.Length -ge 3 -and $clockSourceBytes[0] -eq 0xEF -and $clockSourceBytes[1] -eq 0xBB -and $clockSourceBytes[2] -eq 0xBF)) 'MatrixClock.lua tiene BOM UTF-8 y Rainmeter no podrá cargarlo.'
$clockSource = [IO.File]::ReadAllText($clockSourcePath)
Assert ($clockSource -match 'recordProgress' -and $clockSource -match 'math\.sin' -and $clockSource -match 'buttonWidth') 'El botón de grabación no conserva la expansión y el pulso animado.'
Assert ($clockSource -match 'alertRings' -and $clockSource -match 'updateAlertPulses' -and $clockSource -match 'Ring_SSD_TEMP' -and $clockSource -match 'mix\(195, 255, pulse\)' -and $clockSource -match 'mix\(12, 28, pulse\)' -and $clockSource -match '"%d,0,%d,255"') 'Los anillos críticos no conservan el destello entre dos rojos sólidos.'
$skinTemplateSource = Get-Content (Join-Path $root 'src\skin\AlienGamerMode.Template.ini') -Raw
$styleBlock = [regex]::Match($skinTemplateSource, '(?ms)^\[BG2Style\].*?(?=^\[|\z)').Value
$auxiliaryRingBlocks = @([regex]::Matches($skinTemplateSource, '(?ms)^\[BG2_[^\]]+\].*?(?=^\[|\z)'))
Assert ($styleBlock -notmatch '(?m)^Meter=' -and $auxiliaryRingBlocks.Count -eq 7 -and -not ($auxiliaryRingBlocks.Value -match '(?m)^Meter=')) 'Los aros auxiliares BG2 vuelven a dibujar el círculo residual o duplican los contornos de los sensores.'
$ringAnimatorPath = Join-Path $root 'src\skin\RingAnimator.lua'
$ringAnimatorBytes = [IO.File]::ReadAllBytes($ringAnimatorPath)
Assert (-not ($ringAnimatorBytes.Length -ge 3 -and $ringAnimatorBytes[0] -eq 0xEF -and $ringAnimatorBytes[1] -eq 0xBB -and $ringAnimatorBytes[2] -eq 0xBF)) 'RingAnimator.lua tiene BOM UTF-8 y Rainmeter no podrá cargarlo.'
$backgroundAnimatorPath = Join-Path $root 'src\skin\BackgroundAnimator.lua'
$backgroundAnimatorBytes = [IO.File]::ReadAllBytes($backgroundAnimatorPath)
$backgroundAnimatorSource = [IO.File]::ReadAllText($backgroundAnimatorPath)
Assert (-not ($backgroundAnimatorBytes.Length -ge 3 -and $backgroundAnimatorBytes[0] -eq 0xEF -and $backgroundAnimatorBytes[1] -eq 0xBB -and $backgroundAnimatorBytes[2] -eq 0xBF)) 'BackgroundAnimator.lua tiene BOM UTF-8 y Rainmeter no podrá cargarlo.'
Assert ($backgroundAnimatorSource -match 'maximumParticles\s*=\s*48' -and $backgroundAnimatorSource -match 'resetParticle' -and $backgroundAnimatorSource -match 'smoothstep') 'El fondo no conserva sus luciérnagas con trayectorias y transiciones suaves.'
Assert ($backgroundAnimatorSource -match 'fadeStart' -and $backgroundAnimatorSource -match 'pulseRate' -and $backgroundAnimatorSource -notmatch 'AudioOutput|updateWaves|updateGrid') 'Las partículas no varían su altura de desaparición y brillo o todavía dependen de audio/ondas/malla.'
Assert ($backgroundAnimatorSource -match 'math\.random\(\)\s*<\s*0\.30' -and $backgroundAnimatorSource -match 'currentSizeScale.*targetSizeScale') 'No se conserva la distribución 70/30 o la transición gradual de tamaño.'
Assert ($backgroundAnimatorSource -match 'updateThermalTargets' -and $backgroundAnimatorSource -match "mode ~= 'thermal'" -and $backgroundAnimatorSource -match "measureValue\('FRAME_TIME'\)" -and $backgroundAnimatorSource -match 'smoothness \* 0\.70 \+ activity \* 0\.30' -and $backgroundAnimatorSource -match 'invalidFrameSamples >= 3') 'El modo térmico no relaciona sensores validados, fluidez y actividad o conserva frame time obsoleto.'
Assert ($backgroundAnimatorSource -match 'targetCount >= currentCount and 0\.08 or 0\.035' -and $backgroundAnimatorSource -match "SetOptionGroup.*AmbientParticles.*ImageTint") 'El modo térmico no suaviza densidad/color o no actualiza el tinte del grupo.'
Assert ($backgroundAnimatorSource -match 'thermalMinimumParticles' -and $backgroundAnimatorSource -match 'thermalMaximumParticles' -and $backgroundAnimatorSource -match 'gpuProtectionThreshold' -and $backgroundAnimatorSource -match 'protection \* 0\.82') 'El modo térmico no usa parámetros propios o no reduce carga ante saturación.'

$testRoot = Join-Path $root 'build\tests'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$syntheticProfile = [ordered]@{
    schemaVersion=2; language='es-MX'; bridgePort=27843; unavailableValue=-1
    computer=[ordered]@{manufacturer='Equipo';model='Prueba';name='TEST'}
    cpu=[ordered]@{name='CPU de prueba';physicalCores=6;logicalProcessors=8}
    gpu=[ordered]@{name='GPU de prueba'}
    storage=[ordered]@{friendlyName='Unidad';mediaType='SSD';busType='NVMe'}
    storageLabel='NVME'
    monitor=[ordered]@{deviceName='\\.\DISPLAY_TEST';primary=$false;x=1920;y=0;width=1920;height=1080}
    mappings=[ordered]@{}
    appearance=[ordered]@{backgroundEffect=[ordered]@{enabled=$true;mode='manual';particleCount=26;speed=0.65;sizeScale=1.0;color='255,112,20';updateFps=10}}
    cores=@(
        [ordered]@{displayIndex=0;logicalIndex=0;type='performance';key='a';available=$true},
        [ordered]@{displayIndex=1;logicalIndex=1;type='performance';key='b';available=$true},
        [ordered]@{displayIndex=2;logicalIndex=3;type='efficiency';key='c';available=$true},
        [ordered]@{displayIndex=3;logicalIndex=7;type='generic';key='d';available=$true}
    )
    displaySummary=[ordered]@{detectedLogicalProcessors=8;monitoredLogicalProcessors=4;performanceLogicalProcessors=2;efficiencyLogicalProcessors=1;performancePhysicalCores=2;efficiencyPhysicalCores=1}
    features=[ordered]@{processorPanelVisible=$true;performancePanelVisible=$true;clock=$true;compactOverlay=$false}
}
$profilePath = Join-Path $testRoot 'profile.json'
$syntheticProfile | ConvertTo-Json -Depth 8 | Set-Content $profilePath -Encoding UTF8
$skinRoot = Join-Path $testRoot 'Skin\AlienGamerMode'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Build-AdaptiveSkin.ps1') -ProfilePath $profilePath -OutputDirectory $skinRoot | Out-Null
$ini = Get-Content (Join-Path $skinRoot 'AlienGamerMode.ini') -Raw
Assert (@([regex]::Matches($ini,'(?m)^\[COREUSE\d+\]$')).Count -eq 4) 'La skin no generó exactamente los cuatro procesadores con sensor.'
Assert ($ini -match '(?m)^Text=P-CORE 0$') 'Falta P-CORE 0.'
Assert ($ini -match '(?m)^Text=E-CORE 3$') 'No conservó el índice lógico real E-CORE 3.'
Assert ($ini -match '(?m)^Text=CORE 7$') 'No aplicó etiqueta genérica al procesador sin clasificación.'
Assert ($ini -notmatch '(?m)^Text=.*CORE 2$') 'Mostró un procesador ausente.'
Assert ($ini -match '(?m)^WindowWidth=1920$' -and $ini -match '(?m)^WindowHeight=1080$') 'No adaptó la ventana al monitor sintético.'
Assert ($ini -match '(?m)^WindowX=1920$' -and $ini -match '(?m)^WindowY=0$') 'No conservó las coordenadas virtuales del monitor elegido.'
Assert ($ini -match '(?ms)^\[MeterBackground\]\r?\nMeter=Shape\r?\nShape=Rectangle 0,0,1920,1080') 'El generador dañó o dimensionó incorrectamente el fondo completo.'
Assert ($ini -match '(?m)^KeepOnScreen=0$') 'Rainmeter podría limitar la skin al monitor principal.'
Assert ($ini -match '(?ms)^\[HWiNFO_BRIDGE\].*?^URL=http://127\.0\.0\.1:27843/$') 'El generador dañó el encabezado o URL del puente de sensores.'
Assert ($ini -match '(?ms)^\[VRAM_USED_MB\].*?^StringIndex=11$') 'El índice dinámico de VRAM usada es incorrecto.'
Assert ($ini -match '(?ms)^\[GPU_POWER_ALERT\].*?^StringIndex=18$') 'El generador perdió el último indicador de alerta.'
Assert ($ini -match '¡EXCELENTE!' -and $ini -match 'ATENCIÓN' -and $ini -notmatch 'Â|Ã') 'La generación dañó los caracteres UTF-8 de la interfaz.'
Assert ($ini -match 'MONITOR TÉRMICO EN VIVO' -and $ini -match 'NÚCLEOS FÍSICOS') 'Los textos visibles no conservan la acentuación correcta.'
$iniBytes = [IO.File]::ReadAllBytes((Join-Path $skinRoot 'AlienGamerMode.ini'))
Assert ($iniBytes.Length -ge 2 -and $iniBytes[0] -eq 255 -and $iniBytes[1] -eq 254) 'La skin debe guardarse como Unicode UTF-16 LE para Rainmeter.'
$generatedClockBytes = [IO.File]::ReadAllBytes((Join-Path $skinRoot '@Resources\MatrixClock.lua'))
Assert (-not ($generatedClockBytes.Length -ge 3 -and $generatedClockBytes[0] -eq 0xEF -and $generatedClockBytes[1] -eq 0xBB -and $generatedClockBytes[2] -eq 0xBF)) 'El reloj generado recuperó un BOM incompatible con Lua de Rainmeter.'
$generatedAnimator = Join-Path $skinRoot '@Resources\RingAnimator.lua'
Assert (Test-Path $generatedAnimator) 'La skin generada no incluye el animador de anillos.'
Assert ($ini -match '(?ms)^\[SMOOTH_GPU_USE\].*?^UpdateDivider=1$' -and $ini -match '(?ms)^\[SMOOTH_COREUSE0\].*?^UpdateDivider=1$') 'La interpolación visual no se ejecutará a 10 FPS.'
Assert ($ini -match '(?ms)^\[Ring_GPU_USE\].*?^MeasureName=SMOOTH_GPU_USE$' -and $ini -match '(?ms)^\[Ring_CORETEMP0\].*?^MeasureName=SMOOTH_COREUSE0$') 'Los anillos no usan las medidas visuales interpoladas.'
Assert ($ini -notmatch 'MONITORIZADOS\s*$') 'La leyenda híbrida invade el panel de estado con texto redundante.'
Assert ($ini -match '(?ms)^\[GameStatusBackground\].*?^Shape=Rectangle 720,575,900,75,18') 'El panel flotante no quedó 10 px más arriba.'
Assert ($ini -match '(?ms)^\[Outline_CORE0\].*?^Y=690$') 'La primera fila de procesadores no quedó 30 px más abajo.'
Assert ($ini -match '(?m)^RegExp=.*' -and @([regex]::Matches(([regex]::Match($ini,'(?m)^RegExp=(.*)$').Groups[1].Value),'\(\-\?\[0\-9\]')).Count -ge 0) 'No generó el contrato del puente.'
Assert ($ini -match 'SetOptionGroup OLEDShift') 'No protegió el fondo fijo durante el pixel shift.'
Assert ($ini -notmatch '(?m)^Plugin=RunCommand$' -and $ini -notmatch '(?m)^LeftMouseUpAction=\["C:\\Windows\\System32\\WindowsPowerShell' -and @([regex]::Matches($ini,'(?m)^LeftMouseUpAction=\["C:\\Windows\\System32\\wscript\.exe"')).Count -ge 5) 'Los botones no usan el iniciador sin consola o aún ejecutan PowerShell directamente.'
Assert ($ini -notmatch 'AlienGamerMode-Off' -and $ini -match 'AlienGamerModeLauncher\.vbs') 'OFF todavía depende de la tarea o de una consola visible.'
Assert ($ini -match '(?ms)^\[MeterOffButton\].*?^MouseActionCursor=1' -and $ini -match '(?ms)^\[MeterRecordButton\].*?^MouseActionCursor=1') 'OFF o Grabar no tienen un área clicable explícita.'
Assert ($commandSource -match '(?s)if \(\$Stop.*?!DeactivateConfig.*?AlienGamerMode') 'El comando OFF no conserva un respaldo visual cuando el agente no responde.'
Assert ($commandSource -match 'stop-monitor\.request\.json' -and $agentSource -match 'Test-StopRequest') 'OFF no cuenta con un canal alterno fiable entre Rainmeter y el agente.'
Assert ($launcherSource -match 'shell\.Run command, 0, False' -and $launcherSource -match 'Case "activate"' -and $launcherSource -match 'Case "stop"') 'El iniciador no mantiene el agente y las órdenes completamente ocultos.'
Assert ($installerSource -match '\$wscript' -and $installerSource -match 'AlienGamerModeLauncher\.vbs' -and $installerSource -notmatch 'New-Shortcut \$desktopLink \$powershell \$args') 'Los accesos directos todavía hospedan el agente en una consola de PowerShell.'
Assert ($commandSource -match 'AddSeconds\(3\)' -and $commandSource -match 'Stop-AlienGamerMode\.ps1' -and $fallbackStopSource -match 'Stop-Process -Name Rainmeter' -and $fallbackStopSource -match 'Stop-Process -Name HWiNFO64') 'OFF no limita la espera o carece de limpieza independiente cuando el agente no responde.'
Assert ($agentSource -match 'if \(\$stopEvent\.WaitOne\(0\) -or \(Test-StopRequest\)\) \{ Stop-Monitor \}') 'El agente no procesa la solicitud de OFF mediante la misma función que el menú de bandeja.'
Assert ($recorderSource -match "LOCALAPPDATA 'AlienGamerMode'" -and $recorderSource -match "Status = 'recording'" -and $recorderSource -match "Status = 'finalizing'") 'La grabación no conserva un estado compartido y persistente.'
Assert ($recorderSource -match 'preEventBufferSeconds' -and $recorderSource -match 'BufferWorker' -and $recorderSource -match 'MarkIncident' -and $recorderSource -match 'Get-StabilityMetrics' -and $recorderSource -match 'Datos_brutos' -and $recorderSource -match 'Protect-SystemMetadata') 'Event Intelligence no incorpora búfer previo, incidentes, estabilidad, datos brutos y privacidad.'
Assert ($recorderSource -match 'function New-VisualReport' -and $recorderSource -match 'function New-VisualChartSvg' -and $recorderSource -match 'saveVisualReportBesideReport' -and $recorderSource -match 'Text\.UTF8Encoding\(\$false\)') 'El reporte visual autónomo no está integrado o no garantiza UTF-8.'
Assert ($recorderSource.Contains("PSObject.Properties['TimestampLocal']") -and $recorderSource -match 'TryParseExact' -and $recorderSource -match 'if \(-not \$parsed\) \{ continue \}') 'El reporte no protege listas de incidentes vacías o fechas inválidas.'
Assert ($recorderSource -notmatch '\[datetime\]::Parse\(' -and $recorderSource -match '\$validPreRows' -and $recorderSource -match "PSObject.Properties\['FechaHora'\]") 'El búfer previo todavía puede fallar con fechas vacías o inválidas.'
Assert ($agentSource -match "tray\.stopMonitor" -and $agentSource -match "tray\.finishRecording" -and $agentSource -match "tray\.finalizingReport") 'La bandeja no refleja los estados dinámicos del monitor y la grabación.'
Assert ($agentSource -notmatch 'backgroundMenu|Set-BackgroundMode|Show-BackgroundSettings' -and $layoutEditorSource -match 'backgroundMode' -and $layoutEditorSource -match 'particleCount' -and $layoutEditorSource -match 'ColorDialog') 'El fondo debe configurarse por pantalla desde el editor y no mediante un menú global ambiguo.'
Assert ($agentSource -match 'tray\.hardwareConfiguration' -and $agentSource -match 'function Show-HardwareSettings' -and $agentSource -match 'targetMonitorId' -and $agentSource -match 'preferredStorage') 'La bandeja no permite reconfigurar pantalla, GPU y almacenamiento sin reinstalar.'
Assert ($agentSource -notmatch '\$modulesItem\s*=' -and $agentSource -match 'tray\.displayLayout') 'La bandeja conserva un menú rápido de módulos ambiguo en modo multidisplay.'
Assert ((Test-Path (Join-Path $root 'src\AlienGamer.MultiDisplay.psm1')) -and (Test-Path (Join-Path $root 'src\Build-MultiDisplaySkins.ps1')) -and (Test-Path (Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1'))) 'Faltan componentes del editor visual o del motor multidisplay.'
Assert ($agentSource -match 'function Show-DisplayLayoutEditor' -and $agentSource -match 'Build-MultiDisplaySkins\.ps1' -and $agentSource -match 'Activate-DisplaySkins' -and $agentSource -match 'tray\.displayLayout') 'La bandeja no integra el editor visual y la activación multidisplay.'
Assert ($installerSource -match '\$config\.schemaVersion\s*=\s*3' -and $installerSource -match 'Copy-Item -LiteralPath \$defaultConfig -Destination \$configPath -Force' -and $installerSource -match 'displayViews' -and $installerSource -match 'ConvertTo-Json -Depth 20') 'La instalación no crea de forma segura la configuración multidisplay limpia.'
Assert ($agentSource -match 'function Initialize-MultiDisplayConfiguration' -and $agentSource -match 'Configuración visual migrada' -and $agentSource -match 'Set-AgentConfigProperty.*processorPanelVisible.*\$true') 'El agente no repara una configuración 1.4 que haya sobrevivido al instalador.'
Assert ($agentSource -match 'function Complete-DisplayLayoutEditor' -and $agentSource -match 'RedirectStandardError' -and $agentSource -notmatch 'Show-AlienGamerLayoutEditor\.ps1[^\r\n]+-Wait') 'El editor de pantallas todavía puede bloquear el menú de bandeja.'
Assert ($layoutEditorSource -match '\[switch\]\$HideConsole' -and $layoutEditorSource -match 'GetConsoleWindow' -and $layoutEditorSource -match 'ShowWindow' -and $agentSource -match 'WindowStyle Minimized' -and $agentSource -match '-HideConsole') 'El editor no separa correctamente la consola oculta de su ventana gráfica.'
Assert ($layoutEditorSource -match 'ExportScreenshotPath' -and $layoutEditorSource -match 'DrawToBitmap') 'El editor no puede exportar una captura verificable para la documentación.'
Assert ($layoutEditorSource -match 'Start-Interaction' -and $layoutEditorSource -match "'resize'" -and $layoutEditorSource -match 'Test-Geometry' -and $layoutEditorSource -match 'IntersectsWith' -and $layoutEditorSource -match 'invalidPlacement') 'El editor no permite redimensionar o no impide solapamientos y salidas de pantalla.'
Assert ($layoutEditorSource -match 'header\.visible=\$true' -and $layoutEditorSource -match 'definitions\[\$name\]\.fixed' -and $layoutEditorSource -notmatch "selectableModuleNames=@\('header'") 'El encabezado no está protegido como módulo obligatorio y fijo.'
Assert ($layoutEditorSource -match 'preset\.Add_SelectedIndexChanged' -and $layoutEditorSource -match 'Set-AGLayoutPreset.*CanvasWidth' -and $layoutEditorSource -match 'particleCount' -and $layoutEditorSource -match 'ColorDialog') 'Los diseños no se previsualizan al seleccionarse o faltan controles del fondo manual.'
Assert ($layoutEditorSource -match 'Invoke-EditorAction' -and $layoutEditorSource -match 'Get-GeometryIssue' -and $layoutEditorSource -match '\$box\.Capture=\$true') 'El editor no protege sus eventos, no identifica geometría inválida o puede perder el arrastre de redimensionado.'
Assert ($layoutEditorSource -match 'Write-EditorError' -and $layoutEditorSource -match 'Update-SaveAvailability' -and $layoutEditorSource -notmatch '\[Console\]::Error\.WriteLine') 'El editor todavía puede ocultar el error real detrás de una consola nula o permitir guardar geometría inválida.'
Assert ($agentSource -match 'layoutEditorStartedAt' -and $agentSource -match 'MainWindowHandle -eq 0' -and $agentSource -match 'libero el menu' -and $agentSource -match 'Error controlado en el ciclo de bandeja') 'El menú puede quedar deshabilitado o una excepción del temporizador puede escapar si el editor no publica una ventana.'
Assert ($agentSource -match 'agent-diagnostic\.log' -and $agentSource -match 'stage=build begin' -and $agentSource -match 'stage=activate complete' -and $agentSource -match 'APPLY failed stage=') 'La aplicación en caliente no deja diagnóstico por etapas.'
Assert ($layoutEditorSource -match '\[char\]0x2198' -and $layoutEditorSource -match 'ThreadException' -and $layoutEditorSource -match 'layout-editor\.trace\.log') 'El editor no protege excepciones de interfaz, no deja traza del guardado o conserva el símbolo Unicode incompatible con Windows PowerShell 5.1.'
Assert ($agentSource -match '\[switch\]\$OpenLayoutEditor' -and $launcherSource -match 'activate-layout' -and $installerSource -match 'openLayoutAfterClose\s*=\s*\$true') 'La instalación no abre el editor de distribución al finalizar.'
Assert ($agentSource -match "tray\.markIncident" -and $agentSource -match "Invoke-RecorderCommand '-StartBuffer'" -and $agentSource -match "Invoke-RecorderCommand '-StopBuffer'") 'La bandeja no controla marcas o ciclo del búfer previo.'
Assert ($agentSource -match "dialog\.waitApply" -and $agentSource -match 'Complete-DisplayLayoutEditor' -and $agentSource -match 'Refresh-DisplaySkins') 'El editor no informa progreso o no actualiza todas las vistas al guardar.'
Assert ($multiDisplayBuildSource -match 'ReuseValidatedProfile' -and $agentSource -match 'Refresh-DisplaySkins -ReuseValidatedProfile') 'Los cambios visuales todavía fuerzan una resolución completa y lenta de sensores.'
Assert ($multiDisplayBuildSource -match 'sharedResources=Join-Path \$OutputDirectory ''@Resources''' -and $multiDisplayBuildSource -match 'RingAnimator\.lua' -and $multiDisplayBuildSource -match 'ParticleGlow\.png') 'La compilación multidisplay no publica los recursos visuales en el @Resources raíz de Rainmeter.'
Assert ($agentSource -match 'function Show-DisplayApplyOverlays' -and $agentSource -match 'dialog\.applyingLayout' -and $agentSource -match 'Show-DisplayApplyOverlays') 'La aplicación de una distribución no muestra progreso sobre la pantalla de destino.'
Assert ($agentSource -notmatch "Items\.Add\('Salir del modo'\)" -and $agentSource -match "tray\.closeApp") 'La bandeja conserva acciones redundantes o nombres ambiguos.'
Assert ($agentSource -match 'function Set-AppLanguage' -and $agentSource -match "Set-AppLanguage 'es-MX'" -and $agentSource -match "Set-AppLanguage 'en-US'" -and $agentSource -match 'Refresh-DisplaySkins') 'La bandeja no permite cambiar el idioma en caliente y conservarlo.'
Assert ($agentSource -match "bridge\.pid" -and $agentSource -match 'function Test-MonitorActive') 'La bandeja no usa el proceso real del puente para detectar el monitor activo.'

# Todo diseño predefinido debe ser válido por sí mismo en las dos resoluciones
# reales de prueba y en una pantalla vertical compacta.
Import-Module (Join-Path $root 'src\AlienGamer.MultiDisplay.psm1') -Force
Add-Type -AssemblyName System.Drawing
$moduleDefinitions=Get-AGModuleDefinitions
foreach($size in @(@(2048,1280),@(2560,1440),@(1080,1920))){
    foreach($presetName in @('full-horizontal','essential-horizontal','essential-vertical','performance-only','temperatures-only')){
        $presetView=New-AGDisplayView -Preset $presetName
        Set-AGLayoutPreset -View $presetView -Preset $presetName -CanvasWidth $size[0] -CanvasHeight $size[1]|Out-Null
        $visibleNames=@($moduleDefinitions.Keys|Where-Object {$presetView.modules.$_.visible})
        foreach($moduleName in $visibleNames){
            $module=$presetView.modules.$moduleName
            Assert ($module.x-ge8 -and $module.y-ge8 -and ($module.x+$module.width)-le($size[0]-8) -and ($module.y+$module.height)-le($size[1]-8)) "El preset $presetName deja $moduleName fuera de $($size[0])x$($size[1])."
            $candidate=[Drawing.RectangleF]::new([single]($module.x-4),[single]($module.y-4),[single]($module.width+8),[single]($module.height+8))
            foreach($otherName in $visibleNames){
                if($otherName-eq$moduleName){continue}
                $other=$presetView.modules.$otherName
                $otherRect=[Drawing.RectangleF]::new([single]$other.x,[single]$other.y,[single]$other.width,[single]$other.height)
                Assert (-not$candidate.IntersectsWith($otherRect)) "El preset $presetName solapa $moduleName con $otherName en $($size[0])x$($size[1])."
            }
        }
        if($presetName-in@('essential-horizontal','essential-vertical')){Assert (-not$presetView.modules.controls.visible) "El preset $presetName no debe mostrar controles."}
        if($presetName-eq'essential-vertical'){
            $headerCenter=$presetView.modules.header.x+($presetView.modules.header.width/2.0)
            Assert ([Math]::Abs($headerCenter-($size[0]/2.0))-le1) 'El encabezado vertical no está centrado.'
        }
    }
}
Assert ($ini -match '(?m)^\[MeterSubtitle\]$' -and $ini -match 'EQUIPO PRUEBA') 'No generó el modelo dinámico del equipo.'
Assert ($ini -match '(?ms)^\[MeterSignature\]\r?\nMeter=Image.*?^ImageName=#@#AlienmauSignature\.png$' -and $ini -notmatch '(?ms)^\[MeterSignature\].*?FontFace=Dali') 'La firma todavía depende de instalar o redistribuir Dali.'
Assert (Test-Path (Join-Path $skinRoot '@Resources\AlienmauSignature.png')) 'La skin generada no contiene la firma gráfica independiente.'
Assert (Test-Path (Join-Path $skinRoot '@Resources\BackgroundAnimator.lua')) 'La skin generada no contiene el animador ambiental.'
Assert ($ini -match '(?ms)^\[BackgroundScript\].*?^UpdateDivider=1$' -and @([regex]::Matches($ini,'(?m)^\[Particle\d+\]$')).Count -eq 48 -and $ini -notmatch '(?m)^\[AudioOutput|^\[AmbientBackground\]') 'El fondo no conserva 48 partículas ligeras a 10 FPS o aún incluye el concepto anterior.'
Assert ($ini -match '(?m)^BackgroundEffectMode=manual$' -and $ini -match '(?ms)^\[BackgroundScript\].*?^Mode=#BackgroundEffectMode#$') 'La skin generada no contiene el selector persistente del modo de fondo.'
Assert (Test-Path (Join-Path $skinRoot '@Resources\ParticleGlow.png')) 'La skin generada no contiene el degradado radial de las luciérnagas.'
Assert ($ini -match '(?m)^GlassFill=22,27,38,145$' -and $ini -match '(?ms)^\[Block_RAM\].*?Fill Color #GlassFill#.*?^Shape2=Line' -and $ini -match '(?ms)^\[Block_CORES\].*?Fill Color 22,27,38,158') 'Los contenedores no conservan el glassmorfismo transparente y legible.'
Assert ($ini -match '(?ms)^\[Particle1\].*?^TransformationMatrix=' -and $ini -match '(?ms)^\[Particle1\].*?^Group=AmbientParticles\|OLEDShift') 'Las luciérnagas no responden a resolución o protección OLED.'
Assert ($ini -match '(?ms)^\[Block_CORES\].*?^Group=.*ProcessorPanel.*Module_processors.*OLEDShift' -and $ini -match '(?ms)^\[GameStatusBackground\].*?^Group=.*PerformancePanel.*Module_performance.*OLEDShift') 'Los módulos configurables no quedaron agrupados para su presentación.'
Assert ($ini -match '(?ms)^\[ClockDigit1\].*?^Group=.*MatrixClock.*ClockPanel.*Module_clock.*OLEDShift' -and $ini -match '(?ms)^\[ClockColons\].*?^Group=.*ClockPanel.*Module_clock.*OLEDShift') 'El reloj no quedó agrupado como módulo configurable.'
Assert ($ini -match '(?ms)^\[MatrixDigitShapes\].*?^Shape35=' -and @([regex]::Matches($ini,'(?m)^MeterStyle=MatrixDigitShapes$')).Count -eq 6) 'El reloj no predeclara las 35 celdas de sus seis dígitos.'
foreach ($clockDigit in 1..6) {
    Assert ($ini -match ('(?ms)^\[ClockDigit' + $clockDigit + '\].*?^Shape35=.*?(?=^\[|\z)')) "ClockDigit$clockDigit no contiene físicamente sus 35 celdas Shape."
}
$recordHitBlock = [regex]::Match($ini,'(?ms)^\[HitArea_Record\].*?(?=^\[|\z)').Value
$offHitBlock = [regex]::Match($ini,'(?ms)^\[HitArea_Off\].*?(?=^\[|\z)').Value
Assert ($recordHitBlock -match 'MouseActionCursor=1' -and $offHitBlock -match 'MouseActionCursor=1') 'Faltan las zonas superiores de captura para Grabar u OFF.'
Assert ($recordHitBlock -match 'RecordHover' -and $offHitBlock -match 'OffHover') 'Las zonas superiores no activan las transiciones de interacción.'
Assert ($recordHitBlock -match ('W=' + [regex]::Escape(([string][math]::Ceiling(205 * [math]::Min(1920/1711,1080/1023)))))) 'La zona clicable de Grabar no cubre su ancho expandido.'
Assert ($recordHitBlock -notmatch 'TransformationMatrix=' -and $offHitBlock -notmatch 'TransformationMatrix=') 'Las zonas clicables no deben volver a escalarse con TransformationMatrix.'
Assert ($ini.TrimEnd().EndsWith($offHitBlock.TrimEnd())) 'Las zonas clicables no quedaron por encima de todos los medidores.'

Import-Module (Join-Path $root 'src\AlienGamer.MultiDisplay.psm1') -Force
$customView = New-AGDisplayView -Id 'display-test' -MonitorId 'MONITOR_TEST' -MonitorDeviceName '\\.\DISPLAY_TEST'
$customView.layoutPreset = 'custom'
$customView.modules.ram.x = 95
$customView.modules.ram.y = 210
$customView.modules.ram.width = 820
$customView.modules.ram.height = 830
$customView.modules.clock.visible = $false
$syntheticProfile | Add-Member NoteProperty layout $customView -Force
$layoutProfilePath = Join-Path $testRoot 'profile-layout.json'
$layoutSkinRoot = Join-Path $testRoot 'LayoutSkin\AlienGamerMode'
$syntheticProfile | ConvertTo-Json -Depth 12 | Set-Content $layoutProfilePath -Encoding UTF8
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Build-AdaptiveSkin.ps1') -ProfilePath $layoutProfilePath -OutputDirectory $layoutSkinRoot | Out-Null
$layoutIni = Get-Content (Join-Path $layoutSkinRoot 'AlienGamerMode.ini') -Raw
$layoutRam = [regex]::Match($layoutIni,'(?ms)^\[Block_RAM\].*?(?=^\[|\z)').Value
$ramMatrixMatch=[regex]::Match($layoutRam,'(?m)^TransformationMatrix=([^;]+);[^;]+;[^;]+;[^;]+;([^;]+);')
Assert ($layoutRam -match '(?m)^Group=.*Module_ram' -and $ramMatrixMatch.Success -and [double]::Parse($ramMatrixMatch.Groups[2].Value,[Globalization.CultureInfo]::InvariantCulture) -gt 70) 'El editor no traslada el módulo RAM a su posición personalizada.'
Assert ([double]::Parse($ramMatrixMatch.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture) -gt 2.0) 'El generador no aplica el tamaño personalizado del módulo.'
Assert ($layoutIni -match '(?ms)^\[ClockDigit1\].*?^Hidden=1\r?$' -and $layoutIni -match '(?m)^IfTrueAction=.*SetOptionGroup Module_ram TransformationMatrix') 'La visibilidad o el pixel shift no respetan el diseño personalizado.'
Assert ($layoutIni -match 'record-toggle" "#BridgeUrl#" "#CURRENTCONFIG#"') 'El botón Grabar no informa qué vista multidisplay inició la acción.'
$syntheticProfile.PSObject.Properties.Remove('layout')

$syntheticProfile.appearance.backgroundEffect.mode = 'thermal'
$thermalProfilePath = Join-Path $testRoot 'profile-thermal.json'
$thermalSkinRoot = Join-Path $testRoot 'ThermalSkin\AlienGamerMode'
$syntheticProfile | ConvertTo-Json -Depth 8 | Set-Content $thermalProfilePath -Encoding UTF8
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Build-AdaptiveSkin.ps1') -ProfilePath $thermalProfilePath -OutputDirectory $thermalSkinRoot | Out-Null
$thermalIni = Get-Content (Join-Path $thermalSkinRoot 'AlienGamerMode.ini') -Raw
Assert ($thermalIni -match '(?m)^BackgroundEffectMode=thermal$' -and $thermalIni -match '(?ms)^\[BackgroundScript\].*?^Mode=#BackgroundEffectMode#$') 'El generador no conserva el modo térmico seleccionado.'
Assert ($thermalIni -match '(?m)^BackgroundThermalMinimum=8$' -and $thermalIni -match '(?m)^BackgroundThermalMaximum=32$' -and $thermalIni -match '(?ms)^\[BackgroundScript\].*?^ThermalMaximumParticles=#BackgroundThermalMaximum#$') 'La skin térmica no recibe sus límites independientes.'
$syntheticProfile.appearance.backgroundEffect.mode = 'manual'

$syntheticProfile.language = 'en-US'
$englishProfilePath = Join-Path $testRoot 'profile-en.json'
$englishSkinRoot = Join-Path $testRoot 'EnglishSkin\AlienGamerMode'
$syntheticProfile | ConvertTo-Json -Depth 8 | Set-Content $englishProfilePath -Encoding UTF8
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Build-AdaptiveSkin.ps1') -ProfilePath $englishProfilePath -OutputDirectory $englishSkinRoot | Out-Null
$englishIni = Get-Content (Join-Path $englishSkinRoot 'AlienGamerMode.ini') -Raw
Assert ($englishIni -match 'LIVE THERMAL MONITOR' -and $englishIni -match 'SYSTEM USAGE' -and $englishIni -match 'PHYSICAL CORES' -and $englishIni -match 'RECORD EVENT' -and $englishIni -match 'LOW FLUIDITY') 'La skin inglesa conserva textos en español o no se generó correctamente.'
Assert ($englishIni -notmatch 'MONITOR TÉRMICO|USO DEL SISTEMA|NÚCLEOS FÍSICOS|GRABAR EVENTO|BAJA FLUIDEZ') 'La skin inglesa contiene textos visibles importantes sin traducir.'

$syntheticProfile.language = 'es-MX'
$syntheticProfile.features.processorPanelVisible = $false
$syntheticProfile.features.performancePanelVisible = $false
$syntheticProfile.features.clock = $false
$hiddenProfilePath = Join-Path $testRoot 'profile-hidden.json'
$hiddenSkinRoot = Join-Path $testRoot 'HiddenSkin\AlienGamerMode'
$syntheticProfile | ConvertTo-Json -Depth 8 | Set-Content $hiddenProfilePath -Encoding UTF8
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Build-AdaptiveSkin.ps1') -ProfilePath $hiddenProfilePath -OutputDirectory $hiddenSkinRoot | Out-Null
$hiddenIni = Get-Content (Join-Path $hiddenSkinRoot 'AlienGamerMode.ini') -Raw
Assert ($hiddenIni -match '(?ms)^\[Block_CORES\].*?^Hidden=1\r?$' -and $hiddenIni -match '(?ms)^\[Outline_CORE0\].*?^Hidden=1\r?$') 'Ocultar Procesadores / carga no afecta todo el módulo.'
Assert ($hiddenIni -match '(?ms)^\[GameStatusBackground\].*?^Hidden=1\r?$' -and $hiddenIni -match '(?ms)^\[FPSValue\].*?^Hidden=1\r?$' -and $hiddenIni -match '(?ms)^\[AlertCPUActive\].*?^Hidden=1\r?$') 'Ocultar FPS y alertas no afecta todo el panel flotante.'
Assert ($hiddenIni -match '(?ms)^\[ClockDigit1\].*?^Hidden=1\r?$' -and $hiddenIni -match '(?ms)^\[ClockColons\].*?^Hidden=1\r?$') 'Ocultar el reloj no afecta todos sus elementos.'

$syntheticProfile.features.processorPanelVisible = $true
$syntheticProfile.features.performancePanelVisible = $true
$syntheticProfile.features.clock = $true
$syntheticProfile.features.compactOverlay = $true
$compactProfilePath = Join-Path $testRoot 'profile-compact.json'
$compactSkinRoot = Join-Path $testRoot 'CompactSkin\AlienGamerMode'
$syntheticProfile | ConvertTo-Json -Depth 8 | Set-Content $compactProfilePath -Encoding UTF8
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Build-AdaptiveSkin.ps1') -ProfilePath $compactProfilePath -OutputDirectory $compactSkinRoot | Out-Null
$compactIni = Get-Content (Join-Path $compactSkinRoot 'AlienGamerMode.ini') -Raw
$compactPerformanceBlock=[regex]::Match($compactIni,'(?ms)^\[GameStatusBackground\].*?(?=^\[|\z)').Value
Assert ($compactIni -match '(?ms)^\[GameStatusBackground\].*?^X=-315\r?$.*?^Y=-101\r?$' -and $compactIni -match '(?ms)^\[FPSValue\].*?^X=493\r?$.*?^Y=509\r?$') 'El panel compacto no centra FPS y frame time en el lienzo de referencia.'
Assert ($compactIni -match '(?ms)^\[Block_RAM\].*?^Hidden=1\r?$' -and $compactIni -match '(?ms)^\[MeterTitle\].*?^Hidden=1\r?$' -and $compactIni -match '(?ms)^\[HitArea_Record\].*?^Hidden=1\r?$') 'El modo compacto deja capas completas o controles flotando alrededor del panel FPS.'
Assert ($compactPerformanceBlock -match '(?m)^Group=.*CompactOnly' -and $compactPerformanceBlock -notmatch '(?m)^Hidden=1') 'El modo compacto ocultó el único panel que debe permanecer visible.'

if ($failures.Count) {
    $failures | ForEach-Object { Write-Host "FALLO: $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'OK: validación oficial completada.' -ForegroundColor Green
Write-Host 'Procesadores sintéticos visibles: 4 de 8 detectados; sin huecos inventados.'
