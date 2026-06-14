# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Format-Time([int]$Seconds) {
    if ($Seconds -lt 0) {
        $Seconds = 0
    }
    $minutes = [Math]::Floor($Seconds / 60)
    $remainingSeconds = $Seconds % 60
    return "{0:00}:{1:00}" -f $minutes, $remainingSeconds
}

function New-PomodoroOperationResult(
    [bool]$Ok,
    [string]$StatusKey,
    [string]$View,
    [bool]$ShouldUpdateTimer,
    [object]$Data
) {
    return [pscustomobject]@{
        Ok = $Ok
        StatusKey = $StatusKey
        MessageKey = ""
        View = $View
        ShouldRender = $false
        ShouldUpdateTimer = $ShouldUpdateTimer
        Data = $Data
    }
}

function Start-Pomodoro([string]$TaskId) {
    if ($script:TimerState -ne "idle") {
        $result = New-PomodoroOperationResult $false "" "" $false $null
        $result.MessageKey = "TimerAlreadyRunning"
        return $result
    }

    $script:CurrentPomodoroTaskId = $TaskId
    $task = $null
    if (-not [string]::IsNullOrWhiteSpace($TaskId)) {
        $task = Get-TaskById $TaskId
    }
    if ($null -ne $task) {
        $script:CurrentPomodoroTaskTitle = $task.title
    }
    else {
        $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
        $script:CurrentPomodoroTaskId = $null
    }

    $script:TimerPhase = "work"
    if ([bool]$script:Settings.StartSoundReminder) {
        Play-StartSound
    }
    $script:PomodoroStartedAt = Get-IsoNow
    $script:PomodoroStartedAtDate = Get-Date
    $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Start-BackgroundAudio "work"
    return New-PomodoroOperationResult $true "Focusing" "timer" $true $script:CurrentPomodoroTaskId
}

function Pause-Pomodoro {
    if ($script:TimerState -ne "running") {
        return New-PomodoroOperationResult $false "" "" $false $null
    }
    $script:SecondsRemaining = [Math]::Max(0, [int][Math]::Ceiling(($script:PomodoroEndAt - (Get-Date)).TotalSeconds))
    $script:TimerState = "paused"
    Stop-BackgroundAudio
    return New-PomodoroOperationResult $true "" "" $true $null
}

function Continue-Pomodoro {
    if ($script:TimerState -ne "paused") {
        return New-PomodoroOperationResult $false "" "" $false $null
    }
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Start-BackgroundAudio $script:TimerPhase
    return New-PomodoroOperationResult $true "" "" $true $null
}

function Stop-Pomodoro {
    if ($script:TimerState -eq "idle") {
        $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
        Stop-BackgroundAudio
        return New-PomodoroOperationResult $true "" "" $true $null
    }

    $ended = Get-IsoNow
    $elapsed = 0
    if ($null -ne $script:PomodoroStartedAtDate) {
        $elapsed = [int][Math]::Max(0, ((Get-Date) - $script:PomodoroStartedAtDate).TotalSeconds)
    }
    if ($script:TimerPhase -eq "break") {
        Append-PomodoroRecord $null $script:PomodoroStartedAt $ended ([int]$script:Settings.ShortBreakMinutes) $elapsed "skipped_break"
    }
    else {
        Append-PomodoroRecord $script:CurrentPomodoroTaskId $script:PomodoroStartedAt $ended ([int]$script:Settings.WorkMinutes) $elapsed "interrupted"
    }
    Stop-BackgroundAudio
    $script:TimerState = "idle"
    $script:TimerPhase = "work"
    $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    $script:CurrentPomodoroTaskId = $null
    $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
    return New-PomodoroOperationResult $true "PomodoroInterrupted" "" $true $null
}

function Complete-Pomodoro {
    if ($script:TimerPhase -eq "break") {
        return Complete-Break
    }

    $ended = Get-IsoNow
    $plannedSeconds = [int]$script:Settings.WorkMinutes * 60
    Append-PomodoroRecord $script:CurrentPomodoroTaskId $script:PomodoroStartedAt $ended ([int]$script:Settings.WorkMinutes) $plannedSeconds "completed"

    if (-not [string]::IsNullOrWhiteSpace($script:CurrentPomodoroTaskId)) {
        $task = Get-TaskById $script:CurrentPomodoroTaskId
        if ($null -ne $task) {
            $task.pomodoroCount = [int]$task.pomodoroCount + 1
            Save-Tasks
        }
    }

    Stop-BackgroundAudio
    Trigger-Reminder
    return Start-BreakTimer
}

function Start-BreakTimer {
    $script:TimerPhase = "break"
    $script:PomodoroStartedAt = Get-IsoNow
    $script:PomodoroStartedAtDate = Get-Date
    $script:SecondsRemaining = [int]$script:Settings.ShortBreakMinutes * 60
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Start-BackgroundAudio "break"
    return New-PomodoroOperationResult $true "BreakFocusing" "" $true $null
}

function Complete-Break {
    $ended = Get-IsoNow
    $plannedSeconds = [int]$script:Settings.ShortBreakMinutes * 60
    Append-PomodoroRecord $null $script:PomodoroStartedAt $ended ([int]$script:Settings.ShortBreakMinutes) $plannedSeconds "break_completed"

    Stop-BackgroundAudio
    $script:TimerState = "idle"
    $script:TimerPhase = "work"
    $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    $script:CurrentPomodoroTaskId = $null
    $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
    return New-PomodoroOperationResult $true "BreakDone" "" $true $null
}

