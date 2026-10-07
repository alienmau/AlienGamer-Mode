$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.Process.psm1') -Force
& (Join-Path $root 'installer\Build-ProcessHost.ps1')
$output=Join-Path $root ('build\tests\hidden-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output -Force|Out-Null
$shell='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$probe=Join-Path $PSScriptRoot 'ConsoleProbe.ps1'
$result=Join-Path $output 'direct.json';$errorLog=Join-Path $output 'stderr.txt'
$arguments="-NoProfile -File `"$probe`" -OutputPath `"$result`" -Fail"
$process=Start-AGHiddenProcess $shell -ArgumentList $arguments -RedirectStandardError $errorLog -PassThru
if(-not$process.WaitForExit(15000)){throw 'Hidden child timed out.'}
$process.WaitForExit()
if($process.ExitCode-ne7){throw 'Child exit code was not preserved.'};$process.Dispose()
if((Get-Content -LiteralPath $result -Raw|ConvertFrom-Json).consoleHandle-ne0){throw 'A console was allocated.'}
if((Get-Content -LiteralPath $errorLog -Raw)-notmatch'EXPECTED probe error'){throw 'Error diagnostics lost.'}
$guiResult=Join-Path $output 'gui.json'
$process=Start-AGHiddenProcess $shell -ArgumentList "-NoProfile -STA -WindowStyle Hidden -File `"$probe`" -OutputPath `"$guiResult`" -Gui" -PassThru
if(-not$process.WaitForExit(15000)){throw 'GUI probe timed out.'};$process.Dispose()
$gui=Get-Content -LiteralPath $guiResult -Raw|ConvertFrom-Json
if($gui.consoleHandle-ne0-or-not$gui.guiVisible){throw 'Console-free launch hid a graphical dialog.'}
$result=Join-Path $output 'bootstrap.json'
$arguments=[AlienGamer.Runtime.ProcessHost]::Quote($shell)+' -NoProfile -File '+[AlienGamer.Runtime.ProcessHost]::Quote($probe)+' -OutputPath '+[AlienGamer.Runtime.ProcessHost]::Quote($result)
$hostProcess=Start-AGHiddenProcess (Join-Path $root 'assets\AlienGamerProcessHost.exe') -ArgumentList $arguments -PassThru
if(-not$hostProcess.WaitForExit(15000)){throw 'Bootstrap timed out.'}
if($hostProcess.ExitCode-ne0){throw 'Bootstrap failed.'};$hostProcess.Dispose()
$deadline=[DateTime]::UtcNow.AddSeconds(15)
while(-not(Test-Path -LiteralPath $result)-and[DateTime]::UtcNow-lt$deadline){Start-Sleep -Milliseconds 100}
if(-not(Test-Path -LiteralPath $result)){throw 'Bootstrap child did not run.'}
if((Get-Content -LiteralPath $result -Raw|ConvertFrom-Json).consoleHandle-ne0){throw 'Bootstrap allocated a console.'}
$stage=Join-Path $output 'launcher with spaces';New-Item -ItemType Directory -Path (Join-Path $stage 'assets') -Force|Out-Null
Copy-Item -LiteralPath (Join-Path $root 'src\AlienGamerModeLauncher.vbs') -Destination $stage
Copy-Item -LiteralPath (Join-Path $root 'assets\AlienGamerProcessHost.exe') -Destination (Join-Path $stage 'assets')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LauncherProbe.ps1') -Destination (Join-Path $stage 'AlienGamerModeAgent.ps1')
$launcher=Join-Path $stage 'AlienGamerModeLauncher.vbs'
$hostProcess=Start-AGHiddenProcess 'C:\Windows\System32\wscript.exe' -ArgumentList "//B //NoLogo `"$launcher`" agent-activate" -PassThru
if(-not$hostProcess.WaitForExit(15000)){throw 'VBS launcher timed out.'};$hostProcess.Dispose()
$result=Join-Path $stage 'console.json';$deadline=[DateTime]::UtcNow.AddSeconds(15)
while(-not(Test-Path -LiteralPath $result)-and[DateTime]::UtcNow-lt$deadline){Start-Sleep -Milliseconds 100}
if(-not(Test-Path -LiteralPath $result)){throw 'VBS launcher did not execute child.'}
if((Get-Content -LiteralPath $result -Raw|ConvertFrom-Json).consoleHandle-ne0){throw 'VBS launch allocated a console.'}
Write-Output 'OK: GUI bootstrap and child processes allocate no console; exit codes and stderr preserved.'
