# This file is dot-sourced by TaskPomodoro.ps1. It exposes read-only Pomodoro runtime snapshots.

function Test-PomodoroRuntimeIdle { return ([string]$script:TimerState -eq "idle") }

function Test-PomodoroRuntimeStarterPhase { return ([string]$script:TimerPhase -eq "starter") }

function Test-PomodoroRuntimeStarterForTask([string]$TaskId) {
    return ((Test-PomodoroRuntimeStarterPhase) -and $script:TimerState -in @("running", "paused") -and [string]$script:CurrentPomodoroTaskId -eq [string]$TaskId)
}
function Test-PomodoroRuntimePaused { return ([string]$script:TimerState -eq "paused") }

function Test-PomodoroRuntimeRunning { return ([string]$script:TimerState -eq "running") }

function Get-PomodoroRuntimeCurrentTaskId { return [string]$script:CurrentPomodoroTaskId }

function Get-PomodoroRuntimeEngineSnapshot {
    $state = [string]$script:TimerState
    $phase = [string]$script:TimerPhase
    return [pscustomobject]@{
        State = $state
        Phase = $phase
        TaskId = $script:CurrentPomodoroTaskId
        StartedAt = $script:PomodoroStartedAt
        StartedAtDate = $script:PomodoroStartedAtDate
        IsIdle = ($state -eq "idle")
        IsRunning = ($state -eq "running")
        IsPaused = ($state -eq "paused")
        IsStarter = ($phase -eq "starter")
        IsBreak = ($phase -eq "break")
    }
}

function Get-PomodoroRuntimeTimerViewSnapshot {
    $state = [string]$script:TimerState
    $phase = [string]$script:TimerPhase
    return [pscustomobject]@{
        State = $state
        Phase = $phase
        RemainingSeconds = [int][Math]::Max(0, [int]$script:SecondsRemaining)
        TaskId = [string]$script:CurrentPomodoroTaskId
        TaskTitle = [string]$script:CurrentPomodoroTaskTitle
        PlannedMinutes = [int]$script:CurrentPhasePlannedMinutes
        StartedAt = [string]$script:PomodoroStartedAt
        EndAt = if ($null -eq $script:PomodoroEndAt) { "" } else { $script:PomodoroEndAt.ToString("yyyy-MM-ddTHH:mm:sszzz") }
        PausedAt = if ($null -eq $script:PomodoroPausedAtDate) { "" } else { $script:PomodoroPausedAtDate.ToString("yyyy-MM-ddTHH:mm:sszzz") }
        PauseThresholdsTriggered = @($script:PomodoroPauseThresholdsTriggered)
        IsIdle = ($state -eq "idle")
        IsRunning = ($state -eq "running")
        IsPaused = ($state -eq "paused")
        IsStarter = ($phase -eq "starter")
        IsBreak = ($phase -eq "break")
    }
}


function Get-PomodoroRuntimeCompletionNotificationSnapshot {
    return [pscustomobject]@{
        Phase = [string]$script:TimerPhase
        TaskId = [string]$script:CurrentPomodoroTaskId
        TaskTitle = [string]$script:CurrentPomodoroTaskTitle
        StartedAt = [string]$script:PomodoroStartedAt
    }
}

function Test-PomodoroRuntimeBreakPhase { return ([string]$script:TimerPhase -eq "break") }

function Get-PomodoroRuntimeInlineCountdownSnapshot([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) { return $null }
    if ($script:TimerState -notin @("running", "paused")) { return $null }
    $boundTaskId = [string]$script:CurrentPomodoroTaskId
    if ([string]::IsNullOrWhiteSpace($boundTaskId) -or $boundTaskId -ne [string]$TaskId) { return $null }
    $kind = switch ([string]$script:TimerPhase) {
        "starter" { "starter" }
        "work" { "pomodoro" }
        "break" { "break" }
        default { "" }
    }
    if ([string]::IsNullOrWhiteSpace($kind)) { return $null }
    return [pscustomobject]@{ TaskId = $boundTaskId; Kind = $kind; RemainingSeconds = [int][Math]::Max(0, [int]$script:SecondsRemaining) }
}
