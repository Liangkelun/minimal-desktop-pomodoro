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
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            Show-HelpMenu $sender
        }
        elseif ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Show-HelpTopic "HelpTitle" "HelpText"
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
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    $update = New-Object System.Windows.Forms.ToolStripMenuItem
    $update.Text = T "HelpUpdate"
    Add-HelpActionMenuItem $update "RestartApp" { Restart-TaskPomodoroApp } $true
    Add-HelpActionMenuItem $update "OpenAppFolder" { Open-AppFolder } $true
    Add-HelpActionMenuItem $update "UpdateFromGit" { Invoke-GitUpdateAndRestart } (Test-GitUpdateEnabled)
    Add-HelpMenuItem $update "UpdateInfo" "HelpUpdate" "UpdateInfoText"
    $menu.Items.Add($update) | Out-Null
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    Add-HelpMenuItem $menu "HelpSponsor" "HelpSponsor" "HelpSponsorText"
    Add-HelpMenuItem $menu "HelpAboutGovernance" "HelpAboutGovernance" "HelpAboutGovernanceText"
    $menu.Show($Owner, (New-Object System.Drawing.Point -ArgumentList @(0, [int]$Owner.Height)))
}
