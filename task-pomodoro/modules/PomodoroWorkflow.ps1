# This file is dot-sourced by TaskPomodoro.ps1. Keep Pomodoro workflows UI-free and side-effect-light at load time.


function Invoke-PomodoroStartWorkflow([string]$TaskId, [int]$PlannedPomodoros = 0, [bool]$KeepCurrentView = $false) {
    Apply-PomodoroStartPlanIfNeeded $TaskId $PlannedPomodoros | Out-Null
    $result = Start-Pomodoro $TaskId
    if ($result.Ok -and $KeepCurrentView -and -not [string]::IsNullOrWhiteSpace($TaskId)) {
        $result.View = ""
        $result.ShouldRender = $true
    }
    return $result
}

function Test-PomodoroCompletionNeedsAdditionalPlan {
    if (-not (Test-PomodoroRuntimeBreakPhase)) { return $false }
    return Test-PomodoroTaskNeedsAdditionalPlan (Get-PomodoroRuntimeCurrentTaskId)
}

function Invoke-PomodoroAddEstimateWorkflow([int]$Count) {
    return Add-PomodoroEstimateForTask (Get-PomodoroRuntimeCurrentTaskId) $Count
}

function Invoke-PomodoroTaskInvalidationWorkflow([string]$TaskId) {
    $currentTaskId = Get-PomodoroRuntimeCurrentTaskId
    if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]$TaskId -ne [string]$currentTaskId) {
        return @()
    }
    $stopResult = Stop-Pomodoro
    if ($null -ne $stopResult -and ($stopResult.PSObject.Properties.Name -contains "Events")) {
        return @($stopResult.Events)
    }
    return @()
}
function Invoke-PomodoroPauseOrContinueWorkflow {
    if (Test-PomodoroRuntimePaused) { return Continue-Pomodoro }
    if (Test-PomodoroRuntimeRunning) { return Pause-Pomodoro }
    return New-PomodoroOperationResult $false "" "" $false $null
}

function Invoke-PomodoroStopWorkflow { return Stop-Pomodoro }

function Invoke-PomodoroCompleteWorkflow {
    $snapshot = Get-PomodoroRuntimeCompletionNotificationSnapshot
    $phase = [string]$snapshot.Phase
    $plannedMinutes = 0
    if ($phase -eq "work") { $plannedMinutes = Get-PomodoroWorkMinutes }
    $endedAt = Get-IsoNow
    $result = Complete-Pomodoro
    if ($phase -eq "work" -and $null -ne $result -and [bool]$result.Ok) {
        Publish-AppNotification "PomodoroFinished" @{ TaskId = [string]$snapshot.TaskId; TaskTitle = [string]$snapshot.TaskTitle; StartedAt = [string]$snapshot.StartedAt; EndedAt = $endedAt; PlannedMinutes = $plannedMinutes; Result = $result } | Out-Null
    }
    return $result
}
function Invoke-TaskStarterStartWorkflow([string]$TaskId) { return Start-TaskStarter $TaskId }

function Get-TaskStarterCompletionDefaultAction {
    $action = [string]$script:Settings.StarterDefaultAction
    if ($action -in @("pomodoro", "again", "complete", "stop")) { return $action }
    return "pomodoro"
}

function Invoke-TaskStarterCompleteWorkflow { return Complete-TaskStarter }

function Invoke-TaskStarterAgainWorkflow([string]$TaskId, [object[]]$StopEvents) {
    $next = Start-TaskStarter $TaskId
    if ($next.Ok) { return Add-PomodoroResultEvents $next $StopEvents }
    return $next
}

function Invoke-TaskStarterCompleteTaskWorkflow([string]$TaskId, [object[]]$StopEvents) {
    $next = Invoke-TaskCompleteWorkflow $TaskId
    if ($next.Ok) { return Add-PomodoroResultEvents $next $StopEvents }
    return $next
}