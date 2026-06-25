# This file is dot-sourced by TaskPomodoro.ps1. It covers inbox, behavior events, execution records, and daily continuation workflows.

function Reset-SelfTestBehaviorEvents {
    $path = Get-AppPath "BehaviorEventsFile"
    Initialize-BehaviorEvents
    Set-Content -LiteralPath $path -Value "" -Encoding UTF8 -NoNewline
    $script:BehaviorCurrentSessionId = ""
    $script:BehaviorCurrentSessionTaskId = ""
}


function Add-SelfTestBehaviorEvent([string]$Type, [string]$TaskId, [string]$At, [object]$Payload = $null) {
    $record = [pscustomobject][ordered]@{
        id = New-BehaviorEventId
        at = $At
        type = $Type
        taskId = $TaskId
        sessionId = "selftest-session"
        source = "selftest"
        payload = if ($null -eq $Payload) { [pscustomobject]@{} } else { $Payload }
    }
    $line = ConvertTo-Json -InputObject $record -Depth 6 -Compress
    $line | Add-Content -LiteralPath (Get-AppPath "BehaviorEventsFile") -Encoding UTF8
}
function Invoke-SelfTestInboxExecutionScenarios {
    $script:InboxItems = @()
    Save-Inbox
    Reset-SelfTestBehaviorEvents

    $createInbox = Invoke-InboxCreateWorkflow "__selftest_inbox__"
    Invoke-AppResultEvents $createInbox
    if (-not $createInbox.Ok -or @(Get-InboxItems).Count -ne 1) {
        throw "selftest failed: inbox create"
    }
    $inboxId = [string](@(Get-InboxItems)[0].id)
    if (@(Get-BehaviorEvents | Where-Object { [string]$_.type -eq "inbox_item_added" }).Count -ne 1) {
        throw "selftest failed: inbox add event"
    }

    $editInbox = Invoke-InboxEditWorkflow $inboxId "__selftest_inbox_edited__"
    Invoke-AppResultEvents $editInbox
    if (-not $editInbox.Ok -or [string](Get-InboxItemById $inboxId).title -ne "__selftest_inbox_edited__" -or @(Get-BehaviorEvents | Where-Object { [string]$_.type -eq "inbox_item_edited" }).Count -ne 1) {
        throw "selftest failed: inbox edit"
    }

    $promote = Invoke-InboxPromoteWorkflow $inboxId $false
    Invoke-AppResultEvents $promote
    if (-not $promote.Ok -or $promote.StatusKey -ne "InboxItemPromoted" -or @(Get-InboxItems).Count -ne 0) {
        throw "selftest failed: inbox promote"
    }
    $taskId = [string]$promote.Data.id
    if ([string]::IsNullOrWhiteSpace($taskId) -or $null -eq (Get-TaskById $taskId)) {
        throw "selftest failed: promoted task exists"
    }
    foreach ($type in @("task_created", "inbox_item_promoted")) {
        if (@(Get-BehaviorEvents | Where-Object { [string]$_.type -eq $type -and [string]$_.taskId -eq $taskId }).Count -lt 1) {
            throw "selftest failed: missing behavior event $type"
        }
    }

    $sessionId = Start-BehaviorSessionForTask $taskId
    Append-BehaviorEvent "task_started" $taskId $sessionId "selftest" ([pscustomobject]@{})
    $records = Get-ExecutionRecords
    if (@($records.Active | Where-Object { [string]$_.Id -eq $taskId }).Count -ne 1) {
        throw "selftest failed: active execution record"
    }
    $complete = Complete-Task $taskId
    Invoke-AppResultEvents $complete
    $records = Get-ExecutionRecords
    if (@($records.History | Where-Object { [string]$_.Id -eq $taskId }).Count -ne 1) {
        throw "selftest failed: history execution record"
    }


    Reset-SelfTestBehaviorEvents
    Set-Content -LiteralPath (Get-AppPath "PomodorosFile") -Value "" -Encoding UTF8 -NoNewline
    $statsTask = New-TaskObject "__selftest_stats__" $false
    $statsTask.estimatedPomodoroCount = 4
    $statsTask.pomodoroCount = 1
    $otherTask = New-TaskObject "__selftest_stats_other__" $false
    $script:Tasks = @($statsTask, $otherTask)
    $base = (Get-Date).AddDays(-1).Date
    Add-SelfTestBehaviorEvent "pomodoro_started" $statsTask.id ($base.AddHours(9).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Add-SelfTestBehaviorEvent "pomodoro_interrupted" $statsTask.id ($base.AddHours(9).AddMinutes(10).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Add-SelfTestBehaviorEvent "pomodoro_started" $statsTask.id ($base.AddHours(9).AddMinutes(14).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Add-SelfTestBehaviorEvent "pomodoro_interrupted" $statsTask.id ($base.AddHours(10).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Add-SelfTestBehaviorEvent "pomodoro_started" $otherTask.id ($base.AddHours(10).AddMinutes(2).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Add-SelfTestBehaviorEvent "pomodoro_started" $statsTask.id ($base.AddHours(10).AddMinutes(8).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Add-SelfTestBehaviorEvent "pomodoro_paused" $statsTask.id ($base.AddHours(10).AddMinutes(20).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Add-SelfTestBehaviorEvent "pomodoro_resumed" $statsTask.id ($base.AddHours(10).AddMinutes(22).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    $longPauseAt = $base.AddHours(10).AddMinutes(30).ToString("yyyy-MM-ddTHH:mm:sszzz")
    Add-SelfTestBehaviorEvent "pomodoro_paused" $statsTask.id $longPauseAt ([pscustomobject]@{ PausedAt = $longPauseAt })
    Add-SelfTestBehaviorEvent "pomodoro_pause_interrupted" $statsTask.id ($base.AddHours(10).AddMinutes(35).ToString("yyyy-MM-ddTHH:mm:sszzz")) ([pscustomobject]@{ PausedAt = $longPauseAt })
    Add-SelfTestBehaviorEvent "pomodoro_pause_interrupted" $statsTask.id ($base.AddHours(10).AddMinutes(40).ToString("yyyy-MM-ddTHH:mm:sszzz")) ([pscustomobject]@{ PausedAt = $longPauseAt })
    Add-SelfTestBehaviorEvent "pomodoro_resumed" $statsTask.id ($base.AddHours(10).AddMinutes(42).ToString("yyyy-MM-ddTHH:mm:sszzz")) ([pscustomobject]@{ PausedAt = $longPauseAt })
    Add-SelfTestBehaviorEvent "pomodoro_interrupted" $statsTask.id ($base.AddHours(11).ToString("yyyy-MM-ddTHH:mm:sszzz"))
    Append-PomodoroRecord $statsTask.id ($base.AddHours(9).ToString("yyyy-MM-ddTHH:mm:sszzz")) ($base.AddHours(9).AddMinutes(25).ToString("yyyy-MM-ddTHH:mm:sszzz")) 25 1500 "completed"
    Append-PomodoroRecord $statsTask.id ($base.AddHours(10).ToString("yyyy-MM-ddTHH:mm:sszzz")) ($base.AddHours(10).AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:sszzz")) 25 300 "interrupted"
    $stats = Get-ExecutionTaskStats $statsTask.id
    if ($stats.RecoverySuccessCount -ne 4 -or $stats.WeightedInterruptionCount -ne 10) {
        throw "selftest failed: execution stats recovery"
    }
    if ($stats.ActualPomodoros -ne 1 -or $stats.PlannedPomodorosText -ne "4" -or $stats.FocusSeconds -ne 1800) {
        throw "selftest failed: execution stats pomodoro and focus"
    }
    $statsText = Get-ExecutionTaskStatsText $statsTask.id
    if ($statsText -notlike "*4 / 10*" -or $statsText -notlike "*1 / 4*") {
        throw "selftest failed: execution stats text"
    }
    if ((Get-YesterdayRecoverySuccessCount) -ne 4) {
        throw "selftest failed: yesterday recovery success count"
    }
    Reset-SelfTestBehaviorEvents
    $legacyStatsTask = New-TaskObject "__selftest_legacy_pause_windows__" $false
    $script:Tasks = @($legacyStatsTask)
    $legacyPauseOne = $base.AddHours(12).ToString("yyyy-MM-ddTHH:mm:sszzz")
    $legacyPauseTwo = $base.AddHours(13).ToString("yyyy-MM-ddTHH:mm:sszzz")
    Add-SelfTestBehaviorEvent "pomodoro_pause_interrupted" $legacyStatsTask.id ($base.AddHours(12).AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:sszzz")) ([pscustomobject]@{ PausedAt = $legacyPauseOne })
    Add-SelfTestBehaviorEvent "pomodoro_pause_interrupted" $legacyStatsTask.id ($base.AddHours(12).AddMinutes(10).ToString("yyyy-MM-ddTHH:mm:sszzz")) ([pscustomobject]@{ PausedAt = $legacyPauseOne })
    Add-SelfTestBehaviorEvent "pomodoro_pause_interrupted" $legacyStatsTask.id ($base.AddHours(13).AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:sszzz")) ([pscustomobject]@{ PausedAt = $legacyPauseTwo })
    $legacyStats = Get-ExecutionTaskStats $legacyStatsTask.id
    if ($legacyStats.RecoverySuccessCount -ne 1 -or $legacyStats.WeightedInterruptionCount -ne 5) {
        throw "selftest failed: legacy pause window recovery inference"
    }

    Reset-SelfTestBehaviorEvents
    $yesterdayTask = New-TaskObject "__selftest_yesterday_yes__" $false
    $yesterdayTask.scheduledFor = Get-YesterdayString
    $yesterdayTask.scheduledAt = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:sszzz")
    $script:Tasks = @($yesterdayTask)
    $script:Settings.LastDailyContinuationPromptDate = ""
    $yes = Complete-DailyContinuationPrompt $true
    if (-not $yes.Ok -or [string](Get-TaskById $yesterdayTask.id).scheduledFor -ne (Get-TodayString)) {
        throw "selftest failed: daily continuation yes"
    }
    if ([string]$script:Settings.LastDailyContinuationPromptDate -ne (Get-TodayString)) {
        throw "selftest failed: daily continuation prompt date"
    }
    if (@(Get-BehaviorEvents | Where-Object { [string]$_.type -eq "daily_continuation_yes" }).Count -ne 1) {
        throw "selftest failed: daily continuation yes event"
    }

    Reset-SelfTestBehaviorEvents
    $dropTask = New-TaskObject "__selftest_yesterday_no__" $false
    $dropTask.scheduledFor = Get-YesterdayString
    $dropTask.scheduledAt = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:sszzz")
    $script:Tasks = @($dropTask)
    $script:Settings.LastDailyContinuationPromptDate = ""
    $no = Complete-DailyContinuationPrompt $false
    if (-not $no.Ok -or $null -ne (Get-TaskById $dropTask.id).scheduledFor) {
        throw "selftest failed: daily continuation no"
    }
    if (@(Get-BehaviorEvents | Where-Object { [string]$_.type -eq "daily_continuation_no" }).Count -ne 1) {
        throw "selftest failed: daily continuation no event"
    }
}
