# This file is dot-sourced by TaskPomodoro.ps1. It names settings persistence policy at call sites.

function Save-SettingsWithNotification([string]$Scope, [bool]$PreserveWindow) {
    if ($PreserveWindow) { Save-Settings -PreserveWindow }
    else { Save-Settings }
    Publish-AppNotification "SettingsChanged" @{ Scope = $Scope; PreserveWindow = $PreserveWindow } | Out-Null
}

function Save-GeneralSettings {
    Save-SettingsWithNotification "general" $false
}

function Save-SettingsPreservingWindowState {
    Save-SettingsWithNotification "preserve-window" $true
}

function Save-TranslationSettings {
    Save-SettingsWithNotification "translation" $true
}

function Save-TranslationRuntimeSettings {
    Save-SettingsWithNotification "translation-runtime" $true
}

function Save-TranslationDictionarySettings {
    Save-SettingsWithNotification "translation-dictionary" $true
}

function Save-PomodoroDefaultSettings {
    Save-SettingsWithNotification "pomodoro-default" $false
}

function Save-AppLifecycleSettings {
    Save-SettingsWithNotification "app-lifecycle" $false
}

function Save-AppRuntimeSettings {
    Save-SettingsWithNotification "app-runtime" $true
}
