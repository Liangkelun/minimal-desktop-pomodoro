# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Add-SettingRow([System.Windows.Forms.TableLayoutPanel]$Panel, [string]$LabelText, [System.Windows.Forms.Control]$Control, [int]$Row) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $LabelText
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.BackColor = $Panel.BackColor
    $label.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
    $Control.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Control.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $Panel.Controls.Add($label, 0, $Row)
    $Panel.Controls.Add($Control, 1, $Row)
}

function Add-SettingSection([System.Windows.Forms.TableLayoutPanel]$Panel, [string]$Text, [int]$Row) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.BackColor = $Panel.BackColor
    $label.ForeColor = [System.Drawing.Color]::DimGray
    $label.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
    $label.Font = New-Object System.Drawing.Font -ArgumentList @($label.Font, [System.Drawing.FontStyle]::Bold)
    $Panel.Controls.Add($label, 0, $Row)
    $Panel.SetColumnSpan($label, 2)
}

function Get-ObjectPropertyValue([object]$Object, [string]$Name) {
    if ($null -ne $Object -and ($Object.PSObject.Properties.Name -contains $Name)) {
        return $Object.PSObject.Properties[$Name].Value
    }
    return ""
}

function Set-ObjectPropertyValue([object]$Object, [string]$Name, [object]$Value) {
    Add-Member -InputObject $Object -MemberType NoteProperty -Name $Name -Value $Value -Force
}

function Get-AudioPathForPreview([string]$Kind, [string]$CustomPath) {
    switch ($Kind) {
        "start" { return Resolve-AudioFile $CustomPath "ding.wav" }
        "end" { return Resolve-AudioFile $CustomPath "Alarm01.wav" }
        "work" { return Resolve-AudioFile $CustomPath "chimes.wav" }
        "break" { return Resolve-AudioFile $CustomPath "chord.wav" }
    }
    return $null
}

function Play-AudioPreview([object]$Tag) {
    $custom = [string](Get-ObjectPropertyValue $Tag.State $Tag.Property)
    $path = Get-AudioPathForPreview $Tag.Kind $custom
    Play-Wav $path ([System.Media.SystemSounds]::Asterisk)
}

function Select-AudioFileFromButton([System.Windows.Forms.Button]$Button) {
    $tag = $Button.Tag
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = T "AudioFile"
    $dialog.Filter = "Audio files (*.wav;*.mp3;*.wma;*.m4a;*.aac)|*.wav;*.mp3;*.wma;*.m4a;*.aac|WAV audio (*.wav)|*.wav|All files (*.*)|*.*"
    $current = [string](Get-ObjectPropertyValue $tag.State $tag.Property)
    if (-not [string]::IsNullOrWhiteSpace($current) -and (Test-Path -LiteralPath $current)) {
        $dialog.InitialDirectory = Split-Path -Parent $current
    }
    else {
        $media = Join-Path $env:WINDIR "Media"
        if (Test-Path -LiteralPath $media) {
            $dialog.InitialDirectory = $media
        }
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-ObjectPropertyValue $tag.State $tag.Property $dialog.FileName
        if ($null -ne $tag.Library) { $item = [pscustomobject]@{ Label = T "AudioFile"; Path = $dialog.FileName; IsCustom = $true }; $tag.Library.Items.Add($item) | Out-Null; $tag.Library.SelectedItem = $item }
        $Button.Text = "...*"
        Set-Status ((T "AudioSelected") + ": " + [System.IO.Path]::GetFileName($dialog.FileName))
        if ($null -eq $tag.Library) {
            Play-AudioPreview $tag
        }
    }
}

function New-CheckOnlyControl([bool]$Checked) {
    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $panel.WrapContents = $false
    $panel.Margin = New-Object System.Windows.Forms.Padding(0)
    $panel.Padding = New-Object System.Windows.Forms.Padding(0)
    $panel.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

    $check = New-Object System.Windows.Forms.CheckBox
    $check.Width = 24
    $check.Height = 24
    $check.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)
    $check.Checked = $Checked
    $panel.Controls.Add($check)

    return [pscustomobject]@{
        Panel = $panel
        Check = $check
    }
}

