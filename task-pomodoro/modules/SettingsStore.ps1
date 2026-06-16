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
        WorkMusicFile = Get-DefaultAudioPath "focus-loop.mp3"
        BreakMusicFile = Get-DefaultAudioPath "break-loop.mp3"
        Language = Get-DefaultLanguage
        DailyArchiveHour = 0
        DailyArchiveMinute = 0
        LastDailyArchiveAt = $null
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
    Ensure-SettingsDefaults
    $defaults = Get-DefaultSettings

    $script:Settings.Opacity = Get-ClampedNumber $script:Settings.Opacity $defaults.Opacity 0.30 1.00
    $script:Settings.TaskFontSize = Get-ClampedNumber $script:Settings.TaskFontSize $defaults.TaskFontSize 9.0 32.0
    $script:Settings.WorkMinutes = [int](Get-ClampedNumber $script:Settings.WorkMinutes $defaults.WorkMinutes 1 180)
    $script:Settings.ShortBreakMinutes = [int](Get-ClampedNumber $script:Settings.ShortBreakMinutes $defaults.ShortBreakMinutes 1 60)
    $script:Settings.PomodoroRounds = [int](Get-ClampedNumber $script:Settings.PomodoroRounds $defaults.PomodoroRounds 1 24)
    $script:Settings.WindowWidth = [int](Get-ClampedNumber $script:Settings.WindowWidth $defaults.WindowWidth 300 900)
    $script:Settings.WindowHeight = [int](Get-ClampedNumber $script:Settings.WindowHeight $defaults.WindowHeight 34 900)
    $script:Settings.DailyArchiveHour = Get-ClampedIntegerAllowZero $script:Settings.DailyArchiveHour $defaults.DailyArchiveHour 0 23
    $script:Settings.DailyArchiveMinute = Get-ClampedIntegerAllowZero $script:Settings.DailyArchiveMinute $defaults.DailyArchiveMinute 0 59
    try { $script:Settings.TopMost = [bool]$script:Settings.TopMost } catch { $script:Settings.TopMost = $defaults.TopMost }
    try { $script:Settings.SoundReminder = [bool]$script:Settings.SoundReminder } catch { $script:Settings.SoundReminder = $defaults.SoundReminder }
    try { $script:Settings.StartSoundReminder = [bool]$script:Settings.StartSoundReminder } catch { $script:Settings.StartSoundReminder = $defaults.StartSoundReminder }
    try { $script:Settings.EndSoundReminder = [bool]$script:Settings.EndSoundReminder } catch { $script:Settings.EndSoundReminder = $defaults.EndSoundReminder }
    try { $script:Settings.ColorReminder = [bool]$script:Settings.ColorReminder } catch { $script:Settings.ColorReminder = $defaults.ColorReminder }
    try { $script:Settings.TaskbarReminder = [bool]$script:Settings.TaskbarReminder } catch { $script:Settings.TaskbarReminder = $defaults.TaskbarReminder }
    try { $script:Settings.ToastReminder = [bool]$script:Settings.ToastReminder } catch { $script:Settings.ToastReminder = $defaults.ToastReminder }
    try { $script:Settings.WorkMusic = [bool]$script:Settings.WorkMusic } catch { $script:Settings.WorkMusic = $defaults.WorkMusic }
    try { $script:Settings.BreakMusic = [bool]$script:Settings.BreakMusic } catch { $script:Settings.BreakMusic = $defaults.BreakMusic }
    try { $script:Settings.AutoStartNextPomodoro = [bool]$script:Settings.AutoStartNextPomodoro } catch { $script:Settings.AutoStartNextPomodoro = $defaults.AutoStartNextPomodoro }
    try { $script:Settings.WorkMusicLoop = [bool]$script:Settings.WorkMusicLoop } catch { $script:Settings.WorkMusicLoop = $defaults.WorkMusicLoop }
    try { $script:Settings.BreakMusicLoop = [bool]$script:Settings.BreakMusicLoop } catch { $script:Settings.BreakMusicLoop = $defaults.BreakMusicLoop }
    try { $script:Settings.DesktopShortcutPrompted = [bool]$script:Settings.DesktopShortcutPrompted } catch { $script:Settings.DesktopShortcutPrompted = $defaults.DesktopShortcutPrompted }
    $defaultAudioFiles = @{
        StartSoundFile = Get-DefaultAudioPath "focus-start.wav"
        EndSoundFile = Get-DefaultAudioPath "break-start.wav"
        WorkMusicFile = Get-DefaultAudioPath "focus-loop.mp3"
        BreakMusicFile = Get-DefaultAudioPath "break-loop.mp3"
    }
    $oldFocusLoop = Get-DefaultAudioPath "focus-loop.wav"; if ($script:Settings.WorkMusicFile -eq $oldFocusLoop -and -not [string]::IsNullOrWhiteSpace([string]$defaultAudioFiles.WorkMusicFile)) { $script:Settings.WorkMusicFile = $defaultAudioFiles.WorkMusicFile }
    $oldBreakLoop = Get-DefaultAudioPath "break-loop.wav"; if ($script:Settings.BreakMusicFile -eq $oldBreakLoop -and -not [string]::IsNullOrWhiteSpace([string]$defaultAudioFiles.BreakMusicFile)) { $script:Settings.BreakMusicFile = $defaultAudioFiles.BreakMusicFile }
    foreach ($fileProp in @("StartSoundFile", "EndSoundFile", "WorkMusicFile", "BreakMusicFile")) {
        if ($null -eq $script:Settings.$fileProp -or [string]::IsNullOrWhiteSpace([string]$script:Settings.$fileProp)) {
            $script:Settings.$fileProp = $defaultAudioFiles[$fileProp]
        }
        else {
            $script:Settings.$fileProp = [string]$script:Settings.$fileProp
            if (-not (Test-Path -LiteralPath $script:Settings.$fileProp) -and -not [string]::IsNullOrWhiteSpace($defaultAudioFiles[$fileProp])) {
                $script:Settings.$fileProp = $defaultAudioFiles[$fileProp]
            }
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

function Load-Settings {
    $settingsFile = Get-AppPath "SettingsFile"
    if (-not (Test-Path -LiteralPath $settingsFile)) {
        $script:Settings = Get-DefaultSettings
        Save-Settings
        return
    }

    try {
        $raw = Get-Content -LiteralPath $settingsFile -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            throw "empty settings"
        }
        $script:Settings = $raw | ConvertFrom-Json
        Normalize-Settings
    }
    catch {
        Backup-DataFile $settingsFile "invalid"
        $script:Settings = Get-DefaultSettings
        Save-Settings
    }
}

function Reset-SettingsToDefaults {
    $language = Get-DefaultLanguage
    $lastDailyArchiveAt = $null
    $desktopShortcutPrompted = $false
    if ($null -ne $script:Settings) {
        if ($script:Settings.PSObject.Properties.Name -contains "Language") {
            $language = [string]$script:Settings.Language
        }
        if ($script:Settings.PSObject.Properties.Name -contains "LastDailyArchiveAt") {
            $lastDailyArchiveAt = $script:Settings.LastDailyArchiveAt
        }
        if ($script:Settings.PSObject.Properties.Name -contains "DesktopShortcutPrompted") {
            $desktopShortcutPrompted = [bool]$script:Settings.DesktopShortcutPrompted
        }
    }

    $script:Settings = Get-DefaultSettings
    $script:Settings.Language = $language
    $script:Settings.LastDailyArchiveAt = $lastDailyArchiveAt
    $script:Settings.DesktopShortcutPrompted = $desktopShortcutPrompted
    if ($null -ne $script:Form) {
        $script:Settings.WindowWidth = [int]$script:Form.Width
        $script:Settings.WindowHeight = [int]$script:Form.Height
        $script:Settings.WindowX = [int]$script:Form.Location.X
        $script:Settings.WindowY = [int]$script:Form.Location.Y
        $script:Form.TopMost = [bool]$script:Settings.TopMost
        $script:Form.Opacity = [double]$script:Settings.Opacity
    }
    Normalize-Settings
}

function Save-Settings {
    if ($null -ne $script:Form) {
        $script:Settings.WindowWidth = [int]$script:Form.Width
        $script:Settings.WindowHeight = [int]$script:Form.Height
        $script:Settings.WindowX = [int]$script:Form.Location.X
        $script:Settings.WindowY = [int]$script:Form.Location.Y
        if ($script:WatermarkMode -and $null -ne $script:WatermarkPreviousTopMost) {
            $script:Settings.TopMost = [bool]$script:WatermarkPreviousTopMost
        }
        else {
            $script:Settings.TopMost = [bool]$script:Form.TopMost
        }
        if ($script:WatermarkMode -and $null -ne $script:WatermarkPreviousOpacity) {
            $script:Settings.Opacity = [double]$script:WatermarkPreviousOpacity
        }
        else {
            $script:Settings.Opacity = [double]$script:Form.Opacity
        }
    }
    Normalize-Settings
    Write-JsonAtomic (Get-AppPath "SettingsFile") $script:Settings
}

