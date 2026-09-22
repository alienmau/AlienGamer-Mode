param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$DiscoveryPath,
    [switch]$HideConsole,
    [switch]$SelfTest,
    [switch]$AutoSaveTest,
    [string]$ExportScreenshotPath
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::CatchException)
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
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.Localization.psm1') -Force

$config=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
$discovery=Get-Content -LiteralPath $DiscoveryPath -Raw -Encoding UTF8|ConvertFrom-Json
$language=Resolve-AGLanguage ([string]$config.language)
$ui=Get-AGTranslations -Language $language
function T([string]$Name){Get-AGText -Translations $ui -Path ('layoutEditor.'+$Name)}
$editorErrorPath=Join-Path (Join-Path $env:LOCALAPPDATA 'AlienGamerMode') 'layout-editor.error.log'
$editorTracePath=Join-Path (Join-Path $env:LOCALAPPDATA 'AlienGamerMode') 'layout-editor.trace.log'
function Write-EditorTrace([string]$Message){
    try{
        $directory=Split-Path -Parent $editorTracePath
        if(-not(Test-Path -LiteralPath $directory)){New-Item -ItemType Directory -Path $directory -Force|Out-Null}
        $line=(Get-Date).ToString('o')+' '+$Message+"`r`n"
        [IO.File]::AppendAllText($editorTracePath,$line,(New-Object Text.UTF8Encoding($false)))
    }catch{}
}
function Write-EditorError($ErrorRecord){
    try{
        $directory=Split-Path -Parent $editorErrorPath
        if(-not(Test-Path -LiteralPath $directory)){New-Item -ItemType Directory -Path $directory -Force|Out-Null}
        $message=if($ErrorRecord-and$ErrorRecord.Exception){$ErrorRecord.Exception.ToString()}elseif($ErrorRecord){[string]$ErrorRecord}else{'Error desconocido del editor.'}
        $stack=if($ErrorRecord-and$ErrorRecord.ScriptStackTrace){[string]$ErrorRecord.ScriptStackTrace}else{''}
        $text=(Get-Date).ToString('o')+"`r`n"+$message+"`r`n"+$stack+"`r`n---`r`n"
        [IO.File]::AppendAllText($editorErrorPath,$text,(New-Object Text.UTF8Encoding($false)))
    }catch{}
}
function Set-Property($Object,[string]$Name,$Value){
    if($Object-is[Collections.IDictionary]){$Object[$Name]=$Value;return}
    if($Object.PSObject.Properties[$Name]){$Object.$Name=$Value}else{$Object|Add-Member NoteProperty $Name $Value}
}

$definitions=Get-AGModuleDefinitions
$allModuleNames=@('header','clock','controls','ram','vram','system','temperatures','performance','processors')
$selectableModuleNames=@('clock','controls','ram','vram','system','temperatures','performance','processors')
$moduleLabels=@{header=(T 'headerFixed');clock=(T 'clock');controls=(T 'controls');ram=(T 'ram');vram=(T 'vram');system=(T 'system');temperatures=(T 'temperatures');performance=(T 'performance');processors=(T 'processors')}
$views=New-Object 'System.Collections.Generic.List[object]'
foreach($view in @(Get-AGDisplayViews -Config $config)){$views.Add($view)}

