# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function New-TaskOperationResult(
    [bool]$Ok,
    [string]$StatusKey,
    [string]$MessageKey,
    [bool]$ShouldRender,
    [object]$Data
) {
    return [pscustomobject]@{
        Ok = $Ok
        StatusKey = $StatusKey
        MessageKey = $MessageKey
        ShouldRender = $ShouldRender
        Data = $Data
    }
}

function New-TaskId {
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $short = [guid]::NewGuid().ToString("N").Substring(0, 6)
    return "$stamp-$short"
}

function Ensure-TaskDefaults([object]$Task) {
    Ensure-Property $Task "id" (New-TaskId)
    Ensure-Property $Task "title" ""
    Ensure-Property $Task "source" "manual"
    Ensure-Property $Task "status" "todo"
    Ensure-Property $Task "createdAt" (Get-IsoNow)
    Ensure-Property $Task "scheduledFor" $null
    Ensure-Property $Task "scheduledAt" $null
    Ensure-Property $Task "sortOrder" (Get-TaskSortSeed $Task.createdAt)
    $todayOrder = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$Task.scheduledFor)) {
        $todayOrder = Get-TaskSortSeed $Task.scheduledAt
        if ($todayOrder -eq 0) {
            $todayOrder = Get-TaskSortSeed $Task.createdAt
        }
    }
    Ensure-Property $Task "todaySortOrder" $todayOrder
    Ensure-Property $Task "completedAt" $null
    Ensure-Property $Task "archivedAt" $null
    Ensure-Property $Task "reminderAt" $null
    Ensure-Property $Task "dueAt" $null
    Ensure-Property $Task "pomodoroCount" 0
    Ensure-Property $Task "estimatedPomodoroCount" 0
    Ensure-Property $Task "priority" 2
    Ensure-Property $Task "notes" ""
    Ensure-Property $Task "links" @()
    if ($null -eq $Task.links) {
        $Task.links = @()
    }
    elseif (-not ($Task.links -is [array])) {
        $Task.links = @([string]$Task.links)
    }
    Ensure-Property $Task "external" ([pscustomobject]@{ codexRunId = $null; fingerprint = $null })
}

function Test-TaskIsActive([object]$Task) {
    return ($null -ne $Task -and [string]$Task.status -in @("todo", "done"))
}

function Test-TaskIsCompleted([object]$Task) {
    return (
        $null -ne $Task -and
        [string]$Task.status -in @("done", "archived") -and
        -not [string]::IsNullOrWhiteSpace([string]$Task.completedAt)
    )
}

function New-TaskObject([string]$Title, [bool]$ScheduleToday) {
    $now = Get-IsoNow
    $today = Get-TodayString
    $scheduledFor = $null
    $scheduledAt = $null
    $sortOrder = Get-NextTaskSortOrder "tasks"
    $todaySortOrder = $null
    if ($ScheduleToday) {
        $scheduledFor = $today
        $scheduledAt = $now
        $todaySortOrder = Get-NextTaskSortOrder "today"
    }

    return [pscustomobject]@{
        id = New-TaskId
        title = $Title.Trim()
        source = "manual"
        status = "todo"
        createdAt = $now
        scheduledFor = $scheduledFor
        scheduledAt = $scheduledAt
        sortOrder = $sortOrder
        todaySortOrder = $todaySortOrder
        completedAt = $null
        archivedAt = $null
        reminderAt = $null
        dueAt = $null
        pomodoroCount = 0
        estimatedPomodoroCount = 0
        priority = 2
        notes = ""
        links = @()
        external = [pscustomobject]@{
            codexRunId = $null
            fingerprint = $null
        }
    }
}

function Parse-TaskInput([string]$Text) {
    $title = ""
    if ($null -ne $Text) {
        $title = $Text.Trim()
    }
    $position = $null
    $cnListDelimiter = [regex]::Escape([string][char]0x3001)
    $numberedPattern = '^\s*(\d+)(?:[.)]|' + $cnListDelimiter + '|\s+)\s*(.+?)\s*$'
    if ($title -match $numberedPattern) {
        $position = [int]$Matches[1]
        $title = [string]$Matches[2]
    }
    return [pscustomobject]@{
        Title = $title.Trim()
        Position = $position
    }
}
