# This file is dot-sourced by TaskPomodoro.ps1. It owns the task details dialog UI.

function Edit-TaskDetails([string]$Id) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return
    }

    $surfaceColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $panelColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = T "TaskDetails"
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(460, 420)
    $dialog.Font = $script:Form.Font
    $dialog.BackColor = $surfaceColor

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 2
    $layout.RowCount = 9
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.Margin = New-Object System.Windows.Forms.Padding(0)
    $layout.BackColor = $surfaceColor
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 120))) | Out-Null
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 55))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 45))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38))) | Out-Null

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = T "TaskTitle"
    $titleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $titleLabel.BackColor = $surfaceColor
    $layout.Controls.Add($titleLabel, 0, 0)

    $titleBox = New-TaskDetailTextBox $false
    $titleBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $titleBox.Text = [string]$task.title
    $layout.Controls.Add($titleBox, 1, 0)

    $estimateLabel = New-Object System.Windows.Forms.Label
    $estimateLabel.Text = T "EstimatedPomodoros"
    $estimateLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $estimateLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $estimateLabel.BackColor = $surfaceColor
    $layout.Controls.Add($estimateLabel, 0, 1)

    $estimateBox = New-Object System.Windows.Forms.NumericUpDown
    $estimateBox.Dock = [System.Windows.Forms.DockStyle]::Left
    $estimateBox.Width = 88
    $estimateBox.Minimum = 0
    $estimateBox.Maximum = 99
    $estimateBox.Value = [decimal][Math]::Max(0, [int]$task.estimatedPomodoroCount)
    $layout.Controls.Add($estimateBox, 1, 1)

    $actualLabel = New-Object System.Windows.Forms.Label
    $actualLabel.Text = T "ActualPomodoros"
    $actualLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $actualLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $actualLabel.BackColor = $surfaceColor
    $layout.Controls.Add($actualLabel, 0, 2)

    $actualBox = New-Object System.Windows.Forms.NumericUpDown
    $actualBox.Dock = [System.Windows.Forms.DockStyle]::Left
    $actualBox.Width = 88
    $actualBox.Minimum = 0
    $actualBox.Maximum = 999
    $actualBox.Value = [decimal][Math]::Max(0, [int]$task.pomodoroCount)
    $layout.Controls.Add($actualBox, 1, 2)

    $notesLabel = New-Object System.Windows.Forms.Label
    $notesLabel.Text = T "TaskNotes"
    $notesLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $notesLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $notesLabel.BackColor = $surfaceColor
    $layout.Controls.Add($notesLabel, 0, 3)
    $layout.SetColumnSpan($notesLabel, 2)

    $notesBox = New-TaskDetailTextBox $true
    $notesBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $notesBox.Text = [string]$task.notes
    $layout.Controls.Add($notesBox, 0, 4)
    $layout.SetColumnSpan($notesBox, 2)

    $linksHeader = New-Object System.Windows.Forms.TableLayoutPanel
    $linksHeader.Dock = [System.Windows.Forms.DockStyle]::Fill
    $linksHeader.ColumnCount = 2
    $linksHeader.RowCount = 1
    $linksHeader.Margin = New-Object System.Windows.Forms.Padding(0)
    $linksHeader.BackColor = $surfaceColor
    $linksHeader.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $linksHeader.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 42))) | Out-Null

    $linksLabel = New-Object System.Windows.Forms.Label
    $linksLabel.Text = T "TaskLinks"
    $linksLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $linksLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $linksLabel.BackColor = $surfaceColor
    $linksHeader.Controls.Add($linksLabel, 0, 0)

    $openLink = New-Button "..." 34
    $openLink.Dock = [System.Windows.Forms.DockStyle]::Fill
    $openLink.Margin = New-Object System.Windows.Forms.Padding(0)
    $linksHeader.Controls.Add($openLink, 1, 0)

    $layout.Controls.Add($linksHeader, 0, 5)
    $layout.SetColumnSpan($linksHeader, 2)

    $linksBox = New-TaskLinksTextBox
    $linksBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $linksBox.Text = Get-TaskLinksText $task
    $layout.Controls.Add($linksBox, 0, 6)
    $layout.SetColumnSpan($linksBox, 2)
    $openLink.Add_Click({
        [string[]]$links = ConvertTo-TaskLinks $linksBox.Text
        if ($links.Count -gt 0) {
            Open-TaskLinkTarget ([string]$links[0]) $Id $task
        }
        else {
            [System.Windows.Forms.MessageBox]::Show((T "NoTaskLink"), (T "AppTitle")) | Out-Null
        }
    })

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = T "OpenTaskLink"
    $hint.Dock = [System.Windows.Forms.DockStyle]::Fill
    $hint.ForeColor = [System.Drawing.Color]::DimGray
    $hint.BackColor = $surfaceColor
    $hint.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $layout.Controls.Add($hint, 0, 7)
    $layout.SetColumnSpan($hint, 2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $buttons.WrapContents = $false
    $buttons.BackColor = $surfaceColor

    $save = New-Button (T "SaveSettings") 82
    $save.Add_Click({
        if (Set-TaskDetails $Id $titleBox.Text $notesBox.Text ([int]$estimateBox.Value) ([int]$actualBox.Value) $linksBox.Text) {
            $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $dialog.Close()
            Render-CurrentView
        }
        else {
            [System.Windows.Forms.MessageBox]::Show((T "EnterTaskFirst"), (T "AppTitle")) | Out-Null
        }
    })
    $cancel = New-Button (T "Cancel") 82
    $cancel.Add_Click({
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $dialog.Close()
    })
    $buttons.Controls.Add($save)
    $buttons.Controls.Add($cancel)
    $layout.Controls.Add($buttons, 0, 8)
    $layout.SetColumnSpan($buttons, 2)

    $dialog.Controls.Add($layout)
    $dialog.AcceptButton = $save
    $dialog.CancelButton = $cancel
    $titleBox.Select($titleBox.Text.Length, 0)
    $dialog.ShowDialog($script:Form) | Out-Null
    $dialog.Dispose()
}
