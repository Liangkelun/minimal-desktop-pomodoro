# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Select-ListItemAtPoint([System.Windows.Forms.ListBox]$List, [int]$X, [int]$Y) {
    $index = $List.IndexFromPoint($X, $Y)
    if ($index -lt 0 -or $index -ge $List.Items.Count) {
        $List.ClearSelected()
        Hide-TaskTitlePreview
        return $null
    }
    $item = $List.Items[$index]
    if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.Id)) {
        $List.ClearSelected()
        Hide-TaskTitlePreview
        return $null
    }
    $List.SelectedIndex = $index
    return $item
}

function Add-MenuEntry([object]$Menu, [System.Windows.Forms.ToolStripItem]$Item) {
    if ($Menu -is [System.Windows.Forms.ToolStripMenuItem]) {
        $Menu.DropDownItems.Add($Item) | Out-Null
    }
    else {
        $Menu.Items.Add($Item) | Out-Null
    }
}

function Add-MenuItem([object]$Menu, [string]$Text, [string]$TaskId, [scriptblock]$Action) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    $item.Tag = $TaskId
    $item.Add_Click($Action)
    Add-MenuEntry $Menu $item
}

function Add-SubMenu([object]$Menu, [string]$Text) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    Add-MenuEntry $Menu $item
    return $item
}

function Add-OpenTaskLinkMenuItem([object]$Menu, [string]$TaskId) {
    $taskIdForClick = [string]$TaskId
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = T "OpenTaskLink"
    $item.Tag = $taskIdForClick
    $item.Add_Click({ param($sender, $eventArgs) Open-TaskLink ([string]$sender.Tag) })
    Add-MenuEntry $Menu $item
}

function Show-TaskMenu([System.Windows.Forms.ListBox]$List, [string]$Mode) {
    $selected = $List.SelectedItem
    if ($null -eq $selected) {
        return
    }
    if ([string]::IsNullOrWhiteSpace($selected.Id)) {
        return
    }

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $task = Get-TaskById ([string]$selected.Id)
    $completeText = T "CompleteTaskMenu"
    $completeAction = { param($sender, $eventArgs) Invoke-TaskOperationResult (Complete-Task ([string]$sender.Tag)) }
    if (Test-TaskIsCompleted $task) {
        $completeText = T "UncompleteTaskMenu"
        $completeAction = { param($sender, $eventArgs) Invoke-TaskOperationResult (Uncomplete-Task ([string]$sender.Tag)) }
    }
    if ($Mode -eq "today") {
        Add-MenuItem $menu (T "PomodoroMenu") $selected.Id { param($sender, $eventArgs) Invoke-AppActionResult (Start-Pomodoro ([string]$sender.Tag)) }
        Add-MenuItem $menu $completeText $selected.Id $completeAction
        Add-MenuItem $menu (T "EditTask") $selected.Id { param($sender, $eventArgs) Edit-TaskDetails ([string]$sender.Tag) }
        $more = Add-SubMenu $menu "..."
        Add-OpenTaskLinkMenuItem $more $selected.Id
        Add-MenuItem $more (T "RemoveFromToday") $selected.Id { param($sender, $eventArgs) Invoke-TaskOperationResult (Unschedule-TaskToday ([string]$sender.Tag)) }
        Add-MenuItem $more (T "EndTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskOperationResult (End-Task ([string]$sender.Tag)) }
        Add-MenuItem $more (T "PinToTop") $selected.Id { param($sender, $eventArgs) Invoke-TaskOperationResult (Pin-TaskToTop "today" ([string]$sender.Tag)) }
    }
    else {
        Add-MenuItem $menu (T "ScheduleToday") $selected.Id { param($sender, $eventArgs) Invoke-TaskOperationResult (Schedule-TaskToday ([string]$sender.Tag)) }
        Add-MenuItem $menu $completeText $selected.Id $completeAction
        Add-MenuItem $menu (T "EditTask") $selected.Id { param($sender, $eventArgs) Edit-TaskDetails ([string]$sender.Tag) }
        Add-MenuItem $menu (T "EndTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskOperationResult (End-Task ([string]$sender.Tag)) }
        $more = Add-SubMenu $menu "..."
        Add-OpenTaskLinkMenuItem $more $selected.Id
        Add-MenuItem $more (T "PinToTop") $selected.Id { param($sender, $eventArgs) Invoke-TaskOperationResult (Pin-TaskToTop "tasks" ([string]$sender.Tag)) }
    }
    $point = $List.PointToClient([System.Windows.Forms.Cursor]::Position)
    $menu.Show($List, $point)
}

