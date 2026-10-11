$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.UI.psm1') -Force
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1'),[ref]$tokens,[ref]$errors)
foreach($name in @('Set-Property','Show-MobileDialog')){
    $node=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    Invoke-Expression ($node.Extent.Text.Replace('$PSScriptRoot',("'"+(Join-Path $root 'src').Replace("'","''")+"'")))
}
$ConfigPath='C:\Users\alien\AppData\Local\AlienGamerMode\AlienGamerMode.json'
$script:editorConfigFile=$ConfigPath
$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
$language='es-MX'
function Write-EditorTrace($Message){}
$moduleLabels=@{ram='RAM';vram='VRAM';system='CPU/GPU';temperatures='Temperaturas';clock='Reloj';timer='Timer';processors='Procesadores'}
$form=New-Object Windows.Forms.Form
$probe=[pscustomobject]@{passed=$false;error='';ticks=0}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=900
$timer.Add_Tick({
    $dialog=@([Windows.Forms.Application]::OpenForms|Where-Object Text -like 'Monitor*red local')[0]
    if(-not $dialog){return}
    $probe.ticks++
    $url=@($dialog.Controls|Where-Object {$_ -is [Windows.Forms.TextBox]})[0]
    $qr=@($dialog.Controls|Where-Object {$_ -is [Windows.Forms.PictureBox]})[0]
    if($url.Text -and $qr.Image){$probe.passed=$true;$timer.Stop();$dialog.Close()}
    elseif($probe.ticks -gt 3){$probe.error=(@($dialog.Controls|Where-Object {$_ -is [Windows.Forms.Label]}|ForEach-Object Text)-join ' / ');$timer.Stop();$dialog.Close()}
})
function Invoke-EditorAction([scriptblock]$Action){& $Action}
try{$timer.Start();Invoke-EditorAction {Show-MobileDialog}}finally{$timer.Dispose();$form.Dispose()}
if(-not $probe.passed){throw $probe.error}
'PASS: existing enabled HTTPS endpoint displays QR without saving or toggling.'
