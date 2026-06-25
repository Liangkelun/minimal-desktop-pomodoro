# This file is dot-sourced by TaskPomodoro.ps1. It renders task-centered execution records from behavior events and pomodoro records.

function Render-DoneView {
    $script:ContentPanel.Controls.Clear()

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 2
    $layout.Margin = New-Object System.Windows.Forms.Padding(0)
    Add-BottomChromeTracking $layout
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

    $title = New-Object System.Windows.Forms.Label
    $title.Dock = [System.Windows.Forms.DockStyle]::Fill
    $title.Text = T "ExecutionRecords"
    Add-BottomChromeTracking $title
    $layout.Controls.Add($title, 0, 0)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Dock = [System.Windows.Forms.DockStyle]::Fill
    $list.DisplayMember = "Display"
    $list.IntegralHeight = $false
    $list.Font = New-Object System.Drawing.Font($script:Form.Font.FontFamily, [float]$script:Settings.TaskFontSize, [System.Drawing.FontStyle]::Regular)
    $list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $list.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    Enable-ExecutionRecordDrawing $list
    $list.Tag = [pscustomobject]@{ Mode = "execution" }
    Add-BottomChromeTracking $list

    $records = Get-ExecutionRecords
    if (@($records.Active).Count -gt 0) {
        $list.Items.Add([pscustomobject]@{ Id = ""; Display = T "ExecutionActiveHeader"; IsHeader = $true }) | Out-Null
        foreach ($record in @($records.Active)) { $list.Items.Add($record) | Out-Null }
    }
    if (@($records.History).Count -gt 0) {
        $list.Items.Add([pscustomobject]@{ Id = ""; Display = T "ExecutionHistoryHeader"; IsHeader = $true }) | Out-Null
        foreach ($record in @($records.History)) { $list.Items.Add($record) | Out-Null }
    }
    if ($list.Items.Count -eq 0) {
        $list.Items.Add([pscustomobject]@{ Id = ""; Display = T "NoExecutionRecords"; IsHeader = $true }) | Out-Null
    }

    $list.Add_MouseDown({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
            if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item.Id)) {
                Show-TaskTitlePreview $sender $item ([int]$eventArgs.X) ([int]$eventArgs.Y)
            }
        }
        elseif ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
            if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item.Id)) { Show-ExecutionRecordMenu $sender }
        }
    })
    $list.Add_DoubleClick({
        param($sender, $eventArgs)
        $selected = $sender.SelectedItem
        if ($null -eq $selected -or [string]::IsNullOrWhiteSpace([string]$selected.Id)) { return }
        if ((([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Control) -eq [System.Windows.Forms.Keys]::Control)) {
            Open-TaskLink ([string]$selected.Id)
            return
        }
        Show-ExecutionRecordDetail ([string]$selected.Id)
    })

    $layout.Controls.Add($list, 0, 1)
    $script:ContentPanel.Controls.Add($layout)
    Set-Status (T "ExecutionRecordsHint")
}

function Show-ExecutionRecordDetail([string]$TaskId) {
    $detail = Get-ExecutionDetailText $TaskId
    if ([string]::IsNullOrWhiteSpace($detail)) { return }
    [System.Windows.Forms.MessageBox]::Show($detail, (T "ExecutionRecords")) | Out-Null
}


function Show-ExecutionRecordMenu([System.Windows.Forms.ListBox]$List) {
    $selected = $List.SelectedItem
    if ($null -eq $selected -or [string]::IsNullOrWhiteSpace([string]$selected.Id)) { return }

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    Add-MenuItem $menu (T "ExecutionStats") ([string]$selected.Id) { param($sender, $eventArgs) Show-ExecutionStatsDialog ([string]$sender.Tag) }
    Add-MenuItem $menu (T "ViewExecutionDetail") ([string]$selected.Id) { param($sender, $eventArgs) Show-ExecutionRecordDetail ([string]$sender.Tag) }
    Add-MenuItem $menu (T "TaskDetails") ([string]$selected.Id) { param($sender, $eventArgs) Edit-TaskDetails ([string]$sender.Tag) }
    Add-OpenTaskLinkMenuItem $menu ([string]$selected.Id)
    $point = $List.PointToClient([System.Windows.Forms.Cursor]::Position)
    $menu.Show($List, $point)
}
