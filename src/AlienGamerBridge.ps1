param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\build\AlienGamerMode.profile.json'),
    [int]$Port = 0,
    [string]$StateDirectory = (Join-Path $env:LOCALAPPDATA 'AlienGamerMode')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.HWiNFO.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.MobileTls.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.SharedTimer.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.TimerHttp.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.TimerAlarm.psm1') -Force
$culture = [Globalization.CultureInfo]::InvariantCulture
if (-not (Test-Path $ProfilePath)) { throw "No existe el perfil resuelto: $ProfilePath" }
$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
if ($Port -le 0) { $Port = [int]$profile.bridgePort }
if (-not (Test-Path $StateDirectory)) { New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null }
$pidFile = Join-Path $StateDirectory 'bridge.pid'
$logFile = Join-Path $StateDirectory 'bridge.log'
$configFile = Join-Path $StateDirectory 'AlienGamerMode.json'
[void](Invoke-AGSharedTimer -Directory $StateDirectory)
$mobileEndpointFile = Join-Path $StateDirectory 'mobile-endpoint.json'
$PID | Set-Content -LiteralPath $pidFile -Encoding ASCII

function Get-ReadingValue([hashtable]$ByKey, $Mapping, [double]$Unavailable) {
    if (-not $Mapping -or -not $Mapping.available -or -not $Mapping.key -or -not $ByKey.ContainsKey([string]$Mapping.key)) { return $Unavailable }
    return [double]$ByKey[[string]$Mapping.key].Value
}

function Get-VramValueMB([hashtable]$ByKey, $Mapping, [double]$Unavailable) {
    $value = Get-ReadingValue $ByKey $Mapping $Unavailable
    if ($value -eq $Unavailable) { return $Unavailable }
    if ($Mapping.unit -eq 'GB') { return $value * 1024 }
    return $value
}

function Limit-Reading([double]$Value, [double]$Minimum, [double]$Maximum, [double]$Unavailable) {
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value) -or $Value -lt $Minimum -or $Value -gt $Maximum) { return $Unavailable }
    return $Value
}

function Get-AlienGamerStatus {
    $inventory = try { @(Get-HWiNFOInventory) } catch { @() }
    $byKey = @{}
    foreach ($reading in $inventory) { $byKey[[string]$reading.Key] = $reading }
    $missing = [double]$profile.unavailableValue
    $coreValues = @()
    foreach ($core in @($profile.cores)) {
        $value = if ($byKey.ContainsKey([string]$core.key)) { [double]$byKey[[string]$core.key].Value } else { $missing }
        $value = Limit-Reading $value 0 100 $missing
        $coreValues += [ordered]@{ logicalIndex=[int]$core.logicalIndex; type=[string]$core.type; value=$value; available=($value -ne $missing) }
    }
    $m = $profile.mappings
    $gpuTemperature = Limit-Reading (Get-ReadingValue $byKey $m.gpuTemperature $missing) -20 150 $missing
    $gpuUsage = Limit-Reading (Get-ReadingValue $byKey $m.gpuUsage $missing) 0 100 $missing
    $cpuTemperature = Limit-Reading (Get-ReadingValue $byKey $m.cpuTemperature $missing) -20 150 $missing
    $cpuUsage = Limit-Reading (Get-ReadingValue $byKey $m.cpuUsage $missing) 0 100 $missing
    $storageTemperature = Limit-Reading (Get-ReadingValue $byKey $m.storageTemperature $missing) -20 150 $missing
    $coreMaximumTemperature = Limit-Reading (Get-ReadingValue $byKey $m.coreMaximumTemperature $missing) -20 150 $missing
    $vramUsed = Limit-Reading (Get-VramValueMB $byKey $m.vramUsed $missing) 0 1048576 $missing
    $vramFree = Limit-Reading (Get-VramValueMB $byKey $m.vramFree $missing) 0 1048576 $missing
    $fps = Limit-Reading (Get-ReadingValue $byKey $m.fps $missing) 0 2000 $missing
    $frameTime = Limit-Reading (Get-ReadingValue $byKey $m.frameTime $missing) 0 10000 $missing
    if ($fps -gt 0.5 -and $frameTime -gt 0) {
        $ratio = $frameTime / (1000.0 / $fps)
        if ($ratio -lt 0.65 -or $ratio -gt 1.35) { $fps = $missing; $frameTime = $missing }
    }
    $cpuThermal = Limit-Reading (Get-ReadingValue $byKey $m.cpuThermal $missing) 0 1 $missing
    $gpuThermal = Limit-Reading (Get-ReadingValue $byKey $m.gpuThermal $missing) 0 1 $missing
    $cpuPower = Limit-Reading (Get-ReadingValue $byKey $m.cpuPower $missing) 0 1 $missing
    $gpuPower = Limit-Reading (Get-ReadingValue $byKey $m.gpuPower $missing) 0 1 $missing
    return [ordered]@{
        timestamp = (Get-Date).ToString('o')
        source = if($inventory.Count){'HWiNFO Shared Memory'}else{'Unavailable'}
        gpuTemperature = $gpuTemperature
        gpuUsage = $gpuUsage
        cpuTemperature = $cpuTemperature
        cpuUsage = $cpuUsage
        storageTemperature = $storageTemperature
        coreMaximumTemperature = $coreMaximumTemperature
        cores = $coreValues
        vramUsed = $vramUsed
        vramFree = $vramFree
        fps = $fps
        frameTime = $frameTime
        cpuThermal = $cpuThermal
        gpuThermal = $gpuThermal
        cpuPower = $cpuPower
        gpuPower = $gpuPower
    }
}

