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
    $settings = [ordered]@{ preEventBufferSeconds=60; incidentWindowBeforeSeconds=15; incidentWindowAfterSeconds=15; privacyAssistant=$true; saveRawCsvBesideReport=$true; saveVisualReportBesideReport=$true; comparisonHistorySessions=10 }
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
    $validPreRows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($preRow in $preRows) {
        if ($null -eq $preRow -or -not $preRow.PSObject.Properties['FechaHora']) { continue }
        $captured = [datetime]::MinValue
        $timestampText = [string]$preRow.FechaHora
        $parsed = [datetime]::TryParseExact($timestampText, 'yyyy-MM-dd HH:mm:ss.fff', $Invariant, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$captured)
        if (-not $parsed) { $parsed = [datetime]::TryParse($timestampText, $Invariant, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$captured) }
        if (-not $parsed) { continue }
        $preRow.Segundos = [math]::Round(($captured - $recordingStart).TotalSeconds,3)
        if (-not $preRow.PSObject.Properties['Fase']) { $preRow | Add-Member NoteProperty Fase 'Pre-evento' } else { $preRow.Fase='Pre-evento' }
        if (-not $preRow.PSObject.Properties['Incidente']) { $preRow | Add-Member NoteProperty Incidente 0 }
        if (-not $preRow.PSObject.Properties['IncidenteEtiqueta']) { $preRow | Add-Member NoteProperty IncidenteEtiqueta '' }
        $validPreRows.Add($preRow)
    }
    if ($validPreRows.Count) { @($validPreRows) | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8 }
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
    if ($FrameTime -le 33.3) { return 'Atención' }
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
    foreach($marker in @($Markers | Where-Object { $null -ne $_ -and $_.PSObject.Properties['TimestampLocal'] })) {
        $when = [datetime]::MinValue
        $timestampText = [string]$marker.TimestampLocal
        $parsed = [datetime]::TryParseExact($timestampText, 'yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$when)
        if (-not $parsed) { $parsed = [datetime]::TryParse($timestampText, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$when) }
        if (-not $parsed) { continue }
        $from = $when.AddSeconds(-[int]$Settings.incidentWindowBeforeSeconds)
        $to = $when.AddSeconds([int]$Settings.incidentWindowAfterSeconds)
        $window = @($Rows | Where-Object {
            $sampleTime = [datetime]::MinValue
            $sampleText = [string]$_.FechaHora
            $sampleParsed = [datetime]::TryParseExact($sampleText, 'yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$sampleTime)
            $sampleParsed -and $sampleTime -ge $from -and $sampleTime -le $to
        })
        $diagnosis = Get-Diagnosis $window
        $stability = Get-StabilityMetrics $window
        $markerLabel=if($marker.PSObject.Properties['Label']){[string]$marker.Label}else{"Incidente $($marker.Index)"}
        $analyses.Add([pscustomobject]@{ Index=$marker.Index; Label=$markerLabel; Timestamp=$marker.TimestampLocal; WindowStart=$from.ToString('yyyy-MM-dd HH:mm:ss'); WindowEnd=$to.ToString('yyyy-MM-dd HH:mm:ss'); Samples=$window.Count; StabilityScore=$stability.Score; StabilityGrade=$stability.Grade; PreliminaryInterpretation=$diagnosis.Verdict; Evidence=$diagnosis.Evidence })
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
        if ($thermalStreak -ge 3 -or ($thermal / $valid.Count) -ge 0.10) { $verdict.Add('Limitación térmica sostenida probable'); $severity='Alta' }
        else { $verdict.Add('Evento térmico transitorio'); if ($severity -eq 'Normal') { $severity='Observación' } }
        $evidence.Add("Alertas térmicas en $thermal muestras (~$thermal s acumulados), racha máxima ~$thermalStreak s; CPU máx. $maxCpuTemp °C, GPU máx. $maxGpuTemp °C.")
    }
    if ($power -gt 0) {
        if ($powerStreak -ge 3 -or ($power / $valid.Count) -ge 0.10) { $verdict.Add('Límite de potencia sostenido'); if ($severity -notin @('Alta')) { $severity='Media' } }
        else { $verdict.Add('Límite de potencia transitorio'); if ($severity -eq 'Normal') { $severity='Observación' } }
        $evidence.Add("Límite de potencia en $power muestras (~$power s acumulados), racha máxima ~$powerStreak s.")
    }
    if ($maxVram -ge 90) { $verdict.Add('Presión de VRAM'); $evidence.Add("VRAM alcanzó $([math]::Round($maxVram,1))%."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($maxRam -ge 90) { $verdict.Add('Presión de memoria RAM'); $evidence.Add("RAM alcanzó $([math]::Round($maxRam,1))%."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($maxSsdTemp -ge 65) { $verdict.Add('SSD caliente'); $evidence.Add("SSD alcanzó $maxSsdTemp °C."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($p95Frame -gt 33.3 -and $maxGpuUse -ge 95) { $verdict.Add('Cuello de botella GPU probable'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms con GPU hasta $maxGpuUse%."); $severity='Alta' }
    elseif ($p95Frame -gt 33.3 -and $maxCpuUse -ge 90) { $verdict.Add('Cuello de botella CPU probable'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms con CPU hasta $maxCpuUse%."); $severity='Alta' }
    elseif ($p95Frame -gt 33.3) { $verdict.Add('Tirones sin causa concluyente en sensores visibles'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms; revisar juego, shaders, almacenamiento, red y procesos en segundo plano."); if ($severity -eq 'Normal') { $severity='Media' } }
    if ($verdict.Count -eq 0) { $verdict.Add('Sin anomalías claras durante la captura'); $evidence.Add("Frame time P95 $([math]::Round($p95Frame,1)) ms; no se activaron límites térmicos o de potencia.") }
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

function ConvertTo-HtmlText($Value) {
    return [Net.WebUtility]::HtmlEncode([string]$Value)
}

function Format-VisualNumber([double]$Value, [string]$Format='0.0') {
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value) -or $Value -lt 0) { return 'N/D' }
    return $Value.ToString($Format, $Invariant)
}

function Get-PositiveMetric($Rows, [string]$Property, [string]$Operation='Maximum') {
    $values = @($Rows | ForEach-Object { if ($_.PSObject.Properties[$Property]) { [double]$_.$Property } } | Where-Object { $_ -ge 0 })
    if (-not $values.Count) { return -1.0 }
    $measurement = $values | Measure-Object -Minimum -Maximum -Average
    return [double]$measurement.$Operation
}

function Select-VisualRows($Rows, [int]$Maximum=700) {
    $all = @($Rows)
    if ($all.Count -le $Maximum) { return $all }
    $step = [math]::Ceiling($all.Count / [double]$Maximum)
    $selected = New-Object 'System.Collections.Generic.List[object]'
    for ($index=0; $index -lt $all.Count; $index += $step) { $selected.Add($all[$index]) }
    if ($selected[$selected.Count-1] -ne $all[-1]) { $selected.Add($all[-1]) }
    return $selected.ToArray()
}

function New-VisualChartSvg($Rows, [object[]]$Series, [string]$Title, [bool]$StartAtZero=$true, [string]$Unit='', [string]$IncidentLabel='INCIDENTE', [string]$EmptySamples='Sin muestras disponibles.', [string]$EmptyReadings='No hay lecturas válidas para esta gráfica.') {
    $width=1000.0; $height=300.0; $left=62.0; $right=24.0; $top=30.0; $bottom=42.0
    $plotWidth=$width-$left-$right; $plotHeight=$height-$top-$bottom
    $all=@($Rows); $sampled=@(Select-VisualRows $all)
    if (-not $all.Count) { return "<section class='chart-card'><h3>$(ConvertTo-HtmlText $Title)</h3><p class='empty'>$(ConvertTo-HtmlText $EmptySamples)</p></section>" }
    $xValues=@($all|ForEach-Object{[double]$_.Segundos});$xMin=($xValues|Measure-Object -Minimum).Minimum;$xMax=($xValues|Measure-Object -Maximum).Maximum
    if($xMax-le$xMin){$xMax=$xMin+1}
    $allY=New-Object 'System.Collections.Generic.List[double]'
    foreach($seriesItem in $Series){foreach($row in $all){if($row.PSObject.Properties[$seriesItem.Field]){$value=[double]$row.($seriesItem.Field);if($value-ge[double]$seriesItem.Minimum){$allY.Add($value)}}}}
    if(-not$allY.Count){return "<section class='chart-card'><h3>$(ConvertTo-HtmlText $Title)</h3><p class='empty'>$(ConvertTo-HtmlText $EmptyReadings)</p></section>"}
    $measured=$allY|Measure-Object -Minimum -Maximum;$yMin=if($StartAtZero){0.0}else{[math]::Floor(([double]$measured.Minimum-5)/5)*5};$yMax=[double]$measured.Maximum
    if($yMax-le$yMin){$yMax=$yMin+1}else{$yMax=$yMax+($yMax-$yMin)*0.08}
    $f={param([double]$n)$n.ToString('0.##',$Invariant)}
    $builder=New-Object Text.StringBuilder
    [void]$builder.Append("<section class='chart-card'><h3>$(ConvertTo-HtmlText $Title)</h3><svg class='chart' viewBox='0 0 1000 300' role='img' aria-label='$(ConvertTo-HtmlText $Title)'>")
    for($grid=0;$grid-le4;$grid++){$ratio=$grid/4.0;$y=$top+$plotHeight*(1-$ratio);$label=$yMin+($yMax-$yMin)*$ratio;[void]$builder.Append("<line class='grid' x1='$left' y1='$(&$f $y)' x2='$($width-$right)' y2='$(&$f $y)'/><text class='axis y-axis' x='$($left-10)' y='$(&$f ($y+4))'>$([Net.WebUtility]::HtmlEncode((Format-VisualNumber $label '0.#')))$([Net.WebUtility]::HtmlEncode($Unit))</text>")}
    foreach($row in $all|Where-Object{[int]$_.Incidente-gt0}){$x=$left+(([double]$row.Segundos-$xMin)/($xMax-$xMin))*$plotWidth;[void]$builder.Append("<line class='incident-line' x1='$(&$f $x)' y1='$top' x2='$(&$f $x)' y2='$($top+$plotHeight)'/><text class='incident-label' x='$(&$f ($x+5))' y='$($top+14)'>$(ConvertTo-HtmlText $IncidentLabel)</text>")}
    foreach($seriesItem in $Series){$path=New-Object Text.StringBuilder;$drawing=$false;foreach($row in $sampled){$value=if($row.PSObject.Properties[$seriesItem.Field]){[double]$row.($seriesItem.Field)}else{-1};if($value-lt[double]$seriesItem.Minimum){$drawing=$false;continue};$x=$left+(([double]$row.Segundos-$xMin)/($xMax-$xMin))*$plotWidth;$y=$top+$plotHeight-(($value-$yMin)/($yMax-$yMin))*$plotHeight;$command=if($drawing){'L'}else{'M'};[void]$path.Append("$command$(&$f $x),$(&$f $y) ");$drawing=$true};if($path.Length){[void]$builder.Append("<path class='series' d='$path' stroke='$($seriesItem.Color)'/>")}}
    $startLabel=if([string]$all[0].FechaHora -match '(\d{2}:\d{2}:\d{2})'){$Matches[1]}else{'Inicio'};$endLabel=if([string]$all[-1].FechaHora -match '(\d{2}:\d{2}:\d{2})'){$Matches[1]}else{'Fin'}
    [void]$builder.Append("<text class='axis' x='$left' y='$($height-12)'>$startLabel</text><text class='axis end' x='$($width-$right)' y='$($height-12)'>$endLabel</text></svg><div class='legend'>")
    foreach($seriesItem in $Series){[void]$builder.Append("<span><i style='background:$($seriesItem.Color)'></i>$(ConvertTo-HtmlText $seriesItem.Label)</span>")}
    [void]$builder.Append('</div></section>')
    return $builder.ToString()
}

function New-VisualReport([string]$CsvPath,[string]$MetadataPath,[string]$MarkerPath,[string]$Destination,[bool]$PrivacyProtected,[string]$ExcelFileName,[string]$RawFileName) {
    $rows=@(Import-Csv -LiteralPath $CsvPath)
    if(-not$rows.Count){throw 'La captura no contiene muestras para el reporte visual.'}
    $metadata=Get-Content -LiteralPath $MetadataPath -Raw|ConvertFrom-Json
    $settings=Get-EventIntelligenceSettings
    $markers=@();if(Test-Path $MarkerPath){try{$parsed=Get-Content $MarkerPath -Raw|ConvertFrom-Json;if($null-ne$parsed){$markers=@($parsed|Where-Object{$null-ne$_-and$_.PSObject.Properties['TimestampLocal']})}}catch{$markers=@()}}
    if($PrivacyProtected){$metadata.Sistema=Protect-SystemMetadata $metadata.Sistema}
    $valid=@($rows|Where-Object{$_.MuestraValida-eq'True'-or$_.MuestraValida-eq$true})
    $diagnosis=Get-Diagnosis $rows;$stability=Get-StabilityMetrics $rows;$incidents=@(Get-IncidentAnalysis $rows $markers $settings)
    $duration=if($rows.Count-gt1){[math]::Max(0,[double]$rows[-1].Segundos-[double]$rows[0].Segundos)}else{0}
    $fpsAverage=Get-PositiveMetric $valid 'FPS' 'Average';$fpsMinimum=@($valid|ForEach-Object{[double]$_.FPS}|Where-Object{$_-gt0}|Measure-Object -Minimum).Minimum
    if($null-eq$fpsMinimum){$fpsMinimum=-1}
    $cpuMax=Get-PositiveMetric $valid 'CPUTemperaturaC';$coreMax=Get-PositiveMetric $valid 'CoreMaxTemperaturaC';$gpuMax=Get-PositiveMetric $valid 'GPUTemperaturaC'
    $ramMax=Get-PositiveMetric $valid 'RAMUsoPct';$vramMax=Get-PositiveMetric $valid 'VRAMUsoPct'
    $thermalCount=@($valid|Where-Object{[int]$_.CPUAlertaTermica-gt0-or[int]$_.GPUAlertaTermica-gt0}).Count
    $powerCount=@($valid|Where-Object{[int]$_.CPUAlertaPotencia-gt0-or[int]$_.GPUAlertaPotencia-gt0}).Count
    $isEnglish=$language-eq'en-US'
    $copy=if($isEnglish){@{title='AlienGamer Mode — Visual event report';summary='Executive summary';session='Captured session';stability='Stability';samples='Valid samples';duration='Duration';fps='Average FPS';fpsMin='Minimum FPS';frame='Frame time P95';cpu='Maximum CPU';gpu='Maximum GPU';memory='Memory pressure';interpretation='Preliminary interpretation';evidence='Observed evidence';recommendation='Suggested next step';charts='Session timeline';fpsChart='Frames per second (FPS)';frameChart='Frame time';temperatures='Component temperatures';utilization='System utilization';incidents='Marked incidents';comparison='Comparison baseline';system='System context';privacy='Protected for sharing';full='Full technical detail';warning='This interpretation is based on correlations in the available sensors. It does not prove a cause or replace a complete technical diagnosis.';noIncidents='No incidents were explicitly marked during this recording.';previous='The previous local session remains available in the Excel comparison sheet.';files='Companion evidence';excel='Excel workbook';raw='Raw CSV';incident='INCIDENT';emptySamples='No samples are available.';emptyReadings='No valid readings are available for this chart.';label='Label';time='Time';tableSamples='Samples';tableStability='Stability';tableInterpretation='Interpretation';minimum='min';coreMax='Core max';thermalFlags='Thermal flags';powerFlags='Power flags';localFooter='Generated locally by AlienGamer Mode. No data was sent over the Internet.'}}else{@{title='AlienGamer Mode — Reporte visual de evento';summary='Resumen ejecutivo';session='Sesión capturada';stability='Estabilidad';samples='Muestras válidas';duration='Duración';fps='FPS promedio';fpsMin='FPS mínimos';frame='Frame time P95';cpu='CPU máxima';gpu='GPU máxima';memory='Presión de memoria';interpretation='Interpretación preliminar';evidence='Evidencia observada';recommendation='Siguiente paso sugerido';charts='Cronología de la sesión';fpsChart='Fotogramas por segundo (FPS)';frameChart='Tiempo por fotograma';temperatures='Temperaturas de componentes';utilization='Uso del sistema';incidents='Incidentes marcados';comparison='Referencia comparativa';system='Contexto del sistema';privacy='Protegido para compartir';full='Detalle técnico completo';warning='Esta interpretación se basa en correlaciones de los sensores disponibles. No demuestra una causa ni sustituye un diagnóstico técnico completo.';noIncidents='No se marcaron incidentes explícitos durante esta grabación.';previous='La sesión local anterior permanece disponible en la hoja Comparación del libro de Excel.';files='Evidencia complementaria';excel='Libro de Excel';raw='CSV de datos brutos';incident='INCIDENTE';emptySamples='Sin muestras disponibles.';emptyReadings='No hay lecturas válidas para esta gráfica.';label='Etiqueta';time='Hora';tableSamples='Muestras';tableStability='Estabilidad';tableInterpretation='Interpretación';minimum='mín.';coreMax='Máximo de núcleos';thermalFlags='Alertas térmicas';powerFlags='Alertas de potencia';localFooter='Generado localmente por AlienGamer Mode. No se enviaron datos a Internet.'}}
    $seriesFps=@([pscustomobject]@{Field='FPS';Label='FPS';Color='#37f58a';Minimum=0.01})
    $seriesFrame=@([pscustomobject]@{Field='FrameTimeMs';Label='Frame time (ms)';Color='#ffb020';Minimum=0.01})
    $seriesTemp=@([pscustomobject]@{Field='CPUTemperaturaC';Label='CPU';Color='#ff6b3d';Minimum=0},[pscustomobject]@{Field='CoreMaxTemperaturaC';Label='Core max';Color='#ff2d55';Minimum=0},[pscustomobject]@{Field='GPUTemperaturaC';Label='GPU';Color='#2eb8ff';Minimum=0},[pscustomobject]@{Field='SSDTemperaturaC';Label='SSD';Color='#ffe082';Minimum=0})
    $seriesUse=@([pscustomobject]@{Field='GPUUsoPct';Label='GPU';Color='#6548ff';Minimum=0},[pscustomobject]@{Field='CPUUsoPct';Label='CPU';Color='#25d9ef';Minimum=0},[pscustomobject]@{Field='RAMUsoPct';Label='RAM';Color='#ff3445';Minimum=0},[pscustomobject]@{Field='VRAMUsoPct';Label='VRAM';Color='#85d000';Minimum=0})
    $charts=(New-VisualChartSvg $rows $seriesFps $copy.fpsChart $true ' FPS' $copy.incident $copy.emptySamples $copy.emptyReadings)+(New-VisualChartSvg $rows $seriesFrame $copy.frameChart $true ' ms' $copy.incident $copy.emptySamples $copy.emptyReadings)+(New-VisualChartSvg $rows $seriesTemp $copy.temperatures $false '°C' $copy.incident $copy.emptySamples $copy.emptyReadings)+(New-VisualChartSvg $rows $seriesUse $copy.utilization $true '%' $copy.incident $copy.emptySamples $copy.emptyReadings)
    $incidentRows=if($incidents.Count){($incidents|ForEach-Object{"<tr><td>$(ConvertTo-HtmlText $_.Index)</td><td>$(ConvertTo-HtmlText $_.Label)</td><td>$(ConvertTo-HtmlText $_.Timestamp)</td><td>$(ConvertTo-HtmlText $_.Samples)</td><td>$($_.StabilityScore)/100 — $(ConvertTo-HtmlText $_.StabilityGrade)</td><td>$(ConvertTo-HtmlText $_.PreliminaryInterpretation)</td></tr>"})-join''}else{"<tr><td colspan='6'>$(ConvertTo-HtmlText $copy.noIncidents)</td></tr>"}
    $systemRows=($metadata.Sistema.PSObject.Properties|Where-Object{$_.Name-notlike'ProcesosConMayorRAM*'}|ForEach-Object{"<tr><th>$(ConvertTo-HtmlText $_.Name)</th><td>$(ConvertTo-HtmlText $_.Value)</td></tr>"})-join''
    $privacyLabel=if($PrivacyProtected){$copy.privacy}else{$copy.full}
    $durationText='{0:00}:{1:00}'-f[Math]::Floor($duration/60),[Math]::Floor($duration%60)
    $interpretation=if($isEnglish){"Stability was rated $($stability.Grade.ToLowerInvariant()) with a score of $($stability.Score)/100. Thermal flags appeared in $thermalCount samples and power-limit flags in $powerCount samples."}else{$diagnosis.Verdict}
    $evidence=if($isEnglish){"Frame time P95: $($stability.P95) ms; P99: $($stability.P99) ms; maximum CPU: $(Format-VisualNumber $cpuMax) °C; maximum GPU: $(Format-VisualNumber $gpuMax) °C."}else{$diagnosis.Evidence}
    $recommendation=if($isEnglish){'Review the marked windows and compare another capture under the same game, scene, power and cooling conditions.'}else{$diagnosis.Recommendation}
    $html=@"
<!doctype html><html lang="$(if($isEnglish){'en'}else{'es'})"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(ConvertTo-HtmlText $copy.title)</title><style>
:root{color-scheme:dark;--bg:#05070a;--panel:rgba(20,25,35,.86);--line:#354052;--text:#edf3ff;--muted:#93a1b7;--cyan:#25d9ef;--orange:#ff7a18;--red:#ff3445}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 75% 0,#10222b 0,transparent 32%),linear-gradient(180deg,#040609,#080b10);color:var(--text);font:15px/1.55 Segoe UI,Arial,sans-serif}.page{max-width:1180px;margin:auto;padding:48px 28px 80px}header{border-bottom:1px solid #273142;padding-bottom:28px;margin-bottom:28px}.eyebrow{color:var(--cyan);font-weight:700;letter-spacing:.18em;text-transform:uppercase}h1{font-size:clamp(30px,5vw,54px);line-height:1.05;margin:.3em 0}.meta,.muted{color:var(--muted)}.badges{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}.badge{border:1px solid #344153;border-radius:999px;padding:6px 12px;background:#101722}.summary{display:grid;grid-template-columns:1.4fr .6fr;gap:20px}.panel,.metric,.chart-card{background:var(--panel);border:1px solid var(--line);border-radius:18px;box-shadow:0 14px 38px #0006}.panel{padding:24px}.verdict{font-size:22px;font-weight:700;color:#fff}.warning{border-left:3px solid var(--orange);padding:12px 16px;background:#21150c;color:#ffd7b3;border-radius:0 10px 10px 0}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:22px 0}.metric{padding:18px}.metric b{display:block;font-size:27px;color:#fff}.metric span{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.08em}.section-title{font-size:26px;margin:42px 0 16px}.chart-card{padding:20px;margin:16px 0}.chart-card h3{margin:0 0 10px}.chart{width:100%;height:auto;display:block}.grid{stroke:#253042;stroke-width:1}.axis{fill:#8997ad;font-size:11px}.y-axis{text-anchor:end}.end{text-anchor:end}.series{fill:none;stroke-width:2.3;stroke-linecap:round;stroke-linejoin:round;vector-effect:non-scaling-stroke}.incident-line{stroke:var(--red);stroke-width:1.5;stroke-dasharray:5 5}.incident-label{fill:#ff6070;font-size:10px;font-weight:700}.legend{display:flex;gap:18px;flex-wrap:wrap;color:var(--muted);font-size:12px}.legend i{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:6px}.table-wrap{overflow:auto}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:11px;border-bottom:1px solid #293345;vertical-align:top}th{color:#9fb0c7}.files a{color:var(--cyan)}details{margin-top:20px}summary{cursor:pointer;color:var(--cyan);font-weight:600}.footer{margin-top:36px;color:var(--muted);font-size:12px}@media(max-width:800px){.summary{grid-template-columns:1fr}.metrics{grid-template-columns:repeat(2,1fr)}.page{padding:28px 14px}}@media(max-width:480px){.metrics{grid-template-columns:1fr}}@media print{body{background:#fff;color:#111}.page{max-width:none;padding:12mm}.panel,.metric,.chart-card{background:#fff;color:#111;box-shadow:none;break-inside:avoid}.meta,.muted,.axis,.legend{color:#444;fill:#444}.verdict,.metric b{color:#111}}
</style></head><body><main class="page"><header><div class="eyebrow">AlienGamer Mode</div><h1>$(ConvertTo-HtmlText $copy.title)</h1><div class="meta">$(ConvertTo-HtmlText $copy.session): $(ConvertTo-HtmlText $metadata.InicioLocal) — $(ConvertTo-HtmlText $metadata.FinLocal)</div><div class="badges"><span class="badge">$(ConvertTo-HtmlText $privacyLabel)</span><span class="badge">$($valid.Count) / $($rows.Count) $(ConvertTo-HtmlText $copy.samples)</span><span class="badge">$($incidents.Count) $(ConvertTo-HtmlText $copy.incidents)</span></div></header>
<section class="summary"><div class="panel"><h2>$(ConvertTo-HtmlText $copy.summary)</h2><div class="verdict">$(ConvertTo-HtmlText $interpretation)</div><h3>$(ConvertTo-HtmlText $copy.evidence)</h3><p>$(ConvertTo-HtmlText $evidence)</p><h3>$(ConvertTo-HtmlText $copy.recommendation)</h3><p>$(ConvertTo-HtmlText $recommendation)</p><p class="warning">$(ConvertTo-HtmlText $copy.warning)</p></div><div class="panel"><h2>$(ConvertTo-HtmlText $copy.stability)</h2><div style="font-size:64px;font-weight:800;color:var(--cyan)">$($stability.Score)<small style="font-size:20px;color:var(--muted)">/100</small></div><div class="verdict">$(ConvertTo-HtmlText $stability.Grade)</div><p class="muted">$(ConvertTo-HtmlText $stability.Reasons)</p></div></section>
<section class="metrics"><div class="metric"><span>$(ConvertTo-HtmlText $copy.duration)</span><b>$durationText</b></div><div class="metric"><span>$(ConvertTo-HtmlText $copy.fps)</span><b>$(Format-VisualNumber $fpsAverage)</b><small class="muted">$(ConvertTo-HtmlText $copy.minimum) $(Format-VisualNumber ([double]$fpsMinimum))</small></div><div class="metric"><span>$(ConvertTo-HtmlText $copy.frame)</span><b>$(Format-VisualNumber ([double]$stability.P95)) ms</b></div><div class="metric"><span>$(ConvertTo-HtmlText $copy.cpu)</span><b>$(Format-VisualNumber $cpuMax) °C</b><small class="muted">$(ConvertTo-HtmlText $copy.coreMax) $(Format-VisualNumber $coreMax) °C</small></div><div class="metric"><span>$(ConvertTo-HtmlText $copy.gpu)</span><b>$(Format-VisualNumber $gpuMax) °C</b></div><div class="metric"><span>$(ConvertTo-HtmlText $copy.memory)</span><b>RAM $(Format-VisualNumber $ramMax)%</b><small class="muted">VRAM $(Format-VisualNumber $vramMax)%</small></div><div class="metric"><span>$(ConvertTo-HtmlText $copy.thermalFlags)</span><b>$thermalCount</b></div><div class="metric"><span>$(ConvertTo-HtmlText $copy.powerFlags)</span><b>$powerCount</b></div></section>
<h2 class="section-title">$(ConvertTo-HtmlText $copy.charts)</h2>$charts
<h2 class="section-title">$(ConvertTo-HtmlText $copy.incidents)</h2><section class="panel table-wrap"><table><thead><tr><th>#</th><th>$(ConvertTo-HtmlText $copy.label)</th><th>$(ConvertTo-HtmlText $copy.time)</th><th>$(ConvertTo-HtmlText $copy.tableSamples)</th><th>$(ConvertTo-HtmlText $copy.tableStability)</th><th>$(ConvertTo-HtmlText $copy.tableInterpretation)</th></tr></thead><tbody>$incidentRows</tbody></table></section>
<h2 class="section-title">$(ConvertTo-HtmlText $copy.files)</h2><section class="panel files"><p><a href="$(ConvertTo-HtmlText $ExcelFileName)">$(ConvertTo-HtmlText $copy.excel)</a> · <a href="$(ConvertTo-HtmlText $RawFileName)">$(ConvertTo-HtmlText $copy.raw)</a></p><p class="muted">$(ConvertTo-HtmlText $copy.previous)</p></section>
<details class="panel"><summary>$(ConvertTo-HtmlText $copy.system)</summary><div class="table-wrap"><table><tbody>$systemRows</tbody></table></div></details><p class="footer">$(ConvertTo-HtmlText $copy.localFooter) $(ConvertTo-HtmlText $copy.warning)</p></main></body></html>
"@
    [IO.File]::WriteAllText($Destination,$html,(New-Object Text.UTF8Encoding($false)))
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
    if(Test-Path $MarkerPath){
        try {
            $parsedMarkers = Get-Content $MarkerPath -Raw | ConvertFrom-Json
            if ($null -ne $parsedMarkers) { $markers = @($parsedMarkers | Where-Object { $null -ne $_ -and $_.PSObject.Properties['TimestampLocal'] }) }
        } catch { $markers=@() }
    }
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
        $directory=[IO.Path]::GetDirectoryName($dialog.FileName);$baseName=[IO.Path]::GetFileNameWithoutExtension($dialog.FileName)
        $rawDestination=[IO.Path]::Combine($directory,($baseName+'-datos-brutos.csv'))
        $visualDestination=[IO.Path]::Combine($directory,($baseName+'-visual.html'))
        $visualError=$null;$excelError=$null
        if([bool]$settings.saveVisualReportBesideReport){try{New-VisualReport $CsvPath $MetadataPath $MarkerPath $visualDestination $privacyProtected ([IO.Path]::GetFileName($dialog.FileName)) ([IO.Path]::GetFileName($rawDestination))}catch{$visualError=$_.Exception.Message}}
        try{New-ExcelReport $CsvPath $MetadataPath $MarkerPath $dialog.FileName $privacyProtected}catch{$excelError=$_.Exception.Message}
        if([bool]$settings.saveRawCsvBesideReport){Copy-Item $CsvPath $rawDestination -Force}
        if(-not$visualError-and-not$excelError){
            $savedPaths="$($dialog.FileName)`n$visualDestination`n$rawDestination"
            [System.Windows.Forms.MessageBox]::Show("$(T 'recorder.saved')`n$savedPaths", 'AlienGamer Mode', 'OK', 'Information') | Out-Null
            Remove-Item -LiteralPath $CsvPath,$MetadataPath,$MarkerPath -Force -ErrorAction SilentlyContinue
        }else{
            $partial=@();if(Test-Path$visualDestination){$partial+=$visualDestination};if(Test-Path$dialog.FileName){$partial+=$dialog.FileName};if(Test-Path$rawDestination){$partial+=$rawDestination}
            $errors=@($visualError,$excelError|Where-Object{$_})-join"`r`n"
            [System.Windows.Forms.MessageBox]::Show("$(T 'recorder.failed')`n$errors`n`n$(T 'recorder.csvPreserved')`n$CsvPath`n`n$($partial-join"`r`n")",'AlienGamer Mode','OK','Warning')|Out-Null
        }
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
