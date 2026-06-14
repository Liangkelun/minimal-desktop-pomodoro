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

        if ($showCheckbox) {
            $checkText = [string][char]0x25CB
            $checkColor = $textColor
            if ($isCompleted) {
                $checkText = [string][char]0x2713
                if (-not $selected) {
                    $checkColor = [System.Drawing.Color]::FromArgb(24, 96, 56)
                }
            }
            $checkFont = New-Object System.Drawing.Font($List.Font, [System.Drawing.FontStyle]::Regular)
            $checkRect = New-Object System.Drawing.Rectangle -ArgumentList @($textRect.X, $textRect.Y, 22, $textRect.Height)
            [System.Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics, $checkText, $checkFont, $checkRect, $checkColor, $textFlags)
            $textRect.X += 22
            $textRect.Width = [Math]::Max(0, ($textRect.Width - 22))
        }

        $fontStyle = [System.Drawing.FontStyle]::Regular
        if ($isCompleted) {
            $fontStyle = [System.Drawing.FontStyle]::Strikeout
        }
        $textFont = New-Object System.Drawing.Font($List.Font, $fontStyle)
        [System.Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics, [string]$item.Display, $textFont, $textRect, $textColor, $textFlags)
    }
    finally {
        if ($null -ne $textFont) { $textFont.Dispose() }
        if ($null -ne $checkFont) { $checkFont.Dispose() }
    }
    $EventArgs.DrawFocusRectangle()
}
