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
    $label.ForeColor = [System.Drawing.Color]::FromArgb(17, 24, 39)
    $label.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 2)
    $label.Font = New-Object System.Drawing.Font -ArgumentList @($label.Font.FontFamily, ($label.Font.Size + 2.0), [System.Drawing.FontStyle]::Bold)
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
    if (-not [string]::IsNullOrWhiteSpace($CustomPath) -and (Test-Path -LiteralPath $CustomPath)) {
        return $CustomPath
    }
    $catalogPath = Get-AudioCatalogDefaultPath $Kind
    if (-not [string]::IsNullOrWhiteSpace($catalogPath)) {
        return $catalogPath
    }
    switch ($Kind) {
        "start" { return Resolve-AudioFile $CustomPath "ding.wav" }
        "end" { return Resolve-AudioFile $CustomPath "Alarm01.wav" }
        "work" { return Resolve-AudioFile $CustomPath "chimes.wav" }
        "break" { return Resolve-AudioFile $CustomPath "chord.wav" }
        "starter" { return Resolve-AudioFile $CustomPath "chimes.wav" }
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
        if ($null -ne $tag.Library) { $item = New-CustomAudioLibraryItem $dialog.FileName; $tag.Library.Items.Add($item) | Out-Null; $tag.Library.SelectedItem = $item; Set-AudioLibraryDropDownWidth $tag.Library; Set-AudioLibraryTooltip $tag.Library }
        $Button.Text = "...*"
        Set-Status ((T "AudioSelected") + ": " + [System.IO.Path]::GetFileName($dialog.FileName))
        if ($null -eq $tag.Library) {
            Play-AudioPreview $tag
        }
    }
}

function New-VolumeSettingControl([int]$Value) {
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill; $panel.ColumnCount = 2; $panel.RowCount = 1; $panel.Margin = New-Object System.Windows.Forms.Padding(0); $panel.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null; $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 56))) | Out-Null
    $slider = New-Object System.Windows.Forms.TrackBar
    $slider.Minimum = 0; $slider.Maximum = 100; $slider.TickFrequency = 10; $slider.SmallChange = 5; $slider.LargeChange = 10; $slider.Value = [Math]::Max(0, [Math]::Min(100, $Value))
    $slider.Dock = [System.Windows.Forms.DockStyle]::Fill; $slider.AutoSize = $false; $slider.Height = 30; $slider.Margin = New-Object System.Windows.Forms.Padding(0, 3, 4, 0)
    $label = New-Object System.Windows.Forms.Label
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill; $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight; $label.AutoSize = $false; $label.MinimumSize = New-Object System.Drawing.Size(56, 0); $label.Margin = New-Object System.Windows.Forms.Padding(0); $label.BackColor = $panel.BackColor; $label.Text = "$($slider.Value)%"
    $slider.Tag = $label
    $slider.Add_Scroll({ param($sender, $eventArgs) $sender.Tag.Text = "$($sender.Value)%"; Set-BackgroundAudioVolume ([int]$sender.Value) })
    $slider.Add_MouseUp({ param($sender, $eventArgs) Play-VolumePreview ([int]$sender.Value) })
    $panel.Controls.Add($slider, 0, 0); $panel.Controls.Add($label, 1, 0)
    return [pscustomobject]@{ Panel = $panel; Slider = $slider; Label = $label }
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

function Set-AudioLibraryTooltip([System.Windows.Forms.ComboBox]$Library) {
    if ($null -eq $Library -or $null -eq $Library.Tag -or -not ($Library.Tag.PSObject.Properties.Name -contains "ToolTip")) { return }
    $label = ""
    if ($null -ne $Library.SelectedItem) { $label = [string]$Library.SelectedItem.Label }
    if (-not [string]::IsNullOrWhiteSpace($label)) { $Library.Tag.ToolTip.SetToolTip($Library, $label) }
}

function Set-AudioLibraryDropDownWidth([System.Windows.Forms.ComboBox]$Library) {
    if ($null -eq $Library) { return }
    $width = [Math]::Max(220, [int]$Library.Width)
    foreach ($item in $Library.Items) {
        $label = [string]$item.Label
        if (-not [string]::IsNullOrWhiteSpace($label)) { $width = [Math]::Max($width, [System.Windows.Forms.TextRenderer]::MeasureText($label, $Library.Font).Width + 36) }
    }
    $Library.DropDownWidth = [Math]::Min(520, $width)
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
    $audioToolTip = New-Object System.Windows.Forms.ToolTip
    $library.Dock = [System.Windows.Forms.DockStyle]::Fill; $library.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $library.DisplayMember = "Label"; $library.ValueMember = "Path"; $library.Height = 24; $library.Margin = New-Object System.Windows.Forms.Padding(4, 1, 0, 0)
    foreach ($catalogItem in @(Get-AudioCatalogItemsForKind $Kind)) {
        $library.Items.Add((New-AudioLibraryItem $catalogItem)) | Out-Null
    }
    $button = New-Button "..." 32
    $button.Dock = [System.Windows.Forms.DockStyle]::Fill; $button.Height = 24; $button.Margin = New-Object System.Windows.Forms.Padding(4, 1, 0, 0); $button.Tag = [pscustomobject]@{ State = $AudioState; Property = $Property; Kind = $Kind; Library = $library }
    $button.Add_Click({ param($sender, $eventArgs) Select-AudioFileFromButton $sender })
    $current = [string](Get-ObjectPropertyValue $AudioState $Property); foreach ($item in $library.Items) { if ([string]::Equals([string]$item.Path, $current, [System.StringComparison]::OrdinalIgnoreCase)) { $library.SelectedItem = $item; break } }
    if ($library.SelectedIndex -lt 0 -and -not [string]::IsNullOrWhiteSpace($current)) { $button.Text = "...*"; $custom = New-CustomAudioLibraryItem $current; $library.Items.Add($custom) | Out-Null; $library.SelectedItem = $custom }
    elseif ($library.SelectedIndex -lt 0 -and $library.Items.Count -gt 0) { $library.SelectedIndex = 0 }
    $library.Tag = [pscustomobject]@{ State = $AudioState; Property = $Property; Kind = $Kind; Button = $button; ToolTip = $audioToolTip }
    $library.Add_SelectedIndexChanged({ param($sender, $eventArgs) if ($null -eq $sender.SelectedItem) { return }; $tag = $sender.Tag; $item = $sender.SelectedItem; Set-ObjectPropertyValue $tag.State $tag.Property ([string]$item.Path); if ([bool]$item.IsCustom) { $tag.Button.Text = "...*" } else { $tag.Button.Text = "..." }; Set-AudioLibraryTooltip $sender; Play-AudioPreview $tag })
    Set-AudioLibraryDropDownWidth $library
    Set-AudioLibraryTooltip $library
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
