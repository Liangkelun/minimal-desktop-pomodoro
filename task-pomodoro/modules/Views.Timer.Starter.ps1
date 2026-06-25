# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Show-TaskStarterDoneDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = T "TaskStarterMenu"
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MinimizeBox = $false; $dialog.MaximizeBox = $false; $dialog.ShowInTaskbar = $false
    $dialog.Width = 560; $dialog.Height = 160

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill; $layout.ColumnCount = 1; $layout.RowCount = 2
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38))) | Out-Null

    $label = New-Object System.Windows.Forms.Label
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill; $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.Text = T "StarterDonePrompt"
    $layout.Controls.Add($label, 0, 0)

    $buttons = New-Object System.Windows.Forms.TableLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill; $buttons.ColumnCount = 4; $buttons.RowCount = 1
    foreach ($i in 1..4) { $buttons.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) | Out-Null }
    $buttons.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $buttonByAction = @{}
    $index = 0
    foreach ($entry in @(
        @{ Text = T "StarterStartPomodoro"; Action = "pomodoro" },
        @{ Text = Get-TaskStarterAgainText; Action = "again" },
        @{ Text = T "StarterCompleteTask"; Action = "complete" },
        @{ Text = T "StarterStop"; Action = "stop" }
    )) {
        $button = New-Button ([string]$entry.Text) 100
        $button.Dock = [System.Windows.Forms.DockStyle]::Fill
        $button.Margin = New-Object System.Windows.Forms.Padding(2)
        $button.Tag = [pscustomobject]@{ Dialog = $dialog; Action = [string]$entry.Action }
        $button.Add_Click({ param($sender, $eventArgs) $sender.Tag.Dialog.Tag = [string]$sender.Tag.Action; $sender.Tag.Dialog.Close() })
        $buttons.Controls.Add($button, $index, 0)
        $buttonByAction[[string]$entry.Action] = $button
        $index++
    }

    $layout.Controls.Add($buttons, 0, 1); $dialog.Controls.Add($layout); $dialog.Tag = "stop"
    $defaultAction = Get-TaskStarterCompletionDefaultAction
    $dialog.AcceptButton = $buttonByAction[$defaultAction]
    $dialog.CancelButton = $buttonByAction["stop"]
    if ($null -ne $dialog.AcceptButton) { ([System.Windows.Forms.Button]$dialog.AcceptButton).Select() }
    if ($null -ne $script:Form -and -not $script:Form.IsDisposed) { $dialog.ShowDialog($script:Form) | Out-Null } else { $dialog.ShowDialog() | Out-Null }
    return [string]$dialog.Tag
}

function Complete-TaskStarterFromUi {
    $taskId = Get-PomodoroRuntimeCurrentTaskId
    $result = Invoke-TaskStarterCompleteWorkflow
    if (-not $result.Ok -or [string]::IsNullOrWhiteSpace($taskId)) { return $result }
    Stop-BackgroundAudio
    $stopEvents = @($result.Events)
    $action = Show-TaskStarterDoneDialog
    if ($action -eq "pomodoro") {
        $next = Start-PomodoroFromUi $taskId
        if ($next.Ok) { return Add-PomodoroResultEvents $next $stopEvents }
        return $result
    }
    if ($action -eq "again") {
        $next = Invoke-TaskStarterAgainWorkflow $taskId $stopEvents
        if ($next.Ok) { return $next }
        return $result
    }
    if ($action -eq "complete") {
        $next = Invoke-TaskStarterCompleteTaskWorkflow $taskId $stopEvents
        if ($next.Ok) { return $next }
        return $result
    }
    return $result
}