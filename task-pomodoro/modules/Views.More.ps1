# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Render-MoreView {
    $script:ContentPanel.Controls.Clear()

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $panel.WrapContents = $false
    $panel.Padding = New-Object System.Windows.Forms.Padding(2)
    Add-BottomChromeTracking $panel

    $done = New-Button (T "Done") 260
    $done.Add_Click({ Set-ActiveView "done" })
    Add-BottomChromeTracking $done
    $panel.Controls.Add($done)

    $check = New-Button (T "DataCheck") 260
    $check.Add_Click({ Invoke-DataCheck })
    Add-BottomChromeTracking $check
    $panel.Controls.Add($check)

    $script:ContentPanel.Controls.Add($panel)
}

function Render-DoneView {
    $script:ContentPanel.Controls.Clear()

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 2
    Add-BottomChromeTracking $layout
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

    $title = New-Object System.Windows.Forms.Label
    $title.Dock = [System.Windows.Forms.DockStyle]::Fill
    $title.Text = T "Done"
    Add-BottomChromeTracking $title
    $layout.Controls.Add($title, 0, 0)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Dock = [System.Windows.Forms.DockStyle]::Fill
    $list.DisplayMember = "Display"
    $list.IntegralHeight = $false
    $list.Font = $script:Form.Font
    $list.Tag = [pscustomobject]@{ Mode = "done" }
    Enable-TaskListDrawing $list
    Add-BottomChromeTracking $list

    $doneTasks = Get-DoneTasks
    foreach ($task in $doneTasks) {
        $item = [pscustomobject]@{
            Id = $task.id
            Display = Format-DoneLine $task
        }
        $list.Items.Add($item) | Out-Null
    }
    if ($list.Items.Count -eq 0) {
        $list.Items.Add([pscustomobject]@{ Id = ""; Display = T "NoDoneTasks" }) | Out-Null
    }
    $list.Add_MouseDown({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
            if ($null -ne $item) {
                Show-TaskTitlePreview $sender $item ([int]$eventArgs.X) ([int]$eventArgs.Y)
            }
        }
        elseif ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
            if ($null -ne $item) {
                Show-DoneTaskMenu $sender
            }
        }
    })
    $list.Add_DoubleClick({
        param($sender, $eventArgs)
        $selected = $sender.SelectedItem
        if ($null -eq $selected -or [string]::IsNullOrWhiteSpace([string]$selected.Id)) {
            return
        }
        if ((([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Control) -eq [System.Windows.Forms.Keys]::Control)) {
            Open-TaskLink ([string]$selected.Id)
            return
        }
        Edit-TaskDetails $selected.Id
    })

    $layout.Controls.Add($list, 0, 1)
    $script:ContentPanel.Controls.Add($layout)
}

function Show-DoneTaskMenu([System.Windows.Forms.ListBox]$List) {
    $selected = $List.SelectedItem
    if ($null -eq $selected -or [string]::IsNullOrWhiteSpace([string]$selected.Id)) {
        return
    }

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    Add-MenuItem $menu (T "TaskDetails") $selected.Id { param($sender, $eventArgs) Edit-TaskDetails ([string]$sender.Tag) }
    Add-OpenTaskLinkMenuItem $menu $selected.Id
    $point = $List.PointToClient([System.Windows.Forms.Cursor]::Position)
    $menu.Show($List, $point)
}

