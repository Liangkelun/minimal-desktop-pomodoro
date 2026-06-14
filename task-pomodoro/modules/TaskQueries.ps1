# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-TaskById([string]$Id) {
    foreach ($task in $script:Tasks) {
        if ($task.id -eq $Id) {
            return $task
        }
    }
    return $null
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
