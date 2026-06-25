# This file is dot-sourced by TaskPomodoro.ps1. Keep inbox UI separate from task list ordering and Today behavior.

function Format-InboxLine([object]$Item) {
    if ($null -eq $Item) { return "" }
    $created = Format-ExecutionDate ([string]$Item.createdAt)
    if ([string]::IsNullOrWhiteSpace($created)) { return [string]$Item.title }
    return "$([string]$Item.title) - $created"
}

function Render-InboxView {
    Hide-TaskTitlePreview
    $script:ContentPanel.Controls.Clear()

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 2
    $layout.Margin = New-Object System.Windows.Forms.Padding(0)
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32))) | Out-Null
    Add-BottomChromeTracking $layout

    $list = New-Object System.Windows.Forms.ListBox
    $list.Dock = [System.Windows.Forms.DockStyle]::Fill
    $list.DisplayMember = "Display"
    $list.IntegralHeight = $false
    $list.Font = New-Object System.Drawing.Font($script:Form.Font.FontFamily, [float]$script:Settings.TaskFontSize, [System.Drawing.FontStyle]::Regular)
    $list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $list.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $list.Tag = [pscustomobject]@{ Mode = "inbox" }
    Add-BottomChromeTracking $list

    foreach ($item in (Get-InboxItems)) {
        $list.Items.Add([pscustomobject]@{ Id = [string]$item.id; Display = Format-InboxLine $item }) | Out-Null
    }
    if ($list.Items.Count -eq 0) {
        $list.Items.Add([pscustomobject]@{ Id = ""; Display = T "NoInboxItems" }) | Out-Null
    }
    $list.Add_MouseDown({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
            if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item.Id)) { Show-InboxItemMenu $sender }
        }
    })
    $list.Add_MouseDoubleClick({
        param($sender, $eventArgs)
        $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
        if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.Id)) { return }
        Invoke-AppActionResult (Invoke-InboxPromoteWorkflow ([string]$item.Id) $false)
    })

    $input = New-Object System.Windows.Forms.TextBox
    $input.Dock = [System.Windows.Forms.DockStyle]::Fill
    $input.Font = $script:Form.Font
    $input.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
    $input.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $script:TaskInputBox = $input
    Add-BottomChromeTracking $input
    $input.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            Invoke-AppActionResult (Invoke-InboxCreateWorkflow $sender.Text)
            $eventArgs.SuppressKeyPress = $true
        }
    })

    $layout.Controls.Add($list, 0, 0)
    $layout.Controls.Add($input, 0, 1)
    $script:ContentPanel.Controls.Add($layout)
    Set-Status (T "InboxHint")
}

function Edit-InboxItem([string]$Id) {
    $item = Get-InboxItemById $Id
    if ($null -eq $item) { return }
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = T "Edit"
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MinimizeBox = $false; $dialog.MaximizeBox = $false; $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(420, 110)
    $dialog.Font = $script:Form.Font
    $dialog.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill; $layout.ColumnCount = 2; $layout.RowCount = 2
    $layout.Padding = New-Object System.Windows.Forms.Padding(12); $layout.BackColor = $dialog.BackColor
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 72))) | Out-Null
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38))) | Out-Null
    $label = New-Object System.Windows.Forms.Label; $label.Text = T "TaskTitle"; $label.Dock = [System.Windows.Forms.DockStyle]::Fill; $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft; $label.BackColor = $dialog.BackColor
    $titleBox = New-TaskDetailTextBox $false; $titleBox.Dock = [System.Windows.Forms.DockStyle]::Fill; $titleBox.Text = [string]$item.title
    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel; $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft; $buttons.WrapContents = $false; $buttons.BackColor = $dialog.BackColor
    $save = New-Button (T "SaveSettings") 82; $cancel = New-Button (T "Cancel") 82
    $save.Add_Click({ $result = Invoke-InboxEditWorkflow $Id $titleBox.Text; if ([bool]$result.Ok) { $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK; $dialog.Close() }; Invoke-AppActionResult $result }.GetNewClosure())
    $cancel.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dialog.Close() })
    $buttons.Controls.Add($save); $buttons.Controls.Add($cancel)
    $layout.Controls.Add($label, 0, 0); $layout.Controls.Add($titleBox, 1, 0); $layout.Controls.Add($buttons, 0, 1); $layout.SetColumnSpan($buttons, 2)
    $dialog.Controls.Add($layout); $dialog.AcceptButton = $save; $dialog.CancelButton = $cancel; $titleBox.Select($titleBox.Text.Length, 0)
    $dialog.ShowDialog($script:Form) | Out-Null
    $dialog.Dispose()
}

function Show-InboxItemMenu([System.Windows.Forms.ListBox]$List) {
    $selected = $List.SelectedItem
    if ($null -eq $selected -or [string]::IsNullOrWhiteSpace([string]$selected.Id)) { return }
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    Add-MenuItem $menu (T "PromoteToTask") ([string]$selected.Id) { param($sender, $eventArgs) Invoke-AppActionResult (Invoke-InboxPromoteWorkflow ([string]$sender.Tag) $false) }
    Add-MenuItem $menu (T "PromoteToToday") ([string]$selected.Id) { param($sender, $eventArgs) Invoke-AppActionResult (Invoke-InboxPromoteWorkflow ([string]$sender.Tag) $true) }
    Add-MenuItem $menu (T "Edit") ([string]$selected.Id) { param($sender, $eventArgs) Edit-InboxItem ([string]$sender.Tag) }
    Add-MenuItem $menu (T "Delete") ([string]$selected.Id) { param($sender, $eventArgs) Invoke-AppActionResult (Invoke-InboxDeleteWorkflow ([string]$sender.Tag)) }
    $point = $List.PointToClient([System.Windows.Forms.Cursor]::Position)
    $menu.Show($List, $point)
}