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
        $Button.Text = "...*"
        Set-Status ((T "AudioSelected") + ": " + [System.IO.Path]::GetFileName($dialog.FileName))
        Play-AudioPreview $tag
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
    $check.Tag = [pscustomobject]@{ State = $AudioState; Property = $Property; Kind = $Kind }
    $check.Add_CheckedChanged({
        param($sender, $eventArgs)
        if ($sender.Checked) {
            Play-AudioPreview $sender.Tag
        }
    })
    $panel.Controls.Add($check)

    $button = New-Button "..." 44
    $button.Height = 24
    $button.Margin = New-Object System.Windows.Forms.Padding(6, 1, 0, 0)
    if (-not [string]::IsNullOrWhiteSpace([string](Get-ObjectPropertyValue $AudioState $Property))) {
        $button.Text = "...*"
    }
    $button.Tag = [pscustomobject]@{ State = $AudioState; Property = $Property; Kind = $Kind }
    $button.Add_Click({
        param($sender, $eventArgs)
        Select-AudioFileFromButton $sender
    })
    $panel.Controls.Add($button)

    $loop = $null
    if ($IncludeLoop) {
        $loop = New-Object System.Windows.Forms.CheckBox
        $loop.Appearance = [System.Windows.Forms.Appearance]::Button
        $loop.Width = 30
        $loop.Height = 24
        $loop.Margin = New-Object System.Windows.Forms.Padding(6, 1, 0, 0)
        $loop.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $loop.Checked = $LoopChecked
        $loop.Add_CheckedChanged({
            param($sender, $eventArgs)
            Set-LoopToggleVisual ([System.Windows.Forms.CheckBox]$sender)
        })
        Set-LoopToggleVisual $loop
        $panel.Controls.Add($loop)
    }

    return [pscustomobject]@{
        Panel = $panel
        Check = $check
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

