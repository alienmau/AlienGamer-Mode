param([ValidateRange(2,12)][int]$MonitorCount=2)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.MultiDisplay.psm1') -Force
$output=Join-Path $root 'build\tests\enfoque'
New-Item -ItemType Directory -Path $output -Force|Out-Null
$config=Get-Content -LiteralPath (Join-Path $root 'config\AlienGamerMode.default.json') -Raw -Encoding UTF8|ConvertFrom-Json
$view=New-AGDisplayView -Id 'laptop-test' -Name 'Lenovo DisplayHDR' -MonitorId 'MONITOR\TEST-LAPTOP' -MonitorDeviceName '\\.\DISPLAY2' -Preset 'full-horizontal' -Enabled $true
Set-AGLayoutPreset -View $view -Preset 'full-horizontal' -CanvasWidth 2048 -CanvasHeight 1280|Out-Null
$config.displayViews=@($view)
$config.display.targetMonitorId='MONITOR\TEST-LAPTOP'
$monitors=@(
    [pscustomobject]@{deviceName='\\.\DISPLAY2';pnpDeviceId='MONITOR\TEST-LAPTOP';friendlyName='Lenovo DisplayHDR';width=2048;height=1280;x=0;y=0;primary=$true},
    [pscustomobject]@{deviceName='\\.\DISPLAY1';pnpDeviceId='MONITOR\TEST-ASUS';friendlyName='ASUS VG27AQ3A';width=2560;height=1440;x=2048;y=0;primary=$false}
)
for($i=2;$i-lt$MonitorCount;$i++){
    $monitors+=,[pscustomobject]@{deviceName=('\\.\DISPLAY'+($i+1));pnpDeviceId=('MONITOR\TEST-'+$i);friendlyName=('Monitor adicional '+($i+1));width=1920;height=1080;x=($i*2560);y=0;primary=$false}
}
$configPath=Join-Path $output 'config.json';$discoveryPath=Join-Path $output 'discovery.json'
$config|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $configPath -Encoding UTF8
@{monitors=$monitors}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $discoveryPath -Encoding UTF8
$capture=if($MonitorCount-eq2){'enfoque-orange.png'}else{'enfoque-'+$MonitorCount+'-monitors.png'}
& (Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1') -ConfigPath $configPath -DiscoveryPath $discoveryPath -UiTest -ExportScreenshotPath (Join-Path $output $capture)
if($LASTEXITCODE-ne0){throw 'Enfoque UI test failed.'}
