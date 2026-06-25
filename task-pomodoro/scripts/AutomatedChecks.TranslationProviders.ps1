# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for Translation provider adapter boundary assertions.

function Invoke-TranslationProviderBoundaryCheck([string]$ModulesDir) {
    $translationProviders = Join-Path $ModulesDir "TranslationProviders.ps1"
    $translationPlatform = Join-Path $ModulesDir "TranslationPlatform.ps1"
    $legacyTranslationPlatform = Join-Path $ModulesDir "WatermarkTranslation.Platform.ps1"
    $translationCore = Join-Path $ModulesDir "WatermarkTranslation.ps1"
    $translationSettings = Join-Path $ModulesDir "TranslationSettings.ps1"
    $legacyTranslationSettings = Join-Path $ModulesDir "WatermarkTranslation.Settings.ps1"
    $translationDictionary = Join-Path $ModulesDir "TranslationDictionary.ps1"
    $legacyTranslationDictionary = Join-Path $ModulesDir "WatermarkTranslation.Dictionary.ps1"
    $translationWorkflow = Join-Path $ModulesDir "TranslationWorkflow.ps1"
    $translationRuntime = Join-Path $ModulesDir "TranslationRuntime.ps1"
    $translationBridge = Join-Path $ModulesDir "TranslationBridge.ps1"
    foreach ($requiredFile in @($translationProviders, $translationPlatform, $legacyTranslationPlatform, $translationCore, $translationSettings, $legacyTranslationSettings, $translationDictionary, $legacyTranslationDictionary, $translationWorkflow, $translationBridge, $translationRuntime)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1"); $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("TranslationPlatform.ps1", "WatermarkTranslation.Platform.ps1", "TranslationProviders.ps1", "WatermarkTranslation.ps1", "TranslationSettings.ps1", "WatermarkTranslation.Settings.ps1")) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    if ([Array]::IndexOf($loadOrder, "TranslationPlatform.ps1") -gt [Array]::IndexOf($loadOrder, "WatermarkTranslation.Platform.ps1") -or [Array]::IndexOf($loadOrder, "TranslationPlatform.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationProviders.ps1") -or [Array]::IndexOf($loadOrder, "TranslationProviders.ps1") -gt [Array]::IndexOf($loadOrder, "WatermarkTranslation.ps1") -or [Array]::IndexOf($loadOrder, "TranslationProviders.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationSettings.ps1")) { throw "TranslationProviders.ps1 must load after neutral platform and before translation core/settings." }

    $providerRaw = Get-Content -LiteralPath $translationProviders -Encoding UTF8 -Raw
    foreach ($required in @("function Test-TranslationProviderEnabled", "function Invoke-TranslationProviderApi", "function Add-TranslationCharacterUsage", "function Test-TranslationCharacterBudget", "Invoke-RestMethod", "Unprotect-TranslationSecret", "Save-TranslationRuntimeSettings")) { if ($providerRaw -notlike "*$required*") { throw "TranslationProviders.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $translationProviders @("System.Windows.Automation", "Clipboard]", "Get-TranslationSelection", "Start-TranslationClipboardListener", "Show-TranslationSurfaceResult", "Hide-TranslationSurfaces", "WatermarkMode", "Set-Status", "Save-Settings", "Render-CurrentView") "TranslationProviders.ps1 must stay an online provider adapter."

    $providerOnlyTerms = @("Invoke-RestMethod", "Unprotect-TranslationSecret", "Get-Md5Hex", "Add-TranslationCharacterUsage", "Test-TranslationCharacterBudget", "https://api.deepl.com", "api-free.deepl.com", "fanyi-api.baidu.com", "function Invoke-WatermarkTranslationApi", "function Test-WatermarkTranslationApiEnabled")
    foreach ($file in @($translationCore, $translationSettings, $legacyTranslationSettings, $translationDictionary, $legacyTranslationDictionary, $translationWorkflow, $translationBridge, $translationRuntime)) {
        Test-FileDoesNotContain $file $providerOnlyTerms "$([System.IO.Path]::GetFileName($file)) must call online translation only through TranslationProviders.ps1."
    }
    "Translation provider adapters are isolated from core translation flow"
}