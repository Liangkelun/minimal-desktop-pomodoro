# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for Translation rules and lookup boundary assertions.

function Test-TranslationMalformedIndexFallback([string]$ModulesDir) {
    $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "TaskPomodoroChecks"
    if (-not (Test-Path -LiteralPath $tempBase)) { New-Item -ItemType Directory -Path $tempBase | Out-Null }
    $tempDir = Join-Path $tempBase ("dict-index-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    try {
        $dictPath = Join-Path $tempDir "bad.tsv"
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $tsv = "word`tphonetic`tpos`ttranslation`ttags`tfrequency`texchange`r`nexample`t`t n.`tsample`t`t1`t`r`n"
        [System.IO.File]::WriteAllText($dictPath, $tsv, $utf8)
        $stream = [System.IO.File]::Open((Get-TranslationDictionaryIndexPath $dictPath), [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $writer = New-Object System.IO.BinaryWriter($stream)
        try {
            $wordBytes = [System.Text.Encoding]::UTF8.GetBytes("example")
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("TPDK2"))
            $writer.Write([int64](Get-Item -LiteralPath $dictPath).Length)
            $writer.Write([int32]1)
            $writer.Write([int32]$wordBytes.Length)
            $writer.Write([int32]0)
            $writer.Write([uint16]$wordBytes.Length)
            $writer.Write([int64]0)
            $writer.Write([int32]1000000)
            $writer.Write($wordBytes)
        }
        finally { $writer.Dispose() }

        function Get-AppPath([string]$Name) { return $tempDir }
        . (Join-Path $ModulesDir "TranslationDictionary.ps1")
        $script:Settings = [pscustomobject]@{ TranslationDictionaryPath = $dictPath; TranslationDictionaryFetchOrder = "local-first" }
        Clear-TranslationDictionaryCache
        $result = Get-TranslationLocalResult "example"
        if ($null -eq $result -or [string]$result.Word -ne "example") { throw "Malformed dictionary index did not fall back to TSV lookup." }
        if ([bool]$script:TranslationDictionaryLastIndexUsed) { throw "Malformed dictionary index must be marked unused after fallback." }
        return "Malformed compact index falls back to TSV lookup"
    }
    finally { Remove-IsolatedProjectCopy $tempDir }
}

function Invoke-TranslationLookupBoundaryCheck([string]$ModulesDir) {
    $rules = Join-Path $ModulesDir "TranslationRules.ps1"
    $lookup = Join-Path $ModulesDir "TranslationLookup.ps1"
    $dictionaryIndex = Join-Path $ModulesDir "TranslationDictionaryIndex.ps1"
    $dictionary = Join-Path $ModulesDir "TranslationDictionary.ps1"
    $legacyDictionary = Join-Path $ModulesDir "WatermarkTranslation.Dictionary.ps1"
    $providers = Join-Path $ModulesDir "TranslationProviders.ps1"
    $workflow = Join-Path $ModulesDir "TranslationWorkflow.ps1"
    $core = Join-Path $ModulesDir "WatermarkTranslation.ps1"
    foreach ($requiredFile in @($rules, $lookup, $dictionaryIndex, $dictionary, $legacyDictionary, $providers, $workflow, $core)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1"); $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("TranslationDictionaryIndex.ps1", "TranslationDictionary.ps1", "TranslationDictionaryInstall.ps1", "WatermarkTranslation.Dictionary.ps1", "TranslationRules.ps1", "TranslationLookup.ps1", "TranslationProviders.ps1", "TranslationWorkflow.ps1", "WatermarkTranslation.ps1")) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    if ([Array]::IndexOf($loadOrder, "TranslationDictionaryIndex.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationDictionary.ps1")) { throw "TranslationDictionaryIndex.ps1 must load before TranslationDictionary.ps1." }
    if ([Array]::IndexOf($loadOrder, "TranslationRules.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationLookup.ps1") -or [Array]::IndexOf($loadOrder, "TranslationDictionary.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationLookup.ps1") -or [Array]::IndexOf($loadOrder, "TranslationProviders.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationLookup.ps1")) { throw "TranslationLookup.ps1 must load after rules, neutral dictionary, and providers." }
    if ([Array]::IndexOf($loadOrder, "TranslationLookup.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationWorkflow.ps1") -or [Array]::IndexOf($loadOrder, "TranslationWorkflow.ps1") -gt [Array]::IndexOf($loadOrder, "WatermarkTranslation.ps1")) { throw "TranslationWorkflow.ps1 must load after lookup and before WatermarkTranslation.ps1." }

    $rulesRaw = Get-Content -LiteralPath $rules -Encoding UTF8 -Raw
    foreach ($required in @("function Get-TranslationSelectionKind", "function New-TranslationResult", "function New-TranslationHintResult")) { if ($rulesRaw -notlike "*$required*") { throw "TranslationRules.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $rules @("System.Windows.Forms", "System.Windows.Automation", "Clipboard]", "Invoke-RestMethod", "Save-Settings", "function Get-TranslationSelection ", "Get-TranslationSelection ", "Show-TranslationSurfaceResult", "Get-WatermarkTranslationLocalResult", "Invoke-TranslationProviderApi") "TranslationRules.ps1 must stay focused on text rules and result models."

    $lookupRaw = Get-Content -LiteralPath $lookup -Encoding UTF8 -Raw
    foreach ($required in @("function Get-TranslationResult", "function Clear-TranslationLookupCache", "Get-TranslationLocalResult", "Invoke-TranslationProviderApi", "New-TranslationHintResult", "TranslationCache")) { if ($lookupRaw -notlike "*$required*") { throw "TranslationLookup.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $lookup @("System.Windows.Forms", "System.Windows.Automation", "Clipboard]", "Invoke-RestMethod", "Unprotect-TranslationSecret", "function Get-TranslationSelection ", "Get-TranslationSelection ", "Show-TranslationSurfaceResult", "Hide-TranslationSurfaces", "Set-Status", "Save-Settings", "Get-WatermarkTranslationLocalResult") "TranslationLookup.ps1 must only orchestrate dictionary/provider lookup and cache."
    $dictionaryRaw = Get-Content -LiteralPath $dictionary -Encoding UTF8 -Raw
    foreach ($required in @("function Get-TranslationBuiltinDictionaryPath", "function Convert-TranslationDefinitionToShortText", "function Clear-TranslationDictionaryCache", "function Add-TranslationDictionaryFile", "function Load-TranslationDictionary", "function Get-TranslationLookupCandidates", "function Get-TranslationLocalResult")) { if ($dictionaryRaw -notlike "*$required*") { throw "TranslationDictionary.ps1 must own local dictionary implementation: $required" } }
    $dictionaryIndexRaw = Get-Content -LiteralPath $dictionaryIndex -Encoding UTF8 -Raw
    foreach ($required in @("function Get-TranslationDictionaryIndexPath", "function Clear-TranslationDictionaryIndexCache", "function Find-TranslationDictionaryLineByIndex", "function Open-TranslationDictionaryIndex")) { if ($dictionaryIndexRaw -notlike "*$required*") { throw "TranslationDictionaryIndex.ps1 must own compact dictionary offset index support: $required" } }
    . $dictionaryIndex
    $fallbackMessage = Test-TranslationMalformedIndexFallback $ModulesDir
    Test-FileDoesNotContain $legacyDictionary @("[System.IO.File]::ReadLines", "`$script:TranslationDictionary", "Convert-TranslationDefinitionToShortText", "function Get-TranslationLocalResult", "function Load-TranslationDictionary ") "WatermarkTranslation.Dictionary.ps1 must stay compatibility-only and delegate local dictionary implementation to TranslationDictionary.ps1."
    Test-FileDoesNotContain $core @("function Get-WatermarkTranslationSelectionKind", "function New-WatermarkTranslationHintResult", "function Get-WatermarkTranslationResult", "function Get-TranslationSelectionKind", "function New-TranslationResult", "function Get-TranslationResult", "Get-WatermarkTranslationLocalResult", "Invoke-TranslationProviderApi", "TranslationCache") "WatermarkTranslation.ps1 must delegate text rules and lookup through neutral Translation modules."
    "Translation text rules and lookup orchestration are isolated from Watermark runtime glue; $fallbackMessage"
}