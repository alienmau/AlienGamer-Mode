$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.Output.psm1') -Force
$directory=Join-Path $root ('build\tests\destinations-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory|Out-Null
$monitor=[pscustomobject]@{deviceName='DISPLAY_TEST';pnpDeviceId='PHYSICAL_TEST';friendlyName='Test display'}
foreach($mode in @('desktop','mobile','both')){
    $config=Get-Content -LiteralPath (Join-Path $root 'config\AlienGamerMode.default.json') -Raw|ConvertFrom-Json
    $config.mobileView.token='a'*48
    $config.mobileView|Add-Member NoteProperty tls ([pscustomobject]@{enabled=$true;prepared=$true}) -Force
    Set-AGOutputDestination -Config $config -Mode $mode -Monitor $monitor
    $desktop=@($config.displayViews|Where-Object enabled).Count
    if(($desktop -gt 0) -ne ($mode -ne 'mobile') -or $config.mobileView.enabled -ne ($mode -ne 'desktop')){throw "Wrong outputs: $mode"}
    if($config.mobileView.token -ne ('a'*48) -or -not $config.mobileView.tls.enabled){throw 'Destination change replaced HTTPS identity.'}
    if($mode -eq 'mobile' -and $config.display.targetMonitorId -ne 'auto'){throw 'Mobile-only retained required physical screen.'}
}
$config=Get-Content -LiteralPath (Join-Path $root 'config\AlienGamerMode.default.json') -Raw|ConvertFrom-Json
Set-AGOutputDestination -Config $config -Mode mobile
if($config.mobileView.token -notmatch '^[a-f0-9]{48}$'){throw 'Fresh mobile setup did not create QR secret.'}
$path=Join-Path $directory 'configuration.json'
$config|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $path -Encoding UTF8
$backup=New-AGConfigurationBackup -ConfigPath $path
if((Get-FileHash -LiteralPath $path).Hash -ne (Get-FileHash -LiteralPath $backup).Hash){throw 'Technical configuration backup mismatch.'}
$rejected=$false;try{Set-AGOutputDestination -Config $config -Mode desktop}catch{$rejected=$true}
if(-not $rejected){throw 'Desktop setup accepted no selected display.'}
# Cancel must not open Notepad or create a backup; accepting must back up first.
Add-Type -AssemblyName System.Windows.Forms
$tokens=$null;$errors=$null
$agentAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src\AlienGamerModeAgent.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Agent parse errors.'}
$editNode=$agentAst.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Open-ConfigurationFile'},$true)
$hardwareNode=$agentAst.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Show-HardwareSettings'},$true)
if($hardwareNode.Extent.Text -match 'monitorBox|config\.display\.|config\.displayViews'){throw 'Hardware settings still select or modify displays.'}
Invoke-Expression $editNode.Extent.Text
$configPath=$path;$script:language='es-MX';$script:opened=0;$script:backups=@()
function T($Key){return $Key}
function Write-AgentLog($Message){$script:backups+=,$Message}
function Start-Process {param($FilePath,$ArgumentList) if(-not @($script:backups).Count){throw 'Notepad opened without a backup.'};$script:opened++}
function Show-AGMessage {param($Text,$Buttons,$Icon,$English) return $script:answer}
$script:answer=[Windows.Forms.DialogResult]::No
Open-ConfigurationFile
if($script:opened -or $script:backups.Count){throw 'Cancel still edited configuration.'}
$script:answer=[Windows.Forms.DialogResult]::Yes
Open-ConfigurationFile
if($script:opened -ne 1 -or $script:backups.Count -ne 1){throw 'Accepted configuration edit failed.'}
Remove-Item Function:\Start-Process
# Exercise actual installer controls without running elevation, setup or sensor tasks.
Import-Module (Join-Path $root 'src\AlienGamer.UI.psm1') -Force
Import-Module (Join-Path $root 'src\AlienGamer.Localization.psm1') -Force
$installer=[IO.File]::ReadAllText((Join-Path $root 'installer\Install-AlienGamerMode.ps1'))
$start=$installer.IndexOf('$form = New-Object Windows.Forms.Form')
$finish=$installer.IndexOf('$installButton.Add_Click(', $start)
if($start -lt 0 -or $finish -le $start){throw 'Installer UI boundary missing.'}
function Get-MajorMinorVersion($Path){return [version]'9.0'}
$rainmeterPath=Join-Path $directory 'missing-rainmeter.exe'
$hwinfoPath=$path
$iconPath=Join-Path $directory 'missing-icon.ico'
$discovery=[pscustomobject]@{monitors=@($monitor);gpus=@([pscustomobject]@{name='Test GPU'});storage=@([pscustomobject]@{friendlyName='Test SSD';busType='NVMe';sizeBytes=1GB})}
foreach($language in @('es-MX','en-US')){
    $ui=Get-AGTranslations -Language $language -LocalesRoot (Join-Path $root 'src\locales')
    function T([string]$Key){Get-AGText -Translations $ui -Path $Key}
    Invoke-Expression $installer.Substring($start,$finish-$start)
    try{
        $destinationBox.SelectedIndex=1
        if($monitorBox.Enabled -or -not $installButton.Enabled){throw 'Mobile setup still requires desktop/Rainmeter.'}
        $form.StartPosition='Manual';$form.Location=New-Object Drawing.Point(-12000,-12000)
        $form.Show();$form.PerformLayout();[Windows.Forms.Application]::DoEvents()
        $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
        try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save((Join-Path $directory ('installer-mobile-'+$language+'.png')))}finally{$bitmap.Dispose()}
        $destinationBox.SelectedIndex=2
        if(-not $monitorBox.Enabled -or $installButton.Enabled){throw 'Both mode ignored missing desktop requirement.'}
        $rainOk=$true;& $updateDestination
        if(-not $installButton.Enabled){throw 'Both mode rejected fulfilled requirements.'}
        $destinationBox.SelectedIndex=0
        if(-not $monitorBox.Enabled -or -not $installButton.Enabled){throw 'Desktop mode regressed.'}
    }finally{$form.Dispose()}
    $hardwareSource=$hardwareNode.Extent.Text
    $hardwareStart=$hardwareSource.IndexOf('$form = New-Object Windows.Forms.Form')
    $hardwareEnd=$hardwareSource.IndexOf("if(`$form.ShowDialog() -ne 'OK')",$hardwareStart)
    $gpus=@($discovery.gpus);$storage=@($discovery.storage)
    Invoke-Expression $hardwareSource.Substring($hardwareStart,$hardwareEnd-$hardwareStart)
    try{
        $form.StartPosition='Manual';$form.Location=New-Object Drawing.Point(-12000,-12000)
        $form.Show();[Windows.Forms.Application]::DoEvents()
        $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
        try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save((Join-Path $directory ('hardware-'+$language+'.png')))}finally{$bitmap.Dispose()}
    }finally{$form.Dispose()}
}
"PASS: three destinations, HTTPS identity preservation, new QR secret, backup integrity and ES/EN installer controls. Screenshots: $directory"
