# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Format-SingleLineTaskText([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    return (($Text -replace "\s*[\r\n]+\s*", " ").Trim())
}

function Format-TaskLine([object]$Task, [int]$Index) {
    $actual = 0
    if ($null -ne $Task.pomodoroCount) {
        $actual = [int]$Task.pomodoroCount
    }
    $estimated = 0
    if ($null -ne $Task.estimatedPomodoroCount) {
        $estimated = [int]$Task.estimatedPomodoroCount
    }
    $title = Format-SingleLineTaskText ([string]$Task.title)
    $prefix = ""
    if ($Index -gt 0) {
        $prefix = "$Index. "
    }
    if ($estimated -gt 0) {
        return "$prefix$title [$actual/$estimated]"
    }
    if ($actual -gt 0) {
        return "$prefix$title [$actual]"
    }
    return "$prefix$title"
}

function Get-TaskPomodoroProgressText([object]$Task) {
    if ($null -eq $Task) { return "" }
    $actual = 0
    if ($null -ne $Task.pomodoroCount) { $actual = [int]$Task.pomodoroCount }
    $estimated = 0
    if ($null -ne $Task.estimatedPomodoroCount) { $estimated = [int]$Task.estimatedPomodoroCount }
    if ($estimated -gt 0) { return "[$actual/$estimated]" }
    if ($actual -gt 0) { return "[$actual]" }
    return ""
}

function Format-DoneLine([object]$Task) {
    $count = 0
    if ($null -ne $Task.pomodoroCount) {
        $count = [int]$Task.pomodoroCount
    }
    $date = $Task.completedAt
    if ([string]::IsNullOrWhiteSpace([string]$date)) {
        $date = $Task.archivedAt
    }
    if (-not [string]::IsNullOrWhiteSpace($date) -and $date.Length -ge 10) {
        $date = $date.Substring(0, 10)
    }
    $title = Format-SingleLineTaskText ([string]$Task.title)
    return "$date  $title [$count]"
}



