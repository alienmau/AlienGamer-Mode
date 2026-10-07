# Shared desktop theme: Estudio, orange accent. No external dependencies.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
if(-not ('AlienGamer.Desktop.Theme' -as [type])){
    Add-Type -Path (Join-Path $PSScriptRoot 'native\AlienGamerTheme.cs') -ReferencedAssemblies System.Windows.Forms,System.Drawing
}
function Set-AGWindowTheme([Windows.Forms.Control]$Control){[AlienGamer.Desktop.Theme]::Apply($Control)}
function Set-AGPrimaryButton([Windows.Forms.Button]$Button){[AlienGamer.Desktop.Theme]::Primary($Button)}
function Set-AGMenuTheme([Windows.Forms.ContextMenuStrip]$Menu){[AlienGamer.Desktop.Theme]::Menu($Menu)}
function Show-AGMessage {
    param([string]$Text,[string]$Title='AlienGamer Mode',[Windows.Forms.MessageBoxButtons]$Buttons='OK',[Windows.Forms.MessageBoxIcon]$Icon='Information',[Windows.Forms.IWin32Window]$Owner=$null,[switch]$English)
    [AlienGamer.Desktop.Theme]::Message($Owner,$Text,$Title,$Buttons,$Icon,$English.IsPresent)
}
function Show-AGColorPicker([Windows.Forms.IWin32Window]$Owner,[Drawing.Color]$Color,[switch]$English){[AlienGamer.Desktop.Theme]::ChooseColor($Owner,$Color,$English.IsPresent)}
Export-ModuleMember -Function Set-AGWindowTheme,Set-AGPrimaryButton,Set-AGMenuTheme,Show-AGMessage,Show-AGColorPicker
