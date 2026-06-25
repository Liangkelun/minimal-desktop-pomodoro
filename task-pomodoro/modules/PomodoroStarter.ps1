# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.


function Test-TaskStarterRunningForTask([string]$TaskId) {
    return (Test-PomodoroRuntimeStarterForTask $TaskId)
}

function Get-TaskStarterInlineText([string]$TaskId) {
    $state = Get-TaskInlineCountdownState $TaskId
    if ($null -eq $state -or [string]$state.Kind -ne "starter") { return "" }
    return [string]$state.Text
}

function New-TaskStarterRefreshResult([object]$Result) {
    if ($null -ne $Result) { $Result.ShouldRender = $true }
    return $Result
}

function Start-TaskStarter([string]$TaskId) {
    if (-not (Test-PomodoroRuntimeIdle)) {
        $result = New-PomodoroOperationResult $false "" "" $false $null
        $result.MessageKey = "TimerAlreadyRunning"
        return $result
    }

    $taskBinding = Get-PomodoroStarterTaskBinding $TaskId
    if (-not [bool]$taskBinding.HasTask) {
        return New-PomodoroOperationResult $false "" "" $false $null
    }

    Reset-PomodoroSession
    Set-PomodoroRuntimeCurrentTask ([string]$taskBinding.TaskId) ([string]$taskBinding.TaskTitle)
    Start-PomodoroRuntimePhase "starter" (Get-TaskStarterMinutes)

    return New-TaskStarterRefreshResult (New-PomodoroOperationResult $true "StarterFocusing" "" $true ([string]$taskBinding.TaskId) (New-PomodoroStarterStartedEvents))

}


function Stop-TaskStarter {
    Reset-PomodoroSession
    Set-PomodoroRuntimeIdleWorkState $true
    return New-TaskStarterRefreshResult (New-PomodoroOperationResult $true "StarterStopped" "" $true $null (New-PomodoroStarterStoppedEvents))
}


function Complete-TaskStarter {
    if (-not (Test-PomodoroRuntimeStarterPhase)) {
        return New-PomodoroOperationResult $false "" "" $false $null
    }
    $taskId = Get-PomodoroRuntimeCurrentTaskId
    Reset-PomodoroSession
    Set-PomodoroRuntimeIdleWorkState $true
    return New-TaskStarterRefreshResult (New-PomodoroOperationResult $true "StarterDone" "" $true $taskId (New-PomodoroStarterCompletedEvents))
}
