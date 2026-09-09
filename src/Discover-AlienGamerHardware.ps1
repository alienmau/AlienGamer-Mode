param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\build\discovery.json'),
    [switch]$AllowMissingHWiNFO
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.HWiNFO.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms

# Rainmeter usa las coordenadas efectivas de Windows en monitores con escalado
# distinto. Forzar DPI por monitor aquí entregaba píxeles físicos (por ejemplo,
# 2560x1600) y Rainmeter aplicaba después el 150 %, ampliando la skin dos veces.
# Screen.AllScreens sin ese cambio devuelve el espacio exacto que Rainmeter usa.

if (-not ('AlienGamer.NativeCpuSets' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace AlienGamer {
  public sealed class CpuSetInfo {
    public int LogicalIndex { get; set; }
    public int CoreIndex { get; set; }
    public int EfficiencyClass { get; set; }
  }
  public static class NativeCpuSets {
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool GetSystemCpuSetInformation(IntPtr buffer, uint length, out uint returned, IntPtr process, uint flags);
    public static CpuSetInfo[] Read() {
      uint needed;
      GetSystemCpuSetInformation(IntPtr.Zero, 0, out needed, IntPtr.Zero, 0);
      if (needed == 0) return new CpuSetInfo[0];
      IntPtr p = Marshal.AllocHGlobal((int)needed);
      try {
        if (!GetSystemCpuSetInformation(p, needed, out needed, IntPtr.Zero, 0)) return new CpuSetInfo[0];
        var result = new List<CpuSetInfo>();
        int offset = 0;
        while (offset + 24 <= needed) {
          IntPtr item = IntPtr.Add(p, offset);
          int size = Marshal.ReadInt32(item, 0);
          int type = Marshal.ReadInt32(item, 4);
          if (size <= 0) break;
          if (type == 0) result.Add(new CpuSetInfo {
            LogicalIndex = Marshal.ReadByte(item, 14),
            CoreIndex = Marshal.ReadByte(item, 15),
            EfficiencyClass = Marshal.ReadByte(item, 18)
          });
          offset += size;
        }
        return result.ToArray();
      } finally { Marshal.FreeHGlobal(p); }
    }
  }
}
'@
}

$screens = @([Windows.Forms.Screen]::AllScreens | ForEach-Object {
    [pscustomobject]@{
        deviceName = $_.DeviceName
        primary = $_.Primary
        x = $_.Bounds.X
        y = $_.Bounds.Y
        width = $_.Bounds.Width
        height = $_.Bounds.Height
        workingX = $_.WorkingArea.X
        workingY = $_.WorkingArea.Y
        workingWidth = $_.WorkingArea.Width
        workingHeight = $_.WorkingArea.Height
    }
})

$computer = Get-CimInstance Win32_ComputerSystem | Select-Object -First 1
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuSets = @([AlienGamer.NativeCpuSets]::Read() | Sort-Object LogicalIndex)
$efficiencyClasses = @($cpuSets | Select-Object -ExpandProperty EfficiencyClass -Unique | Sort-Object)
$highestEfficiencyClass = if ($efficiencyClasses.Count) { ($efficiencyClasses | Measure-Object -Maximum).Maximum } else { 0 }
$cpuTopology = @($cpuSets | ForEach-Object {
    [pscustomobject]@{
        logicalIndex = $_.LogicalIndex
        physicalCoreIndex = $_.CoreIndex
        efficiencyClass = $_.EfficiencyClass
        type = if ($efficiencyClasses.Count -le 1) { 'generic' } elseif ($_.EfficiencyClass -eq $highestEfficiencyClass) { 'performance' } else { 'efficiency' }
    }
})
$gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
    [pscustomobject]@{
        name = $_.Name
        pnpDeviceId = $_.PNPDeviceID
        adapterRamBytes = [uint64]$_.AdapterRAM
        driverVersion = $_.DriverVersion
        status = $_.Status
        discreteScore = if ($_.Name -match 'NVIDIA|Radeon RX|Arc') { 100 } elseif ($_.Name -match 'Intel|Integrated') { 10 } else { 50 }
    }
} | Sort-Object discreteScore -Descending)

$physicalDisks = @()
try {
    $physicalDisks = @(Get-PhysicalDisk | ForEach-Object {
        [pscustomobject]@{
            friendlyName = $_.FriendlyName
            mediaType = [string]$_.MediaType
            busType = [string]$_.BusType
            sizeBytes = [uint64]$_.Size
            healthStatus = [string]$_.HealthStatus
        }
    })
} catch {
    $physicalDisks = @(Get-CimInstance Win32_DiskDrive | ForEach-Object {
        [pscustomobject]@{
            friendlyName = $_.Model
            mediaType = if ($_.MediaType -match 'SSD') { 'SSD' } else { 'Unspecified' }
            busType = $_.InterfaceType
            sizeBytes = [uint64]$_.Size
            healthStatus = $_.Status
        }
    })
}

$inventory = @()
$hwinfoError = $null
try { $inventory = @(Get-HWiNFOInventory) } catch {
    $hwinfoError = $_.Exception.Message
    if (-not $AllowMissingHWiNFO) { throw }
}

$payload = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    computer = [ordered]@{
        manufacturer = $computer.Manufacturer
        model = $computer.Model
        name = $env:COMPUTERNAME
    }
    cpu = [ordered]@{
        name = $cpu.Name.Trim()
        manufacturer = $cpu.Manufacturer
        physicalCores = [int]$cpu.NumberOfCores
        logicalProcessors = [int]$cpu.NumberOfLogicalProcessors
        maxClockMHz = [int]$cpu.MaxClockSpeed
        topology = $cpuTopology
    }
    gpus = $gpus
    storage = $physicalDisks
    monitors = $screens
    prerequisites = [ordered]@{
        rainmeterPath = @("$env:ProgramFiles\Rainmeter\Rainmeter.exe", "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        hwinfoPath = @("$env:ProgramFiles\HWiNFO64\HWiNFO64.exe", "$env:ProgramFiles\HWiNFO64\HWiNFO64A.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
        hwinfoSharedMemoryAvailable = $inventory.Count -gt 0
        hwinfoError = $hwinfoError
    }
    hwinfoInventory = $inventory
}

$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$payload
