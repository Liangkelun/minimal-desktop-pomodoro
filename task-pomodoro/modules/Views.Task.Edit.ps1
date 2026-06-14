# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Complete-TaskTitleInlineEdit([System.Windows.Forms.TextBox]$Box, [bool]$Cancel) {
    if ($null -eq $Box -or $Box.IsDisposed -or $Box.Tag.Closed) {
        return
    }
    $state = $Box.Tag
    $state.Closed = $true
    $changed = (-not $Cancel -and -not [string]::IsNullOrWhiteSpace($Box.Text) -and $Box.Text.Trim() -ne [string]$state.Original)
    if ($changed) {
        Set-TaskTitle ([string]$state.Id) $Box.Text | Out-Null
    }
    $list = $state.List
    $Box.Dispose()
    $script:TaskTitleEditBox = $null
    if ($changed) {
        Render-CurrentView
    }
    elseif ($null -ne $list -and -not $list.IsDisposed) {
        $list.Focus()
    }
}

function Start-TaskTitleInlineEdit([System.Windows.Forms.ListBox]$List, [object]$Item, [int]$Index) {
    if ($null -eq $List -or $List.IsDisposed -or $Index -lt 0 -or [string]::IsNullOrWhiteSpace([string]$Item.Id)) {
        return
    }
    $task = Get-TaskById ([string]$Item.Id)
    if ($null -eq $task) {
        return
    }
    Hide-TaskTitlePreview
    if ($null -ne $script:TaskTitleEditBox -and -not $script:TaskTitleEditBox.IsDisposed) {
        $script:TaskTitleEditBox.Dispose()
    }

    $bounds = $List.GetItemRectangle($Index)
    $x = 4
    if ((Get-TaskListMode $List) -in @("tasks", "today")) {
        $x += 22
    }
    $displayText = [string]$Item.Display
    if ($displayText -match '^(\s*\d+\.\s*)') {
        $prefixSize = [System.Windows.Forms.TextRenderer]::MeasureText($Matches[1], $List.Font, (New-Object System.Drawing.Size -ArgumentList @(240, 100)), [System.Windows.Forms.TextFormatFlags]::NoPadding)
        $x += [int]$prefixSize.Width
    }

    $editHost = $script:ContentPanel
    if ($null -eq $editHost -or $editHost.IsDisposed) {
        return
    }
    $screenPoint = $List.PointToScreen((New-Object System.Drawing.Point -ArgumentList @([int]($bounds.X + $x), [int]($bounds.Y + 1))))
    $localPoint = $editHost.PointToClient($screenPoint)
    $width = [int][Math]::Max(80, [Math]::Min(([int]$bounds.Width - $x - 6), ([int]$editHost.ClientSize.Width - [int]$localPoint.X - 4)))
    $height = [int][Math]::Max(20, ([int]$bounds.Height - 2))

    $edit = New-Object System.Windows.Forms.TextBox
    $edit.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $edit.Font = $List.Font
    $edit.Text = [string]$task.title
    $edit.Location = $localPoint
    $edit.Size = New-Object System.Drawing.Size -ArgumentList @($width, $height)
    $edit.Tag = [pscustomobject]@{ Id = [string]$Item.Id; Original = [string]$task.title; List = $List; Closed = $false }
    $edit.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $eventArgs.SuppressKeyPress = $true
            Complete-TaskTitleInlineEdit $sender $false
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $eventArgs.SuppressKeyPress = $true
            Complete-TaskTitleInlineEdit $sender $true
        }
    })
    $edit.Add_Leave({ param($sender, $eventArgs) Complete-TaskTitleInlineEdit $sender $false })
    $script:TaskTitleEditBox = $edit
    $editHost.Controls.Add($edit)
    $edit.BringToFront()
    $edit.Focus()
    $edit.SelectAll()
}

function Start-SelectedTaskTitleInlineEdit([System.Windows.Forms.ListBox]$List) {
    if ($null -eq $List -or $List.IsDisposed -or $List.SelectedIndex -lt 0) {
        return
    }
    $item = $List.SelectedItem
    if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.Id)) {
        return
    }
    Start-TaskTitleInlineEdit $List $item $List.SelectedIndex
}
