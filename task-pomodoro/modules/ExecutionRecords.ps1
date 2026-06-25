# This file is dot-sourced by TaskPomodoro.ps1. It builds task-centered execution records from tasks, pomodoros, and behavior events.

function Format-ExecutionDate([object]$Value) {
    $dt = ConvertTo-LocalDateTimeOrNull $Value
    if ($null -eq $dt) { return "" }
    return $dt.ToString("MM-dd HH:mm")
}


function Get-ExecutionEventPoint([object]$Event) {
    if ($null -eq $Event) { return $null }
    $when = ConvertTo-LocalDateTimeOrNull ([string]$Event.at)
    if ($null -eq $when) { return $null }
    $pauseKey = ""
    try { $pauseKey = [string]$Event.payload.PausedAt } catch {}
    if ([string]::IsNullOrWhiteSpace($pauseKey) -and [string]$Event.type -eq "pomodoro_paused") { $pauseKey = [string]$Event.at }
    return [pscustomobject]@{ Type = [string]$Event.type; At = [string]$Event.at; When = $when; TaskId = [string]$Event.taskId; PauseKey = $pauseKey }
}

function Test-ExecutionDateMatch([datetime]$When, [string]$DateString) {
    if ([string]::IsNullOrWhiteSpace($DateString)) { return $true }
    return ($When.ToString("yyyy-MM-dd") -eq [string]$DateString)
}

function Get-ExecutionNextPoint([object[]]$Points, [datetime]$After, [string[]]$Types, [string]$DateString = "") {
    foreach ($candidate in @($Points | Where-Object { $_.When -gt $After -and [string]$_.Type -in $Types } | Sort-Object When)) {
        if (-not (Test-ExecutionDateMatch $candidate.When $DateString)) { continue }
        return $candidate
    }
    return $null
}

# Legacy logs can miss explicit resume events; a later different pause window proves the previous window ended.
function Get-ExecutionNextDifferentPauseWindow([object[]]$Points, [datetime]$After, [string]$PauseKey, [string]$DateString = "") {
    foreach ($candidate in @($Points | Where-Object { $_.When -gt $After -and [string]$_.Type -in @("pomodoro_paused", "pomodoro_pause_interrupted") } | Sort-Object When)) {
        if (-not (Test-ExecutionDateMatch $candidate.When $DateString)) { continue }
        $candidateKey = [string]$candidate.PauseKey
        if ([string]::IsNullOrWhiteSpace($candidateKey)) { continue }
        if ($candidateKey -ne [string]$PauseKey) { return $candidate }
    }
    return $null
}

