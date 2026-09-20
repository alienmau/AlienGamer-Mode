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
        header       = [ordered]@{ x=35;   y=20;  width=500;  height=90 }
        clock        = [ordered]@{ x=760;  y=25;  width=470;  height=100 }
        controls     = [ordered]@{ x=1435; y=25;  width=205;  height=110 }
        ram          = [ordered]@{ x=35;   y=150; width=410;  height=415 }
        vram         = [ordered]@{ x=455;  y=150; width=410;  height=415 }
        system       = [ordered]@{ x=875;  y=150; width=280;  height=415 }
        temperatures = [ordered]@{ x=1165; y=150; width=500;  height=415 }
        performance  = [ordered]@{ x=720;  y=575; width=900;  height=75 }
        processors   = [ordered]@{ x=35;   y=610; width=1630; height=370 }
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
        background=[ordered]@{enabled=$true;mode='manual'}
        modules=[ordered]@{}; canvas=[ordered]@{width=1711;height=1023}
    }
    Set-AGLayoutPreset -View $view -Preset $Preset | Out-Null
    [pscustomobject]$view
}

function Set-AGLayoutPreset {
    param([Parameter(Mandatory)]$View,[Parameter(Mandatory)][string]$Preset)
    $definitions = Get-AGModuleDefinitions
    $modules = [ordered]@{}
    foreach ($entry in $definitions.GetEnumerator()) {
        $modules[$entry.Key] = [ordered]@{visible=$true;x=[int]$entry.Value.x;y=[int]$entry.Value.y}
    }
    switch ($Preset) {
        'essential-horizontal' {
            $modules.processors.visible=$false; $modules.performance.visible=$false
            $View.canvas=[ordered]@{width=1711;height=590}
        }
        'essential-vertical' {
            foreach($name in @('header','clock','controls','processors','performance')){$modules[$name].visible=$false}
            $modules.ram.x=45; $modules.ram.y=25
            $modules.vram.x=45; $modules.vram.y=455
            $modules.system.x=110; $modules.system.y=885
            $modules.temperatures.x=0; $modules.temperatures.y=1315
            $View.canvas=[ordered]@{width=500;height=1755}
        }
        'performance-only' {
            foreach($name in @($modules.Keys)){ $modules[$name].visible=($name -eq 'performance') }
            $modules.performance.x=0; $modules.performance.y=0
            $View.canvas=[ordered]@{width=900;height=75}
        }
        'temperatures-only' {
            foreach($name in @($modules.Keys)){ $modules[$name].visible=($name -eq 'temperatures') }
            $modules.temperatures.x=0; $modules.temperatures.y=0
            $View.canvas=[ordered]@{width=500;height=415}
        }
        default {
            $Preset='full-horizontal'; $View.canvas=[ordered]@{width=1711;height=1023}
        }
    }
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
        $view=New-AGDisplayView -Id $id -Name ([string](Get-AGPropertyValue $raw 'name' $id)) -MonitorId ([string](Get-AGPropertyValue $raw 'monitorId' 'auto')) -MonitorDeviceName ([string](Get-AGPropertyValue $raw 'monitorDeviceName' 'auto')) -Preset ([string](Get-AGPropertyValue $raw 'layoutPreset' 'full-horizontal')) -Enabled ([bool](Get-AGPropertyValue $raw 'enabled' $true))
        $rawBackground=Get-AGPropertyValue $raw 'background'
        if($rawBackground){
            $view.background.enabled=[bool](Get-AGPropertyValue $rawBackground 'enabled' $true)
            $rawMode=[string](Get-AGPropertyValue $rawBackground 'mode' 'manual')
            $view.background.mode=if($rawMode -in @('manual','thermal')){$rawMode}else{'manual'}
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
                }
            }
        }
        $view
    }
    @($normalized)
}

Export-ModuleMember -Function Get-AGModuleDefinitions,New-AGDisplayView,Set-AGLayoutPreset,ConvertTo-AGSafeViewId,Get-AGDisplayViews
