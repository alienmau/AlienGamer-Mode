Set-StrictMode -Version 2.0

function Get-AGPropertyValue {
    param($Object,[string]$Name,$Default=$null)
    if($null -eq $Object){return $Default}
    $property=$Object.PSObject.Properties[$Name]
    if($property){return $property.Value}
    return $Default
}

function Get-AGModuleDefinitions {
    [ordered]@{
        header       = [ordered]@{ x=35;   y=20;  width=500;  height=90;  minScale=1.0; maxScale=1.0; fixed=$true }
        clock        = [ordered]@{ x=760;  y=25;  width=470;  height=100; minScale=0.55;maxScale=2.2; fixed=$false }
        controls     = [ordered]@{ x=1435; y=25;  width=205;  height=110; minScale=0.75;maxScale=2.0; fixed=$false }
        ram          = [ordered]@{ x=35;   y=150; width=410;  height=415; minScale=0.45;maxScale=2.5; fixed=$false }
        vram         = [ordered]@{ x=455;  y=150; width=410;  height=415; minScale=0.45;maxScale=2.5; fixed=$false }
        system       = [ordered]@{ x=875;  y=150; width=280;  height=415; minScale=0.55;maxScale=2.2; fixed=$false }
        temperatures = [ordered]@{ x=1165; y=150; width=500;  height=415; minScale=0.45;maxScale=2.5; fixed=$false }
        performance  = [ordered]@{ x=720;  y=575; width=900;  height=75;  minScale=0.50;maxScale=2.0; fixed=$false }
        processors   = [ordered]@{ x=35;   y=610; width=1630; height=370; minScale=0.35;maxScale=1.5; fixed=$false }
    }
}

function New-AGDisplayView {
    param(
        [string]$Id = 'principal',
        [string]$Name = 'AlienGamer Mode',
        [string]$MonitorId = 'auto',
        [string]$MonitorDeviceName = 'auto',
        [string]$Preset = 'full-horizontal',
        [bool]$Enabled = $true
    )
    $view = [ordered]@{
        id=$Id; name=$Name; enabled=$Enabled; monitorId=$MonitorId
        monitorDeviceName=$MonitorDeviceName; layoutPreset=$Preset
        background=[pscustomobject][ordered]@{enabled=$true;mode='manual';particleCount=26;speed=0.65;sizeScale=1.0;color='255,112,20'}
        modules=[pscustomobject][ordered]@{}; canvas=[pscustomobject][ordered]@{width=1711;height=1023}
    }
    Set-AGLayoutPreset -View $view -Preset $Preset | Out-Null
    [pscustomobject]$view
}

