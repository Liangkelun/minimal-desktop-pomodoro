# This file is dot-sourced before task list views. Keep task list item projection separate from view assembly.

function New-TaskListViewItem([string]$Id, [string]$Display) {
    return [pscustomobject]@{
        Id = $Id
        Display = $Display
    }
}

function Get-TaskListItemsForView([string]$Mode) {
    $scheduleToday = ($Mode -eq "today")
    if ($scheduleToday) {
        $tasks = @(Get-TodayTasks)
    }
    else {
        $tasks = @(Get-OpenTasks)
    }

    $items = New-Object System.Collections.ArrayList
    if ($tasks.Count -eq 0) {
        $emptyText = T ($(if ($scheduleToday) { "NoTodayTasks" } else { "NoOpenTasks" }))
        $items.Add((New-TaskListViewItem "" $emptyText)) | Out-Null
        return $items.ToArray()
    }

    $displayIndex = 1
    foreach ($task in $tasks) {
        $items.Add((New-TaskListViewItem $task.id (Format-TaskLine $task $displayIndex))) | Out-Null
        $displayIndex++
    }
    $items.Add((New-TaskListViewItem "" "")) | Out-Null
    return $items.ToArray()
}