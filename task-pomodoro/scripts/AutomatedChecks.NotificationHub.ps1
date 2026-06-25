# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for notification hub boundary assertions.

function Invoke-NotificationHubBoundaryCheck([string]$ModulesDir) {
    $notificationHub = Join-Path $ModulesDir "NotificationHub.ps1"; $settingsWorkflow = Join-Path $ModulesDir "SettingsWorkflow.ps1"
    foreach ($requiredFile in @($notificationHub, $settingsWorkflow)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1"); $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("SettingsStore.ps1", "NotificationHub.ps1", "SettingsWorkflow.ps1")) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    if ([Array]::IndexOf($loadOrder, "SettingsStore.ps1") -gt [Array]::IndexOf($loadOrder, "NotificationHub.ps1") -or [Array]::IndexOf($loadOrder, "NotificationHub.ps1") -gt [Array]::IndexOf($loadOrder, "SettingsWorkflow.ps1")) { throw "NotificationHub.ps1 must load after SettingsStore.ps1 and before SettingsWorkflow.ps1" }
    $hubRaw = Get-Content -LiteralPath $notificationHub -Encoding UTF8 -Raw; foreach ($required in @("function Initialize-AppNotificationHub", "function Register-AppNotificationHandler", "function Clear-AppNotificationHandlers", "function Publish-AppNotification")) { if ($hubRaw -notlike "*$required*") { throw "NotificationHub.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $notificationHub @("System.Windows.Forms", "Save-Settings", "Write-JsonAtomic", "Invoke-RestMethod", "Set-Status", "WindowState", "Watermark", "TranslationRuntime") "NotificationHub.ps1 must stay side-effect-light."
    $workflowRaw = Get-Content -LiteralPath $settingsWorkflow -Encoding UTF8 -Raw; foreach ($required in @("Publish-AppNotification", "SettingsChanged", "Scope", "PreserveWindow")) { if ($workflowRaw -notlike "*$required*") { throw "SettingsWorkflow.ps1 must publish SettingsChanged notifications with $required." } }
}