function Set-LoopToggleVisual([System.Windows.Forms.CheckBox]$Loop) {
    if ($null -eq $Loop) {
        return
    }
    if ($Loop.Checked) {
        $Loop.Text = T "LoopOnIcon"
        $Loop.ForeColor = [System.Drawing.Color]::FromArgb(24, 96, 56)
    }
    else {
        $Loop.Text = T "LoopOffIcon"
        $Loop.ForeColor = [System.Drawing.Color]::DimGray
    }
}

function New-AudioSettingControl([bool]$Checked, [object]$AudioState, [string]$Property, [string]$Kind, [bool]$IncludeLoop, [bool]$LoopChecked) {
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill; $panel.RowCount = 1; $panel.ColumnCount = 3; $panel.Margin = New-Object System.Windows.Forms.Padding(0); $panel.Padding = New-Object System.Windows.Forms.Padding(0); $panel.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 26))) | Out-Null; $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null; $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null
    if ($IncludeLoop) { $panel.ColumnCount = 4; $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null }
    $check = New-Object System.Windows.Forms.CheckBox
    $check.Width = 24; $check.Height = 24; $check.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 0); $check.Checked = $Checked; $check.Tag = [pscustomobject]@{ State = $AudioState; Property = $Property; Kind = $Kind }
    $check.Add_CheckedChanged({ param($sender, $eventArgs) if ($sender.Checked) { Play-AudioPreview $sender.Tag } })
    $panel.Controls.Add($check, 0, 0)
    $library = New-Object System.Windows.Forms.ComboBox
    $library.Dock = [System.Windows.Forms.DockStyle]::Fill; $library.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $library.DisplayMember = "Label"; $library.ValueMember = "Path"; $library.Height = 24; $library.Margin = New-Object System.Windows.Forms.Padding(4, 1, 0, 0)
    $map = @{ start = @("focus-start.wav", "break-start.wav"); end = @("break-start.wav", "focus-start.wav"); work = @("focus-loop.mp3", "focus-loop.wav", "break-loop.mp3", "break-loop.wav"); break = @("break-loop.mp3", "break-loop.wav", "focus-loop.mp3", "focus-loop.wav") }
    $prefix = "Built-in "; if ([string]$script:Settings.Language -ne "en-US") { $prefix = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5YaF572uIA==")) }
    if ($map.ContainsKey($Kind)) { foreach ($fileName in $map[$Kind]) { $path = Get-DefaultAudioPath $fileName; if (-not [string]::IsNullOrWhiteSpace($path)) { $library.Items.Add([pscustomobject]@{ Label = "$prefix$fileName"; Path = $path; IsCustom = $false }) | Out-Null } } }
    $button = New-Button "..." 32
    $button.Dock = [System.Windows.Forms.DockStyle]::Fill; $button.Height = 24; $button.Margin = New-Object System.Windows.Forms.Padding(4, 1, 0, 0); $button.Tag = [pscustomobject]@{ State = $AudioState; Property = $Property; Kind = $Kind; Library = $library }
    $button.Add_Click({ param($sender, $eventArgs) Select-AudioFileFromButton $sender })
    $current = [string](Get-ObjectPropertyValue $AudioState $Property); foreach ($item in $library.Items) { if ([string]::Equals([string]$item.Path, $current, [System.StringComparison]::OrdinalIgnoreCase)) { $library.SelectedItem = $item; break } }
    if ($library.SelectedIndex -lt 0 -and -not [string]::IsNullOrWhiteSpace($current)) { $button.Text = "...*"; $custom = [pscustomobject]@{ Label = T "AudioFile"; Path = $current; IsCustom = $true }; $library.Items.Add($custom) | Out-Null; $library.SelectedItem = $custom }
    elseif ($library.SelectedIndex -lt 0 -and $library.Items.Count -gt 0) { $library.SelectedIndex = 0 }
    $library.Tag = [pscustomobject]@{ State = $AudioState; Property = $Property; Kind = $Kind; Button = $button }
    $library.Add_SelectedIndexChanged({ param($sender, $eventArgs) if ($null -eq $sender.SelectedItem) { return }; $tag = $sender.Tag; $item = $sender.SelectedItem; Set-ObjectPropertyValue $tag.State $tag.Property ([string]$item.Path); if ([bool]$item.IsCustom) { $tag.Button.Text = "...*" } else { $tag.Button.Text = "..." }; Play-AudioPreview $tag })
    $panel.Controls.Add($library, 1, 0); $panel.Controls.Add($button, 2, 0)
    $loop = $null
    if ($IncludeLoop) {
        $loop = New-Object System.Windows.Forms.CheckBox
        $loop.Appearance = [System.Windows.Forms.Appearance]::Button
        $loop.Width = 30
        $loop.Height = 24
        $loop.Dock = [System.Windows.Forms.DockStyle]::Fill
        $loop.Margin = New-Object System.Windows.Forms.Padding(4, 1, 0, 1)
        $loop.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $loop.Checked = $LoopChecked
        $loop.Add_CheckedChanged({
            param($sender, $eventArgs)
            Set-LoopToggleVisual ([System.Windows.Forms.CheckBox]$sender)
        })
        Set-LoopToggleVisual $loop
        $panel.Controls.Add($loop, 3, 0)
    }

    return [pscustomobject]@{
        Panel = $panel
        Check = $check
        Library = $library
        Loop = $loop
    }
}

