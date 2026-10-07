param([string]$ResultPath)
$ErrorActionPreference='Stop'
try{
    $root=Split-Path -Parent $PSScriptRoot
    $installed=Join-Path $env:ProgramData 'AlienGamerMode\App\mobile\index.html'
    if(-not(Test-Path -LiteralPath $installed)){throw 'La pantalla movil no esta instalada.'}
    Copy-Item -LiteralPath (Join-Path $root 'src\mobile\index.html') -Destination $installed -Force
    $editor=Join-Path $env:ProgramData 'AlienGamerMode\App\Show-AlienGamerLayoutEditor.ps1'
    if(Test-Path -LiteralPath $editor){Copy-Item -LiteralPath (Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1') -Destination $editor -Force}
    @{updated=$true;path=$installed}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}catch{
    @{updated=$false;error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
    exit 1
}
