# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Restore-SelfTestFileContent([string]$Path, [string]$Content) {
    Invoke-WithNamedMutex (Get-AppScopedMutexName "data") {
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8 -NoNewline
    }
}

function Invoke-SelfTest {
    $originalTasks = @($script:Tasks)
    $originalTasksRaw = $null
    $originalSettingsRaw = $null
    $originalPomodorosRaw = $null
    if (Test-Path -LiteralPath $script:TasksFile) {
        $originalTasksRaw = Get-Content -LiteralPath $script:TasksFile -Encoding UTF8 -Raw
    }
    if (Test-Path -LiteralPath $script:SettingsFile) {
        $originalSettingsRaw = Get-Content -LiteralPath $script:SettingsFile -Encoding UTF8 -Raw
    }
    if (Test-Path -LiteralPath $script:PomodorosFile) {
        $originalPomodorosRaw = Get-Content -LiteralPath $script:PomodorosFile -Encoding UTF8 -Raw
    }
    try {
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
        $defaultActionResult = Invoke-TaskDefaultAction "tasks" $defaultActionTask.id
        if (-not $defaultActionResult.Ok -or $defaultActionResult.StatusKey -ne "ScheduledToday") {
            throw "selftest failed: task default action result"
        }
        if ((Get-TaskById $defaultActionTask.id).scheduledFor -ne (Get-TodayString)) {
            throw "selftest failed: task default action schedule"
        }
        if ($script:TimerState -ne "idle") {
            throw "selftest failed: task default action started timer"
        }
        if (-not (Set-TaskTitle $defaultActionTask.id "__selftest_edited__")) {
            throw "selftest failed: edit task title"
        }
        if ((Get-TaskById $defaultActionTask.id).title -ne "__selftest_edited__") {
            throw "selftest failed: edited task title persisted"
        }
        if (-not (Set-TaskDetails $defaultActionTask.id "__selftest_details__" "__selftest_notes__" 3 5 @("https://example.com", "C:\temp\example.txt"))) {
            throw "selftest failed: set task details"
        }
        $convertedSingleLink = ConvertTo-TaskLinks "D:\single.docx"
        $convertedManyLinks = ConvertTo-TaskLinks "D:\one.docx`r`nD:\two.docx"
        if (-not ($convertedSingleLink -is [string[]]) -or $convertedSingleLink.Count -ne 1 -or $convertedSingleLink[0] -ne "D:\single.docx") {
            throw "selftest failed: single link conversion returns stable array"
        }
        if (-not ($convertedManyLinks -is [string[]]) -or $convertedManyLinks.Count -ne 2 -or $convertedManyLinks[1] -ne "D:\two.docx") {
            throw "selftest failed: multiline link conversion returns stable array"
        }
        $detailsTask = Get-TaskById $defaultActionTask.id
        if (
            $detailsTask.title -ne "__selftest_details__" -or
            $detailsTask.notes -ne "__selftest_notes__" -or
            [int]$detailsTask.estimatedPomodoroCount -ne 3 -or
            [int]$detailsTask.pomodoroCount -ne 5 -or
            (Get-FirstTaskLink $detailsTask) -ne "https://example.com"
        ) {
            throw "selftest failed: task details persisted"
        }
        $linksText = Get-TaskLinksText $detailsTask
        if ($linksText -ne "https://example.com`r`nC:\temp\example.txt") {
            throw "selftest failed: task links multiline text"
        }
        if (-not (Set-TaskDetails $defaultActionTask.id "__selftest_details__" "__selftest_notes__" 3 5 "D:\example.docx")) {
            throw "selftest failed: set single task link"
        }
        $singleLinkTask = Get-TaskById $defaultActionTask.id
        if (@($singleLinkTask.links).Count -ne 1 -or (Get-FirstTaskLink $singleLinkTask) -ne "D:\example.docx" -or (Get-TaskLinksText $singleLinkTask) -ne "D:\example.docx") {
            throw "selftest failed: single task link stays whole"
        }
        $legacyLinkTask = [pscustomobject]@{ links = "D:\legacy.docx" }
        Ensure-TaskDefaults $legacyLinkTask
        if (-not ($legacyLinkTask.links -is [array]) -or @($legacyLinkTask.links).Count -ne 1 -or (Get-FirstTaskLink $legacyLinkTask) -ne "D:\legacy.docx") {
            throw "selftest failed: legacy string task link normalized"
        }
        $quotedArg = ConvertTo-ProcessQuotedArgument "D:\has space\文档.vbs"
        if ($quotedArg -ne '"D:\has space\文档.vbs"') {
            throw "selftest failed: process argument quoting"
        }
        $encodedCommand = ConvertTo-EncodedPowerShellCommand "Write-Output 'ok'"
        $decodedCommand = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encodedCommand))
        if ($decodedCommand -ne "Write-Output 'ok'") {
            throw "selftest failed: encoded powershell command"
        }
        $relaunchScript = New-AppRelaunchScript 12345 (Join-Path $script:DataDir "restart-selftest.log")
        if (
            -not $relaunchScript.Contains('$parentProcessId = 12345') -or
            -not $relaunchScript.Contains((Get-AppScopedMutexName "instance")) -or
            -not $relaunchScript.Contains("WaitOne(30000)") -or
            -not $relaunchScript.Contains("StartTaskPomodoro.vbs")
        ) {
            throw "selftest failed: relaunch helper script"
        }
        $mutexName = Get-AppScopedMutexName "selftest"
        if ($mutexName -notlike "Local\MinimalDesktopPomodoro-selftest-*") {
            throw "selftest failed: scoped mutex name"
        }
        foreach ($requiredTextKey in @("NoOpenTasks", "NoTodayTasks", "HelpShortcutsText", "Close")) {
            if ([string]::IsNullOrWhiteSpace((T $requiredTextKey))) {
                throw "selftest failed: required ui text"
            }
        }
        $linkTestFile = Join-Path $script:DataDir "selftest link file.txt"
        "selftest" | Set-Content -LiteralPath $linkTestFile -Encoding UTF8
        try {
            $resolvedPath = Resolve-TaskLinkTarget $linkTestFile
            $resolvedFileUri = Resolve-TaskLinkTarget ([System.Uri]::new($linkTestFile).AbsoluteUri)
            $resolvedMarkdown = Resolve-TaskLinkTarget ("[local](" + $linkTestFile + ")")
            if (-not $resolvedPath.Exists -or -not $resolvedFileUri.Exists -or -not $resolvedMarkdown.Exists) {
                throw "selftest failed: resolve local task link"
            }
        }
        finally {
            Remove-Item -LiteralPath $linkTestFile -Force -ErrorAction SilentlyContinue
        }
        $longLinkRoot = Join-Path $script:DataDir "__selftest__\含 空格\现代文明长期存续面临的系统性风险与复杂性挑战\01_当前主线"
        Ensure-Directory $longLinkRoot
        $longLinkFile = Join-Path $longLinkRoot "Foresight_Main_Manuscript_Chinese_Review_20260604.docx"
        "selftest" | Set-Content -LiteralPath $longLinkFile -Encoding UTF8
        try {
            $mixedLinks = ConvertTo-TaskLinks ("`"$longLinkFile`"`r`n`r`n<https://example.com/work>`r`n[local]($longLinkFile)")
            if ($mixedLinks.Count -ne 3 -or $mixedLinks[0] -ne $longLinkFile -or $mixedLinks[1] -ne "https://example.com/work" -or $mixedLinks[2] -ne $longLinkFile) {
                throw "selftest failed: mixed long task links"
            }
            foreach ($candidate in @($longLinkFile, ('"' + $longLinkFile + '"'), ('<' + $longLinkFile + '>'), ("[local](" + $longLinkFile + ")"), ([System.Uri]::new($longLinkFile).AbsoluteUri))) {
                $resolvedLongPath = Resolve-TaskLinkTarget $candidate
                if (-not $resolvedLongPath.Exists -or [string]$resolvedLongPath.OpenTarget -ne $longLinkFile) {
                    throw "selftest failed: resolve long local task link"
                }
            }
            $resolvedObject = Resolve-TaskLinkTarget ([pscustomobject]@{ OpenTarget = $longLinkFile; Exists = $true; IsPath = $true })
            $resolvedObjectText = Resolve-TaskLinkTarget ("@{OpenTarget=$longLinkFile; Exists=True; IsPath=True}")
            if ([string]$resolvedObject.OpenTarget -ne $longLinkFile -or [string]$resolvedObjectText.OpenTarget -ne $longLinkFile) {
                throw "selftest failed: resolve parsed task link target"
            }
        }
        finally {
            Remove-Item -LiteralPath (Join-Path $script:DataDir "__selftest__") -Recurse -Force -ErrorAction SilentlyContinue
        }
        $originalOpenTaskLink = (Get-Command Open-TaskLink).ScriptBlock
        $script:SelfTestOpenTaskLinkId = ""
        $menu = New-Object System.Windows.Forms.ContextMenuStrip
        try {
            Set-Item -Path Function:\Open-TaskLink -Value { param([string]$Id) $script:SelfTestOpenTaskLinkId = $Id }
            Add-OpenTaskLinkMenuItem $menu "menu-task-id"
            $menu.Items[0].PerformClick()
            if ($script:SelfTestOpenTaskLinkId -ne "menu-task-id") {
                throw "selftest failed: open task link menu click"
            }
        }
        finally {
            Set-Item -Path Function:\Open-TaskLink -Value $originalOpenTaskLink
            $menu.Dispose()
            Remove-Variable -Name SelfTestOpenTaskLinkId -Scope Script -ErrorAction SilentlyContinue
        }
        $completeResult = Complete-Task $defaultActionTask.id
        if (-not $completeResult.Ok -or (Get-TaskById $defaultActionTask.id).status -ne "done" -or @(Get-OpenTasks).Count -ne 1 -or @(Get-DoneTasks).Count -ne 0) {
            throw "selftest failed: complete task stays active"
        }
        $uncompleteResult = Uncomplete-Task $defaultActionTask.id
        if (-not $uncompleteResult.Ok -or (Get-TaskById $defaultActionTask.id).status -ne "todo" -or $null -ne (Get-TaskById $defaultActionTask.id).completedAt) {
            throw "selftest failed: uncomplete task"
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

        $script:Settings.StartSoundReminder = $false
        $script:Settings.EndSoundReminder = $false
        $script:Settings.WorkMusic = $false
        $script:Settings.BreakMusic = $false
        $timerTask = New-TaskObject "__selftest_timer__" $true
        $script:Tasks = @($timerTask)
        $startResult = Start-Pomodoro $timerTask.id
        if (-not $startResult.Ok -or $startResult.StatusKey -ne "Focusing" -or $startResult.View -ne "timer" -or $script:TimerState -ne "running") {
            throw "selftest failed: start pomodoro result"
        }
        $pauseResult = Pause-Pomodoro
        if (-not $pauseResult.Ok -or $script:TimerState -ne "paused") {
            throw "selftest failed: pause pomodoro result"
        }
        $continueResult = Continue-Pomodoro
        if (-not $continueResult.Ok -or $script:TimerState -ne "running") {
            throw "selftest failed: continue pomodoro result"
        }
        $stopResult = Stop-Pomodoro
        if (-not $stopResult.Ok -or $stopResult.StatusKey -ne "PomodoroInterrupted" -or $script:TimerState -ne "idle") {
            throw "selftest failed: stop pomodoro result"
        }

        $script:TaskRowHeight = 24
        if (-not (Test-TaskTopDragBand 7) -or (Test-TaskTopDragBand 12)) {
            throw "selftest failed: top drag band"
        }

        $testList = New-Object System.Windows.Forms.ListBox
        $testList.Width = 220
        $testList.Height = 72
        $testList.Items.Add([pscustomobject]@{ Id = "task-1"; Display = "1. task" }) | Out-Null
        $testList.Items.Add([pscustomobject]@{ Id = ""; Display = "empty" }) | Out-Null
        $selectedItem = Select-ListItemAtPoint $testList 4 4
        if ($null -eq $selectedItem -or $testList.SelectedIndex -ne 0) {
            throw "selftest failed: select real list item"
        }
        $nullItem = Select-ListItemAtPoint $testList 4 ($testList.ItemHeight + 4)
        if ($null -ne $nullItem -or $testList.SelectedIndex -ne -1) {
            throw "selftest failed: clear placeholder list item"
        }
        $testList.SelectedIndex = 0
        $blankItem = Select-ListItemAtPoint $testList 4 200
        if ($null -ne $blankItem -or $testList.SelectedIndex -ne -1) {
            throw "selftest failed: clear blank list area"
        }
        $testList.Dispose()

        $script:Form = New-Object TaskPomodoroResizableForm
        $script:Form.Height = 100
        $script:Form.Location = New-Object System.Drawing.Point -ArgumentList @(-5000, -5000)
        $script:Form.Opacity = 0.88
        $script:Form.TopMost = $false
        $script:Form.Padding = New-Object System.Windows.Forms.Padding(4)
        $script:Form.MinimumSize = New-Object System.Drawing.Size(240, 34)
        $script:ContentPanel = New-Object System.Windows.Forms.Panel
        $script:ContentPanel.Padding = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
        $script:MainPanel = New-Object System.Windows.Forms.Panel
        $script:NavRowStyle = New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)
        $script:TaskInputRowStyle = $null
        $script:TaskRowHeight = 24
        $script:BottomChromeVisible = $true
        $script:SizeToggleButton = New-Object System.Windows.Forms.Button
        Resize-WindowForTaskRows 1
        $oneRowHeight = [int]$script:Form.Height
        if ($oneRowHeight -lt 38 -or $oneRowHeight -gt 48) {
            throw "selftest failed: resize one row"
        }
        $oneRowUsableHeight = $oneRowHeight - [int]$script:Form.Padding.Vertical - [int]$script:ContentPanel.Padding.Vertical - (Get-TaskRowsWindowSlack)
        if ($oneRowUsableHeight -lt [int]$script:TaskRowHeight) {
            throw "selftest failed: one-row view clips task row"
        }
        if ($script:SizeToggleButton.Text -ne [string][char]0x25A1) {
            throw "selftest failed: size toggle collapsed icon"
        }
        Resize-WindowForTaskRows 10
        if ([int]$script:Form.Height -lt 240 -or [int]$script:Form.Height -le $oneRowHeight) {
            throw "selftest failed: resize ten rows"
        }
        if ($script:SizeToggleButton.Text -ne "-") {
            throw "selftest failed: size toggle expanded icon"
        }
        $script:WatermarkToggleButton = $null
        $script:Settings.Opacity = 0.92
        $heightBeforeWatermark = [int]$script:Form.Height
        Enter-WatermarkMode
        if (-not $script:WatermarkMode -or -not $script:Form.WatermarkMode -or [Math]::Abs([double]$script:Form.Opacity - 0.50) -gt 0.01) {
            throw "selftest failed: enter watermark"
        }
        if ([int]$script:Form.Height -ne $heightBeforeWatermark) {
            throw "selftest failed: watermark preserved window height"
        }
        if ($script:WatermarkToggleButton.Text -ne [string][char]0x25B3 -or $script:WatermarkToggleButton.Parent -ne $script:Form) {
            throw "selftest failed: watermark toggle icon"
        }
        if (-not $script:Form.ClickThroughEnabled) {
            throw "selftest failed: watermark click through"
        }
        Exit-WatermarkMode
        if ($script:WatermarkMode -or $script:Form.WatermarkMode -or [Math]::Abs([double]$script:Form.Opacity - 0.88) -gt 0.01) {
            throw "selftest failed: exit watermark"
        }
        if ($script:Form.ClickThroughEnabled) {
            throw "selftest failed: watermark click through reset"
        }
        $script:SizeToggleButton.Dispose()
        $script:Form.Dispose()
        $script:ContentPanel.Dispose()
        $script:MainPanel.Dispose()
        $script:Form = $null
        $script:ContentPanel = $null
        $script:MainPanel = $null
        $script:WatermarkToggleButton = $null

        $endTask = New-TaskObject "__selftest_end__" $false
        $script:Tasks = @($endTask)
        End-Task $endTask.id
        if ((Get-TaskById $endTask.id).status -ne "archived") {
            throw "selftest failed: end task"
        }
    }
    finally {
        if ($null -ne $originalTasksRaw) {
            Restore-SelfTestFileContent $script:TasksFile $originalTasksRaw
            Load-Tasks
        }
        else {
            $script:Tasks = $originalTasks
            Save-Tasks
        }
        if ($null -ne $originalSettingsRaw) {
            Restore-SelfTestFileContent $script:SettingsFile $originalSettingsRaw
            Load-Settings
        }
        else {
            Save-Settings
        }
        if ($null -ne $originalPomodorosRaw) {
            Restore-SelfTestFileContent $script:PomodorosFile $originalPomodorosRaw
        }
    }
    $openCount = @(Get-OpenTasks).Count
    $todayCount = @(Get-TodayTasks).Count
    Write-Output "SELFTEST_OK open=$openCount today=$todayCount"
}