function Get-ExecutionRecoveryStats([object[]]$TaskEvents, [string]$DateString = "") {
    $points = @()
    foreach ($event in @($TaskEvents)) {
        $point = Get-ExecutionEventPoint $event
        if ($null -eq $point) { continue }
        if ([string]$event.type -notin @("pomodoro_interrupted", "pomodoro_started", "pomodoro_paused", "pomodoro_resumed", "pomodoro_pause_interrupted")) { continue }
        $points += $point
    }
    $points = @($points | Sort-Object When)
    $recovered = 0
    $pausePoints = @($points | Where-Object { [string]$_.Type -eq "pomodoro_paused" -and (Test-ExecutionDateMatch $_.When $DateString) })
    $pauseThresholds = @($points | Where-Object { [string]$_.Type -eq "pomodoro_pause_interrupted" -and (Test-ExecutionDateMatch $_.When $DateString) })
    $weightedInterruptions = $pauseThresholds.Count
    $pauseKeys = @{}

    foreach ($pause in $pausePoints) {
        $weightedInterruptions += 1
        if (-not [string]::IsNullOrWhiteSpace([string]$pause.PauseKey)) { $pauseKeys[[string]$pause.PauseKey] = $true }
        $nextRecovery = Get-ExecutionNextPoint $points $pause.When @("pomodoro_resumed", "pomodoro_started") $DateString
        if ($null -ne $nextRecovery) { $recovered++ }
    }

    $legacyThresholdWindows = @{}
    foreach ($threshold in $pauseThresholds) {
        $key = [string]$threshold.PauseKey
        if ([string]::IsNullOrWhiteSpace($key)) { $key = "legacy-threshold-$($threshold.At)" }
        if ($pauseKeys.ContainsKey($key) -or $legacyThresholdWindows.ContainsKey($key)) { continue }
        $legacyThresholdWindows[$key] = $threshold
    }
    foreach ($window in $legacyThresholdWindows.Values) {
        $weightedInterruptions += 1
        $nextRecovery = Get-ExecutionNextPoint $points $window.When @("pomodoro_resumed", "pomodoro_started") $DateString
        if ($null -ne $nextRecovery) { $recovered++ }
        elseif ($null -ne (Get-ExecutionNextDifferentPauseWindow $points $window.When ([string]$window.PauseKey) $DateString)) { $recovered++ }
    }

    foreach ($interrupt in @($points | Where-Object { [string]$_.Type -eq "pomodoro_interrupted" -and (Test-ExecutionDateMatch $_.When $DateString) })) {
        $nextStart = Get-ExecutionNextPoint $points $interrupt.When @("pomodoro_started") $DateString
        if ($null -eq $nextStart) {
            $weightedInterruptions += 3
            continue
        }
        $recovered++
        $minutes = ($nextStart.When - $interrupt.When).TotalMinutes
        if ($minutes -le 5) { $weightedInterruptions += 1 }
        elseif ($minutes -le 10) { $weightedInterruptions += 2 }
        else { $weightedInterruptions += 3 }
    }
    return [pscustomobject]@{ Recovered = $recovered; WeightedInterruptions = $weightedInterruptions }
}
function Format-ExecutionDuration([int]$Seconds) {
    if ($Seconds -le 0) { return "0$(T "ExecutionStatsMinuteUnit")" }
    $totalMinutes = [int][Math]::Round($Seconds / 60.0)
    if ($totalMinutes -lt 1) { $totalMinutes = 1 }
    $hours = [int][Math]::Floor($totalMinutes / 60)
    $minutes = [int]($totalMinutes % 60)
    if ($hours -gt 0) { return "$hours$(T "ExecutionStatsHourUnit")$($minutes.ToString("00"))$(T "ExecutionStatsMinuteUnit")" }
    return "$minutes$(T "ExecutionStatsMinuteUnit")"
}

function Get-ExecutionTaskStats([string]$TaskId) {
    $task = Get-TaskById $TaskId
    if ($null -eq $task) { return $null }
    $taskEvents = @(Get-BehaviorEventsForTask $TaskId)
    $taskPomodoros = @(Get-PomodoroRecords | Where-Object { [string]$_.taskId -eq [string]$TaskId })
    $recovery = Get-ExecutionRecoveryStats $taskEvents

    $completedRecords = @($taskPomodoros | Where-Object { [string]$_.result -eq "completed" })
    $actualPomodoros = [Math]::Max([int]$task.pomodoroCount, [int]$completedRecords.Count)
    $plannedText = "-"
    try {
        if ([int]$task.estimatedPomodoroCount -gt 0) { $plannedText = [string][int]$task.estimatedPomodoroCount }
    } catch {}

    $startPoints = @()
    foreach ($event in @($taskEvents | Where-Object { [string]$_.type -eq "pomodoro_started" })) {
        $point = Get-ExecutionEventPoint $event
        if ($null -ne $point) { $startPoints += $point }
    }
    $firstStarted = ""
    if ($startPoints.Count -gt 0) { $firstStarted = [string](@($startPoints | Sort-Object When)[0].At) }
    elseif ($taskPomodoros.Count -gt 0) { $firstStarted = [string](@($taskPomodoros | Sort-Object startedAt)[0].startedAt) }

    $activityDates = @()
    foreach ($event in @($taskEvents | Where-Object { [string]$_.type -in @("pomodoro_started", "pomodoro_completed", "pomodoro_interrupted", "pomodoro_paused", "pomodoro_resumed", "pomodoro_pause_interrupted", "task_completed", "task_cancelled") })) {
        if (-not [string]::IsNullOrWhiteSpace([string]$event.at)) { $activityDates += [string]$event.at }
    }
    foreach ($record in $taskPomodoros) { if (-not [string]::IsNullOrWhiteSpace([string]$record.endedAt)) { $activityDates += [string]$record.endedAt } }
    $recent = if ($activityDates.Count -gt 0) { [string](@($activityDates | Sort-Object)[-1]) } else { "" }

    $focusMinutes = 0.0
    foreach ($record in $taskPomodoros) {
        try { $focusMinutes += [double]$record.actualMinutes } catch {}
    }
    $focusSeconds = [int][Math]::Round($focusMinutes * 60.0)

    return [pscustomobject]@{
        TaskId = [string]$TaskId
        RecoverySuccessCount = [int]$recovery.Recovered
        WeightedInterruptionCount = [int]$recovery.WeightedInterruptions
        ActualPomodoros = [int]$actualPomodoros
        PlannedPomodorosText = [string]$plannedText
        FirstStartedAt = [string]$firstStarted
        RecentAt = [string]$recent
        FocusSeconds = [int]$focusSeconds
    }
}

