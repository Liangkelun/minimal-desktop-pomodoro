# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Start-Pomodoro([string]$TaskId) {
    $runtime = Get-PomodoroRuntimeEngineSnapshot
    if (-not [bool]$runtime.IsIdle) {
        $result = New-PomodoroOperationResult $false "" "" $false $null
        $result.MessageKey = "TimerAlreadyRunning"
        return $result
    }

    if (Test-PomodoroSessionStartedForDifferentTask $TaskId ([string]$runtime.TaskId)) {
        Reset-PomodoroSession
    }
    Ensure-PomodoroSession $TaskId
    $taskBinding = Get-PomodoroStartTaskBinding $TaskId
    if ([bool]$taskBinding.HasTask) { Set-PomodoroRuntimeCurrentTask ([string]$taskBinding.TaskId) ([string]$taskBinding.TaskTitle) }
    else { Clear-PomodoroRuntimeCurrentTask }

    Add-PomodoroSessionStartedCount | Out-Null
    Start-PomodoroRuntimePhase "work" (Get-PomodoroWorkMinutes)

    $startedTaskId = [string](Get-PomodoroRuntimeEngineSnapshot).TaskId
    $sessionId = Start-BehaviorSessionForTask $startedTaskId
    $events = @(New-PomodoroWorkStartedEvents)
    if (-not [string]::IsNullOrWhiteSpace($startedTaskId)) {
        $events += (New-BehaviorResultEvent "task_started" $startedTaskId $sessionId "user" @{})
        $events += (New-BehaviorResultEvent "pomodoro_started" $startedTaskId $sessionId "user" @{ PlannedMinutes = (Get-PomodoroWorkMinutes) })
    }
    return New-PomodoroOperationResult $true "Focusing" "timer" $true $startedTaskId $events
}

function Pause-Pomodoro {
    if (-not (Test-PomodoroRuntimeRunning)) {
        return New-PomodoroOperationResult $false "" "" $false $null
    }
    Pause-PomodoroRuntimePhase
    $runtime = Get-PomodoroRuntimeTimerViewSnapshot
    return New-PomodoroOperationResult $true "" "" $true $null (New-PomodoroPausedEvents $runtime)
}

function Continue-Pomodoro {
    $runtime = Get-PomodoroRuntimeTimerViewSnapshot
    if (-not [bool]$runtime.IsPaused) {
        return New-PomodoroOperationResult $false "" "" $false $null
    }
    Resume-PomodoroRuntimePhase
    return New-PomodoroOperationResult $true "" "" $true $null (New-PomodoroResumedEvents $runtime)
}

function New-PomodoroPauseThresholdResult([object]$Tick) {
    if ($null -eq $Tick -or [string]$Tick.Kind -ne "pause-threshold") { return $null }
    $statusKey = if ([int]$Tick.ThresholdMinutes -ge 10) { "PomodoroPausedOverTen" } else { "PomodoroPausedOverFive" }
    return New-PomodoroOperationResult $true $statusKey "" $false $null (New-PomodoroPauseThresholdEvents $Tick)
}

function Stop-Pomodoro {
    $runtime = Get-PomodoroRuntimeEngineSnapshot
    if ([bool]$runtime.IsIdle) {
        Reset-PomodoroSession
        Set-PomodoroRuntimeIdleWorkState $true
        return New-PomodoroOperationResult $true "" "" $true $null (New-PomodoroIdleStoppedEvents)
    }

    if ([bool]$runtime.IsStarter) {
        return Stop-TaskStarter
    }

    $ended = Get-IsoNow
    $events = New-PomodoroInterruptedEvents $runtime $ended
    Reset-PomodoroSession
    Set-PomodoroRuntimeIdleWorkState $true
    return New-PomodoroOperationResult $true "PomodoroInterrupted" "" $true $null $events
}

function Complete-Pomodoro {
    $runtime = Get-PomodoroRuntimeEngineSnapshot
    if ([bool]$runtime.IsStarter) {
        return Complete-TaskStarter
    }
    if ([bool]$runtime.IsBreak) {
        return Complete-Break
    }

    $ended = Get-IsoNow
    $events = New-PomodoroWorkCompletedEvents $runtime $ended
    $breakResult = Start-BreakTimer
    return Add-PomodoroResultEvents $breakResult $events
}

function Start-BreakTimer {
    Start-PomodoroRuntimePhase "break" (Get-PomodoroBreakMinutes)
    return New-PomodoroOperationResult $true "BreakFocusing" "" $true $null (New-PomodoroBreakStartedEvents)
}

function Complete-Break {
    $runtime = Get-PomodoroRuntimeEngineSnapshot
    $ended = Get-IsoNow
    $events = New-PomodoroBreakCompletedEvents $runtime $ended

    $nextRound = Get-PomodoroNextRoundDecision ([string]$runtime.TaskId)
    Set-PomodoroRuntimeIdleWorkState $false
    if ([bool]$nextRound.HasNext -and (Get-PomodoroAutoStartNext)) {
        $startResult = Start-Pomodoro ([string]$nextRound.TaskId)
        return Add-PomodoroResultEvents $startResult $events
    }
    if ([bool]$nextRound.HasNext) {
        if (-not [string]::IsNullOrWhiteSpace([string]$nextRound.TaskId)) {
            Set-PomodoroRuntimeCurrentTask ([string]$nextRound.TaskId) ([string]$nextRound.TaskTitle)
        }
        return New-PomodoroOperationResult $true "ReadyNextPomodoro" "" $true $null $events
    }
    Reset-PomodoroSession
    Clear-PomodoroRuntimeCurrentTask
    return New-PomodoroOperationResult $true "BreakDone" "" $true $null $events
}