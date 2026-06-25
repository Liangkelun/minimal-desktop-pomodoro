# This file is dot-sourced before Views.Done.ps1. It owns execution-record statistics dialogs.

function Show-ExecutionStatsDialog([string]$TaskId) {
    $task = Get-TaskById $TaskId
    if ($null -eq $task) { return }
    $statsText = Get-ExecutionTaskStatsText $TaskId
    if ([string]::IsNullOrWhiteSpace($statsText)) { return }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = T "ExecutionStats"
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.Width = 390
    $dialog.Height = 215
    $dialog.Font = $script:Form.Font

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 3
    $layout.Padding = New-Object System.Windows.Forms.Padding(10)
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null

    $header = New-Object System.Windows.Forms.TableLayoutPanel
    $header.Dock = [System.Windows.Forms.DockStyle]::Fill
    $header.ColumnCount = 2
    $header.RowCount = 1
    $header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 32))) | Out-Null

    $title = New-Object System.Windows.Forms.Label
    $title.Dock = [System.Windows.Forms.DockStyle]::Fill
    $title.AutoEllipsis = $true
    $title.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $title.Text = [string]$task.title
    $header.Controls.Add($title, 0, 0)

    $help = New-Object System.Windows.Forms.Button
    $help.Dock = [System.Windows.Forms.DockStyle]::Fill
    $help.Text = T "ExecutionStatsHelp"
    $help.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $help.Add_Click({ [System.Windows.Forms.MessageBox]::Show((T "ExecutionStatsHelpText"), (T "ExecutionStatsHelpTitle"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null })
    $header.Controls.Add($help, 1, 0)

    $body = New-Object System.Windows.Forms.Label
    $body.Dock = [System.Windows.Forms.DockStyle]::Fill
    $body.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $body.AutoSize = $false
    $body.Text = $statsText

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "OK"
    $ok.Width = 76
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttons.Controls.Add($ok)
    $dialog.AcceptButton = $ok

    $layout.Controls.Add($header, 0, 0)
    $layout.Controls.Add($body, 0, 1)
    $layout.Controls.Add($buttons, 0, 2)
    $dialog.Controls.Add($layout)

    try {
        if ($null -ne $script:Form -and -not $script:Form.IsDisposed) { $dialog.ShowDialog($script:Form) | Out-Null }
        else { $dialog.ShowDialog() | Out-Null }
    }
    finally { $dialog.Dispose() }
}
