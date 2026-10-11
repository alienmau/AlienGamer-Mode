$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src/AlienGamer.SharedTimer.psm1') -Force
Import-Module (Join-Path $root 'src/AlienGamer.TimerHttp.psm1') -Force
$dir=Join-Path $PSScriptRoot ('../build/tests/shared-'+[guid]::NewGuid().ToString('N'))
function Assert($ok,$message){if(-not$ok){throw $message}}
$s=Invoke-AGSharedTimer $dir
Assert (-not$s.configured-and$s.remaining-eq0) 'Initial state'
$s=Invoke-AGSharedTimer $dir configure -Seconds 100 -ExtraStep 1 -Revision $s.revision -Now 1000
$s=Invoke-AGSharedTimer $dir start -Revision $s.revision -Now 1000
Assert ($s.deadline-eq1100) 'Start'
$read=Invoke-AGSharedTimer $dir -Now 1070
Assert ($read.remaining-eq30-and$read.revision-eq$s.revision) 'Shared countdown'
$s=Invoke-AGSharedTimer $dir pause -Revision $s.revision -Now 1070
Assert ($s.remaining-eq30-and$s.deadline-eq0) 'Pause'
try{Invoke-AGSharedTimer $dir reset -Revision 0|Out-Null;throw 'Stale revision accepted'}catch{Assert ($_.Exception.Message-like'*changed*') 'Conflict detection'}
1..3|ForEach-Object {$s=Invoke-AGSharedTimer $dir extra -Revision $s.revision -Now 1070}
Assert ($s.remaining-eq210-and$s.extraCount-eq3) 'Increment cap'
try{Invoke-AGSharedTimer $dir extra|Out-Null;throw 'Fourth increment accepted'}catch{Assert ($_.Exception.Message-like'*maximum*') 'Fourth increment'}
$s=Invoke-AGSharedTimer $dir start -Revision $s.revision -Now 1100
$s=Invoke-AGSharedTimer $dir -Now 1310
Assert ($s.status-eq'finished'-and$s.remaining-eq0) 'Finish'
$s=Invoke-AGSharedTimer $dir reset -Revision $s.revision
Assert ($s.remaining-eq100-and$s.status-eq'idle') 'Reset to saved duration'
$settings=[pscustomobject]@{allowTimerControl=$false;modules=@('timer')}
$request=[pscustomobject]@{Method='POST';Headers=@{origin='https://192.168.0.2:27844';'x-aliengamer-timer'='1';'content-type'='application/json'};Body=(@{action='start';revision=$s.revision}|ConvertTo-Json -Compress)}
Assert ((Invoke-AGTimerRequest $request $true 'https://192.168.0.2:27844' $settings $dir).Code-eq403) 'Read only'
$settings.allowTimerControl=$true
Assert ((Invoke-AGTimerRequest $request $false 'https://192.168.0.2:27844' $settings $dir).Code-eq403) 'HTTP denied'
Assert ((Invoke-AGTimerRequest $request $true 'https://evil.example' $settings $dir).Code-eq403) 'Wrong origin denied'
$result=Invoke-AGTimerRequest $request $true 'https://192.168.0.2:27844' $settings $dir
Assert ($result.Code-eq200-and$result.Body.status-eq'running') 'Authorized control'
Assert ((Invoke-AGTimerRequest $request $true 'https://192.168.0.2:27844' $settings $dir).Code-eq409) 'Duplicate revision denied'
$request.Body='{"action":"shell","revision":1}'
Assert ((Invoke-AGTimerRequest $request $true 'https://192.168.0.2:27844' $settings $dir).Code-eq400) 'Unknown action denied'
$raw="POST /m/test/timer HTTP/1.1`r`nContent-Length: 2`r`nOrigin: https://local`r`n`r`n{}"
$stream=[IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes($raw))
try{$parsed=Read-AGHttpRequest $stream;Assert ($parsed.Body-eq'{}'-and$parsed.Method-eq'POST') 'HTTP parser'}finally{$stream.Dispose()}
$migration=Join-Path $dir 'migration';New-Item -ItemType Directory -Path $migration|Out-Null
[IO.File]::WriteAllText((Join-Path $migration 'AlienGamerMode.json'),'{"displayViews":[{"id":"enabled","enabled":true}]}')
$legacy="baseDuration=100`nextraStep=1`nextraCount=0`nduration=100`nremaining=100`ndeadline=1100`nstatus=running`nconfigured=1`n"
[IO.File]::WriteAllText((Join-Path $migration 'session-timer-enabled.txt'),$legacy)
[IO.File]::WriteAllText((Join-Path $migration 'session-timer-disabled.txt'),($legacy-replace'100','200'))
$m=Invoke-AGSharedTimer $migration -Now 1000
Assert ($m.duration-eq100-and$m.status-eq'running') 'Migration prefers enabled screens'
Assert (Test-Path (Join-Path $migration 'session-timer-enabled.txt')) 'Legacy files retained'
Import-Module (Join-Path $root 'src/AlienGamer.Process.psm1') -Force
$parallel=Join-Path $dir 'parallel';Invoke-AGSharedTimer $parallel configure -Seconds 100 -ExtraStep 1|Out-Null
$jobs=@()
try{
    1..4|ForEach-Object {
        $code="Import-Module '"+(Join-Path $root 'src/AlienGamer.SharedTimer.psm1')+"'; try { Invoke-AGSharedTimer -Directory '$parallel' -Action extra | Out-Null; exit 0 } catch { exit 1 }"
        $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $jobs+=Start-AGHiddenProcess -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -EncodedCommand '+$encoded) -PassThru
    }
    foreach($job in $jobs){if(-not$job.WaitForExit(10000)){throw 'Parallel action timed out.'}}
    $p=Invoke-AGSharedTimer $parallel
    Assert ($p.extraCount-eq3-and$p.duration-eq280) 'Concurrent writes preserve cap and state'
}finally{foreach($job in $jobs){if(-not$job.HasExited){$job.Kill()};$job.Dispose()}}
Write-Output 'PASS: shared countdown, configure/start/pause/extra/reset/finish, conflicts, migration, concurrent writers, permission, TLS, origin, parser.'
