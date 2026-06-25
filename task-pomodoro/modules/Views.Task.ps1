# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Render-TaskView([string]$Mode) {
    Hide-TaskTitlePreview
    if ($null -ne $script:TaskTitleEditBox -and -not $script:TaskTitleEditBox.IsDisposed) {
        $script:TaskTitleEditBox.Dispose()
        $script:TaskTitleEditBox = $null
    }
    $script:ContentPanel.Controls.Clear()
    $scheduleToday = ($Mode -eq "today")

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 2
    Add-BottomChromeTracking $layout
    $layout.Margin = New-Object System.Windows.Forms.Padding(0)
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32))) | Out-Null
    $script:TaskInputRowStyle = $layout.RowStyles[1]
    Add-BottomChromeTracking $layout

    $inputRow = New-Object System.Windows.Forms.TableLayoutPanel
    $inputRow.Dock = [System.Windows.Forms.DockStyle]::Fill
    $inputRow.ColumnCount = 1
    $inputRow.RowCount = 1
    $inputRow.Margin = New-Object System.Windows.Forms.Padding(0)
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

    $input = New-Object System.Windows.Forms.TextBox
    $input.Dock = [System.Windows.Forms.DockStyle]::Fill
    $input.Font = $script:Form.Font
    $input.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
    $input.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $input.Tag = [bool]$scheduleToday
    $script:TaskInputBox = $input
    $input.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            Invoke-TaskOperationResult (Invoke-TaskCreateWorkflow $sender.Text ([bool]$sender.Tag))
            $eventArgs.SuppressKeyPress = $true
        }
    })
    $inputRow.Controls.Add($input, 0, 0)
    Add-BottomChromeTracking $inputRow
    Add-BottomChromeTracking $input

    $list = New-Object System.Windows.Forms.ListBox
    $list.Dock = [System.Windows.Forms.DockStyle]::Fill
    $list.DisplayMember = "Display"
    $list.IntegralHeight = $false
    $list.Font = New-Object System.Drawing.Font($script:Form.Font.FontFamily, [float]$script:Settings.TaskFontSize, [System.Drawing.FontStyle]::Regular)
    Enable-TaskListDrawing $list
    $script:TaskRowHeight = [Math]::Max(22, ($list.ItemHeight + 2))
    Ensure-TaskRowsVisible (Get-CollapsedTaskRows)
    $list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $list.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $list.AllowDrop = $true; $script:TaskListBox = $list
    $list.Tag = [pscustomobject]@{
        Mode = $Mode
        DragId = ""
        DragStart = [System.Drawing.Point]::Empty
        WindowDrag = $false
        LastClickId = ""
        LastClickAt = [DateTime]::MinValue
        LastClickPoint = [System.Drawing.Point]::Empty
        SuppressMouseDoubleClick = $false
    }
    $list.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -ne [System.Windows.Forms.Keys]::F2) { return }
        if (-not [bool]$script:Settings.ShortcutF2EditTaskEnabled) { return }
        if ($sender.SelectedIndex -lt 0 -or $null -eq $sender.SelectedItem) { $eventArgs.SuppressKeyPress = $true; return }
        $item = $sender.SelectedItem
        if (-not [string]::IsNullOrWhiteSpace([string]$item.Id)) { Hide-TaskTitlePreview; Edit-TaskDetails ([string]$item.Id) }
        $eventArgs.SuppressKeyPress = $true
    })

    foreach ($item in (Get-TaskListItemsForView $Mode)) {
        $list.Items.Add($item) | Out-Null
    }

    Register-TaskListEventHandlers $list

    $layout.Controls.Add($list, 0, 0)
    $layout.Controls.Add($inputRow, 0, 1)
    $script:ContentPanel.Controls.Add($layout)
    Set-Status (T "ClickTaskHint")
}

