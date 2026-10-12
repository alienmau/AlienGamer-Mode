param([Parameter(Mandatory)][string]$Directory,[switch]$Preview,[switch]$Muted)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.TimerAlarm.psm1') -Force
$resultPath=Join-Path $Directory 'timer-alarm-playback.json'
$player=$null
try{
    $previewStop=Join-Path $Directory 'preview-stop.signal'
    if($Preview-and(Test-Path -LiteralPath $previewStop)){exit 0}
    $settings=Get-AGTimerAlarmSettings $Directory
    if(-not$Preview-and$settings.output-notin@('pc','both')){exit 0}
    $file=Resolve-AGAlarmSound $Directory $PSScriptRoot $settings
    if(-not(Test-Path -LiteralPath $file)){throw 'Alarm sound not found.'}
    $playback=Start-AGAlarmPlayback $file $settings.deviceId -Muted:$Muted;$player=$playback.Player
    @{ok=$true;fallback=$playback.Fallback;time=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $resultPath -Encoding UTF8
    $started=[DateTime]::UtcNow;$seenPlaying=$false
    do{
        Start-Sleep -Milliseconds 100
        if($Preview-and(Test-Path -LiteralPath $previewStop)){break}
        $state=[string]$player.PlaybackSession.PlaybackState
        if($state-eq'Playing'){$seenPlaying=$true}
        if($seenPlaying-and$state-in@('None','Paused')){break}
        if(-not$seenPlaying-and([DateTime]::UtcNow-$started).TotalSeconds-gt10){throw 'Audio did not start. Check device, file and volume.'}
    }while(([DateTime]::UtcNow-$started).TotalSeconds-lt300)
}catch{
    @{ok=$false;error=$_.Exception.Message;time=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $resultPath -Encoding UTF8
    exit 1
}finally{if($player){$player.Pause();$player.Dispose()}}
