param([Parameter(Mandatory)][string]$RainmeterConfig)

$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
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
$statePath=Join-Path $dataRoot "session-timer-$safeId.txt"
$duration=1800
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
$form.ClientSize=New-Object Drawing.Size(330,228)
$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.MinimizeBox=$false
$form.StartPosition='CenterScreen';$form.TopMost=$true
$form.BackColor=[Drawing.Color]::FromArgb(17,23,32)
$form.ForeColor=[Drawing.Color]::White
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$intro=New-Object Windows.Forms.Label
$intro.Text=if($english){'Set a duration, then press Play on the monitor.'}else{'Define la duración y pulsa Iniciar en el monitor.'}
$intro.SetBounds(17,15,305,23);$form.Controls.Add($intro)
$labels=if($english){@('Hours','Minutes','Seconds')}else{@('Horas','Minutos','Segundos')}
$values=@([int][Math]::Floor($duration/3600),([int][Math]::Floor($duration/60)%60),($duration%60))
$boxes=@()
for($i=0;$i-lt3;$i++){
    $x=18+$i*106
    $label=New-Object Windows.Forms.Label;$label.Text=$labels[$i];$label.SetBounds($x,52,95,21);$form.Controls.Add($label)
    $box=New-Object Windows.Forms.NumericUpDown;$box.Minimum=0;$box.Maximum=if($i-eq0){99}else{59};$box.Value=$values[$i]
    $box.SetBounds($x,77,95,28);$form.Controls.Add($box);$boxes+=,$box
}
$extraLabel=New-Object Windows.Forms.Label
$extraLabel.Text=if($english){'Extra minutes per press (3 maximum)'}else{'Minutos extra por pulsación (máximo 3)'}
$extraLabel.SetBounds(18,122,265,23);$form.Controls.Add($extraLabel)
$extraBox=New-Object Windows.Forms.NumericUpDown;$extraBox.Minimum=1;$extraBox.Maximum=30;$extraBox.Value=$extraStep
$extraBox.SetBounds(18,150,95,28);$form.Controls.Add($extraBox)
$save=New-Object Windows.Forms.Button;$save.Text=if($english){'Save'}else{'Guardar'};$save.SetBounds(133,185,88,30);$form.Controls.Add($save)
$cancel=New-Object Windows.Forms.Button;$cancel.Text=if($english){'Cancel'}else{'Cancelar'};$cancel.SetBounds(230,185,88,30);$form.Controls.Add($cancel)
$cancel.Add_Click({$form.Close()})
$save.Add_Click({
    $seconds=[int]$boxes[0].Value*3600+[int]$boxes[1].Value*60+[int]$boxes[2].Value
    if($seconds-lt60){
        $minimumMessage=if($english){'Choose at least one minute.'}else{'Elige al menos un minuto.'}
        [Windows.Forms.MessageBox]::Show($form,$minimumMessage,'AlienGamer Mode','OK','Information')|Out-Null
        return
    }
    $increment=[int]$extraBox.Value
    if($seconds+3*$increment*60-gt359999){
        $limitMessage=if($english){'Reduce the duration to leave room for the three extra increments.'}else{'Reduce la duración para permitir los tres incrementos extra.'}
        [Windows.Forms.MessageBox]::Show($form,$limitMessage,'AlienGamer Mode','OK','Information')|Out-Null
        return
    }
    $content="baseDuration=$seconds`nextraStep=$increment`nextraCount=0`nduration=$seconds`nremaining=$seconds`ndeadline=0`nstatus=idle`nconfigured=1`n"
    $tempPath="$statePath.$PID.tmp"
    [IO.File]::WriteAllText($tempPath,$content,(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tempPath -Destination $statePath -Force
    $form.Close()
})
[void]$form.ShowDialog()
$form.Dispose()
