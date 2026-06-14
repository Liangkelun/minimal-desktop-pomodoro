# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Render-SettingsView {
    $script:ContentPanel.Controls.Clear()

    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill; $root.RowCount = 2; $root.ColumnCount = 1
    $root.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40))) | Out-Null
    Add-BottomChromeTracking $root

    $scroll = New-Object System.Windows.Forms.Panel
    $scroll.Dock = [System.Windows.Forms.DockStyle]::Fill; $scroll.AutoScroll = $true; $scroll.BackColor = $root.BackColor
    Add-BottomChromeTracking $scroll

    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Top; $panel.AutoSize = $true; $panel.ColumnCount = 2; $panel.RowCount = 14
    $panel.Padding = New-Object System.Windows.Forms.Padding(2); $panel.BackColor = $root.BackColor
    Add-BottomChromeTracking $panel
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 46))) | Out-Null
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 54))) | Out-Null
    for ($i = 0; $i -lt $panel.RowCount; $i++) {
        $rowHeight = 30
        if ($i -in @(0, 6)) {
            $rowHeight = 24
        }
        elseif ($i -eq 2) {
            $rowHeight = 40
        }
        $panel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, $rowHeight))) | Out-Null
    }

    $audioState = [pscustomobject]@{
        StartSoundFile = [string]$script:Settings.StartSoundFile
        EndSoundFile = [string]$script:Settings.EndSoundFile
        WorkMusicFile = [string]$script:Settings.WorkMusicFile
        BreakMusicFile = [string]$script:Settings.BreakMusicFile
    }

    $language = New-Object System.Windows.Forms.ComboBox
    $language.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $language.DisplayMember = "Label"
    $language.ValueMember = "Value"
    $language.Items.Add([pscustomobject]@{ Label = T "Chinese"; Value = "zh-CN" }) | Out-Null
    $language.Items.Add([pscustomobject]@{ Label = T "English"; Value = "en-US" }) | Out-Null
    if ($script:Settings.Language -eq "en-US") {
        $language.SelectedIndex = 1
    }
    else {
        $language.SelectedIndex = 0
    }
    Add-SettingSection $panel (T "GeneralSettings") 0
    Add-SettingRow $panel (T "Language") $language 1

    $opacityPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $opacityPanel.Dock = [System.Windows.Forms.DockStyle]::Fill; $opacityPanel.ColumnCount = 2; $opacityPanel.RowCount = 1
    $opacityPanel.Margin = New-Object System.Windows.Forms.Padding(0); $opacityPanel.BackColor = $panel.BackColor
    $opacityPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $opacityPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 56))) | Out-Null

    $opacity = New-Object System.Windows.Forms.TrackBar
    $opacity.Minimum = 30
    $opacity.Maximum = 100
    $opacity.TickFrequency = 10
    $opacity.SmallChange = 5
    $opacity.LargeChange = 10
    $opacity.Value = [int]([Math]::Round([double]$script:Settings.Opacity * 100))
    $opacity.Dock = [System.Windows.Forms.DockStyle]::Fill
    $opacity.AutoSize = $false; $opacity.Height = 30; $opacity.Margin = New-Object System.Windows.Forms.Padding(0, 3, 4, 0)
    $opacityLabel = New-Object System.Windows.Forms.Label
    $opacityLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $opacityLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $opacityLabel.AutoSize = $false
    $opacityLabel.MinimumSize = New-Object System.Drawing.Size(56, 0)
    $opacityLabel.Margin = New-Object System.Windows.Forms.Padding(0)
    $opacityLabel.BackColor = $panel.BackColor
    $opacityLabel.Text = "$($opacity.Value)%"
    $opacity.Tag = $opacityLabel
    $opacity.Add_Scroll({
        param($sender, $eventArgs)
        $label = [System.Windows.Forms.Label]$sender.Tag
        $previewOpacity = [double]($sender.Value / 100)
        if ($script:WatermarkMode) {
            $script:WatermarkPreviousOpacity = $previewOpacity
            Update-WatermarkToggleButton
        }
        else {
            $script:Form.Opacity = $previewOpacity
        }
        $label.Text = "$($sender.Value)%"
    })
    $opacityPanel.Controls.Add($opacity, 0, 0)
    $opacityPanel.Controls.Add($opacityLabel, 1, 0)
    Add-SettingRow $panel (T "Opacity") $opacityPanel 2

    $taskFont = New-Object System.Windows.Forms.NumericUpDown
    $taskFont.Minimum = 9
    $taskFont.Maximum = 32
    $taskFont.DecimalPlaces = 1
    $taskFont.Increment = [decimal]0.5
    $taskFont.Value = [decimal]$script:Settings.TaskFontSize
    Add-SettingRow $panel (T "TaskFontSize") $taskFont 3

    $topMostControl = New-CheckOnlyControl ([bool]$script:Settings.TopMost)
    Add-SettingRow $panel (T "TopMost") $topMostControl.Panel 4

    $dailyArchivePanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $dailyArchivePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $dailyArchivePanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $dailyArchivePanel.WrapContents = $false
    $dailyArchivePanel.Margin = New-Object System.Windows.Forms.Padding(0)
    $dailyArchivePanel.Padding = New-Object System.Windows.Forms.Padding(0)
    $dailyArchivePanel.BackColor = $panel.BackColor

    $dailyArchiveHour = New-Object System.Windows.Forms.NumericUpDown
    $dailyArchiveHour.Minimum = 0
    $dailyArchiveHour.Maximum = 23
    $dailyArchiveHour.Width = 52
    $dailyArchiveHour.Value = [decimal]$script:Settings.DailyArchiveHour
    $dailyArchivePanel.Controls.Add($dailyArchiveHour)

    $timeSeparator = New-Object System.Windows.Forms.Label
    $timeSeparator.Text = ":"
    $timeSeparator.Width = 12
    $timeSeparator.Height = 24
    $timeSeparator.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $dailyArchivePanel.Controls.Add($timeSeparator)

    $dailyArchiveMinute = New-Object System.Windows.Forms.NumericUpDown
    $dailyArchiveMinute.Minimum = 0
    $dailyArchiveMinute.Maximum = 59
    $dailyArchiveMinute.Width = 52
    $dailyArchiveMinute.Value = [decimal]$script:Settings.DailyArchiveMinute
    $dailyArchivePanel.Controls.Add($dailyArchiveMinute)
    Add-SettingRow $panel (T "DailyArchiveTime") $dailyArchivePanel 5

    Add-SettingSection $panel (T "PomodoroSettings") 6

    $work = New-Object System.Windows.Forms.NumericUpDown
    $work.Minimum = 1
    $work.Maximum = 180
    $work.Value = [decimal]$script:Settings.WorkMinutes
    Add-SettingRow $panel (T "WorkMinutes") $work 7

    $break = New-Object System.Windows.Forms.NumericUpDown
    $break.Minimum = 1
    $break.Maximum = 60
    $break.Value = [decimal]$script:Settings.ShortBreakMinutes
    Add-SettingRow $panel (T "ShortBreakMinutes") $break 8

    $startSoundControl = New-AudioSettingControl ([bool]$script:Settings.StartSoundReminder) $audioState "StartSoundFile" "start" $false $false
    Add-SettingRow $panel (T "StartSoundReminder") $startSoundControl.Panel 9

    $endSoundControl = New-AudioSettingControl ([bool]$script:Settings.EndSoundReminder) $audioState "EndSoundFile" "end" $false $false
    Add-SettingRow $panel (T "EndSoundReminder") $endSoundControl.Panel 10

    $colorControl = New-CheckOnlyControl ([bool]$script:Settings.ColorReminder)
    Add-SettingRow $panel (T "ColorReminder") $colorControl.Panel 11

    $workMusicControl = New-AudioSettingControl ([bool]$script:Settings.WorkMusic) $audioState "WorkMusicFile" "work" $true ([bool]$script:Settings.WorkMusicLoop)
    Add-SettingRow $panel (T "WorkMusic") $workMusicControl.Panel 12

    $breakMusicControl = New-AudioSettingControl ([bool]$script:Settings.BreakMusic) $audioState "BreakMusicFile" "break" $true ([bool]$script:Settings.BreakMusicLoop)
    Add-SettingRow $panel (T "BreakMusic") $breakMusicControl.Panel 13

    $save = New-Button (T "SaveSettings") 110
    $save.Tag = [pscustomobject]@{
        Language = $language
        Work = $work
        Break = $break
        Opacity = $opacity
        TaskFont = $taskFont
        TopMost = $topMostControl.Check
        DailyArchiveHour = $dailyArchiveHour
        DailyArchiveMinute = $dailyArchiveMinute
        StartSound = $startSoundControl.Check
        EndSound = $endSoundControl.Check
        Color = $colorControl.Check
        WorkMusic = $workMusicControl.Check
        WorkMusicLoop = $workMusicControl.Loop
        BreakMusic = $breakMusicControl.Check
        BreakMusicLoop = $breakMusicControl.Loop
        AudioState = $audioState
    }
    $language.Tag = $save.Tag
    $language.Add_SelectedIndexChanged({
        param($sender, $eventArgs)
        if ($null -eq $sender.Tag) {
            return
        }
        $selectedLanguage = "zh-CN"
        if ($sender.SelectedItem -ne $null) {
            $selectedLanguage = [string]$sender.SelectedItem.Value
        }
        if ($selectedLanguage -eq [string]$script:Settings.Language) {
            return
        }

        $script:Settings.Language = $selectedLanguage
        Save-Settings
        $script:Form.Text = T "AppTitle"
        Update-NavText
        Update-WatermarkToggleButton
        Set-Status (T "SettingsSaved")
        Render-CurrentView
    })
    $save.Add_Click({
        param($sender, $eventArgs)
        $archivedCount = Apply-SettingsControls $sender.Tag
        if ($archivedCount -gt 0) {
            Set-Status (T "DailyArchivedTasks")
        }
        else {
            Set-Status (T "SettingsSaved")
        }
        Render-CurrentView
    })

    $defaults = New-Button (T "DefaultSettings") 110
    $defaults.Add_Click({
        Reset-SettingsToDefaults
        if ($script:TimerState -eq "idle") { $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60 }
        elseif ($script:TimerState -eq "running") { Start-BackgroundAudio $script:TimerPhase }
        elseif ($script:TimerState -ne "paused") { Stop-BackgroundAudio }
        Save-Settings
        Update-NavText; Update-WatermarkToggleButton; Update-TimerLabels; Set-Status (T "SettingsSaved")
        Render-CurrentView
    })

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft; $buttons.WrapContents = $false
    $buttons.Padding = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
    $buttons.Margin = New-Object System.Windows.Forms.Padding(0); $buttons.BackColor = $root.BackColor
    $buttons.Controls.Add($save)
    $buttons.Controls.Add($defaults)
    Add-BottomChromeTracking $buttons

    $scroll.Controls.Add($panel)
    $root.Controls.Add($scroll, 0, 0)
    $root.Controls.Add($buttons, 0, 1)
    $script:ContentPanel.Controls.Add($root)
}