function ConvertTo-Pipe($Status) {
    $values = New-Object 'System.Collections.Generic.List[double]'
    foreach ($name in @('gpuTemperature','gpuUsage','cpuTemperature','cpuUsage','storageTemperature','coreMaximumTemperature')) { $values.Add([double]$Status[$name]) }
    foreach ($core in @($Status.cores)) { $values.Add([double]$core.value) }
    foreach ($name in @('vramUsed','vramFree','fps','frameTime','cpuThermal','gpuThermal','cpuPower','gpuPower')) { $values.Add([double]$Status[$name]) }
    # WebParser trata estos campos como texto, por lo que el redondeo debe
    # realizarse aquí. Un decimal evita desbordes en FPS, frame time y núcleos.
    return ($values | ForEach-Object { $_.ToString('0.0', $culture) }) -join '|'
}

function Send-Response($Stream, [int]$Code, [string]$ContentType, [string]$Body) {
    $payload = [Text.Encoding]::UTF8.GetBytes($Body)
    $reason = switch($Code){200{'OK'};400{'Bad Request'};403{'Forbidden'};409{'Conflict'};503{'Service Unavailable'};default{'Not Found'}}
    $headers = "HTTP/1.1 $Code $reason`r`nContent-Type: $ContentType; charset=utf-8`r`nCache-Control: no-store, no-cache`r`nReferrer-Policy: no-referrer`r`nX-Content-Type-Options: nosniff`r`nContent-Security-Policy: default-src 'self'; connect-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'`r`nContent-Length: $($payload.Length)`r`nConnection: close`r`n`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    $Stream.Write($payload, 0, $payload.Length)
    $Stream.Flush()
}

function Test-PrivateIpv4([string]$Address) {
    $ip=$null
    if(-not [Net.IPAddress]::TryParse($Address,[ref]$ip) -or $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){return $false}
    $b=$ip.GetAddressBytes()
    return ($b[0] -eq 10 -or ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) -or ($b[0] -eq 192 -and $b[1] -eq 168))
}

function Test-SameSubnet([Net.IPAddress]$Client,[Net.IPAddress]$ServerIp,[int]$PrefixLength) {
    if($Client.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){return $false}
    $a=$Client.GetAddressBytes();$b=$ServerIp.GetAddressBytes()
    for($i=0;$i -lt 4;$i++){
        $bits=[Math]::Max(0,[Math]::Min(8,$PrefixLength-$i*8))
        if($bits -eq 0){break}
        $mask=(256-(1 -shl (8-$bits))) -band 255
        if(($a[$i] -band $mask) -ne ($b[$i] -band $mask)){return $false}
    }
    return $true
}

