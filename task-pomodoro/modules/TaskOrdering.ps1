# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

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
