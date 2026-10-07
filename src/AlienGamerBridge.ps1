param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\build\AlienGamerMode.profile.json'),
    [int]$Port = 0,
    [string]$StateDirectory = (Join-Path $env:LOCALAPPDATA 'AlienGamerMode')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.HWiNFO.psm1') -Force
$culture = [Globalization.CultureInfo]::InvariantCulture
if (-not (Test-Path $ProfilePath)) { throw "No existe el perfil resuelto: $ProfilePath" }
$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
if ($Port -le 0) { $Port = [int]$profile.bridgePort }
if (-not (Test-Path $StateDirectory)) { New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null }
$pidFile = Join-Path $StateDirectory 'bridge.pid'
$logFile = Join-Path $StateDirectory 'bridge.log'
$configFile = Join-Path $StateDirectory 'AlienGamerMode.json'
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
    $reason = if ($Code -eq 200) { 'OK' } elseif ($Code -eq 503) { 'Service Unavailable' } else { 'Not Found' }
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
$mobileTimerView='principal'
$mobileCheck=[DateTime]::MinValue
function Update-MobileListener {
    if(((Get-Date)-$script:mobileCheck).TotalSeconds -lt 3){return}
    $script:mobileCheck=Get-Date
    $settings=$null
    try{$settings=(Get-Content -LiteralPath $configFile -Raw -Encoding UTF8|ConvertFrom-Json).mobileView}catch{}
    $enabled=$settings -and [bool]$settings.enabled -and [string]$settings.token -match '^[a-fA-F0-9]{32,64}$'
    $port=if($settings){[int]$settings.port}else{0}
    if($port -lt 1024 -or $port -gt 65535){$enabled=$false}
    $endpoint=if($enabled){Get-MobileEndpoint}else{$null}
    $changed=($script:mobileListener -and (-not $endpoint -or $script:mobileBinding.ip -ne $endpoint.ip -or $script:mobilePort -ne $port -or $script:mobileToken -ne [string]$settings.token))
    if($changed){$script:mobileListener.Stop();$script:mobileListener=$null;Remove-Item -LiteralPath $mobileEndpointFile -Force -ErrorAction SilentlyContinue}
    if(-not $endpoint){Remove-Item -LiteralPath $mobileEndpointFile -Force -ErrorAction SilentlyContinue;return}
    $script:mobileToken=[string]$settings.token
    $script:mobileModules=@($settings.modules)
    try{
        $active=@((Get-Content -LiteralPath $configFile -Raw -Encoding UTF8|ConvertFrom-Json).displayViews|Where-Object enabled|Select-Object -First 1)
        if($active.Count){$script:mobileTimerView=[string]$active[0].id}
    }catch{}
    if(-not $script:mobileListener){
        try{
            $script:mobileListener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse($endpoint.ip),$port)
            $script:mobileListener.Start()
            $script:mobileBinding=$endpoint;$script:mobilePort=$port
            ([ordered]@{url="http://$($endpoint.ip):$port/m/$($script:mobileToken)/";ip=$endpoint.ip;port=$port;updatedAt=(Get-Date).ToString('o')}|ConvertTo-Json -Compress)|Set-Content -LiteralPath $mobileEndpointFile -Encoding UTF8
            "$(Get-Date -Format o) Mobile LAN listening on $($endpoint.ip):$port"|Add-Content -LiteralPath $logFile -Encoding UTF8
        }catch{
            $script:mobileListener=$null
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
            $stream = $client.GetStream()
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 2048, $true)
            $requestLine = $reader.ReadLine()
            $headerLength=0
            while (($line = $reader.ReadLine()) -ne $null -and $line.Length -gt 0) { $headerLength+=$line.Length;if($headerLength -gt 8192){throw 'Cabeceras HTTP demasiado grandes.'} }
            $path = if ($requestLine -match '^GET\s+([^\s]+)') { $Matches[1].Split('?')[0] } else { '/' }
            if($isMobile){
                $remote=[Net.IPAddress]$client.Client.RemoteEndPoint.Address
                if(-not(Test-SameSubnet $remote ([Net.IPAddress]::Parse($mobileBinding.ip)) $mobileBinding.prefix)){
                    Send-Response $stream 404 'text/plain' 'Not found';continue
                }
                $base="/m/$mobileToken/"
                if($path -eq $base){
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
                    $timerPath=Join-Path $StateDirectory ('session-timer-'+($mobileTimerView -replace '[^A-Za-z0-9_-]','-')+'.txt')
                    $timer=@{}
                    if(Test-Path -LiteralPath $timerPath){
                        foreach($line in @(Get-Content -LiteralPath $timerPath -ErrorAction SilentlyContinue)){
                            if($line -match '^([A-Za-z]+)=(.*)$'){$timer[$Matches[1]]=$Matches[2]}
                        }
                    }
                    $remaining=if($timer.status -eq 'running' -and [long]$timer.deadline -gt 0){[Math]::Max(0,[long]$timer.deadline-[DateTimeOffset]::UtcNow.ToUnixTimeSeconds())}elseif($timer.remaining){[long]$timer.remaining}else{0}
                    $status.timer=[ordered]@{remaining=$remaining;configured=($timer.configured -eq '1');status=if($timer.status){[string]$timer.status}else{'idle'}}
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
            if ($client) { $client.Dispose() }
        }
    }
} finally {
    $listener.Stop()
    if($mobileListener){$mobileListener.Stop()}
    Remove-Item -LiteralPath $mobileEndpointFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
