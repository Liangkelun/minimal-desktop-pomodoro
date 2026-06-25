# This file is dot-sourced before task list views. Keep high-level list interaction policy separate from view assembly, event registration, and gesture mechanics.

function Invoke-TaskListDefaultClickAction([System.Windows.Forms.ListBox]$List, [object]$Item) {
    if ($null -eq $List -or $null -eq $Item -or [string]::IsNullOrWhiteSpace([string]$Item.Id)) { return }
    $ctrlPressed = (([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Control) -eq [System.Windows.Forms.Keys]::Control)
    if ([bool]$script:Settings.ShortcutCtrlDoubleClickOpenLinkEnabled -and $ctrlPressed) {
        Open-TaskLink ([string]$Item.Id)
        return
    }
    $task = Get-TaskById ([string]$Item.Id)
    if (Test-TaskIsCompleted $task) { return }
    if ([string]$List.Tag.Mode -eq "today") {
        Invoke-AppActionResult (Start-PomodoroFromUi ([string]$Item.Id))
        return
    }
    Invoke-AppActionResult (Invoke-TaskDefaultWorkflow ([string]$List.Tag.Mode) ([string]$Item.Id))
}

function Reset-TaskListClickState([object]$Tag) {
    $Tag.LastClickId = ""
    $Tag.LastClickAt = [DateTime]::MinValue
    $Tag.LastClickPoint = [System.Drawing.Point]::Empty
}

function Invoke-TaskListMouseDown([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.MouseEventArgs]$EventArgs) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $EventArgs) { return }
    $tag = $List.Tag
    if ($EventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $item = Select-ListItemAtPoint $List $EventArgs.X $EventArgs.Y
        if ($null -ne $item) {
            Show-TaskMenu $List ([string]$tag.Mode)
        }
        return
    }
    if ($EventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    if (Test-TaskTopDragBand $EventArgs.Y) {
        Start-TaskListWindowDrag $List
        return
    }
    if (Test-TaskFirstRowBlankDragPoint $List $EventArgs.X $EventArgs.Y) {
        Start-TaskListWindowDrag $List
        return
    }

    $previousId = Get-TaskListSelectedItemId $List
    $item = Select-ListItemAtPoint $List $EventArgs.X $EventArgs.Y
    $renameCandidate = $false
    if ($null -ne $item) {
        $gesture = Get-TaskListClickGesture $tag $item $EventArgs
        if ($gesture.IsDoubleClick) {
            $tag.DragId = ""
            Reset-TaskListClickState $tag
            $tag.SuppressMouseDoubleClick = $true
            Hide-TaskTitlePreview
            Invoke-TaskListDefaultClickAction $List $item
            return
        }
        $renameCandidate = [bool]$gesture.RenameCandidate
        Set-TaskListLastClickState $tag $item $EventArgs ([DateTime]$gesture.Now)
    }
    else {
        $tag.DragId = ""
        Reset-TaskListClickState $tag
    }
    if ($null -ne $item -and (Test-TaskCheckboxPoint $List $EventArgs.X)) {
        $tag.DragId = ""
        Reset-TaskListClickState $tag
        Invoke-TaskOperationResult (Invoke-TaskToggleCompletionWorkflow ([string]$item.Id))
        return
    }
    if ($null -ne $item) {
        $sameSelected = (-not [string]::IsNullOrWhiteSpace($previousId) -and $previousId -eq [string]$item.Id)
        $renameClick = ($sameSelected -and $renameCandidate)
        if ($renameClick) {
            $tag.DragId = ""
            Reset-TaskListClickState $tag
            Start-TaskTitleInlineEdit $List $item $List.SelectedIndex
            return
        }
        Show-TaskTitlePreview $List $item ([int]$EventArgs.X) ([int]$EventArgs.Y)
        $tag.DragId = [string]$item.Id
        $tag.DragStart = New-Object System.Drawing.Point -ArgumentList @([int]$EventArgs.X, [int]$EventArgs.Y)
    }
}

function Invoke-TaskListSelectedIndexChanged([System.Windows.Forms.ListBox]$List) {
    if ($null -ne $List -and -not $List.IsDisposed -and $null -ne $List.Tag -and $List.Tag.WindowDrag -and $List.SelectedIndex -ge 0) {
        $List.ClearSelected()
    }
}

function Invoke-TaskListMouseMove([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.MouseEventArgs]$EventArgs) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $EventArgs) { return }
    Update-BottomChromeVisibility
    if ($EventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $null -ne $script:WindowDragStart) {
        Move-WindowDrag
        return
    }
    if (Test-TaskListDragStartReady $List $EventArgs) {
        $tag = $List.Tag
        if (Test-TaskListDragThresholdExceeded $tag $EventArgs) {
            Start-TaskListItemDrag $List
        }
    }
}

function Invoke-TaskListMouseUp([System.Windows.Forms.ListBox]$List) {
    if ($null -ne $List -and $null -ne $List.Tag) {
        $List.Tag.DragId = ""
        if ($List.Tag.WindowDrag) {
            if (-not $List.IsDisposed) {
                $List.ClearSelected()
            }
            $List.Tag.WindowDrag = $false
        }
    }
    Stop-WindowDrag
}

function Invoke-TaskListDragOver([System.Windows.Forms.DragEventArgs]$EventArgs) {
    if ($null -eq $EventArgs) { return }
    if (Test-TaskListDragDataPresent $EventArgs) {
        $EventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move
    }
    else {
        $EventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
}

function Invoke-TaskListDragDrop([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.DragEventArgs]$EventArgs) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $EventArgs) { return }
    $sourceId = Get-TaskListDragSourceId $EventArgs
    if ([string]::IsNullOrWhiteSpace($sourceId)) { return }
    $targetIndex = Get-TaskListDropTargetIndex $List $EventArgs
    Invoke-TaskOperationResult (Invoke-TaskMoveWorkflow ([string]$List.Tag.Mode) $sourceId $targetIndex)
}

function Invoke-TaskListMouseDoubleClick([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.MouseEventArgs]$EventArgs) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $EventArgs) { return }
    if ($null -ne $List.Tag -and $List.Tag.SuppressMouseDoubleClick) {
        $List.Tag.SuppressMouseDoubleClick = $false
        return
    }
    $item = Select-ListItemAtPoint $List $EventArgs.X $EventArgs.Y
    if ($null -ne $item) {
        Invoke-TaskListDefaultClickAction $List $item
    }
}
