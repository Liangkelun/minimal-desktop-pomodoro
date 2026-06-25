# This file is dot-sourced by TaskPomodoro.ps1. It owns translation cache and lookup order.

function Get-TranslationCacheKey([string]$Text, [string]$Kind) {
    return "$Kind|$($Text.ToLowerInvariant())"
}

function Clear-TranslationLookupCache {
    $script:TranslationCache = @{}
}

function Get-TranslationResult([string]$Text, [string]$Kind) {
    $cacheKey = Get-TranslationCacheKey $Text $Kind
    if ($null -eq $script:TranslationCache) { $script:TranslationCache = @{} }
    if ($script:TranslationCache.ContainsKey($cacheKey)) { return $script:TranslationCache[$cacheKey] }
    $result = $null
    if ($Kind -eq "term") { $result = Get-TranslationLocalResult $Text }
    $providerEnabled = Test-TranslationProviderEnabled
    if ($null -eq $result -and $providerEnabled) {
        $translated = Invoke-TranslationProviderApi $Text
        if (-not [string]::IsNullOrWhiteSpace($translated)) {
            $result = New-TranslationResult -Text $Text -Source ([string]$script:Settings.TranslationProvider) -Kind $Kind -Short (Convert-TranslationDefinitionToShortText $translated 3) -Detail $translated -Word $Text
        }
    }
    if ($null -eq $result) {
        if ($providerEnabled -and -not [string]::IsNullOrWhiteSpace([string]$script:Settings.TranslationLastError)) { $result = New-TranslationHintResult "TranslationServiceUnavailable" }
        else { $result = New-TranslationHintResult "TranslationLocalMiss" }
    }
    $script:TranslationCache[$cacheKey] = $result
    return $result
}