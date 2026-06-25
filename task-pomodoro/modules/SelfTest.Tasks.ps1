# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Invoke-SelfTestTaskScenarios([scriptblock]$AfterEditScenarios) {
        $testTask = New-TaskObject "__selftest__" $true
        $script:Tasks = @($testTask)
        if (@(Get-OpenTasks).Count -ne 1) {
            throw "selftest failed: open task filter"
        }
        if (@(Get-TodayTasks).Count -ne 1) {
            throw "selftest failed: today task filter"
        }
        $testTask.status = "done"
        $testTask.completedAt = Get-IsoNow
        if (@(Get-OpenTasks).Count -ne 1) {
            throw "selftest failed: completed task stays active"
        }
        if (@(Get-DoneTasks).Count -ne 0) {
            throw "selftest failed: completed task is not archived"
        }
        End-Task $testTask.id
        if (@(Get-DoneTasks).Count -ne 1) {
            throw "selftest failed: archived done task filter"
        }

        $first = New-TaskObject "__selftest_order_1__" $true
        $second = New-TaskObject "__selftest_order_2__" $true
        $third = New-TaskObject "__selftest_order_3__" $true
        $script:Tasks = @($first, $second, $third)
        Move-TaskInView "today" $third.id 0
        if ((@(Get-TodayTasks))[0].id -ne $third.id) {
            throw "selftest failed: today reorder"
        }
        Move-TaskInView "tasks" $second.id 0
        if ((@(Get-OpenTasks))[0].id -ne $second.id) {
            throw "selftest failed: task reorder"
        }
        Move-TaskInView "tasks" $second.id -1
        $openAfterMoveToEnd = @(Get-OpenTasks)
        if ($openAfterMoveToEnd[$openAfterMoveToEnd.Count - 1].id -ne $second.id) {
            throw "selftest failed: task reorder to end"
        }
        Move-TaskInView "today" $third.id -1
        $todayAfterMoveToEnd = @(Get-TodayTasks)
        if ($todayAfterMoveToEnd[$todayAfterMoveToEnd.Count - 1].id -ne $third.id) {
            throw "selftest failed: today reorder to end"
        }

        $script:Tasks = @()
        $emptyAdd = Add-Task " " $false
        if ($emptyAdd.Ok -or $emptyAdd.MessageKey -ne "EnterTaskFirst") {
            throw "selftest failed: empty add result"
        }
        $addResult = Add-Task "__selftest_add_1__" $false
        if (-not $addResult.Ok -or $addResult.StatusKey -ne "TaskAdded" -or -not $addResult.ShouldRender) {
            throw "selftest failed: add task result"
        }
        Add-Task "__selftest_add_2__" $false
        Add-Task "2 __selftest_add_insert__" $false
        $openAfterInsert = @(Get-OpenTasks)
        if ($openAfterInsert.Count -ne 3 -or $openAfterInsert[1].title -ne "__selftest_add_insert__") {
            throw "selftest failed: numbered task insert"
        }

        Add-Task "__selftest_today_1__" $true
        Add-Task "__selftest_today_2__" $true
        Add-Task ("1" + [string][char]0x3001 + "__selftest_today_insert__") $true
        $todayAfterInsert = @(Get-TodayTasks)
        if ($todayAfterInsert[0].title -ne "__selftest_today_insert__") {
            throw "selftest failed: numbered today insert"
        }

        Pin-TaskToTop "tasks" $openAfterInsert[2].id
        if ((@(Get-OpenTasks))[0].id -ne $openAfterInsert[2].id) {
            throw "selftest failed: pin to top"
        }

        $defaultActionTask = New-TaskObject "__selftest_default_action__" $false
        $script:Tasks = @($defaultActionTask)
        $defaultActionResult = Invoke-TaskDefaultWorkflow "tasks" $defaultActionTask.id
        if (-not $defaultActionResult.Ok -or $defaultActionResult.StatusKey -ne "ScheduledToday") {
            throw "selftest failed: task default action result"
        }
        if ((Get-TaskById $defaultActionTask.id).scheduledFor -ne (Get-TodayString)) {
            throw "selftest failed: task default action schedule"
        }
        if (-not (Test-PomodoroRuntimeIdle)) {
            throw "selftest failed: task default action started timer"
        }
        if (-not (Set-TaskTitle $defaultActionTask.id "__selftest_edited__")) {
            throw "selftest failed: edit task title"
        }
        if ((Get-TaskById $defaultActionTask.id).title -ne "__selftest_edited__") {
            throw "selftest failed: edited task title persisted"
        }
        if ($null -ne $AfterEditScenarios) { & $AfterEditScenarios $defaultActionTask.id }
        $completeResult = Complete-Task $defaultActionTask.id
        if (-not $completeResult.Ok -or (Get-TaskById $defaultActionTask.id).status -ne "done" -or @(Get-OpenTasks).Count -ne 1 -or @(Get-DoneTasks).Count -ne 0) {
            throw "selftest failed: complete task stays active"
        }
        $uncompleteResult = Uncomplete-Task $defaultActionTask.id
        if (-not $uncompleteResult.Ok -or (Get-TaskById $defaultActionTask.id).status -ne "todo" -or $null -ne (Get-TaskById $defaultActionTask.id).completedAt) {
            throw "selftest failed: uncomplete task"
        }
        $deleteResult = Delete-Task $defaultActionTask.id
        if (-not $deleteResult.Ok -or $deleteResult.StatusKey -ne "TaskDeleted" -or $null -ne (Get-TaskById $defaultActionTask.id)) {
            throw "selftest failed: delete task"
        }
        $oldDone = New-TaskObject "__selftest_daily_archive_old__" $false
        $newDone = New-TaskObject "__selftest_daily_archive_new__" $false
        $script:Tasks = @($oldDone, $newDone)
        $oldDone.status = "done"
        $oldDone.completedAt = "2000-01-01T00:00:00+08:00"
        $newDone.status = "done"
        $newDone.completedAt = "2000-01-03T00:00:00+08:00"
        $archiveCount = Archive-CompletedTasksBefore ([datetime]"2000-01-02T00:00:00")
        if ($archiveCount -ne 1 -or $oldDone.status -ne "archived" -or $newDone.status -ne "done") {
            throw "selftest failed: daily archive cutoff"
        }
}

function Invoke-SelfTestEndTaskScenario {
        $endTask = New-TaskObject "__selftest_end__" $false
        $script:Tasks = @($endTask)
        End-Task $endTask.id
        if ((Get-TaskById $endTask.id).status -ne "archived") {
            throw "selftest failed: end task"
        }
}