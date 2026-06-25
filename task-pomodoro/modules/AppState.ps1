# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Initialize-AppState([string]$RootDir) {
    if ([string]::IsNullOrWhiteSpace($RootDir)) {
        throw "RootDir is required."
    }

    $root = [System.IO.Path]::GetFullPath($RootDir)
    $dataDir = Join-Path $root "data"
    $configDir = Join-Path $root "config"

    $script:App = [pscustomobject][ordered]@{
        Paths = [pscustomobject][ordered]@{
            RootDir = $root
            ModulesDir = Join-Path $root "modules"
            DataDir = $dataDir
            ConfigDir = $configDir
            BackupDir = Join-Path $dataDir "backups"
            TasksFile = Join-Path $dataDir "tasks.json"
            InboxFile = Join-Path $dataDir "inbox.json"
            TimerStateFile = Join-Path $dataDir "timer-state.json"
            PomodorosFile = Join-Path $dataDir "pomodoros.jsonl"
            BehaviorEventsFile = Join-Path $dataDir "behavior-events.jsonl"
            SettingsFile = Join-Path $configDir "settings.json"
        }
        Ui = [ordered]@{}
        Window = [ordered]@{}
        Timer = [ordered]@{}
        Runtime = [ordered]@{}
    }

    Sync-AppLegacyPathAliases
}

function Sync-AppLegacyPathAliases {
    if ($null -eq $script:App -or $null -eq $script:App.Paths) {
        throw "App state has not been initialized."
    }

    $paths = $script:App.Paths
    $script:RootDir = [string]$paths.RootDir
    $script:ModulesDir = [string]$paths.ModulesDir
    $script:DataDir = [string]$paths.DataDir
    $script:ConfigDir = [string]$paths.ConfigDir
    $script:BackupDir = [string]$paths.BackupDir
    $script:TasksFile = [string]$paths.TasksFile
    $script:InboxFile = [string]$paths.InboxFile
    $script:TimerStateFile = [string]$paths.TimerStateFile
    $script:PomodorosFile = [string]$paths.PomodorosFile
    $script:BehaviorEventsFile = [string]$paths.BehaviorEventsFile
    $script:SettingsFile = [string]$paths.SettingsFile
}

function Get-AppPath([string]$Name) {
    if ($null -eq $script:App -or $null -eq $script:App.Paths) {
        throw "App state has not been initialized."
    }
    if (-not ($script:App.Paths.PSObject.Properties.Name -contains $Name)) {
        throw "Unknown app path: $Name"
    }
    return [string]$script:App.Paths.$Name
}
