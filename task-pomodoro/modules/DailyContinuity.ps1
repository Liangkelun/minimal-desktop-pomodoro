# This file is dot-sourced by TaskPomodoro.ps1. It owns the daily continuation prompt workflow.

function Get-YesterdayString { return (Get-Date).AddDays(-1).ToString("yyyy-MM-dd") }

function Get-DailyContinuationTasks {
    $yesterday = Get-YesterdayString
    return @($script:Tasks | Where-Object { (Test-TaskIsActive $_) -and [string]$_.scheduledFor -eq $yesterday })
}

function Get-YesterdayCompletedPomodoroCount {
    $yesterday = Get-YesterdayString
    $count = 0
    foreach ($record in @(Get-PomodoroRecords)) {
        if ([string]$record.result -ne "completed") { continue }
        $ended = ConvertTo-LocalDateTimeOrNull $record.endedAt
        if ($null -ne $ended -and $ended.ToString("yyyy-MM-dd") -eq $yesterday) { $count++ }
    }
    return $count
}


function Get-YesterdayRecoverySuccessCount {
    $yesterday = Get-YesterdayString
    $events = @(Get-BehaviorEvents)
    $taskIds = @($events | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.taskId) } | ForEach-Object { [string]$_.taskId } | Sort-Object -Unique)
    $count = 0
    foreach ($taskId in $taskIds) {
        $stats = Get-ExecutionRecoveryStats @($events | Where-Object { [string]$_.taskId -eq $taskId }) $yesterday
        $count += [int]$stats.Recovered
    }
    return $count
}
function Test-DailyContinuationPromptDue {
    $today = Get-TodayString
    if ([string]$script:Settings.LastDailyContinuationPromptDate -eq $today) { return $false }
    return (@(Get-DailyContinuationTasks).Count -gt 0)
}

function Complete-DailyContinuationPrompt([bool]$ContinueYesterday) {
    $today = Get-TodayString
    $tasks = @(Get-DailyContinuationTasks)
    $count = $tasks.Count
    if ($count -gt 0) {
        foreach ($task in $tasks) {
            if ($ContinueYesterday) {
                $task.scheduledFor = $today
                if ([string]::IsNullOrWhiteSpace([string]$task.scheduledAt)) { $task.scheduledAt = Get-IsoNow }
                if ($null -eq $task.todaySortOrder) { $task.todaySortOrder = Get-NextTaskSortOrder "today" }
            }
            else {
                $task.scheduledFor = $null
                $task.scheduledAt = $null
                $task.todaySortOrder = $null
            }
        }
        Save-Tasks
    }
    $script:Settings.LastDailyContinuationPromptDate = $today
    Save-AppRuntimeSettings
    $eventType = if ($ContinueYesterday) { "daily_continuation_yes" } else { "daily_continuation_no" }
    Append-BehaviorEvent $eventType "" "" "user" ([pscustomobject]@{ Count = $count })
    return New-TaskOperationResult $true "SelectTodayTaskPrompt" "" $true $null
}

function Show-DailyContinuationPromptIfDue {
    if (-not (Test-DailyContinuationPromptDue)) { return }
    $completed = Get-YesterdayCompletedPomodoroCount
    $recovered = Get-YesterdayRecoverySuccessCount
    $unfinished = @(Get-DailyContinuationTasks).Count
    $message = (T "DailyContinuationSummary") -f $completed, $recovered, $unfinished
    $choice = [System.Windows.Forms.MessageBox]::Show($message, (T "DailyContinuationTitle"), [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    $continue = ($choice -eq [System.Windows.Forms.DialogResult]::Yes)
    Invoke-AppActionResult (Complete-DailyContinuationPrompt $continue)
    Set-ActiveView "tasks"
    Set-Status (T "SelectTodayTaskPrompt")
}