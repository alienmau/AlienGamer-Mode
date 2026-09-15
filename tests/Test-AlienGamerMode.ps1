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
Assert ($config.schemaVersion -eq 2) 'La configuración no usa schemaVersion 2.'
Assert ($config.dataSource.bridgePort -eq 27843) 'La edición oficial debe usar el puerto local 27843.'
Assert ($config.appearance.backgroundEffect.enabled -eq $true -and $config.appearance.backgroundEffect.updateFps -le 10) 'El fondo ambiental no tiene una configuración equilibrada y personalizable.'
Assert ($config.appearance.backgroundEffect.particleCount -ge 8 -and $config.appearance.backgroundEffect.particleCount -le 48 -and $config.appearance.backgroundEffect.speed -ge 0.2 -and $config.appearance.backgroundEffect.sizeScale -ge 0.7 -and $config.appearance.backgroundEffect.sizeScale -le 1.6 -and $config.appearance.backgroundEffect.color -match '^\d+,\d+,\d+$') 'Las luciérnagas no tienen cantidad, velocidad, tamaño y color configurables dentro de límites seguros.'
Assert ($config.features.processorPanelVisible -eq $true -and $config.features.performancePanelVisible -eq $true) 'Los módulos opcionales deben iniciar visibles en una instalación nueva.'
Assert (Test-Path (Join-Path $root 'src\Start-AlienGamerHWiNFO.ps1')) 'Falta el iniciador elevado de HWiNFO.'
$hwinfoLauncherSource = Get-Content (Join-Path $root 'src\Start-AlienGamerHWiNFO.ps1') -Raw
$installerSource = Get-Content (Join-Path $root 'installer\Install-AlienGamerMode.ps1') -Raw
$innoSource = Get-Content (Join-Path $root 'installer\AlienGamerMode.iss') -Raw
$uninstallerSource = Get-Content (Join-Path $root 'src\Uninstall-AlienGamerMode.ps1') -Raw
$agentSource = Get-Content (Join-Path $root 'src\AlienGamerModeAgent.ps1') -Raw
$discoverySource = Get-Content (Join-Path $root 'src\Discover-AlienGamerHardware.ps1') -Raw
$bridgeSource = Get-Content (Join-Path $root 'src\AlienGamerBridge.ps1') -Raw
$recorderSource = Get-Content (Join-Path $root 'src\AlienGamerEventRecorder.ps1') -Raw
Assert ($installerSource -notmatch 'New-ScheduledTaskAction[^\r\n]+-WorkingDirectory') 'La tarea elevada no debe depender de WorkingDirectory.'
Assert ($installerSource -match 'Settings\.Compatibility\s*=\s*2') 'La tarea debe usar compatibilidad Vista y el motor clasico.'
Assert ($installerSource -notmatch 'UseUnifiedSchedulingEngine\s*=') 'No se debe tocar UseUnifiedSchedulingEngine porque actualiza la tarea a Win7.'
Assert ($installerSource -match 'Set-Content -LiteralPath \$Path -Encoding ASCII') 'El INI de HWiNFO debe guardarse como ASCII sin BOM.'
Assert ($installerSource -match 'function Merge-MissingConfiguration' -and $installerSource -match 'Merge-MissingConfiguration \$config \$configDefaults') 'Las actualizaciones no incorporan parámetros nuevos a configuraciones existentes.'
Assert ($installerSource -match 'Desinstalar AlienGamer Mode\.lnk' -and $installerSource -match 'installedDocs') 'El paquete no instala documentación o acceso de desinstalación.'
Assert ($installerSource -match '(?s)\$form\.ShowDialog\(\).*?if \(\$script:launchAfterClose\)' -and $installerSource -notmatch '\$taskbarCheck\.Checked\) \{ \[Windows\.Forms\.MessageBox\]::Show\(''Windows 11') 'El agente o los avisos todavía pueden superponerse al instalador.'
Assert ($innoSource -match '-WindowStyle Hidden' -and $innoSource -notmatch 'Flags:[^\r\n]*runhidden' -and $installerSource -match '\$form\.TopMost\s*=\s*\$true') 'El empaquetador puede ocultar nuevamente el formulario de configuración.'
Assert ($uninstallerSource -match "ProgramData 'AlienGamerMode\\App'" -and $uninstallerSource -match 'SkinPath=') 'El desinstalador no apunta a las rutas reales de programa y skin.'
Assert ($agentSource -match '\.GetEnumerator\(\)') 'La escritura de posición de Rainmeter debe enumerar claves sin crear líneas vacías.'
Assert ($agentSource -match "'!Move'.*profile\.monitor\.x.*profile\.monitor\.y") 'El agente no fuerza la skin al monitor elegido después de activarla.'
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

