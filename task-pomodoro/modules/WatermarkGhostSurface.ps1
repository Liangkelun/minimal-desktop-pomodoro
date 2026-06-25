# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-WatermarkTransparentColor { return [System.Drawing.Color]::FromArgb(250, 251, 253) }


function Get-WatermarkGhostItems {
    $tasks = if ($script:ActiveView -eq "tasks") { Get-OpenTasks } else { Get-TodayTasks }
    $items = New-Object System.Collections.ArrayList
    $index = 1
    foreach ($task in @($tasks)) {
        $items.Add([pscustomobject]@{ Display = Format-TaskLine $task $index; TaskId = [string]$task.id; IsTask = $true; Completed = (Test-TaskIsCompleted $task) }) | Out-Null
        $index++
    }
    if ($items.Count -eq 0) {
        $items.Add([pscustomobject]@{ Display = (T $(if ($script:ActiveView -eq "tasks") { "NoOpenTasks" } else { "NoTodayTasks" })); TaskId = ""; IsTask = $false; Completed = $false }) | Out-Null
    }
    return [object[]]$items.ToArray()
}

function Draw-WatermarkGhostText([System.Drawing.Graphics]$Graphics, [string]$Text, [System.Drawing.Font]$Font, [System.Drawing.Rectangle]$Rect, [System.Windows.Forms.TextFormatFlags]$Flags) {
    if ([string]::IsNullOrEmpty($Text) -or [int]$Rect.Width -le 0 -or [int]$Rect.Height -le 0) { return }
    $mainColor = [System.Drawing.Color]::FromArgb(31, 41, 55); $shadowColor = [System.Drawing.Color]::White
    if ([string]$script:Settings.BlurTextStyle -eq "light") {
        foreach ($offset in @(@(-1,0), @(1,0), @(0,-1), @(0,1))) { $outlineRect = New-Object System.Drawing.Rectangle -ArgumentList @(([int]$Rect.X + [int]$offset[0]), ([int]$Rect.Y + [int]$offset[1]), [int]$Rect.Width, [int]$Rect.Height); [System.Windows.Forms.TextRenderer]::DrawText($Graphics, $Text, $Font, $outlineRect, [System.Drawing.Color]::Black, $Flags) }
        [System.Windows.Forms.TextRenderer]::DrawText($Graphics, $Text, $Font, $Rect, [System.Drawing.Color]::White, $Flags)
        return
    }
    $backRect = New-Object System.Drawing.Rectangle -ArgumentList @(([int]$Rect.X + 1), ([int]$Rect.Y + 1), [int]$Rect.Width, [int]$Rect.Height)
    [System.Windows.Forms.TextRenderer]::DrawText($Graphics, $Text, $Font, $backRect, $shadowColor, $Flags)
    [System.Windows.Forms.TextRenderer]::DrawText($Graphics, $Text, $Font, $Rect, $mainColor, $Flags)
}

