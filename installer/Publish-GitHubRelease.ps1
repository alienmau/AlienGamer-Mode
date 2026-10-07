param([ValidatePattern('^v\d+\.\d+\.\d+$')][string]$Tag='v1.7.0')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$version=$Tag.Substring(1)
$notes=Join-Path $root "docs\RELEASE-$version.md"
$installer=Join-Path $root "build\installer\AlienGamerMode-Setup-$version.exe"
$checksum=Join-Path $root "build\installer\AlienGamerMode-Setup-$version.sha256.txt"
foreach($file in @($notes,$installer,$checksum)){if(-not(Test-Path -LiteralPath $file)){throw 'Missing release input.'}}
$hash=(Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
if((Get-Content -LiteralPath $checksum -Raw)-notmatch[regex]::Escape($hash)){throw 'Installer checksum mismatch.'}
$api='https://api.github.com/repos/alienmau/AlienGamer-Mode'
# Reuse the existing Git credential helper for this same GitHub destination.
# Credentials stay in memory, never in a file, log, command argument or output.
$credentialLines="protocol=https`nhost=github.com`n`n" | git -c credential.interactive=never credential fill
if($LASTEXITCODE-ne0){throw 'Existing GitHub authentication is unavailable.'}
$credential=@{}
foreach($line in $credentialLines){$split=$line.IndexOf('=');if($split-gt0){$credential[$line.Substring(0,$split)]=$line.Substring($split+1)}}
if(-not$credential.password){throw 'No GitHub credential returned.'}
$headers=@{Authorization=('Bearer '+$credential.password);Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28';'User-Agent'='AlienGamerMode-Release'}
function Request-GitHub([string]$Method,[string]$Uri,$Body){
    $options=@{Method=$Method;Uri=$Uri;Headers=$headers}
    if($null-ne$Body){$options.Body=[Text.Encoding]::UTF8.GetBytes(($Body|ConvertTo-Json -Depth 8));$options.ContentType='application/json; charset=utf-8'}
    Invoke-RestMethod @options
}
try{
    $account=Request-GitHub GET 'https://api.github.com/user' $null
    if($account.login-ne'alienmau'){throw 'Authenticated account does not match the requested repository owner.'}
    $repo=Request-GitHub GET $api $null
    if(-not$repo.permissions.push){throw 'The existing GitHub session cannot publish to this repository.'}
    $release=$null
    try{$release=Request-GitHub GET "$api/releases/tags/$Tag" $null}catch{if([int]$_.Exception.Response.StatusCode-ne404){throw}}
    $body=Get-Content -LiteralPath $notes -Raw -Encoding UTF8
    if(-not$release){$release=Request-GitHub POST "$api/releases" @{tag_name=$Tag;name="AlienGamer Mode $version - Mobile dashboard / Panel movil + nueva interfaz";body=$body;draft=$true;prerelease=$false}}
    else{$release=Request-GitHub PATCH "$api/releases/$($release.id)" @{body=$body}}
    $uploadBase=($release.upload_url-split'\{')[0]
    if(-not$uploadBase.StartsWith('https://uploads.github.com/repos/alienmau/AlienGamer-Mode/releases/')){throw 'Unexpected upload destination.'}
    foreach($file in @($installer,$checksum)){
        $name=Split-Path -Leaf $file;$fileHash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        $label='sha256:'+ $fileHash
        $existing=@($release.assets|Where-Object name -eq $name)
        if($existing.Count){
            if($existing[0].label-ne$label-or$existing[0].size-ne(Get-Item -LiteralPath $file).Length){throw 'Existing release asset differs; it will not be overwritten.'}
            continue
        }
        $uri=$uploadBase+'?name='+[Uri]::EscapeDataString($name)+'&label='+[Uri]::EscapeDataString($label)
        $asset=Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -ContentType 'application/octet-stream' -InFile $file
        if($asset.state-ne'uploaded'-or$asset.size-ne(Get-Item -LiteralPath $file).Length){throw 'Release upload verification failed.'}
    }
    $release=Request-GitHub PATCH "$api/releases/$($release.id)" @{draft=$false;prerelease=$false;make_latest='true'}
    $verified=Request-GitHub GET "$api/releases/tags/$Tag" $null
    if($verified.draft-or@($verified.assets|Where-Object name -eq (Split-Path -Leaf $installer)).Count-ne1){throw 'Public release verification failed.'}
    [pscustomobject]@{url=$verified.html_url;tag=$verified.tag_name;published=$verified.published_at;assets=@($verified.assets|Select-Object name,size,browser_download_url);sha256=$hash}|ConvertTo-Json -Depth 5
}finally{
    $headers.Clear();$credential.Clear();$credentialLines=$null
}
