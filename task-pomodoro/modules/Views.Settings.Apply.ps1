# This file is dot-sourced by TaskPomodoro.ps1. It applies settings controls to app state and storage.

function Apply-SettingsControls([object]$Controls) {
    if ($null -eq $Controls) {
        return New-DailyArchiveOperationResult 0
    }

    $selectedLanguage = "zh-CN"
    if ($Controls.Language.SelectedItem -ne $null) {
        $selectedLanguage = [string]$Controls.Language.SelectedItem.Value
    }
    $script:Settings.Language = $selectedLanguage
    $script:Settings.WorkMinutes = [int]$Controls.Work.Value
    $script:Settings.ShortBreakMinutes = [int]$Controls.Break.Value
    $script:Settings.Opacity = [double]($Controls.Opacity.Value / 100)
    $script:Settings.AudioVolume = [int]$Controls.AudioVolume.Value
    $script:Settings.TaskFontSize = [double]$Controls.TaskFont.Value
    $script:Settings.BlurTextStyle = [string]$Controls.BlurText.SelectedItem.Value
    $script:Settings.TopMost = [bool]$Controls.TopMost.Checked
    $script:Settings.DailyArchiveHour = [int]$Controls.DailyArchiveHour.Value
    $script:Settings.DailyArchiveMinute = [int]$Controls.DailyArchiveMinute.Value
    $script:Settings.ShortcutF2EditTaskEnabled = [bool]$Controls.ShortcutF2EditTask.Checked
    $script:Settings.ShortcutCtrlDoubleClickOpenLinkEnabled = [bool]$Controls.ShortcutCtrlDoubleClickOpenLink.Checked
    $script:Settings.SoundReminder = ([bool]$Controls.StartSound.Checked -or [bool]$Controls.EndSound.Checked)
    $script:Settings.StartSoundReminder = [bool]$Controls.StartSound.Checked
    $script:Settings.EndSoundReminder = [bool]$Controls.EndSound.Checked
    $script:Settings.ColorReminder = [bool]$Controls.Color.Checked
    $script:Settings.WorkMusic = [bool]$Controls.WorkMusic.Checked
    $script:Settings.WorkMusicLoop = [bool]$Controls.WorkMusicLoop.Checked
    $script:Settings.BreakMusic = [bool]$Controls.BreakMusic.Checked
    $script:Settings.BreakMusicLoop = [bool]$Controls.BreakMusicLoop.Checked
    Apply-StarterSettingsControls $Controls.Starter $Controls.AudioState
    Apply-TranslationSettingsControls $Controls.Translation
    $script:Settings.StartSoundFile = [string](Get-ObjectPropertyValue $Controls.AudioState "StartSoundFile")
    $script:Settings.EndSoundFile = [string](Get-ObjectPropertyValue $Controls.AudioState "EndSoundFile")
    $script:Settings.WorkMusicFile = [string](Get-ObjectPropertyValue $Controls.AudioState "WorkMusicFile")
    $script:Settings.BreakMusicFile = [string](Get-ObjectPropertyValue $Controls.AudioState "BreakMusicFile")
    Set-WindowChromeTopMost ([bool]$script:Settings.TopMost)
    Set-WatermarkRuntimeConfiguredOpacity ([double]$script:Settings.Opacity)
    $script:Form.Text = T "AppTitle"
    Update-NavText
    Update-WatermarkRuntimeToggleButton
    Update-PomodoroRuntimeAfterGeneralSettingsChange
    Save-GeneralSettings
    Update-TimerLabels
    return (Invoke-DailyArchiveIfDueResult)
}
