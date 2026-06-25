# This file is dot-sourced before Views.Done.ps1. It owns execution-record list drawing.

function Enable-ExecutionRecordDrawing([System.Windows.Forms.ListBox]$List) {
    $List.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
    $List.ItemHeight = [Math]::Max(22, ($List.Font.Height + 6))
    $List.Add_DrawItem({
        param($sender, $eventArgs)
        Draw-ExecutionRecordItem ([System.Windows.Forms.ListBox]$sender) $eventArgs
    })
}

function Draw-ExecutionRecordItem([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.DrawItemEventArgs]$EventArgs) {
    if ($null -eq $List -or $EventArgs.Index -lt 0 -or $EventArgs.Index -ge $List.Items.Count) { return }

    $item = $List.Items[$EventArgs.Index]
    $isHeader = ($null -ne $item -and ($item.PSObject.Properties.Name -contains "IsHeader") -and [bool]$item.IsHeader)
    $isHistory = ($null -ne $item -and ($item.PSObject.Properties.Name -contains "IsHistory") -and [bool]$item.IsHistory)
    $selected = (($EventArgs.State -band [System.Windows.Forms.DrawItemState]::Selected) -eq [System.Windows.Forms.DrawItemState]::Selected)

    $EventArgs.DrawBackground()
    $textColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    if ($isHeader) { $textColor = [System.Drawing.Color]::FromArgb(107, 114, 128) }
    elseif ($isHistory) { $textColor = [System.Drawing.Color]::DimGray }
    if ($selected) { $textColor = [System.Drawing.SystemColors]::HighlightText }

    $fontStyle = [System.Drawing.FontStyle]::Regular
    if ($isHeader) { $fontStyle = [System.Drawing.FontStyle]::Bold }
    elseif ($isHistory) { $fontStyle = [System.Drawing.FontStyle]::Strikeout }

    $textFont = $null
    try {
        $textFont = New-Object System.Drawing.Font($List.Font, $fontStyle)
        $textRect = New-Object System.Drawing.Rectangle -ArgumentList @(
            ([int]$EventArgs.Bounds.X + 4),
            [int]$EventArgs.Bounds.Y,
            ([int]$EventArgs.Bounds.Width - 8),
            [int]$EventArgs.Bounds.Height
        )
        $flags = [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
            [System.Windows.Forms.TextFormatFlags]::SingleLine -bor
            [System.Windows.Forms.TextFormatFlags]::EndEllipsis -bor
            [System.Windows.Forms.TextFormatFlags]::NoPrefix
        [System.Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics, [string]$item.Display, $textFont, $textRect, $textColor, $flags)
    }
    finally {
        if ($null -ne $textFont) { $textFont.Dispose() }
    }
    $EventArgs.DrawFocusRectangle()
}
