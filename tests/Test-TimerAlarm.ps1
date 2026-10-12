$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.TimerAlarm.psm1') -Force
Import-Module (Join-Path $root 'src\AlienGamer.SharedTimer.psm1') -Force
Import-Module (Join-Path $root 'src\AlienGamer.TimerHttp.psm1') -Force
$dataRoot=Join-Path $root ('build\tests\alarm-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dataRoot|Out-Null
function Assert($condition,$message){if(-not$condition){throw $message}}
$settings=Get-AGTimerAlarmSettings $dataRoot
Assert ($settings.output-eq'mobile'-and$settings.sound-eq'timer-4'-and$settings.deviceId-eq'') 'Default preset/output'
$before=Invoke-AGSharedTimer $dataRoot configure -Seconds 60 -ExtraStep 1
foreach($output in @('pc','both','mobile')){
    $settings=Set-AGTimerAlarmSettings $dataRoot -Output $output -Revision $settings.revision
    $timer=Invoke-AGSharedTimer $dataRoot
    Assert ($timer.revision-eq$before.revision-and$timer.remaining-eq60) 'Audio settings changed timer'
    Assert ((Test-AGTimerAlarmDue @{status='running'} @{status='finished'} $settings)-eq($output-ne'mobile')) 'Output routing'
    Assert (-not(Test-AGTimerAlarmDue $null @{status='finished'} $settings)) 'Alarm on initial completed state'
    Assert (-not(Test-AGTimerAlarmDue @{status='finished'} @{status='finished'} $settings)) 'Repeated alarm'
}
try{Set-AGTimerAlarmSettings $dataRoot -Output both -Revision 0|Out-Null;throw 'Conflict accepted'}catch{Assert ($_.Exception.Message-like'*changed*') 'Conflict detection'}
$request=[pscustomobject]@{Method='POST';Headers=@{origin='https://192.168.0.2:27844';'x-aliengamer-timer'='1';'content-type'='application/json'};Body=(@{action='alarm';revision=$timer.revision;alarmRevision=$settings.revision;output='both';deviceId='bad';customFile='C:\private.mp3'}|ConvertTo-Json -Compress)}
$permission=[pscustomobject]@{allowTimerControl=$true;modules=@('timer')}
Assert ((Invoke-AGTimerRequest $request $false 'https://192.168.0.2:27844' $permission $dataRoot).Code-eq403) 'HTTP accepted alarm change'
Assert ((Invoke-AGTimerRequest $request $true 'https://192.168.0.2:27844' $permission $dataRoot).Code-eq200) 'HTTPS alarm change'
$settings=Get-AGTimerAlarmSettings $dataRoot
Assert ($settings.output-eq'both'-and$settings.deviceId-eq'') 'Mobile changed private device/path'
$mp3=Join-Path $root 'src\mobile\sounds\timer-4.mp3'
$settings=Set-AGTimerAlarmSettings $dataRoot -Sound custom -CustomFile $mp3
Assert ((Get-FileHash (Resolve-AGAlarmSound $dataRoot $root $settings)).Hash-eq(Get-FileHash $mp3).Hash) 'Custom file copy'
$devices=@(Get-AGAudioDevices)
foreach($id in @('',$(if($devices.Count){$devices[0].id}else{'missing'}),'missing-device-test')){
    $playback=Start-AGAlarmPlayback -File $mp3 -DeviceId $id -Muted
    try{
        Assert ($playback.Fallback-eq($id-eq'missing-device-test'-or$id-eq'missing')) 'Disconnected-device fallback'
        $ready=$false
        for($i=0;$i-lt50;$i++){if([string]$playback.Player.PlaybackSession.PlaybackState-eq'Playing'){$ready=$true;break};Start-Sleep -Milliseconds 100}
        Assert $ready 'MP3 playback did not start'
        Assert $playback.Player.IsMuted 'Test played audible sound'
    }finally{$playback.Player.Pause();$playback.Player.Dispose()}
}
# Agent watcher can run with zero desktop skins; model live mobile-only state.
Import-Module (Join-Path $root 'src\AlienGamer.Process.psm1') -Force
$previewDir=Join-Path $dataRoot 'live-preview'
Set-AGTimerAlarmSettings $previewDir -Output pc -Sound timer-4|Out-Null
$process=Start-AGHiddenProcess 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $root 'src\Play-TimerAlarm.ps1')+'" -Directory "'+$previewDir+'" -Preview -Muted') -PassThru
try{
    $readyFile=Join-Path $previewDir 'timer-alarm-playback.json'
    for($i=0;$i-lt50-and-not(Test-Path -LiteralPath $readyFile);$i++){Start-Sleep -Milliseconds 100}
    Assert (Test-Path -LiteralPath $readyFile) 'Preview helper did not start'
    Assert ((Get-Content -LiteralPath $readyFile -Raw|ConvertFrom-Json).ok) 'Preview helper failed'
    [IO.File]::WriteAllText((Join-Path $previewDir 'preview-stop.signal'),'stop')
    Assert ($process.WaitForExit(3000)) 'Graceful preview stop timed out'
    Assert ($process.ExitCode-eq0) 'Preview stop failed'
}finally{if(-not$process.HasExited){$process.Kill()};$process.Dispose()}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src\AlienGamerModeAgent.ps1'),[ref]$tokens,[ref]$errors)
Assert (-not$errors.Count) 'Agent parse error'
$node=$ast.Find({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-eq'Watch-TimerAlarm'},$true)
Invoke-Expression $node.Extent.Text
function Test-MonitorActive{return $true}
function Invoke-AGSharedTimer {param($Directory) return $script:fixtureTimer}
function Start-AGHiddenProcess {param($FilePath,$ArgumentList)$script:alarmLaunches++}
$appRoot=Join-Path $root 'src';$script:alarmLaunches=0;$script:alarmPrevious=$null
foreach($status in @('running','finished','finished','finished')){$script:fixtureTimer=[pscustomobject]@{status=$status};Watch-TimerAlarm}
Assert ($script:alarmLaunches-eq1) 'Mobile-only agent did not emit exactly one alarm'
'PASS: 3 output modes, no timer reset, conflicts, protected web preferences, custom MP3, Windows/default/explicit/disconnected outputs, muted real playback and mobile-only one-shot watcher.'
