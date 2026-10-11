param([Parameter(Mandatory)][string]$ConfigPath)
$ErrorActionPreference='Stop'
$disk=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
if($disk.PSObject.Properties['mobileView']){throw 'Mobile preferences already exist; do not replace them.'}
$backup=$ConfigPath+'.before-mobile-recovery-'+(Get-Date).ToString('yyyyMMdd-HHmmss')+'.bak'
Copy-Item -LiteralPath $ConfigPath -Destination $backup -ErrorAction Stop
$bytes=New-Object byte[] 24
$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
$token=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
$identity=Join-Path (Split-Path -Parent $ConfigPath) 'MobileTls\identity.json'
$ready=Test-Path -LiteralPath $identity
$mobile=[pscustomobject]@{enabled=$true;port=27844;token=$token;modules=@('ram','vram','system','temperatures','fps','alerts','clock','timer');tls=[pscustomobject]@{prepared=$ready;enabled=$ready}}
$disk|Add-Member NoteProperty mobileView $mobile
$temporary=$ConfigPath+'.recovery.tmp'
[IO.File]::WriteAllText($temporary,($disk|ConvertTo-Json -Depth 24),(New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $temporary -Destination $ConfigPath -Force
[pscustomobject]@{Restored=$true;Backup=$backup;NewQr=$true;ExistingCertificatePreserved=$true}
