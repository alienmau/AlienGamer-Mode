param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$DiscoveryPath,
    [switch]$HideConsole,
    [switch]$SelfTest,
    [switch]$AutoSaveTest,
    [string]$ExportScreenshotPath,
    [switch]$UiTest
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
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.UI.psm1') -Force

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
$allModuleNames=@('header','clock','controls','ram','vram','system','temperatures','performance','processors','timer')
$selectableModuleNames=@('clock','timer','controls','ram','vram','system','temperatures','performance','processors')
$moduleLabels=@{header=(T 'headerFixed');clock=(T 'clock');timer=(T 'timer');controls=(T 'controls');ram=(T 'ram');vram=(T 'vram');system=(T 'system');temperatures=(T 'temperatures');performance=(T 'performance');processors=(T 'processors')}
$views=New-Object 'System.Collections.Generic.List[object]'
foreach($view in @(Get-AGDisplayViews -Config $config)){$views.Add($view)}
foreach($view in $views){
    $explicit=([string]$view.monitorId -notin @('','auto')) -or ([string]$view.monitorDeviceName -notin @('','auto'))
    if($explicit -and -not(Resolve-AGViewMonitor -View $view -Monitors @($discovery.monitors))){
        # Preserve the layout, but never keep an orphaned view active after
        # Windows renumbers displays on a power or docking transition.
        $view.enabled=$false
    }
}

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
$script:viewByMonitorIndex=@{}
for($monitorIndex=0;$monitorIndex-lt @($discovery.monitors).Count;$monitorIndex++){
    $monitor=@($discovery.monitors)[$monitorIndex]
    $found=$null
    foreach($candidate in $views){
        if($matched.ContainsKey([string]$candidate.id)){continue}
        $resolved=Resolve-AGViewMonitor -View $candidate -Monitors @($discovery.monitors)
        if($resolved -and [string]$resolved.deviceName -eq [string]$monitor.deviceName){$found=$candidate;break}
    }
    # Only an unbound first-run view may be assigned automatically. A view
    # linked to a disconnected display must never jump to the laptop screen.
    if(-not $found){$found=@($views|Where-Object {-not $matched.ContainsKey($_.id)-and $_.monitorId -in @('','auto') -and $_.monitorDeviceName -in @('','auto')}|Select-Object -First 1)[0]}
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
    $script:viewByMonitorIndex[$monitorIndex]=$found
}

$form=New-Object Windows.Forms.Form
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$form.Text=T 'title';$form.StartPosition='CenterScreen';$form.ClientSize=New-Object Drawing.Size(1280,860);$form.MinimumSize=New-Object Drawing.Size(1120,760);$form.TopMost=$true
$monitorLabel=New-Object Windows.Forms.Label;$monitorLabel.Text=T 'connectedDisplays';$monitorLabel.SetBounds(18,18,225,24);$form.Controls.Add($monitorLabel)
$monitorList=New-Object Windows.Forms.ListBox;$monitorList.SetBounds(18,46,225,610);$form.Controls.Add($monitorList)
$mobileLabel=New-Object Windows.Forms.Label;$mobileLabel.Text=if($language-eq'en-US'){'Other displays · local network'}else{'Otras pantallas · red local'};$mobileLabel.SetBounds(18,670,225,24);$form.Controls.Add($mobileLabel)
$mobileButton=New-Object AlienGamer.Desktop.RoundedButton;$mobileButton.Text=if($language-eq'en-US'){'Mobile display (phone / tablet)'}else{'Pantalla móvil (celular / tablet)'};$mobileButton.SetBounds(18,698,225,36);$form.Controls.Add($mobileButton)
$mobileHint=New-Object Windows.Forms.Label;$mobileHint.Text=if($language-eq'en-US'){'Connect by QR over your home network.'}else{'Conecta por QR desde tu red local.'};$mobileHint.ForeColor=[Drawing.Color]::DimGray;$mobileHint.SetBounds(18,740,225,38);$form.Controls.Add($mobileHint)
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
$colorButton=New-Object AlienGamer.Desktop.RoundedButton;$colorButton.Text=T 'chooseColor';$colorButton.SetBounds($sideX,357,225,30);$form.Controls.Add($colorButton)
$headerInfo=New-Object Windows.Forms.Label;$headerInfo.Text=(T 'headerFixed');$headerInfo.ForeColor=[Drawing.Color]::DimGray;$headerInfo.SetBounds($sideX,400,225,22);$form.Controls.Add($headerInfo)
$modulesLabel=New-Object Windows.Forms.Label;$modulesLabel.Text=T 'visibleModules';$modulesLabel.SetBounds($sideX,426,220,20);$form.Controls.Add($modulesLabel)
$modules=New-Object Windows.Forms.CheckedListBox;$modules.CheckOnClick=$true;$modules.SetBounds($sideX,448,225,245);foreach($name in $selectableModuleNames){[void]$modules.Items.Add($moduleLabels[$name])};$form.Controls.Add($modules)
$save=New-Object AlienGamer.Desktop.RoundedButton;$save.Text=T 'saveApply';$save.SetBounds(1000,770,140,36);$form.Controls.Add($save)
$cancel=New-Object AlienGamer.Desktop.RoundedButton;$cancel.Text=T 'cancel';$cancel.SetBounds(1150,770,95,36);$form.Controls.Add($cancel);$form.CancelButton=$cancel

