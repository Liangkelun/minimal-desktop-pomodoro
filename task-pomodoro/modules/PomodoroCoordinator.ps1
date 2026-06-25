# This file is dot-sourced by TaskPomodoro.ps1. Keep Pomodoro result-event side effects out of engines and workflows.

function Invoke-AppResultEvent([object]$Event) {
    switch ([string]$Event.Type) {
        "TaskTimerInvalidated" {
            $timerEvents = @(Invoke-PomodoroTaskInvalidationWorkflow ([string]$Event.TaskId))
            if ($timerEvents.Count -gt 0) { Invoke-AppResultEvents ([pscustomobject]@{ Events = $timerEvents }) }
        }
        "PlayStartSound" { Play-StartSound }
        "StopBackgroundAudio" { Stop-BackgroundAudio }
        "StartBackgroundAudio" { Start-BackgroundAudio ([string]$Event.Phase) }
        "TriggerReminder" { Trigger-Reminder }
        "AppendPomodoroRecord" {
            Append-PomodoroRecord $Event.TaskId ([string]$Event.StartedAt) ([string]$Event.EndedAt) ([int]$Event.PlannedMinutes) ([int]$Event.ActualSeconds) ([string]$Event.Result)
        }
        "AppendBehaviorEvent" {
            Append-BehaviorEvent ([string]$Event.BehaviorType) ([string]$Event.TaskId) ([string]$Event.SessionId) ([string]$Event.Source) $Event.Payload
        }
        "IncrementTaskPomodoro" {
            if (-not [string]::IsNullOrWhiteSpace([string]$Event.TaskId)) {
                $task = Get-TaskById ([string]$Event.TaskId)
                if ($null -ne $task) { $task.pomodoroCount = [int]$task.pomodoroCount + 1; Save-Tasks }
            }
        }
    }
}

function Invoke-PomodoroResultEvents([object]$Result) {
    Invoke-AppResultEvents $Result
}