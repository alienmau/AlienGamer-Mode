param([Parameter(Mandatory)][string]$ResultPath)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$installed='C:\ProgramData\AlienGamerMode\App'
$backup=Join-Path 'C:\ProgramData\AlienGamerMode\UIBackups' ('shared-timer-'+(Get-Date).ToString('yyyyMMdd-HHmmss-fff'))
$copied=[Collections.Generic.List[object]]::new()
$files=@('AlienGamer.SharedTimer.psm1','AlienGamer.TimerHttp.psm1','Invoke-SessionTimer.ps1','AlienGamerBridge.ps1','AlienGamerModeAgent.ps1','AlienGamerModeLauncher.vbs','Configure-SessionTimer.ps1','Show-AlienGamerLayoutEditor.ps1','mobile\index.html','skin\SessionTimer.lua')
try{
    if(-not(Test-Path -LiteralPath (Join-Path $installed 'AlienGamerModeAgent.ps1'))){throw 'App not installed.'}
    foreach($file in $files){if(-not(Test-Path -LiteralPath (Join-Path $root ('src\'+$file)))){throw 'Missing update source.'}}
    foreach($file in $files){
        $destination=Join-Path $installed $file;$prior=Join-Path $backup $file;$existed=Test-Path -LiteralPath $destination
        if($existed){New-Item -ItemType Directory -Path (Split-Path -Parent $prior) -Force|Out-Null;Copy-Item -LiteralPath $destination -Destination $prior}
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force|Out-Null
        Copy-Item -LiteralPath (Join-Path $root ('src\'+$file)) -Destination $destination -Force
        $copied.Add(@{destination=$destination;prior=$prior;existed=$existed})
    }
    # Elevation installs code only. Restart/regeneration must occur in the
    # user's app context, not the elevated/tool-side AppData view.
    @{updated=$true;backup=$backup;preferencesUnchanged=$true;certificateUnchanged=$true;restartAgentRequired=$true}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}catch{
    foreach($op in $copied){if($op.existed){Copy-Item -LiteralPath $op.prior -Destination $op.destination -Force}else{Remove-Item -LiteralPath $op.destination -Force}}
    @{updated=$false;error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
    exit 1
}
