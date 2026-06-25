# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for settings-view boundary assertions.

function Invoke-SettingsViewBoundaryCheck([string]$ModulesDir) {
    $mainScript = Join-Path (Split-Path -Parent $ModulesDir) "TaskPomodoro.ps1"
    $settingsGeneral = Join-Path $ModulesDir "Views.Settings.General.ps1"
    $settingsPomodoro = Join-Path $ModulesDir "Views.Settings.Pomodoro.ps1"
    $settingsView = Join-Path $ModulesDir "Views.Settings.ps1"
    $settingsApply = Join-Path $ModulesDir "Views.Settings.Apply.ps1"
    $settingsStarter = Join-Path $ModulesDir "Views.Settings.Starter.ps1"
    $settingsWorkflow = Join-Path $ModulesDir "SettingsWorkflow.ps1"
    $appMaintenance = Join-Path $ModulesDir "AppMaintenance.ps1"
    $taskArchive = Join-Path $ModulesDir "TaskArchive.ps1"
    $desktopShortcut = Join-Path $ModulesDir "DesktopShortcut.ps1"
    foreach ($requiredFile in @($mainScript, $settingsGeneral, $settingsPomodoro, $settingsView, $settingsApply, $settingsStarter, $settingsWorkflow, $appMaintenance, $taskArchive, $desktopShortcut)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1")
    $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("SettingsWorkflow.ps1", "TaskArchive.ps1", "AppMaintenance.ps1", "DesktopShortcut.ps1", "Views.Settings.Controls.ps1", "Views.Settings.General.ps1", "Views.Settings.Pomodoro.ps1", "Views.Settings.Apply.ps1", "Views.Settings.Starter.ps1", "Views.Settings.ps1")) {
        if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" }
    }
    if ([Array]::IndexOf($loadOrder, "Views.Settings.Controls.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Settings.General.ps1")) { throw "Views.Settings.Controls.ps1 must load before settings row modules" }
    if ([Array]::IndexOf($loadOrder, "Views.Settings.Pomodoro.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Settings.ps1")) { throw "Views.Settings.Pomodoro.ps1 must load before Views.Settings.ps1" }
    if ([Array]::IndexOf($loadOrder, "SettingsStore.ps1") -gt [Array]::IndexOf($loadOrder, "SettingsWorkflow.ps1")) { throw "SettingsStore.ps1 must load before SettingsWorkflow.ps1" }
    if ([Array]::IndexOf($loadOrder, "SettingsWorkflow.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Settings.Apply.ps1")) { throw "SettingsWorkflow.ps1 must load before Views.Settings.Apply.ps1" }
    foreach ($settingsSaveConsumer in @("TaskArchive.ps1", "AppMaintenance.ps1", "DesktopShortcut.ps1")) { if ([Array]::IndexOf($loadOrder, "SettingsWorkflow.ps1") -gt [Array]::IndexOf($loadOrder, $settingsSaveConsumer)) { throw "SettingsWorkflow.ps1 must load before $settingsSaveConsumer" } }
    Test-FileDoesNotContain $settingsView @("function Add-GeneralSettingsRows", "function Add-PomodoroSettingsRows", "New-AudioSettingControl", "New-VolumeSettingControl", "DailyArchiveTime") "Views.Settings.ps1 must keep row construction in settings row modules."
    $workflowRaw = Get-Content -LiteralPath $settingsWorkflow -Encoding UTF8 -Raw
    foreach ($required in @("function Save-GeneralSettings", "function Save-SettingsPreservingWindowState", "function Save-TranslationSettings", "function Save-TranslationRuntimeSettings", "function Save-TranslationDictionarySettings", "function Save-PomodoroDefaultSettings", "function Save-AppLifecycleSettings", "function Save-AppRuntimeSettings")) {
        if ($workflowRaw -notlike "*$required*") { throw "SettingsWorkflow.ps1 missing required marker: $required" }
    }
    foreach ($settingsUiFile in @($settingsView, $settingsApply, $settingsStarter)) {
        Test-FileDoesNotContain $settingsUiFile @("Save-Settings") "$([System.IO.Path]::GetFileName($settingsUiFile)) must use SettingsWorkflow save functions instead of Save-Settings directly."
    }
    foreach ($settingsSaveFile in @($appMaintenance, $taskArchive, $desktopShortcut)) {
        Test-FileDoesNotContain $settingsSaveFile @("Save-Settings") "$([System.IO.Path]::GetFileName($settingsSaveFile)) must use named SettingsWorkflow save functions instead of Save-Settings directly."
    }
    $mainRaw = Get-Content -LiteralPath $mainScript -Encoding UTF8 -Raw
    if ($mainRaw -match '(?m)^\s*Save-Settings(\s|$)') { throw "TaskPomodoro.ps1 must use named SettingsWorkflow save functions instead of Save-Settings directly." }
    foreach ($required in @("Save-SettingsPreservingWindowState", "Save-AppLifecycleSettings")) { if ($mainRaw -notlike "*$required*") { throw "TaskPomodoro.ps1 missing settings workflow marker: $required" } }
    $requiredMarkersByModule = @(
        @{ File = $settingsGeneral; Required = @("function Add-GeneralSettingsRows", "GeneralSettings", "DailyArchiveTime", "New-VolumeSettingControl") },
        @{ File = $settingsPomodoro; Required = @("function Add-PomodoroSettingsRows", "PomodoroSettings", "StartSoundReminder", "BreakMusic") },
        @{ File = $settingsView; Required = @("function Render-SettingsView", "Add-GeneralSettingsRows", "Add-PomodoroSettingsRows", "Apply-SettingsControls", "Save-GeneralSettings") },
        @{ File = $settingsApply; Required = @("function Apply-SettingsControls", "Apply-TranslationSettingsControls", "Save-GeneralSettings") },
        @{ File = $settingsStarter; Required = @("function Apply-StarterSettingsControls", "Save-GeneralSettings") },
        @{ File = $appMaintenance; Required = @("Save-AppLifecycleSettings") },
        @{ File = $taskArchive; Required = @("Save-AppRuntimeSettings") },
        @{ File = $desktopShortcut; Required = @("Save-AppRuntimeSettings") },
        @{ File = $mainScript; Required = @("Save-SettingsPreservingWindowState", "Save-AppLifecycleSettings") }
    )
    foreach ($entry in $requiredMarkersByModule) {
        $raw = Get-Content -LiteralPath $entry.File -Encoding UTF8 -Raw
        foreach ($required in $entry.Required) { if ($raw -notlike "*$required*") { throw "$([System.IO.Path]::GetFileName($entry.File)) missing required marker: $required" } }
    }
    "Settings row construction is split from settings view shell"
}
