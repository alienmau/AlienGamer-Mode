param([Parameter(Mandatory)][string]$ResultPath)
$ErrorActionPreference='Stop'
$installed='C:\ProgramData\AlienGamerMode\App'
$root=Split-Path -Parent $PSScriptRoot
try{
    if(-not(Test-Path -LiteralPath (Join-Path $installed 'AlienGamerModeAgent.ps1'))){throw 'AlienGamer Mode no esta instalado.'}
    $files=@('AlienGamer.UI.psm1','native\AlienGamerTheme.cs','Show-AlienGamerLayoutEditor.ps1','Configure-SessionTimer.ps1','AlienGamerModeAgent.ps1','AlienGamerEventRecorder.ps1','AlienGamer.Process.psm1','native\AlienGamerProcessHost.cs','AlienGamerModeLauncher.vbs','Stop-AlienGamerMode.ps1')
    if(-not(Test-Path -LiteralPath (Join-Path $root 'assets\AlienGamerProcessHost.exe'))){throw 'Falta compilar el lanzador sin consola.'}
    foreach($relative in $files){if(-not(Test-Path -LiteralPath (Join-Path (Join-Path $root 'src') $relative))){throw ('Falta el archivo de tema '+$relative)}}
    $backup=Join-Path 'C:\ProgramData\AlienGamerMode\UIBackups' ((Get-Date).ToString('yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Path $backup -Force|Out-Null
    foreach($relative in $files){
        $destination=Join-Path $installed $relative;$prior=Join-Path $backup $relative
        if(Test-Path -LiteralPath $destination){New-Item -ItemType Directory -Path (Split-Path -Parent $prior) -Force|Out-Null;Copy-Item -LiteralPath $destination -Destination $prior}
    }
    try{
        $hostDestination=Join-Path $installed 'assets\AlienGamerProcessHost.exe'
        $hostBackup=Join-Path $backup 'assets\AlienGamerProcessHost.exe'
        if(Test-Path -LiteralPath $hostDestination){New-Item -ItemType Directory -Path (Split-Path -Parent $hostBackup) -Force|Out-Null;Copy-Item -LiteralPath $hostDestination -Destination $hostBackup}
        New-Item -ItemType Directory -Path (Split-Path -Parent $hostDestination) -Force|Out-Null
        Copy-Item -LiteralPath (Join-Path $root 'assets\AlienGamerProcessHost.exe') -Destination $hostDestination -Force
        foreach($relative in $files){
            $destination=Join-Path $installed $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force|Out-Null
            Copy-Item -LiteralPath (Join-Path (Join-Path $root 'src') $relative) -Destination $destination -Force
        }
    }catch{
        if(Test-Path -LiteralPath $hostBackup){Copy-Item -LiteralPath $hostBackup -Destination $hostDestination -Force}
        foreach($relative in $files){$prior=Join-Path $backup $relative;if(Test-Path -LiteralPath $prior){Copy-Item -LiteralPath $prior -Destination (Join-Path $installed $relative) -Force}}
        throw
    }
    @{updated=$true;backup=$backup;restartAgentRequired=$true;preferencesUnchanged=$true}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}catch{
    @{updated=$false;error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
    exit 1
}
