param(
    [Parameter(Mandatory)][string]$DiscoveryPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$ProfilesDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$PrimaryProfilePath,
    [string]$InstallRoot=$PSScriptRoot
)

$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.MultiDisplay.psm1') -Force
function Set-ObjectProperty($Object,[string]$Name,$Value){
    if($Object.PSObject.Properties[$Name]){$Object.$Name=$Value}else{$Object|Add-Member NoteProperty $Name $Value}
}
$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
$discovery=Get-Content -LiteralPath $DiscoveryPath -Raw|ConvertFrom-Json
$views=@(Get-AGDisplayViews -Config $config|Where-Object enabled)
if(-not $views.Count){throw 'Debe existir al menos una pantalla habilitada.'}
New-Item -ItemType Directory -Path $ProfilesDirectory,$OutputDirectory -Force|Out-Null
$viewsOutput=Join-Path $OutputDirectory 'Views'
if(Test-Path -LiteralPath $viewsOutput){Remove-Item -LiteralPath $viewsOutput -Recurse -Force}
New-Item -ItemType Directory -Path $viewsOutput -Force|Out-Null
$manifest=New-Object 'System.Collections.Generic.List[object]'
$index=0
foreach($view in $views){
    $monitor=$null
    if($view.monitorId -and $view.monitorId -ne 'auto'){$monitor=@($discovery.monitors|Where-Object pnpDeviceId -eq $view.monitorId)[0]}
    if(-not $monitor -and $view.monitorDeviceName -and $view.monitorDeviceName -ne 'auto'){$monitor=@($discovery.monitors|Where-Object deviceName -eq $view.monitorDeviceName)[0]}
    if(-not $monitor){$monitor=if($index-eq 0){@($discovery.monitors|Where-Object primary)[0]}else{@($discovery.monitors|Select-Object -Skip $index -First 1)[0]}}
    if(-not $monitor){continue}

    $viewConfig=($config|ConvertTo-Json -Depth 20|ConvertFrom-Json)
    $viewConfig.display.targetMonitor=[string]$monitor.deviceName
    Set-ObjectProperty $viewConfig.display 'targetMonitorId' ([string]$monitor.pnpDeviceId)
    if(-not $viewConfig.PSObject.Properties['activeDisplayView']){$viewConfig|Add-Member NoteProperty activeDisplayView $view}else{$viewConfig.activeDisplayView=$view}
    if($view.background){
        $viewConfig.appearance.backgroundEffect.enabled=[bool]$view.background.enabled
        if([string]$view.background.mode -in @('manual','thermal')){
            Set-ObjectProperty $viewConfig.appearance.backgroundEffect 'mode' ([string]$view.background.mode)
        }
    }
    if($view.modules){
        Set-ObjectProperty $viewConfig.features 'processorPanelVisible' ([bool]$view.modules.processors.visible)
        Set-ObjectProperty $viewConfig.features 'performancePanelVisible' ([bool]$view.modules.performance.visible)
        Set-ObjectProperty $viewConfig.features 'clock' ([bool]$view.modules.clock.visible)
        $compactOverlay=if($config.features -and $config.features.PSObject.Properties['compactOverlay']){[bool]$config.features.compactOverlay}else{$false}
        Set-ObjectProperty $viewConfig.features 'compactOverlay' $compactOverlay
    }
    $safe=ConvertTo-AGSafeViewId ([string]$view.id)
    $tempConfig=Join-Path $ProfilesDirectory ("config-$safe.json")
    $profilePath=Join-Path $ProfilesDirectory ("profile-$safe.json")
    $skinOutput=Join-Path $OutputDirectory ("Views\$safe")
    $viewConfig|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $tempConfig -Encoding UTF8
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Resolve-AlienGamerProfile.ps1') -DiscoveryPath $DiscoveryPath -ConfigPath $tempConfig -OutputPath $profilePath -MonitorDeviceName ([string]$monitor.deviceName)|Out-Null
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Build-AdaptiveSkin.ps1') -ProfilePath $profilePath -TemplatePath (Join-Path $PSScriptRoot 'skin\AlienGamerMode.Template.ini') -OutputDirectory $skinOutput -InstallRoot $InstallRoot|Out-Null
    $configName="AlienGamerMode\Views\$safe"
    $manifest.Add([pscustomobject]@{id=$safe;name=[string]$view.name;configName=$configName;ini='AlienGamerMode.ini';profilePath=$profilePath;monitor=$monitor})
    if($index-eq 0){Copy-Item -LiteralPath $profilePath -Destination $PrimaryProfilePath -Force}
    $index++
}
if(-not $manifest.Count){throw 'Ninguna pantalla configurada está conectada.'}
$manifestPath=Join-Path (Split-Path -Parent $PrimaryProfilePath) 'display-manifest.json'
$manifest.ToArray()|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath -Encoding UTF8
$manifest.ToArray()