$testRoot = Join-Path $root 'build\tests'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$syntheticProfile = [ordered]@{
    schemaVersion=2; bridgePort=27843; unavailableValue=-1
    computer=[ordered]@{manufacturer='Equipo';model='Prueba';name='TEST'}
    cpu=[ordered]@{name='CPU de prueba';physicalCores=6;logicalProcessors=8}
    gpu=[ordered]@{name='GPU de prueba'}
    storage=[ordered]@{friendlyName='Unidad';mediaType='SSD';busType='NVMe'}
    storageLabel='NVME'
    monitor=[ordered]@{deviceName='\\.\DISPLAY_TEST';primary=$false;x=1920;y=0;width=1920;height=1080}
    mappings=[ordered]@{}
    cores=@(
        [ordered]@{displayIndex=0;logicalIndex=0;type='performance';key='a';available=$true},
        [ordered]@{displayIndex=1;logicalIndex=1;type='performance';key='b';available=$true},
        [ordered]@{displayIndex=2;logicalIndex=3;type='efficiency';key='c';available=$true},
        [ordered]@{displayIndex=3;logicalIndex=7;type='generic';key='d';available=$true}
    )
    displaySummary=[ordered]@{detectedLogicalProcessors=8;monitoredLogicalProcessors=4;performanceLogicalProcessors=2;efficiencyLogicalProcessors=1;performancePhysicalCores=2;efficiencyPhysicalCores=1}
    features=[ordered]@{processorPanelVisible=$true;performancePanelVisible=$true;clock=$true}
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
Assert ($ini -notmatch '(?m)^Plugin=RunCommand$' -and @([regex]::Matches($ini,'(?m)^LeftMouseUpAction=\["C:\\Windows\\System32\\WindowsPowerShell')).Count -ge 5) 'Los botones siguen dependiendo de RunCommand o no ejecutan PowerShell directamente.'
Assert ($ini -notmatch 'AlienGamerMode-Off' -and $ini -match 'AlienGamerModeCommand\.ps1') 'OFF todavía depende de la tarea de la edición estable.'
Assert ($ini -match '(?ms)^\[MeterOffButton\].*?^MouseActionCursor=1' -and $ini -match '(?ms)^\[MeterRecordButton\].*?^MouseActionCursor=1') 'OFF o Grabar no tienen un área clicable explícita.'
$commandSource = Get-Content (Join-Path $root 'src\AlienGamerModeCommand.ps1') -Raw
Assert ($commandSource -match '(?s)if \(\$Stop.*?!DeactivateConfig.*?AlienGamerMode') 'El comando OFF no conserva un respaldo visual cuando el agente no responde.'
Assert ($commandSource -match 'stop-monitor\.request\.json' -and $agentSource -match 'Test-StopRequest') 'OFF no cuenta con un canal alterno fiable entre Rainmeter y el agente.'
Assert ($agentSource -match 'if \(\$stopEvent\.WaitOne\(0\) -or \(Test-StopRequest\)\) \{ Stop-Monitor \}') 'El agente no procesa la solicitud de OFF mediante la misma función que el menú de bandeja.'
Assert ($recorderSource -match "LOCALAPPDATA 'AlienGamerMode'" -and $recorderSource -match "Status = 'recording'" -and $recorderSource -match "Status = 'finalizing'") 'La grabación no conserva un estado compartido y persistente.'
Assert ($agentSource -match "'Detener monitor'" -and $agentSource -match "'Finalizar grabación'" -and $agentSource -match "'Finalizando reporte\.\.\.'") 'La bandeja no refleja los estados dinámicos del monitor y la grabación.'
Assert ($agentSource -match "'Fondo dinámico'" -and $agentSource -match "'Configurar luciérnagas\.\.\.'" -and $agentSource -match 'Show-BackgroundSettings' -and $agentSource -match 'BackgroundParticleSize' -and $agentSource -match 'Windows\.Forms\.TrackBar' -and $agentSource -match 'Windows\.Forms\.ColorDialog') 'La bandeja no permite activar y personalizar cantidad, velocidad, tamaño y color del fondo.'
Assert ($agentSource -match "'Módulos visibles'" -and $agentSource -match "'Procesadores / carga'" -and $agentSource -match "'FPS, frame time y alertas'" -and $agentSource -match "Add\('Reloj'\)" -and $agentSource -match 'Set-ModuleVisibility') 'La bandeja no permite personalizar y guardar los módulos visibles.'
Assert ($agentSource -match 'Espera un momento\.\.\. Aplicando la selección al monitor\.' -and $agentSource -match "'!HideMeterGroup'" -and $agentSource -match '\$profile\.features = \$config\.features') 'El cambio de módulos no informa progreso o sigue rehaciendo la detección completa.'
Assert ($agentSource -notmatch "Items\.Add\('Salir del modo'\)" -and $agentSource -match "Cerrar AlienGamer Mode") 'La bandeja conserva acciones redundantes o nombres ambiguos.'
Assert ($agentSource -match "bridge\.pid" -and $agentSource -match 'function Test-MonitorActive') 'La bandeja no usa el proceso real del puente para detectar el monitor activo.'
Assert ($ini -match '(?m)^\[MeterSubtitle\]$' -and $ini -match 'EQUIPO PRUEBA') 'No generó el modelo dinámico del equipo.'
Assert ($ini -match '(?ms)^\[MeterSignature\]\r?\nMeter=Image.*?^ImageName=#@#AlienmauSignature\.png$' -and $ini -notmatch '(?ms)^\[MeterSignature\].*?FontFace=Dali') 'La firma todavía depende de instalar o redistribuir Dali.'
Assert (Test-Path (Join-Path $skinRoot '@Resources\AlienmauSignature.png')) 'La skin generada no contiene la firma gráfica independiente.'
Assert (Test-Path (Join-Path $skinRoot '@Resources\BackgroundAnimator.lua')) 'La skin generada no contiene el animador ambiental.'
Assert ($ini -match '(?ms)^\[BackgroundScript\].*?^UpdateDivider=1$' -and @([regex]::Matches($ini,'(?m)^\[Particle\d+\]$')).Count -eq 48 -and $ini -notmatch '(?m)^\[AudioOutput|^\[AmbientBackground\]') 'El fondo no conserva 48 partículas ligeras a 10 FPS o aún incluye el concepto anterior.'
Assert (Test-Path (Join-Path $skinRoot '@Resources\ParticleGlow.png')) 'La skin generada no contiene el degradado radial de las luciérnagas.'
Assert ($ini -match '(?m)^GlassFill=22,27,38,145$' -and $ini -match '(?ms)^\[Block_RAM\].*?Fill Color #GlassFill#.*?^Shape2=Line' -and $ini -match '(?ms)^\[Block_CORES\].*?Fill Color 22,27,38,158') 'Los contenedores no conservan el glassmorfismo transparente y legible.'
Assert ($ini -match '(?ms)^\[Particle1\].*?^TransformationMatrix=' -and $ini -match '(?ms)^\[Particle1\].*?^Group=AmbientParticles\|OLEDShift') 'Las luciérnagas no responden a resolución o protección OLED.'
Assert ($ini -match '(?ms)^\[Block_CORES\].*?^Group=ProcessorPanel\|OLEDShift' -and $ini -match '(?ms)^\[GameStatusBackground\].*?^Group=PerformancePanel\|OLEDShift') 'Los módulos configurables no quedaron agrupados para su presentación.'
Assert ($ini -match '(?ms)^\[ClockDigit1\].*?^Group=MatrixClock\|ClockPanel\|OLEDShift' -and $ini -match '(?ms)^\[ClockColons\].*?^Group=ClockPanel\|OLEDShift') 'El reloj no quedó agrupado como módulo configurable.'
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

if ($failures.Count) {
    $failures | ForEach-Object { Write-Host "FALLO: $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'OK: validación oficial completada.' -ForegroundColor Green
Write-Host 'Procesadores sintéticos visibles: 4 de 8 detectados; sin huecos inventados.'
