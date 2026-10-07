param([switch]$Live)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$html=Get-Content -LiteralPath (Join-Path $root 'src\mobile\index.html') -Raw -Encoding UTF8
$bridge=Get-Content -LiteralPath (Join-Path $root 'src\AlienGamerBridge.ps1') -Raw -Encoding UTF8
if($html -notmatch 'requestFullscreen\(' -or $html -notmatch 'exitFullscreen\(' -or $html -match 'OFF</button>' -or $html -notmatch '@media\(orientation:landscape\)'){throw 'La vista móvil no es responsiva o no separa pantalla completa de OFF.'}
if($bridge -notmatch 'Test-SameSubnet' -or $bridge -notmatch 'mobileToken' -or $bridge -match 'IPAddress\]::Any' -or $bridge -notmatch 'Referrer-Policy: no-referrer'){throw 'El servicio móvil no está limitado a la red local y al enlace QR.'}
Import-Module (Join-Path $root 'src\AlienGamer.MultiDisplay.psm1') -Force
$monitors=@(
    [pscustomobject]@{deviceName='\\.\DISPLAY1';pnpDeviceId='MONITOR\ASUS';friendlyName='ASUS'},
    [pscustomobject]@{deviceName='\\.\DISPLAY2';pnpDeviceId='MONITOR\LENOVO';friendlyName='Lenovo'}
)
$view=[pscustomobject]@{monitorId='MONITOR\LENOVO';monitorDeviceName='\\.\DISPLAY1'}
if((Resolve-AGViewMonitor -View $view -Monitors $monitors).friendlyName -ne 'Lenovo'){throw 'La vista siguió el número DISPLAY en lugar de la identidad física.'}
$view.monitorId='MONITOR\MISSING'
if(Resolve-AGViewMonitor -View $view -Monitors $monitors){throw 'Una pantalla desconectada fue reasignada a otro dispositivo.'}
Add-Type -Path (Join-Path $root 'assets\QRCoder.dll')
$generator=[QRCoder.QRCodeGenerator]::new()
$data=$generator.CreateQrCode('http://192.168.0.199:27844/m/0123456789abcdef0123456789abcdef/',[QRCoder.QRCodeGenerator+ECCLevel]::Q)
$renderer=[QRCoder.QRCode]::new($data)
$bitmap=$renderer.GetGraphic(4)
if($bitmap.Width -lt 100){throw 'No se generó un QR legible.'}
$bitmap.Dispose();$renderer.Dispose();$data.Dispose();$generator.Dispose()
Write-Output 'OK: asociación física, privacidad LAN, interfaz responsiva y QR local.'

if(-not $Live){return}
$profile=Join-Path $env:LOCALAPPDATA 'AlienGamerMode\profile.json'
if(-not(Test-Path -LiteralPath $profile)){throw 'La prueba en vivo requiere un perfil de sensores instalado.'}
$dir=Join-Path $env:TEMP ("AlienGamer-mobile-smoke-$PID")
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$token='0123456789abcdef0123456789abcdef'
$config=[ordered]@{mobileView=[ordered]@{enabled=$true;port=27846;token=$token;modules=@('ram','vram','system')}}
$config|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $dir 'AlienGamerMode.json') -Encoding UTF8
$process=$null
try{
    $args="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $root 'src\AlienGamerBridge.ps1')`" -ProfilePath `"$profile`" -Port 27845 -StateDirectory `"$dir`""
    $process=Start-Process powershell.exe -WindowStyle Hidden -ArgumentList $args -PassThru
    $endpointFile=Join-Path $dir 'mobile-endpoint.json'
    $deadline=(Get-Date).AddSeconds(12)
    while((Get-Date) -lt $deadline -and -not(Test-Path -LiteralPath $endpointFile)){Start-Sleep -Milliseconds 300}
    if(-not(Test-Path -LiteralPath $endpointFile)){throw "No arrancó el acceso LAN. Log: $(Get-Content (Join-Path $dir 'bridge.log') -Raw -ErrorAction SilentlyContinue)"}
    $url=[string](Get-Content $endpointFile -Raw|ConvertFrom-Json).url
    $page=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 6
    if($page.StatusCode -ne 200 -or $page.Content -notmatch 'ALIENGAMER MODE'){throw 'La página móvil no respondió.'}
    try{$status=Invoke-RestMethod -Uri ($url+'status') -TimeoutSec 6;if(-not $status.timestamp -or @($status.modules) -notcontains 'ram' -or $status.ramTotalMB -le 0){throw 'Faltan los módulos o la lectura RAM.'}}
    catch{throw "Falló la actualización en vivo: $($_.Exception.Message)"}
    try{Invoke-WebRequest -Uri ($url -replace $token,'00000000000000000000000000000000') -UseBasicParsing -TimeoutSec 6|Out-Null;throw 'El enlace sin token obtuvo acceso.'}catch [System.Net.WebException]{if(-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404){throw}}
    $newToken='fedcba9876543210fedcba9876543210'
    $config.mobileView.token=$newToken
    $config|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $dir 'AlienGamerMode.json') -Encoding UTF8
    $deadline=(Get-Date).AddSeconds(9)
    do{
        Start-Sleep -Milliseconds 250
        $newUrl=try{[string](Get-Content $endpointFile -Raw|ConvertFrom-Json).url}catch{''}
    }while((Get-Date) -lt $deadline -and -not $newUrl.Contains($newToken))
    if(-not $newUrl.Contains($newToken)){throw 'El nuevo QR no reemplazó al anterior.'}
    if((Invoke-WebRequest -Uri $newUrl -UseBasicParsing -TimeoutSec 6).StatusCode -ne 200){throw 'El QR renovado no abrió la página.'}
    try{Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 6|Out-Null;throw 'El QR anterior siguió activo.'}catch [System.Net.WebException]{if(-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404){throw}}
    Write-Output "OK: servicio LAN en vivo, datos y rechazo de enlace no autorizado ($url)."
}finally{
    if($process -and -not $process.HasExited){Stop-Process -Id $process.Id -Force}
    if($process){$process.Dispose()}
}
