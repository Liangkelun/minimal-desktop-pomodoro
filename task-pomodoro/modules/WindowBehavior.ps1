# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Update-DateLabel {
    if ($null -ne $script:StatusLabel) {
        $stamp = (Get-Date).ToString("MM-dd HH:mm")
        if ([string]::IsNullOrWhiteSpace($script:StatusMessage)) {
            $script:StatusLabel.Text = $stamp
        }
        else {
            $script:StatusLabel.Text = "$stamp  $script:StatusMessage"
        }
    }
}

function Set-BottomChromeVisible([bool]$Visible) {
    if ($script:BottomChromeVisible -eq $Visible) {
        return
    }
    $script:BottomChromeVisible = $Visible

    if ($Visible) {
        $script:NavRowStyle.Height = 30
        if ($null -ne $script:TaskInputRowStyle) {
            $script:TaskInputRowStyle.Height = 32
        }
    }
    else {
        $script:NavRowStyle.Height = 0
        if ($null -ne $script:TaskInputRowStyle) {
            $script:TaskInputRowStyle.Height = 0
        }
    }
    if ($null -ne $script:MainPanel) {
        $script:MainPanel.PerformLayout()
    }
    if ($null -ne $script:ContentPanel) {
        $script:ContentPanel.PerformLayout()
    }
}

function Get-CurrentTaskRows {
    if ($null -eq $script:Form) {
        return 10
    }
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $paddingHeight = [int]$script:Form.Padding.Vertical
    if ($null -ne $script:ContentPanel) {
        $paddingHeight += [int]$script:ContentPanel.Padding.Vertical
    }
    $contentHeight = [Math]::Max(0, ([int]$script:Form.Height - $paddingHeight - (Get-TaskRowsWindowSlack)))
    return [int][Math]::Max(1, [Math]::Round($contentHeight / [double]$rowHeight))
}

function Get-TaskRowsWindowSlack {
    return 8
}

function Update-SizeToggleButton {
    if ($null -eq $script:SizeToggleButton) {
        return
    }
    if ((Get-CurrentTaskRows) -le 1) {
        $script:SizeToggleButton.Text = [string][char]0x25A1
    }
    else {
        $script:SizeToggleButton.Text = "-"
    }
}

function Toggle-TaskRowsSize {
    if ((Get-CurrentTaskRows) -le 1) {
        Resize-WindowForTaskRows 10
    }
    else {
        Resize-WindowForTaskRows 1
    }
}

function Ensure-WatermarkToggleButton {
    if ($null -ne $script:WatermarkToggleButton -and -not $script:WatermarkToggleButton.IsDisposed) {
        return
    }
    if ($null -eq $script:Form) {
        return
    }

    $button = New-Button "~" 24
    $button.Height = 22
    $button.Margin = New-Object System.Windows.Forms.Padding(0)
    $button.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)
    $button.Location = New-Object System.Drawing.Point -ArgumentList @([int][Math]::Max(0, ([int]$script:Form.ClientSize.Width - 30)), 4)
    $button.Visible = $false
    $button.Add_MouseDown({
        param($sender, $eventArgs)
        $script:WatermarkToggleDragActive = $false
        $script:WatermarkToggleDragMoved = $false
        $script:WatermarkToggleDragStart = $null

        if (
            $script:WatermarkMode -and
            $eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -and
            $eventArgs.Y -le [Math]::Ceiling($sender.Height / 3.0)
        ) {
            $script:WatermarkToggleDragActive = $true
            $script:WatermarkToggleDragStart = [System.Windows.Forms.Cursor]::Position
            if ($null -ne $script:Form) {
                $script:Form.SetClickThrough($false)
            }
            Start-WindowDrag
        }
    })
    $button.Add_MouseMove({
        param($sender, $eventArgs)
        if (-not $script:WatermarkToggleDragActive -or $eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) {
            return
        }
        if ($null -ne $script:WatermarkToggleDragStart) {
            $current = [System.Windows.Forms.Cursor]::Position
            $dx = [Math]::Abs($current.X - $script:WatermarkToggleDragStart.X)
            $dy = [Math]::Abs($current.Y - $script:WatermarkToggleDragStart.Y)
            if ($dx -gt 3 -or $dy -gt 3) {
                $script:WatermarkToggleDragMoved = $true
            }
        }
        if ($script:WatermarkToggleDragMoved) {
            Move-WindowDrag
        }
    })
    $button.Add_MouseUp({
        param($sender, $eventArgs)
        if ($eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) {
            return
        }

        $wasDrag = $script:WatermarkToggleDragActive
        $wasMoved = $script:WatermarkToggleDragMoved
        $script:WatermarkToggleDragActive = $false
        $script:WatermarkToggleDragMoved = $false
        $script:WatermarkToggleDragStart = $null
        if ($wasDrag) {
            Stop-WindowDrag
        }

        if ($wasMoved -or -not $sender.ClientRectangle.Contains($eventArgs.Location)) {
            Update-WatermarkClickThrough
            return
        }

        Toggle-WatermarkMode
    })

    $script:WatermarkToggleButton = $button
    $script:Form.Controls.Add($button)
    $button.BringToFront()
}