function Draw-WatermarkGhostSurface([System.Windows.Forms.Panel]$Panel, [System.Windows.Forms.PaintEventArgs]$EventArgs) {
    $transparentColor = Get-WatermarkTransparentColor
    $EventArgs.Graphics.Clear($transparentColor)
    $flags = [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::EndEllipsis -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $y = [int]$Panel.Padding.Top
    $rowHeight = [Math]::Max(22, [int]$Panel.Tag.RowHeight)
    $visibleBottom = [int]$Panel.ClientSize.Height - [int]$Panel.Padding.Bottom
    $watermarkButtonReserve = 34
    foreach ($item in @($Panel.Tag.Items)) {
        if (($y + $rowHeight) -gt $visibleBottom) { break }
        $textRect = New-Object System.Drawing.Rectangle -ArgumentList @(([int]$Panel.Padding.Left + 4), $y, [Math]::Max(10, ([int]$Panel.ClientSize.Width - [int]$Panel.Padding.Horizontal - 8 - $watermarkButtonReserve)), $rowHeight)
        $displayText = [string]$item.Display
        $prefixMatch = [regex]::Match($displayText, '^\d+\.\s+')
        if ([bool]$item.IsTask -and $prefixMatch.Success) {
            $prefixSize = [System.Windows.Forms.TextRenderer]::MeasureText($prefixMatch.Value, $Panel.Font, (New-Object System.Drawing.Size -ArgumentList @(120, $textRect.Height)), [System.Windows.Forms.TextFormatFlags]::NoPadding)
            $prefixWidth = [Math]::Max(18, [int]$prefixSize.Width)
            $prefixRect = New-Object System.Drawing.Rectangle -ArgumentList @($textRect.X, $textRect.Y, $prefixWidth, $textRect.Height)
            if ([bool]$item.Completed) {
                $checkFlags = [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
                Draw-WatermarkGhostText $EventArgs.Graphics ([string][char]0x2713) $Panel.Font $prefixRect $checkFlags
            }
            else {
                Draw-WatermarkGhostText $EventArgs.Graphics $prefixMatch.Value $Panel.Font $prefixRect $flags
            }
            $textRect.X += $prefixWidth
            $textRect.Width = [Math]::Max(0, ($textRect.Width - $prefixWidth))
            $displayText = $displayText.Substring($prefixMatch.Value.Length)
        }
        $fontStyle = [System.Drawing.FontStyle]::Regular
        if ([bool]$item.Completed) { $fontStyle = [System.Drawing.FontStyle]::Strikeout }
        $textFont = New-Object System.Drawing.Font($Panel.Font, $fontStyle)
        $timerFont = $null
        $timerBrush = $null
        try {
            Draw-WatermarkGhostText $EventArgs.Graphics $displayText $textFont $textRect $flags
            $inlineText = ""
            if ([bool]$item.IsTask -and [string]$script:ActiveView -eq "today" -and -not [string]::IsNullOrWhiteSpace([string]$item.TaskId)) {
                $inlineText = Get-TaskInlineCountdownText ([string]$item.TaskId)
            }
            if (-not [string]::IsNullOrWhiteSpace($inlineText)) {
                $timerFont = New-Object System.Drawing.Font($Panel.Font, [System.Drawing.FontStyle]::Bold)
                $timerSize = [System.Windows.Forms.TextRenderer]::MeasureText($inlineText, $timerFont)
                $timerWidth = [Math]::Max(54, [int]$timerSize.Width + 12)
                if ($textRect.Width -gt ($timerWidth + 20)) {
                    $timerRect = New-Object System.Drawing.Rectangle -ArgumentList @(($textRect.Right - $timerWidth), $textRect.Y, $timerWidth, $textRect.Height)
                    $timerBrush = New-Object System.Drawing.SolidBrush($transparentColor)
                    $EventArgs.Graphics.FillRectangle($timerBrush, $timerRect)
                    $timerFlags = $flags -bor [System.Windows.Forms.TextFormatFlags]::HorizontalCenter
                    Draw-WatermarkGhostText $EventArgs.Graphics $inlineText $timerFont $timerRect $timerFlags
                }
            }
        }
        finally {
            $textFont.Dispose()
            if ($null -ne $timerFont) { $timerFont.Dispose() }
            if ($null -ne $timerBrush) { $timerBrush.Dispose() }
        }
        $y += $rowHeight
    }
}

function Get-WatermarkGhostMetrics {
    $rowHeight = 22
    if ($null -ne $script:TaskListBox -and -not $script:TaskListBox.IsDisposed) {
        return [pscustomobject]@{ Font = (New-Object System.Drawing.Font($script:TaskListBox.Font, [System.Drawing.FontStyle]::Regular)); RowHeight = [Math]::Max(22, [int]$script:TaskListBox.ItemHeight); Items = (Get-WatermarkGhostItems) }
    }
    $font = New-Object System.Drawing.Font($script:Form.Font.FontFamily, [float]$script:Settings.TaskFontSize, [System.Drawing.FontStyle]::Regular)
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 2) { $rowHeight = [Math]::Max(22, ([int]$script:TaskRowHeight - 2)) }
    return [pscustomobject]@{ Font = $font; RowHeight = $rowHeight; Items = (Get-WatermarkGhostItems) }
}
function Apply-WatermarkGhostSurface {
    if ($null -eq $script:Form) { return }
    $transparentColor = Get-WatermarkTransparentColor
    $script:WatermarkPreviousBackColor = $script:Form.BackColor
    $script:WatermarkPreviousTransparencyKey = $script:Form.TransparencyKey
    $script:Form.BackColor = $transparentColor
    $script:Form.TransparencyKey = $transparentColor
    if ($null -ne $script:MainPanel) { $script:MainPanel.Visible = $false }

    $metrics = Get-WatermarkGhostMetrics
    $panel = New-Object System.Windows.Forms.Panel
    $contentBounds = Get-WatermarkPreviousContentBounds
    if ($null -ne $contentBounds) { $panel.Bounds = $contentBounds } else { $panel.Dock = [System.Windows.Forms.DockStyle]::Fill }
    $panel.BackColor = $transparentColor
    $panel.Padding = New-Object System.Windows.Forms.Padding(0)
    $panel.Font = $metrics.Font
    $panel.Tag = $metrics
    $panel.Add_Paint({ param($sender, $eventArgs) Draw-WatermarkGhostSurface ([System.Windows.Forms.Panel]$sender) $eventArgs })
    $script:WatermarkGhostPanel = $panel
    $script:Form.Controls.Add($panel)
    $panel.BringToFront()
}

function Restore-WatermarkGhostSurface {
    if ($null -ne $script:WatermarkGhostPanel -and -not $script:WatermarkGhostPanel.IsDisposed) { $script:WatermarkGhostPanel.Dispose() }
    $script:WatermarkGhostPanel = $null
    if ($null -ne $script:WatermarkPreviousBackColor) { $script:Form.BackColor = $script:WatermarkPreviousBackColor }
    if ($null -ne $script:WatermarkPreviousTransparencyKey) { $script:Form.TransparencyKey = $script:WatermarkPreviousTransparencyKey } else { $script:Form.TransparencyKey = [System.Drawing.Color]::Empty }
    if ($null -ne $script:MainPanel) { $script:MainPanel.Visible = $true }
    $script:WatermarkPreviousBackColor = $null
    $script:WatermarkPreviousTransparencyKey = $null
}
