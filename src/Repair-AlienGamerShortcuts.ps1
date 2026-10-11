param(
    [string]$InstallRoot = (Join-Path $env:ProgramData 'AlienGamerMode\App'),
    [string[]]$ShortcutDirectories = @(
        [Environment]::GetFolderPath('Desktop'),
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
    )
)
$ErrorActionPreference = 'Stop'
$launcher = Join-Path $InstallRoot 'AlienGamerModeLauncher.vbs'
if (-not (Test-Path -LiteralPath $launcher)) { throw 'Missing AlienGamer launcher.' }
$shell = New-Object -ComObject WScript.Shell
foreach ($directory in $ShortcutDirectories | Select-Object -Unique) {
    if (-not $directory -or -not (Test-Path -LiteralPath $directory)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $directory -Filter '*.lnk' -Recurse) {
        $link = $shell.CreateShortcut($file.FullName)
        # Only migrate this installation's exact agent invocation. Never touch
        # uninstallers, other PowerShell shortcuts or another installation.
        if ([IO.Path]::GetFileName($link.TargetPath) -notmatch '^(powershell|pwsh)\.exe$') { continue }
        $agent = [regex]::Escape((Join-Path $InstallRoot 'AlienGamerModeAgent.ps1'))
        if ($link.Arguments -notmatch ('(?i)-File\s+"' + $agent + '"(?:\s|$)')) { continue }
        $mode = if ($link.Arguments -match '(?i)(?:^|\s)-OpenLayoutEditor(?:\s|$)') {'activate-layout'} elseif ($link.Arguments -match '(?i)(?:^|\s)-Activate(?:\s|$)') {'activate'} else {'agent'}
        $backup = $file.FullName + '.before-hidden-launch.bak'
        if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $file.FullName -Destination $backup }
        $link.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
        $link.Arguments = '//B //NoLogo "' + $launcher + '" ' + $mode
        $link.WorkingDirectory = $InstallRoot
        $link.WindowStyle = 1
        $link.Save()
        [pscustomobject]@{path=$file.FullName; mode=$mode; backup=$backup}
    }
}