function Ensure-HelpButton {
    if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed) {
        return
    }
    if ($null -eq $script:Form) {
        return
    }

    $button = New-Button "?" 24
    $button.Height = 22
    $button.Margin = New-Object System.Windows.Forms.Padding(0)
    $button.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)
    $button.Location = New-Object System.Drawing.Point -ArgumentList @([int][Math]::Max(0, ([int]$script:Form.ClientSize.Width - 56)), 4)
    $button.Visible = $false
    $button.Add_MouseUp({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            Show-HelpMenu $sender
        }
        elseif ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Show-HelpTopic "HelpTitle" "HelpText"
        }
    })

    $script:HelpButton = $button
    $script:Form.Controls.Add($button)
    $button.BringToFront()
}

function Show-HelpTopic([string]$TitleKey, [string]$TextKey) {
    if ($null -ne $script:Form -and $script:WatermarkMode) {
        $script:Form.SetClickThrough($false)
    }
    [System.Windows.Forms.MessageBox]::Show((T $TextKey), (T $TitleKey), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    if ($script:WatermarkMode) {
        Update-WatermarkClickThrough
    }
}

function Add-HelpMenuEntry([object]$Menu, [System.Windows.Forms.ToolStripItem]$Item) {
    if ($Menu -is [System.Windows.Forms.ToolStripMenuItem]) {
        $Menu.DropDownItems.Add($Item) | Out-Null
    }
    else {
        $Menu.Items.Add($Item) | Out-Null
    }
}

function Add-HelpMenuItem([object]$Menu, [string]$TextKey, [string]$TitleKey, [string]$BodyKey) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = T $TextKey
    $item.Tag = [pscustomobject]@{
        TitleKey = $TitleKey
        BodyKey = $BodyKey
    }
    $item.Add_Click({
        param($sender, $eventArgs)
        Show-HelpTopic $sender.Tag.TitleKey $sender.Tag.BodyKey
    })
    Add-HelpMenuEntry $Menu $item
}

function Add-HelpActionMenuItem([object]$Menu, [string]$TextKey, [scriptblock]$Action, [bool]$Enabled) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = T $TextKey
    $item.Enabled = $Enabled
    $item.Add_Click($Action)
    Add-HelpMenuEntry $Menu $item
}

