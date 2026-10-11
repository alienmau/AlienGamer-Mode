$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$root=Split-Path -Parent $PSScriptRoot
$directory=Join-Path $root ('build\tests\wizard-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory -Force|Out-Null
$configPath=Join-Path $directory 'AlienGamerMode.json'
$token='0123456789abcdef0123456789abcdef'
$configuration=@{language='es-MX';mobileView=@{enabled=$true;port=27844;token=$token;modules=@('ram','vram')}}
$configuration|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $configPath -Encoding UTF8
$probe=[pscustomobject]@{Phase=0;Passed=$false;Error='';Deadline=(Get-Date).AddSeconds(15)}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=400
$timer.Add_Tick({
    $window=@([Windows.Forms.Application]::OpenForms|Where-Object {$_.Text-like'Conexi*n segura*'})[0]
    if(-not$window){return}
    try{
        if((Get-Date)-gt$probe.Deadline){throw 'Wizard test timed out.'}
        $all=New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'
        $collect={param($control) foreach($child in $control.Controls){$all.Add($child);& $collect $child}}
        & $collect $window
        $prepare=@($all|Where-Object Text -eq 'Preparar certificado')[0]
        $consent=@($all|Where-Object Text -eq 'Entiendo el permiso y quiero preparar HTTPS.')[0]
        $installed=@($all|Where-Object Text -eq 'Comparé la huella e instalé el certificado en mi dispositivo.')[0]
        switch($probe.Phase){
            0 {
                if(-not$prepare-or$prepare.Enabled){throw 'Missing consent gate.'}
                $consent.Checked=$true;$prepare.PerformClick()
                $saved=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
                if(-not$saved.mobileView.tls.prepared-or$saved.mobileView.tls.enabled){throw 'Preparation activated HTTPS prematurely.'}
                @{url=('http://192.168.1.5:27844/m/'+$token+'/');certificateReady=$true;https=$false;fingerprint='AA:BB';certificateName='Test CA'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $directory 'mobile-endpoint.json') -Encoding UTF8
                $probe.Phase=1
            }
            1 {
                $activate=@($all|Where-Object Text -eq 'Activar HTTPS')[0]
                if(-not$activate){return}
                if($activate.Enabled){throw 'Installation confirmation was skipped.'}
                $installed.Checked=$true;$activate.PerformClick()
                $saved=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
                if(-not$saved.mobileView.tls.enabled-or$saved.mobileView.token-ne$token-or@($saved.mobileView.modules).Count-ne2){throw 'Activation lost mobile preferences.'}
                @{url=('https://192.168.1.5:27844/m/'+$token+'/');certificateReady=$true;https=$true;fingerprint='AA:BB';certificateName='Test CA'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $directory 'mobile-endpoint.json') -Encoding UTF8
                $probe.Phase=2
            }
            2 {
                $done=@($all|Where-Object Text -eq 'Listo')[0]
                if(-not$done){return}
                if(-not$done.Enabled){throw 'Ready action is disabled.'}
                $probe.Passed=$true;$timer.Stop();$done.PerformClick()
            }
        }
    }catch{$probe.Error=$_.Exception.ToString();$timer.Stop();$window.Close()}
})
try{$timer.Start();& (Join-Path $root 'src\Show-MobileHttpsWizard.ps1') -ConfigPath $configPath -Language es-MX}finally{$timer.Dispose()}
if(-not$probe.Passed){throw $probe.Error}
'OK: consent, public setup, manual install confirmation, HTTPS activation and preferences.'
