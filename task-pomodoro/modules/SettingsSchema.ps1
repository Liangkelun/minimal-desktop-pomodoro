# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-DefaultSettings {
    return [pscustomobject]@{
        TopMost = $true
        Opacity = 1.00
        TaskFontSize = 15.0
        BlurTextStyle = "dark"
        WorkMinutes = 25
        ShortBreakMinutes = 5
        PomodoroRounds = 1
        AutoStartNextPomodoro = $true
        StarterMinutes = 3
        StarterMusic = $true
        StarterMusicLoop = $true
        StarterMusicFile = Get-DefaultAudioPath "Clearwater_Path.mp3"
        StarterDefaultAction = "pomodoro"
        AudioDefaultsVersion = 2
        AudioVolume = 100
        SoundReminder = $true
        StartSoundReminder = $true
        EndSoundReminder = $true
        ColorReminder = $true
        TaskbarReminder = $true
        ToastReminder = $false
        WorkMusic = $true
        BreakMusic = $true
        WorkMusicLoop = $true
        BreakMusicLoop = $true
        StartSoundFile = Get-DefaultAudioPath "focus-start.wav"
        EndSoundFile = Get-DefaultAudioPath "break-start.wav"
        WorkMusicFile = Get-DefaultAudioPath "A_Measured_Turn.mp3"
        BreakMusicFile = Get-DefaultAudioPath "break-loop.mp3"
        TranslationProvider = "disabled"
        TranslationTargetLanguage = "zh"
        TranslationFontSize = 15.0
        TranslationSurfaceStyle = "follow"
        TranslationSurfaceColorMode = "black-on-white"
        TranslationClipboardListenerEnabled = $false
        TranslationPerformanceMode = "memory"
        TranslationUiaSelectionEnabled = $true
        TranslationMonthlyLimit = 100000
        TranslationCustomEndpoint = ""
        TranslationCustomApiKeyProtected = ""
        TranslationDeepLMode = "free"
        TranslationDeepLApiKeyProtected = ""
        TranslationBaiduAppId = ""
        TranslationBaiduSecretProtected = ""
        TranslationDictionaryPath = ""
        TranslationDictionaryFetchOrder = "remote-first"
        TranslationMonthKey = ""
        TranslationMonthChars = 0
        TranslationLastError = ""
        ShortcutF2EditTaskEnabled = $true
        ShortcutCtrlDoubleClickOpenLinkEnabled = $true
        Language = Get-DefaultLanguage
        DailyArchiveHour = 0
        DailyArchiveMinute = 0
        LastDailyArchiveAt = $null
        LastDailyContinuationPromptDate = ""
        DesktopShortcutPrompted = $false
        WindowX = $null
        WindowY = $null
        WindowWidth = 300
        WindowHeight = 390
    }
}