function Show-HelpMenu([System.Windows.Forms.Control]$Owner) {
    if ($null -eq $Owner -or $Owner.IsDisposed) {
        return
    }
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    Add-HelpMenuItem $menu "HelpQuick" "HelpTitle" "HelpText"
    Add-HelpMenuItem $menu "HelpDiagram" "HelpDiagram" "HelpDiagramText"
    Add-HelpMenuItem $menu "HelpRules" "HelpRules" "HelpRulesText"
    Add-HelpMenuItem $menu "HelpShortcuts" "HelpShortcuts" "HelpShortcutsText"
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    $update = New-Object System.Windows.Forms.ToolStripMenuItem
    $update.Text = T "HelpUpdate"
    Add-HelpActionMenuItem $update "RestartApp" { Restart-TaskPomodoroApp } $true
    Add-HelpActionMenuItem $update "OpenAppFolder" { Open-AppFolder } $true
    Add-HelpActionMenuItem $update "UpdateFromGit" { Invoke-GitUpdateAndRestart } (Test-GitUpdateEnabled)
    Add-HelpMenuItem $update "UpdateInfo" "HelpUpdate" "UpdateInfoText"
    $menu.Items.Add($update) | Out-Null
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    Add-HelpMenuItem $menu "HelpSponsor" "HelpSponsor" "HelpSponsorText"
    Add-HelpMenuItem $menu "HelpAboutGovernance" "HelpAboutGovernance" "HelpAboutGovernanceText"
    $menu.Show($Owner, (New-Object System.Drawing.Point -ArgumentList @(0, [int]$Owner.Height)))
}

function Update-WatermarkToggleButton {
    if ($null -eq $script:Form) {
        return
    }
    Ensure-WatermarkToggleButton
    Ensure-HelpButton
    if ($null -eq $script:WatermarkToggleButton -or $script:WatermarkToggleButton.IsDisposed) {
        return
    }

    $script:WatermarkToggleButton.Location = New-Object System.Drawing.Point -ArgumentList @([int][Math]::Max(0, ([int]$script:Form.ClientSize.Width - 30)), 4)
    if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed) {
        $script:HelpButton.Location = New-Object System.Drawing.Point -ArgumentList @([int][Math]::Max(0, ([int]$script:Form.ClientSize.Width - 56)), 4)
        $script:HelpButton.BringToFront()
    }
    $script:WatermarkToggleButton.BringToFront()

    if ($script:WatermarkMode) {
        $script:WatermarkToggleButton.Text = [string][char]0x25B3
        $script:WatermarkToggleButton.FlatAppearance.BorderSize = 1
        $script:WatermarkToggleButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
        $script:WatermarkToggleButton.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $script:WatermarkToggleButton.Visible = $true
        if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed) {
            $script:HelpButton.Visible = $false
        }
        return
    }

    $bounds = $script:Form.RectangleToScreen($script:Form.ClientRectangle)
    $cursor = [System.Windows.Forms.Cursor]::Position
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $insideTopRight = (
        $bounds.Contains($cursor) -and
        $cursor.Y -le ($bounds.Top + [Math]::Max(18, $rowHeight)) -and
        $cursor.X -ge ($bounds.Right - 68)
    )
    $script:WatermarkToggleButton.Text = "~"
    $script:WatermarkToggleButton.FlatAppearance.BorderSize = 0
    $script:WatermarkToggleButton.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    if ($insideTopRight) {
        $script:WatermarkToggleButton.Visible = $true
        $script:WatermarkToggleButton.BringToFront()
        if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed) {
            $script:HelpButton.Visible = $true
            $script:HelpButton.BringToFront()
        }
    }
    else {
        $script:WatermarkToggleButton.Visible = $false
        if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed) {
            $script:HelpButton.Visible = $false
        }
    }
}

function Set-UiTimerInterval([int]$Milliseconds) {
    if ($null -eq $script:UiTimer) {
        return
    }
    if ($Milliseconds -lt 50) {
        $Milliseconds = 50
    }
    if ($script:UiTimer.Interval -ne $Milliseconds) {
        $script:UiTimer.Interval = $Milliseconds
    }
}

