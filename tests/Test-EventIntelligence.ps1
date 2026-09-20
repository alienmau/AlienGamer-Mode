$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path $root 'build\tests\event-intelligence'
New-Item -ItemType Directory -Path $testRoot -Force|Out-Null
. (Join-Path $root 'src\AlienGamerEventRecorder.ps1') -RuntimeDirectory $testRoot

$started=(Get-Date).AddSeconds(-70)
$rows=for($i=0;$i -lt 70;$i++){
    $frame=if($i -in 45..49){55.0}elseif($i%13-eq 0){24.0}else{8.4+($i%5)}
    [pscustomobject][ordered]@{
        Muestra=$i+1;FechaHora=$started.AddSeconds($i).ToString('yyyy-MM-dd HH:mm:ss.fff');Segundos=$i-60;Fase=if($i-lt 60){'Pre-evento'}else{'Grabacion'};Incidente=if($i-eq 47){1}else{0};IncidenteEtiqueta=if($i-eq 47){'Incidente 1'}else{''};MuestraValida=$true;LatenciaPuenteMs=3.2;FPS=[math]::Round(1000/$frame,1);FrameTimeMs=$frame;ClasificacionFrameTime=Get-FrameClass $frame;GPUTemperaturaC=68;GPUUsoPct=if($i-in 45..49){97}else{72};CPUTemperaturaC=74;CPUUsoPct=55;SSDTemperaturaC=46;CoreMaxTemperaturaC=78;RAMUsadaGB=12;RAMDisponibleGB=20;RAMTotalGB=32;RAMUsoPct=37.5;VRAMUsadaGB=7;VRAMDisponibleGB=9;VRAMTotalGB=16;VRAMUsoPct=43.8;CPUAlertaTermica=0;GPUAlertaTermica=0;CPUAlertaPotencia=0;GPUAlertaPotencia=if($i-eq 48){1}else{0};ErrorMuestra='';Core0UsoPct=44;Core1UsoPct=62
    }
}
$csv=Join-Path $testRoot 'evento.csv';$meta=Join-Path $testRoot 'meta.json';$markers=Join-Path $testRoot 'incidentes.json';$xlsx=Join-Path $testRoot 'AlienGamerMode-Evento-prueba.xlsx';$html=Join-Path $testRoot 'AlienGamerMode-Evento-prueba-visual.html';$rawName='AlienGamerMode-Evento-prueba-datos-brutos.csv'
Remove-Item $xlsx -Force -ErrorAction SilentlyContinue
Remove-Item $html -Force -ErrorAction SilentlyContinue
$rows|Export-Csv $csv -NoTypeInformation -Encoding UTF8
[pscustomobject]@{InicioLocal=$started.ToString('yyyy-MM-dd HH:mm:ss');FinLocal=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss');Sistema=[pscustomobject]@{Equipo='EQUIPO-PRIVADO';Procesador='CPU prueba';ProcesosConMayorRAMAlInicio='Juego (PID 1234, RAM 1024 MB, CPU 4 s)'}}|ConvertTo-Json -Depth 5|Set-Content $meta -Encoding UTF8
@([pscustomobject]@{Index=1;TimestampUtc=$started.AddSeconds(47).ToUniversalTime().ToString('o');TimestampLocal=$started.AddSeconds(47).ToString('yyyy-MM-dd HH:mm:ss.fff');Label='Incidente 1'})|ConvertTo-Json|Set-Content $markers -Encoding UTF8
New-VisualReport $csv $meta $markers $html $true ([IO.Path]::GetFileName($xlsx)) $rawName
if(-not(Test-Path $html)){throw 'No se creó el reporte visual de prueba.'}
$visual=[IO.File]::ReadAllText($html,[Text.Encoding]::UTF8)
foreach($requiredText in @('Reporte visual de evento','Resumen ejecutivo','Cronolog','Fotogramas por segundo','Tiempo por fotograma','Temperaturas de componentes','Uso del sistema','Incidentes marcados','Interpretaci','EQUIPO-PRIVADO')){
    if($requiredText-eq'EQUIPO-PRIVADO') { if($visual-match[regex]::Escape($requiredText)){throw 'El reporte visual no protegió el identificador del equipo.'} }
    elseif($visual-notmatch[regex]::Escape($requiredText)){throw "Falta contenido visual: $requiredText"}
}
if(([regex]::Matches($visual,"<svg class='chart'")).Count-ne4){throw 'El reporte visual no contiene sus cuatro gráficas.'}
if($visual-notmatch"class='incident-line'"-or$visual-notmatch'Incidente 1'){throw 'El reporte visual no representa el incidente marcado.'}
New-ExcelReport $csv $meta $markers $xlsx $true
if(-not(Test-Path $xlsx)){throw 'No se creó el reporte de prueba.'}
$excel=New-Object -ComObject Excel.Application;$excel.Visible=$false;$book=$excel.Workbooks.Open($xlsx)
try{
    $names=@($book.Worksheets|ForEach-Object{$_.Name})
    foreach($required in @('Resumen','Cronologia','Nucleos','Sistema','Criterios','Incidentes','Comparacion','Datos_brutos','Privacidad')){if($required-notin$names){throw "Falta la hoja $required"}}
    $summarySheet=$book.Worksheets.Item('Resumen');$score=$null
    for($row=1;$row-le 40;$row++){if([string]$summarySheet.Cells.Item($row,4).Text -like '*estabilidad (0-100)*'){$score=[double]$summarySheet.Cells.Item($row,5).Value2;break}}
    if($null-eq$score){throw 'No se encontró la puntuación de estabilidad.'}
    if($score -lt 0 -or $score -gt 100){throw 'La puntuación de estabilidad no es válida.'}
    if($book.Worksheets.Item('Incidentes').Range('A2').Value2 -ne 1){throw 'No se exportó la marca de incidente.'}
    if($book.Worksheets.Item('Sistema').Range('B2').Text -match 'EQUIPO-PRIVADO'){throw 'El asistente de privacidad no ocultó el identificador.'}
}finally{$book.Close($false);$excel.Quit();[void][Runtime.InteropServices.Marshal]::ReleaseComObject($book);[void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel)}
Write-Host "OK: reportes visual y Excel de Event Intelligence validados en $testRoot" -ForegroundColor Green
