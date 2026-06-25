# This file is dot-sourced by TaskPomodoro.ps1. It owns the timer rhythm settings dialog.

function New-PomodoroNumberControl([int]$Value, [int]$Minimum, [int]$Maximum) {
    $number = New-Object System.Windows.Forms.NumericUpDown
    $number.Minimum = $Minimum; $number.Maximum = $Maximum; $number.Value = [decimal]$Value
    return $number
}

function Show-PomodoroSettingsDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = T "PomodoroSettings"
    $dialog.Width = 320; $dialog.Height = 250
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.MaximizeBox = $false; $dialog.MinimizeBox = $false; $dialog.Font = $script:Form.Font

    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill; $root.RowCount = 3; $root.ColumnCount = 1
    $root.Padding = New-Object System.Windows.Forms.Padding(10); $root.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 122))) | Out-Null
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

    $grid = New-Object System.Windows.Forms.TableLayoutPanel
    $grid.Dock = [System.Windows.Forms.DockStyle]::Fill; $grid.ColumnCount = 2; $grid.RowCount = 4; $grid.BackColor = $root.BackColor
    $grid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 54))) | Out-Null
    $grid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 46))) | Out-Null
    for ($i = 0; $i -lt 4; $i++) { $grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) | Out-Null }

    $work = New-PomodoroNumberControl (Get-PomodoroWorkMinutes) 1 180
    $break = New-PomodoroNumberControl (Get-PomodoroBreakMinutes) 1 60
    $roundsValue = [Math]::Max(1, (Get-PomodoroSessionMaxRounds)); if ($roundsValue -le 0) { $roundsValue = [int]$script:Settings.PomodoroRounds }
    $rounds = New-PomodoroNumberControl $roundsValue 1 24
    $auto = New-CheckOnlyControl (Get-PomodoroAutoStartNext)
    Add-SettingRow $grid (T "WorkMinutes") $work 0
    Add-SettingRow $grid (T "ShortBreakMinutes") $break 1
    Add-SettingRow $grid (T "ContinuousRounds") $rounds 2
    Add-SettingRow $grid (T "AutoStartNextPomodoro") $auto.Panel 3

    $scope = New-Object System.Windows.Forms.FlowLayoutPanel
    $scope.Dock = [System.Windows.Forms.DockStyle]::Fill; $scope.WrapContents = $false; $scope.BackColor = $root.BackColor
    $currentOnly = New-Object System.Windows.Forms.RadioButton
    $currentOnly.Text = T "ApplyThisPomodoro"; $currentOnly.Checked = $true; $currentOnly.Width = 86
    $future = New-Object System.Windows.Forms.RadioButton
    $future.Text = T "ApplyFuturePomodoros"; $future.Width = 170
    $scope.Controls.Add($currentOnly); $scope.Controls.Add($future)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $ok = New-Button (T "SaveSettings") 82
    $ok.Add_Click({ Set-PomodoroSessionOptions ([int]$work.Value) ([int]$break.Value) ([int]$rounds.Value) ([bool]$auto.Check.Checked) ([bool]$future.Checked); Set-Status (T "SettingsSaved"); Update-TimerLabels; $dialog.Close() })
    $cancel = New-Button (T "Cancel") 82
    $cancel.Add_Click({ $dialog.Close() })
    $restore = New-Button (T "RestoreDefaults") 92
    $restore.Add_Click({ $work.Value = [decimal]$script:Settings.WorkMinutes; $break.Value = [decimal]$script:Settings.ShortBreakMinutes; $rounds.Value = [decimal]$script:Settings.PomodoroRounds; $auto.Check.Checked = [bool]$script:Settings.AutoStartNextPomodoro })
    $buttons.Controls.Add($ok); $buttons.Controls.Add($cancel); $buttons.Controls.Add($restore)
    $root.Controls.Add($grid, 0, 0); $root.Controls.Add($scope, 0, 1); $root.Controls.Add($buttons, 0, 2)
    $dialog.Controls.Add($root)
    $dialog.ShowDialog($script:Form) | Out-Null
}