# Enfoque: fidelity to the approved reference, with the existing model intact.
$form.AutoScaleMode='Dpi';$form.ClientSize=New-Object Drawing.Size(1100,1000)
$form.MinimumSize=New-Object Drawing.Size(840,720)
$form.Controls.Clear()
$studio=New-Object Windows.Forms.TableLayoutPanel
$studio.Dock='Fill';$studio.ColumnCount=1;$studio.RowCount=3;$studio.Margin=New-Object Windows.Forms.Padding(0)
[void]$studio.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
[void]$studio.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',46)))
[void]$studio.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
[void]$studio.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',72)))
$form.Controls.Add($studio)
$brand=New-Object Windows.Forms.Panel;$brand.Dock='Fill';$brand.Margin=New-Object Windows.Forms.Padding(0)
$brandMark=New-Object Windows.Forms.Label;$brandMark.Text='AG';$brandMark.SetBounds(24,12,30,24);$brandMark.TextAlign='MiddleCenter'
$brandText=New-Object Windows.Forms.Label;$brandText.Text='AlienGamer Mode';$brandText.SetBounds(66,12,240,24)
$brand.Controls.AddRange([Windows.Forms.Control[]]@($brandMark,$brandText));$studio.Controls.Add($brand,0,0)
$viewport=New-Object Windows.Forms.Panel;$viewport.Dock='Fill';$viewport.AutoScroll=$true;$viewport.Margin=New-Object Windows.Forms.Padding(0)
$studio.Controls.Add($viewport,0,1)
$workspace=New-Object Windows.Forms.TableLayoutPanel
$workspace.ColumnCount=1;$workspace.RowCount=6;$workspace.Padding=New-Object Windows.Forms.Padding(20,0,20,16);$workspace.Margin=New-Object Windows.Forms.Padding(0)
[void]$workspace.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
foreach($height in @(84,108,64)){[void]$workspace.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',$height)))}
[void]$workspace.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
[void]$workspace.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',42)))
[void]$workspace.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',204)))
$viewport.Controls.Add($workspace)
$heading=New-Object Windows.Forms.Panel;$heading.Dock='Fill';$heading.Margin=New-Object Windows.Forms.Padding(0)
$studioTitle=New-Object Windows.Forms.Label;$studioTitle.Text=T 'title';$studioTitle.Text=$studioTitle.Text -replace '^AlienGamer Mode\s*[-·]\s*',''
$studioTitle.SetBounds(4,16,650,32)
$subtitle=New-Object Windows.Forms.Label;$subtitle.Text=if($language-eq'en-US'){'Choose a display and arrange its modules.'}else{'Elige una pantalla y organiza sus módulos.'};$subtitle.SetBounds(4,50,650,26)
$heading.Controls.AddRange([Windows.Forms.Control[]]@($studioTitle,$subtitle));$workspace.Controls.Add($heading,0,0)
$deviceBar=New-Object AlienGamer.Desktop.RoundedPanel;$deviceBar.Dock='Fill';$deviceBar.Padding=New-Object Windows.Forms.Padding(10);$deviceBar.Margin=New-Object Windows.Forms.Padding(0,0,0,0)
$deviceCards=New-Object Windows.Forms.FlowLayoutPanel;$deviceCards.Dock='Fill';$deviceCards.WrapContents=$true;$deviceCards.AutoScroll=$false
$deviceBar.Controls.Add($deviceCards);$workspace.Controls.Add($deviceBar,0,1)
$script:displayCards=@()
for($cardIndex=0;$cardIndex-lt@($discovery.monitors).Count;$cardIndex++){
    $monitor=@($discovery.monitors)[$cardIndex]
    $card=New-Object AlienGamer.Desktop.DisplayCard
    $card.Text=if([string]::IsNullOrWhiteSpace([string]$monitor.friendlyName)){[string]$monitor.deviceName}else{[string]$monitor.friendlyName}
    $card.Detail=('{0} × {1} · {2}' -f $monitor.width,$monitor.height,$(if($language-eq'en-US'){'Physical display'}else{'Pantalla física'}))
    $card.AccessibleName=$card.Text;$card.Tag=$cardIndex;$card.Margin=New-Object Windows.Forms.Padding(0,0,10,10)
    $card.Add_Click({param($sender,$eventArgs) $monitorList.SelectedIndex=[int]$sender.Tag})
    $deviceCards.Controls.Add($card);$script:displayCards+=,$card
}
foreach($savedView in $views){
    if(Resolve-AGViewMonitor -View $savedView -Monitors @($discovery.monitors)){continue}
    if([string]$savedView.monitorId-in@('','auto')-and[string]$savedView.monitorDeviceName-in@('','auto')){continue}
    $card=New-Object AlienGamer.Desktop.DisplayCard;$card.Text=[string]$savedView.name
    $card.Detail=if($language-eq'en-US'){'Disconnected · layout preserved'}else{'Desconectada · diseño conservado'}
    $card.Enabled=$false;$card.Tag=-1;$card.Margin=New-Object Windows.Forms.Padding(0,0,10,10);$deviceCards.Controls.Add($card)
}
# Mobile access is a peer display card, not a layout option or invented display.
$mobileButton.Dispose()
$mobileButton=New-Object AlienGamer.Desktop.DisplayCard;$mobileButton.Kind='mobile'
$mobileButton.Text=if($language-eq'en-US'){'Phone or tablet'}else{'Celular o tablet'}
$mobileButton.Detail=if($language-eq'en-US'){'Connect by QR · Local network'}else{'Conexión por QR · Red local'}
$mobileButton.Margin=New-Object Windows.Forms.Padding(0,0,10,10);$deviceCards.Controls.Add($mobileButton)
$displayHeading=New-Object Windows.Forms.Panel;$displayHeading.Dock='Fill';$displayHeading.Margin=New-Object Windows.Forms.Padding(0)
$canvasLabel.SetBounds(0,16,600,24);$canvasLabel.Anchor='Top,Left,Right'
$displayDetail=New-Object Windows.Forms.Label;$displayDetail.SetBounds(0,40,600,20);$displayDetail.Anchor='Top,Left,Right'
$enabled.Dispose();$enabled=New-Object AlienGamer.Desktop.ChoiceBox
$enabled.Text=if($language-eq'en-US'){'Show monitor'}else{'Mostrar monitor'}
$enabled.SetBounds(0,14,180,36);$enabled.Anchor='Top,Right'
$displayHeading.Controls.AddRange([Windows.Forms.Control[]]@($canvasLabel,$displayDetail,$enabled));$workspace.Controls.Add($displayHeading,0,2)
$previewArea=New-Object Windows.Forms.Panel;$previewArea.Dock='Fill';$previewArea.Margin=New-Object Windows.Forms.Padding(0)
$previewFrame=New-Object AlienGamer.Desktop.RoundedPanel;$previewFrame.ShowBorder=$true;$previewFrame.Padding=New-Object Windows.Forms.Padding(12)
$canvas.Parent=$previewFrame;$canvas.Dock='Fill';$canvas.BorderStyle='None'
$previewArea.Controls.Add($previewFrame);$workspace.Controls.Add($previewArea,0,3)
$previewBottom=New-Object Windows.Forms.Panel;$previewBottom.Dock='Fill';$previewBottom.Margin=New-Object Windows.Forms.Padding(0)
$hint.Text=if($language-eq'en-US'){'Select a module. Drag to move; use its corner to resize.'}else{'Selecciona un módulo. Arrastra para mover; usa la esquina para cambiar su tamaño.'}
$hint.SetBounds(0,8,700,26);$hint.AutoEllipsis=$true;$hint.Anchor='Top,Left,Right'
$selectionLabel=New-Object Windows.Forms.Label;$selectionLabel.TextAlign='MiddleRight';$selectionLabel.SetBounds(0,8,240,26);$selectionLabel.Anchor='Top,Right'
$previewBottom.Controls.AddRange([Windows.Forms.Control[]]@($hint,$selectionLabel));$workspace.Controls.Add($previewBottom,0,4)
$inspector=New-Object AlienGamer.Desktop.RoundedPanel;$inspector.Dock='Fill';$inspector.Padding=New-Object Windows.Forms.Padding(16);$inspector.Margin=New-Object Windows.Forms.Padding(0)
$workspace.Controls.Add($inspector,0,5)
$navigationRail=New-Object AlienGamer.Desktop.RoundedPanel;$navigationRail.Dock='Left';$navigationRail.Width=184;$navigationRail.Padding=New-Object Windows.Forms.Padding(8)
$tabStrip=New-Object Windows.Forms.FlowLayoutPanel;$tabStrip.Dock='Fill';$tabStrip.FlowDirection='TopDown';$tabStrip.WrapContents=$false
$navigationRail.Controls.Add($tabStrip)
$inspectorBody=New-Object Windows.Forms.Panel;$inspectorBody.Dock='Fill';$inspectorBody.Padding=New-Object Windows.Forms.Padding(24,0,0,0)
$inspector.Controls.Add($inspectorBody);$inspector.Controls.Add($navigationRail)
$script:studioPages=@();$script:studioTabs=@()
foreach($title in $(if($language-eq'en-US'){@('Modules','Background','Layout')}else{@('Módulos','Fondo','Diseño')})){
    $page=New-Object Windows.Forms.Panel;$page.Dock='Fill';$page.Visible=$false;$inspectorBody.Controls.Add($page);$script:studioPages+=,$page
    $tab=New-Object AlienGamer.Desktop.RoundedButton;$tab.Text=$title;$tab.Size=New-Object Drawing.Size(168,40);$tab.Radius=8;$tab.NavigationStyle=$true;$tab.Margin=New-Object Windows.Forms.Padding(0,0,0,8);$tab.Tag=$script:studioTabs.Count
    $tabStrip.Controls.Add($tab);$script:studioTabs+=,$tab;$tab.Add_Click({param($sender,$eventArgs) Select-StudioTab ([int]$sender.Tag)})
}
function Select-StudioTab([int]$Index){
    for($i=0;$i-lt$script:studioPages.Count;$i++){
        $script:studioPages[$i].Visible=($i-eq$Index);$script:studioTabs[$i].Chosen=($i-eq$Index);$script:studioTabs[$i].Invalidate()
    }
    if($Index-eq1){$inspector.AutoScroll=$true}else{$inspector.AutoScroll=$false}
    if(Get-Command Update-EnfoqueLayout -ErrorAction SilentlyContinue){Update-EnfoqueLayout}
}
$modulesLabel.Dock='Top';$modulesLabel.Height=28
$headerInfo.Dock='Bottom';$headerInfo.Height=26;$headerInfo.Text=if($language-eq'en-US'){'These options apply only to the selected display.'}else{'Se aplican sólo a esta pantalla.'}
$choicesFlow=New-Object Windows.Forms.TableLayoutPanel;$choicesFlow.Dock='Fill';$choicesFlow.ColumnCount=3;$choicesFlow.RowCount=3
for($gridIndex=0;$gridIndex-lt3;$gridIndex++){
    [void]$choicesFlow.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',33.333)))
    [void]$choicesFlow.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',33.333)))
}
$script:moduleChoices=@()
for($choiceIndex=0;$choiceIndex-lt$selectableModuleNames.Count;$choiceIndex++){
    $choice=New-Object AlienGamer.Desktop.ChoiceBox;$choice.Text=$moduleLabels[$selectableModuleNames[$choiceIndex]]
    $choice.Tag=$choiceIndex;$choice.Name=$selectableModuleNames[$choiceIndex];$choice.Margin=New-Object Windows.Forms.Padding(0,0,12,0)
    $choice.Dock='Fill';$choicesFlow.Controls.Add($choice,($choiceIndex%3),[int][Math]::Floor($choiceIndex/3));$script:moduleChoices+=,$choice
    $choice.Add_CheckedChanged({param($sender,$eventArgs)
        if(-not$script:updating-and$script:currentView){$script:selectedModule=$sender.Name;$modules.SetItemChecked([int]$sender.Tag,$sender.Checked);Update-EnfoqueContext}
    })
}
$script:studioPages[0].Controls.Add($choicesFlow);$script:studioPages[0].Controls.Add($headerInfo);$script:studioPages[0].Controls.Add($modulesLabel)
$background.SetBounds(0,0,250,32);$backgroundMode.SetBounds(0,40,250,30)
$countLabel.SetBounds(280,0,250,24);$countTrack.SetBounds(272,32,260,42)
$speedLabel.SetBounds(0,86,250,24);$speedTrack.SetBounds(-8,114,260,42)
$sizeLabel.SetBounds(280,86,250,24);$sizeTrack.SetBounds(272,114,260,42)
$colorButton.SetBounds(0,170,250,36)
$script:studioPages[1].AutoScroll=$true
$script:studioPages[1].Controls.AddRange([Windows.Forms.Control[]]@($background,$backgroundMode,$countLabel,$countTrack,$speedLabel,$speedTrack,$sizeLabel,$sizeTrack,$colorButton))
$presetLabel.SetBounds(0,0,440,28);$preset.SetBounds(0,36,440,30)
$designHint=New-Object Windows.Forms.Label;$designHint.SetBounds(0,88,530,60)
$designHint.Text=if($language-eq'en-US'){'Choose a starting layout, then arrange its modules. Every display keeps its own design.'}else{'Elige un diseño base y organiza sus módulos. Cada pantalla conserva su propio diseño.'}
$script:studioPages[2].Controls.AddRange([Windows.Forms.Control[]]@($presetLabel,$preset,$designHint))
$footer=New-Object Windows.Forms.Panel;$footer.Dock='Fill';$footer.Margin=New-Object Windows.Forms.Padding(0);$footer.Padding=New-Object Windows.Forms.Padding(24,16,24,16)
$studio.Controls.Add($footer,0,2)
$actions=New-Object Windows.Forms.FlowLayoutPanel;$actions.Dock='Right';$actions.Width=376;$actions.FlowDirection='RightToLeft';$actions.WrapContents=$false
$cancel.Text=if($language-eq'en-US'){'Discard changes'}else{'Descartar cambios'}
$cancel.Size=New-Object Drawing.Size(174,38);$save.Size=New-Object Drawing.Size(188,38)
$cancel.Margin=New-Object Windows.Forms.Padding(0,0,10,0);$save.Margin=New-Object Windows.Forms.Padding(0)
$actions.Controls.Add($save);$actions.Controls.Add($cancel)
$status.Dock='Fill';$status.TextAlign='MiddleLeft';$footer.Controls.Add($status);$footer.Controls.Add($actions)
Set-AGWindowTheme $form;Set-AGPrimaryButton $save
$studioTitle.Font=New-Object Drawing.Font('Segoe UI',18,[Drawing.FontStyle]::Bold)
$canvasLabel.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
$modulesLabel.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
if(-not[Windows.Forms.SystemInformation]::HighContrast){
    foreach($surface in @($studio,$brand,$workspace,$viewport,$heading,$displayHeading,$previewArea,$previewBottom,$footer)){$surface.BackColor=[AlienGamer.Desktop.Theme]::Window}
    foreach($label in @($subtitle,$displayDetail,$hint,$headerInfo,$designHint)){$label.ForeColor=[AlienGamer.Desktop.Theme]::Secondary}
    $previewFrame.BackColor=[Drawing.Color]::FromArgb(20,20,20);$canvas.BackColor=[AlienGamer.Desktop.Theme]::Sunken
    $brandMark.ForeColor=[AlienGamer.Desktop.Theme]::Accent;$selectionLabel.ForeColor=[AlienGamer.Desktop.Theme]::Accent
    $deviceCards.BackColor=$deviceBar.BackColor
    $navigationRail.BackColor=[AlienGamer.Desktop.Theme]::Sunken;$tabStrip.BackColor=$navigationRail.BackColor
    foreach($tab in $script:studioTabs){$tab.BackColor=$navigationRail.BackColor}
}
function Update-EnfoqueContext{
    if(-not$script:currentView){return}
    $priorUpdating=$script:updating;$script:updating=$true
    try{
        for($i=0;$i-lt$script:moduleChoices.Count;$i++){$script:moduleChoices[$i].Checked=$modules.GetItemChecked($i)}
        for($i=0;$i-lt$script:displayCards.Count;$i++){
            $card=$script:displayCards[$i];$card.Chosen=($monitorList.SelectedIndex-eq$i)
            $active=[bool]$script:viewByMonitorIndex[$i].enabled
            $card.Caption=if($language-eq'en-US'){if($card.Chosen){'Selected · '}else{''}}else{if($card.Chosen){'Seleccionada · '}else{''}}
            $card.Caption+=$(if($language-eq'en-US'){if($active){'Active'}else{'Inactive'}}else{if($active){'Activa'}else{'Inactiva'}})
            $card.Invalidate()
        }
        if($monitorList.SelectedIndex-ge0){$canvasLabel.Text=$script:displayCards[$monitorList.SelectedIndex].Text}
        $displayDetail.Text=('{0} × {1} · {2}' -f $script:currentMonitor.width,$script:currentMonitor.height,$(if($language-eq'en-US'){'Physical display'}else{'Pantalla física'}))
        $selectionLabel.Text=if($script:selectedModule){$moduleLabels[$script:selectedModule]+' · '+$(if($language-eq'en-US'){'Selected'}else{'Seleccionado'})}else{''}
    }finally{$script:updating=$priorUpdating}
}
function Update-EnfoqueLayout{
    if($script:arrangingEnfoque){return};$script:arrangingEnfoque=$true
    try{
        $available=[Math]::Max(760,$viewport.ClientSize.Width-24)
        $compact=$available-lt940
        $cardColumns=if($available-lt760){2}else{3}
        $deviceHeight=[int][Math]::Ceiling($deviceCards.Controls.Count/[double]$cardColumns)*98+12
        $workspace.RowStyles[1].Height=$deviceHeight
        $inspectorHeight=218;$workspace.RowStyles[5].Height=$inspectorHeight
        if($script:studioPages[1].Visible){$inspectorHeight=[Math]::Max(250,$inspectorHeight);$workspace.RowStyles[5].Height=$inspectorHeight}
        $minimumHeight=84+$deviceHeight+64+200+42+$inspectorHeight+16
        $viewport.AutoScroll=($viewport.ClientSize.Height-lt$minimumHeight)
        if(-not$viewport.AutoScroll){$viewport.AutoScrollMinSize=[Drawing.Size]::Empty;$viewport.AutoScrollPosition=[Drawing.Point]::Empty}
        $workspace.SetBounds(0,0,$available,[Math]::Max($minimumHeight,$viewport.ClientSize.Height))
        if($viewport.AutoScroll){$viewport.AutoScrollMinSize=New-Object Drawing.Size(0,$minimumHeight)}
        $navigationRail.Width=184
        $workspace.PerformLayout();$inspector.PerformLayout();$inspectorBody.PerformLayout()
        $cardWidth=[Math]::Floor(($deviceCards.ClientSize.Width-($cardColumns*10)-2)/$cardColumns)
        foreach($card in $deviceCards.Controls){$card.Width=[Math]::Max(220,[int]$cardWidth)}
        $enabled.Left=[Math]::Max(0,$displayHeading.ClientSize.Width-$enabled.Width)
        $canvasLabel.Width=[Math]::Max(200,$displayHeading.ClientSize.Width-$enabled.Width-24)
        $displayDetail.Width=$canvasLabel.Width
        $previewAspect=if($script:currentView){[double]$script:currentView.canvas.width/[double]$script:currentView.canvas.height}else{1.6}
        $previewWidth=[Math]::Min([Math]::Min(740,$previewArea.ClientSize.Width),[int](($previewArea.ClientSize.Height-40)*$previewAspect+40))
        $previewFrame.SetBounds([int](($previewArea.ClientSize.Width-$previewWidth)/2),0,$previewWidth,$previewArea.ClientSize.Height)
        $selectionLabel.Left=[Math]::Max(0,$previewBottom.ClientSize.Width-240);$hint.Width=[Math]::Max(200,$selectionLabel.Left-12)
        $preset.Width=[Math]::Min(440,$inspectorBody.ClientSize.Width);$designHint.Width=[Math]::Max(180,$inspectorBody.ClientSize.Width-8)
        $workspace.PerformLayout();$inspector.PerformLayout();$inspectorBody.PerformLayout()
        $speedTrack.Left=0
        if($script:currentView){Draw-View}
    }finally{$script:arrangingEnfoque=$false}
}
$viewport.Add_SizeChanged({Update-EnfoqueLayout})
$inspectorBody.Add_SizeChanged({if(-not$script:arrangingEnfoque){Update-EnfoqueLayout}})
$script:initialViewState=ConvertTo-Json -InputObject $views.ToArray() -Depth 24 -Compress
function Update-DirtyState{
    if($script:statusError){return}
    $state=ConvertTo-Json -InputObject $views.ToArray() -Depth 24 -Compress
    $status.Text=if($state-ne$script:initialViewState){if($language-eq'en-US'){'Unsaved changes'}else{'Cambios sin guardar'}}else{if($language-eq'en-US'){'No changes'}else{'Sin cambios'}}
    if(-not[Windows.Forms.SystemInformation]::HighContrast){$status.ForeColor=[AlienGamer.Desktop.Theme]::Secondary}
}
Select-StudioTab 0
Update-EnfoqueLayout

$script:currentView=$null;$script:currentMonitor=$null;$script:updating=$false;$script:interaction=$null;$script:screen=$null
function Select-ComboValue($Combo,[string]$Value){for($i=0;$i-lt$Combo.Items.Count;$i++){if([string]$Combo.Items[$i].Value-eq$Value){$Combo.SelectedIndex=$i;return}};$Combo.SelectedIndex=0}
function Get-SelectedValue($Combo){if($Combo.SelectedItem){return [string]$Combo.SelectedItem.Value};return ''}
function Set-Status([string]$Text,[bool]$Error=$true){$script:statusError=$Error-and-not[string]::IsNullOrWhiteSpace($Text);$status.Text=$Text;$status.ForeColor=if([Windows.Forms.SystemInformation]::HighContrast){[Drawing.SystemColors]::ControlText}elseif($Error){[AlienGamer.Desktop.Theme]::Danger}else{[AlienGamer.Desktop.Theme]::Secondary}}
function Invoke-EditorAction([scriptblock]$Action){
    try{& $Action;Update-EnfoqueContext;Update-DirtyState}catch{
        $script:updating=$false
        $caught=$_;Write-EditorError $caught
        $detail=if($caught-and$caught.Exception){$caught.Exception.Message}else{T 'unknownError'}
        $message=(T 'saveError')+' '+$detail
        Set-Status $message
    }
}
function Get-CurrentView {
    if($monitorList.SelectedIndex-lt 0){return $null}
    return $script:viewByMonitorIndex[$monitorList.SelectedIndex]
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
    if(-not$box-or[bool]$definitions[[string]$box.Tag].fixed){return};$script:selectedModule=[string]$box.Tag
    foreach($tile in $script:screen.Controls){if($tile-is[AlienGamer.Desktop.PreviewTile]){$tile.Selected=([string]$tile.Tag-eq$script:selectedModule);$tile.Invalidate()}}
    $script:interaction=[pscustomobject]@{box=$box;mode=$Mode;point=[Windows.Forms.Cursor]::Position;bounds=$box.Bounds};$box.Capture=$true
}
function Move-Interaction($Sender,$Event){
    if(-not$script:interaction-or$Event.Button-ne[Windows.Forms.MouseButtons]::Left){return};$box=$script:interaction.box;$start=$script:interaction.bounds;$point=[Windows.Forms.Cursor]::Position;$dx=$point.X-$script:interaction.point.X;$dy=$point.Y-$script:interaction.point.Y
    if($script:interaction.mode-eq'move'){$box.Left=[Math]::Max(0,[Math]::Min($script:screen.ClientSize.Width-$box.Width,$start.X+$dx));$box.Top=[Math]::Max(0,[Math]::Min($script:screen.ClientSize.Height-$box.Height,$start.Y+$dy))}
    else{$name=[string]$box.Tag;$definition=$definitions[$name];$aspect=[double]$definition.width/[double]$definition.height;if([Math]::Abs($dy)-gt[Math]::Abs($dx)){$newH=$start.Height+$dy;$newW=[int][Math]::Round($newH*$aspect)}else{$newW=$start.Width+$dx;$newH=[int][Math]::Round($newW/$aspect)};$factor=[double]$canvas.Tag.factor;$minW=[double]$definition.width*[double]$definition.minScale*$factor;$maxW=[double]$definition.width*[double]$definition.maxScale*$factor;$newW=[Math]::Max($minW,[Math]::Min($maxW,[Math]::Min($newW,$script:screen.ClientSize.Width-$box.Left)));$newH=[Math]::Round($newW/$aspect);if($box.Top+$newH-gt$script:screen.ClientSize.Height){$newH=$script:screen.ClientSize.Height-$box.Top;$newW=[Math]::Round($newH*$aspect)};$box.Width=[int]$newW;$box.Height=[int]$newH}
}
function End-Interaction($Sender,$Event){if($script:interaction){$box=$script:interaction.box;$script:interaction=$null;$box.Capture=$false;Commit-PreviewGeometry $box}}
function Move-PreviewByKeyboard($Box,$Event){
    $step=if($Event.Shift){1}else{10};$dx=0;$dy=0
    switch($Event.KeyCode){'Left'{$dx=-$step};'Right'{$dx=$step};'Up'{$dy=-$step};'Down'{$dy=$step};default{return}}
    $Event.Handled=$true;$Event.SuppressKeyPress=$true
    $name=[string]$Box.Tag;$module=Get-Module $script:currentView $name
    if(Test-Geometry $script:currentView $name ($module.x+$dx) ($module.y+$dy) $module.width $module.height){
        $module.x+=$dx;$module.y+=$dy;$script:selectedModule=$name;Set-CustomPreset;Draw-View;Update-SaveAvailability
        foreach($tile in $script:screen.Controls){if([string]$tile.Tag-eq$name){[void]$tile.Focus()}}
    }else{Set-Status (T 'invalidPlacement')}
}
function Draw-View {
    try{
        foreach($old in @($canvas.Controls)){$old.Dispose()};$canvas.Controls.Clear();$script:screen=$null;$view=$script:currentView;if(-not$view){return};$cw=[double]$view.canvas.width;$ch=[double]$view.canvas.height;$factor=[Math]::Min(($canvas.ClientSize.Width-16)/$cw,($canvas.ClientSize.Height-16)/$ch)
        $sw=[int][Math]::Round($cw*$factor);$sh=[int][Math]::Round($ch*$factor);$ox=[int](($canvas.ClientSize.Width-$sw)/2);$oy=[int](($canvas.ClientSize.Height-$sh)/2);$screen=New-Object Windows.Forms.Panel;$screen.SetBounds($ox,$oy,$sw,$sh);$screen.BackColor=if([Windows.Forms.SystemInformation]::HighContrast){[Drawing.SystemColors]::Window}else{[AlienGamer.Desktop.Theme]::Sunken};$screen.BorderStyle='FixedSingle';$canvas.Controls.Add($screen);$script:screen=$screen;$canvas.Tag=[pscustomobject]@{factor=$factor}
        foreach($name in $allModuleNames){
            $module=Get-Module $view $name;if(-not$module-or-not[bool]$module.visible){continue};$box=New-Object AlienGamer.Desktop.PreviewTile;$box.Selected=($name-eq$script:selectedModule);$box.Ring=($name-in@('ram','vram'));$box.FixedHeader=[bool]$definitions[$name].fixed;$box.Tag=$name;$box.BackColor=if([Windows.Forms.SystemInformation]::HighContrast){[Drawing.SystemColors]::Control}else{[AlienGamer.Desktop.Theme]::PreviewCard};$box.SetBounds([int]([double]$module.x*$factor),[int]([double]$module.y*$factor),[Math]::Max(28,[int]([double]$module.width*$factor)),[Math]::Max(20,[int]([double]$module.height*$factor)))
            $box.Text=$moduleLabels[$name];$box.AccessibleName=$moduleLabels[$name];$box.AccessibleDescription=if($language-eq'en-US'){'Arrow keys: move module'}else{'Flechas: mover módulo'};$box.Cursor=if([bool]$definitions[$name].fixed){'Default'}else{'SizeAll'};$box.TabStop=-not[bool]$definitions[$name].fixed
            if(-not[bool]$definitions[$name].fixed){$handle=New-Object AlienGamer.Desktop.ResizeGrip;$handle.Text=[string][char]0x2198;$handle.TextAlign='MiddleCenter';$handle.BackColor=if([Windows.Forms.SystemInformation]::HighContrast){[Drawing.SystemColors]::Highlight}else{[AlienGamer.Desktop.Theme]::Accent};$handle.ForeColor=if([Windows.Forms.SystemInformation]::HighContrast){[Drawing.SystemColors]::HighlightText}else{[Drawing.Color]::Black};$handle.Cursor='SizeNWSE';$handle.Tag=$box;$handle.Anchor='Bottom,Right';$handle.SetBounds([Math]::Max(0,$box.Width-23),[Math]::Max(0,$box.Height-23),22,22);$box.Controls.Add($handle);$handle.BringToFront();$handle.Add_MouseDown({param($s,$e)Invoke-EditorAction {Start-Interaction $s $e 'resize'}});$handle.Add_MouseMove({param($s,$e)Invoke-EditorAction {Move-Interaction $s $e}});$handle.Add_MouseUp({param($s,$e)Invoke-EditorAction {End-Interaction $s $e}});$box.Add_MouseDown({param($s,$e)Invoke-EditorAction {Start-Interaction $s $e 'move'}});$box.Add_MouseMove({param($s,$e)Invoke-EditorAction {Move-Interaction $s $e}});$box.Add_MouseUp({param($s,$e)Invoke-EditorAction {End-Interaction $s $e}});$box.Add_KeyDown({param($s,$e)Invoke-EditorAction {Move-PreviewByKeyboard $s $e}})}
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

function Show-MobileDialog {
    $dialog=New-Object Windows.Forms.Form
    $dialog.Font=New-Object Drawing.Font('Segoe UI',10)
    $dialog.Text=if($language-eq'en-US'){'Mobile monitor · local network'}else{'Monitor móvil · red local'}
    $dialog.ClientSize=New-Object Drawing.Size(530,495)
    $dialog.FormBorderStyle='FixedDialog';$dialog.MaximizeBox=$false;$dialog.StartPosition='CenterParent';$dialog.TopMost=$true
    $mobile=if($config.PSObject.Properties['mobileView']){$config.mobileView}else{$null}
    $check=New-Object Windows.Forms.CheckBox;$check.Text=if($language-eq'en-US'){'Enable web monitor on my local network'}else{'Activar monitor web en mi red local'};$check.Checked=[bool]$mobile.enabled;$check.SetBounds(18,14,490,27);$dialog.Controls.Add($check)
    $notice=New-Object Windows.Forms.Label;$notice.Text=if($language-eq'en-US'){'Turn on to start the local web service and show its QR. Phone on Wi-Fi and laptop on Ethernet must share the same router.'}else{'Activa esta opción para iniciar el servicio web y mostrar su QR. Celular por Wi-Fi y laptop por Ethernet deben usar el mismo router.'};$notice.SetBounds(18,43,493,42);$dialog.Controls.Add($notice)
    $items=New-Object Windows.Forms.CheckedListBox;$items.CheckOnClick=$true;$items.SetBounds(18,90,205,237)
    $mobileNames=@('ram','vram','system','temperatures','fps','alerts','clock','timer','processors')
    $savedModules=if($mobile){@($mobile.modules)}else{@('ram','vram','system','temperatures','performance','clock')}
    if('performance' -in $savedModules){$savedModules=@($savedModules|Where-Object {$_ -ne 'performance'})+@('fps','alerts')}
    if('frameTime' -in $savedModules){$savedModules=@($savedModules|Where-Object {$_ -ne 'frameTime'})+@('fps')}
    $mobileLabels=@{fps=$(if($language-eq'en-US'){'FPS / frame time'}else{'FPS / tiempo de cuadro'});alerts=$(if($language-eq'en-US'){'Alerts'}else{'Alertas'})}
    for($i=0;$i -lt $mobileNames.Count;$i++){$name=$mobileNames[$i];$label=if($mobileLabels.ContainsKey($name)){$mobileLabels[$name]}else{$moduleLabels[$name]};[void]$items.Items.Add($label,($name -in $savedModules))};$dialog.Controls.Add($items)
    $qr=New-Object Windows.Forms.PictureBox;$qr.SetBounds(245,92,250,250);$qr.SizeMode='Zoom';$dialog.Controls.Add($qr)
    $urlBox=New-Object Windows.Forms.TextBox;$urlBox.ReadOnly=$true;$urlBox.SetBounds(18,349,477,26);$dialog.Controls.Add($urlBox)
    $state=New-Object Windows.Forms.Label;$state.SetBounds(18,382,490,45);$dialog.Controls.Add($state)
    $apply=New-Object AlienGamer.Desktop.RoundedButton;$apply.Text=if($language-eq'en-US'){'Apply modules'}else{'Aplicar módulos'};$apply.SetBounds(252,443,116,33);$dialog.Controls.Add($apply)
    $close=New-Object AlienGamer.Desktop.RoundedButton;$close.Text=if($language-eq'en-US'){'Close'}else{'Cerrar'};$close.SetBounds(379,443,116,33);$close.Add_Click({$dialog.Close()});$dialog.Controls.Add($close)
    $copy=New-Object AlienGamer.Desktop.RoundedButton;$copy.Text=if($language-eq'en-US'){'Copy link'}else{'Copiar enlace'};$copy.Enabled=$false;$copy.SetBounds(18,443,116,33);$copy.Add_Click({if($urlBox.Text){[Windows.Forms.Clipboard]::SetText($urlBox.Text);$state.Text=if($language-eq'en-US'){'Link copied. Open it on a device on the same network.'}else{'Enlace copiado. Ábrelo desde un dispositivo en la misma red.'}}});$dialog.Controls.Add($copy)
    $mobileState=[pscustomobject]@{Current=$mobile;Regenerate=$false;Busy=$false;LastUrl='';WaitingSince=(Get-Date)}
    $renew=New-Object AlienGamer.Desktop.RoundedButton;$renew.Text=if($language-eq'en-US'){'New QR'}else{'Nuevo QR'};$renew.Enabled=$false;$renew.SetBounds(143,443,99,33);$dialog.Controls.Add($renew)
    $clearQr={
        $urlBox.Text='';$copy.Enabled=$false;$renew.Enabled=$false;$mobileState.LastUrl=''
        if($qr.Image){$qr.Image.Dispose();$qr.Image=$null}
    }
    $paintQr={
        $items.Enabled=$check.Checked;$apply.Enabled=$check.Checked -and -not $mobileState.Busy
        if(-not $check.Checked){& $clearQr;$state.Text=if($language-eq'en-US'){'Web service is off. Turn it on above to generate a QR.'}else{'Servicio web apagado. Actívalo arriba para generar el QR.'};return}
        $endpointPath=Join-Path (Split-Path -Parent $ConfigPath) 'mobile-endpoint.json'
        try{
            if(-not(Test-Path -LiteralPath $endpointPath)){throw 'WAIT_ENDPOINT'}
            $endpoint=Get-Content -LiteralPath $endpointPath -Raw -Encoding UTF8|ConvertFrom-Json
            if(-not $endpoint.url -or -not $mobileState.Current.token -or -not ([string]$endpoint.url).Contains([string]$mobileState.Current.token)){throw 'WAIT_ENDPOINT'}
            if($mobileState.LastUrl -eq [string]$endpoint.url){return}
            $urlBox.Text=[string]$endpoint.url
            $qrAssembly=Join-Path $PSScriptRoot 'assets\QRCoder.dll'
            if(-not(Test-Path -LiteralPath $qrAssembly)){$qrAssembly=Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\QRCoder.dll'}
            Add-Type -Path $qrAssembly -ErrorAction Stop
            $generator=[QRCoder.QRCodeGenerator]::new()
            $data=$generator.CreateQrCode($urlBox.Text,[QRCoder.QRCodeGenerator+ECCLevel]::Q)
            $renderer=[QRCoder.QRCode]::new($data)
            $bitmap=$renderer.GetGraphic(5)
            if($qr.Image){$qr.Image.Dispose()};$qr.Image=$bitmap
            $renderer.Dispose();$data.Dispose();$generator.Dispose()
            $mobileState.LastUrl=$urlBox.Text;$copy.Enabled=$true;$renew.Enabled=$true
            $state.Text=if($language-eq'en-US'){'Scan with a phone on the same router. Fullscreen needs a tap.'}else{'Escanea desde un dispositivo en el mismo router. Pantalla completa requiere un toque.'}
        }catch{
            & $clearQr
            if($_.Exception.Message -eq 'WAIT_ENDPOINT'){
                $state.Text=if(((Get-Date)-$mobileState.WaitingSince).TotalSeconds -lt 10){if($language-eq'en-US'){'Starting local web service…'}else{'Iniciando servicio web local…'}}else{if($language-eq'en-US'){'No web service response. Activate the monitor and check the local network.'}else{'El servicio no responde. Activa el monitor y comprueba la conexión a la red local.'}}
            }else{$state.Text=$_.Exception.Message}
        }
    }
    $saveMobile={
        if($mobileState.Busy){return}
        $mobileState.Busy=$true
        try{
            $selected=@(for($i=0;$i -lt $mobileNames.Count;$i++){if($items.GetItemChecked($i)){$mobileNames[$i]}})
            if($check.Checked -and -not $selected.Count){throw 'Selecciona al menos un módulo.'}
            $token=if(-not $mobileState.Regenerate -and $mobileState.Current -and [string]$mobileState.Current.token -match '^[a-fA-F0-9]{32,64}$'){[string]$mobileState.Current.token}else{''}
            if(-not $token){$bytes=New-Object byte[] 24;[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes);$token=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()}
            $value=[pscustomobject]@{enabled=[bool]$check.Checked;port=27844;token=$token;modules=$selected}
            $mobileState.Regenerate=$false
            $mobileState.Current=$value
            Set-Property $config 'mobileView' $value
            # This subdialog only changes the mobile setting. Existing visual
            # edits remain in the main editor until Guardar y aplicar.
            $disk=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
            Set-Property $disk 'mobileView' $value
            $temp="$ConfigPath.mobile-$PID.tmp"
            [IO.File]::WriteAllText($temp,($disk|ConvertTo-Json -Depth 24),(New-Object Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $temp -Destination $ConfigPath -Force
            $mobileState.WaitingSince=Get-Date
            & $clearQr
        }catch{$state.Text=$_.Exception.Message}
        finally{$mobileState.Busy=$false}
        & $paintQr
    }
    $apply.Add_Click({& $saveMobile})
    $check.Add_CheckedChanged({& $saveMobile})
    $renew.Add_Click({$mobileState.Regenerate=$true;& $saveMobile})
    & $paintQr
    $refresh=New-Object Windows.Forms.Timer;$refresh.Interval=500
    $refresh.Add_Tick({if(-not $mobileState.Busy){& $paintQr}});$refresh.Start()
    Set-AGWindowTheme $dialog;Set-AGPrimaryButton $apply
    # Reserve enough height for localized explanatory text at the common font.
    $dialog.ClientSize=New-Object Drawing.Size(580,536)
    $check.SetBounds(18,14,544,27);$notice.SetBounds(18,49,544,60)
    $items.SetBounds(18,120,228,237);$qr.SetBounds(280,120,250,250)
    $urlBox.SetBounds(18,386,544,28);$state.SetBounds(18,430,544,45)
    $copy.SetBounds(18,484,116,36);$renew.SetBounds(146,484,100,36)
    $apply.SetBounds(258,484,140,36);$close.SetBounds(414,484,148,36)
    $dialog.AcceptButton=$apply;$dialog.CancelButton=$close
    [void]$dialog.ShowDialog($form)
    $refresh.Stop();$refresh.Dispose()
    if($qr.Image){$qr.Image.Dispose()};$dialog.Dispose()
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
$colorButton.Add_Click({Invoke-EditorAction {if(-not$script:currentView){return};$initial=[Drawing.Color]::Orange;if(([string]$script:currentView.background.color)-match '^(\d+),(\d+),(\d+)$'){$initial=[Drawing.Color]::FromArgb([int]$Matches[1],[int]$Matches[2],[int]$Matches[3])};$c=Show-AGColorPicker -Owner $form -Color $initial -English:($language-eq'en-US');if($null-ne$c){$script:currentView.background.color="$($c.R),$($c.G),$($c.B)";$colorButton.BackColor=$c;$colorButton.ForeColor=if($c.GetBrightness()-gt0.55){[Drawing.Color]::Black}else{[Drawing.Color]::White}}}})
$form.Add_ResizeEnd({Invoke-EditorAction {Draw-View}});$cancel.Add_Click({$form.DialogResult='Cancel';$form.Close()})
$save.Add_Click({try{Write-EditorTrace 'SAVE click';Save-Configuration;Set-Status (T 'saved') $false;$form.DialogResult='OK';$form.Close()}catch{$caught=$_;Write-EditorError $caught;$detail=if($caught-and$caught.Exception){$caught.Exception.Message}else{T 'unknownError'};Set-Status ((T 'saveError')+' '+$detail);(Show-AGMessage -Text ((T 'saveError')+"`r`n"+$detail) -Icon Error -English:($script:language -eq 'en-US'))|Out-Null}})
$mobileButton.Add_Click({Invoke-EditorAction {Show-MobileDialog}})
if($monitorList.Items.Count){$monitorList.SelectedIndex=0}
if($UiTest-or$ExportScreenshotPath){
    $form.Show();[Windows.Forms.Application]::DoEvents();$form.Refresh();[Windows.Forms.Application]::DoEvents()
    if($UiTest){
        foreach($size in @(@(1280,860),@(1100,740),@(1600,1000))){
            $form.ClientSize=New-Object Drawing.Size($size[0],$size[1]);[Windows.Forms.Application]::DoEvents();Draw-View
            if($save.Right-gt$actions.ClientSize.Width-or$save.Bottom-gt$actions.ClientSize.Height){throw ('Primary action clipped: button '+$save.Bounds+' / footer '+$actions.ClientSize)}
            if($canvas.Width-lt240-or$canvas.Height-lt170){throw 'Preview became unusable.'}
            foreach($choice in $script:moduleChoices){if($choice.Bottom-gt$choicesFlow.ClientSize.Height){throw 'Module choice clipped.'}}
            for($tabIndex=0;$tabIndex-lt3;$tabIndex++){
                Select-StudioTab $tabIndex
                if(-not$script:studioPages[$tabIndex].Visible-or-not$script:studioTabs[$tabIndex].Chosen){throw 'Inspector navigation failed.'}
                foreach($tab in $script:studioTabs){if($tab.Right-gt$tabStrip.ClientSize.Width-or$tab.Bottom-gt$tabStrip.ClientSize.Height){throw 'Vertical navigation clipped.'}}
                if($inspectorBody.Padding.Left-lt24){throw 'Inspector content gap lost.'}
            }
        }
        $beforeSelection=[bool]$script:viewByMonitorIndex[0].enabled
        $script:displayCards[1].PerformClick();[Windows.Forms.Application]::DoEvents()
        if($monitorList.SelectedIndex-ne1-or$canvasLabel.Text-ne$script:displayCards[1].Text){throw 'Display selection not synchronized.'}
        $script:displayCards[0].PerformClick();[Windows.Forms.Application]::DoEvents()
        if([bool]$script:viewByMonitorIndex[0].enabled-ne$beforeSelection){throw 'Selecting a display changed its activation.'}
        if($ExportScreenshotPath){
            $form.ClientSize=New-Object Drawing.Size(860,900);Select-StudioTab 0;Update-EnfoqueLayout;[Windows.Forms.Application]::DoEvents()
            $compactBitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
            try{$form.DrawToBitmap($compactBitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$compactBitmap.Save(($ExportScreenshotPath-replace'\.png$','-compact.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$compactBitmap.Dispose()}
        }
        $form.ClientSize=New-Object Drawing.Size(1100,1000);Select-StudioTab 0;Update-EnfoqueLayout;[Windows.Forms.Application]::DoEvents()
        $script:selectedModule='ram';Update-EnfoqueContext;Draw-View
        Write-Output 'OK: Enfoque, three inspector pages, preview and persistent footer at 1100/1280/1600 widths.'
        if(-not$ExportScreenshotPath){$form.Close();$form.Dispose();exit 0}
    }
    $parent=Split-Path -Parent $ExportScreenshotPath
    if($parent-and-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save($ExportScreenshotPath,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose();$form.Close();$form.Dispose()}
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
    (Show-AGMessage -Text ((T 'saveError')+"`r`n"+$detail) -Icon Error -English:($script:language -eq 'en-US'))|Out-Null
}
[Windows.Forms.Application]::add_ThreadException($threadExceptionHandler)
try{
    Write-EditorTrace 'EDITOR dialog open'
    [void]$form.ShowDialog()
}catch{
    $caught=$_;Write-EditorError $caught;Write-EditorTrace ('DIALOG failure '+$caught.Exception.Message)
    (Show-AGMessage -Text ((T 'saveError')+"`r`n"+$caught.Exception.Message) -Icon Error -English:($script:language -eq 'en-US'))|Out-Null
    exit 2
}finally{
    [Windows.Forms.Application]::remove_ThreadException($threadExceptionHandler)
    $form.Dispose()
}
if($form.DialogResult-eq'OK'){Write-EditorTrace 'EDITOR exit 0';exit 0}
Write-EditorTrace 'EDITOR exit 1';exit 1
