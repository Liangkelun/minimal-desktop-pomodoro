# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

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
    $completeAction = { param($sender, $eventArgs) Invoke-TaskMenuCompleteAction ([string]$sender.Tag) }
    if (Test-TaskIsCompleted $task) {
        $completeText = T "UncompleteTaskMenu"
        $completeAction = { param($sender, $eventArgs) Invoke-TaskMenuUncompleteAction ([string]$sender.Tag) }
    }
    if ($Mode -eq "today") {
        $starterActiveForSelected = Test-TaskStarterRunningForTask ([string]$selected.Id)
        if ($starterActiveForSelected) {
            if (Test-PomodoroRuntimePaused) {
                Add-MenuItem $menu (T "Continue") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuContinueTimerAction ([string]$sender.Tag) }
            }
            else {
                Add-MenuItem $menu (T "Pause") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuPauseTimerAction ([string]$sender.Tag) }
            }
            Add-MenuItem $menu (T "Stop") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuStopTimerAction ([string]$sender.Tag) }
            Add-MenuItem $menu (T "Settings") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuStarterSettingsAction ([string]$sender.Tag) }
            Add-MenuEntry $menu (New-Object System.Windows.Forms.ToolStripSeparator)
        }
        Add-MenuItem $menu (T "PomodoroMenu") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuStartPomodoroAction ([string]$sender.Tag) }
        if (-not $starterActiveForSelected) {
            Add-MenuItem $menu (Get-TaskStarterLabel) $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuStartStarterAction ([string]$sender.Tag) }
        }
        Add-MenuItem $menu $completeText $selected.Id $completeAction
        Add-MenuItem $menu (T "EditTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuEditAction ([string]$sender.Tag) }
        $more = Add-SubMenu $menu "..."
        Add-OpenTaskLinkMenuItem $more $selected.Id
        Add-MenuItem $more (T "RemoveFromToday") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuUnscheduleTodayAction ([string]$sender.Tag) }
        Add-MenuItem $more (T "EndTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuEndAction ([string]$sender.Tag) }
        Add-MenuItem $more (T "PinToTop") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuPinTodayAction ([string]$sender.Tag) }
        Add-MenuItem $more (T "DeleteTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuDeleteAction ([string]$sender.Tag) }
    }
    else {
        Add-MenuItem $menu (T "ScheduleToday") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuScheduleTodayAction ([string]$sender.Tag) }
        Add-MenuItem $menu $completeText $selected.Id $completeAction
        Add-MenuItem $menu (T "EditTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuEditAction ([string]$sender.Tag) }
        Add-MenuItem $menu (T "EndTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuEndAction ([string]$sender.Tag) }
        $more = Add-SubMenu $menu "..."
        Add-OpenTaskLinkMenuItem $more $selected.Id
        Add-MenuItem $more (T "PinToTop") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuPinTasksAction ([string]$sender.Tag) }
        Add-MenuItem $more (T "DeleteTask") $selected.Id { param($sender, $eventArgs) Invoke-TaskMenuDeleteAction ([string]$sender.Tag) }
    }
    $point = $List.PointToClient([System.Windows.Forms.Cursor]::Position)
    $menu.Show($List, $point)
}