function Apply-SettingsControls([object]$Controls) {
    if ($null -eq $Controls) {
        return 0
    }

    $selectedLanguage = "zh-CN"
    if ($Controls.Language.SelectedItem -ne $null) {
        $selectedLanguage = [string]$Controls.Language.SelectedItem.Value
    }
    $script:Settings.Language = $selectedLanguage
    $script:Settings.WorkMinutes = [int]$Controls.Work.Value
    $script:Settings.ShortBreakMinutes = [int]$Controls.Break.Value
    $script:Settings.Opacity = [double]($Controls.Opacity.Value / 100)
    $script:Settings.TaskFontSize = [double]$Controls.TaskFont.Value
    $script:Settings.BlurTextStyle = [string]$Controls.BlurText.SelectedItem.Value
    $script:Settings.TopMost = [bool]$Controls.TopMost.Checked
    $script:Settings.DailyArchiveHour = [int]$Controls.DailyArchiveHour.Value
    $script:Settings.DailyArchiveMinute = [int]$Controls.DailyArchiveMinute.Value
    $script:Settings.SoundReminder = ([bool]$Controls.StartSound.Checked -or [bool]$Controls.EndSound.Checked)
    $script:Settings.StartSoundReminder = [bool]$Controls.StartSound.Checked
    $script:Settings.EndSoundReminder = [bool]$Controls.EndSound.Checked
    $script:Settings.ColorReminder = [bool]$Controls.Color.Checked
    $script:Settings.WorkMusic = [bool]$Controls.WorkMusic.Checked
    $script:Settings.WorkMusicLoop = [bool]$Controls.WorkMusicLoop.Checked
    $script:Settings.BreakMusic = [bool]$Controls.BreakMusic.Checked
    $script:Settings.BreakMusicLoop = [bool]$Controls.BreakMusicLoop.Checked
    $script:Settings.StartSoundFile = [string](Get-ObjectPropertyValue $Controls.AudioState "StartSoundFile")
    $script:Settings.EndSoundFile = [string](Get-ObjectPropertyValue $Controls.AudioState "EndSoundFile")
    $script:Settings.WorkMusicFile = [string](Get-ObjectPropertyValue $Controls.AudioState "WorkMusicFile")
    $script:Settings.BreakMusicFile = [string](Get-ObjectPropertyValue $Controls.AudioState "BreakMusicFile")
    $script:Form.TopMost = [bool]$script:Settings.TopMost
    if ($script:WatermarkMode) {
        $script:WatermarkPreviousOpacity = [double]$script:Settings.Opacity
        $script:Form.Opacity = Get-WatermarkModeOpacity
    }
    else {
        $script:Form.Opacity = [double]$script:Settings.Opacity
    }
    $script:Form.Text = T "AppTitle"
    Update-NavText
    Update-WatermarkToggleButton
    if ($script:TimerState -eq "running") {
        Start-BackgroundAudio $script:TimerPhase
    }
    elseif ($script:TimerState -ne "paused") {
        Stop-BackgroundAudio
    }
    if ($script:TimerState -eq "idle") {
        $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    }
    Save-Settings
    Update-TimerLabels
    return (Invoke-DailyArchiveIfDue)
}

