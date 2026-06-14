# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function ConvertTo-LocalDateTimeOrNull([object]$Value) {
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    try {
        return ([DateTimeOffset]::Parse([string]$Value)).LocalDateTime
    }
    catch {
        return $null
    }
}

function Format-IsoLocalDateTime([datetime]$Value) {
    return ([DateTimeOffset]$Value).ToString("yyyy-MM-ddTHH:mm:sszzz")
}

function Archive-CompletedTasksBefore([datetime]$Cutoff) {
    $count = 0
    $archiveStamp = Format-IsoLocalDateTime $Cutoff
    foreach ($task in @($script:Tasks | Where-Object { $_.status -eq "done" })) {
        $completedAt = ConvertTo-LocalDateTimeOrNull $task.completedAt
        if ($null -eq $completedAt -or $completedAt -gt $Cutoff) {
            continue
        }
        $task.status = "archived"
        $task.archivedAt = $archiveStamp
        $count++
    }
    if ($count -gt 0) {
        Save-Tasks
    }
    return $count
}

function Get-LatestDailyArchiveBoundary([datetime]$Now) {
    $hour = 0
    $minute = 0
    if ($null -ne $script:Settings) {
        try { $hour = [int]$script:Settings.DailyArchiveHour } catch { $hour = 0 }
        try { $minute = [int]$script:Settings.DailyArchiveMinute } catch { $minute = 0 }
    }
    if ($hour -lt 0 -or $hour -gt 23) { $hour = 0 }
    if ($minute -lt 0 -or $minute -gt 59) { $minute = 0 }

    $boundary = $Now.Date.AddHours($hour).AddMinutes($minute)
    if ($Now -lt $boundary) {
        $boundary = $boundary.AddDays(-1)
    }
    return $boundary
}

function Invoke-DailyArchiveIfDue {
    if ($null -eq $script:Settings) {
        return 0
    }

    $boundary = Get-LatestDailyArchiveBoundary (Get-Date)
    $lastBoundary = ConvertTo-LocalDateTimeOrNull $script:Settings.LastDailyArchiveAt
    if ($null -ne $lastBoundary -and $lastBoundary -ge $boundary) {
        return 0
    }

    $count = Archive-CompletedTasksBefore $boundary
    $script:Settings.LastDailyArchiveAt = Format-IsoLocalDateTime $boundary
    Save-Settings
    return $count
}

