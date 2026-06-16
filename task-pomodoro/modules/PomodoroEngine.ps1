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
function Get-TaskRemainingPomodoros([object]$Task) {
    if ($null -eq $Task -or $null -eq $Task.estimatedPomodoroCount) { return 0 }
    return [Math]::Max(0, ([int]$Task.estimatedPomodoroCount - [int]$Task.pomodoroCount))
}
function Add-TaskEstimatedPomodoros([object]$Task, [int]$Count) {
    if ($null -eq $Task -or $Count -le 0) { return $false }
    $baseline = [Math]::Max([int]$Task.estimatedPomodoroCount, [int]$Task.pomodoroCount)
    $Task.estimatedPomodoroCount = $baseline + $Count
    Save-Tasks
    return $true
}

function Start-Pomodoro([string]$TaskId) {
    if ($script:TimerState -ne "idle") {
        $result = New-PomodoroOperationResult $false "" "" $false $null
        $result.MessageKey = "TimerAlreadyRunning"
        return $result
    }

    if ([int]$script:PomodoroSessionStartedCount -gt 0 -and [string]$TaskId -ne [string]$script:CurrentPomodoroTaskId) {
        Reset-PomodoroSession
    }
    Ensure-PomodoroSession $TaskId
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

    $script:PomodoroSessionStartedCount = [int]$script:PomodoroSessionStartedCount + 1
    $script:TimerPhase = "work"
    if ([bool]$script:Settings.StartSoundReminder) {
        Play-StartSound
    }
    $script:PomodoroStartedAt = Get-IsoNow
    $script:PomodoroStartedAtDate = Get-Date
    $script:CurrentPhasePlannedMinutes = Get-PomodoroWorkMinutes
    $script:SecondsRemaining = [int]$script:CurrentPhasePlannedMinutes * 60
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
        Reset-PomodoroSession
        $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
        $script:TimerPhase = "work"
        $script:CurrentPomodoroTaskId = $null
        $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
        Stop-BackgroundAudio
        return New-PomodoroOperationResult $true "" "" $true $null
    }

    $ended = Get-IsoNow
    $elapsed = 0
    if ($null -ne $script:PomodoroStartedAtDate) {
        $elapsed = [int][Math]::Max(0, ((Get-Date) - $script:PomodoroStartedAtDate).TotalSeconds)
    }
    if ($script:TimerPhase -eq "break") {
        Append-PomodoroRecord $null $script:PomodoroStartedAt $ended (Get-PomodoroBreakMinutes) $elapsed "skipped_break"
    }
    else {
        Append-PomodoroRecord $script:CurrentPomodoroTaskId $script:PomodoroStartedAt $ended (Get-PomodoroWorkMinutes) $elapsed "interrupted"
    }
    Stop-BackgroundAudio
    Reset-PomodoroSession
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
    $plannedSeconds = (Get-PomodoroWorkMinutes) * 60
    Append-PomodoroRecord $script:CurrentPomodoroTaskId $script:PomodoroStartedAt $ended (Get-PomodoroWorkMinutes) $plannedSeconds "completed"

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
    $script:CurrentPhasePlannedMinutes = Get-PomodoroBreakMinutes
    $script:SecondsRemaining = [int]$script:CurrentPhasePlannedMinutes * 60
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Start-BackgroundAudio "break"
    return New-PomodoroOperationResult $true "BreakFocusing" "" $true $null
}

function Complete-Break {
    $ended = Get-IsoNow
    $plannedSeconds = (Get-PomodoroBreakMinutes) * 60
    Append-PomodoroRecord $null $script:PomodoroStartedAt $ended (Get-PomodoroBreakMinutes) $plannedSeconds "break_completed"

    $hasNextPomodoro = ([int]$script:PomodoroSessionStartedCount -lt [int]$script:PomodoroSessionMaxRounds)
    $nextTaskId = $null
    if (-not [string]::IsNullOrWhiteSpace($script:CurrentPomodoroTaskId)) {
        $task = Get-TaskById $script:CurrentPomodoroTaskId
        if ((Get-TaskRemainingPomodoros $task) -gt 0) { $nextTaskId = [string]$task.id } else { $hasNextPomodoro = $false }
    }
    Stop-BackgroundAudio
    $script:TimerState = "idle"
    $script:TimerPhase = "work"
    $script:SecondsRemaining = (Get-PomodoroWorkMinutes) * 60
    if ($hasNextPomodoro -and (Get-PomodoroAutoStartNext)) {
        return Start-Pomodoro $nextTaskId
    }
    if ($hasNextPomodoro) {
        if (-not [string]::IsNullOrWhiteSpace($nextTaskId)) {
            $script:CurrentPomodoroTaskId = $nextTaskId
            $script:CurrentPomodoroTaskTitle = (Get-TaskById $nextTaskId).title
        }
        return New-PomodoroOperationResult $true "ReadyNextPomodoro" "" $true $null
    }
    Reset-PomodoroSession
    $script:CurrentPomodoroTaskId = $null
    $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
    return New-PomodoroOperationResult $true "BreakDone" "" $true $null
}

