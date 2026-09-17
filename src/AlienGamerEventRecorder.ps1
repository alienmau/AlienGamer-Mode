param(
    [switch]$Toggle,
    [switch]$Worker,
    [switch]$StartBuffer,
    [switch]$StopBuffer,
    [switch]$BufferWorker,
    [switch]$MarkIncident,
    [string]$SessionId,
    [int]$SampleIntervalMs = 1000,
    [string]$BridgeUrl = 'http://127.0.0.1:27843/v2/status',
    [string]$RainmeterConfig = 'AlienGamerMode',
    [string]$RuntimeDirectory = ''
)

$ErrorActionPreference = 'Stop'
$Invariant = [Globalization.CultureInfo]::InvariantCulture
$RuntimeRoot = if($RuntimeDirectory){$RuntimeDirectory}else{Join-Path $env:LOCALAPPDATA 'AlienGamerMode'}
$StatePath = Join-Path $RuntimeRoot 'recording-state.json'
$StopPath = Join-Path $RuntimeRoot 'recording.stop'
$BufferPath = Join-Path $RuntimeRoot 'event-prebuffer.json'
$BufferStatePath = Join-Path $RuntimeRoot 'event-prebuffer-state.json'
$BufferStopPath = Join-Path $RuntimeRoot 'event-prebuffer.stop'
$HistoryRoot = Join-Path $RuntimeRoot 'HistorialEventos'
$Rainmeter = 'C:\Program Files\Rainmeter\Rainmeter.exe'
$PendingRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode\GrabacionesPendientes'
Add-Type -AssemblyName Microsoft.VisualBasic
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.Localization.psm1') -Force
$language = 'es-MX'
try {
    $language = Resolve-AGLanguage ([string](Get-Content (Join-Path $RuntimeRoot 'AlienGamerMode.json') -Raw | ConvertFrom-Json).language)
} catch { }
$ui = Get-AGTranslations -Language $language
function T([string]$Path) { return Get-AGText -Translations $ui -Path $Path }

function Set-RainmeterRecordingState([bool]$Recording) {
    if (-not (Test-Path -LiteralPath $Rainmeter)) { return }
    if ($Recording) {
        & $Rainmeter '!SetVariable' 'RecordingActive' '1' $RainmeterConfig
        & $Rainmeter '!SetOption' 'MeterRecordLabel' 'Text' (T 'skin.finishRecording') $RainmeterConfig
        & $Rainmeter '!ShowMeter' 'MeterRecordingDot' $RainmeterConfig
    } else {
        & $Rainmeter '!SetVariable' 'RecordingActive' '0' $RainmeterConfig
        & $Rainmeter '!SetOption' 'MeterRecordLabel' 'Text' (T 'skin.recordEvent') $RainmeterConfig
        & $Rainmeter '!HideMeter' 'MeterRecordingDot' $RainmeterConfig
    }
    & $Rainmeter '!UpdateMeter' 'MeterRecordButton' $RainmeterConfig
    & $Rainmeter '!UpdateMeter' 'MeterRecordLabel' $RainmeterConfig
    & $Rainmeter '!UpdateMeter' 'MeterRecordingDot' $RainmeterConfig
    & $Rainmeter '!Redraw' $RainmeterConfig
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
    try { return Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json } catch { return $null }
}

function Get-EventIntelligenceSettings {
    $settings = [ordered]@{ preEventBufferSeconds=60; incidentWindowBeforeSeconds=15; incidentWindowAfterSeconds=15; privacyAssistant=$true; saveRawCsvBesideReport=$true; comparisonHistorySessions=10 }
    try {
        $config = Get-Content (Join-Path $RuntimeRoot 'AlienGamerMode.json') -Raw | ConvertFrom-Json
        if ($config.eventIntelligence) {
            foreach ($name in @($settings.Keys)) {
                if ($null -ne $config.eventIntelligence.$name) { $settings[$name] = $config.eventIntelligence.$name }
            }
        }
    } catch { }
    $settings.preEventBufferSeconds = [math]::Max(15,[math]::Min(120,[int]$settings.preEventBufferSeconds))
    $settings.incidentWindowBeforeSeconds = [math]::Max(5,[math]::Min(60,[int]$settings.incidentWindowBeforeSeconds))
    $settings.incidentWindowAfterSeconds = [math]::Max(5,[math]::Min(60,[int]$settings.incidentWindowAfterSeconds))
    return [pscustomobject]$settings
}

