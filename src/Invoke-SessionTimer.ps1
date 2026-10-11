param([ValidateSet('toggle','extra','reset')][string]$Action)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'AlienGamer.SharedTimer.psm1') -Force
Invoke-AGSharedTimer -Directory (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'AlienGamerMode') -Action $Action|Out-Null
