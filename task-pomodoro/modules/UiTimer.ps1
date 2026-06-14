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
    $archivedCount = Invoke-DailyArchiveIfDue
    if ($archivedCount -gt 0) {
        Set-Status (T "DailyArchivedTasks")
        Render-CurrentView
    }
    Update-WatermarkClickThrough
    Update-BottomChromeVisibility
    Update-SizeToggleButton
    if ($script:TimerState -eq "running") {
        $remaining = [int][Math]::Ceiling(($script:PomodoroEndAt - (Get-Date)).TotalSeconds)
        if ($remaining -le 0) {
            $script:SecondsRemaining = 0
            Invoke-AppActionResult (Complete-Pomodoro)
        }
        else {
            $script:SecondsRemaining = $remaining
            Update-TimerLabels
        }
    }
}
