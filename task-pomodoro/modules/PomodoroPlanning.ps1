# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

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

function Test-PomodoroStartNeedsPlan([string]$TaskId) {
    $task = Get-TaskById $TaskId
    return ($null -ne $task -and [int]$task.estimatedPomodoroCount -le 0)
}

function Apply-PomodoroStartPlanIfNeeded([string]$TaskId, [int]$PlannedPomodoros) {
    if ($PlannedPomodoros -le 0) { return $false }
    $task = Get-TaskById $TaskId
    if ($null -eq $task -or [int]$task.estimatedPomodoroCount -gt 0) { return $false }
    Add-TaskEstimatedPomodoros $task $PlannedPomodoros | Out-Null
    return $true
}

function Test-PomodoroTaskNeedsAdditionalPlan([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) { return $false }
    $task = Get-TaskById $TaskId
    return ($null -ne $task -and -not (Test-TaskIsCompleted $task) -and [int]$task.estimatedPomodoroCount -gt 0 -and (Get-TaskRemainingPomodoros $task) -le 0)
}

function Add-PomodoroEstimateForTask([string]$TaskId, [int]$Count) {
    if ($Count -le 0 -or [string]::IsNullOrWhiteSpace($TaskId)) { return $false }
    $task = Get-TaskById $TaskId
    if ($null -eq $task) { return $false }
    Add-TaskEstimatedPomodoros $task $Count | Out-Null
    return $true
}
function Get-PomodoroTaskBinding([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        return [pscustomobject]@{ HasTask = $false; TaskId = $null; TaskTitle = "" }
    }
    $task = Get-TaskById $TaskId
    if ($null -eq $task) {
        return [pscustomobject]@{ HasTask = $false; TaskId = $null; TaskTitle = "" }
    }
    return [pscustomobject]@{ HasTask = $true; TaskId = [string]$task.id; TaskTitle = [string]$task.title }
}

function Get-PomodoroStartTaskBinding([string]$TaskId) {
    return Get-PomodoroTaskBinding $TaskId
}

function Get-PomodoroStarterTaskBinding([string]$TaskId) {
    return Get-PomodoroTaskBinding $TaskId
}
function Get-PomodoroNextRoundDecision([string]$CurrentTaskId) {
    $hasNextPomodoro = Test-PomodoroSessionHasNextRound
    $nextTaskId = $null
    $nextTaskTitle = ""
    if (-not [string]::IsNullOrWhiteSpace($CurrentTaskId)) {
        $task = Get-TaskById $CurrentTaskId
        if ((Get-TaskRemainingPomodoros $task) -gt 0) {
            $nextTaskId = [string]$task.id
            $nextTaskTitle = [string]$task.title
        }
        else {
            $hasNextPomodoro = $false
        }
    }
    return [pscustomobject]@{
        HasNext = [bool]$hasNextPomodoro
        TaskId = $nextTaskId
        TaskTitle = $nextTaskTitle
    }
}