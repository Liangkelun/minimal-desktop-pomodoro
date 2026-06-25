# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Load-Settings {
    $settingsFile = Get-AppPath "SettingsFile"
    if (-not (Test-Path -LiteralPath $settingsFile)) {
        $script:Settings = Get-DefaultSettings
        Save-Settings
        return
    }

    try {
        $raw = Get-Content -LiteralPath $settingsFile -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            throw "empty settings"
        }
        $script:Settings = $raw | ConvertFrom-Json
        Normalize-Settings
    }
    catch {
        Backup-DataFile $settingsFile "invalid"
        $script:Settings = Get-DefaultSettings
        Save-Settings
    }
}

function Reset-SettingsToDefaults {
    $language = Get-DefaultLanguage
    $lastDailyArchiveAt = $null
    $desktopShortcutPrompted = $false
    if ($null -ne $script:Settings) {
        if ($script:Settings.PSObject.Properties.Name -contains "Language") {
            $language = [string]$script:Settings.Language
        }
        if ($script:Settings.PSObject.Properties.Name -contains "LastDailyArchiveAt") {
            $lastDailyArchiveAt = $script:Settings.LastDailyArchiveAt
        }
        if ($script:Settings.PSObject.Properties.Name -contains "DesktopShortcutPrompted") {
            $desktopShortcutPrompted = [bool]$script:Settings.DesktopShortcutPrompted
        }
    }

    $script:Settings = Get-DefaultSettings
    $script:Settings.Language = $language
    $script:Settings.LastDailyArchiveAt = $lastDailyArchiveAt
    $script:Settings.DesktopShortcutPrompted = $desktopShortcutPrompted
    Sync-SettingsWindowStateFromRuntime
    Apply-SettingsWindowChromeFromSettings
    Normalize-Settings
}

function Save-Settings([switch]$PreserveWindow) {
    if (-not $PreserveWindow) {
        Sync-SettingsWindowStateFromRuntime
    }
    Normalize-Settings
    Write-JsonAtomic (Get-AppPath "SettingsFile") $script:Settings
}