function Get-Module($View,[string]$Name){
    if(-not $View -or -not $View.modules){return $null}
    $property=$View.modules.PSObject.Properties[$Name]
    if($property){return $property.Value}
    return $null
}
function Ensure-ViewGeometry($View){
    foreach($name in $allModuleNames){
        $module=Get-Module $View $name
        if(-not $module){continue}
        $definition=$definitions[$name]
        if(-not $module.PSObject.Properties['width']){Set-Property $module 'width' ([int]$definition.width)}
        if(-not $module.PSObject.Properties['height']){Set-Property $module 'height' ([int]$definition.height)}
    }
    $header=Get-Module $View 'header'
    if($header){$header.visible=$true}
    if(-not $View.background){Set-Property $View 'background' ([pscustomobject]@{})}
    $globalEffect=if($config.appearance){$config.appearance.backgroundEffect}else{$null}
    foreach($item in @(
        @('enabled',$true),@('mode','manual'),@('particleCount',26),@('speed',0.65),@('sizeScale',1.0),@('color','255,112,20')
    )){
        if(-not $View.background.PSObject.Properties[$item[0]]){
            $fallback=if($globalEffect -and $globalEffect.PSObject.Properties[$item[0]]){$globalEffect.($item[0])}else{$item[1]}
            Set-Property $View.background $item[0] $fallback
        }
    }
}
function Sync-ViewToMonitor($View,$Monitor){
    Ensure-ViewGeometry $View
    if(-not $View.canvas){Set-Property $View 'canvas' ([pscustomobject]@{width=1711;height=1023})}
    $oldWidth=[Math]::Max(1,[int]$View.canvas.width);$oldHeight=[Math]::Max(1,[int]$View.canvas.height)
    $newWidth=[Math]::Max(320,[int]$Monitor.width);$newHeight=[Math]::Max(240,[int]$Monitor.height)
    $savedPreset=[string]$View.layoutPreset
    if($savedPreset -in @('full-horizontal','essential-horizontal','essential-vertical','performance-only','temperatures-only')){
        Set-AGLayoutPreset -View $View -Preset $savedPreset -CanvasWidth $newWidth -CanvasHeight $newHeight|Out-Null
        Ensure-ViewGeometry $View
        $oldWidth=$newWidth;$oldHeight=$newHeight
    }
    if($oldWidth-ne$newWidth -or $oldHeight-ne$newHeight){
        $rx=$newWidth/[double]$oldWidth;$ry=$newHeight/[double]$oldHeight;$rs=[Math]::Min($rx,$ry)
        foreach($name in $selectableModuleNames){
            $module=Get-Module $View $name;if(-not $module){continue}
            $module.x=[int][Math]::Round([double]$module.x*$rx);$module.y=[int][Math]::Round([double]$module.y*$ry)
            $module.width=[int][Math]::Round([double]$module.width*$rs);$module.height=[int][Math]::Round([double]$module.height*$rs)
        }
        $View.canvas.width=$newWidth;$View.canvas.height=$newHeight
    }
    $base=[Math]::Min($newWidth/1711.0,$newHeight/1023.0)
    $header=Get-Module $View 'header'
    $header.visible=$true;$header.y=[int][Math]::Round(20*$base)
    $header.width=[int][Math]::Round([double]$definitions.header.width*$base);$header.height=[int][Math]::Round([double]$definitions.header.height*$base)
    $header.x=if([string]$View.layoutPreset-eq'essential-vertical'){[int][Math]::Round(($newWidth-$header.width)/2)}else{[int][Math]::Round(35*$base)}
}

$matched=@{}
for($monitorIndex=0;$monitorIndex-lt @($discovery.monitors).Count;$monitorIndex++){
    $monitor=@($discovery.monitors)[$monitorIndex]
    $found=@($views|Where-Object {-not $matched.ContainsKey($_.id)-and(($_.monitorId-and$_.monitorId-eq$monitor.pnpDeviceId)-or($_.monitorDeviceName-eq$monitor.deviceName))}|Select-Object -First 1)[0]
    if(-not $found -and $monitorIndex-eq 0){$found=@($views|Where-Object {-not $matched.ContainsKey($_.id)-and$_.enabled}|Select-Object -First 1)[0]}
    if(-not $found){
        $id=ConvertTo-AGSafeViewId $(if($monitor.pnpDeviceId){[string]$monitor.pnpDeviceId}else{[string]$monitor.deviceName})
        $layout=if([int]$monitor.height-gt[int]$monitor.width){'essential-vertical'}else{'essential-horizontal'}
        $found=New-AGDisplayView -Id $id -Name ([string]$monitor.friendlyName) -MonitorId ([string]$monitor.pnpDeviceId) -MonitorDeviceName ([string]$monitor.deviceName) -Preset $layout -Enabled $false
        Set-AGLayoutPreset -View $found -Preset $layout -CanvasWidth ([int]$monitor.width) -CanvasHeight ([int]$monitor.height)|Out-Null
        $views.Add($found)
    }
    $found.monitorId=[string]$monitor.pnpDeviceId;$found.monitorDeviceName=[string]$monitor.deviceName
    if([string]::IsNullOrWhiteSpace([string]$found.name)){$found.name=[string]$monitor.deviceName}
    Sync-ViewToMonitor $found $monitor;$matched[[string]$found.id]=$true
}

