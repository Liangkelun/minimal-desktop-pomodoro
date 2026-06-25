# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.
function Invoke-SelfTestPomodoroScenarios {
    try {
        $archiveTimerTask = New-TaskObject "__selftest_archive_timer__" $true
        $archiveTimerTask.status = "done"; $archiveTimerTask.completedAt = "2000-01-01T00:00:00+08:00"
        $script:Tasks = @($archiveTimerTask); Invoke-SelfTestPomodoroAction (Start-Pomodoro $archiveTimerTask.id) | Out-Null
        $archiveTimerResult = Invoke-ArchiveCompletedTasksBeforeResult ([datetime]"2000-01-02T00:00:00"); Invoke-AppResultEvents $archiveTimerResult
        $archiveRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if ([int]$archiveTimerResult.Data -ne 1 -or -not [bool]$archiveRuntime.IsIdle -or -not [string]::IsNullOrWhiteSpace([string]$archiveRuntime.TaskId) -or $archiveTimerTask.status -ne "archived") { throw "selftest failed: daily archive clears timer" }

        $script:Settings.StartSoundReminder = $false
        $script:Settings.EndSoundReminder = $false
        $script:Settings.ColorReminder = $false
        $script:Settings.WorkMusic = $false
        $script:Settings.BreakMusic = $false
        $script:Settings.StarterMusic = $false
        $script:Settings.StarterMinutes = 2
        $timerTask = New-TaskObject "__selftest_timer__" $true
        $script:Tasks = @($timerTask)
        $startResult = Invoke-SelfTestPomodoroAction (Start-Pomodoro $timerTask.id)
        $startRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $startResult.Ok -or $startResult.StatusKey -ne "Focusing" -or $startResult.View -ne "timer" -or -not [bool]$startRuntime.IsRunning) {
            throw "selftest failed: start pomodoro result"
        }
        if (@($startResult.Events).Count -lt 1) {
            throw "selftest failed: start pomodoro events"
        }
        $pauseResult = Invoke-SelfTestPomodoroAction (Pause-Pomodoro)
        $pauseRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $pauseResult.Ok -or -not [bool]$pauseRuntime.IsPaused -or @(Get-BehaviorEventsForTask $timerTask.id | Where-Object { [string]$_.type -eq "pomodoro_paused" }).Count -ne 1) {
            throw "selftest failed: pause pomodoro result"
        }
        $script:PomodoroPausedAtDate = (Get-Date).AddMinutes(-6)
        $pauseFive = New-PomodoroPauseThresholdResult (Update-PomodoroRuntimeTick)
        if ($null -eq $pauseFive -or $pauseFive.StatusKey -ne "PomodoroPausedOverFive" -or @($pauseFive.Events | Where-Object { $_.Type -eq "AppendBehaviorEvent" -and $_.BehaviorType -eq "pomodoro_pause_interrupted" }).Count -ne 1) { throw "selftest failed: pause five minute threshold" }
        Invoke-AppResultEvents $pauseFive
        if ($null -ne (Update-PomodoroRuntimeTick)) { throw "selftest failed: pause threshold should not repeat" }
        $script:PomodoroPausedAtDate = (Get-Date).AddMinutes(-11)
        $pauseTen = New-PomodoroPauseThresholdResult (Update-PomodoroRuntimeTick)
        if ($null -eq $pauseTen -or $pauseTen.StatusKey -ne "PomodoroPausedOverTen" -or @($pauseTen.Events | Where-Object { $_.Type -eq "AppendBehaviorEvent" -and $_.BehaviorType -eq "pomodoro_pause_interrupted" }).Count -ne 1) { throw "selftest failed: pause ten minute threshold" }
        Invoke-AppResultEvents $pauseTen
        $continueResult = Invoke-SelfTestPomodoroAction (Continue-Pomodoro)
        $continueRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $continueResult.Ok -or -not [bool]$continueRuntime.IsRunning -or @(Get-BehaviorEventsForTask $timerTask.id | Where-Object { [string]$_.type -eq "pomodoro_resumed" }).Count -ne 1) {
            throw "selftest failed: continue pomodoro result"
        }
        $stopResult = Invoke-SelfTestPomodoroAction (Stop-Pomodoro)
        $stopRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $stopResult.Ok -or $stopResult.StatusKey -ne "PomodoroInterrupted" -or -not [bool]$stopRuntime.IsIdle) {
            throw "selftest failed: stop pomodoro result"
        }
        $restoreSavedAt = Get-Date; $restoreState = [pscustomobject][ordered]@{ Version = 1; State = "paused"; Phase = "work"; TaskId = [string]$timerTask.id; TaskTitle = [string]$timerTask.title; RemainingSeconds = 777; PlannedMinutes = 25; StartedAt = $restoreSavedAt.AddMinutes(-65).ToString("yyyy-MM-ddTHH:mm:sszzz"); EndAt = ""; PausedAt = $restoreSavedAt.AddMinutes(-60).ToString("yyyy-MM-ddTHH:mm:sszzz"); PauseThresholdsTriggered = @(5); SessionWorkMinutes = 25; SessionBreakMinutes = 5; SessionMaxRounds = 2; SessionStartedCount = 1; SessionAutoStartNext = $true; SavedAt = $restoreSavedAt.AddMinutes(-55).ToString("yyyy-MM-ddTHH:mm:sszzz") }
        Write-JsonAtomic (Get-AppPath "TimerStateFile") $restoreState
        if (-not (Restore-PomodoroRuntimeState)) { throw "selftest failed: restore pomodoro runtime state" }
        $restoredRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not [bool]$restoredRuntime.IsPaused -or [string]$restoredRuntime.TaskId -ne [string]$timerTask.id -or [int]$restoredRuntime.RemainingSeconds -ne 777) { throw "selftest failed: restored pomodoro runtime snapshot" }
        if ($null -ne (Update-PomodoroRuntimeTick)) { throw "selftest failed: restored pause should ignore offline time" }
        Invoke-SelfTestPomodoroAction (Stop-Pomodoro) | Out-Null
        $uiStartTask = New-TaskObject "__selftest_inline_ui_start__" $true; $uiStartTask.estimatedPomodoroCount = 1; $script:Tasks = @($uiStartTask); $script:ActiveView = "today"
        $uiStartResult = Invoke-SelfTestPomodoroAction (Start-PomodoroFromUi $uiStartTask.id)
        $uiInlineState = Get-TaskInlineCountdownState $uiStartTask.id
        if (-not $uiStartResult.Ok -or -not $uiStartResult.ShouldRender -or -not [string]::IsNullOrWhiteSpace([string]$uiStartResult.View) -or $null -eq $uiInlineState -or [string]$uiInlineState.Kind -ne "pomodoro") { throw "selftest failed: task inline pomodoro start" }
        Invoke-SelfTestPomodoroAction (Stop-Pomodoro) | Out-Null
        $script:Tasks = @($timerTask); Invoke-SelfTestPomodoroAction (Start-Pomodoro "") | Out-Null
        if ($null -ne (Get-TaskInlineCountdownState $timerTask.id)) { throw "selftest failed: unbound pomodoro should not bind task inline countdown" }
        Invoke-SelfTestPomodoroAction (Stop-Pomodoro) | Out-Null
        $mutationTask = New-TaskObject "__selftest_timer_mutation__" $true
        $script:Tasks = @($mutationTask); Invoke-SelfTestPomodoroAction (Start-Pomodoro $mutationTask.id) | Out-Null
        $mutationCompleteResult = Complete-Task $mutationTask.id
        if (@($mutationCompleteResult.Events | Where-Object { $_.Type -eq "TaskTimerInvalidated" }).Count -ne 1 -or @($mutationCompleteResult.Events | Where-Object { $_.Type -eq "AppendPomodoroRecord" }).Count -ne 0) { throw "selftest failed: task mutation event boundary" }
        Invoke-AppResultEvents $mutationCompleteResult
        $mutationRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $mutationCompleteResult.Ok -or -not [bool]$mutationRuntime.IsIdle -or -not [string]::IsNullOrWhiteSpace([string]$mutationRuntime.TaskId) -or -not ($mutationCompleteResult.PSObject.Properties.Name -contains "ShouldUpdateTimer")) { throw "selftest failed: task mutation clears timer" }
        $currentTask = New-TaskObject "__selftest_current_timer__" $true; $otherTask = New-TaskObject "__selftest_other_mutation__" $true
        $script:Tasks = @($currentTask, $otherTask); Invoke-SelfTestPomodoroAction (Start-Pomodoro $currentTask.id) | Out-Null; Invoke-AppResultEvents (Complete-Task $otherTask.id)
        $currentTaskRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not [bool]$currentTaskRuntime.IsRunning -or [string]$currentTaskRuntime.TaskId -ne [string]$currentTask.id) { throw "selftest failed: non-current task mutation keeps timer" }
        Invoke-SelfTestPomodoroAction (Stop-Pomodoro) | Out-Null
        $script:Tasks = @($timerTask)
        $starterResult = Invoke-SelfTestPomodoroAction (Start-TaskStarter $timerTask.id)
        $starterRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $starterResult.Ok -or $starterResult.StatusKey -ne "StarterFocusing" -or -not $starterResult.ShouldRender -or -not [string]::IsNullOrWhiteSpace([string]$starterResult.View) -or -not [bool]$starterRuntime.IsStarter -or [int]$starterRuntime.RemainingSeconds -ne 120 -or (Get-TaskStarterInlineText $timerTask.id) -ne "02:00") {
            throw "selftest failed: task starter start"
        }
        Invoke-SelfTestPomodoroAction (Pause-Pomodoro) | Out-Null
        $script:PomodoroPausedAtDate = (Get-Date).AddMinutes(-6)
        if ($null -ne (Update-PomodoroRuntimeTick)) { throw "selftest failed: starter pause threshold should not count" }
        Invoke-SelfTestPomodoroAction (Continue-Pomodoro) | Out-Null
        $starterDoneResult = Invoke-SelfTestPomodoroAction (Complete-TaskStarter)
        $starterDoneRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $starterDoneResult.Ok -or $starterDoneResult.StatusKey -ne "StarterDone" -or [string]$starterDoneResult.Data -ne [string]$timerTask.id -or -not [bool]$starterDoneRuntime.IsIdle -or [string]$starterDoneRuntime.Phase -ne "work") {
            throw "selftest failed: task starter complete"
        }
        if ([int](Get-TaskById $timerTask.id).pomodoroCount -ne 0) {
            throw "selftest failed: task starter should not count pomodoro"
        }
        $starterStopResult = Invoke-SelfTestPomodoroAction (Start-TaskStarter $timerTask.id)
        if (-not $starterStopResult.Ok) {
            throw "selftest failed: task starter restart"
        }
        $starterStoppedResult = Invoke-SelfTestPomodoroAction (Stop-Pomodoro)
        $starterStoppedRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $starterStoppedResult.Ok -or $starterStoppedResult.StatusKey -ne "StarterStopped" -or -not [bool]$starterStoppedRuntime.IsIdle) {
            throw "selftest failed: task starter stop"
        }
        $script:Settings.AutoStartNextPomodoro = $false
        $followTask = New-TaskObject "__selftest_manual_next__" $true
        $followTask.estimatedPomodoroCount = 2
        $script:Tasks = @($followTask)
        Invoke-SelfTestPomodoroAction (Start-Pomodoro $followTask.id) | Out-Null
        Invoke-SelfTestPomodoroAction (Complete-Pomodoro) | Out-Null
        if ([int](Get-TaskById $followTask.id).pomodoroCount -ne 1) {
            throw "selftest failed: complete pomodoro event count"
        }
        $breakInlineState = Get-TaskInlineCountdownState $followTask.id
        if ($null -eq $breakInlineState -or [string]$breakInlineState.Kind -ne "break") { throw "selftest failed: task inline break countdown" }
        Invoke-SelfTestPomodoroAction (Pause-Pomodoro) | Out-Null
        $script:PomodoroPausedAtDate = (Get-Date).AddMinutes(-6)
        $breakPauseFive = New-PomodoroPauseThresholdResult (Update-PomodoroRuntimeTick)
        if ($null -eq $breakPauseFive -or $breakPauseFive.StatusKey -ne "PomodoroPausedOverFive") { throw "selftest failed: break pause threshold" }
        Invoke-AppResultEvents $breakPauseFive
        Invoke-SelfTestPomodoroAction (Continue-Pomodoro) | Out-Null
        $breakResult = Invoke-SelfTestPomodoroAction (Complete-Break)
        $breakRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not $breakResult.Ok -or $breakResult.StatusKey -ne "ReadyNextPomodoro" -or -not [bool]$breakRuntime.IsIdle -or [string]$breakRuntime.TaskId -ne [string]$followTask.id) {
            throw "selftest failed: manual next pomodoro readiness"
        }
        Invoke-SelfTestPomodoroAction (Start-Pomodoro ([string]$breakRuntime.TaskId)) | Out-Null
        $manualNextRuntime = Get-PomodoroRuntimeTimerViewSnapshot
        if (-not [bool]$manualNextRuntime.IsRunning -or (Get-PomodoroSessionStartedCount) -ne 2) {
            throw "selftest failed: manual next pomodoro start"
        }
        Invoke-SelfTestPomodoroAction (Stop-Pomodoro) | Out-Null
        $script:Settings.AutoStartNextPomodoro = $true
    }
    finally {
        try { if (-not (Test-PomodoroRuntimeIdle)) { Invoke-SelfTestPomodoroAction (Stop-Pomodoro) | Out-Null } } catch {}
        $script:Settings.AutoStartNextPomodoro = $true
    }
}
