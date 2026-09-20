param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$DiscoveryPath,
    [switch]$HideConsole
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if($HideConsole){
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class AlienGamerEditorWindow {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
    $consoleHandle=[AlienGamerEditorWindow]::GetConsoleWindow()
    if($consoleHandle-ne[IntPtr]::Zero){[void][AlienGamerEditorWindow]::ShowWindow($consoleHandle,0)}
}
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.MultiDisplay.psm1') -Force

$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
$discovery=Get-Content -LiteralPath $DiscoveryPath -Raw|ConvertFrom-Json
$views=New-Object 'System.Collections.Generic.List[object]'
foreach($view in @(Get-AGDisplayViews -Config $config)){$views.Add($view)}
$moduleDefinitions=Get-AGModuleDefinitions
$moduleOrder=@('header','clock','controls','ram','vram','system','temperatures','performance','processors')
$english=[string]$config.language -eq 'en-US'
$names=if($english){@{header='Header';clock='Clock';controls='Controls';ram='RAM';vram='VRAM';system='CPU / GPU usage';temperatures='Temperatures';performance='FPS and alerts';processors='Processors / load'}}else{@{header='Encabezado';clock='Reloj';controls='Controles';ram='RAM';vram='VRAM';system='Uso CPU / GPU';temperatures='Temperaturas';performance='FPS y alertas';processors='Procesadores / carga'}}

foreach($monitor in @($discovery.monitors)){
    $found=@($views|Where-Object {($_.monitorId -and $_.monitorId -eq $monitor.pnpDeviceId)-or($_.monitorDeviceName -eq $monitor.deviceName)})[0]
    if(-not $found){
        $id=ConvertTo-AGSafeViewId $(if($monitor.pnpDeviceId){[string]$monitor.pnpDeviceId}else{[string]$monitor.deviceName})
        $preset=if([int]$monitor.height -gt [int]$monitor.width){'essential-vertical'}else{'essential-horizontal'}
        $found=New-AGDisplayView -Id $id -Name ([string]$monitor.friendlyName) -MonitorId ([string]$monitor.pnpDeviceId) -MonitorDeviceName ([string]$monitor.deviceName) -Preset $preset -Enabled $false
        $views.Add($found)
    }
}

$form=New-Object Windows.Forms.Form
$form.Text=if($english){'AlienGamer Mode - Displays and layout'}else{'AlienGamer Mode - Pantallas y distribución'}
$form.StartPosition='CenterScreen';$form.Size=New-Object Drawing.Size(1080,760);$form.MinimumSize=New-Object Drawing.Size(940,680);$form.TopMost=$true
$monitorList=New-Object Windows.Forms.ListBox;$monitorList.SetBounds(18,48,245,560);$form.Controls.Add($monitorList)
$monitorLabel=New-Object Windows.Forms.Label;$monitorLabel.Text=if($english){'Connected displays'}else{'Pantallas conectadas'};$monitorLabel.SetBounds(18,20,245,24);$form.Controls.Add($monitorLabel)
$canvas=New-Object Windows.Forms.Panel;$canvas.SetBounds(280,95,610,515);$canvas.BackColor=[Drawing.Color]::FromArgb(8,12,18);$canvas.BorderStyle='FixedSingle';$form.Controls.Add($canvas)
$canvasLabel=New-Object Windows.Forms.Label;$canvasLabel.Text=if($english){'Drag the blocks to customize this display'}else{'Arrastra los bloques para personalizar esta pantalla'};$canvasLabel.SetBounds(280,20,610,25);$form.Controls.Add($canvasLabel)
$hint=New-Object Windows.Forms.Label;$hint.Text=if($english){'Positions snap to a 12-unit grid. Hidden blocks keep their last position.'}else{'Las posiciones se ajustan a una cuadrícula de 12 unidades. Los bloques ocultos conservan su posición.'};$hint.ForeColor=[Drawing.Color]::DimGray;$hint.SetBounds(280,48,610,40);$form.Controls.Add($hint)

$enabled=New-Object Windows.Forms.CheckBox;$enabled.Text=if($english){'Enable this display'}else{'Activar esta pantalla'};$enabled.SetBounds(910,20,150,25);$form.Controls.Add($enabled)
$presetLabel=New-Object Windows.Forms.Label;$presetLabel.Text=if($english){'Layout preset'}else{'Diseño predefinido'};$presetLabel.SetBounds(910,60,150,20);$form.Controls.Add($presetLabel)
$preset=New-Object Windows.Forms.ComboBox;$preset.DropDownStyle='DropDownList';$preset.SetBounds(910,82,145,28);[void]$preset.Items.AddRange(@('full-horizontal','essential-horizontal','essential-vertical','performance-only','temperatures-only','custom'));$form.Controls.Add($preset)
$background=New-Object Windows.Forms.CheckBox;$background.Text=if($english){'Dynamic background'}else{'Fondo dinámico'};$background.SetBounds(910,128,150,25);$form.Controls.Add($background)
$backgroundMode=New-Object Windows.Forms.ComboBox;$backgroundMode.DropDownStyle='DropDownList';$backgroundMode.SetBounds(910,156,145,28);[void]$backgroundMode.Items.AddRange(@('manual','thermal'));$form.Controls.Add($backgroundMode)
$modulesLabel=New-Object Windows.Forms.Label;$modulesLabel.Text=if($english){'Visible modules'}else{'Módulos visibles'};$modulesLabel.SetBounds(910,205,150,20);$form.Controls.Add($modulesLabel)
$modules=New-Object Windows.Forms.CheckedListBox;$modules.CheckOnClick=$true;$modules.SetBounds(910,228,145,250);foreach($name in $moduleOrder){[void]$modules.Items.Add($names[$name])};$form.Controls.Add($modules)
$reset=New-Object Windows.Forms.Button;$reset.Text=if($english){'Apply preset'}else{'Aplicar diseño'};$reset.SetBounds(910,492,145,32);$form.Controls.Add($reset)
$save=New-Object Windows.Forms.Button;$save.Text=if($english){'Save and apply'}else{'Guardar y aplicar'};$save.DialogResult='OK';$save.SetBounds(850,660,125,36);$form.Controls.Add($save)
$cancel=New-Object Windows.Forms.Button;$cancel.Text=if($english){'Cancel'}else{'Cancelar'};$cancel.DialogResult='Cancel';$cancel.SetBounds(985,660,75,36);$form.Controls.Add($cancel);$form.AcceptButton=$save;$form.CancelButton=$cancel

$script:currentView=$null;$script:updating=$false;$script:dragControl=$null;$script:dragOrigin=$null;$script:controlOrigin=$null
function Get-CurrentMonitorView {
    if($monitorList.SelectedIndex -lt 0){return $null}
    $monitor=@($discovery.monitors)[$monitorList.SelectedIndex]
    @($views|Where-Object {($_.monitorId -and $_.monitorId -eq $monitor.pnpDeviceId)-or($_.monitorDeviceName -eq $monitor.deviceName)})[0]
}
function Draw-View {
    $script:updating=$true
    try{
        $canvas.Controls.Clear();$view=$script:currentView;if(-not $view){return}
        $cw=[double]$view.canvas.width;$ch=[double]$view.canvas.height
        $availableW=[Math]::Max(1,$canvas.ClientSize.Width-16);$availableH=[Math]::Max(1,$canvas.ClientSize.Height-16)
        $factor=[Math]::Min($availableW/$cw,$availableH/$ch);$ox=[int](($canvas.ClientSize.Width-$cw*$factor)/2);$oy=[int](($canvas.ClientSize.Height-$ch*$factor)/2)
        $canvas.Tag=[pscustomobject]@{factor=$factor;offsetX=$ox;offsetY=$oy}
        foreach($name in $moduleOrder){
            $module=$view.modules.PSObject.Properties[$name].Value;if(-not $module){continue}
            $definition=$moduleDefinitions[$name]
            $box=New-Object Windows.Forms.Label;$box.Text=$names[$name];$box.TextAlign='MiddleCenter';$box.Tag=$name
            $box.BackColor=if([bool]$module.visible){[Drawing.Color]::FromArgb(185,20,85,105)}else{[Drawing.Color]::FromArgb(90,60,65,72)}
            $box.ForeColor=if([bool]$module.visible){[Drawing.Color]::White}else{[Drawing.Color]::DarkGray};$box.BorderStyle='FixedSingle';$box.Cursor='SizeAll'
            $x=$ox+[int]([double]$module.x*$factor);$y=$oy+[int]([double]$module.y*$factor);$w=[Math]::Max(36,[int]([double]$definition.width*$factor));$h=[Math]::Max(24,[int]([double]$definition.height*$factor));$box.SetBounds($x,$y,$w,$h)
            $box.Add_MouseDown({param($sender,$e)if($e.Button-eq'Left'){$script:dragControl=$sender;$script:dragOrigin=$e.Location;$script:controlOrigin=$sender.Location}})
            $box.Add_MouseMove({param($sender,$e)if($script:dragControl-eq$sender -and $e.Button-eq'Left'){$sender.Left=$script:controlOrigin.X+$e.X-$script:dragOrigin.X;$sender.Top=$script:controlOrigin.Y+$e.Y-$script:dragOrigin.Y}})
            $box.Add_MouseUp({param($sender,$e)if($script:dragControl-eq$sender){$name=[string]$sender.Tag;$module=$script:currentView.modules.PSObject.Properties[$name].Value;$geometry=$canvas.Tag;$rawX=($sender.Left-[double]$geometry.offsetX)/[double]$geometry.factor;$rawY=($sender.Top-[double]$geometry.offsetY)/[double]$geometry.factor;$module.x=[int]([Math]::Round($rawX/12)*12);$module.y=[int]([Math]::Round($rawY/12)*12);$script:currentView.layoutPreset='custom';$preset.SelectedItem='custom';$script:dragControl=$null;Draw-View}})
            $canvas.Controls.Add($box)
        }
    }finally{$script:updating=$false}
}
function Load-View {
    $script:currentView=Get-CurrentMonitorView;if(-not $script:currentView){return}
    $script:updating=$true
    $enabled.Checked=[bool]$script:currentView.enabled;$background.Checked=[bool]$script:currentView.background.enabled;$backgroundMode.SelectedItem=[string]$script:currentView.background.mode;$preset.SelectedItem=[string]$script:currentView.layoutPreset;if($preset.SelectedIndex-lt 0){$preset.SelectedItem='custom'}
    for($i=0;$i-lt $moduleOrder.Count;$i++){$module=$script:currentView.modules.PSObject.Properties[$moduleOrder[$i]].Value;$modules.SetItemChecked($i,[bool]$module.visible)}
    $script:updating=$false;Draw-View
}
foreach($monitor in @($discovery.monitors)){[void]$monitorList.Items.Add("$($monitor.friendlyName) · $($monitor.width)x$($monitor.height)" )}
$monitorList.Add_SelectedIndexChanged({Load-View})
$enabled.Add_CheckedChanged({if(-not $script:updating -and $script:currentView){$script:currentView.enabled=$enabled.Checked}})
$background.Add_CheckedChanged({if(-not $script:updating -and $script:currentView){$script:currentView.background.enabled=$background.Checked}})
$backgroundMode.Add_SelectedIndexChanged({if(-not $script:updating -and $script:currentView){$script:currentView.background.mode=[string]$backgroundMode.SelectedItem}})
$modules.Add_ItemCheck({param($sender,$e)if(-not $script:updating -and $script:currentView){$module=$script:currentView.modules.PSObject.Properties[$moduleOrder[$e.Index]].Value;$module.visible=$e.NewValue-eq[Windows.Forms.CheckState]::Checked;$form.BeginInvoke([Action]{Draw-View})|Out-Null}})
$reset.Add_Click({if($script:currentView -and [string]$preset.SelectedItem-ne'custom'){Set-AGLayoutPreset -View $script:currentView -Preset ([string]$preset.SelectedItem)|Out-Null;Load-View}})
$form.Add_ResizeEnd({if($script:currentView){Draw-View}})
if($monitorList.Items.Count){$monitorList.SelectedIndex=0}

if($form.ShowDialog()-eq'OK'){
    if(-not @($views|Where-Object enabled).Count){[Windows.Forms.MessageBox]::Show($(if($english){'Enable at least one display.'}else{'Activa al menos una pantalla.'}),'AlienGamer Mode','OK','Warning')|Out-Null;exit 2}
    if($config.PSObject.Properties['displayViews']){$config.displayViews=$views.ToArray()}else{$config|Add-Member NoteProperty displayViews $views.ToArray()}
    $config.schemaVersion=3
    $config|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    exit 0
}
exit 1
