param([switch]$CertificateTest)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.MobileTls.psm1') -Force
$html=Get-AGMobileSetupHtml -Fingerprint 'AA:BB' -Name '<test>' -SecureUrl 'https://192.168.1.5:27844/m/test/'
if($html-notmatch '&lt;test&gt;' -or $html-notmatch 'href="../certificate"' -or $html-notmatch 'S26 Ultra' -or $html-notmatch 'iPhone / iPad' -or $html-notmatch 'https-secure.jpg' -or $html-notmatch 'https-untrusted.jpg'){throw 'Setup guidance or escaping missing.'}
$bridge=Get-Content -LiteralPath (Join-Path $root 'src\AlienGamerBridge.ps1') -Raw
if($bridge-notmatch 'AuthenticateAsServer' -or $bridge-notmatch 'Tls12' -or $bridge-match 'RemoteCertificateValidationCallback'){throw 'Production TLS boundary changed.'}
if(-not$CertificateTest){'OK: setup content, escaping and TLS boundaries.';return}
$directory=Join-Path $root ('build\tests\tls-'+[guid]::NewGuid().ToString('N'))
$created=New-Object 'System.Collections.Generic.List[string]'
try{
    $blocked=$false
    try{Get-AGMobileTlsIdentity -Directory $directory -IPAddress '192.168.1.5' -AllowAuthorityCreation $false|Out-Null}catch{$blocked=$true}
    if(-not$blocked){throw 'TLS silently created a new trust authority.'}
    $identity=Get-AGMobileTlsIdentity -Directory $directory -IPAddress '192.168.1.5'
    $record=Get-Content -LiteralPath (Join-Path $directory 'identity.json') -Raw|ConvertFrom-Json
    $created.Add($record.authority);$created.Add($record.server)
    if(Test-Path -LiteralPath ('Cert:\CurrentUser\Root\'+$record.authority)){throw 'Root trust installed without consent.'}
    $public=New-Object Security.Cryptography.X509Certificates.X509Certificate2($identity.PublicPath)
    if($public.HasPrivateKey){throw 'Private key was exported.'}
    if($identity.Certificate.Issuer-ne$public.Subject){throw 'Unexpected certificate issuer.'}
    $san=@($identity.Certificate.Extensions|Where-Object {$_.Oid.Value-eq'2.5.29.17'})[0].Format($false)
    if($san-notmatch '192.168.1.5'){throw 'Missing LAN IP SAN.'}
    $again=Get-AGMobileTlsIdentity -Directory $directory -IPAddress '192.168.1.5'
    if($again.Certificate.Thumbprint-ne$record.server){throw 'Stable address replaced its certificate.'}
    $changed=Get-AGMobileTlsIdentity -Directory $directory -IPAddress '192.168.1.6'
    $created.Add($changed.Certificate.Thumbprint)
    if($changed.Fingerprint-ne$identity.Fingerprint -or $changed.Certificate.Thumbprint-eq$record.server){throw 'Address renewal did not preserve CA and replace leaf.'}
    'OK: certificates, public-only export, no root trust, stable identity and IP renewal.'
}finally{
    # Only this test's exact generated certificates; never user trust stores.
    foreach($thumb in $created|Select-Object -Unique){if($thumb-match'^[0-9A-F]{40}$'){Remove-Item -LiteralPath ('Cert:\CurrentUser\My\'+$thumb) -DeleteKey -ErrorAction SilentlyContinue}}
}