$form=New-Object Windows.Forms.Form
$form.Text=T 'title';$form.StartPosition='CenterScreen';$form.ClientSize=New-Object Drawing.Size(1280,860);$form.MinimumSize=New-Object Drawing.Size(1120,760);$form.TopMost=$true
$monitorLabel=New-Object Windows.Forms.Label;$monitorLabel.Text=T 'connectedDisplays';$monitorLabel.SetBounds(18,18,225,24);$form.Controls.Add($monitorLabel)
$monitorList=New-Object Windows.Forms.ListBox;$monitorList.SetBounds(18,46,225,690);$form.Controls.Add($monitorList)
$canvasLabel=New-Object Windows.Forms.Label;$canvasLabel.Text=T 'preview';$canvasLabel.SetBounds(260,18,730,24);$form.Controls.Add($canvasLabel)
$hint=New-Object Windows.Forms.Label;$hint.Text=T 'hint';$hint.ForeColor=[Drawing.Color]::DimGray;$hint.SetBounds(260,42,730,34);$form.Controls.Add($hint)
$canvas=New-Object Windows.Forms.Panel;$canvas.SetBounds(260,80,740,650);$canvas.BackColor=[Drawing.Color]::FromArgb(22,26,34);$canvas.BorderStyle='FixedSingle';$form.Controls.Add($canvas)
$status=New-Object Windows.Forms.Label;$status.SetBounds(260,738,740,30);$status.ForeColor=[Drawing.Color]::Firebrick;$form.Controls.Add($status)

$sideX=1018
$enabled=New-Object Windows.Forms.CheckBox;$enabled.Text=T 'enableDisplay';$enabled.SetBounds($sideX,18,230,24);$form.Controls.Add($enabled)
$presetLabel=New-Object Windows.Forms.Label;$presetLabel.Text=T 'preset';$presetLabel.SetBounds($sideX,50,220,20);$form.Controls.Add($presetLabel)
$preset=New-Object Windows.Forms.ComboBox;$preset.DropDownStyle='DropDownList';$preset.DisplayMember='Label';$preset.ValueMember='Value';$preset.SetBounds($sideX,72,225,28);$form.Controls.Add($preset)
foreach($item in @(@('full-horizontal','presetFull'),@('essential-horizontal','presetEssential'),@('essential-vertical','presetVertical'),@('performance-only','presetPerformance'),@('temperatures-only','presetTemperatures'),@('custom','presetCustom'))){[void]$preset.Items.Add([pscustomobject]@{Value=$item[0];Label=(T $item[1])})}
$background=New-Object Windows.Forms.CheckBox;$background.Text=T 'dynamicBackground';$background.SetBounds($sideX,112,220,24);$form.Controls.Add($background)
$backgroundMode=New-Object Windows.Forms.ComboBox;$backgroundMode.DropDownStyle='DropDownList';$backgroundMode.DisplayMember='Label';$backgroundMode.ValueMember='Value';$backgroundMode.SetBounds($sideX,140,225,28);$form.Controls.Add($backgroundMode)
[void]$backgroundMode.Items.Add([pscustomobject]@{Value='manual';Label=(T 'modeManual')});[void]$backgroundMode.Items.Add([pscustomobject]@{Value='thermal';Label=(T 'modeThermal')})
$countLabel=New-Object Windows.Forms.Label;$countLabel.SetBounds($sideX,178,220,18);$form.Controls.Add($countLabel)
$countTrack=New-Object Windows.Forms.TrackBar;$countTrack.Minimum=8;$countTrack.Maximum=48;$countTrack.TickFrequency=5;$countTrack.SetBounds($sideX,197,225,38);$form.Controls.Add($countTrack)
$speedLabel=New-Object Windows.Forms.Label;$speedLabel.SetBounds($sideX,237,220,18);$form.Controls.Add($speedLabel)
$speedTrack=New-Object Windows.Forms.TrackBar;$speedTrack.Minimum=20;$speedTrack.Maximum=150;$speedTrack.TickFrequency=20;$speedTrack.SetBounds($sideX,256,225,38);$form.Controls.Add($speedTrack)
$sizeLabel=New-Object Windows.Forms.Label;$sizeLabel.SetBounds($sideX,296,220,18);$form.Controls.Add($sizeLabel)
$sizeTrack=New-Object Windows.Forms.TrackBar;$sizeTrack.Minimum=70;$sizeTrack.Maximum=160;$sizeTrack.TickFrequency=10;$sizeTrack.SetBounds($sideX,315,225,38);$form.Controls.Add($sizeTrack)
$colorButton=New-Object Windows.Forms.Button;$colorButton.Text=T 'chooseColor';$colorButton.SetBounds($sideX,357,225,30);$form.Controls.Add($colorButton)
$headerInfo=New-Object Windows.Forms.Label;$headerInfo.Text=(T 'headerFixed');$headerInfo.ForeColor=[Drawing.Color]::DimGray;$headerInfo.SetBounds($sideX,400,225,22);$form.Controls.Add($headerInfo)
$modulesLabel=New-Object Windows.Forms.Label;$modulesLabel.Text=T 'visibleModules';$modulesLabel.SetBounds($sideX,426,220,20);$form.Controls.Add($modulesLabel)
$modules=New-Object Windows.Forms.CheckedListBox;$modules.CheckOnClick=$true;$modules.SetBounds($sideX,448,225,245);foreach($name in $selectableModuleNames){[void]$modules.Items.Add($moduleLabels[$name])};$form.Controls.Add($modules)
$save=New-Object Windows.Forms.Button;$save.Text=T 'saveApply';$save.SetBounds(1000,770,140,36);$form.Controls.Add($save)
$cancel=New-Object Windows.Forms.Button;$cancel.Text=T 'cancel';$cancel.SetBounds(1150,770,95,36);$form.Controls.Add($cancel);$form.CancelButton=$cancel