function Set-AGLayoutPreset {
    param(
        [Parameter(Mandatory)]$View,
        [Parameter(Mandatory)][string]$Preset,
        [int]$CanvasWidth=0,
        [int]$CanvasHeight=0
    )
    $definitions = Get-AGModuleDefinitions
    if($CanvasWidth -le 0){$CanvasWidth=[Math]::Max(500,[int](Get-AGPropertyValue (Get-AGPropertyValue $View 'canvas') 'width' 1711))}
    if($CanvasHeight -le 0){$CanvasHeight=[Math]::Max(320,[int](Get-AGPropertyValue (Get-AGPropertyValue $View 'canvas') 'height' 1023))}
    $baseScale=[Math]::Min($CanvasWidth/1711.0,$CanvasHeight/1023.0)
    $baseOffsetX=[Math]::Max(0,($CanvasWidth-(1711*$baseScale))/2)
    $baseOffsetY=[Math]::Max(0,($CanvasHeight-(1023*$baseScale))/2)
    $modules = [ordered]@{}
    foreach ($entry in $definitions.GetEnumerator()) {
        $modules[$entry.Key] = [pscustomobject][ordered]@{
            visible=$true
            x=[int][Math]::Round($baseOffsetX+[double]$entry.Value.x*$baseScale)
            y=[int][Math]::Round($baseOffsetY+[double]$entry.Value.y*$baseScale)
            width=[int][Math]::Round([double]$entry.Value.width*$baseScale)
            height=[int][Math]::Round([double]$entry.Value.height*$baseScale)
        }
    }
    # El encabezado identifica la vista y no puede ocultarse ni arrastrarse.
    $modules.header.visible=$true
    $modules.header.x=[int][Math]::Round(35*$baseScale)
    $modules.header.y=[int][Math]::Round(20*$baseScale)
    # Calcula el panel inferior a partir del borde real del panel de rendimiento.
    # Así el diseño generado nunca se invalida a sí mismo en relaciones 16:10.
    $safeMargin=[Math]::Max(8,[int][Math]::Round(10*$baseScale))
    $processorY=[int]($modules.performance.y+$modules.performance.height+$safeMargin)
    $processorScale=[Math]::Min($baseScale*0.92,($CanvasHeight-$processorY-$safeMargin)/[double]$definitions.processors.height)
    $processorScale=[Math]::Max(0.35,$processorScale)
    $modules.processors.width=[int][Math]::Round([double]$definitions.processors.width*$processorScale)
    $modules.processors.height=[int][Math]::Round([double]$definitions.processors.height*$processorScale)
    $modules.processors.x=[int][Math]::Round(($CanvasWidth-$modules.processors.width)/2)
    $modules.processors.y=$processorY
    switch ($Preset) {
        'essential-horizontal' {
            foreach($name in @('clock','controls','processors','performance')){$modules[$name].visible=$false}
        }
        'essential-vertical' {
            foreach($name in @('clock','controls','processors','performance')){$modules[$name].visible=$false}
            $modules.header.x=[int][Math]::Round(($CanvasWidth-$modules.header.width)/2)
            $availableTop=[int]($modules.header.y+$modules.header.height+[Math]::Max(12,[int][Math]::Round(18*$baseScale)))
            $gap=[Math]::Max(10,[int][Math]::Round(18*$baseScale))
            $columnWidth=[Math]::Max(180,$CanvasWidth-2*$gap)
            $verticalScale=[Math]::Min($columnWidth/500.0,($CanvasHeight-$availableTop-3*$gap-$safeMargin)/1660.0)
            $verticalScale=[Math]::Max(0.35,$verticalScale)
            $y=$availableTop
            foreach($name in @('ram','vram','system','temperatures')){
                $definition=$definitions[$name]
                $modules[$name].width=[int][Math]::Round($definition.width*$verticalScale)
                $modules[$name].height=[int][Math]::Round($definition.height*$verticalScale)
                $modules[$name].x=[int][Math]::Round(($CanvasWidth-$modules[$name].width)/2)
                $modules[$name].y=$y
                $y+=$modules[$name].height+$gap
            }
        }
        'performance-only' {
            foreach($name in @($modules.Keys)){ $modules[$name].visible=($name -in @('header','performance')) }
            $modules.performance.x=[int][Math]::Round(($CanvasWidth-$modules.performance.width)/2)
            $modules.performance.y=[int][Math]::Round(($CanvasHeight-$modules.performance.height)/2)
        }
        'temperatures-only' {
            foreach($name in @($modules.Keys)){ $modules[$name].visible=($name -in @('header','temperatures')) }
            $modules.temperatures.x=[int][Math]::Round(($CanvasWidth-$modules.temperatures.width)/2)
            $modules.temperatures.y=[int][Math]::Round(($CanvasHeight-$modules.temperatures.height)/2)
        }
        default {
            $Preset='full-horizontal'
        }
    }
    $View.canvas=[pscustomobject][ordered]@{width=$CanvasWidth;height=$CanvasHeight}
    $View.layoutPreset=$Preset
    $View.modules=[pscustomobject]$modules
    $View
}

function ConvertTo-AGSafeViewId([string]$Value) {
    $safe = ($Value -replace '[^A-Za-z0-9_-]','-').Trim('-')
    if (-not $safe) { $safe='display' }
    $safe.ToLowerInvariant()
}