function Start-PreEventBuffer {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
    try {
        if (Test-Path $BufferStatePath) {
            $existing = Get-Content $BufferStatePath -Raw | ConvertFrom-Json
            if ($existing.WorkerPid -and (Get-Process -Id ([int]$existing.WorkerPid) -ErrorAction SilentlyContinue)) { return }
        }
    } catch { }
    Remove-Item $BufferStopPath -Force -ErrorAction SilentlyContinue
    $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -BufferWorker -SampleIntervalMs $SampleIntervalMs -BridgeUrl `"$BridgeUrl`""
    $process = Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
    [pscustomobject]@{ WorkerPid=$process.Id; StartedUtc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content $BufferStatePath -Encoding UTF8
}

function Stop-PreEventBuffer {
    'STOP' | Set-Content $BufferStopPath -Encoding ASCII
    Start-Sleep -Milliseconds 150
    try {
        if (Test-Path $BufferStatePath) {
            $state = Get-Content $BufferStatePath -Raw | ConvertFrom-Json
            if ($state.WorkerPid) { Stop-Process -Id ([int]$state.WorkerPid) -Force -ErrorAction SilentlyContinue }
        }
    } catch { }
    Remove-Item $BufferStatePath,$BufferStopPath -Force -ErrorAction SilentlyContinue
}

function Add-IncidentMarker {
    $state = Read-State
    if (-not $state -or $state.Status -ne 'recording' -or -not $state.MarkerPath) { return $false }
    $existing = @()
    if (Test-Path $state.MarkerPath) { try { $existing = @(Get-Content $state.MarkerPath -Raw | ConvertFrom-Json) } catch { $existing=@() } }
    $marker = [pscustomobject]@{ Index=($existing.Count+1); TimestampUtc=[DateTime]::UtcNow.ToString('o'); TimestampLocal=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'); Label="Incidente $($existing.Count+1)" }
    @($existing + $marker) | ConvertTo-Json -Depth 4 | Set-Content $state.MarkerPath -Encoding UTF8
    return $true
}

function Start-RecordingWorker {
    New-Item -ItemType Directory -Path $RuntimeRoot,$PendingRoot,$HistoryRoot -Force | Out-Null
    Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
    $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,8))
    $csv = Join-Path $PendingRoot ("Evento-$id.csv")
    $meta = Join-Path $PendingRoot ("Evento-$id-meta.json")
    $markers = Join-Path $PendingRoot ("Evento-$id-incidentes.json")
    $state = [pscustomobject]@{
        SessionId = $id
        StartUtc = [DateTime]::UtcNow.ToString('o')
        CsvPath = $csv
        MetadataPath = $meta
        MarkerPath = $markers
        WorkerPid = 0
        Status = 'recording'
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8

    $preRows = @()
    if (Test-Path $BufferPath) { try { $preRows = @(Get-Content $BufferPath -Raw | ConvertFrom-Json) } catch { $preRows=@() } }
    $recordingStart = Get-Date
    foreach ($preRow in $preRows) {
        try {
            $captured = [datetime]::Parse([string]$preRow.FechaHora)
            $preRow.Segundos = [math]::Round(($captured - $recordingStart).TotalSeconds,3)
            if (-not $preRow.PSObject.Properties['Fase']) { $preRow | Add-Member NoteProperty Fase 'Pre-evento' } else { $preRow.Fase='Pre-evento' }
            if (-not $preRow.PSObject.Properties['Incidente']) { $preRow | Add-Member NoteProperty Incidente 0 }
            if (-not $preRow.PSObject.Properties['IncidenteEtiqueta']) { $preRow | Add-Member NoteProperty IncidenteEtiqueta '' }
        } catch { }
    }
    if ($preRows.Count) { $preRows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8 }
    '[]' | Set-Content $markers -Encoding UTF8

    $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Worker -SessionId `"$id`" -SampleIntervalMs $SampleIntervalMs -BridgeUrl `"$BridgeUrl`" -RainmeterConfig `"$RainmeterConfig`""
    $process = Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
    $state.WorkerPid = $process.Id
    $state | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Set-RainmeterRecordingState $true
}

function Stop-RecordingWorker {
    $state = Read-State
    if ($state) {
        $state.Status = 'finalizing'
        $state | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
    }
    'STOP' | Set-Content -LiteralPath $StopPath -Encoding ASCII
    Set-RainmeterRecordingState $false
}

function Get-SystemMetadata {
    $computer = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $videoControllers = @(Get-CimInstance Win32_VideoController)
    $gpus = @($videoControllers | Select-Object -ExpandProperty Name)
    $gpuDrivers = @($videoControllers | ForEach-Object { "$($_.Name): $($_.DriverVersion)" })
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    $powerPlan = (& powercfg /getactivescheme 2>$null) -join ' '
    $hwinfoPath = 'C:\Program Files\HWiNFO64\HWiNFO64.exe'
    $rainmeterPath = 'C:\Program Files\Rainmeter\Rainmeter.exe'
    return [ordered]@{
        Equipo = "$($computer.Manufacturer) $($computer.Model)".Trim()
        SistemaOperativo = "$($os.Caption) $($os.Version)"
        Procesador = $cpu.Name
        NucleosFisicos = $cpu.NumberOfCores
        ProcesadoresLogicos = $cpu.NumberOfLogicalProcessors
        Graficas = ($gpus -join ' | ')
        ControladoresGraficos = ($gpuDrivers -join ' | ')
        ResolucionPantallas = (($videoControllers | ForEach-Object { "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate) Hz" }) -join ' | ')
        RAMTotalGB = [math]::Round([double]$computer.TotalPhysicalMemory / 1GB, 2)
        DiscoC_TotalGB = if ($disk) { [math]::Round([double]$disk.Size / 1GB, 2) } else { 0 }
        DiscoC_LibreGB = if ($disk) { [math]::Round([double]$disk.FreeSpace / 1GB, 2) } else { 0 }
        Alimentacion = if ($battery -and $battery.BatteryStatus -eq 1) { 'Bateria' } else { 'CA / conectado' }
        PlanEnergia = $powerPlan
        SesionWindows = $env:SESSIONNAME
        HWiNFOVersion = if (Test-Path $hwinfoPath) { (Get-Item $hwinfoPath).VersionInfo.FileVersion } else { 'No detectado' }
        RainmeterVersion = if (Test-Path $rainmeterPath) { (Get-Item $rainmeterPath).VersionInfo.FileVersion } else { 'No detectado' }
        IntervaloMuestreoMs = $SampleIntervalMs
        FuenteSensores = 'HWiNFO Shared Memory mediante AlienGamer Bridge v2'
    }
}

function Get-TopProcesses {
    return ((Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 12 |
        ForEach-Object { '{0} (PID {1}, RAM {2:N0} MB, CPU {3:N1} s)' -f $_.ProcessName,$_.Id,($_.WorkingSet64/1MB),([double]$_.CPU) }) -join ' | ')
}

function Convert-Invariant([string]$Value) {
    $number = 0.0
    if ([double]::TryParse($Value, [Globalization.NumberStyles]::Float, $Invariant, [ref]$number)) { return $number }
    return 0.0
}

function Get-FrameClass([double]$FrameTime) {
    if ($FrameTime -le 0) { return 'Sin dato' }
    if ($FrameTime -lt 8.3) { return 'Excelente' }
    if ($FrameTime -lt 16.7) { return 'Fluido' }
    if ($FrameTime -le 33.3) { return 'Atencion' }
    return 'Baja fluidez'
}

function Get-Sample([datetime]$StartedAt, [int]$Index) {
    $request = [Diagnostics.Stopwatch]::StartNew()
    $valid = $false
    $errorText = ''
    $sensor = $null
    try {
        $sensor = Invoke-RestMethod -Uri $BridgeUrl -TimeoutSec 2
        $valid = $null -ne $sensor.timestamp
    } catch {
        $errorText = $_.Exception.Message
    } finally {
        $request.Stop()
    }

    $memory = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
    $ramTotal = [double]$memory.TotalPhysicalMemory / 1GB
    $ramAvailable = [double]$memory.AvailablePhysicalMemory / 1GB
    $ramUsed = $ramTotal - $ramAvailable
    $ramPercent = if ($ramTotal -gt 0) { 100 * $ramUsed / $ramTotal } else { 0 }
    $vramUsedMb = if ($sensor) { [double]$sensor.vramUsed } else { -1 }
    $vramFreeMb = if ($sensor) { [double]$sensor.vramFree } else { -1 }
    $vramTotal = if ($vramUsedMb -ge 0 -and $vramFreeMb -ge 0) { ($vramUsedMb + $vramFreeMb) / 1024 } else { -1 }
    $vramUsed = if ($vramUsedMb -ge 0) { $vramUsedMb / 1024 } else { -1 }
    $vramPercent = if ($vramTotal -gt 0) { 100 * $vramUsed / $vramTotal } else { 0 }

    $row = [ordered]@{
        Muestra = $Index
        FechaHora = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
        Segundos = [math]::Round(((Get-Date) - $StartedAt).TotalSeconds, 3)
        Fase = 'Grabacion'
        Incidente = 0
        IncidenteEtiqueta = ''
        MuestraValida = $valid
        LatenciaPuenteMs = [math]::Round($request.Elapsed.TotalMilliseconds, 2)
        FPS = if($sensor){[double]$sensor.fps}else{-1}
        FrameTimeMs = if($sensor){[double]$sensor.frameTime}else{-1}
        ClasificacionFrameTime = if($sensor){Get-FrameClass ([double]$sensor.frameTime)}else{'Sin dato'}
        GPUTemperaturaC = if($sensor){[double]$sensor.gpuTemperature}else{-1}
        GPUUsoPct = if($sensor){[double]$sensor.gpuUsage}else{-1}
        CPUTemperaturaC = if($sensor){[double]$sensor.cpuTemperature}else{-1}
        CPUUsoPct = if($sensor){[double]$sensor.cpuUsage}else{-1}
        SSDTemperaturaC = if($sensor){[double]$sensor.storageTemperature}else{-1}
        CoreMaxTemperaturaC = if($sensor){[double]$sensor.coreMaximumTemperature}else{-1}
        RAMUsadaGB = [math]::Round($ramUsed, 3)
        RAMDisponibleGB = [math]::Round($ramAvailable, 3)
        RAMTotalGB = [math]::Round($ramTotal, 3)
        RAMUsoPct = [math]::Round($ramPercent, 2)
        VRAMUsadaGB = [math]::Round($vramUsed, 3)
        VRAMDisponibleGB = if($vramFreeMb -ge 0){[math]::Round($vramFreeMb / 1024, 3)}else{-1}
        VRAMTotalGB = [math]::Round($vramTotal, 3)
        VRAMUsoPct = [math]::Round($vramPercent, 2)
        CPUAlertaTermica = [int]($sensor -and [double]$sensor.cpuThermal -gt 0)
        GPUAlertaTermica = [int]($sensor -and [double]$sensor.gpuThermal -gt 0)
        CPUAlertaPotencia = [int]($sensor -and [double]$sensor.cpuPower -gt 0)
        GPUAlertaPotencia = [int]($sensor -and [double]$sensor.gpuPower -gt 0)
        ErrorMuestra = $errorText
    }
    if ($sensor) { foreach ($core in @($sensor.cores)) { $row["Core$($core.logicalIndex)UsoPct"] = [double]$core.value } }
    return [pscustomobject]$row
}

function Get-Percentile([double[]]$Values, [double]$Percentile) {
    $sorted = @($Values | Where-Object { $_ -gt 0 } | Sort-Object)
    if ($sorted.Count -eq 0) { return 0.0 }
    $position = ($sorted.Count - 1) * $Percentile
    $lower = [math]::Floor($position)
    $upper = [math]::Ceiling($position)
    if ($lower -eq $upper) { return [double]$sorted[$lower] }
    return [double]$sorted[$lower] + ($position - $lower) * ([double]$sorted[$upper] - [double]$sorted[$lower])
}

function Get-LongestAlertStreak($Rows, [string[]]$Properties) {
    $current = 0; $maximum = 0
    foreach ($row in $Rows) {
        $active = $false
        foreach ($property in $Properties) { if ([int]$row.$property -gt 0) { $active = $true; break } }
        if ($active) { $current++; if ($current -gt $maximum) { $maximum = $current } } else { $current = 0 }
    }
    return $maximum
}

function Get-StabilityMetrics($Rows) {
    $valid = @($Rows | Where-Object { ($_.MuestraValida -eq 'True' -or $_.MuestraValida -eq $true) -and [double]$_.FrameTimeMs -gt 0 })
    if (-not $valid.Count) { return [pscustomobject]@{ Score=0; Grade='Sin datos'; Mean=0; P95=0; P99=0; Max=0; SpikeRate=0; Variation=0; Reasons='No hay frame time válido suficiente para puntuar la estabilidad.' } }
    $values = [double[]]@($valid | ForEach-Object { [double]$_.FrameTimeMs })
    $mean = ($values | Measure-Object -Average).Average
    $max = ($values | Measure-Object -Maximum).Maximum
    $p95 = Get-Percentile $values 0.95
    $p99 = Get-Percentile $values 0.99
    $variance = 0.0
    foreach($value in $values){ $variance += [math]::Pow($value-$mean,2) }
    $std = [math]::Sqrt($variance/[math]::Max(1,$values.Count))
    $variation = if($mean -gt 0){$std/$mean}else{0}
    $spikes = @($values | Where-Object { $_ -gt 33.3 }).Count
    $spikeRate = 100.0*$spikes/$values.Count
    $invalidRate = 100.0*(@($Rows).Count-$valid.Count)/[math]::Max(1,@($Rows).Count)
    $alerts = @($valid | Where-Object { [int]$_.CPUAlertaTermica -gt 0 -or [int]$_.GPUAlertaTermica -gt 0 -or [int]$_.CPUAlertaPotencia -gt 0 -or [int]$_.GPUAlertaPotencia -gt 0 }).Count
    $penalty = 0.0
    $penalty += [math]::Min(35,[math]::Max(0,($p95-8.3)*1.4))
    $penalty += [math]::Min(20,[math]::Max(0,($p99-$p95)*0.8))
    $penalty += [math]::Min(20,$spikeRate*1.5)
    $penalty += [math]::Min(15,$variation*20)
    $penalty += [math]::Min(10,$invalidRate*0.5)
    if($alerts){$penalty += [math]::Min(10,100.0*$alerts/$valid.Count)}
    $score = [int][math]::Round([math]::Max(0,[math]::Min(100,100-$penalty)))
    $grade = if($score-ge 90){'Excelente'}elseif($score-ge 75){'Estable'}elseif($score-ge 55){'Variable'}elseif($score-ge 35){'Inestable'}else{'Muy inestable'}
    $reasons = "P95 $([math]::Round($p95,1)) ms; P99 $([math]::Round($p99,1)) ms; $([math]::Round($spikeRate,1))% de muestras por encima de 33.3 ms; variación relativa $([math]::Round($variation*100,1))%."
    return [pscustomobject]@{ Score=$score; Grade=$grade; Mean=[math]::Round($mean,2); P95=[math]::Round($p95,2); P99=[math]::Round($p99,2); Max=[math]::Round($max,2); SpikeRate=[math]::Round($spikeRate,2); Variation=[math]::Round($variation*100,2); Reasons=$reasons }
}

function Get-IncidentAnalysis($Rows,$Markers,$Settings) {
    $analyses = New-Object 'System.Collections.Generic.List[object]'
    foreach($marker in @($Markers)) {
        $when = [datetime]::Parse([string]$marker.TimestampLocal)
        $from = $when.AddSeconds(-[int]$Settings.incidentWindowBeforeSeconds)
        $to = $when.AddSeconds([int]$Settings.incidentWindowAfterSeconds)
        $window = @($Rows | Where-Object { try { $sampleTime=[datetime]::Parse([string]$_.FechaHora); $sampleTime -ge $from -and $sampleTime -le $to } catch { $false } })
        $diagnosis = Get-Diagnosis $window
        $stability = Get-StabilityMetrics $window
        $analyses.Add([pscustomobject]@{ Index=$marker.Index; Timestamp=$marker.TimestampLocal; WindowStart=$from.ToString('yyyy-MM-dd HH:mm:ss'); WindowEnd=$to.ToString('yyyy-MM-dd HH:mm:ss'); Samples=$window.Count; StabilityScore=$stability.Score; StabilityGrade=$stability.Grade; PreliminaryInterpretation=$diagnosis.Verdict; Evidence=$diagnosis.Evidence })
    }
    return $analyses.ToArray()
}

function Protect-SystemMetadata($System) {
    $protected = [ordered]@{}
    foreach($property in $System.PSObject.Properties) {
        $value = [string]$property.Value
        if($property.Name -in @('Equipo','SesionWindows')){$value='OCULTO POR PRIVACIDAD'}
        elseif($property.Name -like 'ProcesosConMayorRAM*'){$value=[regex]::Replace($value,'\s*\(PID\s+\d+,',' (PID oculto,')}
        $protected[$property.Name]=$value
    }
    return [pscustomobject]$protected
}

function Get-Diagnosis($Rows) {
    $valid = @($Rows | Where-Object { $_.MuestraValida -eq 'True' -or $_.MuestraValida -eq $true })
    if ($valid.Count -eq 0) {
        return [pscustomobject]@{ Verdict='Sin datos válidos'; Evidence='El puente de sensores no entregó muestras válidas durante el evento.'; Severity='Crítico'; Recommendation='Verificar HWiNFO, memoria compartida y el puente antes de interpretar el evento.' }
    }
    $maxCpuTemp = ($valid | Measure-Object CPUTemperaturaC -Maximum).Maximum
    $maxGpuTemp = ($valid | Measure-Object GPUTemperaturaC -Maximum).Maximum
    $maxSsdTemp = ($valid | Measure-Object SSDTemperaturaC -Maximum).Maximum
    $maxRam = ($valid | Measure-Object RAMUsoPct -Maximum).Maximum
    $maxVram = ($valid | Measure-Object VRAMUsoPct -Maximum).Maximum
    $maxGpuUse = ($valid | Measure-Object GPUUsoPct -Maximum).Maximum
    $maxCpuUse = ($valid | Measure-Object CPUUsoPct -Maximum).Maximum
    $p95Frame = Get-Percentile ([double[]]@($valid.FrameTimeMs)) 0.95
    $thermal = @($valid | Where-Object { [int]$_.CPUAlertaTermica -gt 0 -or [int]$_.GPUAlertaTermica -gt 0 }).Count
    $power = @($valid | Where-Object { [int]$_.CPUAlertaPotencia -gt 0 -or [int]$_.GPUAlertaPotencia -gt 0 }).Count
    $thermalStreak = Get-LongestAlertStreak $valid @('CPUAlertaTermica','GPUAlertaTermica')
    $powerStreak = Get-LongestAlertStreak $valid @('CPUAlertaPotencia','GPUAlertaPotencia')
    $evidence = New-Object 'System.Collections.Generic.List[string]'
    $verdict = New-Object 'System.Collections.Generic.List[string]'
    $severity = 'Normal'
    if ($thermal -gt 0) {
        if ($thermalStreak -ge 3 -or ($thermal / $valid.Count) -ge 0.10) { $verdict.Add('Limitacion termica sostenida probable'); $severity='Alta' }
        else { $verdict.Add('Evento termico transitorio'); if ($severity -eq 'Normal') { $severity='Observacion' } }
        $evidence.Add("Alertas termicas en $thermal muestras (~$thermal s acumulados), racha maxima ~$thermalStreak s; CPU max $maxCpuTemp C, GPU max $maxGpuTemp C.")
    }
    if ($power -gt 0) {
        if ($powerStreak -ge 3 -or ($power / $valid.Count) -ge 0.10) { $verdict.Add('Limite de potencia sostenido'); if ($severity -notin @('Alta')) { $severity='Media' } }
        else { $verdict.Add('Limite de potencia transitorio'); if ($severity -eq 'Normal') { $severity='Observacion' } }
        $evidence.Add("Limite de potencia en $power muestras (~$power s acumulados), racha maxima ~$powerStreak s.")
    }
    if ($maxVram -ge 90) { $verdict.Add('Presion de VRAM'); $evidence.Add("VRAM alcanzo $([math]::Round($maxVram,1))%."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($maxRam -ge 90) { $verdict.Add('Presion de memoria RAM'); $evidence.Add("RAM alcanzo $([math]::Round($maxRam,1))%."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($maxSsdTemp -ge 65) { $verdict.Add('SSD caliente'); $evidence.Add("SSD alcanzo $maxSsdTemp C."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($p95Frame -gt 33.3 -and $maxGpuUse -ge 95) { $verdict.Add('Cuello de botella GPU probable'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms con GPU hasta $maxGpuUse%."); $severity='Alta' }
    elseif ($p95Frame -gt 33.3 -and $maxCpuUse -ge 90) { $verdict.Add('Cuello de botella CPU probable'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms con CPU hasta $maxCpuUse%."); $severity='Alta' }
    elseif ($p95Frame -gt 33.3) { $verdict.Add('Tirones sin causa concluyente en sensores visibles'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms; revisar juego, shaders, almacenamiento, red y procesos en segundo plano."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($verdict.Count -eq 0) { $verdict.Add('Sin anomalias claras durante la captura'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms; no se activaron limites termicos o de potencia.") }
    $recommendation = if($thermal -gt 0){'Revisar refrigeración, ventilación, pasta térmica y límites del fabricante; confirmar la duración de la limitación.'}
        elseif($power -gt 0){'Revisar plan de energía, cargador, límites de potencia y comportamiento esperado del fabricante.'}
        elseif($maxVram -ge 90){'Reducir texturas o resolución y repetir la captura para comprobar si mejora la estabilidad.'}
        elseif($maxRam -ge 90){'Cerrar procesos no esenciales, revisar paginación y repetir la captura.'}
        elseif($maxSsdTemp -ge 65){'Revisar ventilación y salud SMART de la unidad; correlacionar con actividad de almacenamiento.'}
        elseif($p95Frame -gt 33.3 -and $maxGpuUse -ge 95){'Probar menor calidad o resolución y comparar otra sesión para confirmar presión sostenida de GPU.'}
        elseif($p95Frame -gt 33.3 -and $maxCpuUse -ge 90){'Revisar procesos en segundo plano, plan de energía y carga por núcleo; repetir en la misma escena.'}
        elseif($p95Frame -gt 33.3){'Comparar otra sesión y revisar shaders, red, almacenamiento y procesos en segundo plano.'}
        else{'No se detectó una señal concluyente. Conservar el reporte como referencia y comparar si el síntoma se repite.'}
    return [pscustomobject]@{ Verdict=($verdict -join ' | '); Evidence=($evidence -join ' '); Severity=$severity; Recommendation=$recommendation }
}

function Write-ExcelMatrix($Sheet, [int]$StartRow, [int]$StartColumn, $Rows) {
    $rowArray = @($Rows)
    if ($rowArray.Count -eq 0) { return }
    $columns = @($rowArray[0]).Count
    $matrix = New-Object 'object[,]' $rowArray.Count, $columns
    for ($r=0; $r -lt $rowArray.Count; $r++) {
        $values = @($rowArray[$r])
        if ($values.Count -ne $columns) { throw "La matriz de Excel contiene una fila de $($values.Count) columnas; se esperaban $columns." }
        for ($c=0; $c -lt $columns; $c++) { $matrix[$r,$c] = $values[$c] }
    }
    $topLeft = $Sheet.Cells.Item($StartRow, $StartColumn)
    $bottomRight = $Sheet.Cells.Item($StartRow + $rowArray.Count - 1, $StartColumn + $columns - 1)
    $Sheet.Range($topLeft, $bottomRight).Value2 = $matrix
}

function New-ExcelReport([string]$CsvPath, [string]$MetadataPath, [string]$MarkerPath, [string]$Destination, [bool]$PrivacyProtected) {
    $rows = @(Import-Csv -LiteralPath $CsvPath)
    $metadata = Get-Content -LiteralPath $MetadataPath -Raw | ConvertFrom-Json
    $settings = Get-EventIntelligenceSettings
    $markers = @()
    if(Test-Path $MarkerPath){try{$markers=@(Get-Content $MarkerPath -Raw | ConvertFrom-Json)}catch{$markers=@()}}
    if($PrivacyProtected){$metadata.Sistema=Protect-SystemMetadata $metadata.Sistema}
    $diagnosis = Get-Diagnosis $rows
    $stability = Get-StabilityMetrics $rows
    $incidentAnalyses = @(Get-IncidentAnalysis $rows $markers $settings)
    New-Item -ItemType Directory -Path $HistoryRoot -Force | Out-Null
    $previousSession = $null
    $previousFile = Get-ChildItem $HistoryRoot -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if($previousFile){try{$previousSession=Get-Content $previousFile.FullName -Raw | ConvertFrom-Json}catch{$previousSession=$null}}
    $valid = @($rows | Where-Object { $_.MuestraValida -eq 'True' })
    $excel = $null; $book = $null
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $book = $excel.Workbooks.Add()
        while ($book.Worksheets.Count -lt 9) { [void]$book.Worksheets.Add() }
        $summary = $book.Worksheets.Item(1); $summary.Name = 'Resumen'
        $timeline = $book.Worksheets.Item(2); $timeline.Name = 'Cronologia'
        $cores = $book.Worksheets.Item(3); $cores.Name = 'Nucleos'
        $system = $book.Worksheets.Item(4); $system.Name = 'Sistema'
        $criteria = $book.Worksheets.Item(5); $criteria.Name = 'Criterios'
        $incidents = $book.Worksheets.Item(6); $incidents.Name = 'Incidentes'
        $comparison = $book.Worksheets.Item(7); $comparison.Name = 'Comparacion'
        $raw = $book.Worksheets.Item(8); $raw.Name = 'Datos_brutos'
        $privacy = $book.Worksheets.Item(9); $privacy.Name = 'Privacidad'
        for ($i=$book.Worksheets.Count; $i -gt 9; $i--) { $book.Worksheets.Item($i).Delete() }

        $dark = 0x211814; $header = 0x463730; $cyan = 0xFFE100; $white = 0xFFFFFF; $muted = 0xB9A091; $orange = 0x20B0FF
        $summary.Range('A1:H1').Merge(); $summary.Range('A1').Value2='ALIENGAMER MODE - REPORTE DE EVENTO'; $summary.Range('A1').Font.Size=20; $summary.Range('A1').Font.Bold=$true; $summary.Range('A1').Font.Color=$orange
        $summary.Range('A3:B3').Value2=@('CAMPO','VALOR'); $summary.Range('A3:B3').Interior.Color=$header; $summary.Range('A3:B3').Font.Bold=$true
        $recordingDuration = if ($rows.Count -gt 0) { [math]::Max(0,[double]$rows[-1].Segundos) } else { 0 }
        $preEventDuration = if ($rows.Count -gt 0) { [math]::Max(0,-[double]$rows[0].Segundos) } else { 0 }
        $duration = $recordingDuration + $preEventDuration
        $summaryRows = New-Object 'System.Collections.Generic.List[object[]]'
        $summaryPairs=@('Inicio',$metadata.InicioLocal,'Fin',$metadata.FinLocal,'Ventana total analizada (s)',[math]::Round($duration,1),'Pre-evento incluido (s)',[math]::Round($preEventDuration,1),'Grabación posterior (s)',[math]::Round($recordingDuration,1),'Muestras',$rows.Count,'Muestras validas',$valid.Count,'Juego','Completar por el usuario','Sintoma observado','Completar por el usuario','Escena / partida','Completar por el usuario','Notas','Completar por el usuario','Interpretación preliminar',$diagnosis.Verdict,'Severidad',$diagnosis.Severity,'Recomendación orientativa',$diagnosis.Recommendation,'Evidencia',$diagnosis.Evidence,'Advertencia',(T 'recorder.preliminaryWarning'))
        for($k=0;$k-lt$summaryPairs.Count;$k+=2){[void]$summaryRows.Add([object[]]@($summaryPairs[$k],$summaryPairs[$k+1]))}
        $summary.Range('B4:B5').NumberFormat='@'
        Write-ExcelMatrix $summary 4 1 $summaryRows

        $summary.Range('D3:E3').Value2=@('INDICADOR','RESULTADO'); $summary.Range('D3:E3').Interior.Color=$header; $summary.Range('D3:E3').Font.Bold=$true
        function Avg($name) { if ($valid.Count) { [math]::Round((($valid | Measure-Object $name -Average).Average),2) } else { 0 } }
        function Max($name) { if ($valid.Count) { [math]::Round((($valid | Measure-Object $name -Maximum).Maximum),2) } else { 0 } }
        function MinPositive($name) { $v=@($valid | ForEach-Object { [double]($_.$name) } | Where-Object { $_ -gt 0 }); if($v.Count){[math]::Round(($v|Measure-Object -Minimum).Minimum,2)}else{0} }
        $kpis = New-Object 'System.Collections.Generic.List[object[]]'
        $kpiPairs = @(
            @('FPS promedio',(Avg 'FPS')), @('FPS minimo',(MinPositive 'FPS')), @('FPS 1% low aprox.',[math]::Round((Get-Percentile ([double[]]@($valid.FPS)) 0.01),2)),
            @('Frame time promedio ms',(Avg 'FrameTimeMs')), @('Frame time P95 ms',[math]::Round((Get-Percentile ([double[]]@($valid.FrameTimeMs)) 0.95),2)), @('Frame time P99 ms',[math]::Round((Get-Percentile ([double[]]@($valid.FrameTimeMs)) 0.99),2)), @('Frame time max ms',(Max 'FrameTimeMs')),
            @('GPU temperatura max C',(Max 'GPUTemperaturaC')), @('GPU uso max %',(Max 'GPUUsoPct')), @('CPU temperatura max C',(Max 'CPUTemperaturaC')), @('Core max temperatura C',(Max 'CoreMaxTemperaturaC')), @('CPU uso max %',(Max 'CPUUsoPct')),
            @('SSD temperatura max C',(Max 'SSDTemperaturaC')), @('RAM uso max %',(Max 'RAMUsoPct')), @('VRAM uso max %',(Max 'VRAMUsoPct')),
            @('Muestras CPU thermal',@($valid|Where-Object{[int]$_.CPUAlertaTermica -gt 0}).Count), @('Muestras GPU thermal',@($valid|Where-Object{[int]$_.GPUAlertaTermica -gt 0}).Count),
            @('Muestras CPU power limit',@($valid|Where-Object{[int]$_.CPUAlertaPotencia -gt 0}).Count), @('Muestras GPU power limit',@($valid|Where-Object{[int]$_.GPUAlertaPotencia -gt 0}).Count),
            @('Puntuación de estabilidad (0-100)',$stability.Score), @('Clasificación de estabilidad',$stability.Grade), @('Picos > 33.3 ms (%)',$stability.SpikeRate), @('Variación de frame time (%)',$stability.Variation)
        )
        foreach($pair in $kpiPairs){[void]$kpis.Add([object[]]$pair)}
        Write-ExcelMatrix $summary 4 4 $kpis
        $summary.Columns.Item('A').ColumnWidth=25; $summary.Columns.Item('B').ColumnWidth=75; $summary.Columns.Item('D').ColumnWidth=31; $summary.Columns.Item('E').ColumnWidth=18
        $summary.Range('A4:B25').WrapText=$true

        $timelineHeaders = @('Muestra','Fecha y hora','Segundos','Fase','Incidente','Etiqueta incidente','Valida','Latencia puente ms','FPS','Frame time ms','Clasificacion','GPU temp C','GPU uso %','CPU temp C','CPU uso %','SSD temp C','Core max temp C','RAM usada GB','RAM disponible GB','RAM total GB','RAM uso %','VRAM usada GB','VRAM disponible GB','VRAM total GB','VRAM uso %','CPU thermal','GPU thermal','CPU power limit','GPU power limit','Error')
        Write-ExcelMatrix $timeline 1 1 (,([object[]]$timelineHeaders))
        $timelineRows = foreach($r in $rows){ ,@($r.Muestra,$r.FechaHora,[double]$r.Segundos,$r.Fase,[int]$r.Incidente,$r.IncidenteEtiqueta,$r.MuestraValida,[double]$r.LatenciaPuenteMs,[double]$r.FPS,[double]$r.FrameTimeMs,$r.ClasificacionFrameTime,[double]$r.GPUTemperaturaC,[double]$r.GPUUsoPct,[double]$r.CPUTemperaturaC,[double]$r.CPUUsoPct,[double]$r.SSDTemperaturaC,[double]$r.CoreMaxTemperaturaC,[double]$r.RAMUsadaGB,[double]$r.RAMDisponibleGB,[double]$r.RAMTotalGB,[double]$r.RAMUsoPct,[double]$r.VRAMUsadaGB,[double]$r.VRAMDisponibleGB,[double]$r.VRAMTotalGB,[double]$r.VRAMUsoPct,[int]$r.CPUAlertaTermica,[int]$r.GPUAlertaTermica,[int]$r.CPUAlertaPotencia,[int]$r.GPUAlertaPotencia,$r.ErrorMuestra) }
        $timeline.Range('B:B').NumberFormat='@'
        if($timelineRows.Count){ Write-ExcelMatrix $timeline 2 1 $timelineRows }
        $timeline.Range('A1:AD1').Interior.Color=$header; $timeline.Range('A1:AD1').Font.Bold=$true; $timeline.Range('A1:AD1').AutoFilter() | Out-Null
        $timeline.Range('A:AD').EntireColumn.AutoFit() | Out-Null; $timeline.Columns.Item('B').ColumnWidth=24; $timeline.Columns.Item('AD').ColumnWidth=45

        $coreProperties = @($rows[0].PSObject.Properties.Name | Where-Object { $_ -match '^Core\d+UsoPct$' } | Sort-Object { [int]([regex]::Match($_,'\d+').Value) })
        $coreHeaders = @('Muestra','Fecha y hora','Segundos') + @($coreProperties | ForEach-Object { "Procesador lógico $([regex]::Match($_,'\d+').Value) uso %" })
        Write-ExcelMatrix $cores 1 1 (,([object[]]$coreHeaders))
        $coreRows = foreach($r in $rows){ $a=@($r.Muestra,$r.FechaHora,[double]$r.Segundos); foreach($property in $coreProperties){$a += [double]($r.$property)}; ,$a }
        if($coreRows.Count){ Write-ExcelMatrix $cores 2 1 $coreRows }
        $coreLastColumn = 3 + $coreProperties.Count
        $coreHeaderRange = $cores.Range($cores.Cells.Item(1,1),$cores.Cells.Item(1,$coreLastColumn))
        $coreHeaderRange.Interior.Color=$header; $coreHeaderRange.Font.Bold=$true; $cores.UsedRange.EntireColumn.AutoFit() | Out-Null

        $system.Range('A1:B1').Value2=@('PARAMETRO','VALOR'); $system.Range('A1:B1').Interior.Color=$header; $system.Range('A1:B1').Font.Bold=$true
        $systemRows=@(); foreach($p in $metadata.Sistema.PSObject.Properties){$systemRows += ,@($p.Name,[string]$p.Value)}; Write-ExcelMatrix $system 2 1 $systemRows; $system.Columns.Item('A').ColumnWidth=30; $system.Columns.Item('B').ColumnWidth=90; $system.Range('B:B').WrapText=$true

        $criteriaRows = New-Object 'System.Collections.Generic.List[object[]]'
        $criteriaPairs = @(
            @('METRICA','RANGO / EVENTO','INTERPRETACION'),
            @('Frame time','< 8.3 ms','Excelente; equivale a mas de 120 FPS'), @('Frame time','8.3 a < 16.7 ms','Fluido; entre 60 y 120 FPS'), @('Frame time','16.7 a 33.3 ms','Atencion; entre 30 y 60 FPS'), @('Frame time','> 33.3 ms','Baja fluidez; menos de 30 FPS'),
            @('CPU thermal / GPU thermal','1','HWiNFO detecto limitacion termica'), @('CPU/GPU power limit','1','El componente alcanzo un limite electrico o de potencia'), @('VRAM / RAM','>= 90%','Presion de memoria probable'), @('SSD','>= 65 C','Temperatura alta; correlacionar con caidas y actividad de disco'),
            @('Limitacion','General','FPS/PresentMon puede ser N/D fuera de un juego 3D o alterarse en una sesion remota.'), @('Alcance','General','Este reporte orienta; no sustituye logs del juego, red, SMART detallado ni trazas ETW.')
        )
        foreach($triple in $criteriaPairs){[void]$criteriaRows.Add([object[]]$triple)}
        Write-ExcelMatrix $criteria 1 1 $criteriaRows; $criteria.Range('A1:C1').Interior.Color=$header; $criteria.Range('A1:C1').Font.Bold=$true; $criteria.Columns.Item('A').ColumnWidth=28; $criteria.Columns.Item('B').ColumnWidth=24; $criteria.Columns.Item('C').ColumnWidth=95; $criteria.Range('A:C').WrapText=$true

        $incidentRows = New-Object 'System.Collections.Generic.List[object[]]';[void]$incidentRows.Add([object[]]@('INCIDENTE','MARCA','VENTANA ANALIZADA','MUESTRAS','ESTABILIDAD','INTERPRETACIÓN PRELIMINAR','EVIDENCIA'))
        if($incidentAnalyses.Count){foreach($item in $incidentAnalyses){$incidentRows += ,@($item.Index,$item.Timestamp,"$($item.WindowStart) a $($item.WindowEnd)",$item.Samples,"$($item.StabilityScore)/100 - $($item.StabilityGrade)",$item.PreliminaryInterpretation,$item.Evidence)}}
        else{$incidentRows += ,@('Sin marcas','','','','','No se marcó un instante específico durante la grabación.','El resumen general analiza toda la sesión.')}
        Write-ExcelMatrix $incidents 1 1 $incidentRows; $incidents.Range('A1:G1').Interior.Color=$header; $incidents.Range('A1:G1').Font.Bold=$true; $incidents.Columns.Item('A').ColumnWidth=14; $incidents.Columns.Item('B').ColumnWidth=24; $incidents.Columns.Item('C').ColumnWidth=42; $incidents.Columns.Item('D').ColumnWidth=12; $incidents.Columns.Item('E').ColumnWidth=22; $incidents.Columns.Item('F').ColumnWidth=55; $incidents.Columns.Item('G').ColumnWidth=85; $incidents.Range('A:G').WrapText=$true

        $currentSession = [ordered]@{ Timestamp=$metadata.FinLocal; StabilityScore=$stability.Score; StabilityGrade=$stability.Grade; FPSAverage=(Avg 'FPS'); FPSMinimum=(MinPositive 'FPS'); FrameTimeP95=$stability.P95; FrameTimeP99=$stability.P99; FrameTimeMax=$stability.Max; GPUTemperatureMax=(Max 'GPUTemperaturaC'); CPUTemperatureMax=(Max 'CPUTemperaturaC'); RAMMax=(Max 'RAMUsoPct'); VRAMMax=(Max 'VRAMUsoPct'); Incidents=$markers.Count; PreliminaryInterpretation=$diagnosis.Verdict }
        $comparisonRows=New-Object 'System.Collections.Generic.List[object[]]';[void]$comparisonRows.Add([object[]]@('MÉTRICA','SESIÓN ACTUAL','SESIÓN ANTERIOR','CAMBIO'))
        foreach($metric in @(@('Puntuación estabilidad','StabilityScore'),@('FPS promedio','FPSAverage'),@('FPS mínimo','FPSMinimum'),@('Frame time P95 ms','FrameTimeP95'),@('Frame time P99 ms','FrameTimeP99'),@('Frame time máximo ms','FrameTimeMax'),@('GPU temperatura máxima C','GPUTemperatureMax'),@('CPU temperatura máxima C','CPUTemperatureMax'),@('RAM máxima %','RAMMax'),@('VRAM máxima %','VRAMMax'),@('Incidentes marcados','Incidents'))){$current=[double]$currentSession[$metric[1]]; if($previousSession){$previous=[double]$previousSession.($metric[1]);$delta=[math]::Round($current-$previous,2)}else{$previous='N/D';$delta='N/D'};$comparisonRows+=,@($metric[0],$current,$previous,$delta)}
        $comparisonRows += ,@('Interpretación actual',$diagnosis.Verdict,'','')
        $comparisonRows += ,@('Alcance','La comparación usa la sesión anterior guardada en este equipo. Diferencias de juego, escena o configuración pueden cambiar los resultados.','','')
        Write-ExcelMatrix $comparison 1 1 $comparisonRows; $comparison.Range('A1:D1').Interior.Color=$header; $comparison.Range('A1:D1').Font.Bold=$true; $comparison.Columns.Item('A').ColumnWidth=35; $comparison.Columns.Item('B').ColumnWidth=75; $comparison.Columns.Item('C').ColumnWidth=20; $comparison.Columns.Item('D').ColumnWidth=16; $comparison.Range('A:D').WrapText=$true

        $rawProperties=@($rows[0].PSObject.Properties.Name)
        Write-ExcelMatrix $raw 1 1 (,([object[]]$rawProperties))
        $rawRows=foreach($r in $rows){$values=@();foreach($property in $rawProperties){$values += $r.$property};,$values}
        if($rawRows.Count){Write-ExcelMatrix $raw 2 1 $rawRows}
        $rawLastColumn=$rawProperties.Count; $rawHeader=$raw.Range($raw.Cells.Item(1,1),$raw.Cells.Item(1,$rawLastColumn));$rawHeader.Interior.Color=$header;$rawHeader.Font.Bold=$true;$rawHeader.AutoFilter()|Out-Null;$raw.UsedRange.EntireColumn.AutoFit()|Out-Null

        $privacyRows=New-Object 'System.Collections.Generic.List[object[]]';$privacyPairs=@('Modo del reporte',$(if($PrivacyProtected){'Protegido para compartir'}else{'Detalle técnico completo'}),'Identificadores del equipo',$(if($PrivacyProtected){'Ocultos'}else{'Incluidos'}),'PID de procesos',$(if($PrivacyProtected){'Ocultos'}else{'Incluidos'}),'Datos de sensores','Incluidos','Recomendación','Revisa las hojas Sistema y Datos_brutos antes de publicar o enviar el archivo a terceros.','Aviso',(T 'recorder.preliminaryWarning'));for($k=0;$k-lt$privacyPairs.Count;$k+=2){[void]$privacyRows.Add([object[]]@($privacyPairs[$k],$privacyPairs[$k+1]))};$privacyRows.Insert(0,[object[]]@('PRIVACIDAD','ESTADO'))
        Write-ExcelMatrix $privacy 1 1 $privacyRows;$privacy.Range('A1:B1').Interior.Color=$header;$privacy.Range('A1:B1').Font.Bold=$true;$privacy.Columns.Item('A').ColumnWidth=30;$privacy.Columns.Item('B').ColumnWidth=95;$privacy.Range('A:B').WrapText=$true

        foreach($sheet in @($summary,$timeline,$cores,$system,$criteria,$incidents,$comparison,$raw,$privacy)) {
            $used=$sheet.UsedRange;$used.Font.Name='Segoe UI';$used.Font.Size=10;$used.Interior.Color=$dark;$used.Font.Color=$white
            $sheet.Rows.Item(1).RowHeight=28;$sheet.Activate();$excel.ActiveWindow.SplitRow=1;$excel.ActiveWindow.FreezePanes=$true
        }
        foreach($range in @($summary.Range('A3:B3'),$summary.Range('D3:E3'),$timeline.Range('A1:AD1'),$coreHeaderRange,$system.Range('A1:B1'),$criteria.Range('A1:C1'),$incidents.Range('A1:G1'),$comparison.Range('A1:D1'),$rawHeader,$privacy.Range('A1:B1'))){$range.Interior.Color=$header;$range.Font.Bold=$true}
        $summary.Range('A1:H1').Interior.Color=$dark;$summary.Range('A1').Font.Size=20;$summary.Range('A1').Font.Bold=$true;$summary.Range('A1').Font.Color=$orange
        $summary.Activate()
        $book.SaveAs($Destination, 51)
        $historyPath=Join-Path $HistoryRoot ((Get-Date -Format 'yyyyMMdd-HHmmss')+'.json'); [pscustomobject]$currentSession|ConvertTo-Json -Depth 5|Set-Content $historyPath -Encoding UTF8
        Get-ChildItem $HistoryRoot -Filter '*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -Skip ([int]$settings.comparisonHistorySessions) | Remove-Item -Force -ErrorAction SilentlyContinue
    } finally {
        if($book){$book.Close($false)}
        if($excel){$excel.Quit()}
        foreach($obj in @($privacy,$raw,$comparison,$incidents,$criteria,$system,$cores,$timeline,$summary,$book,$excel)){if($obj){[void][Runtime.InteropServices.Marshal]::ReleaseComObject($obj)}}
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}

function Finish-Recording([string]$CsvPath, [string]$MetadataPath, [string]$MarkerPath, [datetime]$StartedAt, [string]$StartProcesses) {
    $system = Get-SystemMetadata
    $system['ProcesosConMayorRAMAlInicio'] = $StartProcesses
    $system['ProcesosConMayorRAMAlFinal'] = Get-TopProcesses
    $metadata = [ordered]@{
        InicioLocal = $StartedAt.ToString('yyyy-MM-dd HH:mm:ss')
        FinLocal = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Sistema = $system
    }
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $MetadataPath -Encoding UTF8
    Add-Type -AssemblyName System.Windows.Forms
    $settings = Get-EventIntelligenceSettings
    $privacyProtected = $true
    if([bool]$settings.privacyAssistant){
        $privacyChoice=[System.Windows.Forms.MessageBox]::Show((T 'recorder.privacyQuestion'),(T 'recorder.privacyTitle'),'YesNoCancel','Question')
        if($privacyChoice -eq [System.Windows.Forms.DialogResult]::Cancel){[System.Windows.Forms.MessageBox]::Show("$(T 'recorder.pending')`n$CsvPath",'AlienGamer Mode','OK','Information')|Out-Null;return}
        $privacyProtected = $privacyChoice -eq [System.Windows.Forms.DialogResult]::Yes
    }
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = T 'recorder.saveTitle'
    $dialog.Filter = T 'recorder.reportFilter'
    $dialog.DefaultExt = 'xlsx'
    $dialog.AddExtension = $true
    $dialog.FileName = 'AlienGamerMode-Evento-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xlsx'
    $dialog.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        New-ExcelReport $CsvPath $MetadataPath $MarkerPath $dialog.FileName $privacyProtected
        if([bool]$settings.saveRawCsvBesideReport){$rawDestination=[IO.Path]::Combine([IO.Path]::GetDirectoryName($dialog.FileName),([IO.Path]::GetFileNameWithoutExtension($dialog.FileName)+'-datos-brutos.csv'));Copy-Item $CsvPath $rawDestination -Force}
        [System.Windows.Forms.MessageBox]::Show("$(T 'recorder.saved')`n$($dialog.FileName)", 'AlienGamer Mode', 'OK', 'Information') | Out-Null
        Remove-Item -LiteralPath $CsvPath,$MetadataPath,$MarkerPath -Force -ErrorAction SilentlyContinue
    } else {
        [System.Windows.Forms.MessageBox]::Show("$(T 'recorder.pending')`n$CsvPath", 'AlienGamer Mode', 'OK', 'Information') | Out-Null
    }
}

if($StartBuffer){Start-PreEventBuffer;exit}
if($StopBuffer){Stop-PreEventBuffer;exit}
if($MarkIncident){if(Add-IncidentMarker){Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue;[System.Windows.Forms.MessageBox]::Show((T 'dialog.incidentMarked'),'AlienGamer Mode','OK','Information')|Out-Null};exit}

if ($Toggle) {
    $state = Read-State
    if ($state -and $state.WorkerPid -and (Get-Process -Id ([int]$state.WorkerPid) -ErrorAction SilentlyContinue)) {
        if ($state.Status -ne 'finalizing') { Stop-RecordingWorker }
    } else {
        Remove-Item -LiteralPath $StatePath,$StopPath -Force -ErrorAction SilentlyContinue
        Start-RecordingWorker
    }
    exit
}

if($BufferWorker){
    $settings=Get-EventIntelligenceSettings;$startedAt=Get-Date;$index=0;$buffer=New-Object 'System.Collections.Generic.List[object]'
    try{while(-not(Test-Path $BufferStopPath)){$index++;$sample=Get-Sample $startedAt $index;$sample.Fase='Pre-evento';$buffer.Add($sample);while($buffer.Count -gt [int]$settings.preEventBufferSeconds){$buffer.RemoveAt(0)};@($buffer)|ConvertTo-Json -Depth 5|Set-Content $BufferPath -Encoding UTF8;Start-Sleep -Milliseconds ([math]::Max(250,$SampleIntervalMs))}}finally{Remove-Item $BufferStatePath,$BufferStopPath -Force -ErrorAction SilentlyContinue}
    exit
}

if ($Worker) {
    $state = Read-State
    if (-not $state -or $state.SessionId -ne $SessionId) { exit 2 }
    $startedAt = Get-Date
    $startProcesses = Get-TopProcesses
    $existingRows = if(Test-Path $state.CsvPath){@(Import-Csv $state.CsvPath)}else{@()}
    $index = $existingRows.Count
    $lastMarkerCount=0
    try {
        while (-not (Test-Path -LiteralPath $StopPath)) {
            $index++
            $sample = Get-Sample $startedAt $index
            $markers=@();if(Test-Path $state.MarkerPath){try{$markers=@(Get-Content $state.MarkerPath -Raw|ConvertFrom-Json)}catch{$markers=@()}}
            if($markers.Count -gt $lastMarkerCount){$sample.Incidente=1;$sample.IncidenteEtiqueta=[string]$markers[-1].Label;$lastMarkerCount=$markers.Count}
            if ($index -eq 1 -and -not(Test-Path $state.CsvPath)) { $sample | Export-Csv -LiteralPath $state.CsvPath -NoTypeInformation -Encoding UTF8 }
            else { $sample | Export-Csv -LiteralPath $state.CsvPath -NoTypeInformation -Encoding UTF8 -Append }
            Start-Sleep -Milliseconds ([math]::Max(250,$SampleIntervalMs))
        }
        Finish-Recording $state.CsvPath $state.MetadataPath $state.MarkerPath $startedAt $startProcesses
    } catch {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show("$(T 'recorder.failed')`n$($_.Exception.Message)`n`n$(T 'recorder.csvPreserved')`n$($state.CsvPath)", 'AlienGamer Mode', 'OK', 'Error') | Out-Null
    } finally {
        Remove-Item -LiteralPath $StatePath,$StopPath -Force -ErrorAction SilentlyContinue
        Set-RainmeterRecordingState $false
    }
}
