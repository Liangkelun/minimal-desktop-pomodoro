# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function ConvertTo-TaskPreviewText([string]$Text, [int]$MaxChars) {
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    if ($MaxChars -lt 12) {
        $MaxChars = 12
    }

    $lines = New-Object System.Collections.ArrayList
    foreach ($rawLine in ($Text.Trim() -split "`r?`n")) {
        $line = $rawLine.Trim()
        while ($line.Length -gt $MaxChars) {
            $lines.Add($line.Substring(0, $MaxChars)) | Out-Null
            $line = $line.Substring($MaxChars)
        }
        if ($line.Length -gt 0) {
            $lines.Add($line) | Out-Null
        }
    }
    return ([string[]]$lines.ToArray()) -join "`n"
}

function Show-TaskTitlePreview([System.Windows.Forms.ListBox]$List, [object]$Item, [int]$ClickX, [int]$ClickY) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $Item -or [string]::IsNullOrWhiteSpace([string]$Item.Id)) {
        return
    }

    $task = Get-TaskById ([string]$Item.Id)
    if ($null -eq $task) {
        return
    }

    $text = ConvertTo-TaskPreviewText ([string]$task.title) 34
    if ([string]::IsNullOrWhiteSpace($text)) {
        return
    }

    Hide-TaskTitlePreview
    if ($null -eq $script:ContentPanel -or $script:ContentPanel.IsDisposed) {
        return
    }

    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $panel.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $false
    $label.Text = $text
    $label.Font = $List.Font
    $label.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $label.BackColor = $panel.BackColor
    $listWidth = [int]$List.ClientSize.Width
    if ($listWidth -le 0) {
        $listWidth = [int]$List.Width
    }
    $labelWidth = [int][Math]::Min([Math]::Max(190, ($listWidth - 28)), 360)
    $measureBounds = New-Object System.Drawing.Size -ArgumentList @($labelWidth, 1000)
    $measureFlags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPadding
    $measured = [System.Windows.Forms.TextRenderer]::MeasureText($text, $List.Font, $measureBounds, $measureFlags)
    $heightCap = 220
    if ($null -ne $script:ContentPanel -and [int]$script:ContentPanel.ClientSize.Height -gt 0) {
        $heightCap = [Math]::Max(40, [int]$script:ContentPanel.ClientSize.Height - 12)
    }
    $labelHeight = [int][Math]::Min($heightCap, [Math]::Max(24, ([int]$measured.Height + 8)))
    $label.Width = $labelWidth
    $label.Height = $labelHeight
    $panel.Width = [int]($labelWidth + [int]$panel.Padding.Horizontal)
    $panel.Height = [int]($labelHeight + [int]$panel.Padding.Vertical)
    $label.Location = New-Object System.Drawing.Point -ArgumentList @([int]$panel.Padding.Left, [int]$panel.Padding.Top)
    $panel.Controls.Add($label)

    $previewX = [int]($ClickX + 10)
    $previewY = [int]($ClickY + [int]$List.ItemHeight)
    $screenPoint = $List.PointToScreen((New-Object System.Drawing.Point -ArgumentList @($previewX, $previewY)))
    $localPoint = $script:ContentPanel.PointToClient($screenPoint)
    $maxX = [int][Math]::Max(4, ([int]$script:ContentPanel.ClientSize.Width - [int]$panel.Width - 4))
    $maxY = [int][Math]::Max(4, ([int]$script:ContentPanel.ClientSize.Height - [int]$panel.Height - 4))
    $x = [int][Math]::Max(4, [Math]::Min([int]$localPoint.X, $maxX))
    $y = [int][Math]::Max(4, [Math]::Min([int]$localPoint.Y, $maxY))
    $panel.Location = New-Object System.Drawing.Point -ArgumentList @($x, $y)

    $script:TaskPreviewPanel = $panel
    $script:ContentPanel.Controls.Add($panel)
    $panel.BringToFront()
}

function Hide-TaskTitlePreview {
    if ($null -ne $script:TaskPreviewPanel -and -not $script:TaskPreviewPanel.IsDisposed) {
        $script:TaskPreviewPanel.Dispose()
    }
    $script:TaskPreviewPanel = $null
}

function Open-TaskLinkTarget([string]$Target) {
    $target = Resolve-TaskLinkTarget $Target
    if ([string]::IsNullOrWhiteSpace([string]$target.OpenTarget)) {
        Write-TaskLinkDebug "OpenTargetBlank" "" $Target $null
        [System.Windows.Forms.MessageBox]::Show((T "NoTaskLink"), (T "AppTitle")) | Out-Null
        return
    }
    if ($target.IsPath -and -not $target.Exists) {
        Write-TaskLinkDebug "OpenTargetMissing" "" ([string]$target.OpenTarget) $null
        [System.Windows.Forms.MessageBox]::Show(((T "NoTaskLink") + "`r`n" + [string]$target.OpenTarget), (T "OpenTaskLink")) | Out-Null
        return
    }

    try {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = [string]$target.OpenTarget
        $info.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($info) | Out-Null
    }
    catch {
        if ($target.IsPath -and $target.Exists) {
            try {
                if (Test-Path -LiteralPath ([string]$target.OpenTarget) -PathType Container) {
                    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$([string]$target.OpenTarget)`"" | Out-Null
                }
                else {
                    Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$([string]$target.OpenTarget)`"" | Out-Null
                }
                return
            }
            catch {}
        }
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T "OpenTaskLink")) | Out-Null
    }
}

function Open-TaskLink([string]$Id) {
    $task = Get-TaskById $Id
    $target = Get-FirstTaskLink $task
    if ([string]::IsNullOrWhiteSpace($target) -and -not [string]::IsNullOrWhiteSpace($Id)) {
        try {
            if (-not [string]::IsNullOrWhiteSpace([string]$script:TasksFile) -and (Test-Path -LiteralPath $script:TasksFile)) {
                Load-Tasks
                $task = Get-TaskById $Id
                $target = Get-FirstTaskLink $task
            }
        }
        catch {}
    }
    if ([string]::IsNullOrWhiteSpace($target)) {
        Write-TaskLinkDebug "OpenTaskLinkBlank" $Id $target $task
        [System.Windows.Forms.MessageBox]::Show((T "NoTaskLink"), (T "AppTitle")) | Out-Null
        return
    }
    Open-TaskLinkTarget $target
}

function New-TaskDetailTextBox([bool]$Multiline) {
    $box = New-Object System.Windows.Forms.TextBox
    $box.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $box.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255); $box.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55); $box.Multiline = $Multiline
    if ($Multiline) {
        $box.AcceptsReturn = $true
        $box.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    }
    return $box
}

function New-TaskLinksTextBox {
    $box = New-TaskDetailTextBox $true
    $box.WordWrap = $false; $box.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    return $box
}

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

