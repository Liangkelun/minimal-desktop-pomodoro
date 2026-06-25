# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Render-TimerView {
    $script:ContentPanel.Controls.Clear()
    $script:CurrentTaskLabel = $null

    $compactTimer = ((Get-CurrentTaskRows) -le (Get-CollapsedTaskRows))
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 4
    if ($compactTimer) { $layout.RowCount = 3 }
    Add-BottomChromeTracking $layout
    if ($compactTimer) {
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    }
    else {
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 84))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    }

    $script:TimerLabel = New-Object System.Windows.Forms.Label
    $script:TimerLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:TimerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $timerFontSize = 30; if ($compactTimer) { $timerFontSize = 18 }
    $script:TimerLabel.Font = New-Object System.Drawing.Font($script:Form.Font.FontFamily, $timerFontSize, [System.Drawing.FontStyle]::Bold)
    Add-BottomChromeTracking $script:TimerLabel
    $layout.Controls.Add($script:TimerLabel, 0, 0)

    if (-not $compactTimer) {
        $script:CurrentTaskLabel = New-Object System.Windows.Forms.Label
        $script:CurrentTaskLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
        $script:CurrentTaskLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $script:CurrentTaskLabel.AutoEllipsis = $true
        Add-BottomChromeTracking $script:CurrentTaskLabel
        $layout.Controls.Add($script:CurrentTaskLabel, 0, 1)
    }

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttons.WrapContents = $false
    $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    Add-BottomChromeTracking $buttons

    $startWidth = 72; $pauseWidth = 72; $stopWidth = 72; $settingsWidth = 62
    if ($compactTimer) { $startWidth = 48; $pauseWidth = 54; $stopWidth = 48; $settingsWidth = 58 }

    $script:StartButton = New-Button (T "Start") $startWidth
    $script:StartButton.Add_Click({
        $snapshot = Get-PomodoroRuntimeTimerViewSnapshot
        if ([bool]$snapshot.IsIdle) { Invoke-AppActionResult (Invoke-PomodoroStartWorkflow ([string]$snapshot.TaskId) 0 $false) }
    })
    Add-BottomChromeTracking $script:StartButton
    $buttons.Controls.Add($script:StartButton)

    $script:PauseButton = New-Button (T "Pause") $pauseWidth
    $script:PauseButton.Add_Click({
        $snapshot = Get-PomodoroRuntimeTimerViewSnapshot
        if ([bool]$snapshot.IsPaused -or [bool]$snapshot.IsRunning) { Invoke-AppActionResult (Invoke-PomodoroPauseOrContinueWorkflow) }
    })
    Add-BottomChromeTracking $script:PauseButton
    $buttons.Controls.Add($script:PauseButton)

    $stop = New-Button (T "Stop") $stopWidth
    $stop.Add_Click({ Invoke-AppActionResult (Invoke-PomodoroStopWorkflow) })
    Add-BottomChromeTracking $stop
    $buttons.Controls.Add($stop)

    $settings = New-Button (T "Settings") $settingsWidth
    $settings.Add_Click({
        $snapshot = Get-PomodoroRuntimeTimerViewSnapshot
        if ([bool]$snapshot.IsStarter) { Show-TaskStarterSettingsDialog } else { Show-PomodoroSettingsDialog }
    })
    Add-BottomChromeTracking $settings
    $buttons.Controls.Add($settings)

    $buttonRow = 2; if ($compactTimer) { $buttonRow = 1 }
    $layout.Controls.Add($buttons, 0, $buttonRow)
    $script:ContentPanel.Controls.Add($layout)
    Update-TimerLabels
}

function Update-TimerLabels {
    $snapshot = Get-PomodoroRuntimeTimerViewSnapshot
    if ($null -ne $script:TimerLabel) {
        $script:TimerLabel.Text = Format-Time ([int]$snapshot.RemainingSeconds)
    }
    if ($null -ne $script:CurrentTaskLabel) {
        if ([bool]$snapshot.IsStarter) {
            $name = [string]$snapshot.TaskTitle
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = T "UnboundFocus"
            }
            $script:CurrentTaskLabel.Text = "$(Get-TaskStarterLabel): $name"
        }
        elseif ([bool]$snapshot.IsBreak) {
            $script:CurrentTaskLabel.Text = T "BreakFocusing"
        }
        else {
            $name = [string]$snapshot.TaskTitle
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = T "UnboundFocus"
            }
            $task = Get-TaskById ([string]$snapshot.TaskId)
            $progress = Get-TaskPomodoroProgressText $task
            if (-not [string]::IsNullOrWhiteSpace($progress)) {
                $name = "$name $progress"
            }
            $script:CurrentTaskLabel.Text = "$(T "CurrentTask"): $name"
        }
    }
    if ($null -ne $script:PauseButton) {
        if ([bool]$snapshot.IsPaused) {
            $script:PauseButton.Text = T "Continue"
            $script:PauseButton.Enabled = $true
        }
        elseif ([bool]$snapshot.IsRunning) {
            $script:PauseButton.Text = T "Pause"
            $script:PauseButton.Enabled = $true
        }
        else {
            $script:PauseButton.Text = T "Pause"
            $script:PauseButton.Enabled = $false
        }
    }
    if ($null -ne $script:StartButton) {
        $script:StartButton.Enabled = [bool]$snapshot.IsIdle
    }
}