function Get-ExecutionTaskStatsText([string]$TaskId) {
    $stats = Get-ExecutionTaskStats $TaskId
    if ($null -eq $stats) { return "" }
    $startText = Format-ExecutionDate $stats.FirstStartedAt
    if ([string]::IsNullOrWhiteSpace($startText)) { $startText = "-" }
    $recentText = Format-ExecutionDate $stats.RecentAt
    if ([string]::IsNullOrWhiteSpace($recentText)) { $recentText = "-" }
    $lines = @(
        "$(T "ExecutionStatsRecovery"): $($stats.RecoverySuccessCount) / $($stats.WeightedInterruptionCount)",
        "$(T "ExecutionStatsPomodoro"): $($stats.ActualPomodoros) / $($stats.PlannedPomodorosText)",
        "$(T "ExecutionStatsTime"): $(T "ExecutionStatsStart") $startText | $(T "ExecutionStatsRecent") $recentText",
        "$(T "ExecutionStatsFocusDuration"): $(Format-ExecutionDuration ([int]$stats.FocusSeconds))"
    )
    return ($lines -join "`r`n")
}
function Get-ExecutionEventLabel([string]$Type) {
    switch ($Type) {
        "task_created" { return T "ExecutionEventTaskCreated" }
        "task_scheduled_today" { return T "ExecutionEventScheduled" }
        "task_unscheduled_today" { return T "ExecutionEventUnscheduled" }
        "task_started" { return T "ExecutionEventTaskStarted" }
        "pomodoro_started" { return T "ExecutionEventPomodoroStarted" }
        "pomodoro_completed" { return T "ExecutionEventPomodoroCompleted" }
        "pomodoro_interrupted" { return T "ExecutionEventPomodoroInterrupted" }
        "pomodoro_paused" { return T "ExecutionEventPomodoroPaused" }
        "pomodoro_resumed" { return T "ExecutionEventPomodoroResumed" }
        "pomodoro_pause_interrupted" { return T "ExecutionEventPomodoroPauseInterrupted" }
        "task_completed" { return T "ExecutionEventTaskCompleted" }
        "task_cancelled" { return T "ExecutionEventTaskCancelled" }
        "inbox_item_promoted" { return T "ExecutionEventInboxPromoted" }
        default { return $Type }
    }
}

