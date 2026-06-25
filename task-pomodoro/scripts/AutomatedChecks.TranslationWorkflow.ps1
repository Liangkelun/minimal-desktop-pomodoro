# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for Translation workflow boundary assertions.

function Invoke-TranslationWorkflowBoundaryCheck([string]$ModulesDir) {
    $workflow = Join-Path $ModulesDir "TranslationWorkflow.ps1"
    $bridge = Join-Path $ModulesDir "TranslationBridge.ps1"
    $translationCore = Join-Path $ModulesDir "WatermarkTranslation.ps1"
    $rules = Join-Path $ModulesDir "TranslationRules.ps1"
    $lookup = Join-Path $ModulesDir "TranslationLookup.ps1"
    $runtime = Join-Path $ModulesDir "TranslationRuntime.ps1"
    $surface = Join-Path $ModulesDir "TranslationSurface.ps1"
    foreach ($requiredFile in @($workflow, $bridge, $translationCore, $rules, $lookup, $runtime, $surface)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1"); $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("TranslationRules.ps1", "TranslationLookup.ps1", "TranslationWorkflow.ps1", "TranslationBridge.ps1", "WatermarkTranslation.ps1", "TranslationRuntime.ps1")) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    if ([Array]::IndexOf($loadOrder, "TranslationLookup.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationWorkflow.ps1")) { throw "TranslationWorkflow.ps1 must load after TranslationLookup.ps1" }
    if ([Array]::IndexOf($loadOrder, "TranslationWorkflow.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationBridge.ps1")) { throw "TranslationWorkflow.ps1 must load before TranslationBridge.ps1" }
    if ([Array]::IndexOf($loadOrder, "TranslationBridge.ps1") -gt [Array]::IndexOf($loadOrder, "WatermarkTranslation.ps1")) { throw "TranslationBridge.ps1 must load before WatermarkTranslation.ps1" }
    if ([Array]::IndexOf($loadOrder, "TranslationBridge.ps1") -gt [Array]::IndexOf($loadOrder, "TranslationRuntime.ps1")) { throw "TranslationBridge.ps1 must load before TranslationRuntime.ps1" }
    $workflowRaw = Get-Content -LiteralPath $workflow -Encoding UTF8 -Raw
    foreach ($required in @("function Reset-TranslationWorkflowState", "function Clear-TranslationWorkflowShownState", "function Test-TranslationWorkflowRecentRequest", "function Invoke-TranslationWorkflowRequest", "Get-TranslationSelectionKind", "Get-TranslationResult", "Publish-AppNotification", "TranslationCompleted", "TranslationFailed", "`$script:TranslationWorkflowLastSignature", "`$script:TranslationWorkflowLastShownSignature", "`$script:TranslationWorkflowLastSource", "`$script:TranslationWorkflowLastAt")) { if ($workflowRaw -notlike "*$required*") { throw "TranslationWorkflow.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $workflow @("Show-WatermarkTranslationResult", "Ensure-WatermarkTranslationForms", "System.Windows.Forms", "Get-WatermarkTranslationSelection ", "Get-WatermarkTranslationSelectionKind", "Get-WatermarkTranslationResult", "function Get-TranslationSelection ", "Get-TranslationSelection ", "Clipboard]", "Set-Clipboard", "Set-Status", "`$script:WatermarkTranslationLastSignature", "`$script:WatermarkTranslationLastShownSignature", "`$script:WatermarkTranslationLastSource", "`$script:WatermarkTranslationLastAt") "TranslationWorkflow.ps1 must stay free of overlay rendering, selection adapters, and historical WatermarkTranslationLast* private state."
    $bridgeRaw = Get-Content -LiteralPath $bridge -Encoding UTF8 -Raw
    foreach ($required in @("function Register-TranslationNotificationHandlers", "function Clear-TranslationNotificationHandlers", "function Show-TranslationText", "function Update-TranslationSelectionBridge", "Register-AppNotificationHandler", "Show-TranslationSurfaceResult", "Invoke-TranslationWorkflowRequest", "Get-TranslationSelection")) { if ($bridgeRaw -notlike "*$required*") { throw "TranslationBridge.ps1 must own translation notification and selection bridge: $required" } }
    Test-FileDoesNotContain $bridge @("Invoke-RestMethod", "Save-Settings", "Save-GeneralSettings", "TaskFontSize", "WatermarkPrevious", "New-Object System.Windows.Forms.Timer", "Start-TranslationRuntime", "Stop-TranslationRuntime") "TranslationBridge.ps1 must bridge selection/workflow/surface without owning runtime resources, provider calls, or host state."
    $coreRaw = Get-Content -LiteralPath $translationCore -Encoding UTF8 -Raw
    foreach ($required in @("Clear-WatermarkTranslationNotificationHandlers", "Clear-TranslationNotificationHandlers", "Register-WatermarkTranslationNotificationHandlers", "Register-TranslationNotificationHandlers", "Show-WatermarkTranslationText", "Show-TranslationText", "Update-WatermarkTranslationSelection", "Update-TranslationSelectionBridge", "Start-WatermarkTranslationMode", "Start-TranslationRuntime", "Stop-WatermarkTranslationMode", "Stop-TranslationRuntime")) { if ($coreRaw -notlike "*$required*") { throw "WatermarkTranslation.ps1 must stay as compatibility wrappers: $required" } }
    Test-FileDoesNotContain $translationCore @("Register-AppNotificationHandler", "Clear-AppNotificationHandlers", "Show-TranslationSurfaceResult", "Get-TranslationSelection", "Invoke-TranslationWorkflowRequest") "WatermarkTranslation.ps1 must delegate bridge work to TranslationBridge.ps1."
    foreach ($stateClient in @($translationCore, $bridge, $runtime, $surface)) {
        Test-FileDoesNotContain $stateClient @('$script:WatermarkTranslationLastSignature', '$script:WatermarkTranslationLastShownSignature', '$script:WatermarkTranslationLastSource', '$script:WatermarkTranslationLastAt') "$([System.IO.Path]::GetFileName($stateClient)) must use TranslationWorkflow state functions instead of direct WatermarkTranslationLast* fields."
    }
    $surfaceRaw = Get-Content -LiteralPath $surface -Encoding UTF8 -Raw
    foreach ($required in @("[System.Windows.Forms.Screen]::FromRectangle", "`$placeDetailAbove", "`$cursor.X + 12")) { if (-not $surfaceRaw.Contains($required)) { throw "TranslationSurface.ps1 must keep selection-anchored overlay placement marker: $required" } }
    "Translation workflow publishes events and neutral bridge handles selection/surface wiring"
}