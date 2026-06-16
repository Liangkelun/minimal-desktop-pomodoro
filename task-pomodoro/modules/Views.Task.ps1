# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Invoke-TaskListDefaultClickAction([System.Windows.Forms.ListBox]$List, [object]$Item) {
    if ($null -eq $List -or $null -eq $Item -or [string]::IsNullOrWhiteSpace([string]$Item.Id)) {
        return
    }
    if ((([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Control) -eq [System.Windows.Forms.Keys]::Control)) {
        Open-TaskLink ([string]$Item.Id)
        return
    }
    $task = Get-TaskById ([string]$Item.Id)
    if (Test-TaskIsCompleted $task) {
        return
    }
    if ([string]$List.Tag.Mode -eq "today") {
        Invoke-AppActionResult (Start-PomodoroFromUi ([string]$Item.Id))
        return
    }
    Invoke-AppActionResult (Invoke-TaskDefaultAction ([string]$List.Tag.Mode) ([string]$Item.Id))
}

function Reset-TaskListClickState([object]$Tag) { $Tag.LastClickId = ""; $Tag.LastClickAt = [DateTime]::MinValue; $Tag.LastClickPoint = [System.Drawing.Point]::Empty }

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
            Invoke-TaskOperationResult (Add-Task $sender.Text ([bool]$sender.Tag))
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
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::F2) {
            Start-SelectedTaskTitleInlineEdit $sender
            $eventArgs.SuppressKeyPress = $true
        }
    })

    if ($scheduleToday) {
        $tasks = Get-TodayTasks
    }
    else {
        $tasks = Get-OpenTasks
    }

    $displayIndex = 1
    foreach ($task in $tasks) {
        $item = [pscustomobject]@{
            Id = $task.id
            Display = Format-TaskLine $task $displayIndex
        }
        $list.Items.Add($item) | Out-Null
        $displayIndex++
    }
    if ($list.Items.Count -eq 0) { $list.Items.Add([pscustomobject]@{ Id = ""; Display = T ($(if ($scheduleToday) { "NoTodayTasks" } else { "NoOpenTasks" })) }) | Out-Null } else { $list.Items.Add([pscustomobject]@{ Id = ""; Display = "" }) | Out-Null }

    $list.Add_MouseDown({
        param($sender, $eventArgs)
        $tag = $sender.Tag
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
            if ($null -ne $item) {
                Show-TaskMenu $sender ([string]$tag.Mode)
            }
        }
        elseif ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if (Test-TaskTopDragBand $eventArgs.Y) {
                Start-TaskListWindowDrag $sender
                return
            }
            if (Test-TaskFirstRowBlankDragPoint $sender $eventArgs.X $eventArgs.Y) {
                Start-TaskListWindowDrag $sender
                return
            }

            $previousId = ""
            if ($null -ne $sender.SelectedItem) {
                $previousId = [string]$sender.SelectedItem.Id
            }
            $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
            $renameCandidate = $false
            if ($null -ne $item) {
                $now = Get-Date
                $elapsed = ($now - [DateTime]$tag.LastClickAt).TotalMilliseconds
                $lastPoint = [System.Drawing.Point]$tag.LastClickPoint
                $doubleSize = [System.Windows.Forms.SystemInformation]::DoubleClickSize
                $sameLastClick = ([string]$tag.LastClickId -eq [string]$item.Id)
                $withinDoubleTime = ($elapsed -ge 0 -and $elapsed -le [System.Windows.Forms.SystemInformation]::DoubleClickTime)
                $withinDoubleArea = ([Math]::Abs([int]$eventArgs.X - [int]$lastPoint.X) -le [Math]::Ceiling([double]$doubleSize.Width / 2.0) -and [Math]::Abs([int]$eventArgs.Y - [int]$lastPoint.Y) -le [Math]::Ceiling([double]$doubleSize.Height / 2.0))
                $isDoubleClick = ($eventArgs.Clicks -ge 2 -or ($sameLastClick -and $withinDoubleTime -and $withinDoubleArea))
                $renameCandidate = ($sameLastClick -and $elapsed -gt [System.Windows.Forms.SystemInformation]::DoubleClickTime -and $elapsed -le 2000 -and $withinDoubleArea)
                if ($isDoubleClick) {
                    $tag.DragId = ""
                    Reset-TaskListClickState $tag
                    $tag.SuppressMouseDoubleClick = $true
                    Hide-TaskTitlePreview
                    Invoke-TaskListDefaultClickAction $sender $item
                    return
                }
                $tag.LastClickId = [string]$item.Id
                $tag.LastClickAt = $now
                $tag.LastClickPoint = New-Object System.Drawing.Point -ArgumentList @([int]$eventArgs.X, [int]$eventArgs.Y)
            }
            else {
                $tag.DragId = ""
                Reset-TaskListClickState $tag
            }
            if ($null -ne $item -and (Test-TaskCheckboxPoint $sender $eventArgs.X)) {
                $tag.DragId = ""
                Reset-TaskListClickState $tag
                Invoke-TaskOperationResult (Toggle-TaskCompletion ([string]$item.Id))
                return
            }
            if ($null -ne $item) {
                $sameSelected = (-not [string]::IsNullOrWhiteSpace($previousId) -and $previousId -eq [string]$item.Id)
                $renameClick = ($sameSelected -and $renameCandidate)
                if ($renameClick) {
                    $tag.DragId = ""
                    Reset-TaskListClickState $tag
                    Start-TaskTitleInlineEdit $sender $item $sender.SelectedIndex
                    return
                }
                Show-TaskTitlePreview $sender $item ([int]$eventArgs.X) ([int]$eventArgs.Y)
                $tag.DragId = [string]$item.Id
                $tag.DragStart = New-Object System.Drawing.Point -ArgumentList @([int]$eventArgs.X, [int]$eventArgs.Y)
            }
        }
    })
    $list.Add_SelectedIndexChanged({
        param($sender, $eventArgs)
        if ($null -ne $sender -and -not $sender.IsDisposed -and $null -ne $sender.Tag -and $sender.Tag.WindowDrag -and $sender.SelectedIndex -ge 0) {
            $sender.ClearSelected()
        }
    })
    $list.Add_MouseMove({
        param($sender, $eventArgs)
        Update-BottomChromeVisibility
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $null -ne $script:WindowDragStart) {
            Move-WindowDrag
            return
        }
        $tag = $sender.Tag
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -and -not [string]::IsNullOrWhiteSpace([string]$tag.DragId)) {
            $dx = [Math]::Abs($eventArgs.X - $tag.DragStart.X)
            $dy = [Math]::Abs($eventArgs.Y - $tag.DragStart.Y)
            if ($dx -ge 4 -or $dy -ge 4) {
                $sender.DoDragDrop([string]$tag.DragId, [System.Windows.Forms.DragDropEffects]::Move) | Out-Null
                $tag.DragId = ""
            }
        }
    })
    $list.Add_MouseUp({
        param($sender, $eventArgs)
        if ($null -ne $sender -and $null -ne $sender.Tag) {
            $sender.Tag.DragId = ""
            if ($sender.Tag.WindowDrag) {
                if (-not $sender.IsDisposed) {
                    $sender.ClearSelected()
                }
                $sender.Tag.WindowDrag = $false
            }
        }
        Stop-WindowDrag
    })
    $list.Add_DragOver({
        param($sender, $eventArgs)
        if ($eventArgs.Data.GetDataPresent([string])) {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move
        }
        else {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    })
    $list.Add_DragDrop({
        param($sender, $eventArgs)
        if (-not $eventArgs.Data.GetDataPresent([string])) {
            return
        }
        $sourceId = [string]$eventArgs.Data.GetData([string])
        $point = $sender.PointToClient((New-Object System.Drawing.Point -ArgumentList @([int]$eventArgs.X, [int]$eventArgs.Y)))
        $targetIndex = $sender.IndexFromPoint($point)
        Invoke-TaskOperationResult (Move-TaskInView ([string]$sender.Tag.Mode) $sourceId $targetIndex)
    })
    $list.Add_MouseDoubleClick({
        param($sender, $eventArgs)
        if ($null -ne $sender.Tag -and $sender.Tag.SuppressMouseDoubleClick) {
            $sender.Tag.SuppressMouseDoubleClick = $false
            return
        }
        $item = Select-ListItemAtPoint $sender $eventArgs.X $eventArgs.Y
        if ($null -ne $item) {
            Invoke-TaskListDefaultClickAction $sender $item
        }
    })

    $layout.Controls.Add($list, 0, 0)
    $layout.Controls.Add($inputRow, 0, 1)
    $script:ContentPanel.Controls.Add($layout)
    Set-Status (T "ClickTaskHint")
}

