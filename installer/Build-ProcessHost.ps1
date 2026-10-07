$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output=Join-Path $root 'assets\AlienGamerProcessHost.exe'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ "/out:$output" (Join-Path $root 'src\native\AlienGamerProcessHost.cs')
if($LASTEXITCODE-ne0){throw 'Could not build the console-free process launcher.'}
Write-Output $output
