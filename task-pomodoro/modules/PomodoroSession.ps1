# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-PomodoroWorkMinutes { if ([int]$script:PomodoroSessionWorkMinutes -gt 0) { return [int]$script:PomodoroSessionWorkMinutes }; return [int]$script:Settings.WorkMinutes }
function Get-PomodoroBreakMinutes { if ([int]$script:PomodoroSessionBreakMinutes -gt 0) { return [int]$script:PomodoroSessionBreakMinutes }; return [int]$script:Settings.ShortBreakMinutes }
function Get-PomodoroAutoStartNext { if ($null -ne $script:PomodoroSessionAutoStartNext) { return [bool]$script:PomodoroSessionAutoStartNext }; return [bool]$script:Settings.AutoStartNextPomodoro }
function Get-TaskStarterMinutes { return [Math]::Min(30, [Math]::Max(1, [int]$script:Settings.StarterMinutes)) }
function Get-TaskStarterSeconds { return (Get-TaskStarterMinutes) * 60 }

function Get-PomodoroSessionStartedCount { return [int]$script:PomodoroSessionStartedCount }
function Get-PomodoroSessionMaxRounds { return [int]$script:PomodoroSessionMaxRounds }

function Test-PomodoroSessionStartedForDifferentTask([string]$TaskId, [string]$CurrentTaskId) {
    return ((Get-PomodoroSessionStartedCount) -gt 0 -and [string]$TaskId -ne [string]$CurrentTaskId)
}

function Add-PomodoroSessionStartedCount {
    $script:PomodoroSessionStartedCount = (Get-PomodoroSessionStartedCount) + 1
    return [int]$script:PomodoroSessionStartedCount
}

function Test-PomodoroSessionHasNextRound {
    return ((Get-PomodoroSessionStartedCount) -lt (Get-PomodoroSessionMaxRounds))
}


function Reset-PomodoroSession {
    $script:PomodoroSessionWorkMinutes = 0
    $script:PomodoroSessionBreakMinutes = 0
    $script:PomodoroSessionMaxRounds = 0
    $script:PomodoroSessionStartedCount = 0
    $script:PomodoroSessionAutoStartNext = $null
    Clear-PomodoroRuntimePlannedDuration
}

function Get-InitialPomodoroRounds([string]$TaskId) {
    $rounds = [int]$script:Settings.PomodoroRounds
    $task = Get-TaskById $TaskId
    if ($null -ne $task) {
        $remaining = Get-TaskRemainingPomodoros $task
        if ($remaining -gt 0) { $rounds = $remaining }
    }
    return [Math]::Max(1, $rounds)
}

function Ensure-PomodoroSession([string]$TaskId) {
    if ([int]$script:PomodoroSessionMaxRounds -gt 0) { return }
    $script:PomodoroSessionWorkMinutes = [int]$script:Settings.WorkMinutes
    $script:PomodoroSessionBreakMinutes = [int]$script:Settings.ShortBreakMinutes
    $script:PomodoroSessionMaxRounds = Get-InitialPomodoroRounds $TaskId
    $script:PomodoroSessionStartedCount = 0
    $script:PomodoroSessionAutoStartNext = [bool]$script:Settings.AutoStartNextPomodoro
}

function Set-PomodoroSessionOptions([int]$WorkMinutes, [int]$BreakMinutes, [int]$Rounds, [bool]$AutoStartNext, [bool]$SaveAsDefault) {
    $script:PomodoroSessionWorkMinutes = [Math]::Min(180, [Math]::Max(1, $WorkMinutes))
    $script:PomodoroSessionBreakMinutes = [Math]::Min(60, [Math]::Max(1, $BreakMinutes))
    $script:PomodoroSessionMaxRounds = [Math]::Min(24, [Math]::Max(1, $Rounds))
    $script:PomodoroSessionAutoStartNext = $AutoStartNext
    if ($SaveAsDefault) {
        $script:Settings.WorkMinutes = [int]$script:PomodoroSessionWorkMinutes
        $script:Settings.ShortBreakMinutes = [int]$script:PomodoroSessionBreakMinutes
        $script:Settings.PomodoroRounds = [int]$script:PomodoroSessionMaxRounds
        $script:Settings.AutoStartNextPomodoro = $AutoStartNext
        Save-PomodoroDefaultSettings
    }
    Update-CurrentPomodoroDuration
}

function Update-CurrentPomodoroDuration {
    $minutes = Get-PomodoroWorkMinutes
    if (Test-PomodoroRuntimeBreakPhase) { $minutes = Get-PomodoroBreakMinutes }
    Update-PomodoroRuntimeDuration $minutes
}
