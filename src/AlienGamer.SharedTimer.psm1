function Invoke-AGSharedTimer {
    param([Parameter(Mandatory)][string]$Directory,[ValidateSet('read','configure','toggle','start','pause','extra','reset')][string]$Action='read',[int]$Seconds=0,[int]$ExtraStep=5,[long]$Revision=-1,[long]$Now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    New-Item -ItemType Directory -Path $Directory -Force|Out-Null
    $path=Join-Path $Directory 'session-timer-shared.txt'
    $hash=[Security.Cryptography.SHA256]::Create()
    try{$key=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Directory).ToLowerInvariant())))).Replace('-','')}finally{$hash.Dispose()}
    $mutex=[Threading.Mutex]::new($false,('Local\AlienGamerTimer-'+$key))
    $locked=$false
    try{
        try{$locked=$mutex.WaitOne(3000)}catch [Threading.AbandonedMutexException]{$locked=$true}
        if(-not$locked){throw 'Timer busy. Try again.'}
        $parse={param($file)
            $v=@{};foreach($line in [IO.File]::ReadAllLines($file)){if($line-match'^([A-Za-z]+)=(.*)$'){$v[$Matches[1]]=$Matches[2]}}
            $d=0L;$b=0L;$r=0L;$end=0L;$step=0;$count=0;$version=0L
            if(-not[long]::TryParse($v.duration,[ref]$d)-or-not[long]::TryParse($v.baseDuration,[ref]$b)-or-not[long]::TryParse($v.remaining,[ref]$r)-or-not[long]::TryParse($v.deadline,[ref]$end)-or-not[int]::TryParse($v.extraStep,[ref]$step)-or-not[int]::TryParse($v.extraCount,[ref]$count)){return}
            [void][long]::TryParse($v.revision,[ref]$version)
            if($b-lt0-or$d-lt$b-or$d-gt359999-or$r-lt0-or$r-gt$d-or$step-lt1-or$step-gt30-or$count-lt0-or$count-gt3-or$v.status-notin@('idle','running','paused','finished')-or($v.configured-eq'1'-and$b-lt60)-or($v.status-eq'running'-and$end-le0)){return}
            [ordered]@{baseDuration=$b;extraStep=$step;extraCount=$count;duration=$d;remaining=$r;deadline=$end;status=$v.status;configured=($v.configured-eq'1');revision=$version}
        }
        $exists=Test-Path -LiteralPath $path
        $state=if($exists){& $parse $path}else{$null}
        if($exists-and-not$state){throw 'Shared timer state invalid. Restore its backup before continuing.'}
        $new=-not$state
        if(-not$state){
            # One-time migration: prefer enabled screens, then a live session.
            $active=@()
            $configuration=Join-Path $Directory 'AlienGamerMode.json'
            if(Test-Path -LiteralPath $configuration){
                foreach($view in @((Get-Content -LiteralPath $configuration -Raw|ConvertFrom-Json).displayViews|Where-Object enabled)){
                    $id=([string]$view.id-replace'[^A-Za-z0-9_-]','-').Trim('-').ToLowerInvariant()
                    $active+=@("session-timer-AlienGamerMode-Views-$id.txt","session-timer-$id.txt")
                }
            }
            $legacy=@(Get-ChildItem -LiteralPath $Directory -Filter 'session-timer-*.txt' -File|Where-Object Name -ne 'session-timer-shared.txt'|ForEach-Object{
                $s=& $parse $_.FullName
                if($s-and$s.configured){
                    if($s.status-eq'running'-and$s.deadline-le$Now){$s.status='finished';$s.remaining=0;$s.deadline=0}
                    $rank=switch($s.status){'running'{0};'paused'{1};'idle'{2};default{3}}
                    if($active.Count-and$_.Name-notin$active){$rank+=10}
                    [pscustomobject]@{state=$s;rank=$rank;date=$_.LastWriteTimeUtc}
                }
            })|Sort-Object rank,@{Expression='date';Descending=$true}|Select-Object -First 1
            $state=if($legacy){$legacy.state}else{[ordered]@{baseDuration=0L;extraStep=5;extraCount=0;duration=0L;remaining=0L;deadline=0L;status='idle';configured=$false;revision=0L}}
        }
        $expired=$false
        if($state.status-eq'running'){$state.remaining=[Math]::Min($state.duration,[Math]::Max(0,$state.deadline-$Now));if($state.remaining-eq0){$state.status='finished';$state.deadline=0;$expired=$true}}
        if($Action-ne'read'-and$Revision-ge0-and$Revision-ne$state.revision){throw 'Timer changed on another screen. Refresh and try again.'}
        switch($Action){
            'configure'{
                if($Seconds-lt60-or$Seconds-gt359999-or$ExtraStep-lt1-or$ExtraStep-gt30-or$Seconds+3*$ExtraStep*60-gt359999){throw 'Invalid timer duration or increment.'}
                $state.baseDuration=$Seconds;$state.duration=$Seconds;$state.remaining=$Seconds;$state.extraStep=$ExtraStep;$state.extraCount=0;$state.deadline=0;$state.status='idle';$state.configured=$true
            }
            'reset'{$state.remaining=$state.baseDuration;$state.duration=$state.baseDuration;$state.deadline=0;$state.status='idle';$state.extraCount=0}
            'extra'{
                if(-not$state.configured-or$state.extraCount-ge3-or$state.duration+$state.extraStep*60-gt359999){throw 'Extra time unavailable (maximum three increments).'}
                $n=$state.extraStep*60;$state.duration+=$n;$state.remaining+=$n;$state.extraCount++
                if($state.status-eq'running'){$state.deadline+=$n}elseif($state.status-eq'finished'){$state.status='paused'}
            }
            {$_-in@('toggle','start','pause')}{
                if(-not$state.configured){throw 'Configure the timer first.'}
                if($Action-eq'pause'-or($Action-eq'toggle'-and$state.status-eq'running')){if($state.status-eq'running'){$state.status='paused';$state.deadline=0}}
                elseif($state.status-ne'running'){
                    if($state.status-eq'finished'){$state.remaining=$state.baseDuration;$state.duration=$state.baseDuration;$state.extraCount=0}
                    $state.status='running';$state.deadline=$Now+$state.remaining
                }
            }
        }
        if($new-or$expired-or$Action-ne'read'){
            $state.revision++
            $lines=foreach($k in $state.Keys){$value=if($k-eq'configured'){[int][bool]$state[$k]}else{$state[$k]};"$k=$value"}
            $temp="$path.$PID.tmp";[IO.File]::WriteAllText($temp,($lines-join"`n")+"`n",[Text.UTF8Encoding]::new($false))
            if([IO.File]::Exists($path)){[IO.File]::Replace($temp,$path,($path+'.bak'))}else{[IO.File]::Move($temp,$path)}
        }
        [pscustomobject]$state
    }finally{if($locked){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
Export-ModuleMember -Function Invoke-AGSharedTimer