function Test-WatermarkTogglePoint([System.Drawing.Point]$ScreenPoint) {
    if ($null -eq $script:Form) {
        return $false
    }
    $bounds = $script:Form.RectangleToScreen($script:Form.ClientRectangle)
    if (-not $bounds.Contains($ScreenPoint)) {
        return $false
    }
    $exitSize = 32
    return ($ScreenPoint.X -ge ($bounds.Right - $exitSize) -and $ScreenPoint.Y -le ($bounds.Top + $exitSize))
}

function Update-WatermarkClickThrough {
    if ($null -eq $script:Form) {
        return
    }
    if (-not $script:WatermarkMode) {
        if ($script:Form.ClickThroughEnabled) {
            $script:Form.SetClickThrough($false)
        }
        return
    }
    if ($script:WatermarkToggleDragActive) {
        $script:Form.SetClickThrough($false)
        return
    }

    $insideToggle = Test-WatermarkTogglePoint ([System.Windows.Forms.Cursor]::Position)
    $script:Form.SetClickThrough(-not $insideToggle)
}

function Toggle-WatermarkMode {
    if ($script:WatermarkMode) {
        Exit-WatermarkMode
    }
    else {
        Enter-WatermarkMode
    }
}

function Update-BottomChromeVisibility {
    if ($null -eq $script:Form -or $null -eq $script:NavRowStyle) {
        return
    }
    Update-WatermarkToggleButton
    if ($script:WatermarkMode) {
        Set-BottomChromeVisible $false
        return
    }

    $bounds = $script:Form.RectangleToScreen($script:Form.ClientRectangle)
    $cursor = [System.Windows.Forms.Cursor]::Position
    $inside = $bounds.Contains($cursor)
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $revealPixels = [Math]::Max(8, [int][Math]::Ceiling($rowHeight / 3.0))
    $keepPixels = [Math]::Max(54, ($rowHeight + 36))
    if ($script:BottomChromeSuppressed) {
        if (-not $inside -or $cursor.Y -lt ($bounds.Bottom - $keepPixels)) {
            $script:BottomChromeSuppressed = $false
        }
        else {
            Set-BottomChromeVisible $false
            return
        }
    }

    $bottomPixels = $revealPixels
    if ($script:BottomChromeVisible) {
        $bottomPixels = $keepPixels
    }
    $nearBottom = ($inside -and $cursor.Y -ge ($bounds.Bottom - $bottomPixels))
    $inputFocused = ($null -ne $script:TaskInputBox -and $script:TaskInputBox.Focused)
    $shouldShow = ($nearBottom -or $inputFocused)

    Set-BottomChromeVisible $shouldShow
}

function Resize-WindowForTaskRows([int]$Rows) {
    if ($null -eq $script:Form) {
        return
    }
    if ($Rows -lt 1) {
        $Rows = 1
    }
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    Set-BottomChromeVisible $false
    $script:BottomChromeSuppressed = $true

    $paddingHeight = [int]$script:Form.Padding.Vertical
    if ($null -ne $script:ContentPanel) {
        $paddingHeight += [int]$script:ContentPanel.Padding.Vertical
    }
    $height = $paddingHeight + ($Rows * $rowHeight) + (Get-TaskRowsWindowSlack)
    if ($height -lt $script:Form.MinimumSize.Height) {
        $height = $script:Form.MinimumSize.Height
    }
    $script:Form.Height = $height
    Update-SizeToggleButton
}

function Enter-WatermarkMode {
    if ($null -eq $script:Form -or $script:WatermarkMode) {
        return
    }
    $script:WatermarkMode = $true
    $script:WatermarkPreviousOpacity = [double]$script:Form.Opacity
    $script:WatermarkPreviousTopMost = [bool]$script:Form.TopMost
    $script:Form.WatermarkMode = $true
    Set-UiTimerInterval 250
    $script:Form.WatermarkExitSize = 32
    $script:Form.TopMost = $true
    $script:Form.Opacity = 0.50
    Set-BottomChromeVisible $false
    $script:BottomChromeSuppressed = $true
    Update-WatermarkToggleButton
    Update-WatermarkClickThrough
}

