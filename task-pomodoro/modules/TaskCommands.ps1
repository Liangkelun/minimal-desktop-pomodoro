# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Add-TaskTimerInvalidationEvent([object]$Result, [string]$Id, [string]$Reason) {
    if ($null -eq $Result -or -not [bool]$Result.Ok) {
        return $Result
    }
    Add-AppResultEvents $Result (New-AppEvent "TaskTimerInvalidated" @{ TaskId = $Id; Reason = $Reason; TimerPolicy = "stop-if-current" }) | Out-Null
    Add-Member -InputObject $Result -MemberType NoteProperty -Name ShouldUpdateTimer -Value $true -Force
    return $Result
}
function Add-Task([string]$Title, [bool]$ScheduleToday) {
    $parsed = Parse-TaskInput $Title
    if ([string]::IsNullOrWhiteSpace($parsed.Title)) {
        return New-TaskOperationResult $false "" "EnterTaskFirst" $false $null
    }

    $task = New-TaskObject $parsed.Title $ScheduleToday
    $script:Tasks = @($script:Tasks) + $task
    if ($null -ne $parsed.Position) {
        $mode = "tasks"
        if ($ScheduleToday) {
            $mode = "today"
        }
        Set-TaskPositionInView $mode $task.id ([int]$parsed.Position)
    }
    else {
        Save-Tasks
    }
    $result = New-TaskOperationResult $true "TaskAdded" "" $true $task
    Add-BehaviorResultEvent $result "task_created" ([string]$task.id) "" "user" @{ Title = [string]$task.title } | Out-Null
    if ($ScheduleToday) { Add-BehaviorResultEvent $result "task_scheduled_today" ([string]$task.id) "" "user" @{ FromCreate = $true } | Out-Null }
    return $result
}

function Complete-Task([string]$Id) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    $task.status = "done"
    if ([string]::IsNullOrWhiteSpace([string]$task.completedAt)) {
        $task.completedAt = Get-IsoNow
    }
    Save-Tasks
    $sessionId = Get-BehaviorSessionForTask $Id
    $result = Add-TaskTimerInvalidationEvent (New-TaskOperationResult $true "TaskCompleted" "" $true $task) $Id "completed"
    Add-BehaviorResultEvent $result "task_completed" $Id $sessionId "user" @{ Title = [string]$task.title } | Out-Null
    Stop-BehaviorSessionForTask $Id
    return $result
}
function Uncomplete-Task([string]$Id) {
    $task = Get-TaskById $Id
    if ($null -eq $task -or [string]$task.status -ne "done") {
        return New-TaskOperationResult $false "" "" $false $null
    }
    $task.status = "todo"
    $task.completedAt = $null
    Save-Tasks
    return New-TaskOperationResult $true "TaskUncompleted" "" $true $task
}

function Toggle-TaskCompletion([string]$Id) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    if (Test-TaskIsCompleted $task) {
        return Uncomplete-Task $Id
    }
    return Complete-Task $Id
}

function End-Task([string]$Id) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    $task.status = "archived"
    $task.archivedAt = Get-IsoNow
    Save-Tasks
    $sessionId = Get-BehaviorSessionForTask $Id
    $result = Add-TaskTimerInvalidationEvent (New-TaskOperationResult $true "" "" $true $task) $Id "archived"
    Add-BehaviorResultEvent $result "task_cancelled" $Id $sessionId "user" @{ Title = [string]$task.title } | Out-Null
    Stop-BehaviorSessionForTask $Id
    return $result
}
function Delete-Task([string]$Id) {
    if ([string]::IsNullOrWhiteSpace($Id)) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    $beforeCount = @($script:Tasks).Count
    $script:Tasks = @($script:Tasks | Where-Object { [string]$_.id -ne $Id })
    if (@($script:Tasks).Count -eq $beforeCount) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    Save-Tasks
    return Add-TaskTimerInvalidationEvent (New-TaskOperationResult $true "TaskDeleted" "" $true $null) $Id "deleted"
}

function Set-TaskTitle([string]$Id, [string]$Title) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($Title)) {
        return $false
    }
    $newTitle = $Title.Trim()
    if ($newTitle -eq [string]$task.title) {
        return $false
    }
    $task.title = $newTitle
    Save-Tasks
    return $true
}

function Schedule-TaskToday([string]$Id) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    $task.scheduledFor = Get-TodayString
    $task.scheduledAt = Get-IsoNow
    $task.todaySortOrder = Get-NextTaskSortOrder "today"
    Save-Tasks
    $result = New-TaskOperationResult $true "ScheduledToday" "" $true $task
    Add-BehaviorResultEvent $result "task_scheduled_today" $Id "" "user" @{ FromCreate = $false } | Out-Null
    return $result
}
function Unschedule-TaskToday([string]$Id) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    $task.scheduledFor = $null
    $task.scheduledAt = $null
    $task.todaySortOrder = $null
    Save-Tasks
    $result = Add-TaskTimerInvalidationEvent (New-TaskOperationResult $true "" "" $true $task) $Id "unscheduled"
    Add-BehaviorResultEvent $result "task_unscheduled_today" $Id (Get-BehaviorSessionForTask $Id) "user" @{} | Out-Null
    return $result
}