param([Parameter(Mandatory)][string]$RainmeterConfig)

$ErrorActionPreference='Stop'
$script:timerAppRoot=$PSScriptRoot
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.UI.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.SharedTimer.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.TimerAlarm.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.Process.psm1') -Force
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class AlienGamerTimerConsole {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr handle, int command);
}
"@
$consoleHandle=[AlienGamerTimerConsole]::GetConsoleWindow()
if($consoleHandle-ne[IntPtr]::Zero){[void][AlienGamerTimerConsole]::ShowWindow($consoleHandle,0)}
$dataRoot=Join-Path $env:LOCALAPPDATA 'AlienGamerMode'
if(-not(Test-Path -LiteralPath $dataRoot)){New-Item -ItemType Directory -Path $dataRoot -Force|Out-Null}
$safeId=$RainmeterConfig -replace '[^A-Za-z0-9_-]','-'
$statePath=Join-Path $dataRoot 'session-timer-shared.txt'
$shared=Invoke-AGSharedTimer -Directory $dataRoot
$alarm=Get-AGTimerAlarmSettings $dataRoot
$script:alarmCustomFile=''
$duration=0
$extraStep=5
if(Test-Path -LiteralPath $statePath){
    $raw=Get-Content -LiteralPath $statePath -Raw
    if($raw -match '(?m)^duration=(\d+)$'){$duration=[Math]::Max(60,[Math]::Min(359999,[int]$Matches[1]))}
    if($raw -match '(?m)^baseDuration=(\d+)$'){$duration=[Math]::Max(60,[Math]::Min(359999,[int]$Matches[1]))}
    if($raw -match '(?m)^extraStep=(\d+)$'){$extraStep=[Math]::Max(1,[Math]::Min(30,[int]$Matches[1]))}
}
$configPath=Join-Path $dataRoot 'AlienGamerMode.json'
$english=$false
try{$english=((Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json).language -eq 'en-US')}catch{}
$form=New-Object Windows.Forms.Form
$form.Text=if($english){'Session timer'}else{'Temporizador de sesión'}
$form.ClientSize=New-Object Drawing.Size(470,570)
$form.AutoScroll=$true
$form.AutoScaleMode='Dpi'
$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.MinimizeBox=$false
$form.StartPosition='CenterScreen';$form.TopMost=$true
$form.BackColor=[Drawing.Color]::FromArgb(17,23,32)
$form.ForeColor=[Drawing.Color]::White
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$intro=New-Object Windows.Forms.Label
$intro.Text=if($english){'Set your session time and choose where the alarm plays.'}else{'Define tu tiempo y elige dónde escuchar la alarma.'}
$intro.SetBounds(24,18,342,44);$form.Controls.Add($intro)
$labels=if($english){@('Hours','Minutes','Seconds')}else{@('Horas','Minutos','Segundos')}
$values=@([int][Math]::Floor($duration/3600),([int][Math]::Floor($duration/60)%60),($duration%60))
$boxes=@()
for($i=0;$i-lt3;$i++){
    $x=24+$i*118
    $label=New-Object Windows.Forms.Label;$label.Text=$labels[$i];$label.SetBounds($x,76,104,24);$form.Controls.Add($label)
    $box=New-Object Windows.Forms.NumericUpDown;$box.Minimum=0;$box.Maximum=if($i-eq0){99}else{59};$box.Value=$values[$i]
    $box.SetBounds($x,104,104,32);$form.Controls.Add($box);$boxes+=,$box
}
$extraLabel=New-Object Windows.Forms.Label
$extraLabel.Text=if($english){'Extra minutes per press (3 maximum)'}else{'Minutos extra por pulsación (máximo 3)'}
$extraLabel.SetBounds(24,150,342,24);$form.Controls.Add($extraLabel)
$extraBox=New-Object Windows.Forms.NumericUpDown;$extraBox.Minimum=1;$extraBox.Maximum=30;$extraBox.Value=$extraStep
$extraBox.SetBounds(24,178,104,32);$form.Controls.Add($extraBox)
$outputLabel=New-Object Windows.Forms.Label;$outputLabel.Text=if($english){'Play alarm on'}else{'Reproducir alarma en'};$outputLabel.SetBounds(24,222,410,24);$form.Controls.Add($outputLabel)
$outputBox=New-Object Windows.Forms.ComboBox;$outputBox.DropDownStyle='DropDownList';$outputBox.SetBounds(24,250,410,32)
$outputNames=if($english){@('Mobile only','PC only','Both: PC and mobile')}else{@('Sólo móvil','Sólo PC','Ambos: PC y móvil')}
$outputBox.Items.AddRange([object[]]$outputNames);$outputBox.SelectedIndex=@('mobile','pc','both').IndexOf([string]$alarm.output);$form.Controls.Add($outputBox)
$soundLabel=New-Object Windows.Forms.Label;$soundLabel.Text=if($english){'PC alarm sound'}else{'Sonido de alarma en PC'};$soundLabel.SetBounds(24,292,410,24);$form.Controls.Add($soundLabel)
$soundBox=New-Object Windows.Forms.ComboBox;$soundBox.DropDownStyle='DropDownList';$soundBox.SetBounds(24,320,280,32)
$soundNames=if($english){@('Sound 1','Sound 2','Sound 3','Sound 4 · default','My MP3 file')}else{@('Sonido 1','Sonido 2','Sonido 3','Sonido 4 · predeterminado','Mi archivo MP3')}
$soundBox.Items.AddRange([object[]]$soundNames);$soundBox.SelectedIndex=@('timer-1','timer-2','timer-3','timer-4','custom').IndexOf([string]$alarm.sound);$form.Controls.Add($soundBox)
$browse=New-Object AlienGamer.Desktop.RoundedButton;$browse.Text=if($english){'Choose MP3'}else{'Elegir MP3'};$browse.SetBounds(314,320,120,36);$form.Controls.Add($browse)
$advanced=New-Object Windows.Forms.CheckBox;$advanced.Text=if($english){'Advanced: choose PC audio output'}else{'Avanzado: elegir salida de audio de PC'};$advanced.SetBounds(24,366,410,28);$form.Controls.Add($advanced)
$deviceBox=New-Object Windows.Forms.ComboBox;$deviceBox.DropDownStyle='DropDownList';$deviceBox.DisplayMember='name';$deviceBox.SetBounds(24,402,410,32);$form.Controls.Add($deviceBox)
$defaultName=if($english){'Follow Windows audio output · recommended'}else{'Seguir la salida de Windows · recomendado'}
[void]$deviceBox.Items.Add([pscustomobject]@{id='';name=$defaultName})
try{foreach($device in @(Get-AGAudioDevices)){[void]$deviceBox.Items.Add($device)}}catch{}
$deviceBox.SelectedIndex=0
for($i=1;$i-lt$deviceBox.Items.Count;$i++){if($deviceBox.Items[$i].id-ceq$alarm.deviceId){$deviceBox.SelectedIndex=$i}}
if($alarm.deviceId-and$deviceBox.SelectedIndex-eq0){[void]$deviceBox.Items.Add([pscustomobject]@{id=$alarm.deviceId;name=$(if($english){'Saved device disconnected · Windows fallback'}else{'Salida guardada desconectada · se usará Windows'})});$deviceBox.SelectedIndex=$deviceBox.Items.Count-1}
$advanced.Checked=[bool]$alarm.deviceId
$note=New-Object Windows.Forms.Label;$note.SetBounds(24,448,410,42);$form.Controls.Add($note)
$preview=New-Object AlienGamer.Desktop.RoundedButton;$preview.Text=if($english){'Test PC sound'}else{'Probar en PC'};$preview.SetBounds(24,506,130,40);$form.Controls.Add($preview)
$save=New-Object AlienGamer.Desktop.RoundedButton;$save.Text=if($english){'Save'}else{'Guardar'};$save.SetBounds(322,506,112,40);$form.Controls.Add($save)
$cancel=New-Object AlienGamer.Desktop.RoundedButton;$cancel.Text=if($english){'Cancel'}else{'Cancelar'};$cancel.SetBounds(202,506,112,40);$form.Controls.Add($cancel)
$script:alarmPreviewDirectory=$null
$script:alarmPreviewProcess=$null
$script:alarmPreviewTimer=New-Object Windows.Forms.Timer
$script:alarmPreviewTimer.Interval=200
function Reset-AlarmPreviewButton {
    $preview.Text=if($english){'Test PC sound'}else{'Probar en PC'}
    $script:alarmPreviewTimer.Stop()
}
function Stop-AlarmPreview {
    $process=$script:alarmPreviewProcess
    try{
        if($process-and-not$process.HasExited){
            # Signal only this dialog's preview; never stop the real alarm.
            [IO.File]::WriteAllText((Join-Path $script:alarmPreviewDirectory 'preview-stop.signal'),'stop')
            if(-not$process.WaitForExit(1000)){$process.Kill();[void]$process.WaitForExit(1000)}
        }
    }finally{
        if($process){$process.Dispose()}
        $script:alarmPreviewProcess=$null;Reset-AlarmPreviewButton
    }
}
$script:alarmPreviewTimer.Add_Tick({
    if($script:alarmPreviewProcess-and$script:alarmPreviewProcess.HasExited){Stop-AlarmPreview}
})
function Update-AlarmControls {
    $pc=$outputBox.SelectedIndex-ne0
    if(-not$pc){Stop-AlarmPreview}
    $soundBox.Enabled=$pc;$browse.Enabled=$pc-and$soundBox.SelectedIndex-eq4;$advanced.Enabled=$pc;$deviceBox.Visible=$pc-and$advanced.Checked;$preview.Enabled=$pc
    $note.Text=if(-not$pc){if($english){'Choose and test the mobile sound on the web page.'}else{'Elige y prueba el sonido del móvil desde la página web.'}}elseif($advanced.Checked){if($english){'Disconnected output: falls back to Windows. Volume is not changed.'}else{'Si se desconecta, se usa Windows. No se cambia el volumen.'}}else{if($english){'Uses the Windows output selected when the alarm starts.'}else{'Usa la salida seleccionada en Windows cuando suene la alarma.'}}
}
function Save-AlarmSelection([string]$Directory,[long]$Revision=-1){
    $params=@{Directory=$Directory;Output=@('mobile','pc','both')[$outputBox.SelectedIndex];Sound=@('timer-1','timer-2','timer-3','timer-4','custom')[$soundBox.SelectedIndex];DeviceId=$(if($advanced.Checked){[string]$deviceBox.SelectedItem.id}else{''});Revision=$Revision}
    if($script:alarmCustomFile){$params.CustomFile=$script:alarmCustomFile}
    Set-AGTimerAlarmSettings @params
}
$browse.Add_Click({
    $picker=New-Object Windows.Forms.OpenFileDialog;$picker.Filter='MP3 (*.mp3)|*.mp3';$picker.CheckFileExists=$true
    try{if($picker.ShowDialog($form)-eq'OK'){$file=Get-Item -LiteralPath $picker.FileName;if($file.Length-le0-or$file.Length-gt10MB){throw 'MP3: máximo 10 MB / maximum 10 MB'};$script:alarmCustomFile=$file.FullName;$note.Text=$file.Name}}catch{Show-AGMessage -Owner $form -Text $_.Exception.Message -English:$english|Out-Null}finally{$picker.Dispose()}
})
$outputBox.Add_SelectedIndexChanged({Stop-AlarmPreview;Update-AlarmControls});$soundBox.Add_SelectedIndexChanged({Stop-AlarmPreview;Update-AlarmControls});$advanced.Add_CheckedChanged({Stop-AlarmPreview;Update-AlarmControls})
$deviceBox.Add_SelectedIndexChanged({Stop-AlarmPreview})
$preview.Add_Click({
    if($script:alarmPreviewProcess-and-not$script:alarmPreviewProcess.HasExited){Stop-AlarmPreview;return}
    Stop-AlarmPreview
    try{
        # Preview has its own settings; Cancel never changes saved preferences.
        $script:alarmPreviewDirectory=Join-Path $dataRoot ('AlarmPreview-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $script:alarmPreviewDirectory|Out-Null
        if($soundBox.SelectedIndex-eq4-and-not$script:alarmCustomFile){$saved=Join-Path $dataRoot 'timer-alarm-custom.mp3';if(Test-Path -LiteralPath $saved){Copy-Item -LiteralPath $saved -Destination (Join-Path $script:alarmPreviewDirectory 'timer-alarm-custom.mp3') -Force}}
        Save-AlarmSelection $script:alarmPreviewDirectory|Out-Null
        $script:alarmPreviewProcess=Start-AGHiddenProcess powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $script:timerAppRoot 'Play-TimerAlarm.ps1')+'" -Directory "'+$script:alarmPreviewDirectory+'" -Preview') -PassThru
        $preview.Text=if($english){'Stop'}else{'Detener'};$script:alarmPreviewTimer.Start()
    }catch{Show-AGMessage -Owner $form -Text $_.Exception.Message -English:$english|Out-Null}
})
$form.AcceptButton=$save;$form.CancelButton=$cancel
Set-AGWindowTheme $form;Set-AGPrimaryButton $save
# Keep actions visible while settings can scroll on small/high-DPI screens.
$body=New-Object Windows.Forms.Panel;$body.Dock='Fill';$body.AutoScroll=$true;$body.AutoScrollMinSize=New-Object Drawing.Size(0,498);$body.BackColor=if([Windows.Forms.SystemInformation]::HighContrast){[Drawing.SystemColors]::Window}else{[AlienGamer.Desktop.Theme]::Window}
$footer=New-Object Windows.Forms.Panel;$footer.Dock='Bottom';$footer.Height=64;$footer.BackColor=if([Windows.Forms.SystemInformation]::HighContrast){[Drawing.SystemColors]::Control}else{[AlienGamer.Desktop.Theme]::Surface}
foreach($control in @($form.Controls)){if($control-notin@($save,$cancel,$preview)){$body.Controls.Add($control)}}
foreach($button in @($save,$cancel,$preview)){$button.Top=12;$footer.Controls.Add($button)}
$form.Controls.Add($body);$form.Controls.Add($footer);$form.MaximumSize=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Size
Update-AlarmControls
$cancel.Add_Click({$form.Close()})
$form.Add_FormClosing({Stop-AlarmPreview})
$save.Add_Click({
    Stop-AlarmPreview
    $seconds=[int]$boxes[0].Value*3600+[int]$boxes[1].Value*60+[int]$boxes[2].Value
    $increment=[int]$extraBox.Value
    $timeChanged=$seconds-ne$shared.baseDuration-or$increment-ne$shared.extraStep
    if($timeChanged-and$seconds-lt60){
        $minimumMessage=if($english){'Choose at least one minute.'}else{'Elige al menos un minuto.'}
        Show-AGMessage -Owner $form -Text $minimumMessage -English:$english | Out-Null
        return
    }
    if($seconds+3*$increment*60-gt359999){
        $limitMessage=if($english){'Reduce the duration to leave room for the three extra increments.'}else{'Reduce la duración para permitir los tres incrementos extra.'}
        Show-AGMessage -Owner $form -Text $limitMessage -English:$english | Out-Null
        return
    }
    if($timeChanged-and$shared.status-in@('running','paused')){
        $warning=if($english){'Saving a different duration will replace the countdown on all screens. Continue?'}else{'Cambiar la duración reemplazará la cuenta en todas las pantallas. ¿Continuar?'}
        if((Show-AGMessage -Owner $form -Text $warning -Buttons YesNo -English:$english)-ne'Yes'){return}
    }
    try{
        Save-AlarmSelection $dataRoot $alarm.revision|Out-Null
        if($timeChanged){Invoke-AGSharedTimer -Directory $dataRoot -Action configure -Seconds $seconds -ExtraStep $increment -Revision $shared.revision|Out-Null}
    }
    catch{Show-AGMessage -Owner $form -Text $_.Exception.Message -English:$english|Out-Null;$shared=Invoke-AGSharedTimer -Directory $dataRoot;$alarm=Get-AGTimerAlarmSettings $dataRoot;return}
    $form.Close()
})
try{[void]$form.ShowDialog()}finally{Stop-AlarmPreview;$script:alarmPreviewTimer.Dispose();$form.Dispose()}
