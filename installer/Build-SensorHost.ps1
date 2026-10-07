$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'No se encontro el compilador .NET Framework de Windows.' }
$source = Join-Path $packageRoot 'src\native\AlienGamerSensorHost.cs'
$output = Join-Path $packageRoot 'assets\AlienGamerSensorHost.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ "/out:$output" $source
if ($LASTEXITCODE -ne 0) { throw "No se pudo compilar el lanzador de sensores ($LASTEXITCODE)." }
Write-Output $output
