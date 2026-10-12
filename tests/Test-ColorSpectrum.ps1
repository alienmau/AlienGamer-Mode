$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.UI.psm1') -Force
$output=Join-Path $root 'build\tests\color-spectrum'
New-Item -ItemType Directory -Path $output -Force|Out-Null
foreach($english in @($false,$true)){
    foreach($mode in @('unchanged','apply','cancel')){
        $script:failure=$null
        $timer=New-Object Windows.Forms.Timer
        $timer.Interval=150
        $timer.Add_Tick({
            $timer.Stop()
            $dialog=@([Windows.Forms.Application]::OpenForms)[0]
            try{
                $spectrum=$dialog.Controls['ColorSpectrum']
                if(-not $spectrum -or @($dialog.Controls|Where-Object {$_ -is [Windows.Forms.NumericUpDown]}).Count){throw 'Spectrum missing or RGB inputs still present.'}
                foreach($control in $dialog.Controls){if($control.Right -gt $dialog.ClientSize.Width -or $control.Bottom -gt $dialog.ClientSize.Height){throw 'Control clipped.'}}
                if($mode -ne 'unchanged'){
                    $spectrum.Hue=120
                    $dialog.Controls['ColorBrightness'].Value=80
                    $flags=[Reflection.BindingFlags]'Instance,NonPublic'
                    $spectrum.GetType().GetMethod('OnKeyDown',$flags).Invoke($spectrum,@([Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Right)))|Out-Null
                    if($spectrum.Hue -ne 121){throw 'Arrow keyboard selection failed.'}
                    $spectrum.Hue=120
                }
                if($mode -eq 'apply'){
                    $bitmap=New-Object Drawing.Bitmap($dialog.Width,$dialog.Height)
                    try{$dialog.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$dialog.Width,$dialog.Height));$bitmap.Save((Join-Path $output ("spectrum-$english.png")))}finally{$bitmap.Dispose()}
                }
                $dialog.Controls[$(if($mode-eq'cancel'){'CancelColor'}else{'ApplyColor'})].PerformClick()
            }catch{$script:failure=$_;$dialog.Close()}
        })
        $timer.Start()
        try{$actual=Show-AGColorPicker -Owner $null -Color ([Drawing.Color]::FromArgb(0,112,20)) -English:$english}finally{$timer.Dispose()}
        if($script:failure){throw $script:failure}
        if($mode-eq'cancel'){if($null-ne$actual){throw 'Cancel returned a color.'}}
        elseif($mode-eq'unchanged'){if($actual.ToArgb()-ne[Drawing.Color]::FromArgb(0,112,20).ToArgb()){throw 'Original color changed without interaction.'}}
        elseif($actual.ToArgb()-ne[Drawing.Color]::FromArgb(0,204,0).ToArgb()){throw 'Selected hue/brightness not returned.'}
    }
}
'PASS: Spanish/English dialogs, rainbow, keyboard, preview, brightness, Apply, Cancel and original-color preservation.'
