# This file is dot-sourced before Views.Settings.ps1. Keep general settings row construction separate from the settings view shell.

function Add-GeneralSettingsRows([System.Windows.Forms.TableLayoutPanel]$Panel) {
    $language = New-Object System.Windows.Forms.ComboBox
    $language.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $language.DisplayMember = "Label"
    $language.ValueMember = "Value"
    $language.Items.Add([pscustomobject]@{ Label = T "Chinese"; Value = "zh-CN" }) | Out-Null
    $language.Items.Add([pscustomobject]@{ Label = T "English"; Value = "en-US" }) | Out-Null
    if ($script:Settings.Language -eq "en-US") { $language.SelectedIndex = 1 } else { $language.SelectedIndex = 0 }
    Add-SettingSection $Panel (T "GeneralSettings") 0
    Add-SettingRow $Panel (T "Language") $language 1

    $opacityPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $opacityPanel.Dock = [System.Windows.Forms.DockStyle]::Fill; $opacityPanel.ColumnCount = 2; $opacityPanel.RowCount = 1
    $opacityPanel.Margin = New-Object System.Windows.Forms.Padding(0); $opacityPanel.BackColor = $Panel.BackColor
    $opacityPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $opacityPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 56))) | Out-Null
    $opacity = New-Object System.Windows.Forms.TrackBar
    $opacity.Minimum = 30; $opacity.Maximum = 100; $opacity.TickFrequency = 10; $opacity.SmallChange = 5; $opacity.LargeChange = 10
    $opacity.Value = [int]([Math]::Round([double]$script:Settings.Opacity * 100))
    $opacity.Dock = [System.Windows.Forms.DockStyle]::Fill; $opacity.AutoSize = $false; $opacity.Height = 30; $opacity.Margin = New-Object System.Windows.Forms.Padding(0, 3, 4, 0)
    $opacityLabel = New-Object System.Windows.Forms.Label
    $opacityLabel.Dock = [System.Windows.Forms.DockStyle]::Fill; $opacityLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight; $opacityLabel.AutoSize = $false; $opacityLabel.MinimumSize = New-Object System.Drawing.Size(56, 0); $opacityLabel.Margin = New-Object System.Windows.Forms.Padding(0); $opacityLabel.BackColor = $Panel.BackColor; $opacityLabel.Text = "$($opacity.Value)%"
    $opacity.Tag = $opacityLabel
    $opacity.Add_Scroll({ param($sender, $eventArgs) $label = [System.Windows.Forms.Label]$sender.Tag; $previewOpacity = [double]($sender.Value / 100); Set-WatermarkRuntimeConfiguredOpacity $previewOpacity; $label.Text = "$($sender.Value)%" })
    $opacityPanel.Controls.Add($opacity, 0, 0); $opacityPanel.Controls.Add($opacityLabel, 1, 0)
    Add-SettingRow $Panel (T "Opacity") $opacityPanel 2

    $audioVolumeControl = New-VolumeSettingControl ([int]$script:Settings.AudioVolume)
    Add-SettingRow $Panel (T "AudioVolume") $audioVolumeControl.Panel 3

    $taskFont = New-Object System.Windows.Forms.NumericUpDown
    $taskFont.Minimum = 9; $taskFont.Maximum = 32; $taskFont.DecimalPlaces = 1; $taskFont.Increment = [decimal]0.5; $taskFont.Value = [decimal]$script:Settings.TaskFontSize
    Add-SettingRow $Panel (T "TaskFontSize") $taskFont 4

    $blurText = New-Object System.Windows.Forms.ComboBox
    $blurText.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $blurText.DisplayMember = "Label"; $blurText.ValueMember = "Value"
    $darkBlurLabel = -join ([char[]](0x9ED1, 0x5B57, 0x767D, 0x5F71))
    $lightBlurLabel = -join ([char[]](0x767D, 0x5B57, 0x9ED1, 0x5F71))
    $blurText.Items.Add([pscustomobject]@{ Label = $darkBlurLabel; Value = "dark" }) | Out-Null
    $blurText.Items.Add([pscustomobject]@{ Label = $lightBlurLabel; Value = "light" }) | Out-Null
    $blurText.SelectedIndex = 0; if ([string]$script:Settings.BlurTextStyle -eq "light") { $blurText.SelectedIndex = 1 }
    Add-SettingRow $Panel (T "Watermark") $blurText 5

    $topMostControl = New-CheckOnlyControl ([bool]$script:Settings.TopMost)
    Add-SettingRow $Panel (T "TopMost") $topMostControl.Panel 6

    $dailyArchivePanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $dailyArchivePanel.Dock = [System.Windows.Forms.DockStyle]::Fill; $dailyArchivePanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight; $dailyArchivePanel.WrapContents = $false; $dailyArchivePanel.Margin = New-Object System.Windows.Forms.Padding(0); $dailyArchivePanel.Padding = New-Object System.Windows.Forms.Padding(0); $dailyArchivePanel.BackColor = $Panel.BackColor
    $dailyArchiveHour = New-Object System.Windows.Forms.NumericUpDown
    $dailyArchiveHour.Minimum = 0; $dailyArchiveHour.Maximum = 23; $dailyArchiveHour.Width = 52; $dailyArchiveHour.Value = [decimal]$script:Settings.DailyArchiveHour
    $dailyArchivePanel.Controls.Add($dailyArchiveHour)
    $timeSeparator = New-Object System.Windows.Forms.Label
    $timeSeparator.Text = ":"; $timeSeparator.Width = 12; $timeSeparator.Height = 24; $timeSeparator.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $dailyArchivePanel.Controls.Add($timeSeparator)
    $dailyArchiveMinute = New-Object System.Windows.Forms.NumericUpDown
    $dailyArchiveMinute.Minimum = 0; $dailyArchiveMinute.Maximum = 59; $dailyArchiveMinute.Width = 52; $dailyArchiveMinute.Value = [decimal]$script:Settings.DailyArchiveMinute
    $dailyArchivePanel.Controls.Add($dailyArchiveMinute)
    Add-SettingRow $Panel (T "DailyArchiveTime") $dailyArchivePanel 7

    Add-SettingSection $Panel (T "HelpShortcuts") 8
    $shortcutF2Edit = New-CheckOnlyControl ([bool]$script:Settings.ShortcutF2EditTaskEnabled)
    Add-SettingRow $Panel (T "ShortcutF2EditTask") $shortcutF2Edit.Panel 9
    $shortcutCtrlOpen = New-CheckOnlyControl ([bool]$script:Settings.ShortcutCtrlDoubleClickOpenLinkEnabled)
    Add-SettingRow $Panel (T "ShortcutCtrlDoubleClickOpenLink") $shortcutCtrlOpen.Panel 10

    return [pscustomobject]@{ Language = $language; Opacity = $opacity; AudioVolume = $audioVolumeControl; TaskFont = $taskFont; BlurText = $blurText; TopMost = $topMostControl; DailyArchiveHour = $dailyArchiveHour; DailyArchiveMinute = $dailyArchiveMinute; ShortcutF2EditTask = $shortcutF2Edit; ShortcutCtrlDoubleClickOpenLink = $shortcutCtrlOpen }
}
