$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$script:timerAppRoot=Join-Path $root 'src'
Import-Module (Join-Path $root 'src\AlienGamer.UI.psm1') -Force
Import-Module (Join-Path $root 'src\AlienGamer.TimerAlarm.psm1') -Force
Import-Module (Join-Path $root 'src\AlienGamer.SharedTimer.psm1') -Force
$source=[IO.File]::ReadAllText((Join-Path $root 'src\Configure-SessionTimer.ps1'))
$start=$source.IndexOf('$form=New-Object Windows.Forms.Form')
$end=$source.IndexOf('try{[void]$form.ShowDialog()', $start)
Add-Type -TypeDefinition @'
public class AlarmPreviewFixture {
    public bool HasExited;
    public bool Disposed;
    public bool WaitForExit(int milliseconds) { HasExited=true;return true; }
    public void Kill() { HasExited=true; }
    public void Dispose() { Disposed=true; }
}
'@
function Start-AGHiddenProcess {param($FilePath,$ArgumentList,[switch]$PassThru) return New-Object AlarmPreviewFixture}
function Show-AGMessage {param($Owner,$Text,$English,$Buttons) throw ('Unexpected dialog: '+$Text)}
$output=Join-Path $root 'build\tests\timer-alarm-ui'
New-Item -ItemType Directory -Path $output -Force|Out-Null
foreach($english in @($false,$true)){
    $dataRoot=Join-Path $output ([guid]::NewGuid().ToString('N'))
    $duration=300;$extraStep=5;$alarm=Get-AGTimerAlarmSettings $dataRoot
    $shared=Invoke-AGSharedTimer $dataRoot configure -Seconds 300 -ExtraStep 5
    $shared=Invoke-AGSharedTimer $dataRoot start -Revision $shared.revision
    $original=$shared;$script:alarmCustomFile=''
    Invoke-Expression $source.Substring($start,$end-$start)
    try{
        $form.StartPosition='Manual';$form.Location=New-Object Drawing.Point(-12000,-12000);$form.Show();[Windows.Forms.Application]::DoEvents()
        if($preview.Enabled-or$soundBox.Enabled-or$deviceBox.Visible){throw 'PC controls not disabled for mobile-only.'}
        $outputBox.SelectedIndex=2;$advanced.Checked=$true;[Windows.Forms.Application]::DoEvents()
        if(-not$preview.Enabled-or-not$deviceBox.Visible-or$deviceBox.Items.Count-lt1){throw 'Both/advanced controls missing.'}
        $soundBox.SelectedIndex=4;if(-not$browse.Enabled){throw 'Custom file button unavailable.'}
        $soundBox.SelectedIndex=3
        foreach($scale in @(1,1.5,2)){
            if($scale-ne1){$form.Scale([Drawing.SizeF]::new([single]($scale/$previousScale),[single]($scale/$previousScale)))}
            $previousScale=$scale;[Windows.Forms.Application]::DoEvents()
            foreach($button in @($save,$cancel,$preview)){if($button.Right-gt$footer.ClientSize.Width-or$button.Bottom-gt$footer.ClientSize.Height){throw "Actions clipped at $scale"}}
            if($scale-eq1){$bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height);try{$form.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$form.Width,$form.Height));$bitmap.Save((Join-Path $output ("alarm-$english.png")))}finally{$bitmap.Dispose()}}
        }
        $preview.PerformClick();$first=$script:alarmPreviewProcess
        if($preview.Text-notin@('Detener','Stop')){throw 'Preview did not become Stop.'}
        $preview.PerformClick()
        if(-not$first.HasExited-or-not$first.Disposed-or$script:alarmPreviewProcess){throw 'Preview stop did not release its own process.'}
        if(-not(Test-Path -LiteralPath (Join-Path $script:alarmPreviewDirectory 'preview-stop.signal'))){throw 'Graceful preview stop missing.'}
        $preview.PerformClick();$natural=$script:alarmPreviewProcess;$natural.HasExited=$true
        Start-Sleep -Milliseconds 250;[Windows.Forms.Application]::DoEvents()
        if($preview.Text-notin@('Probar en PC','Test PC sound')-or-not$natural.Disposed){throw 'Natural completion did not reset preview.'}
        $preview.PerformClick();$saving=$script:alarmPreviewProcess
        if($english){$cancel.PerformClick()}else{$save.PerformClick()}
        if(-not$saving.HasExited-or-not$saving.Disposed){throw 'Saving did not stop preview.'}
        $current=Invoke-AGSharedTimer $dataRoot
        if($current.revision-ne$original.revision-or$current.status-ne'running'-or$current.deadline-ne$original.deadline){throw 'Saving audio-only options reset the running timer.'}
    }finally{Stop-AlarmPreview;$script:alarmPreviewTimer.Dispose();$form.Dispose()}
}
'PASS: ES/EN timer/audio UI, mobile-only PC controls disabled, presets/custom picker, advanced output and persistent actions at 100/150/200%.'
