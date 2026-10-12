$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$directory=Join-Path $root ('build\tests\mobile-only-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory|Out-Null
function Load-Function([string]$File,[string]$Name){
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($File,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw "Parse errors: $File"}
    $node=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name},$true)
    if(-not $node){throw "Missing function: $Name"}
    return $node.Extent.Text
}
$editor=Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1'
foreach($name in @('Set-Property','Test-MobileOutputEnabled','Update-SaveAvailability','Save-Configuration')){Invoke-Expression (Load-Function $editor $name)}
function Write-EditorTrace($Message){}
function T($Name){return $Name}
function Get-Module($View,$Name){return $null}
function Get-GeometryIssue($View){return ''}
function Set-Status($Text,$Dirty){$script:status.Text=$Text}
$save=[pscustomobject]@{Enabled=$false}
$status=[pscustomobject]@{Text='enableOne'}
$views=New-Object 'System.Collections.Generic.List[object]'
$views.Add([pscustomobject]@{id='laptop';enabled=$false})
$allModuleNames=@()
$ConfigPath=Join-Path $directory 'config.json'
$config=Get-Content -LiteralPath (Join-Path $root 'config\AlienGamerMode.default.json') -Raw|ConvertFrom-Json
Set-Property $config 'displayViews' @($views.ToArray())
Set-Property $config 'mobileView' ([pscustomobject]@{enabled=$true;token='retained';tls=[pscustomobject]@{enabled=$true}})
$config|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $ConfigPath -Encoding UTF8
# A stale editor snapshot must still accept the current saved mobile setting.
$config.mobileView.enabled=$false
Update-SaveAvailability
if(-not $save.Enabled){throw 'Mobile-only save was disabled.'}
Save-Configuration
$saved=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
if($saved.displayViews[0].enabled -or -not $saved.mobileView.enabled -or $saved.mobileView.token -ne 'retained'){throw 'Save changed desktop/mobile state.'}
$DiscoveryPath=Join-Path $directory 'discovery.json'
@{monitors=@(@{deviceName='\\.\DISPLAY_TEST';primary=$true;width=1920;height=1080});gpus=@();storage=@();cpu=@{logicalProcessors=0;topology=@()};hwinfoInventory=@()}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $DiscoveryPath -Encoding UTF8
$profilePath=Join-Path $directory 'profile.json'
$buildArguments=@{DiscoveryPath=$DiscoveryPath;ConfigPath=$ConfigPath;ProfilesDirectory=(Join-Path $directory 'profiles');OutputDirectory=(Join-Path $directory 'skins');PrimaryProfilePath=$profilePath}
& (Join-Path $root 'src\Build-MultiDisplaySkins.ps1') @buildArguments|Out-Null
$profile=Get-Content -LiteralPath $profilePath -Raw|ConvertFrom-Json
if(-not $profile.validation){throw 'Mobile-only startup did not create sensor validation.'}
$displayManifestPath=Join-Path $directory 'display-manifest.json'
if((Get-Content -LiteralPath $displayManifestPath -Raw).Trim() -ne '[]'){throw 'Mobile-only manifest was not empty.'}
if(Test-Path -LiteralPath (Join-Path $directory 'skins\Views')){throw 'Mobile-only startup generated desktop skins.'}
$hash=(Get-FileHash -LiteralPath $profilePath).Hash
& (Join-Path $root 'src\Build-MultiDisplaySkins.ps1') @buildArguments -ReuseValidatedProfile|Out-Null
if((Get-FileHash -LiteralPath $profilePath).Hash -ne $hash){throw 'Applying mobile-only layout changed validated sensors.'}
$agent=Join-Path $root 'src\AlienGamerModeAgent.ps1'
foreach($name in @('Get-DisplayManifest','Get-ActiveRainmeterConfigs','Activate-DisplaySkins')){Invoke-Expression (Load-Function $agent $name)}
$rainmeter=Join-Path $directory 'must-not-launch.exe'
if(@(Get-ActiveRainmeterConfigs).Count){throw 'Empty manifest activated a legacy desktop skin.'}
Activate-DisplaySkins # Must not invoke the nonexistent Rainmeter executable.
# Both outputs disabled must still fail, rather than creating an invisible service.
$saved.mobileView.enabled=$false
$saved|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $ConfigPath -Encoding UTF8
Update-SaveAvailability
if($save.Enabled){throw 'Save accepted no outputs.'}
$rejected=$false;try{Save-Configuration}catch{$rejected=$true}
if(-not $rejected){throw 'Save did not reject no outputs.'}
$rejected=$false;try{& (Join-Path $root 'src\Build-MultiDisplaySkins.ps1') @buildArguments|Out-Null}catch{$rejected=$true}
if(-not $rejected){throw 'Startup did not reject no outputs.'}
$views[0].enabled=$true
Update-SaveAvailability
if(-not $save.Enabled){throw 'Desktop-only layout regressed.'}
'PASS: mobile-only save/start/profile reuse, no desktop activation, no-output rejection and desktop-only validation.'
