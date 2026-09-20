param(
    [string]$DiscoveryPath = (Join-Path $PSScriptRoot '..\build\discovery.json'),
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\AlienGamerMode.default.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\build\AlienGamerMode.profile.json'),
    [string]$MonitorDeviceName,
    [string]$PreferredGpu,
    [string]$PreferredStorage
)

$ErrorActionPreference = 'Stop'
$discovery = Get-Content -LiteralPath $DiscoveryPath -Raw | ConvertFrom-Json
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$inventory = @($discovery.hwinfoInventory)

function Normalize([string]$Text) {
    if (-not $Text) { return '' }
    $form = $Text.Normalize([Text.NormalizationForm]::FormD)
    return (($form.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' }) -join '').ToLowerInvariant()
}

function Select-Reading {
    param([string[]]$Labels, [string[]]$Units, [string[]]$Sensors = @(), [string]$Device = '', [string]$Regex = '')
    $ranked = foreach ($r in $inventory) {
        $canonicalLabel = Normalize ([string]$r.Label)
        $userLabel = Normalize ([string]$r.LabelUser)
        $label = "$canonicalLabel $userLabel".Trim()
        $sensor = Normalize ("$($r.Sensor) $($r.SensorUser)")
        $score = 0
        foreach ($candidate in $Labels) {
            $normalizedCandidate = Normalize $candidate
            if ($canonicalLabel -eq $normalizedCandidate -or $userLabel -eq $normalizedCandidate) { $score += 300 }
            elseif ($label -like "*$normalizedCandidate*") { $score += 30 }
        }
        foreach ($candidate in $Sensors) { if ($sensor -like "*$(Normalize $candidate)*") { $score += 10 } }
        if ($Units.Count -and $Units -contains $r.Unit) { $score += 8 } elseif ($Units.Count) { $score -= 20 }
        if ($Device -and $sensor -like "*$(Normalize $Device)*") { $score += 20 }
        if ($Regex -and $label -match $Regex) { $score += 40 }
        if ($score -gt 0) { [pscustomobject]@{ score=$score; reading=$r } }
    }
    return ($ranked | Sort-Object score -Descending | Select-Object -First 1).reading
}

function To-Mapping($Reading) {
    if (-not $Reading) { return [pscustomobject]@{ available=$false; key=$null; sensor=$null; label=$null; unit=$null } }
    return [pscustomobject]@{ available=$true; key=$Reading.Key; sensor=$Reading.Sensor; label=$Reading.Label; unit=$Reading.Unit }
}

$monitorIdentity = if ($config.display.PSObject.Properties['targetMonitorId']) { [string]$config.display.targetMonitorId } else { '' }
$monitor = if ($monitorIdentity -and $monitorIdentity -ne 'auto') { $discovery.monitors | Where-Object pnpDeviceId -eq $monitorIdentity | Select-Object -First 1 } else { $null }
if (-not $monitor -and $MonitorDeviceName) { $monitor = $discovery.monitors | Where-Object deviceName -eq $MonitorDeviceName | Select-Object -First 1 }
if (-not $monitor -and $config.display.targetMonitor -ne 'auto') { $monitor = $discovery.monitors | Where-Object deviceName -eq $config.display.targetMonitor | Select-Object -First 1 }
if (-not $monitor -and $config.display.preference -eq 'secondary') { $monitor = $discovery.monitors | Where-Object { -not $_.primary } | Select-Object -First 1 }
if (-not $monitor) { $monitor = $discovery.monitors | Where-Object primary | Select-Object -First 1 }

$gpu = if ($PreferredGpu) { $discovery.gpus | Where-Object name -like "*$PreferredGpu*" | Select-Object -First 1 } else { $discovery.gpus | Sort-Object discreteScore -Descending | Select-Object -First 1 }
$storage = if ($PreferredStorage) { $discovery.storage | Where-Object friendlyName -like "*$PreferredStorage*" | Select-Object -First 1 } else { $discovery.storage | Sort-Object @{Expression={if ($_.busType -eq 'NVMe') {0} elseif ($_.mediaType -eq 'SSD') {1} else {2}}} | Select-Object -First 1 }

$gpuName = if ($gpu) { $gpu.name } else { '' }
$storageName = if ($storage) { $storage.friendlyName } else { '' }
$maps = [ordered]@{}
$maps.gpuTemperature = To-Mapping (Select-Reading @('GPU Temperature','Temperatura de la GPU') @('°C','C') @('GPU') $gpuName)
$maps.gpuUsage = To-Mapping (Select-Reading @('GPU Core Load','GPU Usage','Carga del nucleo de GPU','Uso de GPU') @('%') @('GPU') $gpuName)
$maps.cpuTemperature = To-Mapping (Select-Reading @('CPU Package','CPU (Tctl/Tdie)','CPU Die','CPU Entera') @('°C','C') @('CPU'))
$maps.cpuUsage = To-Mapping (Select-Reading @('Total CPU Usage','CPU Total','Uso total de CPU') @('%') @('CPU'))
$maps.coreMaximumTemperature = To-Mapping (Select-Reading @('Core Max','Core Maximum','Maximo de Nucleo','Maximo del nucleo') @('°C','C') @('CPU'))
$maps.storageTemperature = To-Mapping (Select-Reading @('Drive Temperature','Temperatura de la unidad','Temperature') @('°C','C') @('S.M.A.R.T.','Drive') $storageName)
$maps.vramUsed = To-Mapping (Select-Reading @('GPU Memory Allocated','GPU Memory Usage','Memoria GPU asignada') @('MB','GB') @('GPU') $gpuName)
$maps.vramFree = To-Mapping (Select-Reading @('GPU Memory Available','Memoria GPU disponible') @('MB','GB') @('GPU') $gpuName)
$maps.fps = To-Mapping (Select-Reading @('Framerate Presented (avg)','Framerate Presented (Average)','FPS promedio') @('FPS') @('PresentMon') '' '^framerate presented \((avg|average)\)$')
$maps.frameTime = To-Mapping (Select-Reading @('Frame Time Presented (avg)','Frame Time Presented (Average)','Tiempo de fotograma promedio') @('ms') @('PresentMon') '' '^frame time presented \((avg|average)\)$')
$maps.cpuThermal = To-Mapping (Select-Reading @('Package/Ring Thermal Throttling','CPU Package Thermal Throttling') @('Yes/No','Sí/No','bool') @('CPU'))
$maps.gpuThermal = To-Mapping (Select-Reading @('Performance Limit - Thermal','Thermal Performance Limit') @('Yes/No','Sí/No','bool') @('GPU') $gpuName)
$maps.cpuPower = To-Mapping (Select-Reading @('Package/Ring Power Limit Exceeded','CPU Package Power Limit Exceeded') @('Yes/No','Sí/No','bool') @('CPU'))
$maps.gpuPower = To-Mapping (Select-Reading @('Performance Limit - Power','Power Performance Limit','Limite de rendimiento - Potencia') @('Yes/No','Sí/No','bool') @('GPU') $gpuName)

if ($config.dataSource.sensorOverrides) {
    foreach ($property in $config.dataSource.sensorOverrides.PSObject.Properties) {
        if ($property.Name -eq 'cores' -or -not $property.Value) { continue }
        $overrideReading = $inventory | Where-Object Key -eq ([string]$property.Value) | Select-Object -First 1
        if ($overrideReading -and $maps.Contains($property.Name)) { $maps[$property.Name] = To-Mapping $overrideReading }
    }
}

$topology = @($discovery.cpu.topology)
$coreCandidates = @($inventory | Where-Object {
    $label = Normalize ("$($_.Label) $($_.LabelUser)")
    $_.Unit -eq '%' -and ($label -match '(core|cpu)[^0-9]*[0-9]+.*(usage|use|load|uso|carga)' -or $label -match '(usage|use|load|uso|carga).*(core|cpu)[^0-9]*[0-9]+')
})
$usedKeys = @{}
$coreMappings = New-Object 'System.Collections.Generic.List[object]'
if ($config.dataSource.sensorOverrides -and @($config.dataSource.sensorOverrides.cores).Count -gt 0) {
    foreach ($override in @($config.dataSource.sensorOverrides.cores)) {
        $match = $inventory | Where-Object Key -eq ([string]$override.key) | Select-Object -First 1
        if (-not $match) { continue }
        $type = if ($override.type) { [string]$override.type } else { 'generic' }
        $coreMappings.Add([pscustomobject]@{ displayIndex=$coreMappings.Count; logicalIndex=[int]$override.logicalIndex; type=$type; key=$match.Key; label=$match.Label; available=$true })
    }
}
if ($coreMappings.Count -eq 0) {
    for ($logical = 0; $logical -lt [int]$discovery.cpu.logicalProcessors; $logical++) {
        $patterns = @("Core $logical", "Core #$logical", "CPU $logical", "CPU #$logical", "Nucleo $logical", "Núcleo $logical")
        $match = $null
        foreach ($candidate in $coreCandidates) {
            if ($usedKeys.ContainsKey($candidate.Key)) { continue }
            $label = Normalize ("$($candidate.Label) $($candidate.LabelUser)")
            if (@($patterns | Where-Object { $label -like "*$(Normalize $_)*" }).Count) { $match = $candidate; break }
        }
        if (-not $match) { continue }
        $usedKeys[$match.Key] = $true
        $topo = $topology | Where-Object logicalIndex -eq $logical | Select-Object -First 1
        $type = if ($topo) { $topo.type } else { 'generic' }
        $coreMappings.Add([pscustomobject]@{ displayIndex=$coreMappings.Count; logicalIndex=$logical; type=$type; key=$match.Key; label=$match.Label; available=$true })
    }
}

# Validación previa a la visualización. Una asociación ambigua o incoherente se
# invalida para que el puente entregue N/D (-1), nunca un falso positivo.
$validationIssues = New-Object 'System.Collections.Generic.List[string]'
function Invalidate-Mapping([string]$Name, [string]$Reason) {
    $maps[$Name] = To-Mapping $null
    $validationIssues.Add("${Name}: $Reason")
}
function Get-MappedReading([string]$Name) {
    $mapping = $maps[$Name]
    if (-not $mapping -or -not $mapping.available) { return $null }
    return $inventory | Where-Object Key -eq ([string]$mapping.key) | Select-Object -First 1
}
function Validate-Mapping([string]$Name, [string]$LabelRegex, [string]$SensorRegex, [double]$Minimum, [double]$Maximum, [switch]$Boolean) {
    $reading = Get-MappedReading $Name
    if (-not $reading) { return }
    $canonical = Normalize ([string]$reading.Label)
    $sensorName = Normalize ([string]$reading.Sensor)
    if ($LabelRegex -and $canonical -notmatch $LabelRegex) { Invalidate-Mapping $Name "etiqueta inesperada '$($reading.Label)'"; return }
    if ($SensorRegex -and $sensorName -notmatch $SensorRegex) { Invalidate-Mapping $Name "fuente inesperada '$($reading.Sensor)'"; return }
    $value = [double]$reading.Value
    if ($Boolean -and $value -notin @(0.0,1.0)) { Invalidate-Mapping $Name "indicador no booleano '$value'"; return }
    if ($value -lt $Minimum -or $value -gt $Maximum) { Invalidate-Mapping $Name "valor fuera de rango '$value'" }
}

Validate-Mapping 'gpuTemperature' '^gpu temperature$' '(dgpu|nvidia|radeon|arc)' -20 150
Validate-Mapping 'gpuUsage' '^(gpu core load|gpu usage)$' '(dgpu|nvidia|radeon|arc)' 0 100
Validate-Mapping 'cpuTemperature' '^(cpu package|cpu \(tctl/tdie\)|cpu die|cpu entera)$' 'cpu' -20 150
Validate-Mapping 'cpuUsage' '^(total cpu usage|cpu total|uso total de cpu)$' 'cpu' 0 100
Validate-Mapping 'coreMaximumTemperature' '^(core max|core maximum|maximo de nucleo|maximo del nucleo)$' 'cpu' -20 150
Validate-Mapping 'storageTemperature' '^(drive temperature|temperatura de la unidad|temperature)$' '(s\.m\.a\.r\.t|drive)' -20 150
Validate-Mapping 'vramUsed' '^(gpu memory allocated|gpu memory usage|memoria gpu asignada)$' '(dgpu|nvidia|radeon|arc)' 0 1048576
Validate-Mapping 'vramFree' '^(gpu memory available|memoria gpu disponible)$' '(dgpu|nvidia|radeon|arc)' 0 1048576
Validate-Mapping 'fps' '^framerate presented \((avg|average)\)$' '^presentmon$' 0 2000
Validate-Mapping 'frameTime' '^frame time presented \((avg|average)\)$' '^presentmon$' 0 10000
Validate-Mapping 'cpuThermal' '^(package/ring thermal throttling|cpu package thermal throttling)$' 'cpu' 0 1 -Boolean
Validate-Mapping 'gpuThermal' '^(performance limit - thermal|thermal performance limit)$' '(dgpu|nvidia|radeon|arc)' 0 1 -Boolean
Validate-Mapping 'cpuPower' '^(package/ring power limit exceeded|cpu package power limit exceeded)$' 'cpu' 0 1 -Boolean
Validate-Mapping 'gpuPower' '^(performance limit - power|power performance limit)$' '(dgpu|nvidia|radeon|arc)' 0 1 -Boolean

$fpsReading = Get-MappedReading 'fps'
$frameReading = Get-MappedReading 'frameTime'
if ($fpsReading -and $frameReading -and [double]$fpsReading.Value -gt 0.5 -and [double]$frameReading.Value -gt 0) {
    $expectedFrameTime = 1000.0 / [double]$fpsReading.Value
    $ratio = [double]$frameReading.Value / $expectedFrameTime
    if ($ratio -lt 0.65 -or $ratio -gt 1.35) {
        Invalidate-Mapping 'fps' 'no coincide con el frame time promedio'
        Invalidate-Mapping 'frameTime' 'no coincide con el FPS promedio'
    }
}

$storageLabel = if ($storage.busType -eq 'NVMe') { 'NVME' } elseif ($storage.mediaType -eq 'SSD') { 'SSD' } elseif ($storage.mediaType -eq 'HDD') { 'HDD' } else { 'UNIDAD' }
$profile = [ordered]@{
    schemaVersion = 2
    language = if ($config.language) { [string]$config.language } else { 'es-MX' }
    generatedAt = (Get-Date).ToString('o')
    bridgePort = [int]$config.dataSource.bridgePort
    unavailableValue = [double]$config.dataSource.unavailableValue
    computer = $discovery.computer
    cpu = $discovery.cpu
    gpu = $gpu
    storage = $storage
    storageLabel = $storageLabel
    monitor = $monitor
    mappings = $maps
    cores = $coreMappings.ToArray()
    displaySummary = [ordered]@{
        detectedLogicalProcessors = [int]$discovery.cpu.logicalProcessors
        monitoredLogicalProcessors = $coreMappings.Count
        performanceLogicalProcessors = @($coreMappings | Where-Object type -eq 'performance').Count
        efficiencyLogicalProcessors = @($coreMappings | Where-Object type -eq 'efficiency').Count
        performancePhysicalCores = @($topology | Where-Object type -eq 'performance' | Select-Object -ExpandProperty physicalCoreIndex -Unique).Count
        efficiencyPhysicalCores = @($topology | Where-Object type -eq 'efficiency' | Select-Object -ExpandProperty physicalCoreIndex -Unique).Count
    }
    validation = [ordered]@{
        passed = ($validationIssues.Count -eq 0)
        checkedAt = (Get-Date).ToString('o')
        issues = $validationIssues.ToArray()
    }
    sourceConfig = $ConfigPath
    labels = $config.labels
    appearance = $config.appearance
    features = $config.features
    layout = if ($config.PSObject.Properties['activeDisplayView']) { $config.activeDisplayView } else { $null }
}

$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$profile | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$profile