function Get-AGDisplayViews {
    param([Parameter(Mandatory)]$Config)
    $views = @()
    if ($Config.PSObject.Properties['displayViews']) { $views=@($Config.displayViews) }
    if (-not $views.Count) {
        $legacyMonitorId=[string](Get-AGPropertyValue $Config.display 'targetMonitorId' 'auto')
        $legacyMonitorDevice=[string](Get-AGPropertyValue $Config.display 'targetMonitor' 'auto')
        $legacyId = if($legacyMonitorId -and $legacyMonitorId -ne 'auto'){
            ConvertTo-AGSafeViewId $legacyMonitorId
        } else {'principal'}
        $views = @(New-AGDisplayView -Id $legacyId -Name 'AlienGamer Mode' -MonitorId $legacyMonitorId -MonitorDeviceName $legacyMonitorDevice)
    }
    $seen=@{}
    $normalized=foreach($raw in $views){
        $id=ConvertTo-AGSafeViewId ([string](Get-AGPropertyValue $raw 'id' 'display'))
        if($seen.ContainsKey($id)){continue};$seen[$id]=$true
        $rawPreset=[string](Get-AGPropertyValue $raw 'layoutPreset' 'full-horizontal')
        $initialPreset=if($rawPreset-in@('full-horizontal','essential-horizontal','essential-vertical','performance-only','temperatures-only')){$rawPreset}else{'full-horizontal'}
        $view=New-AGDisplayView -Id $id -Name ([string](Get-AGPropertyValue $raw 'name' $id)) -MonitorId ([string](Get-AGPropertyValue $raw 'monitorId' 'auto')) -MonitorDeviceName ([string](Get-AGPropertyValue $raw 'monitorDeviceName' 'auto')) -Preset $initialPreset -Enabled ([bool](Get-AGPropertyValue $raw 'enabled' $true))
        $rawBackground=Get-AGPropertyValue $raw 'background'
        if($rawBackground){
            $view.background.enabled=[bool](Get-AGPropertyValue $rawBackground 'enabled' $true)
            $rawMode=[string](Get-AGPropertyValue $rawBackground 'mode' 'manual')
            $view.background.mode=if($rawMode -in @('manual','thermal')){$rawMode}else{'manual'}
            $globalBackground=Get-AGPropertyValue (Get-AGPropertyValue $Config 'appearance') 'backgroundEffect'
            $view.background.particleCount=[Math]::Max(8,[Math]::Min(48,[int](Get-AGPropertyValue $rawBackground 'particleCount' (Get-AGPropertyValue $globalBackground 'particleCount' 26))))
            $view.background.speed=[Math]::Max(0.2,[Math]::Min(1.5,[double](Get-AGPropertyValue $rawBackground 'speed' (Get-AGPropertyValue $globalBackground 'speed' 0.65))))
            $view.background.sizeScale=[Math]::Max(0.7,[Math]::Min(1.6,[double](Get-AGPropertyValue $rawBackground 'sizeScale' (Get-AGPropertyValue $globalBackground 'sizeScale' 1.0))))
            $view.background.color=[string](Get-AGPropertyValue $rawBackground 'color' (Get-AGPropertyValue $globalBackground 'color' '255,112,20'))
        }
        $rawCanvas=Get-AGPropertyValue $raw 'canvas'
        if($rawCanvas){
            $view.canvas.width=[Math]::Max(200,[int](Get-AGPropertyValue $rawCanvas 'width' 1711))
            $view.canvas.height=[Math]::Max(75,[int](Get-AGPropertyValue $rawCanvas 'height' 1023))
        }
        $rawModules=Get-AGPropertyValue $raw 'modules'
        if($rawModules){
            foreach($name in @(Get-AGModuleDefinitions).Keys){
                $module=Get-AGPropertyValue $rawModules $name
                if($module){
                    $view.modules.$name.visible=[bool](Get-AGPropertyValue $module 'visible' $true)
                    $view.modules.$name.x=[int](Get-AGPropertyValue $module 'x' $view.modules.$name.x)
                    $view.modules.$name.y=[int](Get-AGPropertyValue $module 'y' $view.modules.$name.y)
                    $definition=(Get-AGModuleDefinitions)[$name]
                    $view.modules.$name.width=[Math]::Max(24,[int](Get-AGPropertyValue $module 'width' $definition.width))
                    $view.modules.$name.height=[Math]::Max(18,[int](Get-AGPropertyValue $module 'height' $definition.height))
                }
            }
        }
        $view.layoutPreset=if($rawPreset-in@('full-horizontal','essential-horizontal','essential-vertical','performance-only','temperatures-only','custom')){$rawPreset}else{'full-horizontal'}
        $view.modules.header.visible=$true
        $view
    }
    @($normalized)
}

Export-ModuleMember -Function Get-AGModuleDefinitions,New-AGDisplayView,Set-AGLayoutPreset,ConvertTo-AGSafeViewId,Get-AGDisplayViews
