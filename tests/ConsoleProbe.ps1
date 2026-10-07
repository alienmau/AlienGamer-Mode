param([Parameter(Mandatory)][string]$OutputPath,[switch]$Fail,[switch]$Gui)
$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ConsoleProbe {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
}
'@
$visible=$false
if($Gui){Add-Type -AssemblyName System.Windows.Forms;$form=New-Object Windows.Forms.Form;$form.Show();[Windows.Forms.Application]::DoEvents();$visible=[ConsoleProbe]::IsWindowVisible($form.Handle);$form.Close();$form.Dispose()}
@{consoleHandle=[ConsoleProbe]::GetConsoleWindow().ToInt64();pid=$PID;guiVisible=$visible}|ConvertTo-Json|Set-Content -LiteralPath $OutputPath -Encoding UTF8
if($Fail){[Console]::Error.WriteLine('EXPECTED probe error');exit 7}
