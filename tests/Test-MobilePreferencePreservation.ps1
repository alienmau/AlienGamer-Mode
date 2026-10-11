$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Editor parse errors.'}
foreach($name in @('Set-Property','Save-Configuration')){
    $node=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    Invoke-Expression $node.Extent.Text
}
function Write-EditorTrace($Message){}
function Get-Module($View,$Name){return $null}
function Get-GeometryIssue($View){return ''}
$directory=Join-Path $root ('build\tests\mobile-preserve-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory -Force|Out-Null
$ConfigPath=Join-Path $directory 'config.json'
$views=New-Object 'System.Collections.Generic.List[object]'
$views.Add([pscustomobject]@{id='principal';enabled=$true})
$allModuleNames=@()
foreach($enabled in @($true,$false)){
    $config=[pscustomobject]@{schemaVersion=3;displayViews=@();mobileView=[pscustomobject]@{token='old';enabled=$true}}
    $disk=[pscustomobject]@{mobileView=[pscustomobject]@{token='new';enabled=$enabled;modules=@('timer');tls=[pscustomobject]@{prepared=$true;enabled=$true}}}
    [IO.File]::WriteAllText($ConfigPath,($disk|ConvertTo-Json -Depth 8))
    Save-Configuration
    $actual=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
    if($actual.mobileView.token -ne 'new' -or $actual.mobileView.enabled -ne $enabled -or -not $actual.mobileView.tls.enabled -or $actual.displayViews[0].id -ne 'principal'){throw 'Mobile preferences were overwritten.'}
}
$installer=[IO.File]::ReadAllText((Join-Path $root 'installer\Install-AlienGamerMode.ps1'))
$capture=[regex]::Match($installer,'(?s)        \$previousMobile=\$null.*?(?=        \$legacyBackup =)')
$restore=[regex]::Match($installer,'(?m)^        if\(\$previousMobile\).*')
if(-not $capture.Success -or -not $restore.Success){throw 'Installer preservation steps missing.'}
$dataRoot=$directory
Copy-Item -LiteralPath $ConfigPath -Destination (Join-Path $directory 'AlienGamerMode.json')
Invoke-Expression $capture.Value
$config=[pscustomobject]@{mobileView=[pscustomobject]@{enabled=$false}}
Invoke-Expression $restore.Value
if($config.mobileView.token -ne 'new' -or -not $config.mobileView.tls.enabled){throw 'Installer lost mobile access.'}
'PASS: stale editor snapshots, disabled consent, TLS/token preservation and installer upgrade.'