function Get-ExecutionTaskAggregate([object]$Task, [object[]]$Events, [object[]]$Pomodoros) {
    $taskId = [string]$Task.id
    $taskEvents = @($Events | Where-Object { [string]$_.taskId -eq $taskId } | Sort-Object at)
    $taskPomodoros = @($Pomodoros | Where-Object { [string]$_.taskId -eq $taskId })
    $startEvents = @($taskEvents | Where-Object { [string]$_.type -in @("task_started", "pomodoro_started") })
    $firstStarted = ""
    if ($startEvents.Count -gt 0) { $firstStarted = [string]$startEvents[0].at }
    elseif ($taskPomodoros.Count -gt 0) { $firstStarted = [string](@($taskPomodoros | Sort-Object startedAt)[0].startedAt) }

    $activityDates = @()
    foreach ($event in $taskEvents) { if (-not [string]::IsNullOrWhiteSpace([string]$event.at)) { $activityDates += [string]$event.at } }
    foreach ($record in $taskPomodoros) { if (-not [string]::IsNullOrWhiteSpace([string]$record.endedAt)) { $activityDates += [string]$record.endedAt } }
    foreach ($value in @($Task.completedAt, $Task.archivedAt, $Task.scheduledAt, $Task.createdAt)) { if (-not [string]::IsNullOrWhiteSpace([string]$value)) { $activityDates += [string]$value } }
    $lastActive = if ($activityDates.Count -gt 0) { [string](@($activityDates | Sort-Object)[-1]) } else { "" }

    $isCompleted = Test-TaskIsCompleted $Task
    $isCancelled = ([string]$Task.status -eq "archived" -and [string]::IsNullOrWhiteSpace([string]$Task.completedAt))
    $hasStarted = (-not [string]::IsNullOrWhiteSpace($firstStarted) -or [int]$Task.pomodoroCount -gt 0)
    if (-not $hasStarted -and -not $isCompleted -and -not $isCancelled) { return $null }

    $statusKey = "ExecutionStatusActive"
    $endAt = ""
    $isHistory = $false
    if ($isCompleted) { $statusKey = "ExecutionStatusCompleted"; $endAt = [string]$Task.completedAt; $isHistory = $true }
    elseif ($isCancelled) { $statusKey = "ExecutionStatusCancelled"; $endAt = [string]$Task.archivedAt; $isHistory = $true }

    $timeText = if ($isHistory) { Format-ExecutionDate $endAt } else { Format-ExecutionDate $lastActive }
    $startedText = Format-ExecutionDate $firstStarted
    $pomodoroText = "$(T "PomodoroCount") $([int]$Task.pomodoroCount)"
    $display = "[$(T $statusKey)] $([string]$Task.title) - $pomodoroText"
    if (-not [string]::IsNullOrWhiteSpace($startedText)) { $display += " - $(T "ExecutionFirstStarted") $startedText" }
    if (-not [string]::IsNullOrWhiteSpace($timeText)) { $display += " - $(T "ExecutionLastActive") $timeText" }

    return [pscustomobject]@{ Id = $taskId; Task = $Task; Display = $display; IsHistory = $isHistory; SortAt = if ($isHistory) { $endAt } else { $lastActive }; FirstStartedAt = $firstStarted; LastActiveAt = $lastActive; EndedAt = $endAt }
}

function Get-ExecutionRecords {
    $events = @(Get-BehaviorEvents)
    $pomodoros = @(Get-PomodoroRecords)
    $records = @()
    foreach ($task in @($script:Tasks)) {
        $record = Get-ExecutionTaskAggregate $task $events $pomodoros
        if ($null -ne $record) { $records += $record }
    }
    $active = @($records | Where-Object { -not [bool]$_.IsHistory } | Sort-Object @{ Expression = { [string]$_.SortAt }; Descending = $true }, Display)
    $history = @($records | Where-Object { [bool]$_.IsHistory } | Sort-Object @{ Expression = { [string]$_.SortAt }; Descending = $true }, Display)
    return [pscustomobject]@{ Active = $active; History = $history }
}

function Get-ExecutionDetailText([string]$TaskId) {
    $task = Get-TaskById $TaskId
    if ($null -eq $task) { return "" }
    $lines = New-Object System.Collections.ArrayList
    $lines.Add([string]$task.title) | Out-Null
    $lines.Add("") | Out-Null
    foreach ($event in @(Get-BehaviorEventsForTask $TaskId)) {
        $time = Format-ExecutionDate ([string]$event.at)
        $label = Get-ExecutionEventLabel ([string]$event.type)
        $line = if ([string]::IsNullOrWhiteSpace($time)) { $label } else { "$time  $label" }
        $lines.Add($line) | Out-Null
    }
    foreach ($record in @(Get-PomodoroRecords | Where-Object { [string]$_.taskId -eq [string]$TaskId } | Sort-Object endedAt)) {
        $time = Format-ExecutionDate ([string]$record.endedAt)
        $label = if ([string]$record.result -eq "completed") { T "ExecutionEventPomodoroCompleted" } else { T "ExecutionEventPomodoroInterrupted" }
        $lines.Add("$time  $label") | Out-Null
    }
    if ($lines.Count -le 2) { $lines.Add((T "ExecutionNoDetail")) | Out-Null }
    return ($lines -join "`r`n")
}