# This file is dot-sourced by TaskPomodoro.ps1. It owns Pomodoro state-transition event sets.

function New-PomodoroWorkStartedEvents {
    $events = @()
    if ([bool]$script:Settings.StartSoundReminder) { $events += (New-PomodoroPlayStartSoundEvent) }
    $events += (New-PomodoroStartBackgroundAudioEvent "work")
    return @($events)
}

function Test-PomodoroRuntimePauseCountsAsInterruption([object]$Runtime) {
    if ($null -eq $Runtime) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Runtime.TaskId)) { return $false }
    return ([string]$Runtime.Phase -in @("work", "break"))
}

function New-PomodoroPausedEvents([object]$Runtime) {
    $events = @((New-PomodoroStopBackgroundAudioEvent))
    if (Test-PomodoroRuntimePauseCountsAsInterruption $Runtime) {
        $events += (New-BehaviorResultEvent "pomodoro_paused" ([string]$Runtime.TaskId) (Get-BehaviorSessionForTask ([string]$Runtime.TaskId)) "user" @{ Phase = [string]$Runtime.Phase; PausedAt = [string]$Runtime.PausedAt; RemainingSeconds = [int]$Runtime.RemainingSeconds })
    }
    return @($events)
}

function New-PomodoroResumedEvents([object]$Runtime) {
    $phase = [string]$Runtime.Phase
    $events = @((New-PomodoroStartBackgroundAudioEvent $phase))
    if (Test-PomodoroRuntimePauseCountsAsInterruption $Runtime) {
        $events += (New-BehaviorResultEvent "pomodoro_resumed" ([string]$Runtime.TaskId) (Get-BehaviorSessionForTask ([string]$Runtime.TaskId)) "user" @{ Phase = $phase; PausedAt = [string]$Runtime.PausedAt; RemainingSeconds = [int]$Runtime.RemainingSeconds; PauseThresholdsTriggered = @($Runtime.PauseThresholdsTriggered) })
    }
    return @($events)
}
function New-PomodoroIdleStoppedEvents { return @((New-PomodoroStopBackgroundAudioEvent)) }

function New-PomodoroPauseThresholdEvents([object]$Tick) {
    if ($null -eq $Tick -or [string]::IsNullOrWhiteSpace([string]$Tick.TaskId)) { return @() }
    return @((New-BehaviorResultEvent "pomodoro_pause_interrupted" ([string]$Tick.TaskId) (Get-BehaviorSessionForTask ([string]$Tick.TaskId)) "timer" @{ Phase = [string]$Tick.Phase; ThresholdMinutes = [int]$Tick.ThresholdMinutes; PausedSeconds = [int]$Tick.PausedSeconds; PausedAt = [string]$Tick.PausedAt }))
}

function New-PomodoroInterruptedEvents([object]$Runtime, [string]$EndedAt) {
    $events = @((New-PomodoroInterruptedRecordEvent $Runtime $EndedAt), (New-PomodoroStopBackgroundAudioEvent))
    if (-not [string]::IsNullOrWhiteSpace([string]$Runtime.TaskId)) { $events += (New-BehaviorResultEvent "pomodoro_interrupted" ([string]$Runtime.TaskId) (Get-BehaviorSessionForTask ([string]$Runtime.TaskId)) "user" @{ EndedAt = $EndedAt }) }
    return @($events)
}

function New-PomodoroWorkCompletedEvents([object]$Runtime, [string]$EndedAt) {
    $events = @((New-PomodoroCompletedWorkRecordEvent $Runtime $EndedAt))
    if (-not [string]::IsNullOrWhiteSpace([string]$Runtime.TaskId)) {
        $events += (New-PomodoroIncrementTaskEvent ([string]$Runtime.TaskId))
        $events += (New-BehaviorResultEvent "pomodoro_completed" ([string]$Runtime.TaskId) (Get-BehaviorSessionForTask ([string]$Runtime.TaskId)) "user" @{ EndedAt = $EndedAt; PlannedMinutes = (Get-PomodoroWorkMinutes) })
    }
    $events += (New-PomodoroStopBackgroundAudioEvent)
    $events += (New-PomodoroTriggerReminderEvent)
    return @($events)
}

function New-PomodoroBreakStartedEvents { return @((New-PomodoroStartBackgroundAudioEvent "break")) }

function New-PomodoroBreakCompletedEvents([object]$Runtime, [string]$EndedAt) {
    return @((New-PomodoroCompletedBreakRecordEvent $Runtime $EndedAt), (New-PomodoroStopBackgroundAudioEvent))
}
function New-PomodoroStarterStartedEvents { return @((New-PomodoroStartBackgroundAudioEvent "starter")) }
function New-PomodoroStarterStoppedEvents { return @((New-PomodoroStopBackgroundAudioEvent)) }
function New-PomodoroStarterCompletedEvents { return @((New-PomodoroStopBackgroundAudioEvent)) }
