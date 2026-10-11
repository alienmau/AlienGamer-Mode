$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$stage=Join-Path $root ('build\tests\shortcuts-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$shell=New-Object -ComObject WScript.Shell
$install=Join-Path $root 'src'
foreach($name in @('activate','startup','uninstall','unrelated')) {
    $link=$shell.CreateShortcut((Join-Path $stage ($name+'.lnk')))
    $link.TargetPath=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $script=if($name-eq'uninstall'){'Uninstall-AlienGamerMode.ps1'}elseif($name-eq'unrelated'){'OtherAgent.ps1'}else{'AlienGamerModeAgent.ps1'}
    $link.Arguments='-NoProfile -File "'+(Join-Path $install $script)+'"'
    if($name-eq'activate'){$link.Arguments+=' -Activate'}
    $link.Save()
}
$result=@(& (Join-Path $install 'Repair-AlienGamerShortcuts.ps1') -InstallRoot $install -ShortcutDirectories @($stage))
if($result.Count-ne2){throw 'Expected exactly two migrated shortcuts.'}
foreach($name in @('activate','startup','uninstall','unrelated')) {
    $link=$shell.CreateShortcut((Join-Path $stage ($name+'.lnk')))
    $migrated=$name-in@('activate','startup')
    if(([IO.Path]::GetFileName($link.TargetPath)-eq'wscript.exe')-ne$migrated){throw "Wrong target: $name"}
    if($migrated-and-not(Test-Path -LiteralPath (Join-Path $stage ($name+'.lnk.before-hidden-launch.bak')))){throw 'Missing backup.'}
}
if(@(& (Join-Path $install 'Repair-AlienGamerShortcuts.ps1') -InstallRoot $install -ShortcutDirectories @($stage)).Count){throw 'Migration is not idempotent.'}
'OK: legacy pins migrated, backups preserved, unrelated shortcuts untouched.'
