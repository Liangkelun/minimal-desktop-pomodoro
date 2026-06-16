# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Ensure-HelpButton {
    if ($null -ne $script:HelpButton -and -not $script:HelpButton.IsDisposed) {
        return
    }
    if ($null -eq $script:Form) {
        return
    }

    $button = New-Button "?" 24
    $button.Height = 22
    $button.Margin = New-Object System.Windows.Forms.Padding(0)
    $button.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)
    $button.Location = New-Object System.Drawing.Point -ArgumentList @([int][Math]::Max(0, ([int]$script:Form.ClientSize.Width - 56)), 4)
    $button.Visible = $false
    $button.Add_MouseUp({
        param($sender, $eventArgs)
        if ($eventArgs.Button -in @([System.Windows.Forms.MouseButtons]::Left, [System.Windows.Forms.MouseButtons]::Right)) {
            Show-HelpMenu $sender
        }
    })

    $script:HelpButton = $button
    $script:Form.Controls.Add($button)
    $button.BringToFront()
}

function Show-HelpTopic([string]$TitleKey, [string]$TextKey) {
    if ($null -ne $script:Form -and $script:WatermarkMode) {
        $script:Form.SetClickThrough($false)
    }
    [System.Windows.Forms.MessageBox]::Show((T $TextKey), (T $TitleKey), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    if ($script:WatermarkMode) {
        Update-WatermarkClickThrough
    }
}

function Show-HelpSponsor {
    $qrPath = Join-Path (Get-AppPath "RootDir") "assets\sponsor\wechat-sponsor.jpg"
    if (-not (Test-Path -LiteralPath $qrPath -PathType Leaf)) {
        Show-HelpTopic "HelpSponsor" "HelpSponsorText"
        return
    }
    if ($null -ne $script:Form -and $script:WatermarkMode) {
        $script:Form.SetClickThrough($false)
    }

    $dialog = New-Object System.Windows.Forms.Form
    $image = $null
    try {
        $dialog.Text = T "HelpSponsor"
        $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
        $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $dialog.MinimizeBox = $false; $dialog.MaximizeBox = $false; $dialog.ShowInTaskbar = $false
        $dialog.ClientSize = New-Object System.Drawing.Size(470, 630)
        $dialog.Font = $script:Form.Font
        $dialog.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)

        $layout = New-Object System.Windows.Forms.TableLayoutPanel
        $layout.Dock = [System.Windows.Forms.DockStyle]::Fill; $layout.RowCount = 3; $layout.ColumnCount = 1
        $layout.Padding = New-Object System.Windows.Forms.Padding(14); $layout.BackColor = $dialog.BackColor
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 116))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
        $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38))) | Out-Null

        $text = New-Object System.Windows.Forms.Label
        $text.Text = T "HelpSponsorText"
        $text.Dock = [System.Windows.Forms.DockStyle]::Fill; $text.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft; $text.BackColor = $dialog.BackColor
        $layout.Controls.Add($text, 0, 0)

        $picture = New-Object System.Windows.Forms.PictureBox
        $picture.Dock = [System.Windows.Forms.DockStyle]::Fill; $picture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom; $picture.BackColor = [System.Drawing.Color]::White
        $image = [System.Drawing.Image]::FromFile($qrPath)
        $picture.Image = $image
        $layout.Controls.Add($picture, 0, 1)

        $close = New-Button (T "Cancel") 92
        $close.Anchor = [System.Windows.Forms.AnchorStyles]::Right; $close.Add_Click({ param($sender, $eventArgs) $sender.FindForm().Close() })
        $layout.Controls.Add($close, 0, 2)
        $dialog.AcceptButton = $close
        $dialog.CancelButton = $close
        $dialog.Controls.Add($layout)

        if ($null -ne $script:Form -and -not $script:Form.IsDisposed) {
            $dialog.ShowDialog($script:Form) | Out-Null
        }
        else {
            $dialog.ShowDialog() | Out-Null
        }
    }
    finally {
        if ($null -ne $image) { $image.Dispose() }
        $dialog.Dispose()
        if ($script:WatermarkMode) {
            Update-WatermarkClickThrough
        }
    }
}

function Add-HelpMenuEntry([object]$Menu, [System.Windows.Forms.ToolStripItem]$Item) {
    if ($Menu -is [System.Windows.Forms.ToolStripMenuItem]) {
        $Menu.DropDownItems.Add($Item) | Out-Null
    }
    else {
        $Menu.Items.Add($Item) | Out-Null
    }
}

function Add-HelpMenuItem([object]$Menu, [string]$TextKey, [string]$TitleKey, [string]$BodyKey) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = T $TextKey
    $item.Tag = [pscustomobject]@{
        TitleKey = $TitleKey
        BodyKey = $BodyKey
    }
    $item.Add_Click({
        param($sender, $eventArgs)
        Show-HelpTopic $sender.Tag.TitleKey $sender.Tag.BodyKey
    })
    Add-HelpMenuEntry $Menu $item
}

function Add-HelpActionMenuItem([object]$Menu, [string]$TextKey, [scriptblock]$Action, [bool]$Enabled) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = T $TextKey
    $item.Enabled = $Enabled
    $item.Add_Click($Action)
    Add-HelpMenuEntry $Menu $item
}

function Show-HelpMenu([System.Windows.Forms.Control]$Owner) {
    if ($null -eq $Owner -or $Owner.IsDisposed) {
        return
    }
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    Add-HelpMenuItem $menu "HelpQuick" "HelpTitle" "HelpText"
    Add-HelpMenuItem $menu "HelpDiagram" "HelpDiagram" "HelpDiagramText"
    Add-HelpMenuItem $menu "HelpRules" "HelpRules" "HelpRulesText"
    Add-HelpMenuItem $menu "HelpShortcuts" "HelpShortcuts" "HelpShortcutsText"
    Add-HelpActionMenuItem $menu "Settings" { Set-ActiveView "settings" } $true
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    $update = New-Object System.Windows.Forms.ToolStripMenuItem
    $update.Text = T "HelpUpdate"
    Add-HelpActionMenuItem $update "RestartApp" { Restart-TaskPomodoroApp } $true
    Add-HelpActionMenuItem $update "OpenAppFolder" { Open-AppFolder } $true
    Add-HelpActionMenuItem $update "DesktopShortcutMenu" { Invoke-DesktopShortcutInstallFromMenu | Out-Null } (Test-DesktopShortcutCanInstall)
    Add-HelpActionMenuItem $update "UpdateFromGit" { Invoke-GitUpdateAndRestart } (Test-GitUpdateEnabled)
    Add-HelpMenuItem $update "UpdateInfo" "HelpUpdate" "UpdateInfoText"
    $menu.Items.Add($update) | Out-Null
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    Add-HelpActionMenuItem $menu "HelpSponsor" { Show-HelpSponsor } $true
    Add-HelpMenuItem $menu "HelpAboutGovernance" "HelpAboutGovernance" "HelpAboutGovernanceText"
    $menu.Show($Owner, (New-Object System.Drawing.Point -ArgumentList @(0, [int]$Owner.Height)))
}