$script:currentView=$null;$script:currentMonitor=$null;$script:updating=$false;$script:interaction=$null;$script:screen=$null
function Select-ComboValue($Combo,[string]$Value){for($i=0;$i-lt$Combo.Items.Count;$i++){if([string]$Combo.Items[$i].Value-eq$Value){$Combo.SelectedIndex=$i;return}};$Combo.SelectedIndex=0}
function Get-SelectedValue($Combo){if($Combo.SelectedItem){return [string]$Combo.SelectedItem.Value};return ''}
function Set-Status([string]$Text,[bool]$Error=$true){$status.Text=$Text;$status.ForeColor=if($Error){[Drawing.Color]::Firebrick}else{[Drawing.Color]::DarkGreen}}
function Invoke-EditorAction([scriptblock]$Action){
    try{& $Action}catch{
        $script:updating=$false
        $caught=$_;Write-EditorError $caught
        $detail=if($caught-and$caught.Exception){$caught.Exception.Message}else{T 'unknownError'}
        $message=(T 'saveError')+' '+$detail
        Set-Status $message
    }
}
function Get-CurrentView {
    if($monitorList.SelectedIndex-lt 0){return $null};$monitor=@($discovery.monitors)[$monitorList.SelectedIndex]
    return @($views|Where-Object {($_.monitorId-and$_.monitorId-eq$monitor.pnpDeviceId)-or($_.monitorDeviceName-eq$monitor.deviceName)}|Select-Object -First 1)[0]
}
function Get-Rect($View,[string]$Name){$module=Get-Module $View $Name;if(-not$module){return $null};return [Drawing.RectangleF]::new([single]$module.x,[single]$module.y,[single]$module.width,[single]$module.height)}
function Test-Geometry($View,[string]$Name,[double]$X,[double]$Y,[double]$Width,[double]$Height){
    $margin=8.0;$canvasWidth=[double]$View.canvas.width;$canvasHeight=[double]$View.canvas.height
    if($X-lt$margin-or$Y-lt$margin-or($X+$Width)-gt($canvasWidth-$margin)-or($Y+$Height)-gt($canvasHeight-$margin)){return $false}
    $candidate=[Drawing.RectangleF]::new([single]($X-$margin/2),[single]($Y-$margin/2),[single]($Width+$margin),[single]($Height+$margin))
    foreach($otherName in $allModuleNames){if($otherName-eq$Name){continue};$other=Get-Module $View $otherName;if(-not$other-or-not[bool]$other.visible){continue};if($candidate.IntersectsWith((Get-Rect $View $otherName))){return $false}}
    return $true
}
function Set-CustomPreset {if(-not$script:currentView){return};$script:currentView.layoutPreset='custom';$script:updating=$true;Select-ComboValue $preset 'custom';$script:updating=$false}
function Commit-PreviewGeometry($Box){
    if(-not$script:currentView-or-not$canvas.Tag){return};$name=[string]$Box.Tag;$module=Get-Module $script:currentView $name;$factor=[double]$canvas.Tag.factor
    $x=[Math]::Round($Box.Left/$factor);$y=[Math]::Round($Box.Top/$factor);$w=[Math]::Round($Box.Width/$factor);$h=[Math]::Round($Box.Height/$factor)
    if(Test-Geometry $script:currentView $name $x $y $w $h){$module.x=[int]$x;$module.y=[int]$y;$module.width=[int]$w;$module.height=[int]$h;Set-CustomPreset;Set-Status ''}else{Set-Status (T 'invalidPlacement')};Draw-View;Update-SaveAvailability
}
function Start-Interaction($Sender,$Event,[string]$Mode){
    if($Event.Button-ne[Windows.Forms.MouseButtons]::Left){return};$box=if($Sender-is[Windows.Forms.Panel]-and$Sender.Tag-is[string]){$Sender}elseif($Sender.Tag-is[Windows.Forms.Panel]){$Sender.Tag}else{$Sender.Parent}
    if(-not$box-or[bool]$definitions[[string]$box.Tag].fixed){return};$script:interaction=[pscustomobject]@{box=$box;mode=$Mode;point=[Windows.Forms.Cursor]::Position;bounds=$box.Bounds};$box.Capture=$true
}
function Move-Interaction($Sender,$Event){
    if(-not$script:interaction-or$Event.Button-ne[Windows.Forms.MouseButtons]::Left){return};$box=$script:interaction.box;$start=$script:interaction.bounds;$point=[Windows.Forms.Cursor]::Position;$dx=$point.X-$script:interaction.point.X;$dy=$point.Y-$script:interaction.point.Y
    if($script:interaction.mode-eq'move'){$box.Left=[Math]::Max(0,[Math]::Min($script:screen.ClientSize.Width-$box.Width,$start.X+$dx));$box.Top=[Math]::Max(0,[Math]::Min($script:screen.ClientSize.Height-$box.Height,$start.Y+$dy))}
    else{$name=[string]$box.Tag;$definition=$definitions[$name];$aspect=[double]$definition.width/[double]$definition.height;if([Math]::Abs($dy)-gt[Math]::Abs($dx)){$newH=$start.Height+$dy;$newW=[int][Math]::Round($newH*$aspect)}else{$newW=$start.Width+$dx;$newH=[int][Math]::Round($newW/$aspect)};$factor=[double]$canvas.Tag.factor;$minW=[double]$definition.width*[double]$definition.minScale*$factor;$maxW=[double]$definition.width*[double]$definition.maxScale*$factor;$newW=[Math]::Max($minW,[Math]::Min($maxW,[Math]::Min($newW,$script:screen.ClientSize.Width-$box.Left)));$newH=[Math]::Round($newW/$aspect);if($box.Top+$newH-gt$script:screen.ClientSize.Height){$newH=$script:screen.ClientSize.Height-$box.Top;$newW=[Math]::Round($newH*$aspect)};$box.Width=[int]$newW;$box.Height=[int]$newH}
}
function End-Interaction($Sender,$Event){if($script:interaction){$box=$script:interaction.box;$script:interaction=$null;$box.Capture=$false;Commit-PreviewGeometry $box}}
function Draw-View {
    try{
        $canvas.Controls.Clear();$script:screen=$null;$view=$script:currentView;if(-not$view){return};$cw=[double]$view.canvas.width;$ch=[double]$view.canvas.height;$factor=[Math]::Min(($canvas.ClientSize.Width-16)/$cw,($canvas.ClientSize.Height-16)/$ch)
        $sw=[int][Math]::Round($cw*$factor);$sh=[int][Math]::Round($ch*$factor);$ox=[int](($canvas.ClientSize.Width-$sw)/2);$oy=[int](($canvas.ClientSize.Height-$sh)/2);$screen=New-Object Windows.Forms.Panel;$screen.SetBounds($ox,$oy,$sw,$sh);$screen.BackColor=[Drawing.Color]::FromArgb(4,7,12);$screen.BorderStyle='FixedSingle';$canvas.Controls.Add($screen);$script:screen=$screen;$canvas.Tag=[pscustomobject]@{factor=$factor}
        foreach($name in $allModuleNames){
            $module=Get-Module $view $name;if(-not$module-or-not[bool]$module.visible){continue};$box=New-Object Windows.Forms.Panel;$box.Tag=$name;$box.BackColor=if([bool]$definitions[$name].fixed){[Drawing.Color]::FromArgb(150,54,66,82)}else{[Drawing.Color]::FromArgb(185,18,88,108)};$box.BorderStyle='FixedSingle';$box.SetBounds([int]([double]$module.x*$factor),[int]([double]$module.y*$factor),[Math]::Max(28,[int]([double]$module.width*$factor)),[Math]::Max(20,[int]([double]$module.height*$factor)))
            $label=New-Object Windows.Forms.Label;$label.Text=$moduleLabels[$name];$label.TextAlign='MiddleCenter';$label.Dock='Fill';$label.ForeColor=[Drawing.Color]::White;$label.Tag=$box;$label.Cursor=if([bool]$definitions[$name].fixed){'Default'}else{'SizeAll'};$box.Controls.Add($label)
            if(-not[bool]$definitions[$name].fixed){$handle=New-Object Windows.Forms.Label;$handle.Text=[string][char]0x2198;$handle.TextAlign='MiddleCenter';$handle.BackColor=[Drawing.Color]::FromArgb(240,255,132,0);$handle.ForeColor=[Drawing.Color]::White;$handle.Cursor='SizeNWSE';$handle.Tag=$box;$handle.Anchor='Bottom,Right';$handle.SetBounds([Math]::Max(0,$box.Width-24),[Math]::Max(0,$box.Height-24),24,24);$box.Controls.Add($handle);$handle.BringToFront();$handle.Add_MouseDown({param($s,$e)Invoke-EditorAction {Start-Interaction $s $e 'resize'}});$handle.Add_MouseMove({param($s,$e)Invoke-EditorAction {Move-Interaction $s $e}});$handle.Add_MouseUp({param($s,$e)Invoke-EditorAction {End-Interaction $s $e}});$box.Add_MouseDown({param($s,$e)Invoke-EditorAction {Start-Interaction $s $e 'move'}});$box.Add_MouseMove({param($s,$e)Invoke-EditorAction {Move-Interaction $s $e}});$box.Add_MouseUp({param($s,$e)Invoke-EditorAction {End-Interaction $s $e}});$label.Add_MouseDown({param($s,$e)Invoke-EditorAction {Start-Interaction $s $e 'move'}});$label.Add_MouseMove({param($s,$e)Invoke-EditorAction {Move-Interaction $s $e}});$label.Add_MouseUp({param($s,$e)Invoke-EditorAction {End-Interaction $s $e}})}
            $screen.Controls.Add($box)
        }
    }catch{$caught=$_;Write-EditorError $caught;Set-Status ((T 'saveError')+' '+$caught.Exception.Message)}
}
function Update-BackgroundControls {$manual=$background.Checked-and(Get-SelectedValue $backgroundMode)-eq'manual';$backgroundMode.Enabled=$background.Checked;foreach($control in @($countTrack,$speedTrack,$sizeTrack,$colorButton)){$control.Enabled=$manual}}
function Update-TrackLabels {$countLabel.Text=(T 'fireflyCount')+': '+$countTrack.Value;$speedLabel.Text=(T 'riseSpeed')+': '+($speedTrack.Value/100.0).ToString('0.00');$sizeLabel.Text=(T 'generalSize')+': '+($sizeTrack.Value/100.0).ToString('0.00')}
function Load-View {
    try{$script:currentMonitor=if($monitorList.SelectedIndex-ge0){@($discovery.monitors)[$monitorList.SelectedIndex]}else{$null};$script:currentView=Get-CurrentView;if(-not$script:currentView){return};Sync-ViewToMonitor $script:currentView $script:currentMonitor;$script:updating=$true;$enabled.Checked=[bool]$script:currentView.enabled;Select-ComboValue $preset ([string]$script:currentView.layoutPreset);$background.Checked=[bool]$script:currentView.background.enabled;Select-ComboValue $backgroundMode ([string]$script:currentView.background.mode);$countTrack.Value=[Math]::Max($countTrack.Minimum,[Math]::Min($countTrack.Maximum,[int]$script:currentView.background.particleCount));$speedTrack.Value=[Math]::Max($speedTrack.Minimum,[Math]::Min($speedTrack.Maximum,[int][Math]::Round([double]$script:currentView.background.speed*100)));$sizeTrack.Value=[Math]::Max($sizeTrack.Minimum,[Math]::Min($sizeTrack.Maximum,[int][Math]::Round([double]$script:currentView.background.sizeScale*100)));if(([string]$script:currentView.background.color)-match '^(\d+),(\d+),(\d+)$'){$colorButton.BackColor=[Drawing.Color]::FromArgb([int]$Matches[1],[int]$Matches[2],[int]$Matches[3])};for($i=0;$i-lt$selectableModuleNames.Count;$i++){$module=Get-Module $script:currentView $selectableModuleNames[$i];$modules.SetItemChecked($i,[bool]$module.visible)};$script:updating=$false;Update-BackgroundControls;Update-TrackLabels;Draw-View;Update-SaveAvailability}catch{$caught=$_;$script:updating=$false;Write-EditorError $caught;Set-Status ((T 'saveError')+' '+$caught.Exception.Message)}
}
function Get-GeometryIssue($View){
    $margin=8.0;$canvasWidth=[double]$View.canvas.width;$canvasHeight=[double]$View.canvas.height
    foreach($name in $allModuleNames){
        $module=Get-Module $View $name
        if(-not$module-or-not[bool]$module.visible){continue}
        $x=[double]$module.x;$y=[double]$module.y;$width=[double]$module.width;$height=[double]$module.height
        if($x-lt$margin-or$y-lt$margin-or($x+$width)-gt($canvasWidth-$margin)-or($y+$height)-gt($canvasHeight-$margin)){
            return ('{0}: {1} fuera del limite ({2},{3},{4},{5} en {6}x{7})' -f $View.name,$moduleLabels[$name],$x,$y,$width,$height,$canvasWidth,$canvasHeight)
        }
        $candidate=[Drawing.RectangleF]::new([single]($x-$margin/2),[single]($y-$margin/2),[single]($width+$margin),[single]($height+$margin))
        foreach($otherName in $allModuleNames){
            if($otherName-eq$name){continue}
            $other=Get-Module $View $otherName
            if(-not$other-or-not[bool]$other.visible){continue}
            if($candidate.IntersectsWith((Get-Rect $View $otherName))){return ('{0}: {1} invade {2}' -f $View.name,$moduleLabels[$name],$moduleLabels[$otherName])}
        }
    }
    return ''
}
function Validate-View($View){return [string]::IsNullOrWhiteSpace((Get-GeometryIssue $View))}
function Update-SaveAvailability {
    $enabledViews=@($views|Where-Object enabled)
    if(-not$enabledViews.Count){$save.Enabled=$false;Set-Status (T 'enableOne');return}
    foreach($view in $enabledViews){$issue=Get-GeometryIssue $view;if($issue){$save.Enabled=$false;Set-Status ((T 'invalidPlacement')+' ['+$issue+']');return}}
    $save.Enabled=$true
    if($status.Text-like((T 'invalidPlacement')+'*')-or$status.Text-eq(T 'enableOne')){Set-Status '' $false}
}
function Save-Configuration {
    Write-EditorTrace 'SAVE begin'
    if(-not@($views|Where-Object enabled).Count){throw (T 'enableOne')}
    foreach($view in $views){
        $header=Get-Module $view 'header';if($header){$header.visible=$true}
        if($view.enabled){$issue=Get-GeometryIssue $view;if($issue){throw ((T 'invalidPlacement')+' ['+$issue+']')}}
    }
    if($config.PSObject.Properties['displayViews']){$config.displayViews=[object[]]$views.ToArray()}else{$config|Add-Member NoteProperty displayViews ([object[]]$views.ToArray())}
    $config.schemaVersion=3;$json=$config|ConvertTo-Json -Depth 24;$utf8=New-Object Text.UTF8Encoding($false);[IO.File]::WriteAllText($ConfigPath,$json,$utf8)
    Write-EditorTrace ('SAVE written '+$ConfigPath)
}

