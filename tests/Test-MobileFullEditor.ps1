param([switch]$Installed,[switch]$CheckHttps)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskProbe=[pscustomobject]@{passed=$false;opened=$false;ticks=0;error=''}
$taskTimer=New-Object Windows.Forms.Timer;$taskTimer.Interval=1000
$taskTimer.Add_Tick({
    $taskForms=@([Windows.Forms.Application]::OpenForms)
    $taskWizard=@($taskForms|Where-Object Text -like 'Conexi*n segura*')[0]
    if($taskWizard){
        $taskAll=New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'
        $taskWalk={param($p)foreach($c in $p.Controls){$taskAll.Add($c);& $taskWalk $c}}
        & $taskWalk $taskWizard
        $taskProbe.passed=(@($taskAll|Where-Object {$_.Text -like 'Tu conexi*n HTTPS'}).Count -gt 0) -and (@($taskAll|Where-Object {$_ -is [Windows.Forms.PictureBox] -and $_.Image}).Count -gt 0)
        $taskProbe.error='Configured HTTPS did not reopen its summary and QR. '+(@($taskAll|Where-Object {$_ -is [Windows.Forms.Label]}|ForEach-Object Text)-join ' / ')
        $taskTimer.Stop();$taskWizard.Close()
        foreach($w in $taskForms){if(-not $w.IsDisposed){$w.Close()}}
        return
    }
    $taskDialog=@($taskForms|Where-Object Text -like 'Monitor*red local')[0]
    if($taskDialog){
        $taskProbe.ticks++
        $taskUrl=@($taskDialog.Controls|Where-Object {$_ -is [Windows.Forms.TextBox]})[0]
        $taskQr=@($taskDialog.Controls|Where-Object {$_ -is [Windows.Forms.PictureBox]})[0]
        if($taskUrl.Text -and $taskQr.Image){
            if($CheckHttps){
                $taskHttps=@($taskDialog.Controls|Where-Object Text -like 'HTTPS activo*')[0]
                if($taskHttps){$taskHttps.PerformClick();return}
            }else{$taskProbe.passed=$true}
        }
        if($taskProbe.passed -or $taskProbe.ticks -ge 4){
            $taskProbe.error=(@($taskDialog.Controls|Where-Object {$_ -is [Windows.Forms.Label]}|ForEach-Object Text)-join ' / ')
            $taskTimer.Stop();$taskDialog.Close()
            foreach($taskWindow in $taskForms){if(-not $taskWindow.IsDisposed){$taskWindow.Close()}}
        }
    }elseif(-not $taskProbe.opened -and $taskForms.Count){
        $taskControls=New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'
        $taskCollect={param($taskParent)foreach($taskChild in $taskParent.Controls){$taskControls.Add($taskChild);& $taskCollect $taskChild}}
        & $taskCollect $taskForms[0]
        $taskCard=@($taskControls|Where-Object {$_.GetType().Name -eq 'DisplayCard' -and $_.Kind -eq 'mobile'})[0]
        if($taskCard){$taskProbe.opened=$true;$taskCard.PerformClick()}
    }
})
try{
    $taskTimer.Start()
    $taskSourceRoot=if($Installed){'C:\ProgramData\AlienGamerMode\App'}else{Join-Path $taskRoot 'src'}
    $taskSource=[IO.File]::ReadAllText((Join-Path $taskSourceRoot 'Show-AlienGamerLayoutEditor.ps1'))
    $taskSource=$taskSource.Replace('[Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::CatchException)','')
    $taskSource=$taskSource.Replace("Write-EditorTrace 'EDITOR exit 1';exit 1","Write-EditorTrace 'EDITOR exit 1'")
    $taskSource=$taskSource.Replace('$PSScriptRoot',("'"+$taskSourceRoot.Replace("'","''")+"'"))
    & ([scriptblock]::Create($taskSource)) -ConfigPath 'C:\Users\alien\AppData\Local\AlienGamerMode\AlienGamerMode.json' -DiscoveryPath 'C:\Users\alien\AppData\Local\AlienGamerMode\discovery.json'
}finally{$taskTimer.Dispose()}
if(-not $taskProbe.passed){throw $taskProbe.error}
'PASS: full editor opens an existing HTTPS QR without toggling or saving.'