function Get-MobileEndpoint {
    $interfaces=@([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object { $_.OperationalStatus -eq [Net.NetworkInformation.OperationalStatus]::Up } |
        Sort-Object @{Expression={if($_.NetworkInterfaceType -eq [Net.NetworkInformation.NetworkInterfaceType]::Ethernet){0}else{1}}})
    foreach($interface in $interfaces){
        $properties=$interface.GetIPProperties()
        if(-not @($properties.GatewayAddresses|Where-Object {$_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork}).Count){continue}
        foreach($address in @($properties.UnicastAddresses)){
            if($address.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and (Test-PrivateIpv4 ([string]$address.Address))){
                return [pscustomobject]@{ip=[string]$address.Address;prefix=[int]$address.PrefixLength}
            }
        }
    }
    return $null
}

$mobileListener=$null
$mobileBinding=$null
$mobileToken=''
$mobilePort=0
$mobileModules=@()
function Get-MobileSessionTimer {
    param([string]$Directory,$Views,[long]$Now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    $candidates=@(foreach($view in @($Views|Where-Object enabled)){
        $id=([string]$view.id -replace '[^A-Za-z0-9_-]','-').Trim('-').ToLowerInvariant()
        if(-not$id){$id='display'}
        # Rainmeter passes CURRENTCONFIG, not the bare display id, to Lua.
        $paths=@((Join-Path $Directory ("session-timer-AlienGamerMode-Views-$id.txt")),(Join-Path $Directory ("session-timer-$id.txt")))
        foreach($path in $paths){
            if(-not(Test-Path -LiteralPath $path)){continue}
            try{
                $values=@{}
                foreach($line in @(Get-Content -LiteralPath $path -ErrorAction Stop)){if($line-match'^([A-Za-z]+)=(.*)$'){$values[$Matches[1]]=$Matches[2]}}
                $remaining=0L;$deadline=0L
                if($values.configured-ne'1'-or$values.status-notin@('idle','running','paused','finished')-or-not[long]::TryParse([string]$values.remaining,[ref]$remaining)-or-not[long]::TryParse([string]$values.deadline,[ref]$deadline)){continue}
                $duration=0L
                if(-not [long]::TryParse([string]$values.duration,[ref]$duration)-or$duration-lt0){$duration=0L}
                $state=[string]$values.status
                if($state-eq'running'){
                    if($deadline-le0){continue}
                    $remaining=[Math]::Max(0,$deadline-$Now)
                    if($remaining-eq0){$state='finished'}
                }
                $rank=switch($state){'running'{0};'paused'{1};'finished'{2};default{3}}
                [pscustomobject]@{rank=$rank;modified=(Get-Item -LiteralPath $path).LastWriteTimeUtc;viewId=[string]$view.id;remaining=[Math]::Max(0,$remaining);duration=$duration;status=$state}
                break
            }catch{continue} # A transient partial write must not break sensor delivery.
        }
    })
    $chosen=$candidates|Sort-Object rank,@{Expression='modified';Descending=$true},viewId|Select-Object -First 1
    if($chosen){return [ordered]@{remaining=$chosen.remaining;duration=$chosen.duration;configured=$true;status=$chosen.status;viewId=$chosen.viewId}}
    return [ordered]@{remaining=0;duration=0;configured=$false;status='idle';viewId=''}
}
$mobileTimerViews=@()
$mobileCheck=[DateTime]::MinValue
$mobileTls=$false
$mobileIdentity=$null
$mobilePrepared=$false
function Update-MobileListener {
    if(((Get-Date)-$script:mobileCheck).TotalSeconds -lt 3){return}
    $script:mobileCheck=Get-Date
    $settings=$null
    try{$settings=(Get-Content -LiteralPath $configFile -Raw -Encoding UTF8|ConvertFrom-Json).mobileView}catch{}
    $enabled=$settings -and [bool]$settings.enabled -and [string]$settings.token -match '^[a-fA-F0-9]{32,64}$'
    $port=if($settings){[int]$settings.port}else{0}
    if($port -lt 1024 -or $port -gt 65535){$enabled=$false}
    $endpoint=if($enabled){Get-MobileEndpoint}else{$null}
    $tlsRequested=$settings -and $settings.PSObject.Properties['tls'] -and [bool]$settings.tls.enabled
    $prepared=$settings -and $settings.PSObject.Properties['tls'] -and ([bool]$settings.tls.prepared -or $tlsRequested)
    $renewCertificate=$script:mobileIdentity -and $script:mobileIdentity.Certificate.NotAfter -lt (Get-Date).AddDays(7)
    $changed=($script:mobileListener -and (-not $endpoint -or $script:mobileBinding.ip -ne $endpoint.ip -or $script:mobilePort -ne $port -or $script:mobileToken -ne [string]$settings.token -or $script:mobileTls -ne [bool]$tlsRequested -or $script:mobilePrepared -ne [bool]$prepared -or $renewCertificate))
    if($changed){$script:mobileListener.Stop();$script:mobileListener=$null;Remove-Item -LiteralPath $mobileEndpointFile -Force -ErrorAction SilentlyContinue}
    if(-not $endpoint){Remove-Item -LiteralPath $mobileEndpointFile -Force -ErrorAction SilentlyContinue;return}
    $script:mobileToken=[string]$settings.token
    $script:mobileModules=@($settings.modules)
    try{
        $script:mobileTimerViews=@((Get-Content -LiteralPath $configFile -Raw -Encoding UTF8|ConvertFrom-Json).displayViews|Where-Object enabled)
    }catch{}
    if(-not $script:mobileListener){
        try{
            $script:mobileIdentity=if($prepared){Get-AGMobileTlsIdentity -Directory (Join-Path $StateDirectory 'MobileTls') -IPAddress $endpoint.ip -AllowAuthorityCreation (-not [bool]$tlsRequested)}else{$null}
            $script:mobileTls=[bool]$tlsRequested;$script:mobilePrepared=[bool]$prepared
            $script:mobileListener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse($endpoint.ip),$port)
            $script:mobileListener.Start()
            $script:mobileBinding=$endpoint;$script:mobilePort=$port
            $scheme=if($script:mobileTls){'https'}else{'http'}
            ([ordered]@{url="${scheme}://$($endpoint.ip):$port/m/$($script:mobileToken)/";ip=$endpoint.ip;port=$port;https=$script:mobileTls;certificateReady=[bool]$script:mobileIdentity;fingerprint=if($script:mobileIdentity){$script:mobileIdentity.Fingerprint}else{''};certificateName=if($script:mobileIdentity){$script:mobileIdentity.Name}else{''};updatedAt=(Get-Date).ToString('o')}|ConvertTo-Json -Compress)|Set-Content -LiteralPath $mobileEndpointFile -Encoding UTF8
            Remove-Item -LiteralPath (Join-Path $StateDirectory 'mobile-error.json') -ErrorAction SilentlyContinue
            "$(Get-Date -Format o) Mobile LAN listening on $($endpoint.ip):$port"|Add-Content -LiteralPath $logFile -Encoding UTF8
        }catch{
            if($script:mobileListener){$script:mobileListener.Stop()}
            $script:mobileListener=$null
            @{message=$_.Exception.Message;httpsRequested=[bool]$tlsRequested}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $StateDirectory 'mobile-error.json') -Encoding UTF8
            "$(Get-Date -Format o) Mobile LAN unavailable: $($_.Exception.Message)"|Add-Content -LiteralPath $logFile -Encoding UTF8
        }
    }
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
    "$(Get-Date -Format o) AlienGamer bridge listening on 127.0.0.1:$Port" | Set-Content -LiteralPath $logFile -Encoding UTF8
    while ($true) {
        $client = $null
        $reader = $null
        try {
            Update-MobileListener
            $isMobile=$false
            if($mobileListener -and $mobileListener.Pending()){$client=$mobileListener.AcceptTcpClient();$isMobile=$true}
            elseif($listener.Pending()){$client=$listener.AcceptTcpClient()}
            else{Start-Sleep -Milliseconds 40;continue}
            $client.ReceiveTimeout=3000
            $client.SendTimeout=3000
            $stream = $client.GetStream()
            # Reject out-of-subnet clients before the TLS handshake.
            if($isMobile -and -not(Test-SameSubnet ([Net.IPAddress]$client.Client.RemoteEndPoint.Address) ([Net.IPAddress]::Parse($mobileBinding.ip)) $mobileBinding.prefix)){continue}
            if($isMobile -and $mobileTls){
                $tlsStream=[Net.Security.SslStream]::new($stream,$false)
                $tlsStream.ReadTimeout=3000;$tlsStream.WriteTimeout=3000
                try{$tlsStream.AuthenticateAsServer($mobileIdentity.Certificate,$false,[Security.Authentication.SslProtocols]::Tls12,$false)}catch{$tlsStream.Dispose();throw}
                $stream=$tlsStream
            }
            $request=Read-AGHttpRequest $stream
            $path=$request.Path
            if($isMobile){
                $remote=[Net.IPAddress]$client.Client.RemoteEndPoint.Address
                if(-not(Test-SameSubnet $remote ([Net.IPAddress]::Parse($mobileBinding.ip)) $mobileBinding.prefix)){
                    Send-Response $stream 404 'text/plain' 'Not found';continue
                }
                $base="/m/$mobileToken/"
                if($path-eq($base+'timer')){
                    $settings=(Get-Content -LiteralPath $configFile -Raw -Encoding UTF8|ConvertFrom-Json).mobileView
                    $result=Invoke-AGTimerRequest $request $mobileTls ("https://$($mobileBinding.ip):$mobilePort") $settings $StateDirectory
                    Send-Response $stream $result.Code 'application/json' ($result.Body|ConvertTo-Json -Compress)
                    continue
                }
                if($request.Method-ne'GET'){Send-Response $stream 404 'text/plain' 'Not found';continue}
                if($path -eq ($base+'certificate') -and $mobileIdentity){
                    $payload=[IO.File]::ReadAllBytes($mobileIdentity.PublicPath)
                    $headers=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: application/pkix-cert`r`nContent-Disposition: attachment; filename=AlienGamerMode-Local-CA.cer`r`nCache-Control: no-store`r`nReferrer-Policy: no-referrer`r`nX-Content-Type-Options: nosniff`r`nContent-Length: $($payload.Length)`r`nConnection: close`r`n`r`n")
                    $stream.Write($headers,0,$headers.Length);$stream.Write($payload,0,$payload.Length);$stream.Flush()
                }elseif($path-in@(($base+'examples/https-secure.jpg'),($base+'examples/https-untrusted.jpg'))){
                    $example=if($path-eq($base+'examples/https-secure.jpg')){'https-secure.jpg'}else{'https-untrusted.jpg'}
                    $payload=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot ('mobile\help\'+$example)))
                    $headers=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: image/jpeg`r`nCache-Control: no-store`r`nReferrer-Policy: no-referrer`r`nX-Content-Type-Options: nosniff`r`nContent-Length: $($payload.Length)`r`nConnection: close`r`n`r`n")
                    $stream.Write($headers,0,$headers.Length);$stream.Write($payload,0,$payload.Length);$stream.Flush()
                }elseif($path -cin @((1..4|ForEach-Object {$base+'sounds/timer-'+$_+'.mp3'}))){
                    # Exact allowlist: never expose arbitrary local files or uploads.
                    $filename=$path.Substring(($base+'sounds/').Length)
                    $payload=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot ('mobile\sounds\'+$filename)))
                    $headers=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: audio/mpeg`r`nCache-Control: private, max-age=3600`r`nReferrer-Policy: no-referrer`r`nX-Content-Type-Options: nosniff`r`nContent-Length: $($payload.Length)`r`nConnection: close`r`n`r`n")
                    $stream.Write($headers,0,$headers.Length);$stream.Write($payload,0,$payload.Length);$stream.Flush()
                }elseif($path -eq ($base+'setup/') -and $mobileIdentity){
                    Send-Response $stream 200 'text/html' (Get-AGMobileSetupHtml -Fingerprint $mobileIdentity.Fingerprint -Name $mobileIdentity.Name -SecureUrl ("https://$($mobileBinding.ip):$mobilePort$base"))
                }elseif($path -eq $base){
                    $html=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'mobile\index.html') -Raw -Encoding UTF8
                    Send-Response $stream 200 'text/html' $html
                }elseif($path -eq ($base+'status')){
                    $status=Get-AlienGamerStatus
                    try{
                        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
                        $memory=[Microsoft.VisualBasic.Devices.ComputerInfo]::new()
                        $status.ramUsedMB=[Math]::Round(($memory.TotalPhysicalMemory-$memory.AvailablePhysicalMemory)/1MB,1)
                        $status.ramTotalMB=[Math]::Round($memory.TotalPhysicalMemory/1MB,1)
                    }catch{$status.ramUsedMB=-1;$status.ramTotalMB=-1}
                    $status.modules=@($mobileModules)
                    $status.timer=Invoke-AGSharedTimer -Directory $StateDirectory
                    $alarm=Get-AGTimerAlarmSettings $StateDirectory
                    # No local paths or hardware device IDs leave the PC.
                    $status.timerAlarm=@{output=$alarm.output;revision=$alarm.revision}
                    $settings=(Get-Content -LiteralPath $configFile -Raw -Encoding UTF8|ConvertFrom-Json).mobileView
                    $status.timerControl=[bool]($mobileTls-and$settings.allowTimerControl-eq$true-and'timer'-in@($settings.modules))
                    Send-Response $stream 200 'application/json' ($status|ConvertTo-Json -Depth 6 -Compress)
                }else{Send-Response $stream 404 'text/plain' 'Not found'}
                continue
            }
            try {
                $status = Get-AlienGamerStatus
                switch ($path) {
                    '/v2/status' { Send-Response $stream 200 'application/json' ($status | ConvertTo-Json -Depth 6 -Compress) }
                    '/health' { Send-Response $stream 200 'application/json' (([ordered]@{ok=$true; port=$Port; coreCount=@($status.cores).Count; timestamp=$status.timestamp}) | ConvertTo-Json -Compress) }
                    default { Send-Response $stream 200 'text/plain' (ConvertTo-Pipe $status) }
                }
            } catch {
                "$(Get-Date -Format o) $($_.Exception.Message)" | Add-Content -LiteralPath $logFile -Encoding UTF8
                try { Send-Response $stream 503 'application/json' (([ordered]@{ok=$false; error=$_.Exception.Message}) | ConvertTo-Json -Compress) }
                catch { "$(Get-Date -Format o) Cliente desconectado antes de recibir la respuesta." | Add-Content -LiteralPath $logFile -Encoding UTF8 }
            }
        } catch {
            # Rainmeter puede cancelar una solicitud durante !Refresh. Esa
            # desconexión pertenece sólo al cliente y nunca debe cerrar el puente.
            "$(Get-Date -Format o) Solicitud interrumpida: $($_.Exception.Message)" | Add-Content -LiteralPath $logFile -Encoding UTF8
        } finally {
            if ($reader) { $reader.Dispose() }
            if ($stream) { $stream.Dispose();$stream=$null }
            if ($client) { $client.Dispose() }
        }
    }
} finally {
    $listener.Stop()
    if($mobileListener){$mobileListener.Stop()}
    Remove-Item -LiteralPath $mobileEndpointFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
