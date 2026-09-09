param([switch]$Activate,[switch]$Stop)

$rainmeter = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
if ($Stop -and (Test-Path -LiteralPath $rainmeter)) {
    # Respuesta visual inmediata: no depende de que el agente procese el evento.
    & $rainmeter '!DeactivateConfig' 'AlienGamerMode'
}

$eventName = if ($Stop) { 'Local\AlienGamerMode.Stop' } else { 'Local\AlienGamerMode.Activate' }
try {
    $event = [Threading.EventWaitHandle]::OpenExisting($eventName)
    [void]$event.Set()
    $event.Dispose()
} catch {
    if ($Stop) {
        # La skin ya fue desactivada arriba. Sin agente no hay más ciclo que cerrar.
    } else {
        $agent = Join-Path $PSScriptRoot 'AlienGamerModeAgent.ps1'
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$agent`" -Activate"
    }
}
