function Get-AGTimerAlarmSettings([string]$Directory){
    $path=Join-Path $Directory 'timer-alarm.json'
    if(Test-Path -LiteralPath $path){
        $s=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
        if($s.output -notin @('mobile','pc','both') -or $s.sound -notin @('timer-1','timer-2','timer-3','timer-4','custom') -or $s.revision -lt 0){throw 'Invalid alarm settings.'}
        return $s
    }
    [pscustomobject]@{output='mobile';sound='timer-4';deviceId='';revision=0}
}
function Set-AGTimerAlarmSettings {
    param([Parameter(Mandatory)][string]$Directory,[ValidateSet('mobile','pc','both')][string]$Output,
        [ValidateSet('timer-1','timer-2','timer-3','timer-4','custom')][string]$Sound,
        [string]$DeviceId,[long]$Revision=-1,[string]$CustomFile)
    New-Item -ItemType Directory -Path $Directory -Force|Out-Null
    $hash=[Security.Cryptography.SHA256]::Create()
    try{$key=[BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Directory).ToLowerInvariant()))).Replace('-','')}finally{$hash.Dispose()}
    # Separate from timer state: sound changes never reset the countdown.
    $mutex=[Threading.Mutex]::new($false,('Local\AlienGamerAlarm-'+$key));$locked=$false
    try{
        try{$locked=$mutex.WaitOne(3000)}catch [Threading.AbandonedMutexException]{$locked=$true}
        if(-not$locked){throw 'Alarm settings busy.'}
        $s=Get-AGTimerAlarmSettings $Directory
        if($Revision-ge0-and$Revision-ne$s.revision){throw 'Alarm settings changed. Reopen and try again.'}
        if($PSBoundParameters.ContainsKey('Output')){$s.output=$Output}
        if($PSBoundParameters.ContainsKey('Sound')){$s.sound=$Sound}
        if($PSBoundParameters.ContainsKey('DeviceId')){$s.deviceId=$DeviceId}
        if($CustomFile){
            $file=Get-Item -LiteralPath $CustomFile
            if($file.Extension -ine '.mp3' -or $file.Length-le0 -or $file.Length-gt10MB){throw 'Choose an MP3 up to 10 MB.'}
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $Directory 'timer-alarm-custom.mp3') -Force
        }
        if($s.output-in@('pc','both')-and$s.sound-eq'custom'-and-not(Test-Path -LiteralPath (Join-Path $Directory 'timer-alarm-custom.mp3'))){throw 'Choose your custom MP3 first.'}
        $s.revision=[long]$s.revision+1
        $path=Join-Path $Directory 'timer-alarm.json';$temp="$path.$PID.tmp"
        [IO.File]::WriteAllText($temp,($s|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
        if([IO.File]::Exists($path)){[IO.File]::Replace($temp,$path,$path+'.bak')}else{[IO.File]::Move($temp,$path)}
        $s
    }finally{if($locked){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
function Wait-AGAudioOperation($Operation,[type]$ResultType){
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $method=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object {$_.Name-eq'AsTask'-and$_.IsGenericMethodDefinition-and$_.GetGenericArguments().Count-eq1-and$_.GetParameters().Count-eq1-and$_.GetParameters()[0].ParameterType.Name-eq'IAsyncOperation`1'}|Select-Object -First 1
    $task=$method.MakeGenericMethod($ResultType).Invoke($null,@($Operation))
    if(-not$task.Wait(5000)){throw 'Audio device discovery timed out.'}
    $task.Result
}
function Get-AGAudioDevices {
    $type=[Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
    $devices=Wait-AGAudioOperation ($type::FindAllAsync([Windows.Devices.Enumeration.DeviceClass,Windows.Devices.Enumeration,ContentType=WindowsRuntime]::AudioRender)) ([Windows.Devices.Enumeration.DeviceInformationCollection,Windows.Devices.Enumeration,ContentType=WindowsRuntime])
    foreach($device in $devices){if($device.IsEnabled){[pscustomobject]@{id=$device.Id;name=$device.Name}}}
}
function Resolve-AGAlarmSound([string]$Directory,[string]$AppRoot,$Settings){
    if($Settings.sound-eq'custom'){return Join-Path $Directory 'timer-alarm-custom.mp3'}
    if($Settings.sound-notin@('timer-1','timer-2','timer-3','timer-4')){throw 'Invalid sound preset.'}
    Join-Path $AppRoot ('mobile\sounds\'+$Settings.sound+'.mp3')
}
function Start-AGAlarmPlayback([string]$File,[string]$DeviceId,[switch]$Muted){
    $type=[Windows.Media.Playback.MediaPlayer,Windows.Media.Playback,ContentType=WindowsRuntime]
    $player=[Activator]::CreateInstance($type);$fallback=$false
    try{
        if($DeviceId){
            $match=@(Get-AGAudioDevices|Where-Object id -ceq $DeviceId)
            if($match.Count){
                $deviceType=[Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
                try{$player.AudioDevice=Wait-AGAudioOperation ($deviceType::CreateFromIdAsync($DeviceId)) $deviceType}catch{$fallback=$true}
            }else{$fallback=$true}
        }
        # A new player without a pinned device resolves Windows' current default.
        $sourceType=[Windows.Media.Core.MediaSource,Windows.Media.Core,ContentType=WindowsRuntime]
        $player.Source=$sourceType::CreateFromUri([Uri]::new([IO.Path]::GetFullPath($File)))
        $player.IsLoopingEnabled=$false;$player.IsMuted=$Muted.IsPresent;$player.Play()
        [pscustomobject]@{Player=$player;Fallback=$fallback}
    }catch{$player.Dispose();throw}
}
function Test-AGTimerAlarmDue($Previous,$Current,$Settings){
    [bool]($Previous-and$Previous.status-eq'running'-and$Current.status-eq'finished'-and$Settings.output-in@('pc','both'))
}
Export-ModuleMember -Function Get-AGTimerAlarmSettings,Set-AGTimerAlarmSettings,Get-AGAudioDevices,Resolve-AGAlarmSound,Start-AGAlarmPlayback,Test-AGTimerAlarmDue
