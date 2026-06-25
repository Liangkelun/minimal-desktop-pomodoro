# This file is dot-sourced by TaskPomodoro.ps1. It owns Pomodoro result-event object helpers, not side-effect handlers.

function New-PomodoroEvent([string]$Type, [hashtable]$Data = @{}) {
    return New-AppEvent $Type $Data
}

function Add-PomodoroResultEvents([object]$Result, [object[]]$Events) {
    return Add-AppResultEvents $Result $Events
}

function New-PomodoroPlayStartSoundEvent { return New-PomodoroEvent "PlayStartSound" }
function New-PomodoroStopBackgroundAudioEvent { return New-PomodoroEvent "StopBackgroundAudio" }
function New-PomodoroStartBackgroundAudioEvent([string]$Phase) { return New-PomodoroEvent "StartBackgroundAudio" @{ Phase = $Phase } }
function New-PomodoroTriggerReminderEvent { return New-PomodoroEvent "TriggerReminder" }
function New-PomodoroIncrementTaskEvent([string]$TaskId) { return New-PomodoroEvent "IncrementTaskPomodoro" @{ TaskId = $TaskId } }

function New-PomodoroAppendRecordEvent([object]$TaskId, [string]$StartedAt, [string]$EndedAt, [int]$PlannedMinutes, [int]$ActualSeconds, [string]$Result) {
    return New-PomodoroEvent "AppendPomodoroRecord" @{ TaskId = $TaskId; StartedAt = $StartedAt; EndedAt = $EndedAt; PlannedMinutes = $PlannedMinutes; ActualSeconds = $ActualSeconds; Result = $Result }
}

function Get-PomodoroElapsedSeconds([object]$StartedAtDate) {
    if ($null -eq $StartedAtDate) { return 0 }
    return [int][Math]::Max(0, ((Get-Date) - $StartedAtDate).TotalSeconds)
}

function New-PomodoroInterruptedRecordEvent([object]$Runtime, [string]$EndedAt) {
    $actualSeconds = Get-PomodoroElapsedSeconds $Runtime.StartedAtDate
    if ([bool]$Runtime.IsBreak) {
        return New-PomodoroAppendRecordEvent $null ([string]$Runtime.StartedAt) $EndedAt (Get-PomodoroBreakMinutes) $actualSeconds "skipped_break"
    }
    return New-PomodoroAppendRecordEvent $Runtime.TaskId ([string]$Runtime.StartedAt) $EndedAt (Get-PomodoroWorkMinutes) $actualSeconds "interrupted"
}

function New-PomodoroCompletedWorkRecordEvent([object]$Runtime, [string]$EndedAt) {
    $plannedMinutes = Get-PomodoroWorkMinutes
    return New-PomodoroAppendRecordEvent $Runtime.TaskId ([string]$Runtime.StartedAt) $EndedAt $plannedMinutes ($plannedMinutes * 60) "completed"
}

function New-PomodoroCompletedBreakRecordEvent([object]$Runtime, [string]$EndedAt) {
    $plannedMinutes = Get-PomodoroBreakMinutes
    return New-PomodoroAppendRecordEvent $null ([string]$Runtime.StartedAt) $EndedAt $plannedMinutes ($plannedMinutes * 60) "break_completed"
}
