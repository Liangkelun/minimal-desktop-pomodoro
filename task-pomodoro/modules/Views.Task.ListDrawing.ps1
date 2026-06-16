# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-TaskListMode([System.Windows.Forms.ListBox]$List) {
    if ($null -ne $List -and $null -ne $List.Tag -and ($List.Tag.PSObject.Properties.Name -contains "Mode")) {
        return [string]$List.Tag.Mode
    }
    return ""
}

function Test-TaskCheckboxPoint([System.Windows.Forms.ListBox]$List, [int]$X) {
    $mode = Get-TaskListMode $List
    return ($mode -in @("tasks", "today") -and $X -ge 0 -and $X -le 24)
}

function Enable-TaskListDrawing([System.Windows.Forms.ListBox]$List) {
    $List.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
    $List.ItemHeight = [Math]::Max(22, ($List.Font.Height + 6))
    $List.Add_DrawItem({
        param($sender, $eventArgs)
        Draw-TaskListItem ([System.Windows.Forms.ListBox]$sender) $eventArgs
    })
    $List.Add_MouseMove({
        param($sender, $eventArgs)
        Update-TaskListHoverState ([System.Windows.Forms.ListBox]$sender) ([int]$eventArgs.X) ([int]$eventArgs.Y)
    })
    $List.Add_MouseLeave({
        param($sender, $eventArgs)
        Clear-TaskListHoverState ([System.Windows.Forms.ListBox]$sender)
    })
}

function Draw-TaskListItem([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.DrawItemEventArgs]$EventArgs) {
    if ($null -eq $List -or $EventArgs.Index -lt 0 -or $EventArgs.Index -ge $List.Items.Count) {
        return
    }

    $item = $List.Items[$EventArgs.Index]
    $task = $null
    if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item.Id)) {
        $task = Get-TaskById ([string]$item.Id)
    }
    $isCompleted = Test-TaskIsCompleted $task
    $showCheckbox = ((Get-TaskListMode $List) -in @("tasks", "today") -and $null -ne $task)
    $hoverIndex = [int](Get-TaskListTagValue $List "HoverIndex" -1)
    $hoverCheckbox = [bool](Get-TaskListTagValue $List "HoverCheckbox" $false)
    $hoverTopDragBand = [bool](Get-TaskListTagValue $List "HoverTopDragBand" $false)
    $isHovered = ($hoverIndex -eq $EventArgs.Index -and -not $hoverTopDragBand)

    $EventArgs.DrawBackground()
    $selected = (($EventArgs.State -band [System.Windows.Forms.DrawItemState]::Selected) -eq [System.Windows.Forms.DrawItemState]::Selected)
    $textColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    if ($isCompleted) {
        $textColor = [System.Drawing.Color]::DimGray
    }
    if ($selected) {
        $textColor = [System.Drawing.SystemColors]::HighlightText
    }

    $checkFont = $null
    $textFont = $null
    try {
        $textFlags = [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
            [System.Windows.Forms.TextFormatFlags]::SingleLine -bor
            [System.Windows.Forms.TextFormatFlags]::EndEllipsis -bor
            [System.Windows.Forms.TextFormatFlags]::NoPrefix
        $textRect = New-Object System.Drawing.Rectangle -ArgumentList @(
            ([int]$EventArgs.Bounds.X + 4),
            [int]$EventArgs.Bounds.Y,
            ([int]$EventArgs.Bounds.Width - 8),
            [int]$EventArgs.Bounds.Height
        )

        $displayText = [string]$item.Display
        $prefixMatch = [regex]::Match($displayText, '^\d+\.\s+')
        if ($showCheckbox -and $prefixMatch.Success) {
            $prefixSize = [System.Windows.Forms.TextRenderer]::MeasureText($prefixMatch.Value, $List.Font, (New-Object System.Drawing.Size -ArgumentList @(120, $textRect.Height)), [System.Windows.Forms.TextFormatFlags]::NoPadding)
            $prefixWidth = [Math]::Max(18, [int]$prefixSize.Width)
            $prefixRect = New-Object System.Drawing.Rectangle -ArgumentList @($textRect.X, $textRect.Y, $prefixWidth, $textRect.Height)
            if ($isCompleted -or $isHovered) {
                $checkText = [string][char]0x25CB
                $checkColor = [System.Drawing.Color]::FromArgb(107, 114, 128)
                if ($selected) {
                    $checkColor = $textColor
                }
                elseif ($hoverCheckbox) {
                    $checkColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
                }
                if ($isCompleted) {
                    $checkText = [string][char]0x2713
                    if (-not $selected) {
                        $checkColor = [System.Drawing.Color]::FromArgb(24, 96, 56)
                    }
                }
                $checkFont = New-Object System.Drawing.Font($List.Font, [System.Drawing.FontStyle]::Regular)
                $checkFlags = [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
                [System.Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics, $checkText, $checkFont, $prefixRect, $checkColor, $checkFlags)
            }
            else {
                [System.Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics, $prefixMatch.Value, $List.Font, $prefixRect, $textColor, $textFlags)
            }
            $textRect.X += $prefixWidth
            $textRect.Width = [Math]::Max(0, ($textRect.Width - $prefixWidth))
            $displayText = $displayText.Substring($prefixMatch.Value.Length)
        }

        $fontStyle = [System.Drawing.FontStyle]::Regular
        if ($isCompleted) {
            $fontStyle = [System.Drawing.FontStyle]::Strikeout
        }
        $textFont = New-Object System.Drawing.Font($List.Font, $fontStyle)
        [System.Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics, $displayText, $textFont, $textRect, $textColor, $textFlags)
    }
    finally {
        if ($null -ne $textFont) { $textFont.Dispose() }
        if ($null -ne $checkFont) { $checkFont.Dispose() }
    }
    $EventArgs.DrawFocusRectangle()
}
