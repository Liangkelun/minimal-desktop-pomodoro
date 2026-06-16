# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

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
    return New-TaskOperationResult $true "TaskAdded" "" $true $task
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
    return New-TaskOperationResult $true "TaskCompleted" "" $true $task
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
    return New-TaskOperationResult $true "" "" $true $task
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
    return New-TaskOperationResult $true "TaskDeleted" "" $true $null
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
    return New-TaskOperationResult $true "ScheduledToday" "" $true $task
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
    return New-TaskOperationResult $true "" "" $true $task
}

function Invoke-TaskDefaultAction([string]$Mode, [string]$Id) {
    if ([string]::IsNullOrWhiteSpace($Id)) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    if ($Mode -eq "today") {
        return Start-Pomodoro $Id
    }
    else {
        return Schedule-TaskToday $Id
    }
}