function Exit-WatermarkMode {
    if ($null -eq $script:Form) {
        return
    }
    $script:WatermarkMode = $false
    $script:Form.WatermarkMode = $false
    $script:BottomChromeSuppressed = $false
    Set-UiTimerInterval 1000
    if ($null -ne $script:WatermarkPreviousOpacity) {
        $script:Form.Opacity = [double]$script:WatermarkPreviousOpacity
    }
    else {
        $script:Form.Opacity = [double]$script:Settings.Opacity
    }
    if ($null -ne $script:WatermarkPreviousTopMost) {
        $script:Form.TopMost = [bool]$script:WatermarkPreviousTopMost
    }
    else {
        $script:Form.TopMost = [bool]$script:Settings.TopMost
    }
    $script:Form.SetClickThrough($false)
    $script:WatermarkPreviousOpacity = $null
    $script:WatermarkPreviousTopMost = $null
    Update-WatermarkToggleButton
    Update-BottomChromeVisibility
}

function Test-WatermarkExitPoint([System.Drawing.Point]$Point) {
    if ($null -eq $script:Form) {
        return $false
    }
    return ($Point.X -ge ($script:Form.ClientSize.Width - 28) -and $Point.Y -le 28)
}

function Add-BottomChromeTracking([System.Windows.Forms.Control]$Control) {
    $Control.Add_MouseMove({
        Update-WatermarkToggleButton
        Update-BottomChromeVisibility
    })
    $Control.Add_MouseEnter({
        Update-WatermarkToggleButton
        Update-BottomChromeVisibility
    })
}

function Timer-Tick {
    Update-DateLabel
    $archivedCount = Invoke-DailyArchiveIfDue
    if ($archivedCount -gt 0) {
        Set-Status (T "DailyArchivedTasks")
        Render-CurrentView
    }
    Update-WatermarkClickThrough
    Update-BottomChromeVisibility
    Update-SizeToggleButton
    if ($script:TimerState -eq "running") {
        $remaining = [int][Math]::Ceiling(($script:PomodoroEndAt - (Get-Date)).TotalSeconds)
        if ($remaining -le 0) {
            $script:SecondsRemaining = 0
            Invoke-AppActionResult (Complete-Pomodoro)
        }
        else {
            $script:SecondsRemaining = $remaining
            Update-TimerLabels
        }
    }
}

function Start-WindowDrag {
    $script:WindowDragStart = [System.Windows.Forms.Cursor]::Position
    $script:WindowDragOrigin = $script:Form.Location
}

function Move-WindowDrag {
    if ($null -eq $script:WindowDragStart -or $null -eq $script:WindowDragOrigin) {
        return
    }
    $current = [System.Windows.Forms.Cursor]::Position
    $newX = [int]([int]$script:WindowDragOrigin.X + [int]$current.X - [int]$script:WindowDragStart.X)
    $newY = [int]([int]$script:WindowDragOrigin.Y + [int]$current.Y - [int]$script:WindowDragStart.Y)
    $script:Form.Location = New-Object System.Drawing.Point -ArgumentList @($newX, $newY)
}

function Stop-WindowDrag {
    $script:WindowDragStart = $null
    $script:WindowDragOrigin = $null
}

function Test-TaskTopDragBand([int]$Y) {
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    return ($Y -ge 0 -and $Y -le [Math]::Max(6, [int][Math]::Ceiling($rowHeight / 3.0)))
}

function Add-WindowDrag([System.Windows.Forms.Control]$Control) {
    $Control.Add_MouseDown({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Start-WindowDrag
        }
    })
    $Control.Add_MouseMove({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Move-WindowDrag
        }
    })
    $Control.Add_MouseUp({
        Stop-WindowDrag
    })
}

