param([Parameter(Mandatory)][string]$ConfigPath,$Owner,[string]$Language='es-MX',[switch]$Preview,[ValidateRange(0,3)][int]$PreviewPhase=0,[string]$ExportScreenshotPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.UI.psm1') -Force
$isEnglish=$Language-eq'en-US'
$wizardText={param([string]$Spanish,[string]$English) if($isEnglish){$English}else{$Spanish}}.GetNewClosure()
$tlsUidirectory=Split-Path -Parent $ConfigPath
$tlsUiassetRoot=$PSScriptRoot
$tlsUiwizard=New-Object Windows.Forms.Form
$tlsUiwizard.Text=& $wizardText 'Conexión segura · celular o tablet' 'Secure connection · phone or tablet'
$tlsUiwizard.StartPosition='CenterParent';$tlsUiwizard.MinimumSize=New-Object Drawing.Size(620,640)
$tlsUiwizard.ClientSize=New-Object Drawing.Size(680,690);$tlsUiwizard.AutoScaleMode='Dpi';$tlsUiwizard.MaximizeBox=$false
$tlsUilayout=New-Object Windows.Forms.TableLayoutPanel;$tlsUilayout.Dock='Fill';$tlsUilayout.Padding=New-Object Windows.Forms.Padding(24);$tlsUilayout.ColumnCount=1;$tlsUilayout.RowCount=4
[void]$tlsUilayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
[void]$tlsUilayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
[void]$tlsUilayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
[void]$tlsUilayout.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')));$tlsUiwizard.Controls.Add($tlsUilayout)
$tlsUiheading=New-Object Windows.Forms.Label;$tlsUiheading.AutoSize=$true;$tlsUiheading.Text=& $wizardText 'HTTPS, paso a paso' 'HTTPS, step by step';$tlsUiheading.Font=New-Object Drawing.Font('Segoe UI',17,[Drawing.FontStyle]::Bold);$tlsUilayout.Controls.Add($tlsUiheading,0,0)
$tlsUisteps=New-Object Windows.Forms.Label;$tlsUisteps.AutoSize=$true;$tlsUisteps.Margin=New-Object Windows.Forms.Padding(0,12,0,20);$tlsUilayout.Controls.Add($tlsUisteps,0,1)
$tlsUibody=New-Object Windows.Forms.FlowLayoutPanel;$tlsUibody.Dock='Fill';$tlsUibody.FlowDirection='TopDown';$tlsUibody.WrapContents=$false;$tlsUibody.AutoScroll=$true;$tlsUilayout.Controls.Add($tlsUibody,0,2)
$tlsUifooter=New-Object Windows.Forms.FlowLayoutPanel;$tlsUifooter.AutoSize=$true;$tlsUifooter.Dock='Fill';$tlsUifooter.FlowDirection='RightToLeft';$tlsUifooter.WrapContents=$true;$tlsUifooter.Padding=New-Object Windows.Forms.Padding(0,20,0,0);$tlsUilayout.Controls.Add($tlsUifooter,0,3)
$tlsUinext=New-Object AlienGamer.Desktop.RoundedButton;$tlsUinext.Size=New-Object Drawing.Size(250,44);$tlsUinext.Margin=New-Object Windows.Forms.Padding(8,0,0,0);$tlsUifooter.Controls.Add($tlsUinext)
$tlsUicancel=New-Object AlienGamer.Desktop.RoundedButton;$tlsUicancel.Text=& $wizardText 'Cerrar' 'Close';$tlsUicancel.Size=New-Object Drawing.Size(108,44);$tlsUicancel.Add_Click(({$tlsUiwizard.Close()}.GetNewClosure()));$tlsUifooter.Controls.Add($tlsUicancel)
$tlsUiback=New-Object AlienGamer.Desktop.RoundedButton;$tlsUiback.Text=& $wizardText 'Volver a HTTP' 'Return to HTTP';$tlsUiback.Size=New-Object Drawing.Size(145,44);$tlsUifooter.Controls.Add($tlsUiback)
$tlsUiintro=New-Object Windows.Forms.Label;$tlsUiintro.AutoSize=$true;$tlsUiintro.MaximumSize=New-Object Drawing.Size(590,0);$tlsUiintro.Margin=New-Object Windows.Forms.Padding(0,0,0,16);$tlsUibody.Controls.Add($tlsUiintro)
$tlsUiconsent=New-Object Windows.Forms.CheckBox;$tlsUiconsent.AutoSize=$true;$tlsUiconsent.MaximumSize=New-Object Drawing.Size(590,0);$tlsUiconsent.Text=& $wizardText 'Entiendo el permiso y quiero preparar HTTPS.' 'I understand the permission and want to prepare HTTPS.';$tlsUiconsent.Margin=New-Object Windows.Forms.Padding(0,0,0,16);$tlsUibody.Controls.Add($tlsUiconsent)
$tlsUifingerprint=New-Object Windows.Forms.TextBox;$tlsUifingerprint.ReadOnly=$true;$tlsUifingerprint.Multiline=$true;$tlsUifingerprint.Width=570;$tlsUifingerprint.Height=72;$tlsUifingerprint.AccessibleName='SHA-256';$tlsUibody.Controls.Add($tlsUifingerprint)
$tlsUiqr=New-Object Windows.Forms.PictureBox;$tlsUiqr.Size=New-Object Drawing.Size(210,210);$tlsUiqr.SizeMode='Zoom';$tlsUiqr.AccessibleName=& $wizardText 'QR de preparación del dispositivo' 'Device setup QR';$tlsUibody.Controls.Add($tlsUiqr)
$tlsUiinstalled=New-Object Windows.Forms.CheckBox;$tlsUiinstalled.AutoSize=$true;$tlsUiinstalled.MaximumSize=New-Object Drawing.Size(590,0);$tlsUiinstalled.Text=& $wizardText 'Comparé la huella e instalé el certificado en mi dispositivo.' 'I compared the fingerprint and installed the certificate on my device.';$tlsUibody.Controls.Add($tlsUiinstalled)
$tlsUistatus=New-Object Windows.Forms.Label;$tlsUistatus.AutoSize=$true;$tlsUistatus.MaximumSize=New-Object Drawing.Size(590,0);$tlsUistatus.AccessibleName=& $wizardText 'Estado de conexión' 'Connection status';$tlsUistatus.Margin=New-Object Windows.Forms.Padding(0,16,0,12);$tlsUibody.Controls.Add($tlsUistatus)
$tlsUistate=[pscustomobject]@{Phase=0;Waiting=$false;Started=Get-Date;Endpoint=$null;QrUrl=''}
$tlsUipersist={param([bool]$Enable,[bool]$Prepare)
    $tlsUidisk=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
    if(-not $tlsUidisk.mobileView.enabled){throw (& $wizardText 'Primero activa el monitor web.' 'First enable the web monitor.')}
    $tlsUidisk.mobileView|Add-Member NoteProperty tls ([pscustomobject]@{enabled=$Enable;prepared=$Prepare}) -Force
    $tlsUitemp=$ConfigPath+'.https.tmp'
    [IO.File]::WriteAllText($tlsUitemp,($tlsUidisk|ConvertTo-Json -Depth 24),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tlsUitemp -Destination $ConfigPath -Force
}.GetNewClosure()
$tlsUirender={
    $tlsUisteps.Text=& $wizardText (('Paso {0} de 4 · Permiso → Preparar → Instalar → Conectar' -f ($tlsUistate.Phase+1))) (('Step {0} of 4 · Permission → Prepare → Install → Connect' -f ($tlsUistate.Phase+1)))
    $tlsUiconsent.Visible=$tlsUistate.Phase-eq0;$tlsUifingerprint.Visible=$tlsUistate.Phase-ge2;$tlsUiqr.Visible=$tlsUistate.Phase-ge2;$tlsUiinstalled.Visible=$tlsUistate.Phase-eq2
    $tlsUiback.Enabled=-not$tlsUistate.Waiting
    switch($tlsUistate.Phase){
        0 {$tlsUiintro.Text=& $wizardText 'HTTPS cifra el monitor dentro de tu red. Prepararemos un certificado propio para esta laptop. No instalaremos confianza automáticamente. En el celular, confiar en una autoridad raíz es un permiso sensible y puede abarcar otros certificados firmados por ella. Puedes conservar HTTP o retirar el certificado después.' 'HTTPS encrypts the monitor on your local network. We will prepare a certificate unique to this laptop. Trust is never installed automatically. Trusting a root authority on your phone is sensitive and can include other certificates it signs. You may keep HTTP or remove the certificate later.';$tlsUinext.Text=& $wizardText 'Preparar certificado' 'Prepare certificate';$tlsUinext.Enabled=$tlsUiconsent.Checked}
        1 {$tlsUiintro.Text=& $wizardText 'Preparando el certificado en la laptop. Las claves privadas se quedan aquí; sólo se compartirá el certificado público. Mantén activo el monitor.' 'Preparing the certificate on your laptop. Private keys stay here; only the public certificate is shared. Keep the monitor active.';$tlsUinext.Text=& $wizardText 'Preparando…' 'Preparing…';$tlsUinext.Enabled=$false}
        2 {$tlsUiintro.Text=& $wizardText 'Escanea este QR para ver las instrucciones Android/Samsung o iPhone/iPad. Antes de instalar, compara la huella SHA-256 con la que aparece abajo. Si difiere, detente. La página de preparación aún usa HTTP: la comparación con esta laptop es esencial. Si no puedes instalarlo, vuelve a HTTP.' 'Scan this QR for Android/Samsung or iPhone/iPad instructions. Before installing, compare its SHA-256 fingerprint with the one below. If it differs, stop. Setup still uses HTTP: comparing with this laptop is essential. If installation is blocked, return to HTTP.';$tlsUinext.Text=& $wizardText 'Activar HTTPS' 'Activate HTTPS';$tlsUinext.Enabled=$tlsUiinstalled.Checked -and -not$tlsUistate.Waiting}
        3 {$tlsUiintro.Text=& $wizardText 'HTTPS está activo en la laptop. Escanea el QR del monitor. Comprueba que el navegador no muestra advertencias; nunca las ignores. Luego, en Editar, activa Mantener pantalla encendida si está disponible. Esta ventana no puede confirmar que el teléfono confía en el certificado. Si falla, vuelve a HTTP. Desactivar HTTPS no elimina la confianza del celular; retira esta CA desde sus ajustes de certificados o su perfil de iOS.' 'HTTPS is active on the laptop. Scan the monitor QR and check that the browser shows no warnings; never bypass them. In Edit, enable Keep screen awake if available. This window cannot confirm phone trust. If it fails, return to HTTP. Switching HTTPS off does not remove phone trust; remove this CA from certificate settings or its iOS profile.';$tlsUinext.Text=& $wizardText 'Listo' 'Done';$tlsUinext.Enabled=$true}
    }
}.GetNewClosure()
$tlsUidrawQr={param([string]$Url)
    if($tlsUistate.QrUrl-eq$Url){return}
    $tlsUiassembly=Join-Path $tlsUiassetRoot 'assets\QRCoder.dll'
    if(-not(Test-Path -LiteralPath $tlsUiassembly)){$tlsUiassembly=Join-Path (Split-Path -Parent $tlsUiassetRoot) 'assets\QRCoder.dll'}
    Add-Type -Path $tlsUiassembly
    $tlsUigenerator=[QRCoder.QRCodeGenerator]::new();$tlsUidata=$tlsUigenerator.CreateQrCode($Url,[QRCoder.QRCodeGenerator+ECCLevel]::Q);$tlsUirenderer=[QRCoder.QRCode]::new($tlsUidata)
    try{if($tlsUiqr.Image){$tlsUiqr.Image.Dispose()};$tlsUiqr.Image=$tlsUirenderer.GetGraphic(4);$tlsUistate.QrUrl=$Url}finally{$tlsUirenderer.Dispose();$tlsUidata.Dispose();$tlsUigenerator.Dispose()}
}.GetNewClosure()
$tlsUiconsent.Add_CheckedChanged(({& $tlsUirender}.GetNewClosure()));$tlsUiinstalled.Add_CheckedChanged(({& $tlsUirender}.GetNewClosure()))
$tlsUinext.Add_Click(({
    try{
        if($Preview){return}
        switch($tlsUistate.Phase){
            0 {& $tlsUipersist $false $true;$tlsUistate.Phase=1;$tlsUistate.Waiting=$true;$tlsUistate.Started=Get-Date;$tlsUistatus.Text=& $wizardText 'Esperando al servicio local…' 'Waiting for the local service…'}
            2 {& $tlsUipersist $true $true;$tlsUistate.Waiting=$true;$tlsUistate.Started=Get-Date;$tlsUistatus.Text=& $wizardText 'Activando HTTPS…' 'Activating HTTPS…'}
            3 {$tlsUiwizard.Close()}
        }
    }catch{$tlsUistatus.Text=$_.Exception.Message}
    & $tlsUirender
}.GetNewClosure()))
$tlsUiback.Add_Click(({
    try{
        if(-not$Preview){
            $tlsUidisk=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
            $tlsUiprepared=$tlsUidisk.mobileView.PSObject.Properties['tls'] -and [bool]$tlsUidisk.mobileView.tls.prepared
            & $tlsUipersist $false ([bool]$tlsUiprepared)
        }
        $tlsUiwizard.Close()
    }catch{$tlsUistatus.Text=$_.Exception.Message}
}.GetNewClosure()))
$tlsUitimer=New-Object Windows.Forms.Timer;$tlsUitimer.Interval=500
$tlsUitimer.Add_Tick(({
    if(-not $tlsUistate.Waiting){return}
    try{
        $tlsUiendpointPath=Join-Path $tlsUidirectory 'mobile-endpoint.json'
        $tlsUiendpoint=if(Test-Path -LiteralPath $tlsUiendpointPath){Get-Content -LiteralPath $tlsUiendpointPath -Raw -Encoding UTF8|ConvertFrom-Json}else{$null}
        $tlsUicurrent=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
        if($tlsUiendpoint -and $tlsUiendpoint.certificateReady -and $tlsUicurrent.mobileView.token -and ([string]$tlsUiendpoint.url).Contains([string]$tlsUicurrent.mobileView.token) -and (($tlsUistate.Phase-eq1 -and -not$tlsUiendpoint.https) -or ($tlsUistate.Phase-eq2 -and $tlsUiendpoint.https))){
            $tlsUistate.Endpoint=$tlsUiendpoint;$tlsUifingerprint.Text=$tlsUiendpoint.fingerprint
            if($tlsUistate.Phase-eq1){& $tlsUidrawQr ($tlsUiendpoint.url+'setup/');$tlsUistate.Phase=2}else{& $tlsUidrawQr $tlsUiendpoint.url;$tlsUistate.Phase=3}
            $tlsUistate.Waiting=$false
            $tlsUistatus.Text=$tlsUiendpoint.certificateName;& $tlsUirender
        }elseif(((Get-Date)-$tlsUistate.Started).TotalSeconds-gt30){
            $tlsUistate.Waiting=$false;$tlsUistate.Phase=0;$tlsUiconsent.Checked=$false
            $tlsUistatus.Text=& $wizardText 'No respondió el servicio. Comprueba que el monitor esté activo. Puedes cerrar y reintentar; no ignores avisos de certificado.' 'The service did not respond. Check that the monitor is active, then close and retry. Never bypass certificate warnings.'
            & $tlsUirender
        }
    }catch{
        $tlsUistate.Waiting=$false;$tlsUistate.Phase=0;$tlsUiconsent.Checked=$false
        & $tlsUirender
        $tlsUistatus.Text=(& $wizardText 'No se pudo preparar el QR. Puedes cerrar o reintentar. Detalle: ' 'Could not prepare the QR. Close or retry. Details: ')+$_.Exception.Message
    }
}.GetNewClosure()))
Set-AGWindowTheme $tlsUiwizard;Set-AGPrimaryButton $tlsUinext
$tlsUiwizard.CancelButton=$tlsUicancel;$tlsUiwizard.AcceptButton=$tlsUinext
if($Preview){
    $tlsUistate.Phase=$PreviewPhase
    if($PreviewPhase-ge2){$tlsUifingerprint.Text=('AA:'*31)+'AA';& $tlsUidrawQr 'https://192.0.2.1:27844/example/'}
}else{
    try{
        $tlsUidisk=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
        if($tlsUidisk.mobileView.PSObject.Properties['tls'] -and $tlsUidisk.mobileView.tls.enabled){
            # Reopening configured HTTPS is a summary, not a new trust ceremony.
            $tlsUistate.Phase=3
            $tlsUiheading.Text=& $wizardText 'Tu conexión HTTPS' 'Your HTTPS connection'
            $tlsUistatus.Text=& $wizardText 'HTTPS configurado. No repitas la instalación si este dispositivo ya reconoce la autoridad. Si falta el QR, el servicio aún no ha entregado el enlace.' 'HTTPS is configured. Do not repeat installation if this device already trusts the authority. If the QR is missing, the service has not provided its link yet.'
        }
        $tlsUiendpointPath=Join-Path $tlsUidirectory 'mobile-endpoint.json'
        if(Test-Path -LiteralPath $tlsUiendpointPath){
            $tlsUiendpoint=Get-Content -LiteralPath $tlsUiendpointPath -Raw -Encoding UTF8|ConvertFrom-Json
            if($tlsUidisk.mobileView.tls.enabled -and $tlsUiendpoint.https -and $tlsUiendpoint.certificateReady -and ([string]$tlsUiendpoint.url).Contains([string]$tlsUidisk.mobileView.token)){
                $tlsUistate.Phase=3;$tlsUifingerprint.Text=$tlsUiendpoint.fingerprint;& $tlsUidrawQr $tlsUiendpoint.url
            }
        }
    }catch{$tlsUistatus.Text=(& $wizardText 'No se pudo leer el estado de conexión: ' 'Could not read connection state: ')+$_.Exception.Message}
}
& $tlsUirender
$tlsUicapture=$null
if($Preview -and $ExportScreenshotPath){
    $tlsUicapture=New-Object Windows.Forms.Timer;$tlsUicapture.Interval=600
    $tlsUicapture.Add_Tick({
        $tlsUicapture.Stop()
        $tlsUibitmap=New-Object Drawing.Bitmap($tlsUiwizard.Width,$tlsUiwizard.Height)
        try{$tlsUiwizard.DrawToBitmap($tlsUibitmap,(New-Object Drawing.Rectangle(0,0,$tlsUiwizard.Width,$tlsUiwizard.Height)));$tlsUibitmap.Save($ExportScreenshotPath)}finally{$tlsUibitmap.Dispose();$tlsUiwizard.Close()}
    });$tlsUicapture.Start()
}
try{$tlsUitimer.Start();[void]$tlsUiwizard.ShowDialog($Owner)}finally{$tlsUitimer.Stop();$tlsUitimer.Dispose();if($tlsUicapture){$tlsUicapture.Dispose()};if($tlsUiqr.Image){$tlsUiqr.Image.Dispose()};$tlsUiwizard.Dispose()}
