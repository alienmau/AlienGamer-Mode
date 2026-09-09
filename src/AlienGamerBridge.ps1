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
    $inventory = @(Get-HWiNFOInventory)
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
        source = 'HWiNFO Shared Memory'
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
    $headers = "HTTP/1.1 $Code $reason`r`nContent-Type: $ContentType; charset=utf-8`r`nCache-Control: no-store, no-cache`r`nContent-Length: $($payload.Length)`r`nConnection: close`r`n`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    $Stream.Write($payload, 0, $payload.Length)
    $Stream.Flush()
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
    "$(Get-Date -Format o) AlienGamer bridge listening on 127.0.0.1:$Port" | Set-Content -LiteralPath $logFile -Encoding UTF8
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 2048, $true)
            $requestLine = $reader.ReadLine()
            while (($line = $reader.ReadLine()) -ne $null -and $line.Length -gt 0) { }
            $path = if ($requestLine -match '^GET\s+([^\s]+)') { $Matches[1].Split('?')[0] } else { '/' }
            try {
                $status = Get-AlienGamerStatus
                switch ($path) {
                    '/v2/status' { Send-Response $stream 200 'application/json' ($status | ConvertTo-Json -Depth 6 -Compress) }
                    '/health' { Send-Response $stream 200 'application/json' (([ordered]@{ok=$true; port=$Port; coreCount=@($status.cores).Count; timestamp=$status.timestamp}) | ConvertTo-Json -Compress) }
                    default { Send-Response $stream 200 'text/plain' (ConvertTo-Pipe $status) }
                }
            } catch {
                "$(Get-Date -Format o) $($_.Exception.Message)" | Add-Content -LiteralPath $logFile -Encoding UTF8
                Send-Response $stream 503 'application/json' (([ordered]@{ok=$false; error=$_.Exception.Message}) | ConvertTo-Json -Compress)
            }
            $reader.Dispose()
        } finally { $client.Dispose() }
    }
} finally {
    $listener.Stop()
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
