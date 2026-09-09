$ErrorActionPreference = 'Stop'

$hwinfoPath = Join-Path $env:ProgramFiles 'HWiNFO64\HWiNFO64.exe'
$dataRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
$logPath = Join-Path $dataRoot 'hwinfo-task.log'
$stopSignal = Join-Path $dataRoot 'stop-hwinfo.signal'
if (-not (Test-Path -LiteralPath $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null }

function Write-TaskLog([string]$Message) {
    "$(Get-Date -Format o) $Message" | Add-Content -LiteralPath $logPath -Encoding UTF8
}

# HWiNFO requiere elevacion. Este script se ejecuta dentro de la tarea
# programada elevada y permanece activo mientras HWiNFO esta abierto.
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-TaskLog "Inicio. Usuario=$($currentIdentity.Name); Elevado=$isAdmin; HWiNFO=$hwinfoPath"
    if (-not (Test-Path -LiteralPath $hwinfoPath)) { throw "No se encontro HWiNFO64 en: $hwinfoPath" }
    Remove-Item -LiteralPath $stopSignal -Force -ErrorAction SilentlyContinue
    $process = Start-Process -FilePath $hwinfoPath -WindowStyle Minimized -PassThru
    Write-TaskLog "HWiNFO iniciado. PID=$($process.Id)"
    while (-not $process.HasExited) {
        if (Test-Path -LiteralPath $stopSignal) {
            Write-TaskLog 'Solicitud de cierre recibida.'
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $stopSignal -Force -ErrorAction SilentlyContinue
            break
        }
        Start-Sleep -Milliseconds 300
        $process.Refresh()
    }
    $process.WaitForExit()
    Write-TaskLog "HWiNFO termino. Codigo=$($process.ExitCode)"
    exit $process.ExitCode
} catch {
    Write-TaskLog "ERROR: $($_.Exception.ToString())"
    exit 1
}
