function Resolve-AGLanguage([string]$Language) {
    if ([string]::IsNullOrWhiteSpace($Language)) { return 'es-MX' }
    switch -Regex ($Language.Trim()) {
        '^(en|english)(-|$)' { return 'en-US' }
        '^(es|spanish)(-|$)' { return 'es-MX' }
        default { return 'es-MX' }
    }
}

function Get-AGTranslations {
    param(
        [string]$Language = 'es-MX',
        [string]$LocalesRoot = (Join-Path $PSScriptRoot 'locales')
    )
    $resolved = Resolve-AGLanguage $Language
    $path = Join-Path $LocalesRoot ($resolved + '.json')
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing language file: $path" }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AGText {
    param($Translations, [string]$Path)
    $value = $Translations
    foreach ($part in $Path -split '\.') {
        if ($null -eq $value -or -not $value.PSObject.Properties[$part]) { return $Path }
        $value = $value.$part
    }
    return [string]$value
}

Export-ModuleMember -Function Resolve-AGLanguage,Get-AGTranslations,Get-AGText
