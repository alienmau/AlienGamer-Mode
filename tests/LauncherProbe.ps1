param([switch]$Activate,[switch]$OpenLayoutEditor)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LauncherProbe { [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); }
'@
@{consoleHandle=[LauncherProbe]::GetConsoleWindow().ToInt64();pid=$PID}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'console.json') -Encoding UTF8
