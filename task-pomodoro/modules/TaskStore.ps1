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

function Get-TaskSortSeed([object]$DateValue) {
    if ($null -eq $DateValue -or [string]::IsNullOrWhiteSpace([string]$DateValue)) {
        return 0
    }
    try {
        return [double]([DateTimeOffset]::Parse([string]$DateValue).ToUnixTimeSeconds())
    }
    catch {
        return 0
    }
}

function Get-TaskOrderValue([object]$Task, [string]$PropertyName, [double]$Fallback) {
    if ($null -ne $Task -and ($Task.PSObject.Properties.Name -contains $PropertyName)) {
        $value = $Task.PSObject.Properties[$PropertyName].Value
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            try {
                return [double]$value
            }
            catch {
            }
        }
    }
    return $Fallback
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

function Get-NextTaskSortOrder([string]$Mode) {
    $max = 0
    $today = Get-TodayString
    foreach ($task in @($script:Tasks | Where-Object { Test-TaskIsActive $_ })) {
        if ($Mode -eq "today" -and $task.scheduledFor -ne $today) {
            continue
        }
        if ($Mode -eq "today") {
            $fallback = Get-TaskSortSeed $task.scheduledAt
            if ($fallback -eq 0) {
                $fallback = Get-TaskSortSeed $task.createdAt
            }
            $value = Get-TaskOrderValue $task "todaySortOrder" $fallback
        }
        else {
            $value = Get-TaskOrderValue $task "sortOrder" (Get-TaskSortSeed $task.createdAt)
        }
        if ($value -gt $max) {
            $max = $value
        }
    }
    return ($max + 1000)
}

function Load-Tasks {
    if (-not (Test-Path -LiteralPath $script:TasksFile)) {
        $script:Tasks = @()
        Save-Tasks
        return
    }

    try {
        $raw = Get-Content -LiteralPath $script:TasksFile -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $script:Tasks = @()
            return
        }
        $data = $raw | ConvertFrom-Json
        if ($null -eq $data) {
            $script:Tasks = @()
        }
        elseif ($data -is [array]) {
            $script:Tasks = @($data)
        }
        else {
            $script:Tasks = @($data)
        }

        $migrated = $false
        foreach ($task in $script:Tasks) {
            $beforeDefaults = $task | ConvertTo-Json -Depth 8 -Compress
            Ensure-TaskDefaults $task
            $afterDefaults = $task | ConvertTo-Json -Depth 8 -Compress
            if ($beforeDefaults -ne $afterDefaults) {
                $migrated = $true
            }
        }
        if ($migrated) {
            Save-Tasks
        }
    }
    catch {
        Backup-DataFile $script:TasksFile "invalid"
        $script:Tasks = @()
        Save-Tasks
    }
}

function Save-Tasks {
    Write-JsonAtomic $script:TasksFile @($script:Tasks)
}

function New-TaskId {
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $short = [guid]::NewGuid().ToString("N").Substring(0, 6)
    return "$stamp-$short"
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

function Get-TaskById([string]$Id) {
    foreach ($task in $script:Tasks) {
        if ($task.id -eq $Id) {
            return $task
        }
    }
    return $null
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

function Get-OpenTasks {
    return @($script:Tasks | Where-Object { Test-TaskIsActive $_ } | Sort-Object @{ Expression = { Get-TaskOrderValue $_ "sortOrder" (Get-TaskSortSeed $_.createdAt) } }, createdAt)
}

function Get-TodayTasks {
    $today = Get-TodayString
    return @($script:Tasks | Where-Object { (Test-TaskIsActive $_) -and $_.scheduledFor -eq $today } | Sort-Object @{ Expression = {
        $fallback = Get-TaskSortSeed $_.scheduledAt
        if ($fallback -eq 0) {
            $fallback = Get-TaskSortSeed $_.createdAt
        }
        Get-TaskOrderValue $_ "todaySortOrder" $fallback
    } }, scheduledAt, createdAt)
}

function Set-TaskOrderForView([string]$Mode, [object[]]$OrderedTasks) {
    for ($i = 0; $i -lt $OrderedTasks.Count; $i++) {
        if ($Mode -eq "today") {
            $OrderedTasks[$i].todaySortOrder = (($i + 1) * 1000)
        }
        else {
            $OrderedTasks[$i].sortOrder = (($i + 1) * 1000)
        }
    }
}

function Set-TaskPositionInView([string]$Mode, [string]$TaskId, [int]$Position) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        return
    }
    if ($Mode -eq "today") {
        $visibleTasks = @(Get-TodayTasks)
    }
    else {
        $visibleTasks = @(Get-OpenTasks)
    }

    $task = $null
    $ordered = New-Object System.Collections.ArrayList
    foreach ($visibleTask in $visibleTasks) {
        if ($visibleTask.id -eq $TaskId) {
            $task = $visibleTask
        }
        else {
            $ordered.Add($visibleTask) | Out-Null
        }
    }
    if ($null -eq $task) {
        return
    }

    $targetIndex = $Position - 1
    if ($targetIndex -lt 0) {
        $targetIndex = 0
    }
    if ($targetIndex -gt $ordered.Count) {
        $targetIndex = $ordered.Count
    }

    $ordered.Insert($targetIndex, $task)
    Set-TaskOrderForView $Mode ([object[]]$ordered.ToArray())
    Save-Tasks
}

function Pin-TaskToTop([string]$Mode, [string]$TaskId) {
    Set-TaskPositionInView $Mode $TaskId 1
    return New-TaskOperationResult $true "" "" $true $TaskId
}

function Move-TaskInView([string]$Mode, [string]$SourceId, [int]$TargetIndex) {
    if ([string]::IsNullOrWhiteSpace($SourceId)) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    if ($Mode -eq "today") {
        $visibleTasks = @(Get-TodayTasks)
    }
    else {
        $visibleTasks = @(Get-OpenTasks)
    }
    if ($visibleTasks.Count -le 1) {
        return New-TaskOperationResult $false "" "" $false $null
    }

    $sourceIndex = -1
    for ($i = 0; $i -lt $visibleTasks.Count; $i++) {
        if ($visibleTasks[$i].id -eq $SourceId) {
            $sourceIndex = $i
            break
        }
    }
    if ($sourceIndex -lt 0) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    if ($TargetIndex -lt 0) {
        $TargetIndex = $visibleTasks.Count
    }
    if ($TargetIndex -gt $visibleTasks.Count) {
        $TargetIndex = $visibleTasks.Count
    }
    if ($sourceIndex -eq $TargetIndex) {
        return New-TaskOperationResult $false "" "" $false $null
    }

    $ordered = New-Object System.Collections.ArrayList
    foreach ($task in $visibleTasks) {
        $ordered.Add($task) | Out-Null
    }
    $moving = $ordered[$sourceIndex]
    $ordered.RemoveAt($sourceIndex)
    if ($TargetIndex -gt $sourceIndex) {
        $TargetIndex--
    }
    if ($TargetIndex -gt $ordered.Count) {
        $TargetIndex = $ordered.Count
    }
    $ordered.Insert($TargetIndex, $moving)
    Set-TaskOrderForView $Mode ([object[]]$ordered.ToArray())
    Save-Tasks
    return New-TaskOperationResult $true "" "" $true $moving
}

function Get-DoneTasks {
    return @($script:Tasks | Where-Object { $_.status -eq "archived" } | Sort-Object @{ Expression = {
        if (-not [string]::IsNullOrWhiteSpace([string]$_.completedAt)) {
            [string]$_.completedAt
        }
        else {
            [string]$_.archivedAt
        }
    }; Descending = $true }, createdAt)
}

