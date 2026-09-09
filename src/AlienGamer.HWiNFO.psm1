Set-StrictMode -Version Latest

function ConvertFrom-HWiNFOText {
    param([byte[]]$Bytes)
    $end = [Array]::IndexOf($Bytes, [byte]0)
    if ($end -lt 0) { $end = $Bytes.Length }
    if ($end -eq 0) { return '' }
    return [Text.Encoding]::UTF8.GetString($Bytes, 0, $end).Trim()
}

function Get-HWiNFOInventory {
    [CmdletBinding()]
    param()

    $map = $null
    $view = $null
    $mutex = $null
    $locked = $false
    try {
        try {
            $mutex = [Threading.Mutex]::OpenExisting('Global\HWiNFO_SM2_MUTEX')
            $locked = $mutex.WaitOne(750)
        } catch { }

        $map = [IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting(
            'Global\HWiNFO_SENS_SM2',
            [IO.MemoryMappedFiles.MemoryMappedFileRights]::Read
        )
        $view = $map.CreateViewAccessor(0, 0, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
        $header = New-Object byte[] 48
        [void]$view.ReadArray(0, $header, 0, $header.Length)
        if ([BitConverter]::ToUInt32($header, 0) -ne 0x53695748) {
            throw 'La memoria compartida no contiene una firma HWiNFO valida.'
        }

        $sensorOffset = [BitConverter]::ToUInt32($header, 20)
        $sensorSize = [BitConverter]::ToUInt32($header, 24)
        $sensorCount = [BitConverter]::ToUInt32($header, 28)
        $readingOffset = [BitConverter]::ToUInt32($header, 32)
        $readingSize = [BitConverter]::ToUInt32($header, 36)
        $readingCount = [BitConverter]::ToUInt32($header, 40)
        if ($sensorSize -lt 264 -or $readingSize -lt 316) {
            throw "Formato HWiNFO no reconocido (sensor=$sensorSize, lectura=$readingSize)."
        }

        $sensors = @()
        for ($i = 0; $i -lt $sensorCount; $i++) {
            $buffer = New-Object byte[] $sensorSize
            [void]$view.ReadArray([long]($sensorOffset + $i * $sensorSize), $buffer, 0, $sensorSize)
            $nameBytes = New-Object byte[] 128
            $userBytes = New-Object byte[] 128
            [Array]::Copy($buffer, 8, $nameBytes, 0, 128)
            [Array]::Copy($buffer, 136, $userBytes, 0, 128)
            $sensors += [pscustomobject]@{
                Index = $i
                SensorId = [BitConverter]::ToUInt32($buffer, 0)
                Instance = [BitConverter]::ToUInt32($buffer, 4)
                Name = ConvertFrom-HWiNFOText $nameBytes
                UserName = ConvertFrom-HWiNFOText $userBytes
            }
        }

        $items = New-Object 'System.Collections.Generic.List[object]'
        for ($i = 0; $i -lt $readingCount; $i++) {
            $buffer = New-Object byte[] $readingSize
            [void]$view.ReadArray([long]($readingOffset + $i * $readingSize), $buffer, 0, $readingSize)
            $sensorIndex = [BitConverter]::ToUInt32($buffer, 4)
            if ($sensorIndex -ge $sensors.Count) { continue }
            $labelBytes = New-Object byte[] 128
            $userLabelBytes = New-Object byte[] 128
            $unitBytes = New-Object byte[] 16
            [Array]::Copy($buffer, 12, $labelBytes, 0, 128)
            [Array]::Copy($buffer, 140, $userLabelBytes, 0, 128)
            [Array]::Copy($buffer, 268, $unitBytes, 0, 16)
            $sensor = $sensors[$sensorIndex]
            $items.Add([pscustomobject]@{
                Key = ('{0:x8}:{1:x8}:{2:x8}' -f $sensor.SensorId, $sensor.Instance, [BitConverter]::ToUInt32($buffer, 8))
                Type = [BitConverter]::ToUInt32($buffer, 0)
                SensorId = $sensor.SensorId
                Instance = $sensor.Instance
                EntryId = [BitConverter]::ToUInt32($buffer, 8)
                Sensor = $sensor.Name
                SensorUser = $sensor.UserName
                Label = ConvertFrom-HWiNFOText $labelBytes
                LabelUser = ConvertFrom-HWiNFOText $userLabelBytes
                Unit = ConvertFrom-HWiNFOText $unitBytes
                Value = [BitConverter]::ToDouble($buffer, 284)
                Minimum = [BitConverter]::ToDouble($buffer, 292)
                Maximum = [BitConverter]::ToDouble($buffer, 300)
                Average = [BitConverter]::ToDouble($buffer, 308)
            })
        }
        return $items.ToArray()
    } finally {
        if ($view) { $view.Dispose() }
        if ($map) { $map.Dispose() }
        if ($locked -and $mutex) { $mutex.ReleaseMutex() }
        if ($mutex) { $mutex.Dispose() }
    }
}

function Find-HWiNFOReading {
    param(
        [object[]]$Inventory,
        [string[]]$Labels,
        [string[]]$SensorPatterns = @(),
        [string[]]$Units = @(),
        [string]$PreferredDevice = ''
    )
    $normalizedLabels = $Labels | ForEach-Object { $_.ToLowerInvariant() }
    $candidates = $Inventory | Where-Object {
        $label = ("$($_.Label) $($_.LabelUser)").ToLowerInvariant()
        $labelMatch = @($normalizedLabels | Where-Object { $label -like "*$_*" }).Count -gt 0
        $unitMatch = $Units.Count -eq 0 -or $Units -contains $_.Unit
        $sensorText = ("$($_.Sensor) $($_.SensorUser)").ToLowerInvariant()
        $sensorMatch = $SensorPatterns.Count -eq 0 -or @($SensorPatterns | Where-Object { $sensorText -like "*$($_.ToLowerInvariant())*" }).Count -gt 0
        $labelMatch -and $unitMatch -and $sensorMatch
    }
    if (-not $candidates) { return $null }
    if ($PreferredDevice) {
        $preferred = $candidates | Where-Object { ("$($_.Sensor) $($_.SensorUser)") -like "*$PreferredDevice*" } | Select-Object -First 1
        if ($preferred) { return $preferred }
    }
    return $candidates | Select-Object -First 1
}

Export-ModuleMember -Function Get-HWiNFOInventory, Find-HWiNFOReading
