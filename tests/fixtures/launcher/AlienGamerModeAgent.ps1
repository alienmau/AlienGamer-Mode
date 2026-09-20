$resultPath = $env:AGM_LAUNCHER_TEST_RESULT
if (-not $resultPath) { exit 2 }
$process = Get-Process -Id $PID
[ordered]@{
    processId = $PID
    mainWindowHandle = [int64]$process.MainWindowHandle
    windowStyle = 'hidden'
} | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
Start-Sleep -Seconds 2
