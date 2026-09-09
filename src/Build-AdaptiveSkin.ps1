param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\build\AlienGamerMode.profile.json'),
    [string]$TemplatePath = (Join-Path $PSScriptRoot 'skin\AlienGamerMode.Template.ini'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\Skin\AlienGamerMode'),
    [string]$InstallRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$text = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
$referenceWidth = 1711.0
$referenceHeight = 1023.0
$monitor = $profile.monitor
if (-not $monitor) { throw 'El perfil no contiene un monitor de destino.' }
$scale = [Math]::Min([double]$monitor.width / $referenceWidth, [double]$monitor.height / $referenceHeight)
$offsetX = [Math]::Floor(([double]$monitor.width - $referenceWidth * $scale) / 2)
$offsetY = [Math]::Floor(([double]$monitor.height - $referenceHeight * $scale) / 2)
$matrix = ('{0:0.######};0;0;{0:0.######};{1};{2}' -f $scale, $offsetX, $offsetY)

# La interfaz anima a 10 FPS, pero sensores y cálculos conservan su cadencia
# original. ClockScript queda a 10 FPS y evita reconstruir dígitos sin cambios.
$text = [regex]::Replace($text, '(?m)^UpdateDivider=(\d+)$', {
    param($match)
    'UpdateDivider=' + ([int]$match.Groups[1].Value * 10)
})
$text = [regex]::Replace($text, '(?ms)(^\[ClockScript\].*?^UpdateDivider=)\d+', '${1}1', 1)
$text = [regex]::Replace($text, '(?ms)(^\[SMOOTH_[^\]]+\].*?^UpdateDivider=)\d+', '${1}1')

$text = $text -replace '(?m)^WindowX=.*$', ('WindowX={0}' -f [int]$monitor.x)
$text = $text -replace '(?m)^WindowY=.*$', ('WindowY={0}' -f [int]$monitor.y)
$text = $text -replace '(?m)^WindowWidth=.*$', ('WindowWidth={0}' -f [int]$monitor.width)
$text = $text -replace '(?m)^WindowHeight=.*$', ('WindowHeight={0}' -f [int]$monitor.height)
$text = $text -replace '(?m)^KeepOnScreen=.*$', 'KeepOnScreen=0'
$text = $text -replace '(?m)^OnRefreshAction=.*$', ('OnRefreshAction=[!Move {0} {1}][!DeactivateConfig "illustro\Clock"][!DeactivateConfig "illustro\Disk"][!DeactivateConfig "illustro\System"][!DeactivateConfig "illustro\Welcome"][!DeactivateConfig "HWiNFO"]' -f [int]$monitor.x, [int]$monitor.y)
$bridgePort = [int]$profile.bridgePort
$text = [regex]::Replace($text, '(?ms)(^\[HWiNFO_BRIDGE\].*?^URL=http://127\.0\.0\.1:)\d+/', {
    param($match)
    $match.Groups[1].Value + $bridgePort + '/'
}, 1)
$recorderPath = Join-Path $InstallRoot 'AlienGamerEventRecorder.ps1'
$text = $text -replace '(?m)^EventRecorderPath=.*$', ('EventRecorderPath=' + $recorderPath)
$commandPath = Join-Path $InstallRoot 'AlienGamerModeCommand.ps1'
$text = $text -replace '(?m)^CommandPath=.*$', ('CommandPath=' + $commandPath)
$text = $text -replace '(?m)^BridgeUrl=.*$', ('BridgeUrl=http://127.0.0.1:' + [int]$profile.bridgePort + '/v2/status')
$backgroundSize = "0,0,$([int]$monitor.width),$([int]$monitor.height)"
$text = [regex]::Replace($text, '(?ms)(^\[MeterBackground\].*?^Shape=Rectangle )0,0,1711,1023', {
    param($match)
    $match.Groups[1].Value + $backgroundSize
}, 1)

$model = ("$($profile.computer.manufacturer) $($profile.computer.model)").Trim().ToUpperInvariant()
if (-not $model) { $model = $profile.computer.name.ToUpperInvariant() }
$subtitleSuffix = if ($profile.labels.subtitleSuffix) { [string]$profile.labels.subtitleSuffix } else { 'MONITOR TÉRMICO EN VIVO' }
$subtitleSuffix = $subtitleSuffix -replace '(?i)\bTERMICO\b', 'TÉRMICO'
$appTitle = if ($profile.labels.appTitle) { [string]$profile.labels.appTitle } else { 'ALIENGAMER MODE' }
$signature = if ($profile.labels.signature) { [string]$profile.labels.signature } else { 'by Alienmau' }
$text = [regex]::Replace($text, '(?ms)(^\[MeterTitle\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $appTitle }, 1)
$text = [regex]::Replace($text, '(?ms)(^\[MeterSignature\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $signature }, 1)
$text = [regex]::Replace($text, '(?ms)(^\[MeterSubtitle\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $model + '  /  ' + $subtitleSuffix }, 1)
$text = $text -replace '(?m)^Text=SSD$', ('Text={0}' -f $profile.storageLabel)
if ($profile.appearance) {
    $colorMap = [ordered]@{ Bg='background'; PCore='performanceCore'; ECore='efficiencyCore'; Green='genericCore'; NvidiaGreen='nvidiaGreen' }
    foreach ($entry in $colorMap.GetEnumerator()) {
        $value = $profile.appearance.($entry.Value)
        if ($value) { $text = [regex]::Replace($text, '(?m)^' + $entry.Key + '=.*$', ($entry.Key + '=' + $value), 1) }
    }
}

$coreCount = @($profile.cores).Count
$totalFields = 14 + $coreCount
$capture = '(-?[0-9]+(?:\.[0-9]+)?)'
$regexp = '(?si)^' + ((1..$totalFields | ForEach-Object { $capture }) -join '\|') + '$'
$text = [regex]::Replace($text, '(?m)^RegExp=.*$', ('RegExp=' + $regexp), 1)

$tailIndex = 7 + $coreCount
$tailNames = @('VRAM_USED_MB','VRAM_FREE_MB','FPS_GAME','FRAME_TIME','CPU_THERMAL_ALERT','GPU_THERMAL_ALERT','CPU_POWER_ALERT','GPU_POWER_ALERT')
for ($i = 0; $i -lt $tailNames.Count; $i++) {
    $sectionPattern = '(?ms)(^\[' + [regex]::Escape($tailNames[$i]) + '\].*?^StringIndex=)\d+'
    $stringIndex = $tailIndex + $i
    $text = [regex]::Replace($text, $sectionPattern, { param($m) $m.Groups[1].Value + $stringIndex }, 1)
}

$physical = [int]$profile.cpu.physicalCores
$logical = [int]$profile.cpu.logicalProcessors
$monitored = $coreCount
$pPhysical = [int]$profile.displaySummary.performancePhysicalCores
$ePhysical = [int]$profile.displaySummary.efficiencyPhysicalCores
$legend = if ($pPhysical + $ePhysical -gt 0) {
    "$physical NÚCLEOS FÍSICOS / $logical HILOS  |  $pPhysical NÚCLEOS DE RENDIMIENTO  |  $ePhysical NÚCLEOS EFICIENTES"
} else {
    "$physical NÚCLEOS FÍSICOS / $logical HILOS  |  $monitored PROCESADORES LÓGICOS MONITORIZADOS"
}
$text = [regex]::Replace($text, '(?ms)(^\[MeterCoresLegend\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $legend }, 1)

$coreSectionPattern = '(?ms)^\[(?:CORETEMP|COREUSE|Outline_CORE|BG_CORETEMP|Ring_CORETEMP|Value_CORETEMP|Label_CORETEMP|Use_CORETEMP)\d+\].*?(?=^\[|\z)'
$text = [regex]::Replace($text, $coreSectionPattern, '')

foreach ($measureName in @('GPU_TEMP','GPU_USE','CPU_TEMP','CPU_USE','SSD_TEMP','CORE_MAX','VRAM_USED_MB','VRAM_FREE_MB','FPS_GAME')) {
    $sectionPattern = '(?ms)(^\[' + $measureName + '\].*?)(?=^\[|\z)'
    $text = [regex]::Replace($text, $sectionPattern, {
        param($match)
        if ($match.Value -match '(?m)^Substitute=') { return $match.Value }
        return $match.Value.TrimEnd("`r","`n") + "`r`nSubstitute=`"-1`":`"N/D`"`r`n`r`n"
    }, 1)
}

if ($coreCount -gt 0) {
    $rows = if ($coreCount -le 12) { 1 } elseif ($coreCount -le 24) { 2 } elseif ($coreCount -le 36) { 3 } else { 4 }
    $cols = [Math]::Ceiling($coreCount / $rows)
    $left = 40.0; $right = 1670.0; $top = 655.0; $bottom = 995.0
    $cellW = ($right - $left) / $cols
    $cellH = ($bottom - $top) / $rows
    $size = [Math]::Floor([Math]::Min(100, [Math]::Max(52, [Math]::Min($cellW - 12, $cellH - 38))))
    $radius = [Math]::Floor($size * 0.43)
    $lineStart = [Math]::Floor($radius * 0.78)
    $generated = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $coreCount; $i++) {
        $core = $profile.cores[$i]
        $row = [Math]::Floor($i / $cols)
        $col = $i % $cols
        $x = [Math]::Round($left + $col * $cellW + ($cellW - $size) / 2)
        $rowOffset = if ($row -eq 0) { 35 } else { 5 }
        $y = [Math]::Round($top + $row * $cellH + $rowOffset)
        $cx = [Math]::Round($x + $size / 2)
        $labelY = [Math]::Round($y + $size + 17)
        $color = if ($core.type -eq 'performance') { '#PCore#' } elseif ($core.type -eq 'efficiency') { '#ECore#' } else { '#Green#' }
        $prefix = if ($core.type -eq 'performance') { 'P-CORE' } elseif ($core.type -eq 'efficiency') { 'E-CORE' } else { 'CORE' }
        $index = [int]$core.logicalIndex
        $stringIndex = 7 + $i
        [void]$generated.AppendLine(@"

[COREUSE$i]
Measure=WebParser
URL=[HWiNFO_BRIDGE]
StringIndex=$stringIndex
DynamicVariables=1
MinValue=0
MaxValue=100
UpdateDivider=10
AverageSize=3

[SMOOTH_COREUSE$i]
Measure=Script
ScriptFile=#@#RingAnimator.lua
TargetMeasure=COREUSE$i
Smoothing=0.38
MinValue=0
MaxValue=100
UpdateDivider=1

[Outline_CORE$i]
Meter=Shape
Shape=Ellipse $([Math]::Round($size/2)),$([Math]::Round($size/2)),$radius,$radius | Fill Color 0,0,0,0 | StrokeWidth 6 | Stroke Color 125,135,155,180
X=$x
Y=$y

[Ring_CORETEMP$i]
Meter=Roundline
MeasureName=SMOOTH_COREUSE$i
X=$x
Y=$y
W=$size
H=$size
StartAngle=4.7124
RotationAngle=6.2832
LineLength=$radius
LineStart=$lineStart
LineColor=$color
Solid=1
AntiAlias=1

[Value_CORETEMP$i]
Meter=String
MeasureName=COREUSE$i
X=$cx
Y=$([Math]::Round($y+$size/2))
StringAlign=CenterCenter
Text=%1%
NumOfDecimals=1
FontFace=Segoe UI Semibold
FontSize=13
FontColor=#Text#
AntiAlias=1

[Label_CORETEMP$i]
Meter=String
X=$cx
Y=$labelY
StringAlign=CenterCenter
Text=$prefix $index
FontFace=Segoe UI
StringStyle=Bold
FontSize=10
FontColor=255,255,255,255
AntiAlias=1
"@)
    }
    $text += $generated.ToString()
}

# Transform every visual meter as one responsive canvas. The full-screen black
# background remains fixed; content gets a shared group for safe OLED shifting.
$text = [regex]::Replace($text, '(?ms)^\[([^\]]+)\](.*?)(?=^\[|\z)', {
    param($match)
    $block = $match.Value
    $sectionName = $match.Groups[1].Value
    if ($block -match '(?m)^Meter=' -and $sectionName -ne 'MeterBackground') {
        if ($block -match '(?m)^Group=(.*)$') { $block = [regex]::Replace($block, '(?m)^Group=(.*)$', 'Group=$1|OLEDShift', 1) }
        else { $block = $block.TrimEnd("`r","`n") + "`r`nGroup=OLEDShift`r`n" }
        if ($block -notmatch '(?m)^TransformationMatrix=') { $block = $block.TrimEnd("`r","`n") + "`r`nTransformationMatrix=$matrix`r`n" }
        return $block.TrimEnd("`r","`n") + "`r`n`r`n"
    }
    return $block
})

$shift0 = ('{0:0.######};0;0;{0:0.######};{1};{2}' -f $scale, $offsetX, $offsetY)
$shift1 = ('{0:0.######};0;0;{0:0.######};{1};{2}' -f $scale, ($offsetX + 2), ($offsetY + 1))
$shift2 = ('{0:0.######};0;0;{0:0.######};{1};{2}' -f $scale, $offsetX, ($offsetY + 2))
$shift3 = ('{0:0.######};0;0;{0:0.######};{1};{2}' -f $scale, ($offsetX - 2), ($offsetY + 1))
$pixelSection = @"
[PixelShift]
Measure=Calc
Formula=Counter % 4
Counter=0
UpdateDivider=1200
IfCondition=(PixelShift = 0)
IfTrueAction=[!SetOptionGroup OLEDShift TransformationMatrix "$shift0"][!UpdateMeterGroup OLEDShift][!Redraw]
IfCondition2=(PixelShift = 1)
IfTrueAction2=[!SetOptionGroup OLEDShift TransformationMatrix "$shift1"][!UpdateMeterGroup OLEDShift][!Redraw]
IfCondition3=(PixelShift = 2)
IfTrueAction3=[!SetOptionGroup OLEDShift TransformationMatrix "$shift2"][!UpdateMeterGroup OLEDShift][!Redraw]
IfCondition4=(PixelShift = 3)
IfTrueAction4=[!SetOptionGroup OLEDShift TransformationMatrix "$shift3"][!UpdateMeterGroup OLEDShift][!Redraw]

"@
$text = [regex]::Replace($text, '(?ms)^\[PixelShift\].*?(?=^\[|\z)', $pixelSection, 1)

# TransformationMatrix cambia la posición dibujada, pero Rainmeter puede conservar
# el área de ratón en las coordenadas originales. Estas capas se agregan al final,
# por encima de todos los medidores, usando coordenadas físicas ya escaladas.
$offHitX = [Math]::Round(1535 * $scale + $offsetX)
$offHitY = [Math]::Round(35 * $scale + $offsetY)
$offHitW = [Math]::Ceiling(105 * $scale)
$offHitH = [Math]::Ceiling(40 * $scale)
$recordHitX = [Math]::Round(1435 * $scale + $offsetX)
$recordHitY = [Math]::Round(95 * $scale + $offsetY)
$recordHitW = [Math]::Ceiling(205 * $scale)
$recordHitH = [Math]::Ceiling(40 * $scale)
$text += @"

[HitArea_Record]
Meter=Shape
X=$recordHitX
Y=$recordHitY
W=$recordHitW
H=$recordHitH
Shape=Rectangle 0,0,$recordHitW,$recordHitH | Fill Color 0,0,0,1 | StrokeWidth 0
LeftMouseUpAction=["C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "#EventRecorderPath#" -Toggle -BridgeUrl "#BridgeUrl#" -RainmeterConfig "AlienGamerMode"]
MouseOverAction=[!SetVariable RecordHover 1]
MouseLeaveAction=[!SetVariable RecordHover 0]
MouseActionCursor=1
ToolTipText=Iniciar o finalizar la grabación de un evento
DynamicVariables=1

[HitArea_Off]
Meter=Shape
X=$offHitX
Y=$offHitY
W=$offHitW
H=$offHitH
Shape=Rectangle 0,0,$offHitW,$offHitH | Fill Color 0,0,0,1 | StrokeWidth 0
LeftMouseUpAction=["C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "#CommandPath#" -Stop]
MouseOverAction=[!SetVariable OffHover 1]
MouseLeaveAction=[!SetVariable OffHover 0]
MouseActionCursor=1
ToolTipText=Desactivar AlienGamer Mode
DynamicVariables=1
"@

if (-not (Test-Path $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
$resources = Join-Path $OutputDirectory '@Resources'
if (-not (Test-Path $resources)) { New-Item -ItemType Directory -Path $resources -Force | Out-Null }
$outputIni = Join-Path $OutputDirectory 'AlienGamerMode.ini'
# Rainmeter interpreta de forma consistente sus skins Unicode como UTF-16 LE.
# UTF-8 provocaba secuencias visibles como "Â¡" y "ATENCIÃ“N".
$text | Set-Content -LiteralPath $outputIni -Encoding Unicode
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skin\MatrixClock.lua') -Destination (Join-Path $resources 'MatrixClock.lua') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skin\RingAnimator.lua') -Destination (Join-Path $resources 'RingAnimator.lua') -Force
$signatureCandidates = @(
    (Join-Path $InstallRoot 'assets\AlienmauSignature.png'),
    (Join-Path $PSScriptRoot '..\assets\AlienmauSignature.png')
)
$signatureAsset = $signatureCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $signatureAsset) { throw 'Falta el recurso gráfico AlienmauSignature.png.' }
Copy-Item -LiteralPath $signatureAsset -Destination (Join-Path $resources 'AlienmauSignature.png') -Force

[pscustomobject]@{
    output = $outputIni
    monitor = $monitor.deviceName
    scale = $scale
    offsetX = $offsetX
    offsetY = $offsetY
    coreCount = $coreCount
    totalBridgeFields = $totalFields
}
