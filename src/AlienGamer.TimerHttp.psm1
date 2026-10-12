function Read-AGHttpRequest($Stream) {
    $bytes=[Collections.Generic.List[byte]]::new()
    while($bytes.Count -lt 8192){
        $b=$Stream.ReadByte();if($b -lt 0){throw 'Incomplete request.'};$bytes.Add([byte]$b)
        $n=$bytes.Count
        if($n-ge4-and$bytes[$n-4]-eq13-and$bytes[$n-3]-eq10-and$bytes[$n-2]-eq13-and$bytes[$n-1]-eq10){break}
    }
    if($bytes.Count-ge8192){throw 'Headers too large.'}
    $lines=[Text.Encoding]::ASCII.GetString($bytes.ToArray()).Split(@("`r`n"),[StringSplitOptions]::None)
    if($lines[0]-notmatch '^(GET|POST) (/[^\s]*) HTTP/1\.[01]$'){throw 'Unsupported request.'}
    $method=$Matches[1];$path=$Matches[2].Split('?')[0];$headers=@{}
    foreach($line in $lines|Select-Object -Skip 1){if(-not$line){continue};if($line-notmatch '^([^:]+):\s*(.*)$'){throw 'Invalid header.'};$key=$Matches[1].Trim().ToLowerInvariant();if($headers.ContainsKey($key)){throw 'Duplicate header.'};$headers[$key]=$Matches[2].Trim()}
    if($headers.ContainsKey('transfer-encoding')){throw 'Chunked requests unsupported.'}
    $length=0
    if($headers.ContainsKey('content-length')-and(-not[int]::TryParse($headers['content-length'],[ref]$length)-or$length-lt0-or$length-gt1024)){throw 'Body too large.'}
    $body=New-Object byte[] $length;$offset=0
    while($offset-lt$length){$n=$Stream.Read($body,$offset,$length-$offset);if($n-le0){throw 'Incomplete body.'};$offset+=$n}
    [pscustomobject]@{Method=$method;Path=$path;Headers=$headers;Body=[Text.UTF8Encoding]::new($false,$true).GetString($body)}
}
function Invoke-AGTimerRequest($Request,[bool]$Tls,[string]$Origin,$Settings,[string]$Directory) {
    if(-not$Tls-or-not$Settings-or$Settings.allowTimerControl-ne$true-or'timer'-notin@($Settings.modules)-or$Request.Headers['origin']-cne$Origin-or$Request.Headers['x-aliengamer-timer']-ne'1'){
        return @{Code=403;Body=@{error='Control no autorizado. Actívalo en la PC y usa HTTPS.'}}
    }
    if($Request.Method-ne'POST'-or$Request.Headers['content-type']-notmatch '^application/json(?:;|$)'){return @{Code=400;Body=@{error='Solicitud no válida.'}}}
    try{
        $v=$Request.Body|ConvertFrom-Json -ErrorAction Stop
        if(($v.action-notin@('configure','start','pause','extra','reset','alarm'))-or($v.revision-isnot[long]-and$v.revision-isnot[int])-or($v.revision-lt0)){throw 'Invalid action or revision.'}
        if($v.action-eq'alarm'){
            if($v.output-notin@('mobile','pc','both')-or($v.alarmRevision-isnot[int]-and$v.alarmRevision-isnot[long])-or$v.alarmRevision-lt0){throw 'Invalid alarm output.'}
            $change=@{Directory=$Directory;Output=[string]$v.output;Revision=[long]$v.alarmRevision}
        }
        $args=@{Directory=$Directory;Action=[string]$v.action;Revision=[long]$v.revision}
        if($v.action-eq'configure'){
            if($v.seconds-isnot[int]-or$v.extraStep-isnot[int]){throw 'Invalid duration.'}
            $args.Seconds=$v.seconds;$args.ExtraStep=$v.extraStep
        }
    }catch{return @{Code=400;Body=@{error='Revisa la duración y los minutos extra.'}}}
    try{
        if($v.action-eq'alarm'){
            Set-AGTimerAlarmSettings @change|Out-Null
            return @{Code=200;Body=(Invoke-AGSharedTimer -Directory $Directory)}
        }
        return @{Code=200;Body=(Invoke-AGSharedTimer @args)}
    }catch{return @{Code=409;Body=@{error='El temporizador o sus opciones cambiaron. Actualiza y vuelve a intentar.'}}}
}
Export-ModuleMember -Function Read-AGHttpRequest,Invoke-AGTimerRequest
