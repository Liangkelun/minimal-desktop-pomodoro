# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-DesktopShortcutName {
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5Lu75Yqh55Wq6IyE6ZKfLmxuaw=="))
}

function Get-DesktopShortcutPath {
    return (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)) (Get-DesktopShortcutName))
}

function Get-DesktopShortcutInstallerPath {
    return (Join-Path (Get-AppPath "RootDir") "scripts\InstallDesktopShortcutIcon.ps1")
}

function Test-DesktopShortcutExists {
    return (Test-Path -LiteralPath (Get-DesktopShortcutPath) -PathType Leaf)
}

function Test-DesktopShortcutCanInstall {
    $installer = Get-DesktopShortcutInstallerPath
    $launcher = Join-Path (Get-AppPath "RootDir") "StartTaskPomodoro.vbs"
    return ((Test-Path -LiteralPath $installer -PathType Leaf) -and (Test-Path -LiteralPath $launcher -PathType Leaf))
}

function Test-DesktopShortcutPromptEligible {
    if ($null -eq $script:Settings -or [bool]$script:Settings.DesktopShortcutPrompted) {
        return $false
    }
    if (-not (Test-DesktopShortcutCanInstall) -or (Test-DesktopShortcutExists)) {
        return $false
    }
    return [string]::IsNullOrWhiteSpace((Get-AppRepositoryRoot))
}

function Install-DesktopShortcut {
    if (-not (Test-DesktopShortcutCanInstall)) {
        throw "Desktop shortcut installer is not available."
    }
    & (Get-DesktopShortcutInstallerPath) | Out-Null
}

function Invoke-DesktopShortcutInstallFromMenu {
    try {
        Install-DesktopShortcut
        Set-Status (T "DesktopShortcutInstalled")
        return $true
    }
    catch {
        Set-Status ((T "DesktopShortcutInstallFailed") + ": " + $_.Exception.Message)
        return $false
    }
}

function Start-DesktopShortcutPromptDrag([System.Windows.Forms.Form]$Dialog) {
    $script:DesktopShortcutPromptDragStart = [System.Windows.Forms.Cursor]::Position
    $script:DesktopShortcutPromptDragOrigin = $Dialog.Location
}

function Move-DesktopShortcutPromptDrag([System.Windows.Forms.Form]$Dialog) {
    if ($null -eq $script:DesktopShortcutPromptDragStart -or $null -eq $script:DesktopShortcutPromptDragOrigin) {
        return
    }
    $current = [System.Windows.Forms.Cursor]::Position
    $x = [int]([int]$script:DesktopShortcutPromptDragOrigin.X + [int]$current.X - [int]$script:DesktopShortcutPromptDragStart.X)
    $y = [int]([int]$script:DesktopShortcutPromptDragOrigin.Y + [int]$current.Y - [int]$script:DesktopShortcutPromptDragStart.Y)
    $Dialog.Location = New-Object System.Drawing.Point -ArgumentList @($x, $y)
}

function Stop-DesktopShortcutPromptDrag {
    $script:DesktopShortcutPromptDragStart = $null
    $script:DesktopShortcutPromptDragOrigin = $null
}

function Add-DesktopShortcutPromptDrag([System.Windows.Forms.Control]$Control, [System.Windows.Forms.Form]$Dialog) {
    $Control.Add_MouseDown({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Start-DesktopShortcutPromptDrag ($sender.FindForm())
        }
    })
    $Control.Add_MouseMove({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Move-DesktopShortcutPromptDrag ($sender.FindForm())
        }
    })
    $Control.Add_MouseUp({ Stop-DesktopShortcutPromptDrag })
}

