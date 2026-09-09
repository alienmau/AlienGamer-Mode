$ErrorActionPreference = 'Stop'
$iss = Join-Path $PSScriptRoot 'AlienGamerMode.iss'
$candidates = @(
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
)
$compiler = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $compiler) {
    throw 'No se encontró Inno Setup 6. Instálalo y vuelve a ejecutar este archivo.'
}
& $compiler $iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup terminó con código $LASTEXITCODE." }
