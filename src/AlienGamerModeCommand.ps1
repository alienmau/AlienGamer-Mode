param([switch]$Activate,[switch]$Stop)

$rainmeter = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
$dataRoot = Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
$stopRequestPath = Join-Path $dataRoot 'stop-monitor.request.json'

if (-not (Test-Path -LiteralPath $dataRoot)) {
    New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
}

if ($Stop) {
    # Canal fiable entre Rainmeter y el agente aunque los procesos tengan
    # niveles de integridad distintos. El evento queda como vía rápida.
    $pendingRequestPath = "$stopRequestPath.tmp.$PID"
    [ordered]@{
        requestedAtUtc = [DateTime]::UtcNow.ToString('o')
        source = 'RainmeterSkin'
        processId = $PID
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $pendingRequestPath -Encoding UTF8
    Move-Item -LiteralPath $pendingRequestPath -Destination $stopRequestPath -Force
}

$eventName = if ($Stop) { 'Local\AlienGamerMode.Stop' } else { 'Local\AlienGamerMode.Activate' }
try {
    $event = [Threading.EventWaitHandle]::OpenExisting($eventName)
    [void]$event.Set()
    $event.Dispose()
} catch {
    if ($Stop) {
        # El agente puede estar elevado y negar acceso al evento con nombre.
        # En ese caso recogerá la solicitud escrita en disco.
    } else {
        $launcher = Join-Path $PSScriptRoot 'AlienGamerModeLauncher.vbs'
        Start-Process "$env:SystemRoot\System32\wscript.exe" -WindowStyle Hidden -ArgumentList "//B //NoLogo `"$launcher`" agent-activate"
    }
}

if ($Stop) {
    # El agente confirma el cierre eliminando la solicitud después de detener
    # grabación, puente, HWiNFO y Rainmeter en el orden habitual.
    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    while ((Test-Path -LiteralPath $stopRequestPath) -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 100
    }

    # Si el agente se cerró junto con su antigua consola, ejecuta la misma
    # limpieza de forma determinista en vez de dejar procesos o consolas vivos.
    if (Test-Path -LiteralPath $stopRequestPath) {
        $fallback = Join-Path $PSScriptRoot 'Stop-AlienGamerMode.ps1'
        if (Test-Path -LiteralPath $fallback) {
            & $fallback -Quiet
        }
        elseif (Test-Path -LiteralPath $rainmeter) {
            & $rainmeter '!DeactivateConfig' 'AlienGamerMode'
            Remove-Item -LiteralPath $stopRequestPath -Force -ErrorAction SilentlyContinue
        }
    }
}
