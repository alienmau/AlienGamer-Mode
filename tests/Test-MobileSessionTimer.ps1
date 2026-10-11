$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src/AlienGamerBridge.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw $errors[0]}
$definition=$ast.Find({param($node)$node-is[Management.Automation.Language.FunctionDefinitionAst]-and$node.Name-eq'Get-MobileSessionTimer'},$true)
Invoke-Expression $definition.Extent.Text
$directory=Join-Path $root ('build/tests/mobile-timer-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory|Out-Null
$views=@(@{id='laptop';enabled=$true},@{id='asus';enabled=$true},@{id='old';enabled=$false})
function Write-Fixture($Id,$Status,$Remaining,$Deadline){
    [IO.File]::WriteAllText((Join-Path $directory "session-timer-AlienGamerMode-Views-$Id.txt"),"configured=1`nstatus=$Status`nremaining=$Remaining`ndeadline=$Deadline`n")
}
Write-Fixture laptop idle 300 0
Write-Fixture asus running 120 1120
Write-Fixture old running 999 1999
$result=Get-MobileSessionTimer $directory $views 1000
if($result.viewId-ne'asus'-or$result.remaining-ne120-or$result.status-ne'running'){throw 'Running timer on second display was not selected.'}
$result=Get-MobileSessionTimer $directory $views 1001
if($result.remaining-ne119){throw 'Countdown did not advance without a state-file rewrite.'}
Write-Fixture asus paused 87 0
if((Get-MobileSessionTimer $directory $views 1000).remaining-ne87){throw 'Paused timer was lost.'}
Write-Fixture asus running 1 999
if((Get-MobileSessionTimer $directory $views 1000).status-ne'finished'){throw 'Expired deadline did not report GAME OVER.'}
[IO.File]::WriteAllText((Join-Path $directory 'session-timer-AlienGamerMode-Views-asus.txt'),'configured=1')
if((Get-MobileSessionTimer $directory $views 1000).viewId-ne'laptop'){throw 'Partial file broke fallback.'}
if((Get-MobileSessionTimer $directory @() 1000).configured){throw 'Inactive timer leaked.'}
'OK: actual skin filename, second display, countdown, pause, completion, partial file and inactive views.'
