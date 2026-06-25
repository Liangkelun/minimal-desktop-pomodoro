# This file is dot-sourced before WatermarkMode.ps1. Keep the ~ button chrome and gestures separate from watermark layout lifecycle.

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
            Set-WindowChromeClickThrough $false
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
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            Show-WatermarkMenu $sender
            return
        }
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
    if ($null -eq $script:Form) { return }
    Ensure-WatermarkToggleButton
    Ensure-HelpButton
    if ($null -eq $script:WatermarkToggleButton -or $script:WatermarkToggleButton.IsDisposed) { return }

    $targetLocation = New-Object System.Drawing.Point -ArgumentList @([int][Math]::Max(0, ([int]$script:Form.ClientSize.Width - 30)), 4)
    if (-not $script:WatermarkToggleButton.Location.Equals($targetLocation)) { $script:WatermarkToggleButton.Location = $targetLocation }
    if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed) {
        $helpLocation = New-Object System.Drawing.Point -ArgumentList @([int][Math]::Max(0, ([int]$script:Form.ClientSize.Width - 56)), 4)
        if (-not $script:HelpButton.Location.Equals($helpLocation)) { $script:HelpButton.Location = $helpLocation }
    }

    if ($script:WatermarkMode) {
        $triangle = [string][char]0x25B3
        $borderColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
        $backColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        if ($script:WatermarkToggleButton.Text -ne $triangle) { $script:WatermarkToggleButton.Text = $triangle }
        if ($script:WatermarkToggleButton.FlatAppearance.BorderSize -ne 1) { $script:WatermarkToggleButton.FlatAppearance.BorderSize = 1 }
        if ($script:WatermarkToggleButton.FlatAppearance.BorderColor.ToArgb() -ne $borderColor.ToArgb()) { $script:WatermarkToggleButton.FlatAppearance.BorderColor = $borderColor }
        if ($script:WatermarkToggleButton.BackColor.ToArgb() -ne $backColor.ToArgb()) { $script:WatermarkToggleButton.BackColor = $backColor }
        if (-not $script:WatermarkToggleButton.Visible) { $script:WatermarkToggleButton.Visible = $true }
        $script:WatermarkToggleButton.BringToFront()
        if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed -and $script:HelpButton.Visible) { $script:HelpButton.Visible = $false }
        return
    }

    $bounds = $script:Form.RectangleToScreen($script:Form.ClientRectangle)
    $cursor = [System.Windows.Forms.Cursor]::Position
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) { $rowHeight = [int]$script:TaskRowHeight }
    $insideTopRight = ($bounds.Contains($cursor) -and $cursor.Y -le ($bounds.Top + [Math]::Max(18, $rowHeight)) -and $cursor.X -ge ($bounds.Right - 68))
    if ($script:WatermarkToggleButton.Text -ne "~") { $script:WatermarkToggleButton.Text = "~" }
    if ($script:WatermarkToggleButton.FlatAppearance.BorderSize -ne 0) { $script:WatermarkToggleButton.FlatAppearance.BorderSize = 0 }
    $normalBack = [System.Drawing.Color]::FromArgb(250, 251, 253)
    if ($script:WatermarkToggleButton.BackColor.ToArgb() -ne $normalBack.ToArgb()) { $script:WatermarkToggleButton.BackColor = $normalBack }
    if ($insideTopRight) {
        if (-not $script:WatermarkToggleButton.Visible) { $script:WatermarkToggleButton.Visible = $true }
        $script:WatermarkToggleButton.BringToFront()
        if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed -and -not $script:HelpButton.Visible) { $script:HelpButton.Visible = $true; $script:HelpButton.BringToFront() }
    }
    else {
        if ($script:WatermarkToggleButton.Visible) { $script:WatermarkToggleButton.Visible = $false }
        if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed -and $script:HelpButton.Visible) { $script:HelpButton.Visible = $false }
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

function Test-WatermarkToggleDragActive {
    return [bool]$script:WatermarkToggleDragActive
}