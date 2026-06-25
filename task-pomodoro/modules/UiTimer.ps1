# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Update-DateLabel {
    if ($null -ne $script:StatusLabel) {
        $stamp = (Get-Date).ToString("MM-dd HH:mm")
        if ([string]::IsNullOrWhiteSpace($script:StatusMessage)) {
            $script:StatusLabel.Text = $stamp
        }
        else {
            $script:StatusLabel.Text = "$stamp  $script:StatusMessage"
        }
    }
}

function Set-UiTimerInterval([int]$Milliseconds) {
    if ($null -eq $script:UiTimer) {
        return
    }
    if ($Milliseconds -lt 50) {
        $Milliseconds = 50
    }
    if ($script:UiTimer.Interval -ne $Milliseconds) {
        $script:UiTimer.Interval = $Milliseconds
    }
}

function Timer-Tick {
    Update-DateLabel
    $archiveResult = Invoke-DailyArchiveIfDueResult
    if ([int]$archiveResult.Data -gt 0) {
        Invoke-AppActionResult $archiveResult
    }
    Update-WatermarkRuntimeClickThrough
    Update-BottomChromeVisibility
    Update-SizeToggleButton
    $pomodoroTick = Update-PomodoroRuntimeTick
    if ($null -eq $pomodoroTick) { return }
    if ([string]$pomodoroTick.Kind -eq "complete") {
        Invoke-AppActionResult (Complete-PomodoroTickFromUi)
        if ($null -ne $script:WatermarkGhostPanel -and -not $script:WatermarkGhostPanel.IsDisposed) { $script:WatermarkGhostPanel.Invalidate() }
        return
    }
    if ([string]$pomodoroTick.Kind -eq "pause-threshold") { Invoke-AppActionResult (New-PomodoroPauseThresholdResult $pomodoroTick); return }
    if ([bool]$pomodoroTick.ShouldUpdateTimer) { Update-TimerLabels }
    if ([bool]$pomodoroTick.ShouldInvalidateTask -and $null -ne $script:TaskListBox -and -not $script:TaskListBox.IsDisposed) { $script:TaskListBox.Invalidate() }
    if ([bool]$pomodoroTick.ShouldInvalidateTask -and $null -ne $script:WatermarkGhostPanel -and -not $script:WatermarkGhostPanel.IsDisposed) { $script:WatermarkGhostPanel.Invalidate() }
}
