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
    $panel.Dock = [System.Windows.Forms.DockStyle]::Top; $panel.AutoSize = $true; $panel.ColumnCount = 2; $panel.RowCount = 39
    $panel.Padding = New-Object System.Windows.Forms.Padding(2); $panel.BackColor = $root.BackColor
    Add-BottomChromeTracking $panel
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 46))) | Out-Null
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 54))) | Out-Null
    for ($i = 0; $i -lt $panel.RowCount; $i++) {
        $rowHeight = 30
        if ($i -in @(0, 8, 11, 19, 23)) {
            $rowHeight = 38
        }
        elseif ($i -eq 2) {
            $rowHeight = 40
        }
        elseif ($i -eq 38) {
            $rowHeight = 50
        }
        $panel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, $rowHeight))) | Out-Null
    }

    $audioState = [pscustomobject]@{
        StartSoundFile = [string]$script:Settings.StartSoundFile
        EndSoundFile = [string]$script:Settings.EndSoundFile
        WorkMusicFile = [string]$script:Settings.WorkMusicFile
        BreakMusicFile = [string]$script:Settings.BreakMusicFile
        StarterMusicFile = [string]$script:Settings.StarterMusicFile
    }

    $generalControls = Add-GeneralSettingsRows $panel

    $pomodoroControls = Add-PomodoroSettingsRows $panel $audioState 11
    $starterControls = Add-StarterSettingsRows $panel $audioState 19
    $translationControls = Add-TranslationSettingsRows $panel 23

    $save = New-Button (T "SaveSettings") 88
    $save.Tag = [pscustomobject]@{
        Language = $generalControls.Language
        Work = $pomodoroControls.Work
        Break = $pomodoroControls.Break
        Opacity = $generalControls.Opacity
        AudioVolume = $generalControls.AudioVolume.Slider
        TaskFont = $generalControls.TaskFont
        BlurText = $generalControls.BlurText
        TopMost = $generalControls.TopMost.Check
        DailyArchiveHour = $generalControls.DailyArchiveHour
        DailyArchiveMinute = $generalControls.DailyArchiveMinute
        ShortcutF2EditTask = $generalControls.ShortcutF2EditTask.Check
        ShortcutCtrlDoubleClickOpenLink = $generalControls.ShortcutCtrlDoubleClickOpenLink.Check
        StartSound = $pomodoroControls.StartSound.Check
        EndSound = $pomodoroControls.EndSound.Check
        Color = $pomodoroControls.Color.Check
        WorkMusic = $pomodoroControls.WorkMusic.Check
        WorkMusicLoop = $pomodoroControls.WorkMusic.Loop
        BreakMusic = $pomodoroControls.BreakMusic.Check
        BreakMusicLoop = $pomodoroControls.BreakMusic.Loop
        Starter = $starterControls
        Translation = $translationControls
        AudioState = $audioState
    }
    $generalControls.Language.Tag = $save.Tag
    $generalControls.Language.Add_SelectedIndexChanged({
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
        Save-GeneralSettings
        $script:Form.Text = T "AppTitle"
        Update-NavText
        Update-WatermarkRuntimeToggleButton
        Set-Status (T "SettingsSaved")
        Render-CurrentView
    })
    $save.Add_Click({
        param($sender, $eventArgs)
        $archiveResult = Apply-SettingsControls $sender.Tag
        if ([int]$archiveResult.Data -gt 0) {
            Invoke-AppActionResult $archiveResult
        }
        else {
            Set-Status (T "SettingsSaved")
            Render-CurrentView
        }
    })

    $defaults = New-Button (T "DefaultSettings") 88
    $defaults.Add_Click({
        Reset-SettingsToDefaults
        Update-PomodoroRuntimeAfterGeneralSettingsChange
        Save-GeneralSettings
        Update-NavText; Update-WatermarkRuntimeToggleButton; Update-TimerLabels; Set-Status (T "SettingsSaved")
        Render-CurrentView
    })

    $cancel = New-Button (T "Cancel") 70
    $cancel.Add_Click({
        Set-WatermarkRuntimeConfiguredOpacity ([double]$script:Settings.Opacity)
        Render-CurrentView
    })

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft; $buttons.WrapContents = $false
    $buttons.Padding = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
    $buttons.Margin = New-Object System.Windows.Forms.Padding(0); $buttons.BackColor = $root.BackColor
    $buttons.Controls.Add($save)
    $buttons.Controls.Add($defaults)
    $buttons.Controls.Add($cancel)
    Add-BottomChromeTracking $buttons

    $scroll.Controls.Add($panel)
    $root.Controls.Add($scroll, 0, 0)
    $root.Controls.Add($buttons, 0, 1)
    $script:ContentPanel.Controls.Add($root)
}

