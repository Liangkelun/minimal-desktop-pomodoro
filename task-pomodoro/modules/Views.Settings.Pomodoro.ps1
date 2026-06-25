# This file is dot-sourced before Views.Settings.ps1. Keep Pomodoro settings row construction separate from the settings view shell.

function Add-PomodoroSettingsRows([System.Windows.Forms.TableLayoutPanel]$Panel, [object]$AudioState, [int]$StartRow) {
    Add-SettingSection $Panel (T "PomodoroSettings") $StartRow
    $work = New-Object System.Windows.Forms.NumericUpDown
    $work.Minimum = 1; $work.Maximum = 180; $work.Value = [decimal]$script:Settings.WorkMinutes
    Add-SettingRow $Panel (T "WorkMinutes") $work ($StartRow + 1)

    $break = New-Object System.Windows.Forms.NumericUpDown
    $break.Minimum = 1; $break.Maximum = 60; $break.Value = [decimal]$script:Settings.ShortBreakMinutes
    Add-SettingRow $Panel (T "ShortBreakMinutes") $break ($StartRow + 2)

    $startSoundControl = New-AudioSettingControl ([bool]$script:Settings.StartSoundReminder) $AudioState "StartSoundFile" "start" $false $false
    Add-SettingRow $Panel (T "StartSoundReminder") $startSoundControl.Panel ($StartRow + 3)
    $endSoundControl = New-AudioSettingControl ([bool]$script:Settings.EndSoundReminder) $AudioState "EndSoundFile" "end" $false $false
    Add-SettingRow $Panel (T "EndSoundReminder") $endSoundControl.Panel ($StartRow + 4)
    $colorControl = New-CheckOnlyControl ([bool]$script:Settings.ColorReminder)
    Add-SettingRow $Panel (T "ColorReminder") $colorControl.Panel ($StartRow + 5)
    $workMusicControl = New-AudioSettingControl ([bool]$script:Settings.WorkMusic) $AudioState "WorkMusicFile" "work" $true ([bool]$script:Settings.WorkMusicLoop)
    Add-SettingRow $Panel (T "WorkMusic") $workMusicControl.Panel ($StartRow + 6)
    $breakMusicControl = New-AudioSettingControl ([bool]$script:Settings.BreakMusic) $AudioState "BreakMusicFile" "break" $true ([bool]$script:Settings.BreakMusicLoop)
    Add-SettingRow $Panel (T "BreakMusic") $breakMusicControl.Panel ($StartRow + 7)

    return [pscustomobject]@{ Work = $work; Break = $break; StartSound = $startSoundControl; EndSound = $endSoundControl; Color = $colorControl; WorkMusic = $workMusicControl; BreakMusic = $breakMusicControl }
}