function Ensure-SettingsDefaults {
    $defaults = Get-DefaultSettings
    foreach ($prop in $defaults.PSObject.Properties) {
        Ensure-Property $script:Settings $prop.Name $prop.Value
    }
}
function Get-ClampedNumber([object]$Value, [double]$Default, [double]$Min, [double]$Max) {
    try {
        $number = [double]$Value
    }
    catch {
        $number = $Default
    }

    if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -le 0) {
        $number = $Default
    }
    if ($number -lt $Min) {
        $number = $Min
    }
    if ($number -gt $Max) {
        $number = $Max
    }
    return $number
}
function Get-ClampedIntegerAllowZero([object]$Value, [int]$Default, [int]$Min, [int]$Max) {
    try {
        $number = [int]$Value
    }
    catch {
        $number = $Default
    }
    if ($number -lt $Min) {
        $number = $Min
    }
    if ($number -gt $Max) {
        $number = $Max
    }
    return $number
}
function Normalize-Settings {
    $needsAudioDefaultsMigration = $true
    if ($null -ne $script:Settings -and ($script:Settings.PSObject.Properties.Name -contains "AudioDefaultsVersion")) {
        try { $needsAudioDefaultsMigration = ([int]$script:Settings.AudioDefaultsVersion -lt 2) } catch { $needsAudioDefaultsMigration = $true }
    }
    Ensure-SettingsDefaults
    $defaults = Get-DefaultSettings

    $script:Settings.Opacity = Get-ClampedNumber $script:Settings.Opacity $defaults.Opacity 0.30 1.00
    $script:Settings.TaskFontSize = Get-ClampedNumber $script:Settings.TaskFontSize $defaults.TaskFontSize 9.0 32.0
    $script:Settings.WorkMinutes = [int](Get-ClampedNumber $script:Settings.WorkMinutes $defaults.WorkMinutes 1 180)
    $script:Settings.ShortBreakMinutes = [int](Get-ClampedNumber $script:Settings.ShortBreakMinutes $defaults.ShortBreakMinutes 1 60)
    $script:Settings.PomodoroRounds = [int](Get-ClampedNumber $script:Settings.PomodoroRounds $defaults.PomodoroRounds 1 24)
    $script:Settings.StarterMinutes = [int](Get-ClampedNumber $script:Settings.StarterMinutes $defaults.StarterMinutes 1 30)
    $script:Settings.WindowWidth = [int](Get-ClampedNumber $script:Settings.WindowWidth $defaults.WindowWidth 300 900)
    $script:Settings.WindowHeight = [int](Get-ClampedNumber $script:Settings.WindowHeight $defaults.WindowHeight 34 900)
    $script:Settings.DailyArchiveHour = Get-ClampedIntegerAllowZero $script:Settings.DailyArchiveHour $defaults.DailyArchiveHour 0 23
    $script:Settings.DailyArchiveMinute = Get-ClampedIntegerAllowZero $script:Settings.DailyArchiveMinute $defaults.DailyArchiveMinute 0 59
    $script:Settings.AudioVolume = Get-ClampedIntegerAllowZero $script:Settings.AudioVolume $defaults.AudioVolume 0 100
    $script:Settings.TranslationFontSize = Get-ClampedNumber $script:Settings.TranslationFontSize $defaults.TranslationFontSize 9.0 32.0
    $script:Settings.TranslationMonthlyLimit = [int](Get-ClampedNumber $script:Settings.TranslationMonthlyLimit $defaults.TranslationMonthlyLimit 1000 2000000)
    $script:Settings.TranslationMonthChars = Get-ClampedIntegerAllowZero $script:Settings.TranslationMonthChars $defaults.TranslationMonthChars 0 200000000
    foreach ($obsoleteTranslationPositionProp in @("TranslationDetailX", "TranslationDetailY")) { if ($script:Settings.PSObject.Properties.Name -contains $obsoleteTranslationPositionProp) { $script:Settings.PSObject.Properties.Remove($obsoleteTranslationPositionProp) } }
    try { $script:Settings.TopMost = [bool]$script:Settings.TopMost } catch { $script:Settings.TopMost = $defaults.TopMost }
    try { $script:Settings.SoundReminder = [bool]$script:Settings.SoundReminder } catch { $script:Settings.SoundReminder = $defaults.SoundReminder }
    try { $script:Settings.StartSoundReminder = [bool]$script:Settings.StartSoundReminder } catch { $script:Settings.StartSoundReminder = $defaults.StartSoundReminder }
    try { $script:Settings.EndSoundReminder = [bool]$script:Settings.EndSoundReminder } catch { $script:Settings.EndSoundReminder = $defaults.EndSoundReminder }
    try { $script:Settings.ColorReminder = [bool]$script:Settings.ColorReminder } catch { $script:Settings.ColorReminder = $defaults.ColorReminder }
    try { $script:Settings.TaskbarReminder = [bool]$script:Settings.TaskbarReminder } catch { $script:Settings.TaskbarReminder = $defaults.TaskbarReminder }
    try { $script:Settings.ToastReminder = [bool]$script:Settings.ToastReminder } catch { $script:Settings.ToastReminder = $defaults.ToastReminder }
    try { $script:Settings.WorkMusic = [bool]$script:Settings.WorkMusic } catch { $script:Settings.WorkMusic = $defaults.WorkMusic }
    try { $script:Settings.BreakMusic = [bool]$script:Settings.BreakMusic } catch { $script:Settings.BreakMusic = $defaults.BreakMusic }
    try { $script:Settings.StarterMusic = [bool]$script:Settings.StarterMusic } catch { $script:Settings.StarterMusic = $defaults.StarterMusic }
    try { $script:Settings.StarterMusicLoop = [bool]$script:Settings.StarterMusicLoop } catch { $script:Settings.StarterMusicLoop = $defaults.StarterMusicLoop }
    try { $script:Settings.AutoStartNextPomodoro = [bool]$script:Settings.AutoStartNextPomodoro } catch { $script:Settings.AutoStartNextPomodoro = $defaults.AutoStartNextPomodoro }
    try { $script:Settings.WorkMusicLoop = [bool]$script:Settings.WorkMusicLoop } catch { $script:Settings.WorkMusicLoop = $defaults.WorkMusicLoop }
    try { $script:Settings.BreakMusicLoop = [bool]$script:Settings.BreakMusicLoop } catch { $script:Settings.BreakMusicLoop = $defaults.BreakMusicLoop }
    try { $script:Settings.DesktopShortcutPrompted = [bool]$script:Settings.DesktopShortcutPrompted } catch { $script:Settings.DesktopShortcutPrompted = $defaults.DesktopShortcutPrompted }
    try { $script:Settings.TranslationClipboardListenerEnabled = [bool]$script:Settings.TranslationClipboardListenerEnabled } catch { $script:Settings.TranslationClipboardListenerEnabled = $defaults.TranslationClipboardListenerEnabled }
    try { $script:Settings.TranslationUiaSelectionEnabled = [bool]$script:Settings.TranslationUiaSelectionEnabled } catch { $script:Settings.TranslationUiaSelectionEnabled = $defaults.TranslationUiaSelectionEnabled }
    if ([string]$script:Settings.TranslationPerformanceMode -notin @("fast", "memory")) { $script:Settings.TranslationPerformanceMode = $defaults.TranslationPerformanceMode }
    try { $script:Settings.ShortcutF2EditTaskEnabled = [bool]$script:Settings.ShortcutF2EditTaskEnabled } catch { $script:Settings.ShortcutF2EditTaskEnabled = $defaults.ShortcutF2EditTaskEnabled }
    try { $script:Settings.ShortcutCtrlDoubleClickOpenLinkEnabled = [bool]$script:Settings.ShortcutCtrlDoubleClickOpenLinkEnabled } catch { $script:Settings.ShortcutCtrlDoubleClickOpenLinkEnabled = $defaults.ShortcutCtrlDoubleClickOpenLinkEnabled }
    if ([string]$script:Settings.TranslationProvider -notin @("disabled", "custom", "deepl", "baidu")) { $script:Settings.TranslationProvider = $defaults.TranslationProvider }
    if ([string]$script:Settings.TranslationTargetLanguage -notin @("zh", "en", "ja", "ko", "fr", "de", "es")) { $script:Settings.TranslationTargetLanguage = $defaults.TranslationTargetLanguage }
    if ([string]$script:Settings.TranslationSurfaceStyle -notin @("follow", "blur", "solid")) { $script:Settings.TranslationSurfaceStyle = $defaults.TranslationSurfaceStyle }
    if ([string]$script:Settings.TranslationSurfaceColorMode -notin @("black-on-white", "white-on-black")) { $script:Settings.TranslationSurfaceColorMode = $defaults.TranslationSurfaceColorMode }
    if ([string]$script:Settings.TranslationDeepLMode -notin @("free", "pro")) { $script:Settings.TranslationDeepLMode = $defaults.TranslationDeepLMode }
    if ([string]$script:Settings.TranslationDictionaryFetchOrder -notin @("remote-first", "local-first")) { $script:Settings.TranslationDictionaryFetchOrder = $defaults.TranslationDictionaryFetchOrder }
    foreach ($translationTextProp in @("TranslationCustomEndpoint", "TranslationCustomApiKeyProtected", "TranslationDeepLApiKeyProtected", "TranslationBaiduAppId", "TranslationBaiduSecretProtected", "TranslationDictionaryPath", "TranslationMonthKey", "TranslationLastError", "LastDailyContinuationPromptDate")) {
        if ($null -eq $script:Settings.$translationTextProp) { $script:Settings.$translationTextProp = "" } else { $script:Settings.$translationTextProp = [string]$script:Settings.$translationTextProp }
    }
    $defaultAudioFiles = @{
        StartSoundFile = Get-DefaultAudioPath "focus-start.wav"
        EndSoundFile = Get-DefaultAudioPath "break-start.wav"
        WorkMusicFile = Get-DefaultAudioPath "A_Measured_Turn.mp3"
        BreakMusicFile = Get-DefaultAudioPath "break-loop.mp3"
        StarterMusicFile = Get-DefaultAudioPath "Clearwater_Path.mp3"
    }
    $oldFocusLoop = Get-DefaultAudioPath "focus-loop.wav"; if ($script:Settings.WorkMusicFile -eq $oldFocusLoop -and -not [string]::IsNullOrWhiteSpace([string]$defaultAudioFiles.WorkMusicFile)) { $script:Settings.WorkMusicFile = $defaultAudioFiles.WorkMusicFile }
    $oldBreakLoop = Get-DefaultAudioPath "break-loop.wav"; if ($script:Settings.BreakMusicFile -eq $oldBreakLoop -and -not [string]::IsNullOrWhiteSpace([string]$defaultAudioFiles.BreakMusicFile)) { $script:Settings.BreakMusicFile = $defaultAudioFiles.BreakMusicFile }
    if ($needsAudioDefaultsMigration) {
        $oldFocusMp3 = Get-DefaultAudioPath "focus-loop.mp3"
        if ($script:Settings.WorkMusicFile -eq $oldFocusMp3 -or $script:Settings.WorkMusicFile -eq $oldFocusLoop) {
            $script:Settings.WorkMusicFile = $defaultAudioFiles.WorkMusicFile
        }
        if ($script:Settings.StarterMusicFile -eq $oldFocusMp3 -or $script:Settings.StarterMusicFile -eq $oldFocusLoop) {
            $script:Settings.StarterMusicFile = $defaultAudioFiles.StarterMusicFile
        }
        $script:Settings.StarterMusic = $true
        $script:Settings.StarterMusicLoop = $true
        $script:Settings.AudioDefaultsVersion = 2
    }
    foreach ($fileProp in @("StartSoundFile", "EndSoundFile", "WorkMusicFile", "BreakMusicFile", "StarterMusicFile")) {
        if ($null -eq $script:Settings.$fileProp -or [string]::IsNullOrWhiteSpace([string]$script:Settings.$fileProp)) {
            $script:Settings.$fileProp = $defaultAudioFiles[$fileProp]
        }
        else {
            $script:Settings.$fileProp = [string]$script:Settings.$fileProp
        }
    }
    if ($script:Settings.Language -eq "en-US") {
        $script:Settings.Language = "en-US"
    }
    elseif ([string]$script:Settings.Language -like "zh*") {
        $script:Settings.Language = "zh-CN"
    }
    else {
        $script:Settings.Language = $defaults.Language
    }
    if ([string]$script:Settings.StarterDefaultAction -notin @("pomodoro", "again", "complete", "stop")) {
        $script:Settings.StarterDefaultAction = $defaults.StarterDefaultAction
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$script:Settings.LastDailyArchiveAt)) {
        try {
            [DateTimeOffset]::Parse([string]$script:Settings.LastDailyArchiveAt) | Out-Null
            $script:Settings.LastDailyArchiveAt = [string]$script:Settings.LastDailyArchiveAt
        }
        catch {
            $script:Settings.LastDailyArchiveAt = $null
        }
    }
}
