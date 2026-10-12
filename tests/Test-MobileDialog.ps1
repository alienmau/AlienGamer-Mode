$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.UI.psm1') -Force
$sourcePath=Join-Path $root 'src\Show-AlienGamerLayoutEditor.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($sourcePath,[ref]$tokens,[ref]$errors)
$definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Show-MobileDialog'},$true)
Invoke-Expression ($definition.Extent.Text.Replace('$PSScriptRoot',("'"+(Join-Path $root 'src').Replace("'","''")+"'")))
function Set-Property($object,[string]$name,$value){$object|Add-Member NoteProperty $name $value -Force}
function Write-EditorTrace($Message){}
function Update-SaveAvailability {$script:parentValidationRefreshed=$true}
$language='es-MX'
$moduleLabels=@{ram='RAM';vram='VRAM';system='CPU/GPU';temperatures='Temperaturas';performance='FPS';clock='Reloj';timer='Timer';processors='Procesadores'}
$config=[pscustomobject]@{mobileView=[pscustomobject]@{enabled=$false;port=27844;token='';modules=@('ram')}}
$tempDirectory=Join-Path $env:TEMP ('AlienGamer-dialog-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDirectory|Out-Null
$ConfigPath=Join-Path $tempDirectory 'AlienGamerMode.json'
$script:editorConfigFile=$ConfigPath
$config|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ConfigPath -Encoding UTF8
# The extracted function locates assets relative to tests, then the repository.
$form=New-Object Windows.Forms.Form
$probe=[pscustomobject]@{phase=0;passed=$false;error=$null;token=''}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=800
$probe|Add-Member NoteProperty deadline ((Get-Date).AddSeconds(30))
$timer.Add_Tick({
    try{
        if((Get-Date)-gt$probe.deadline){throw 'Nested mobile dialog timed out.'}
        $dialog=@([Windows.Forms.Application]::OpenForms|Where-Object {$_.Text -like 'Monitor*red local'})[0]
        if(-not $dialog){return}
        $wizard=@([Windows.Forms.Application]::OpenForms|Where-Object {$_.Text -like 'Conexi*n segura*'})[0]
        if($wizard){
            $all=New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'
            $collect={param($control)foreach($child in $control.Controls){$all.Add($child);& $collect $child}};& $collect $wizard
            switch($probe.phase){
                3 {
                    $consent=@($all|Where-Object Text -eq 'Entiendo el permiso y quiero preparar HTTPS.')[0]
                    $prepare=@($all|Where-Object Text -eq 'Preparar certificado')[0]
                    $consent.Checked=$true;$prepare.PerformClick()
                    @{url=('http://192.168.0.199:27844/m/'+$probe.token+'/');https=$false;certificateReady=$true;fingerprint='AA:BB';certificateName='Fixture CA'}|ConvertTo-Json|Set-Content (Join-Path $tempDirectory 'mobile-endpoint.json') -Encoding UTF8
                    $probe.phase=4
                }
                4 {
                    $activate=@($all|Where-Object Text -eq 'Activar HTTPS')[0];if(-not$activate){return}
                    $wizardQr=@($all|Where-Object {$_ -is [Windows.Forms.PictureBox]})[0]
                    if(-not$wizardQr.Image){throw 'The nested assistant has no QR.'}
                    $probe.phase=5 # Leave it open across several parent refresh intervals.
                }
                5 {
                    $installed=@($all|Where-Object Text -eq 'Comparé la huella e instalé el certificado en mi dispositivo.')[0]
                    $installed.Checked=$true;(@($all|Where-Object Text -eq 'Activar HTTPS')[0]).PerformClick()
                    @{url=('https://192.168.0.199:27844/m/'+$probe.token+'/');https=$true;certificateReady=$true;fingerprint='AA:BB';certificateName='Fixture CA'}|ConvertTo-Json|Set-Content (Join-Path $tempDirectory 'mobile-endpoint.json') -Encoding UTF8
                    $probe.phase=6
                }
                6 {
                    $done=@($all|Where-Object Text -eq 'Listo')[0];if(-not$done){return}
                    $probe.phase=7;(@($all|Where-Object Text -eq 'Cerrar')[0]).PerformClick()
                }
            }
            return
        }
        $check=@($dialog.Controls|Where-Object {$_ -is [Windows.Forms.CheckBox]})[0]
        $copy=@($dialog.Controls|Where-Object Text -eq 'Copiar enlace')[0]
        $renew=@($dialog.Controls|Where-Object Text -eq 'Nuevo QR')[0]
        $url=@($dialog.Controls|Where-Object {$_ -is [Windows.Forms.TextBox]})[0]
        $qr=@($dialog.Controls|Where-Object {$_ -is [Windows.Forms.PictureBox]})[0]
        switch($probe.phase){
            0 {
                if($copy.Enabled -or $renew.Enabled -or $url.Text){throw 'Los botones estan habilitados sin servicio.'}
                $check.Checked=$true
                $saved=Get-Content $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
                if(-not $saved.mobileView.enabled -or -not $saved.mobileView.token){throw 'La casilla no inicio automaticamente el acceso.'}
                $probe.token=$saved.mobileView.token
                @{url=('http://192.168.0.199:27844/m/'+$probe.token+'/')}|ConvertTo-Json|Set-Content (Join-Path $tempDirectory 'mobile-endpoint.json') -Encoding UTF8
            }
            1 {
                if(-not $qr.Image -or -not $copy.Enabled -or -not $url.Text.Contains($probe.token)){throw ('No aparecio el QR listo. '+(@($dialog.Controls|Where-Object {$_ -is [Windows.Forms.Label]}|ForEach-Object Text)-join ' / '))}
                foreach($control in $dialog.Controls){if($control.Right-gt$dialog.ClientSize.Width-or$control.Bottom-gt$dialog.ClientSize.Height){throw ('Control QR recortado: '+$control.Text)}}
                $captureDirectory=Join-Path $root 'build\tests';New-Item -ItemType Directory -Path $captureDirectory -Force|Out-Null
                $bitmap=New-Object Drawing.Bitmap($dialog.Width,$dialog.Height)
                try{$dialog.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$dialog.Width,$dialog.Height)));$bitmap.Save((Join-Path $captureDirectory 'studio-mobile.png'))}finally{$bitmap.Dispose()}
                $renew.PerformClick()
                $saved=Get-Content $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
                if($saved.mobileView.token -eq $probe.token){throw 'Nuevo QR no renovo el token.'}
                $probe.token=$saved.mobileView.token
                @{url=('http://192.168.0.199:27844/m/'+$probe.token+'/')}|ConvertTo-Json|Set-Content (Join-Path $tempDirectory 'mobile-endpoint.json') -Encoding UTF8
            }
            2 {
                if(-not $qr.Image -or -not $url.Text.Contains($probe.token)){throw 'No aparecio el QR renovado.'}
                $https=@($dialog.Controls|Where-Object Text -like 'Configurar HTTPS*')[0]
                if(-not$https.Enabled){throw 'HTTPS requires an unnecessary service toggle.'}
                $probe.phase=3;$https.PerformClick();return
            }
            7 {
                if(-not$url.Text.StartsWith('https://')-or-not$qr.Image){throw 'Returning from the assistant did not refresh the secure QR.'}
                $check.Checked=$false
                $saved=Get-Content $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
                if($saved.mobileView.enabled -or $qr.Image -or $copy.Enabled){throw 'Desactivar no retiro el acceso.'}
                $probe.passed=$true;$timer.Stop();$dialog.Close()
            }
        }
        $probe.phase++
    }catch{$probe.error=$_.Exception.ToString()+"`nPhase: "+$probe.phase+"`n"+$_.ScriptStackTrace;$timer.Stop();if($wizard){$wizard.Close()};if($dialog){$dialog.Close()}}
})
try{$timer.Start();Show-MobileDialog}finally{$timer.Dispose();$form.Dispose()}
if(-not $probe.passed){throw $probe.error}
Write-Output 'OK: real mobile dialog, nested HTTPS assistant, visible QR, close, parent refresh, activation/renewal/deactivation.'
