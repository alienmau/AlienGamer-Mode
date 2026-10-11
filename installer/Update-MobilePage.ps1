param([Parameter(Mandatory)][string]$ResultPath)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Join-Path $root 'src\mobile\index.html'
$destination='C:\ProgramData\AlienGamerMode\App\mobile\index.html'
$backup=Join-Path 'C:\ProgramData\AlienGamerMode\UIBackups' ('mobile-page-'+(Get-Date).ToString('yyyyMMdd-HHmmss-fff')+'\index.html')
try{
    if(-not(Test-Path -LiteralPath $destination)){throw 'Mobile monitor is not installed.'}
    New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force|Out-Null
    Copy-Item -LiteralPath $destination -Destination $backup
    Copy-Item -LiteralPath $source -Destination $destination -Force
    @{updated=$true;backup=$backup;restartRequired=$false;preferencesUnchanged=$true;certificateUnchanged=$true}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}catch{
    if(Test-Path -LiteralPath $backup){Copy-Item -LiteralPath $backup -Destination $destination -Force}
    @{updated=$false;error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
    exit 1
}
