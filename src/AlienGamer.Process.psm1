if(-not('AlienGamer.Runtime.ProcessHost' -as [type])){
    Add-Type -Path (Join-Path $PSScriptRoot 'native\AlienGamerProcessHost.cs')
}
function Start-AGHiddenProcess {
    param([Parameter(Mandatory)][string]$FilePath,[string]$ArgumentList='',[string]$RedirectStandardError='',[switch]$PassThru)
    $process=[AlienGamer.Runtime.ProcessHost]::Start($FilePath,$ArgumentList,$RedirectStandardError)
    if($PassThru){return $process}
    $process.Dispose()
}
Export-ModuleMember -Function Start-AGHiddenProcess
