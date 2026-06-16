# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

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

function Get-WatermarkModeOpacity { return 0.50 }

function Enter-WatermarkMode {
    if ($null -eq $script:Form -or $script:WatermarkMode) {
        return
    }
    $script:WatermarkMode = $true
    $script:WatermarkPreviousOpacity = [double]$script:Form.Opacity
    $script:WatermarkPreviousTopMost = [bool]$script:Form.TopMost
    $script:Form.WatermarkMode = $true
    $script:Form.Opacity = Get-WatermarkModeOpacity
    Set-UiTimerInterval 250
    $script:Form.WatermarkExitSize = 32
    $script:Form.TopMost = $true
    Set-BottomChromeVisible $false
    $script:BottomChromeSuppressed = $true
    Apply-WatermarkGhostSurface
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
    Restore-WatermarkGhostSurface
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
