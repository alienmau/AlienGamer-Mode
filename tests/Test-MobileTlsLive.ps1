$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\AlienGamer.Process.psm1') -Force
$directory=Join-Path $root ('build\tests\tls-live-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory -Force|Out-Null
$profilePath=Join-Path $directory 'profile.json';$configPath=Join-Path $directory 'AlienGamerMode.json'
@{bridgePort=27847;unavailableValue=-1;cores=@();mappings=@{}}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $profilePath -Encoding UTF8
$token='0123456789abcdef0123456789abcdef'
$config=@{displayViews=@(@{id='first';enabled=$true},@{id='second';enabled=$true});mobileView=@{enabled=$true;port=27848;token=$token;modules=@('ram','timer');tls=@{prepared=$true;enabled=$false}}}
[IO.File]::WriteAllText((Join-Path $directory 'session-timer-AlienGamerMode-Views-second.txt'),("configured=1`nbaseDuration=120`nduration=120`nextraStep=5`nextraCount=0`nstatus=running`nremaining=120`ndeadline="+([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+120)+"`n"))
$config|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $configPath -Encoding UTF8
Add-Type @'
using System;
using System.Net.Sockets;
using System.Net.Security;
using System.Security.Authentication;
using System.Text;
using System.IO;
public static class AGTlsTestClient {
 public static string Get(string ip,int port,string path,string expectedThumb) {
  return Request(ip,port,path,expectedThumb,null,null);
 }
 public static string Request(string ip,int port,string path,string expectedThumb,string body,string origin) {
  using(var client=new TcpClient(ip,port)) {
   client.ReceiveTimeout=5000;client.SendTimeout=5000;
   // Test-specific pin: accepts only the generated fixture leaf, never arbitrary TLS.
   using(var tls=new SslStream(client.GetStream(),false,(s,c,chain,errors)=>
      c!=null && c.GetCertHashString()==expectedThumb &&
      (errors & SslPolicyErrors.RemoteCertificateNameMismatch)==0)) {
    tls.ReadTimeout=5000;tls.WriteTimeout=5000;
    tls.AuthenticateAsClient(ip,null,SslProtocols.Tls12,false);
    byte[] request=Encoding.ASCII.GetBytes((body==null?"GET":"POST")+" "+path+" HTTP/1.1\r\nHost: "+ip+":"+port+"\r\nConnection: close\r\n"+(body==null?"":"Origin: "+origin+"\r\nX-AlienGamer-Timer: 1\r\nContent-Type: application/json\r\nContent-Length: "+Encoding.UTF8.GetByteCount(body)+"\r\n")+"\r\n"+(body??""));
    tls.Write(request,0,request.Length);tls.Flush();
    using(var reader=new StreamReader(tls)) return reader.ReadToEnd();
   }
  }
 }
}
'@
$process=$null
try{
    $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $root 'src\AlienGamerBridge.ps1')+'" -ProfilePath "'+$profilePath+'" -StateDirectory "'+$directory+'"'
    $process=Start-AGHiddenProcess 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList $arguments -RedirectStandardError (Join-Path $directory 'stderr.log') -PassThru
    $endpointPath=Join-Path $directory 'mobile-endpoint.json';$deadline=(Get-Date).AddSeconds(30)
    while(-not(Test-Path -LiteralPath $endpointPath)-and(Get-Date)-lt$deadline){Start-Sleep -Milliseconds 200}
    if(-not(Test-Path -LiteralPath $endpointPath)){throw 'Local setup did not start. Check fixture bridge.log.'}
    $endpoint=Get-Content -LiteralPath $endpointPath -Raw|ConvertFrom-Json
    if(-not$endpoint.certificateReady-or$endpoint.https){throw 'Expected HTTP preparation, not automatic HTTPS.'}
    $setup=Invoke-WebRequest -Uri ($endpoint.url+'setup/') -UseBasicParsing -TimeoutSec 5
    if($setup.Content-notmatch[regex]::Escape($endpoint.fingerprint)){throw 'Setup fingerprint missing.'}
    $download=Invoke-WebRequest -Uri ($endpoint.url+'certificate') -UseBasicParsing -TimeoutSec 5
    if($download.Headers['Content-Type']-notmatch'application/pkix-cert'){throw 'Public certificate download missing.'}
    $config.mobileView.tls.enabled=$true
    $config|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $configPath -Encoding UTF8
    $deadline=(Get-Date).AddSeconds(12)
    do{Start-Sleep -Milliseconds 200;$endpoint=try{Get-Content -LiteralPath $endpointPath -Raw|ConvertFrom-Json}catch{$null}}while((Get-Date)-lt$deadline-and(-not$endpoint-or-not$endpoint.https))
    if(-not$endpoint.https){throw 'HTTPS did not activate.'}
    $record=Get-Content -LiteralPath (Join-Path $directory 'MobileTls\identity.json') -Raw|ConvertFrom-Json
    $uri=[uri]$endpoint.url
    $page=[AGTlsTestClient]::Get($uri.Host,$uri.Port,$uri.AbsolutePath,$record.server)
    if($page-notmatch'HTTP/1.1 200 OK'-or$page-notmatch'ALIENGAMER MODE'){throw 'TLS page response failed.'}
    $status=[AGTlsTestClient]::Get($uri.Host,$uri.Port,($uri.AbsolutePath+'status'),$record.server)
    if($status-notmatch'HTTP/1.1 200 OK'-or$status-notmatch'ramTotalMB'){throw 'TLS status failed.'}
    $timerStatus=($status -split "`r`n`r`n",2)[1]|ConvertFrom-Json
    if($timerStatus.timer.status-ne'running'-or$timerStatus.timer.remaining-le0-or$timerStatus.timer.duration-ne120){throw 'HTTPS did not deliver the migrated shared timer.'}
    $command=@{action='pause';revision=$timerStatus.timer.revision}|ConvertTo-Json -Compress
    $origin='https://'+$uri.Host+':'+$uri.Port
    $denied=[AGTlsTestClient]::Request($uri.Host,$uri.Port,($uri.AbsolutePath+'timer'),$record.server,$command,$origin)
    if($denied-notmatch'HTTP/1.1 403'){throw 'Read-only control was not denied.'}
    $config.mobileView.allowTimerControl=$true
    $config|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $configPath -Encoding UTF8
    $badOrigin=[AGTlsTestClient]::Request($uri.Host,$uri.Port,($uri.AbsolutePath+'timer'),$record.server,$command,'https://example.invalid')
    if($badOrigin-notmatch'HTTP/1.1 403'){throw 'Foreign origin accepted.'}
    $paused=[AGTlsTestClient]::Request($uri.Host,$uri.Port,($uri.AbsolutePath+'timer'),$record.server,$command,$origin)
    if($paused-notmatch'HTTP/1.1 200'-or(($paused-split"`r`n`r`n",2)[1]|ConvertFrom-Json).status-ne'paused'){throw 'HTTPS timer pause failed.'}
    $duplicate=[AGTlsTestClient]::Request($uri.Host,$uri.Port,($uri.AbsolutePath+'timer'),$record.server,$command,$origin)
    if($duplicate-notmatch'HTTP/1.1 409'){throw 'Duplicate timer command accepted.'}
    $image=[AGTlsTestClient]::Get($uri.Host,$uri.Port,($uri.AbsolutePath+'examples/https-secure.jpg'),$record.server)
    if($image-notmatch'Content-Type: image/jpeg'){throw 'Setup example image unavailable.'}
    $bad=[AGTlsTestClient]::Get($uri.Host,$uri.Port,($uri.AbsolutePath-replace$token,('0'*32)),$record.server)
    if($bad-notmatch'HTTP/1.1 404'){throw 'TLS accepted an invalid QR token.'}
    $rejected=$false
    try{[AGTlsTestClient]::Get($uri.Host,$uri.Port,$uri.AbsolutePath,('0'*40))|Out-Null}catch{$rejected=$true}
    if(-not$rejected){throw 'Client accepted a wrong certificate pin.'}
    if((Invoke-RestMethod -Uri 'http://127.0.0.1:27847/health').ok-ne$true){throw 'Desktop loopback was affected by TLS.'}
    'OK: HTTP setup/download, TLS handshake/page/status, QR rejection, certificate pin and desktop isolation.'
}finally{
    if($process){if(-not$process.HasExited){$process.Kill();$process.WaitForExit()};$process.Dispose()}
    $metadataPath=Join-Path $directory 'MobileTls\identity.json'
    if(Test-Path -LiteralPath $metadataPath){
        $record=Get-Content -LiteralPath $metadataPath -Raw|ConvertFrom-Json
        foreach($thumb in @($record.authority,$record.server)){if($thumb-match'^[0-9A-F]{40}$'){Remove-Item -LiteralPath ('Cert:\CurrentUser\My\'+$thumb) -DeleteKey -ErrorAction SilentlyContinue}}
    }
}
