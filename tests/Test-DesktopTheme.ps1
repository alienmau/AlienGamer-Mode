$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.UI.psm1') -Force
function Assert([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Luminance([Drawing.Color]$Color){
    $sum=0.0;$channels=@($Color.R,$Color.G,$Color.B);$weights=@(0.2126,0.7152,0.0722)
    for($i=0;$i-lt3;$i++){$c=$channels[$i]/255.0;$v=if($c-le0.04045){$c/12.92}else{[Math]::Pow(($c+0.055)/1.055,2.4)};$sum+=$v*$weights[$i]};return $sum
}
foreach($pair in @(@([AlienGamer.Desktop.Theme]::Text,[AlienGamer.Desktop.Theme]::Surface),@([AlienGamer.Desktop.Theme]::Secondary,[AlienGamer.Desktop.Theme]::Surface),@([AlienGamer.Desktop.Theme]::Window,[AlienGamer.Desktop.Theme]::Accent))){
    $a=Luminance $pair[0];$b=Luminance $pair[1];$ratio=([Math]::Max($a,$b)+0.05)/([Math]::Min($a,$b)+0.05)
    Assert ($ratio-ge4.5) ('Insufficient text contrast: '+$ratio)
}
$window=New-Object Windows.Forms.Form
$button=New-Object Windows.Forms.Button;$button.Text='Apply';$window.Controls.Add($button)
$combo=New-Object Windows.Forms.ComboBox;$combo.DropDownStyle='DropDownList';[void]$combo.Items.Add('Display');$window.Controls.Add($combo)
Set-AGWindowTheme $window;Set-AGPrimaryButton $button
if(-not[Windows.Forms.SystemInformation]::HighContrast){
    Assert ($window.BackColor.ToArgb()-eq[AlienGamer.Desktop.Theme]::Window.ToArgb()) 'Window theme failed.'
    Assert ($button.BackColor.ToArgb()-eq[AlienGamer.Desktop.Theme]::Accent.ToArgb()) 'Orange action failed.'
    Assert ($combo.DrawMode-eq'OwnerDrawFixed') 'Combo theme failed.'
}
$menu=New-Object Windows.Forms.ContextMenuStrip;$item=New-Object Windows.Forms.ToolStripMenuItem('Language');[void]$item.DropDownItems.Add('English');[void]$menu.Items.Add($item)
Set-AGMenuTheme $menu
if(-not[Windows.Forms.SystemInformation]::HighContrast){Assert ($menu.Renderer.GetType().Name-eq'DarkMenuRenderer'-and$item.DropDown.Renderer.GetType().Name-eq'DarkMenuRenderer') 'Menu/submenu theme failed.'}
$probe=@{checked=$false;error=$null}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=150
$timer.Add_Tick({
    $dialog=@([Windows.Forms.Application]::OpenForms|Where-Object Text -eq 'Theme test')[0]
    if(-not$dialog){return}
    $timer.Stop()
    try{
        if(-not[Windows.Forms.SystemInformation]::HighContrast){Assert ($dialog.BackColor.ToArgb()-eq[AlienGamer.Desktop.Theme]::Window.ToArgb()) 'Modal theme failed.'}
        $probe.checked=$true;$dialog.DialogResult='Cancel';$dialog.Close()
    }catch{$probe.error=$_.Exception.Message;$dialog.Close()}
})
try{$timer.Start();$result=Show-AGMessage -Text 'Preserve Cancel semantics.' -Title 'Theme test' -Buttons YesNoCancel;Assert ($probe.checked-and$result-eq'Cancel') ('Modal Cancel failed. '+$probe.error)}finally{$timer.Dispose();$window.Dispose();$menu.Dispose()}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=150
$timer.Add_Tick({
    $dialog=@([Windows.Forms.Application]::OpenForms|Where-Object Text -eq 'Firefly color')[0]
    if($dialog){$timer.Stop();$dialog.DialogResult='Cancel';$dialog.Close()}
})
try{$timer.Start();$color=Show-AGColorPicker -Color ([Drawing.Color]::Orange) -English;Assert ($null-eq$color) 'Color Cancel changed the value.'}finally{$timer.Dispose()}
# Render the real timer form construction, without reading/writing user state
# or registering its Save action.
$source=Get-Content (Join-Path $root 'src\Configure-SessionTimer.ps1') -Raw -Encoding UTF8
$start=$source.IndexOf('$form=New-Object Windows.Forms.Form');$end=$source.IndexOf('$save.Add_Click({')
Assert ($start-ge0-and$end-gt$start) 'Timer form construction not found.'
$english=$false;$duration=120;$extraStep=5
Invoke-Expression $source.Substring($start,$end-$start)
$captureDir=Join-Path $root 'build\tests';New-Item -ItemType Directory -Path $captureDir -Force|Out-Null
try{
    $form.Show();[Windows.Forms.Application]::DoEvents()
    foreach($control in $form.Controls){Assert ($control.Right-le$form.ClientSize.Width-and$control.Bottom-le$form.ClientSize.Height) ('Timer control clipped: '+$control.Text)}
    $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save((Join-Path $captureDir 'studio-timer.png'))}finally{$bitmap.Dispose()}
    foreach($factor in @(1.25,1.5,2.0)){
        $form.Scale((New-Object Drawing.SizeF($factor,$factor)))
        [Windows.Forms.Application]::DoEvents()
        foreach($control in $form.Controls){Assert ($control.Right-le$form.ClientSize.Width-and$control.Bottom-le$form.ClientSize.Height) 'Scaled timer control clipped.'}
        $form.Scale((New-Object Drawing.SizeF((1/$factor),(1/$factor))))
    }
}finally{$form.Close();$form.Dispose()}
Write-Output 'OK: orange contrast, window/control themes, menu/submenu, modal cancellation, RGB cancellation, timer capture and 125/150/200% scaling simulations.'
