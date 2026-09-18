param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\build\AlienGamerMode.profile.json'),
    [string]$TemplatePath = (Join-Path $PSScriptRoot 'skin\AlienGamerMode.Template.ini'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\Skin\AlienGamerMode'),
    [string]$InstallRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.Localization.psm1') -Force
$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$language = Resolve-AGLanguage $(if ($profile.language) { [string]$profile.language } else { 'es-MX' })
$ui = Get-AGTranslations -Language $language
$text = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
$referenceWidth = 1711.0
$referenceHeight = 1023.0
$monitor = $profile.monitor
if (-not $monitor) { throw 'El perfil no contiene un monitor de destino.' }
$scale = [Math]::Min([double]$monitor.width / $referenceWidth, [double]$monitor.height / $referenceHeight)
$offsetX = [Math]::Floor(([double]$monitor.width - $referenceWidth * $scale) / 2)
$offsetY = [Math]::Floor(([double]$monitor.height - $referenceHeight * $scale) / 2)
$matrix = ('{0:0.######};0;0;{0:0.######};{1};{2}' -f $scale, $offsetX, $offsetY)

$backgroundEffect = if ($profile.appearance -and $profile.appearance.backgroundEffect) { $profile.appearance.backgroundEffect } else { $null }
$backgroundEnabled = if ($null -ne $backgroundEffect -and $null -ne $backgroundEffect.enabled) { [bool]$backgroundEffect.enabled } else { $true }
$backgroundMode = if ($backgroundEffect -and [string]$backgroundEffect.mode -in @('manual','thermal')) { [string]$backgroundEffect.mode } else { 'manual' }
$backgroundParticleCount = if ($backgroundEffect -and $null -ne $backgroundEffect.particleCount) { [Math]::Max(8, [Math]::Min(48, [int]$backgroundEffect.particleCount)) } else { 26 }
$backgroundSpeed = if ($backgroundEffect -and $null -ne $backgroundEffect.speed) { [Math]::Max(0.2, [Math]::Min(1.5, [double]$backgroundEffect.speed)) } else { 0.65 }
$backgroundSizeScale = if ($backgroundEffect -and $null -ne $backgroundEffect.sizeScale) { [Math]::Max(0.7, [Math]::Min(1.6, [double]$backgroundEffect.sizeScale)) } else { 1.0 }
$backgroundColor = if ($backgroundEffect -and ([string]$backgroundEffect.color) -match '^\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*$') {
    '{0},{1},{2}' -f [Math]::Min(255,[int]$Matches[1]), [Math]::Min(255,[int]$Matches[2]), [Math]::Min(255,[int]$Matches[3])
} else { '255,112,20' }
$backgroundFps = if ($backgroundEffect -and $null -ne $backgroundEffect.updateFps) { [Math]::Max(2, [Math]::Min(10, [int]$backgroundEffect.updateFps)) } else { 10 }
$backgroundDivider = [Math]::Max(1, [Math]::Round(10 / $backgroundFps))
$processorPanelVisible = if ($profile.features -and $null -ne $profile.features.processorPanelVisible) { [bool]$profile.features.processorPanelVisible } else { $true }
$performancePanelVisible = if ($profile.features -and $null -ne $profile.features.performancePanelVisible) { [bool]$profile.features.performancePanelVisible } else { $true }
$clockVisible = if ($profile.features -and $null -ne $profile.features.clock) { [bool]$profile.features.clock } else { $true }
$compactOverlay = if ($profile.features -and $null -ne $profile.features.compactOverlay) { [bool]$profile.features.compactOverlay } else { $false }
if($compactOverlay){$processorPanelVisible=$false;$performancePanelVisible=$true;$clockVisible=$false}

# La interfaz anima a 10 FPS, pero sensores y cálculos conservan su cadencia
# original. ClockScript queda a 10 FPS y evita reconstruir dígitos sin cambios.
$text = [regex]::Replace($text, '(?m)^UpdateDivider=(\d+)$', {
    param($match)
    'UpdateDivider=' + ([int]$match.Groups[1].Value * 10)
})
$text = [regex]::Replace($text, '(?ms)(^\[ClockScript\].*?^UpdateDivider=)\d+', '${1}1', 1)
$text = [regex]::Replace($text, '(?ms)(^\[BackgroundScript\].*?^UpdateDivider=)\d+', { param($m) $m.Groups[1].Value + $backgroundDivider }, 1)
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
$subtitleSuffix = [string]$ui.skin.subtitle
$appTitle = if ($profile.labels.appTitle) { [string]$profile.labels.appTitle } else { 'ALIENGAMER MODE' }
$signature = if ($profile.labels.signature) { [string]$profile.labels.signature } else { 'by Alienmau' }
$text = [regex]::Replace($text, '(?ms)(^\[MeterTitle\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $appTitle }, 1)
$text = [regex]::Replace($text, '(?ms)(^\[MeterSignature\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $signature }, 1)
$text = [regex]::Replace($text, '(?ms)(^\[MeterSubtitle\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $model + '  /  ' + $subtitleSuffix }, 1)
$storageLabel = if ($profile.storageLabel -eq 'UNIDAD') { [string]$ui.skin.storageFallback } else { [string]$profile.storageLabel }
$text = $text -replace '(?m)^Text=SSD$', ('Text={0}' -f $storageLabel)

function Set-MeterText([string]$Section,[string]$Value) {
    $script:text = [regex]::Replace($script:text, '(?ms)(^\[' + [regex]::Escape($Section) + '\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $Value }, 1)
}
function Set-MeterTooltip([string]$Section,[string]$Value) {
    $script:text = [regex]::Replace($script:text, '(?ms)(^\[' + [regex]::Escape($Section) + '\].*?^ToolTipText=)[^\r\n]*', { param($m) $m.Groups[1].Value + $Value }, 1)
}
Set-MeterText 'MeterUseGroup' ([string]$ui.skin.systemUse)
Set-MeterText 'MeterTempGroup3' ([string]$ui.skin.temperatures)
Set-MeterText 'MeterCoresTitle' ([string]$ui.skin.processorsLoad)
Set-MeterText 'FrameTimeStatus' ([string]$ui.skin.notAvailable)
Set-MeterText 'MeterRecordLabel' ([string]$ui.skin.recordEvent)
Set-MeterTooltip 'FrameTimeHelpCircle' ([string]$ui.skin.frameTimeHelp)
Set-MeterTooltip 'FrameTimeHelpText' ([string]$ui.skin.frameTimeHelp)
Set-MeterTooltip 'MeterRecordButton' ([string]$ui.skin.recordTooltip)
Set-MeterTooltip 'MeterOffButton' ([string]$ui.skin.offTooltip)
Set-MeterTooltip 'MeterOffLabel' ([string]$ui.skin.offTooltip)
$text = $text.Replace('Text "N/D"', ('Text "' + [string]$ui.skin.notAvailable + '"'))
$text = $text.Replace('Text "¡EXCELENTE!"', ('Text "' + [string]$ui.skin.excellent + '"'))
$text = $text.Replace('Text "FLUIDO"', ('Text "' + [string]$ui.skin.smooth + '"'))
$text = $text.Replace('Text "ATENCIÓN"', ('Text "' + [string]$ui.skin.attention + '"'))
$text = $text.Replace('Text "BAJA FLUIDEZ"', ('Text "' + [string]$ui.skin.lowFluidity + '"'))
if ($profile.appearance) {
    $colorMap = [ordered]@{ Bg='background'; PCore='performanceCore'; ECore='efficiencyCore'; Green='genericCore'; NvidiaGreen='nvidiaGreen' }
    foreach ($entry in $colorMap.GetEnumerator()) {
        $value = $profile.appearance.($entry.Value)
        if ($value) { $text = [regex]::Replace($text, '(?m)^' + $entry.Key + '=.*$', ($entry.Key + '=' + $value), 1) }
    }
}
$text = [regex]::Replace($text, '(?m)^BackgroundEffectEnabled=.*$', ('BackgroundEffectEnabled=' + $(if ($backgroundEnabled) { '1' } else { '0' })), 1)
$text = [regex]::Replace($text, '(?m)^BackgroundEffectMode=.*$', ('BackgroundEffectMode=' + $backgroundMode), 1)
$text = [regex]::Replace($text, '(?m)^BackgroundParticleCount=.*$', ('BackgroundParticleCount=' + $backgroundParticleCount), 1)
$text = [regex]::Replace($text, '(?m)^BackgroundParticleSpeed=.*$', ('BackgroundParticleSpeed=' + $backgroundSpeed.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)), 1)
$text = [regex]::Replace($text, '(?m)^BackgroundParticleSize=.*$', ('BackgroundParticleSize=' + $backgroundSizeScale.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)), 1)
$text = [regex]::Replace($text, '(?m)^BackgroundParticleColor=.*$', ('BackgroundParticleColor=' + $backgroundColor), 1)

$particleMeters = New-Object Text.StringBuilder
foreach ($particleIndex in 1..48) {
    [void]$particleMeters.AppendLine(@"
[Particle$particleIndex]
Meter=Image
ImageName=#@#ParticleGlow.png
X=-100
Y=-100
W=12
H=12
ImageTint=#BackgroundParticleColor#
ImageAlpha=0
PreserveAspectRatio=1
Group=AmbientParticles
DynamicVariables=1
"@)
}
$text = $text.Replace(';__PARTICLE_METERS__', $particleMeters.ToString().TrimEnd())

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
    "$physical $($ui.skin.physicalCores) / $logical $($ui.skin.threads)  |  $pPhysical $($ui.skin.performanceCores)  |  $ePhysical $($ui.skin.efficiencyCores)"
} else {
    "$physical $($ui.skin.physicalCores) / $logical $($ui.skin.threads)  |  $monitored $($ui.skin.logicalProcessors)"
}
$text = [regex]::Replace($text, '(?ms)(^\[MeterCoresLegend\].*?^Text=)[^\r\n]*', { param($m) $m.Groups[1].Value + $legend }, 1)

$coreSectionPattern = '(?ms)^\[(?:CORETEMP|COREUSE|Outline_CORE|BG_CORETEMP|Ring_CORETEMP|Value_CORETEMP|Label_CORETEMP|Use_CORETEMP)\d+\].*?(?=^\[|\z)'
$text = [regex]::Replace($text, $coreSectionPattern, '')

foreach ($measureName in @('GPU_TEMP','GPU_USE','CPU_TEMP','CPU_USE','SSD_TEMP','CORE_MAX','VRAM_USED_MB','VRAM_FREE_MB','FPS_GAME')) {
    $sectionPattern = '(?ms)(^\[' + $measureName + '\].*?)(?=^\[|\z)'
    $text = [regex]::Replace($text, $sectionPattern, {
        param($match)
        if ($match.Value -match '(?m)^Substitute=') { return $match.Value }
        return $match.Value.TrimEnd("`r","`n") + "`r`nSubstitute=`"-1`":`"$($ui.skin.notAvailable)`"`r`n`r`n"
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

# Mark optional visual modules before applying the common responsive transform.
$processorMeters = '^(?:Block_CORES|Tab_CORES|MeterCoresTitle|MeterCoresLegend|Outline_CORE\d+|Ring_CORETEMP\d+|Value_CORETEMP\d+|Label_CORETEMP\d+)$'
$performanceMeters = '^(?:GameStatusBackground|FPSLabel|FPSValue|FrameTimeLabel|FrameTimeValue|FrameTimeStatus|FrameTimeHelpCircle|FrameTimeHelpText|AlertCPUText|AlertGPUText|AlertPowerText|AlertCPUBackground|AlertGPUBackground|AlertPowerBackground|AlertCPUActive|AlertGPUActive|AlertPowerActive)$'
$clockMeters = '^(?:ClockDigit[1-6]|ClockColons)$'
$compactDx = -315
$compactDy = -101
$text = [regex]::Replace($text, '(?ms)^\[([^\]]+)\](.*?)(?=^\[|\z)', {
    param($match)
    $block = $match.Value
    $sectionName = $match.Groups[1].Value
    $moduleGroup = $null
    $moduleVisible = $true
    if ($sectionName -match $processorMeters) { $moduleGroup = 'ProcessorPanel'; $moduleVisible = $processorPanelVisible }
    elseif ($sectionName -match $performanceMeters) { $moduleGroup = 'PerformancePanel'; $moduleVisible = $performancePanelVisible }
    elseif ($sectionName -match $clockMeters) { $moduleGroup = 'ClockPanel'; $moduleVisible = $clockVisible }
    if($compactOverlay -and $sectionName -match $performanceMeters -and $block -match '(?m)^Meter='){
        if($sectionName -eq 'GameStatusBackground'){$block=$block.TrimEnd("`r","`n")+"`r`nX=$compactDx`r`nY=$compactDy`r`n"}
        else{
            $block=[regex]::Replace($block,'(?m)^X=(-?\d+(?:\.\d+)?)$',{param($m)'X='+([double]$m.Groups[1].Value+$compactDx)},1)
            $block=[regex]::Replace($block,'(?m)^Y=(-?\d+(?:\.\d+)?)$',{param($m)'Y='+([double]$m.Groups[1].Value+$compactDy)},1)
        }
    }
    if ($moduleGroup -and $block -match '(?m)^Meter=') {
        if ($block -match '(?m)^Group=') { $block = [regex]::Replace($block, '(?m)^Group=[^\r\n]*', { param($m) $m.Value + '|' + $moduleGroup }, 1) }
        else { $block = $block.TrimEnd("`r","`n") + "`r`nGroup=$moduleGroup`r`n" }
        if (-not $moduleVisible) {
            if ($block -match '(?m)^Hidden=') { $block = [regex]::Replace($block, '(?m)^Hidden=.*$', 'Hidden=1', 1) }
            else { $block = $block.TrimEnd("`r","`n") + "`r`nHidden=1`r`n" }
        }
        if($compactOverlay){
            if($block -match '(?m)^Group='){$block=[regex]::Replace($block,'(?m)^Group=[^\r\n]*',{param($m)$m.Value+'|CompactOnly'},1)}else{$block=$block.TrimEnd("`r","`n")+"`r`nGroup=CompactOnly`r`n"}
        }
        return $block.TrimEnd("`r","`n") + "`r`n`r`n"
    }
    if($compactOverlay -and $block -match '(?m)^Meter=' -and $sectionName -ne 'MeterBackground'){
        if($block -match '(?m)^Hidden='){$block=[regex]::Replace($block,'(?m)^Hidden=.*$','Hidden=1',1)}else{$block=$block.TrimEnd("`r","`n")+"`r`nHidden=1`r`n"}
    }
    if($compactOverlay -and $sectionName -eq 'MeterBackground'){
        if($block -match '(?m)^Hidden='){$block=[regex]::Replace($block,'(?m)^Hidden=.*$','Hidden=1',1)}else{$block=$block.TrimEnd("`r","`n")+"`r`nHidden=1`r`n"}
    }
    return $block
})

# Transform every visual meter as one responsive canvas. The full-screen black
# background remains fixed; content gets a shared group for safe OLED shifting.
$text = [regex]::Replace($text, '(?ms)^\[([^\]]+)\](.*?)(?=^\[|\z)', {
    param($match)
    $block = $match.Value
    $sectionName = $match.Groups[1].Value
    if ($block -match '(?m)^Meter=' -and $sectionName -ne 'MeterBackground') {
        if ($block -match '(?m)^Group=') { $block = [regex]::Replace($block, '(?m)^Group=[^\r\n]*', { param($m) $m.Value + '|OLEDShift' }, 1) }
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
$compactHitHidden = if($compactOverlay){'Hidden=1'}else{''}
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
ToolTipText=$($ui.skin.recordTooltip)
DynamicVariables=1
RightMouseUpAction=["C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "#EventRecorderPath#" -MarkIncident -BridgeUrl "#BridgeUrl#" -RainmeterConfig "AlienGamerMode"]
$compactHitHidden

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
ToolTipText=$($ui.skin.offTooltip)
DynamicVariables=1
$compactHitHidden
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
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skin\BackgroundAnimator.lua') -Destination (Join-Path $resources 'BackgroundAnimator.lua') -Force
$particleAssetCandidates = @(
    (Join-Path $InstallRoot 'assets\ParticleGlow.png'),
    (Join-Path $PSScriptRoot '..\assets\ParticleGlow.png')
)
$particleAsset = $particleAssetCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $particleAsset) { throw 'Falta el recurso gráfico ParticleGlow.png.' }
Copy-Item -LiteralPath $particleAsset -Destination (Join-Path $resources 'ParticleGlow.png') -Force
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
