# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for legacy translation wrapper assertions.

function Invoke-LegacyTranslationWrapperBoundaryCheck([string]$ModulesDir) {
    $requiredByFile = @{
        "WatermarkTranslation.ps1" = @("Clear-WatermarkTranslationNotificationHandlers", "Clear-TranslationNotificationHandlers", "Show-WatermarkTranslationText", "Show-TranslationText", "Start-WatermarkTranslationMode", "Start-TranslationRuntime", "Stop-WatermarkTranslationMode", "Stop-TranslationRuntime")
        "WatermarkTranslation.Dictionary.ps1" = @("Get-WatermarkTranslationBuiltinDictionaryPath", "Get-TranslationBuiltinDictionaryPath", "Get-WatermarkTranslationLocalResult", "Get-TranslationLocalResult")
        "WatermarkTranslation.Platform.ps1" = @("Ensure-WatermarkTranslationTypes", "Ensure-TranslationPlatformTypes")
        "WatermarkTranslation.Settings.ps1" = @("Show-WatermarkTranslationSettingsDialog", "Show-TranslationSettingsDialog", "Apply-WatermarkTranslationSettingsControls", "Apply-TranslationSettingsControls")
        "WatermarkTranslation.Surface.ps1" = @("Get-ScreenSafePoint", "Get-TranslationSurfaceSafePoint", "Show-WatermarkTranslationResult", "Show-TranslationSurfaceResult", "Dispose-WatermarkTranslationSurfaces", "Dispose-TranslationSurfaces")
    }
    $maxLinesByFile = @{
        "WatermarkTranslation.ps1" = 12
        "WatermarkTranslation.Dictionary.ps1" = 12
        "WatermarkTranslation.Platform.ps1" = 6
        "WatermarkTranslation.Settings.ps1" = 8
        "WatermarkTranslation.Surface.ps1" = 40
    }
    $forbiddenImplementationTerms = @(
        '$script:Form', '$script:WatermarkTranslationMode', '$script:WatermarkTranslationTimer', '$script:WatermarkTranslationSettingsDialog',
        '$script:WatermarkTranslationMiniForm', '$script:WatermarkTranslationDetailForm', '$script:WatermarkTranslationLastSignature',
        "New-Object System.Windows.Forms", "TaskPomodoroNoActivateForm", "TaskPomodoroTranslationDetailForm", "System.Windows.Automation",
        "Invoke-RestMethod", "Invoke-WebRequest", "Add-Type -Language CSharp", "ProtectedData", "GetClipboardSequenceNumber",
        "Clipboard]::SetText", "Clipboard]::SetDataObject", "Set-Clipboard", "SendKeys", "[System.IO.File]::ReadLines",
        "Import-Csv", "ConvertFrom-Csv", "Save-Settings", "Save-TranslationSettings", "Protect-TranslationSecret", "Unprotect-TranslationSecret",
        "Register-AppNotificationHandler", "Clear-AppNotificationHandlers", "New-Object System.Windows.Forms.Timer"
    )
    foreach ($entry in $requiredByFile.GetEnumerator()) {
        $path = Join-Path $ModulesDir $entry.Key
        Test-RequiredFile $path
        Test-MaxLineCount $path ([int]$maxLinesByFile[$entry.Key]) | Out-Null
        $raw = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
        foreach ($required in $entry.Value) { if ($raw -notlike "*$required*") { throw "$($entry.Key) missing wrapper marker: $required" } }
        Test-FileDoesNotContain $path $forbiddenImplementationTerms "$($entry.Key) must stay compatibility-only; implementation belongs in neutral Translation* modules."
    }
    "Legacy WatermarkTranslation wrappers are compatibility-only"
}