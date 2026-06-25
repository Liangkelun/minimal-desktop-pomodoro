# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Set-StarterDefaultActionSelection([System.Windows.Forms.ComboBox]$Combo, [string]$Value) {
    $Combo.SelectedIndex = 0
    for ($i = 0; $i -lt $Combo.Items.Count; $i++) {
        if ([string]$Combo.Items[$i].Value -eq $Value) { $Combo.SelectedIndex = $i; break }
    }
}

function New-StarterDefaultActionControl {
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $combo.DisplayMember = "Label"
    $combo.ValueMember = "Value"
    foreach ($item in @(
        @{ Label = T "StarterStartPomodoro"; Value = "pomodoro" },
        @{ Label = T "StarterAgain"; Value = "again" },
        @{ Label = T "StarterCompleteTask"; Value = "complete" },
        @{ Label = T "StarterStop"; Value = "stop" }
    )) { $combo.Items.Add([pscustomobject]$item) | Out-Null }
    Set-StarterDefaultActionSelection $combo ([string]$script:Settings.StarterDefaultAction)
    return $combo
}

function Add-StarterSettingsRows([System.Windows.Forms.TableLayoutPanel]$Panel, [object]$AudioState, [int]$StartRow) {
    Add-SettingSection $Panel (T "StarterSettings") $StartRow
    $minutes = New-Object System.Windows.Forms.NumericUpDown
    $minutes.Minimum = 1; $minutes.Maximum = 30; $minutes.Value = [decimal](Get-TaskStarterMinutes)
    Add-SettingRow $Panel (T "StarterMinutes") $minutes ($StartRow + 1)
    $music = New-AudioSettingControl ([bool]$script:Settings.StarterMusic) $AudioState "StarterMusicFile" "starter" $true ([bool]$script:Settings.StarterMusicLoop)
    Add-SettingRow $Panel (T "StarterMusic") $music.Panel ($StartRow + 2)
    $defaultAction = New-StarterDefaultActionControl
    Add-SettingRow $Panel (T "StarterDefaultAction") $defaultAction ($StartRow + 3)
    return [pscustomobject]@{ Minutes = $minutes; Music = $music.Check; MusicLoop = $music.Loop; DefaultAction = $defaultAction }
}

function Apply-StarterSettingsControls([object]$StarterControls, [object]$AudioState) {
    if ($null -eq $StarterControls) { return }
    $script:Settings.StarterMinutes = [int]$StarterControls.Minutes.Value
    $script:Settings.StarterMusic = [bool]$StarterControls.Music.Checked
    if (($StarterControls.PSObject.Properties.Name -contains "MusicLoop") -and $null -ne $StarterControls.MusicLoop) {
        $script:Settings.StarterMusicLoop = [bool]$StarterControls.MusicLoop.Checked
    }
    if ($null -ne $StarterControls.DefaultAction.SelectedItem) { $script:Settings.StarterDefaultAction = [string]$StarterControls.DefaultAction.SelectedItem.Value }
    $script:Settings.StarterMusicFile = [string](Get-ObjectPropertyValue $AudioState "StarterMusicFile")
}

function Set-StarterMusicSelection([object]$MusicControl, [string]$Path) {
    Set-ObjectPropertyValue $MusicControl.AudioState "StarterMusicFile" $Path
    foreach ($item in $MusicControl.Library.Items) {
        if ([string]::Equals([string]$item.Path, $Path, [System.StringComparison]::OrdinalIgnoreCase)) { $MusicControl.Library.SelectedItem = $item; break }
    }
    Set-AudioLibraryTooltip $MusicControl.Library
}

function Show-TaskStarterSettingsDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = T "StarterSettings"; $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog; $dialog.MinimizeBox = $false; $dialog.MaximizeBox = $false; $dialog.ShowInTaskbar = $false
    $dialog.Width = 440; $dialog.Height = 230
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill; $panel.ColumnCount = 2; $panel.RowCount = 4; $panel.Padding = New-Object System.Windows.Forms.Padding(12); $panel.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 38))) | Out-Null; $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 62))) | Out-Null
    foreach ($height in @(32, 32, 32, 42)) { $panel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, $height))) | Out-Null }
    $audioState = [pscustomobject]@{ StarterMusicFile = [string]$script:Settings.StarterMusicFile }
    $minutes = New-Object System.Windows.Forms.NumericUpDown
    $minutes.Minimum = 1; $minutes.Maximum = 30; $minutes.Value = [decimal](Get-TaskStarterMinutes)
    Add-SettingRow $panel (T "StarterMinutes") $minutes 0
    $music = New-AudioSettingControl ([bool]$script:Settings.StarterMusic) $audioState "StarterMusicFile" "starter" $false $false
    Add-SettingRow $panel (T "StarterMusic") $music.Panel 1
    $defaultAction = New-StarterDefaultActionControl
    Add-SettingRow $panel (T "StarterDefaultAction") $defaultAction 2
    $controls = [pscustomobject]@{ Minutes = $minutes; Music = $music.Check; MusicLoop = $music.Loop; DefaultAction = $defaultAction }
    $musicState = [pscustomobject]@{ Library = $music.Library; AudioState = $audioState }
    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft; $buttons.WrapContents = $false; $buttons.BackColor = $panel.BackColor
    $save = New-Button (T "SaveSettings") 88; $cancel = New-Button (T "Cancel") 70; $defaults = New-Button (T "DefaultSettings") 88
    $save.Add_Click({ Apply-StarterSettingsControls $controls $audioState; Save-GeneralSettings; Update-PomodoroRuntimeAudioAfterSettingsChange; Set-Status (T "SettingsSaved"); Render-CurrentView; $dialog.Close() })
    $cancel.Add_Click({ $dialog.Close() })
    $defaults.Add_Click({ $defaultSettings = Get-DefaultSettings; $minutes.Value = [decimal]$defaultSettings.StarterMinutes; $music.Check.Checked = [bool]$defaultSettings.StarterMusic; Set-StarterDefaultActionSelection $defaultAction ([string]$defaultSettings.StarterDefaultAction); Set-StarterMusicSelection $musicState ([string]$defaultSettings.StarterMusicFile) })
    $dialog.Add_FormClosed({ Stop-PreviewAudio })
    $buttons.Controls.Add($save); $buttons.Controls.Add($defaults); $buttons.Controls.Add($cancel)
    $panel.Controls.Add($buttons, 0, 3); $panel.SetColumnSpan($buttons, 2); $dialog.Controls.Add($panel)
    $dialog.AcceptButton = $save; $dialog.CancelButton = $cancel
    if ($null -ne $script:Form -and -not $script:Form.IsDisposed) { $dialog.ShowDialog($script:Form) | Out-Null } else { $dialog.ShowDialog() | Out-Null }
}