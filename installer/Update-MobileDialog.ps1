param([string]$ResultPath)
$ErrorActionPreference='Stop'
try{
    $root=Split-Path -Parent $PSScriptRoot
    $installed=Join-Path $env:ProgramData 'AlienGamerMode\App\Show-AlienGamerLayoutEditor.ps1'
    if(-not(Test-Path -LiteralPath $installed)){throw 'AlienGamer Mode no esta instalado.'}
    Copy-Item -LiteralPath (Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1') -Destination $installed -Force
    @{updated=$true;path=$installed}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}catch{
    @{updated=$false;error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
    exit 1
}
