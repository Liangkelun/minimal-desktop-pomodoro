# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Invoke-SelfTestConfigurationScenarios {
    try {
        $quotedArg = ConvertTo-ProcessQuotedArgument "D:\has space\閺傚洦銆?vbs"
        if ($quotedArg -ne '"D:\has space\閺傚洦銆?vbs"') {
            throw "selftest failed: process argument quoting"
        }
        if ((Get-DesktopShortcutName) -notlike "*.lnk") {
            throw "selftest failed: desktop shortcut name"
        }
        if (-not (Test-Path -LiteralPath (Get-DesktopShortcutInstallerPath) -PathType Leaf)) {
            throw "selftest failed: desktop shortcut installer path"
        }
        Clear-AppNotificationHandlers
$script:SelfTestNotificationCount = 0
Register-AppNotificationHandler "SettingsChanged" { param($notification) if ([string]$notification.Type -eq "SettingsChanged" -and [string]$notification.Data["Scope"] -eq "selftest") { $script:SelfTestNotificationCount++ } }
Publish-AppNotification "SettingsChanged" @{ Scope = "selftest"; PreserveWindow = $true } | Out-Null
if ([int]$script:SelfTestNotificationCount -ne 1) { throw "selftest failed: notification hub roundtrip" }
Clear-AppNotificationHandlers
Remove-Variable -Scope Script -Name SelfTestNotificationCount -ErrorAction SilentlyContinue
        if ((Get-DefaultLanguage "zh-CN") -ne "zh-CN" -or (Get-DefaultLanguage "zh-Hans") -ne "zh-CN" -or (Get-DefaultLanguage "en-US") -ne "en-US" -or (Get-DefaultLanguage "fr-FR") -ne "en-US") {
            throw "selftest failed: default language detection"
        }
        foreach ($kind in @("start", "end", "work", "break", "starter")) {
            $audioItems = @(Get-AudioCatalogItemsForKind $kind)
            if ($audioItems.Count -lt 1) { throw "selftest failed: audio catalog empty kind $kind" }
            foreach ($audioItem in $audioItems) {
                if ([string]::IsNullOrWhiteSpace([string]$audioItem.EnLabel) -or [string]::IsNullOrWhiteSpace((ConvertFrom-AudioTextB64 ([string]$audioItem.ZhB64))) -or -not (Test-Path -LiteralPath (Get-AudioCatalogItemPath $audioItem))) {
                    throw "selftest failed: audio catalog item"
                }
            }
        }
        $languageBeforeAudioTest = [string]$script:Settings.Language
        $starterMinutesBeforeAudioTest = [int]$script:Settings.StarterMinutes
        $audioVolumeBeforeAudioTest = [int]$script:Settings.AudioVolume
        $script:Settings.Language = "zh-CN"
        $script:Settings.StarterMinutes = 3
        $script:Settings.AudioVolume = 37
        if ((Get-AudioVolume) -ne 37 -or -not [bool](Get-DefaultSettings).StarterMusicLoop) { throw "selftest failed: audio defaults" }
        $script:Settings.AudioVolume = 150; Normalize-Settings
        if ([int]$script:Settings.AudioVolume -ne 100) { throw "selftest failed: audio volume clamp" }
        $workMusicBeforeMissingPathTest = [string]$script:Settings.WorkMusicFile
        $missingCustomAudioPath = Join-Path $script:DataDir "missing-custom-audio.wav"
        $script:Settings.WorkMusicFile = $missingCustomAudioPath; Normalize-Settings
        if ([string]$script:Settings.WorkMusicFile -ne $missingCustomAudioPath) { throw "selftest failed: missing custom audio path preserved" }
        $script:Settings.WorkMusicFile = $workMusicBeforeMissingPathTest
        $translationDefaults = Get-DefaultSettings
        if ([string]$translationDefaults.TranslationProvider -ne "disabled" -or [int]$translationDefaults.TranslationMonthlyLimit -ne 100000 -or [bool]$translationDefaults.TranslationClipboardListenerEnabled -or [string]$translationDefaults.TranslationPerformanceMode -ne "memory" -or -not [bool]$translationDefaults.TranslationUiaSelectionEnabled -or [double]$translationDefaults.TranslationFontSize -ne 15.0 -or [string]$translationDefaults.TranslationSurfaceStyle -ne "follow" -or [string]$translationDefaults.TranslationSurfaceColorMode -ne "black-on-white" -or [string]$translationDefaults.TranslationDictionaryFetchOrder -ne "remote-first" -or -not [bool]$translationDefaults.ShortcutF2EditTaskEnabled -or -not [bool]$translationDefaults.ShortcutCtrlDoubleClickOpenLinkEnabled) { throw "selftest failed: translation defaults" }
        $translationSecret = "secret-" + [guid]::NewGuid().ToString("N")
        $translationProtected = Protect-TranslationSecret $translationSecret
        if ([string]::IsNullOrWhiteSpace($translationProtected) -or $translationProtected -eq $translationSecret -or (Unprotect-TranslationSecret $translationProtected) -ne $translationSecret) { throw "selftest failed: translation secret roundtrip" }
        $translationSurfaceStyleBefore = [string]$script:Settings.TranslationSurfaceStyle; $script:Settings.TranslationSurfaceStyle = "invalid"; Normalize-Settings; if ([string]$script:Settings.TranslationSurfaceStyle -ne "follow") { throw "selftest failed: translation surface style normalization" }; $script:Settings.TranslationSurfaceStyle = $translationSurfaceStyleBefore
        $translationSurfaceColorModeBefore = [string]$script:Settings.TranslationSurfaceColorMode; $script:Settings.TranslationSurfaceColorMode = "invalid"; Normalize-Settings; if ([string]$script:Settings.TranslationSurfaceColorMode -ne "black-on-white") { throw "selftest failed: translation surface color mode normalization" }; $script:Settings.TranslationSurfaceColorMode = $translationSurfaceColorModeBefore
        $translationFetchOrderBefore = [string]$script:Settings.TranslationDictionaryFetchOrder; $script:Settings.TranslationDictionaryFetchOrder = "invalid"; Normalize-Settings; if ([string]$script:Settings.TranslationDictionaryFetchOrder -ne "remote-first") { throw "selftest failed: translation dictionary fetch order normalization" }; $script:Settings.TranslationDictionaryFetchOrder = $translationFetchOrderBefore
        if ((Convert-TranslationDefinitionToShortText "n. public; adj. shared" 2) -ne "public; shared") { throw "selftest failed: translation short definition cleanup" }
        Clear-TranslationDictionaryCache
        foreach ($translationWord in @("public", "example", "translation", "document", "true", "false", "return", "value")) {
            $translationLocal = Get-TranslationLocalResult $translationWord
            if ($null -eq $translationLocal -or [string]::IsNullOrWhiteSpace([string]$translationLocal.Short)) { throw "selftest failed: translation local dictionary $translationWord" }
        }
        if ((Get-TranslationSelectionKind "hello") -ne "term" -or (Get-TranslationSelectionKind (("a" * 1201))) -ne "") { throw "selftest failed: translation selection length guard" }
        if ((New-CustomAudioLibraryItem "D:\legacy.wav").Label -ne ((ConvertFrom-AudioTextB64 "6Ieq6YCJ") + " - legacy.wav")) { throw "selftest failed: zh custom audio label" }
        $builtInZh = (New-AudioLibraryItem (@(Get-AudioCatalogItemsForKind "work")[0])).Label
        if ($builtInZh.StartsWith((ConvertFrom-AudioTextB64 "5YaF572u") + " - ")) { throw "selftest failed: zh built-in audio label prefix" }
        if ((Get-TaskStarterLabel) -match "\?") { throw "selftest failed: zh starter label placeholder" }
        $starterLoopBeforeHiddenLoopTest = [bool]$script:Settings.StarterMusicLoop; $starterMusicBeforeHiddenLoopTest = [bool]$script:Settings.StarterMusic
        $script:Settings.StarterMusicLoop = $true
        Apply-StarterSettingsControls ([pscustomobject]@{ Minutes = [pscustomobject]@{ Value = 3 }; Music = [pscustomobject]@{ Checked = $false }; MusicLoop = $null; DefaultAction = [pscustomobject]@{ SelectedItem = $null } }) ([pscustomobject]@{ StarterMusicFile = [string]$script:Settings.StarterMusicFile })
        if (-not [bool]$script:Settings.StarterMusicLoop) { throw "selftest failed: starter hidden loop preserved" }
        $script:Settings.StarterMusicLoop = $starterLoopBeforeHiddenLoopTest; $script:Settings.StarterMusic = $starterMusicBeforeHiddenLoopTest
        $script:Settings.Language = "en-US"
        if ((New-CustomAudioLibraryItem "D:\legacy.wav").Label -ne "Custom - legacy.wav") { throw "selftest failed: en custom audio label" }
        if ((New-AudioLibraryItem (@(Get-AudioCatalogItemsForKind "work")[0])).Label.StartsWith("Built-in - ")) { throw "selftest failed: en built-in audio label prefix" }
        $script:Settings.Language = $languageBeforeAudioTest
        $script:Settings.StarterMinutes = $starterMinutesBeforeAudioTest
        $script:Settings.AudioVolume = $audioVolumeBeforeAudioTest
        $decodedCommand = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String((ConvertTo-EncodedPowerShellCommand "Write-Output 'ok'")))
        if ($decodedCommand -ne "Write-Output 'ok'") { throw "selftest failed: encoded powershell command" }
        $relaunchScript = New-AppRelaunchScript 12345 (Join-Path $script:DataDir "restart-selftest.log")
        foreach ($fragment in @('$parentProcessId = 12345', (Get-AppScopedMutexName "instance"), "WaitOne(30000)", '$canStart = $false', "powershell.exe", "-File")) {
            if (-not $relaunchScript.Contains($fragment)) { throw "selftest failed: relaunch helper script" }
        }
        $mutexName = Get-AppScopedMutexName "selftest"
        if ($mutexName -notlike "Local\MinimalDesktopPomodoro-selftest-*") {
            throw "selftest failed: scoped mutex name"
        }
        $probeCreatedNew = $false
        $probeInstanceMutex = New-Object System.Threading.Mutex($true, (Get-AppScopedMutexName "instance"), [ref]$probeCreatedNew)
        try {
            if ($probeCreatedNew) {
                try { $probeInstanceMutex.ReleaseMutex() } catch {}
                if (-not (Start-AppInstanceLock $true)) { throw "selftest failed: unlocked instance mutex should be acquirable" }
                Stop-AppInstanceLock
            }
        }
        finally {
            $probeInstanceMutex.Dispose()
        }
        foreach ($requiredTextKey in @("NoOpenTasks", "NoTodayTasks", "HelpShortcutsText", "ShortcutF2EditTask", "ShortcutCtrlDoubleClickOpenLink", "TaskFontSize", "Close", "DeleteTask", "DeleteTaskConfirm", "DesktopShortcutPromptTitle", "DesktopShortcutPromptBody", "DesktopShortcutMenu", "AudioVolume", "WatermarkToggle", "WatermarkTranslation", "TranslationSettings", "TranslationFontSize", "TranslationSurfaceStyle", "TranslationSurfaceStyleFollow", "TranslationSurfaceStyleBlur", "TranslationSurfaceStyleSolid", "TranslationSurfaceColorMode", "TranslationSurfaceColorModeBlackOnWhite", "TranslationSurfaceColorModeWhiteOnBlack", "TranslationApiGuide", "TranslationUnbindDictionary", "TranslationGetFullDictionary", "TranslationDictionaryLoaded", "TranslationDictionaryUnbound", "TranslationDictionaryUnavailable", "TranslationDictionaryDownloadHelp", "TranslationLocalMiss", "TranslationPrivacyNote", "TranslationPerformanceMode", "TranslationModeFast", "TranslationModeMemory", "TranslationClipboardListener", "TranslationClipboardListenerNote")) {
            if ([string]::IsNullOrWhiteSpace((T $requiredTextKey))) {
                throw "selftest failed: required ui text"
            }
        }
    }
    finally {
        try { Stop-AppInstanceLock } catch {}
    }
}
