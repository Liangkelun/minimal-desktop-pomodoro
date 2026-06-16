# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Render-TimerView {
    $script:ContentPanel.Controls.Clear()

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 4
    Add-BottomChromeTracking $layout
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 84))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

    $script:TimerLabel = New-Object System.Windows.Forms.Label
    $script:TimerLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:TimerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $script:TimerLabel.Font = New-Object System.Drawing.Font($script:Form.Font.FontFamily, 30, [System.Drawing.FontStyle]::Bold)
    Add-BottomChromeTracking $script:TimerLabel
    $layout.Controls.Add($script:TimerLabel, 0, 0)

    $script:CurrentTaskLabel = New-Object System.Windows.Forms.Label
    $script:CurrentTaskLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:CurrentTaskLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $script:CurrentTaskLabel.AutoEllipsis = $true
    Add-BottomChromeTracking $script:CurrentTaskLabel
    $layout.Controls.Add($script:CurrentTaskLabel, 0, 1)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttons.WrapContents = $false
    $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    Add-BottomChromeTracking $buttons

    $script:StartButton = New-Button (T "Start") 72
    $script:StartButton.Add_Click({
        if ($script:TimerState -eq "idle") {
            Invoke-AppActionResult (Start-Pomodoro ([string]$script:CurrentPomodoroTaskId))
        }
    })
    Add-BottomChromeTracking $script:StartButton
    $buttons.Controls.Add($script:StartButton)

    $script:PauseButton = New-Button (T "Pause") 72
    $script:PauseButton.Add_Click({
        if ($script:TimerState -eq "paused") {
            Invoke-AppActionResult (Continue-Pomodoro)
        }
        elseif ($script:TimerState -eq "running") {
            Invoke-AppActionResult (Pause-Pomodoro)
        }
    })
    Add-BottomChromeTracking $script:PauseButton
    $buttons.Controls.Add($script:PauseButton)

    $stop = New-Button (T "Stop") 72
    $stop.Add_Click({ Invoke-AppActionResult (Stop-Pomodoro) })
    Add-BottomChromeTracking $stop
    $buttons.Controls.Add($stop)

    $settings = New-Button (T "Settings") 62
    $settings.Add_Click({ Show-PomodoroSettingsDialog })
    Add-BottomChromeTracking $settings
    $buttons.Controls.Add($settings)

    $layout.Controls.Add($buttons, 0, 2)
    $script:ContentPanel.Controls.Add($layout)
    Update-TimerLabels
}

function Start-PomodoroFromUi([string]$TaskId) {
    $task = Get-TaskById $TaskId
    if ($null -ne $task -and [int]$task.estimatedPomodoroCount -le 0) {
        $text = [Microsoft.VisualBasic.Interaction]::InputBox((T "PomodoroPlanPrompt"), (T "EstimatedPomodoros"), "1")
        if ([string]::IsNullOrWhiteSpace($text)) { return New-PomodoroOperationResult $false "" "" $false $null }
        try { $planned = [int]$text } catch { $planned = 0 }
        if ($planned -le 0) {
            [System.Windows.Forms.MessageBox]::Show((T "PomodoroPlanInvalid"), (T "AppTitle")) | Out-Null
            return New-PomodoroOperationResult $false "" "" $false $null
        }
        Add-TaskEstimatedPomodoros $task $planned | Out-Null
    }
    return Start-Pomodoro $TaskId
}

function Confirm-AdditionalPomodorosFromUi {
    if ($script:TimerPhase -ne "break" -or [string]::IsNullOrWhiteSpace($script:CurrentPomodoroTaskId)) { return }
    $task = Get-TaskById $script:CurrentPomodoroTaskId
    if ($null -eq $task -or (Test-TaskIsCompleted $task) -or [int]$task.estimatedPomodoroCount -le 0 -or (Get-TaskRemainingPomodoros $task) -gt 0) { return }
    $text = [Microsoft.VisualBasic.Interaction]::InputBox((T "PomodoroAddPrompt"), (T "EstimatedPomodoros"), "1")
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    try { $count = [int]$text } catch { $count = 0 }
    if ($count -le 0) {
        [System.Windows.Forms.MessageBox]::Show((T "PomodoroAddInvalid"), (T "AppTitle")) | Out-Null
        return
    }
    Add-TaskEstimatedPomodoros $task $count | Out-Null
}

function Complete-PomodoroFromUi {
    Confirm-AdditionalPomodorosFromUi
    return Complete-Pomodoro
}

function Update-TimerLabels {
    if ($null -ne $script:TimerLabel) {
        $script:TimerLabel.Text = Format-Time $script:SecondsRemaining
    }
    if ($null -ne $script:CurrentTaskLabel) {
        if ($script:TimerPhase -eq "break") {
            $script:CurrentTaskLabel.Text = T "BreakFocusing"
        }
        else {
            $name = $script:CurrentPomodoroTaskTitle
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = T "UnboundFocus"
            }
            $task = Get-TaskById $script:CurrentPomodoroTaskId
            $progress = Get-TaskPomodoroProgressText $task
            if (-not [string]::IsNullOrWhiteSpace($progress)) {
                $name = "$name $progress"
            }
            $script:CurrentTaskLabel.Text = "$(T "CurrentTask"): $name"
        }
    }
    if ($null -ne $script:PauseButton) {
        if ($script:TimerState -eq "paused") {
            $script:PauseButton.Text = T "Continue"
            $script:PauseButton.Enabled = $true
        }
        elseif ($script:TimerState -eq "running") {
            $script:PauseButton.Text = T "Pause"
            $script:PauseButton.Enabled = $true
        }
        else {
            $script:PauseButton.Text = T "Pause"
            $script:PauseButton.Enabled = $false
        }
    }
    if ($null -ne $script:StartButton) {
        $script:StartButton.Enabled = ($script:TimerState -eq "idle")
    }
}

