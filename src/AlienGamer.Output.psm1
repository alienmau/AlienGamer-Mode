function Set-AGOutputDestination {
    param([Parameter(Mandatory)]$Config,[ValidateSet('desktop','mobile','both')][string]$Mode,$Monitor)
    $desktop=$Mode -ne 'mobile'
    if($desktop -and -not $Monitor){throw 'Select a desktop display.'}
    if(-not $Config.PSObject.Properties['mobileView']){
        $Config|Add-Member NoteProperty mobileView ([pscustomobject]@{enabled=$false;port=27844;token='';modules=@('ram','vram','system','temperatures','fps','alerts','clock');allowTimerControl=$false})
    }
    $Config.mobileView.enabled=$Mode -ne 'desktop'
    if($Config.mobileView.enabled -and -not $Config.mobileView.token){
        $bytes=New-Object byte[] 24;$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
        try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
        $Config.mobileView.token=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
    }
    foreach($view in @($Config.displayViews)){$view.enabled=$false}
    if($desktop){
        $Config.display.targetMonitor=[string]$Monitor.deviceName
        $Config.display|Add-Member NoteProperty targetMonitorId ([string]$Monitor.pnpDeviceId) -Force
        $view=@($Config.displayViews)[0]
        if(-not $view){throw 'Missing desktop layout.'}
        $view.monitorId=[string]$Monitor.pnpDeviceId;$view.monitorDeviceName=[string]$Monitor.deviceName
        $view.name=[string]$Monitor.friendlyName;$view.enabled=$true
    }else{
        $Config.display.targetMonitor='auto'
        $Config.display|Add-Member NoteProperty targetMonitorId 'auto' -Force
    }
}

function New-AGConfigurationBackup {
    param([Parameter(Mandatory)][string]$ConfigPath)
    $directory=Join-Path (Split-Path -Parent $ConfigPath) 'ConfigurationBackups'
    New-Item -ItemType Directory -Path $directory -Force|Out-Null
    $destination=Join-Path $directory ('configuration-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N')+'.json')
    Copy-Item -LiteralPath $ConfigPath -Destination $destination -ErrorAction Stop
    return $destination
}
Export-ModuleMember -Function Set-AGOutputDestination,New-AGConfigurationBackup
