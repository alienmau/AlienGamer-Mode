param([Parameter(Mandatory)][string]$ResultPath)
$ErrorActionPreference='Stop'
$installed='C:\ProgramData\AlienGamerMode\App'
$root=Split-Path -Parent $PSScriptRoot
$files=@('AlienGamer.MobileTls.psm1','Show-MobileHttpsWizard.ps1','AlienGamerBridge.ps1','Show-AlienGamerLayoutEditor.ps1','mobile\index.html','mobile\help\https-secure.jpg','mobile\help\https-untrusted.jpg')
$copied=New-Object 'System.Collections.Generic.List[string]'
$backup=$null
try{
    if(-not(Test-Path -LiteralPath (Join-Path $installed 'AlienGamerModeAgent.ps1'))){throw 'AlienGamer Mode is not installed.'}
    foreach($relative in $files){if(-not(Test-Path -LiteralPath (Join-Path $root ('src\'+$relative)))){throw ('Missing source: '+$relative)}}
    $backup=Join-Path 'C:\ProgramData\AlienGamerMode\UIBackups' ('https-'+(Get-Date).ToString('yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Path $backup -Force|Out-Null
    foreach($relative in $files){
        $destination=Join-Path $installed $relative
        if(Test-Path -LiteralPath $destination){
            $backupPath=Join-Path $backup $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force|Out-Null
            Copy-Item -LiteralPath $destination -Destination $backupPath
        }
    }
    foreach($relative in $files){
        $destination=Join-Path $installed $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force|Out-Null
        Copy-Item -LiteralPath (Join-Path $root ('src\'+$relative)) -Destination $destination -Force
        $copied.Add($relative)
    }
    @{updated=$true;backup=$backup;restartAgentRequired=$true;preferencesUnchanged=$true;trustInstalled=$false}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}catch{
    # Roll back only the exact files this update copied.
    foreach($relative in $copied){
        $prior=Join-Path $backup $relative;$destination=Join-Path $installed $relative
        if(Test-Path -LiteralPath $prior){Copy-Item -LiteralPath $prior -Destination $destination -Force}else{Remove-Item -LiteralPath $destination -Force}
    }
    @{updated=$false;error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath $ResultPath -Encoding UTF8
    exit 1
}
