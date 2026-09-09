param(
    [switch]$Toggle,
    [switch]$Worker,
    [string]$SessionId,
    [int]$SampleIntervalMs = 1000,
    [string]$BridgeUrl = 'http://127.0.0.1:27843/v2/status',
    [string]$RainmeterConfig = 'AlienGamerMode'
)

$ErrorActionPreference = 'Stop'
$Invariant = [Globalization.CultureInfo]::InvariantCulture
$RuntimeRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
$StatePath = Join-Path $RuntimeRoot 'recording-state.json'
$StopPath = Join-Path $RuntimeRoot 'recording.stop'
$Rainmeter = 'C:\Program Files\Rainmeter\Rainmeter.exe'
$PendingRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode\GrabacionesPendientes'
Add-Type -AssemblyName Microsoft.VisualBasic

function Set-RainmeterRecordingState([bool]$Recording) {
    if (-not (Test-Path -LiteralPath $Rainmeter)) { return }
    if ($Recording) {
        & $Rainmeter '!SetVariable' 'RecordingActive' '1' $RainmeterConfig
        & $Rainmeter '!SetOption' 'MeterRecordLabel' 'Text' 'FINALIZAR GRABACIÓN' $RainmeterConfig
        & $Rainmeter '!ShowMeter' 'MeterRecordingDot' $RainmeterConfig
    } else {
        & $Rainmeter '!SetVariable' 'RecordingActive' '0' $RainmeterConfig
        & $Rainmeter '!SetOption' 'MeterRecordLabel' 'Text' 'GRABAR EVENTO' $RainmeterConfig
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

function Start-RecordingWorker {
    New-Item -ItemType Directory -Path $RuntimeRoot,$PendingRoot -Force | Out-Null
    Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
    $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,8))
    $csv = Join-Path $PendingRoot ("Evento-$id.csv")
    $meta = Join-Path $PendingRoot ("Evento-$id-meta.json")
    $state = [pscustomobject]@{
        SessionId = $id
        StartUtc = [DateTime]::UtcNow.ToString('o')
        CsvPath = $csv
        MetadataPath = $meta
        WorkerPid = 0
        Status = 'recording'
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8

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

function Get-Diagnosis($Rows) {
    $valid = @($Rows | Where-Object { $_.MuestraValida -eq 'True' -or $_.MuestraValida -eq $true })
    if ($valid.Count -eq 0) {
        return [pscustomobject]@{ Verdict='Sin datos validos'; Evidence='El puente de sensores no entrego muestras validas durante el evento.'; Severity='Critico' }
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
    return [pscustomobject]@{ Verdict=($verdict -join ' | '); Evidence=($evidence -join ' '); Severity=$severity }
}

function Write-ExcelMatrix($Sheet, [int]$StartRow, [int]$StartColumn, [object[][]]$Rows) {
    if ($Rows.Count -eq 0) { return }
    $columns = $Rows[0].Count
    $matrix = New-Object 'object[,]' $Rows.Count, $columns
    for ($r=0; $r -lt $Rows.Count; $r++) { for ($c=0; $c -lt $columns; $c++) { $matrix[$r,$c] = $Rows[$r][$c] } }
    $topLeft = $Sheet.Cells.Item($StartRow, $StartColumn)
    $bottomRight = $Sheet.Cells.Item($StartRow + $Rows.Count - 1, $StartColumn + $columns - 1)
    $Sheet.Range($topLeft, $bottomRight).Value2 = $matrix
}

function New-ExcelReport([string]$CsvPath, [string]$MetadataPath, [string]$Destination) {
    $rows = @(Import-Csv -LiteralPath $CsvPath)
    $metadata = Get-Content -LiteralPath $MetadataPath -Raw | ConvertFrom-Json
    $diagnosis = Get-Diagnosis $rows
    $valid = @($rows | Where-Object { $_.MuestraValida -eq 'True' })
    $excel = $null; $book = $null
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $book = $excel.Workbooks.Add()
        while ($book.Worksheets.Count -lt 5) { [void]$book.Worksheets.Add() }
        $summary = $book.Worksheets.Item(1); $summary.Name = 'Resumen'
        $timeline = $book.Worksheets.Item(2); $timeline.Name = 'Cronologia'
        $cores = $book.Worksheets.Item(3); $cores.Name = 'Nucleos'
        $system = $book.Worksheets.Item(4); $system.Name = 'Sistema'
        $criteria = $book.Worksheets.Item(5); $criteria.Name = 'Criterios'
        for ($i=$book.Worksheets.Count; $i -gt 5; $i--) { $book.Worksheets.Item($i).Delete() }

        $dark = 0x211814; $header = 0x463730; $cyan = 0xFFE100; $white = 0xFFFFFF; $muted = 0xB9A091; $orange = 0x20B0FF
        foreach ($sheet in @($summary,$timeline,$cores,$system,$criteria)) {
            $sheet.Cells.Font.Name = 'Segoe UI'
            $sheet.Cells.Font.Size = 10
            $sheet.Cells.Interior.Color = $dark
            $sheet.Cells.Font.Color = $white
        }

        $summary.Range('A1:H1').Merge(); $summary.Range('A1').Value2='ALIENGAMER MODE - REPORTE DE EVENTO'; $summary.Range('A1').Font.Size=20; $summary.Range('A1').Font.Bold=$true; $summary.Range('A1').Font.Color=$orange
        $summary.Range('A3:B3').Value2=@('CAMPO','VALOR'); $summary.Range('A3:B3').Interior.Color=$header; $summary.Range('A3:B3').Font.Bold=$true
        $duration = if ($rows.Count -gt 0) { [double]$rows[-1].Segundos } else { 0 }
        $summaryRows = @(
            @('Inicio', $metadata.InicioLocal), @('Fin', $metadata.FinLocal), @('Duracion (s)', [math]::Round($duration,1)), @('Muestras', $rows.Count), @('Muestras validas', $valid.Count),
            @('Juego', 'Completar por el usuario'), @('Sintoma observado', 'Completar por el usuario'), @('Escena / partida', 'Completar por el usuario'), @('Notas', 'Completar por el usuario'),
            @('Veredicto preliminar', $diagnosis.Verdict), @('Severidad', $diagnosis.Severity), @('Evidencia', $diagnosis.Evidence), @('Advertencia', 'Diagnostico orientativo; correlacionar con el momento exacto del sintoma y evidencia adicional.')
        )
        Write-ExcelMatrix $summary 4 1 $summaryRows

        $summary.Range('D3:E3').Value2=@('INDICADOR','RESULTADO'); $summary.Range('D3:E3').Interior.Color=$header; $summary.Range('D3:E3').Font.Bold=$true
        function Avg($name) { if ($valid.Count) { [math]::Round((($valid | Measure-Object $name -Average).Average),2) } else { 0 } }
        function Max($name) { if ($valid.Count) { [math]::Round((($valid | Measure-Object $name -Maximum).Maximum),2) } else { 0 } }
        function MinPositive($name) { $v=@($valid | ForEach-Object { [double]($_.$name) } | Where-Object { $_ -gt 0 }); if($v.Count){[math]::Round(($v|Measure-Object -Minimum).Minimum,2)}else{0} }
        $kpis = @(
            @('FPS promedio',(Avg 'FPS')), @('FPS minimo',(MinPositive 'FPS')), @('FPS 1% low aprox.',[math]::Round((Get-Percentile ([double[]]@($valid.FPS)) 0.01),2)),
            @('Frame time promedio ms',(Avg 'FrameTimeMs')), @('Frame time P95 ms',[math]::Round((Get-Percentile ([double[]]@($valid.FrameTimeMs)) 0.95),2)), @('Frame time P99 ms',[math]::Round((Get-Percentile ([double[]]@($valid.FrameTimeMs)) 0.99),2)), @('Frame time max ms',(Max 'FrameTimeMs')),
            @('GPU temperatura max C',(Max 'GPUTemperaturaC')), @('GPU uso max %',(Max 'GPUUsoPct')), @('CPU temperatura max C',(Max 'CPUTemperaturaC')), @('Core max temperatura C',(Max 'CoreMaxTemperaturaC')), @('CPU uso max %',(Max 'CPUUsoPct')),
            @('SSD temperatura max C',(Max 'SSDTemperaturaC')), @('RAM uso max %',(Max 'RAMUsoPct')), @('VRAM uso max %',(Max 'VRAMUsoPct')),
            @('Muestras CPU thermal',@($valid|Where-Object{[int]$_.CPUAlertaTermica -gt 0}).Count), @('Muestras GPU thermal',@($valid|Where-Object{[int]$_.GPUAlertaTermica -gt 0}).Count),
            @('Muestras CPU power limit',@($valid|Where-Object{[int]$_.CPUAlertaPotencia -gt 0}).Count), @('Muestras GPU power limit',@($valid|Where-Object{[int]$_.GPUAlertaPotencia -gt 0}).Count)
        )
        Write-ExcelMatrix $summary 4 4 $kpis
        $summary.Columns.Item('A').ColumnWidth=25; $summary.Columns.Item('B').ColumnWidth=75; $summary.Columns.Item('D').ColumnWidth=31; $summary.Columns.Item('E').ColumnWidth=18
        $summary.Range('A4:B20').WrapText=$true

        $timelineHeaders = @('Muestra','Fecha y hora','Segundos','Valida','Latencia puente ms','FPS','Frame time ms','Clasificacion','GPU temp C','GPU uso %','CPU temp C','CPU uso %','SSD temp C','Core max temp C','RAM usada GB','RAM disponible GB','RAM total GB','RAM uso %','VRAM usada GB','VRAM disponible GB','VRAM total GB','VRAM uso %','CPU thermal','GPU thermal','CPU power limit','GPU power limit','Error')
        Write-ExcelMatrix $timeline 1 1 (,([object[]]$timelineHeaders))
        $timelineRows = foreach($r in $rows){ ,@($r.Muestra,$r.FechaHora,[double]$r.Segundos,$r.MuestraValida,[double]$r.LatenciaPuenteMs,[double]$r.FPS,[double]$r.FrameTimeMs,$r.ClasificacionFrameTime,[double]$r.GPUTemperaturaC,[double]$r.GPUUsoPct,[double]$r.CPUTemperaturaC,[double]$r.CPUUsoPct,[double]$r.SSDTemperaturaC,[double]$r.CoreMaxTemperaturaC,[double]$r.RAMUsadaGB,[double]$r.RAMDisponibleGB,[double]$r.RAMTotalGB,[double]$r.RAMUsoPct,[double]$r.VRAMUsadaGB,[double]$r.VRAMDisponibleGB,[double]$r.VRAMTotalGB,[double]$r.VRAMUsoPct,[int]$r.CPUAlertaTermica,[int]$r.GPUAlertaTermica,[int]$r.CPUAlertaPotencia,[int]$r.GPUAlertaPotencia,$r.ErrorMuestra) }
        if($timelineRows.Count){ Write-ExcelMatrix $timeline 2 1 $timelineRows }
        $timeline.Range('A1:AA1').Interior.Color=$header; $timeline.Range('A1:AA1').Font.Bold=$true; $timeline.Range('A1:AA1').AutoFilter() | Out-Null
        $timeline.Range('A:AA').EntireColumn.AutoFit() | Out-Null; $timeline.Columns.Item('B').ColumnWidth=24; $timeline.Columns.Item('AA').ColumnWidth=45

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

        $criteriaRows = @(
            @('METRICA','RANGO / EVENTO','INTERPRETACION'),
            @('Frame time','< 8.3 ms','Excelente; equivale a mas de 120 FPS'), @('Frame time','8.3 a < 16.7 ms','Fluido; entre 60 y 120 FPS'), @('Frame time','16.7 a 33.3 ms','Atencion; entre 30 y 60 FPS'), @('Frame time','> 33.3 ms','Baja fluidez; menos de 30 FPS'),
            @('CPU thermal / GPU thermal','1','HWiNFO detecto limitacion termica'), @('CPU/GPU power limit','1','El componente alcanzo un limite electrico o de potencia'), @('VRAM / RAM','>= 90%','Presion de memoria probable'), @('SSD','>= 65 C','Temperatura alta; correlacionar con caidas y actividad de disco'),
            @('Limitacion','General','FPS/PresentMon puede ser N/D fuera de un juego 3D o alterarse en una sesion remota.'), @('Alcance','General','Este reporte orienta; no sustituye logs del juego, red, SMART detallado ni trazas ETW.')
        )
        Write-ExcelMatrix $criteria 1 1 $criteriaRows; $criteria.Range('A1:C1').Interior.Color=$header; $criteria.Range('A1:C1').Font.Bold=$true; $criteria.Columns.Item('A').ColumnWidth=28; $criteria.Columns.Item('B').ColumnWidth=24; $criteria.Columns.Item('C').ColumnWidth=95; $criteria.Range('A:C').WrapText=$true

        foreach($sheet in @($summary,$timeline,$cores,$system,$criteria)) { $sheet.Rows.Item(1).RowHeight=28; $sheet.Activate(); $excel.ActiveWindow.SplitRow=1; $excel.ActiveWindow.FreezePanes=$true }
        $summary.Activate()
        $book.SaveAs($Destination, 51)
    } finally {
        if($book){$book.Close($false)}
        if($excel){$excel.Quit()}
        foreach($obj in @($criteria,$system,$cores,$timeline,$summary,$book,$excel)){if($obj){[void][Runtime.InteropServices.Marshal]::ReleaseComObject($obj)}}
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}

function Finish-Recording([string]$CsvPath, [string]$MetadataPath, [datetime]$StartedAt, [string]$StartProcesses) {
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
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = 'Guardar reporte de evento de AlienGamer Mode'
    $dialog.Filter = 'Libro de Excel (*.xlsx)|*.xlsx'
    $dialog.DefaultExt = 'xlsx'
    $dialog.AddExtension = $true
    $dialog.FileName = 'AlienGamerMode-Evento-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xlsx'
    $dialog.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        New-ExcelReport $CsvPath $MetadataPath $dialog.FileName
        [System.Windows.Forms.MessageBox]::Show("Reporte guardado correctamente en:`n$($dialog.FileName)", 'AlienGamer Mode', 'OK', 'Information') | Out-Null
        Remove-Item -LiteralPath $CsvPath,$MetadataPath -Force -ErrorAction SilentlyContinue
    } else {
        [System.Windows.Forms.MessageBox]::Show("No se perdió la captura. Los datos pendientes permanecen en:`n$CsvPath", 'AlienGamer Mode', 'OK', 'Information') | Out-Null
    }
}

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

if ($Worker) {
    $state = Read-State
    if (-not $state -or $state.SessionId -ne $SessionId) { exit 2 }
    $startedAt = Get-Date
    $startProcesses = Get-TopProcesses
    $index = 0
    try {
        while (-not (Test-Path -LiteralPath $StopPath)) {
            $index++
            $sample = Get-Sample $startedAt $index
            if ($index -eq 1) { $sample | Export-Csv -LiteralPath $state.CsvPath -NoTypeInformation -Encoding UTF8 }
            else { $sample | Export-Csv -LiteralPath $state.CsvPath -NoTypeInformation -Encoding UTF8 -Append }
            Start-Sleep -Milliseconds ([math]::Max(250,$SampleIntervalMs))
        }
        Finish-Recording $state.CsvPath $state.MetadataPath $startedAt $startProcesses
    } catch {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show("No fue posible completar el reporte:`n$($_.Exception.Message)`n`nLa captura CSV se conserva en:`n$($state.CsvPath)", 'AlienGamer Mode', 'OK', 'Error') | Out-Null
    } finally {
        Remove-Item -LiteralPath $StatePath,$StopPath -Force -ErrorAction SilentlyContinue
        Set-RainmeterRecordingState $false
    }
}
