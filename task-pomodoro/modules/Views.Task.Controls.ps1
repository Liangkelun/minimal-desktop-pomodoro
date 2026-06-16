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

function Open-TaskLinkTarget([object]$Target, [string]$TaskId = "", [object]$Task = $null) {
    $target = Resolve-TaskLinkTarget $Target
    if ([string]::IsNullOrWhiteSpace([string]$target.OpenTarget)) {
        Write-TaskLinkDebug "OpenTargetBlank" $TaskId $Target $Task
        [System.Windows.Forms.MessageBox]::Show((T "NoTaskLink"), (T "AppTitle")) | Out-Null
        return
    }
    if ($target.IsPath -and -not $target.Exists) {
        Write-TaskLinkDebug "OpenTargetMissing" $TaskId ([string]$target.OpenTarget) $Task
        [System.Windows.Forms.MessageBox]::Show(((T "NoTaskLink") + "`r`n" + [string]$target.OpenTarget), (T "OpenTaskLink")) | Out-Null
        return
    }

    $openTarget = [string]$target.OpenTarget
    try {
        if ($target.IsPath) {
            Start-Process -FilePath $openTarget | Out-Null
            Write-TaskLinkDebug "OpenTargetStartProcessPath" $TaskId $openTarget $Task
        }
        else {
            $info = New-Object System.Diagnostics.ProcessStartInfo
            $info.FileName = $openTarget
            $info.UseShellExecute = $true
            [System.Diagnostics.Process]::Start($info) | Out-Null
            Write-TaskLinkDebug "OpenTargetShellExecute" $TaskId $openTarget $Task
        }
    }
    catch {
        Write-TaskLinkDebug "OpenTargetStartFailed" $TaskId ($openTarget + " error=" + $_.Exception.Message) $Task
        if ($target.IsPath -and $target.Exists) {
            try {
                if (Test-Path -LiteralPath $openTarget -PathType Container) {
                    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$openTarget`"" | Out-Null
                }
                else {
                    Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$openTarget`"" | Out-Null
                }
                Write-TaskLinkDebug "OpenTargetExplorerFallback" $TaskId $openTarget $Task
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
            $tasksFile = Get-AppPath "TasksFile"
            if (-not [string]::IsNullOrWhiteSpace($tasksFile) -and (Test-Path -LiteralPath $tasksFile)) {
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
    Open-TaskLinkTarget $target $Id $task
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
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.AllowUserToAddRows = $true
    $grid.AllowUserToDeleteRows = $true
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $grid.ColumnHeadersVisible = $false
    $grid.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnKeystrokeOrF2
    $grid.RowHeadersVisible = $true
    $grid.RowHeadersWidth = 28
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::CellSelect
    $grid.MultiSelect = $false
    $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $column.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
    $grid.Columns.Add($column) | Out-Null
    return $grid
}