function Show-DesktopShortcutPrompt {
    if (Test-WatermarkRuntimeActive) { Suspend-WatermarkRuntimeClickThrough }

    $dialog = New-Object System.Windows.Forms.Form
    try {
        $script:DesktopShortcutPromptResult = [System.Windows.Forms.DialogResult]::Cancel
        $dialog.Text = T "DesktopShortcutPromptTitle"
        $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
        $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $dialog.ShowInTaskbar = $false
        $dialog.ClientSize = New-Object System.Drawing.Size(354, 178)
        if ($null -ne $script:Form) {
            $dialog.Font = $script:Form.Font
        }
        else {
            $dialog.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.5)
        }
        $dialog.BackColor = [System.Drawing.Color]::FromArgb(226, 234, 244)
        $dialog.Padding = New-Object System.Windows.Forms.Padding(1)
        $dialog.KeyPreview = $true
        $dialog.Add_KeyDown({ param($sender, $eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.Close() } })

        $layout = New-Object System.Windows.Forms.TableLayoutPanel
        $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
        $layout.RowCount = 4
        $layout.ColumnCount = 1
        $layout.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 10)
        $layout.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 54))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

        $titleRow = New-Object System.Windows.Forms.TableLayoutPanel
        $titleRow.Dock = [System.Windows.Forms.DockStyle]::Fill
        $titleRow.ColumnCount = 2
        $titleRow.RowCount = 1
        $titleRow.Margin = New-Object System.Windows.Forms.Padding(0)
        $titleRow.BackColor = $layout.BackColor
        $titleRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
        $titleRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 28))) | Out-Null
        Add-DesktopShortcutPromptDrag $titleRow $dialog

        $title = New-Object System.Windows.Forms.Label
        $title.Text = T "DesktopShortcutPromptTitle"
        $title.Dock = [System.Windows.Forms.DockStyle]::Fill
        $title.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $title.Font = New-Object System.Drawing.Font($dialog.Font, [System.Drawing.FontStyle]::Bold)
        $title.BackColor = $layout.BackColor
        Add-DesktopShortcutPromptDrag $title $dialog
        $titleRow.Controls.Add($title, 0, 0)

        $close = New-Button (T "Close") 24
        $close.Dock = [System.Windows.Forms.DockStyle]::Fill
        $close.Margin = New-Object System.Windows.Forms.Padding(0)
        $close.Add_Click({ param($sender, $eventArgs) ($sender.FindForm()).Close() })
        $titleRow.Controls.Add($close, 1, 0)
        $layout.Controls.Add($titleRow, 0, 0)

        $body = New-Object System.Windows.Forms.Label
        $body.Text = T "DesktopShortcutPromptBody"
        $body.Dock = [System.Windows.Forms.DockStyle]::Fill
        $body.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $body.BackColor = $layout.BackColor
        $layout.Controls.Add($body, 0, 1)

        $hint = New-Object System.Windows.Forms.Label
        $hint.Text = T "DesktopShortcutPromptHint"
        $hint.Dock = [System.Windows.Forms.DockStyle]::Fill
        $hint.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $hint.ForeColor = [System.Drawing.Color]::FromArgb(92, 104, 118)
        $hint.BackColor = $layout.BackColor
        $hint.Font = New-Object System.Drawing.Font($dialog.Font.FontFamily, 9.0)
        $layout.Controls.Add($hint, 0, 2)

        $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
        $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill
        $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
        $buttons.WrapContents = $false
        $buttons.Margin = New-Object System.Windows.Forms.Padding(0)
        $buttons.BackColor = $layout.BackColor

        $add = New-Button (T "DesktopShortcutAdd") 78
        $add.BackColor = [System.Drawing.Color]::FromArgb(226, 234, 244)
        $add.Add_Click({
            param($sender, $eventArgs)
            $script:DesktopShortcutPromptResult = [System.Windows.Forms.DialogResult]::OK
            ($sender.FindForm()).Close()
        })
        $buttons.Controls.Add($add)

        $skip = New-Button (T "DesktopShortcutSkip") 78
        $skip.Add_Click({ param($sender, $eventArgs) ($sender.FindForm()).Close() })
        $buttons.Controls.Add($skip)
        $layout.Controls.Add($buttons, 0, 3)

        $dialog.Controls.Add($layout)
        if ($null -ne $script:Form -and -not $script:Form.IsDisposed) {
            $dialog.ShowDialog($script:Form) | Out-Null
        }
        else {
            $dialog.ShowDialog() | Out-Null
        }
        return $script:DesktopShortcutPromptResult
    }
    finally {
        $dialog.Dispose()
        Stop-DesktopShortcutPromptDrag
        Remove-Variable -Name DesktopShortcutPromptResult -Scope Script -ErrorAction SilentlyContinue
        if (Test-WatermarkRuntimeActive) { Update-WatermarkRuntimeClickThrough }
    }
}

function Invoke-FirstRunDesktopShortcutPrompt {
    if (-not (Test-DesktopShortcutPromptEligible)) {
        return
    }
    $choice = Show-DesktopShortcutPrompt
    $script:Settings.DesktopShortcutPrompted = $true
    Save-AppRuntimeSettings
    if ($choice -eq [System.Windows.Forms.DialogResult]::OK) {
        Invoke-DesktopShortcutInstallFromMenu | Out-Null
    }
}