if($SelfTest){
    foreach($testView in @($views|Where-Object enabled)){
        Write-Output ('SELFTEST {0} preset={1} canvas={2}x{3}' -f $testView.name,$testView.layoutPreset,$testView.canvas.width,$testView.canvas.height)
        foreach($testName in $allModuleNames){$testModule=Get-Module $testView $testName;if($testModule.visible){Write-Output ('  {0}={1},{2},{3},{4}' -f $testName,$testModule.x,$testModule.y,$testModule.width,$testModule.height)}}
    }
    Save-Configuration;exit 0
}

foreach($monitor in @($discovery.monitors)){$friendly=if([string]::IsNullOrWhiteSpace([string]$monitor.friendlyName)){[string]$monitor.deviceName}else{[string]$monitor.friendlyName};[void]$monitorList.Items.Add($friendly+'  '+[char]0x00B7+'  '+$monitor.width+'x'+$monitor.height)}
$monitorList.Add_SelectedIndexChanged({Invoke-EditorAction {Load-View}});$enabled.Add_CheckedChanged({Invoke-EditorAction {if(-not$script:updating-and$script:currentView){$script:currentView.enabled=$enabled.Checked;Update-SaveAvailability}}})
$preset.Add_SelectedIndexChanged({Invoke-EditorAction {if(-not$script:updating-and$script:currentView-and$script:currentMonitor){$value=Get-SelectedValue $preset;if($value-and$value-ne'custom'){Set-AGLayoutPreset -View $script:currentView -Preset $value -CanvasWidth ([int]$script:currentMonitor.width) -CanvasHeight ([int]$script:currentMonitor.height)|Out-Null;Ensure-ViewGeometry $script:currentView;Load-View}}}})
$background.Add_CheckedChanged({Invoke-EditorAction {if(-not$script:updating-and$script:currentView){$script:currentView.background.enabled=$background.Checked};Update-BackgroundControls}});$backgroundMode.Add_SelectedIndexChanged({Invoke-EditorAction {if(-not$script:updating-and$script:currentView){$script:currentView.background.mode=Get-SelectedValue $backgroundMode};Update-BackgroundControls}})
$modules.Add_ItemCheck({param($s,$e)try{if(-not$script:updating-and$script:currentView){$module=Get-Module $script:currentView $selectableModuleNames[$e.Index];$module.visible=$e.NewValue-eq[Windows.Forms.CheckState]::Checked;Set-CustomPreset;Draw-View;Update-SaveAvailability}}catch{$caught=$_;Write-EditorError $caught;Set-Status ((T 'saveError')+' '+$caught.Exception.Message)}})
$countTrack.Add_ValueChanged({Invoke-EditorAction {Update-TrackLabels;if(-not$script:updating-and$script:currentView){$script:currentView.background.particleCount=$countTrack.Value}}});$speedTrack.Add_ValueChanged({Invoke-EditorAction {Update-TrackLabels;if(-not$script:updating-and$script:currentView){$script:currentView.background.speed=$speedTrack.Value/100.0}}});$sizeTrack.Add_ValueChanged({Invoke-EditorAction {Update-TrackLabels;if(-not$script:updating-and$script:currentView){$script:currentView.background.sizeScale=$sizeTrack.Value/100.0}}})
$colorButton.Add_Click({Invoke-EditorAction {if(-not$script:currentView){return};$dialog=New-Object Windows.Forms.ColorDialog;try{if(([string]$script:currentView.background.color)-match '^(\d+),(\d+),(\d+)$'){$dialog.Color=[Drawing.Color]::FromArgb([int]$Matches[1],[int]$Matches[2],[int]$Matches[3])};if($dialog.ShowDialog()-eq'OK'){$c=$dialog.Color;$script:currentView.background.color="$($c.R),$($c.G),$($c.B)";$colorButton.BackColor=$c}}finally{$dialog.Dispose()}}})
$form.Add_ResizeEnd({Invoke-EditorAction {Draw-View}});$cancel.Add_Click({$form.DialogResult='Cancel';$form.Close()})
$save.Add_Click({try{Write-EditorTrace 'SAVE click';Save-Configuration;Set-Status (T 'saved') $false;$form.DialogResult='OK';$form.Close()}catch{$caught=$_;Write-EditorError $caught;$detail=if($caught-and$caught.Exception){$caught.Exception.Message}else{T 'unknownError'};Set-Status ((T 'saveError')+' '+$detail);[Windows.Forms.MessageBox]::Show(((T 'saveError')+"`r`n"+$detail),'AlienGamer Mode','OK','Error')|Out-Null}})
if($monitorList.Items.Count){$monitorList.SelectedIndex=0}
if($ExportScreenshotPath){
    $parent=Split-Path -Parent $ExportScreenshotPath
    if($parent-and-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    $form.Show();[Windows.Forms.Application]::DoEvents();$form.Refresh();[Windows.Forms.Application]::DoEvents()
    $bitmap=New-Object Drawing.Bitmap($form.ClientSize.Width,$form.ClientSize.Height)
    try{$form.DrawToBitmap($bitmap,$form.ClientRectangle);$bitmap.Save($ExportScreenshotPath,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose();$form.Close();$form.Dispose()}
    exit 0
}
if($AutoSaveTest){
    $autoSaveTimer=New-Object Windows.Forms.Timer
    $autoSaveTimer.Interval=200
    $autoSaveTimer.Add_Tick({$autoSaveTimer.Stop();$autoSaveTimer.Dispose();$save.PerformClick()})
    $autoSaveTimer.Start()
}
$threadExceptionHandler=[Threading.ThreadExceptionEventHandler]{param($sender,$eventArgs)
    $exception=if($eventArgs){$eventArgs.Exception}else{$null}
    Write-EditorError $exception
    $detail=if($exception){$exception.Message}else{T 'unknownError'}
    Write-EditorTrace ('UNHANDLED '+$detail)
    try{Set-Status ((T 'saveError')+' '+$detail)}catch{}
    [Windows.Forms.MessageBox]::Show(((T 'saveError')+"`r`n"+$detail),'AlienGamer Mode','OK','Error')|Out-Null
}
[Windows.Forms.Application]::add_ThreadException($threadExceptionHandler)
try{
    Write-EditorTrace 'EDITOR dialog open'
    [void]$form.ShowDialog()
}catch{
    $caught=$_;Write-EditorError $caught;Write-EditorTrace ('DIALOG failure '+$caught.Exception.Message)
    [Windows.Forms.MessageBox]::Show(((T 'saveError')+"`r`n"+$caught.Exception.Message),'AlienGamer Mode','OK','Error')|Out-Null
    exit 2
}finally{
    [Windows.Forms.Application]::remove_ThreadException($threadExceptionHandler)
    $form.Dispose()
}
if($form.DialogResult-eq'OK'){Write-EditorTrace 'EDITOR exit 0';exit 0}
Write-EditorTrace 'EDITOR exit 1';exit 1
