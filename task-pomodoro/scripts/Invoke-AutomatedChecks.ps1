param(
    [switch]$SkipSelfTest,
    [switch]$SkipDataFiles,
    [switch]$SelfTestInPlace,
    [switch]$KeepSelfTestCopy,
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$script:HasFailure = $false
$script:Results = New-Object System.Collections.Generic.List[object]

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "AutomatedChecks.Core.ps1")
. (Join-Path $scriptDir "AutomatedChecks.Project.ps1")
. (Join-Path $scriptDir "AutomatedChecks.Boundaries.ps1")
. (Join-Path $scriptDir "AutomatedChecks.AppResultEvents.ps1")
. (Join-Path $scriptDir "AutomatedChecks.NotificationHub.ps1")
. (Join-Path $scriptDir "AutomatedChecks.TaskWorkflow.ps1")
. (Join-Path $scriptDir "AutomatedChecks.TaskMenu.ps1")
. (Join-Path $scriptDir "AutomatedChecks.SettingsView.ps1")
. (Join-Path $scriptDir "AutomatedChecks.PomodoroWorkflow.ps1")
. (Join-Path $scriptDir "AutomatedChecks.PomodoroRuntime.ps1")
. (Join-Path $scriptDir "AutomatedChecks.AudioPlayback.ps1")
. (Join-Path $scriptDir "AutomatedChecks.WatermarkRuntime.ps1")
. (Join-Path $scriptDir "AutomatedChecks.WindowState.ps1")
. (Join-Path $scriptDir "AutomatedChecks.TranslationWorkflow.ps1")
. (Join-Path $scriptDir "AutomatedChecks.TranslationProviders.ps1")
. (Join-Path $scriptDir "AutomatedChecks.TranslationSettings.ps1")
. (Join-Path $scriptDir "AutomatedChecks.TranslationLookup.ps1")
. (Join-Path $scriptDir "AutomatedChecks.WatermarkTranslation.ps1")
. (Join-Path $scriptDir "AutomatedChecks.LegacyTranslation.ps1")

$rootDir = Split-Path -Parent $scriptDir
$workspaceRoot = Split-Path -Parent $rootDir
$mainScript = Join-Path $rootDir "TaskPomodoro.ps1"
$modulesDir = Join-Path $rootDir "modules"
$supportScriptsDir = Join-Path $rootDir "scripts"
$dataDir = Join-Path $rootDir "data"
$configDir = Join-Path $rootDir "config"

Invoke-Check "PowerShell syntax: main script" {
    Test-RequiredFile $mainScript
    Test-PowerShellFile $mainScript
    "Parsed TaskPomodoro.ps1"
}

Invoke-Check "PowerShell syntax: support scripts" {
    $files = @(Get-ChildItem -LiteralPath $supportScriptsDir -Filter "*.ps1" -File)
    foreach ($file in $files) {
        Test-PowerShellFile $file.FullName
    }
    "Parsed $($files.Count) support scripts"
}

Invoke-Check "PowerShell syntax: modules" {
    if (-not (Test-Path -LiteralPath $modulesDir -PathType Container)) {
        throw "Missing modules directory: $modulesDir"
    }
    $files = @(Get-ChildItem -LiteralPath $modulesDir -Filter "*.ps1" -File)
    foreach ($file in $files) {
        Test-PowerShellFile $file.FullName
    }
    "Parsed $($files.Count) modules"
}

Invoke-Check "Release metadata" {
    $versionFile = Join-Path $rootDir "VERSION"
    $gitignoreFile = Join-Path $workspaceRoot ".gitignore"
    Test-RequiredFile $gitignoreFile
    Test-RequiredFile (Join-Path $workspaceRoot "README.md")
    Test-RequiredFile (Join-Path $workspaceRoot "CHANGELOG.md")
    Test-RequiredFile (Join-Path $workspaceRoot "LICENSE")
    Test-RequiredFile (Join-Path $workspaceRoot "docs\audio-sources.md")
    Test-RequiredFile (Join-Path $workspaceRoot "docs\release-checklist.md")
    Test-RequiredFile (Join-Path $workspaceRoot "docs\translation-api-and-dictionary.md")
    Test-RequiredFile $versionFile

    $version = (Get-Content -LiteralPath $versionFile -Encoding UTF8 -Raw).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+([-.][0-9A-Za-z.-]+)?$') {
        throw "VERSION must be semver-like. Current value: $version"
    }
    $gitignore = Get-Content -LiteralPath $gitignoreFile -Encoding UTF8 -Raw
    foreach ($requiredIgnore in @("task-pomodoro/data/", "task-pomodoro/config/", "task-pomodoro/launch.log", "task-pomodoro/update.log", "dist/")) {
        if ($gitignore -notlike "*$requiredIgnore*") {
            throw ".gitignore missing runtime ignore pattern: $requiredIgnore"
        }
    }

    "Release metadata present; version=$version"
}

Invoke-Check "Module load order" {
    $mainRaw = Get-Content -LiteralPath $mainScript -Encoding UTF8 -Raw
    $moduleOrderScript = Join-Path $modulesDir "ModuleLoadOrder.ps1"
    Test-RequiredFile $moduleOrderScript
    . $moduleOrderScript
    $expectedModules = @(Get-TaskPomodoroModuleLoadOrder)
    if ($expectedModules.Count -lt 1) {
        throw "TaskPomodoro module load order is empty."
    }
    if ($mainRaw -notlike "*ModuleLoadOrder.ps1*" -or $mainRaw -notlike "*Get-TaskPomodoroModuleLoadOrder*" -or $mainRaw -notlike "*-IncludeSelfTest:`$SelfTest*") {
        throw "TaskPomodoro.ps1 must load modules through ModuleLoadOrder.ps1 and load SelfTest modules only for -SelfTest."
    }
    $loadedSet = @{}
    foreach ($module in $expectedModules) {
        if ($loadedSet.ContainsKey($module)) {
            throw "Module load order contains duplicate module: $module"
        }
        Test-RequiredFile (Join-Path $modulesDir $module)
        $loadedSet[$module] = $true
    }
    $moduleFiles = @(Get-ChildItem -LiteralPath $modulesDir -Filter "*.ps1" -File | Where-Object { $_.Name -ne "ModuleLoadOrder.ps1" } | ForEach-Object { $_.Name })
    $notLoaded = @($moduleFiles | Where-Object { -not $loadedSet.ContainsKey($_) })
    if ($notLoaded.Count -gt 0) {
        throw "Modules are present but not listed in load order:`n$($notLoaded -join "`n")"
    }
    "Module load order has single source; modules=$($expectedModules.Count)"
}


Invoke-Check "Inbox startup persistence" {
    Test-InboxStartupStatePreserved $mainScript
}

Invoke-Check "Self-test module boundaries" {
    $moduleOrderScript = Join-Path $modulesDir "ModuleLoadOrder.ps1"
    . $moduleOrderScript
    $runtimeModules = @(Get-TaskPomodoroModuleLoadOrder -IncludeSelfTest:$false)
    foreach ($moduleName in $runtimeModules) { if ($moduleName -like "SelfTest*.ps1") { throw "Normal app startup must not load SelfTest module: $moduleName" } }
    $modules = @(Get-TaskPomodoroModuleLoadOrder -IncludeSelfTest:$true)
    $expectedSelfTestModules = @("SelfTest.Support.ps1", "SelfTest.Tasks.ps1", "SelfTest.Configuration.ps1", "SelfTest.TaskLinks.ps1", "SelfTest.Pomodoro.ps1", "SelfTest.InboxExecution.ps1", "SelfTest.Ui.ps1", "SelfTest.ps1")
    $lastIndex = -1
    foreach ($moduleName in $expectedSelfTestModules) {
        $index = [Array]::IndexOf($modules, $moduleName)
        if ($index -lt 0 -or $index -le $lastIndex) { throw "Self-test modules must load in this order: $($expectedSelfTestModules -join ', ')." }
        $lastIndex = $index
    }

    $selfTestPath = Join-Path $modulesDir "SelfTest.ps1"
    $selfTestRaw = Get-Content -LiteralPath $selfTestPath -Encoding UTF8 -Raw
    foreach ($delegate in @("Invoke-SelfTestTaskScenarios", "Invoke-SelfTestConfigurationScenarios", "Invoke-SelfTestTaskLinkScenarios", "Invoke-SelfTestPomodoroScenarios", "Invoke-SelfTestInboxExecutionScenarios", "Invoke-SelfTestUiScenarios", "Invoke-SelfTestEndTaskScenario")) {
        if ($selfTestRaw -notlike "*$delegate*") { throw "SelfTest.ps1 must delegate through $delegate." }
    }
    Test-FileDoesNotContain $selfTestPath @('__selftest', 'New-TaskObject', 'Move-TaskInView', 'Add-Task', 'Pin-TaskToTop', 'Invoke-TaskDefaultAction', 'Set-TaskTitle', 'Complete-Task', 'Uncomplete-Task', 'Delete-Task', 'Archive-CompletedTasksBefore', 'End-Task', 'Get-DoneTasks', 'Get-TaskById', 'Get-IsoNow', 'completedAt', 'scheduledFor') 'SelfTest.ps1 must not contain inline task scenario code.'
    Test-FileDoesNotContain $selfTestPath @("ConvertTo-ProcessQuotedArgument", "Get-DesktopShortcutName", "Get-DefaultLanguage", "Get-AudioCatalogItemsForKind", "Protect-TranslationSecret", "Get-WatermarkTranslationLocalResult", "New-CustomAudioLibraryItem", "Apply-StarterSettingsControls", "ConvertTo-EncodedPowerShellCommand", "New-AppRelaunchScript", "Start-AppInstanceLock") "SelfTest.ps1 must not contain inline configuration/audio/translation scenario code."
    Test-FileDoesNotContain $selfTestPath @("Set-TaskDetails", "ConvertTo-TaskLinks", "Ensure-TaskDefaults", "Get-FirstTaskLink", "Get-TaskLinksText", "Resolve-TaskLinkTarget", "Add-OpenTaskLinkMenuItem", "SelfTestOpenTaskLinkId", "Set-Item -Path Function:\Open-TaskLink") "SelfTest.ps1 must not contain inline task-link scenario code."
    Test-FileDoesNotContain $selfTestPath @("Start-Pomodoro", "Pause-Pomodoro", "Continue-Pomodoro", "Stop-Pomodoro", "Start-TaskStarter", "Complete-TaskStarter", "Complete-Pomodoro", "Complete-Break", "TaskTimerInvalidated", "PomodoroSessionStartedCount") "SelfTest.ps1 must not contain inline Pomodoro/starter scenario code."
    Test-FileDoesNotContain $selfTestPath @("New-Object System.Windows.Forms.ListBox", "New-Object System.Windows.Forms.Panel", "New-Object System.Windows.Forms.Button", "TaskPomodoroResizableForm", "Resize-WindowForTaskRows", "Enter-WatermarkMode", "Start-WatermarkTranslationMode", "Show-TranslationSettingsDialog", "Show-WatermarkTranslationResult", "Start-WatermarkTranslationClipboardListener") "SelfTest.ps1 must not contain inline UI/watermark scenario code."

    $requiredMarkersByModule = @(
        @{ File = "SelfTest.Tasks.ps1"; Required = @("function Invoke-SelfTestTaskScenarios", "function Invoke-SelfTestEndTaskScenario", "AfterEditScenarios", "Archive-CompletedTasksBefore", "End-Task") },
        @{ File = "SelfTest.Configuration.ps1"; Required = @("function Invoke-SelfTestConfigurationScenarios", "Get-AudioCatalogItemsForKind", "Protect-TranslationSecret", "ConvertTo-EncodedPowerShellCommand", "New-AppRelaunchScript", "Start-AppInstanceLock") },
        @{ File = "SelfTest.TaskLinks.ps1"; Required = @("function Invoke-SelfTestTaskLinkScenarios", "Resolve-TaskLinkTarget", "Set-Item -Path Function:\Open-TaskLink", "Remove-Variable -Name SelfTestOpenTaskLinkId", "Remove-Item -LiteralPath") },
        @{ File = "SelfTest.Pomodoro.ps1"; Required = @("function Invoke-SelfTestPomodoroScenarios", "finally", "Stop-Pomodoro", "AutoStartNextPomodoro = `$true") },
        @{ File = "SelfTest.InboxExecution.ps1"; Required = @("function Invoke-SelfTestInboxExecutionScenarios", "Invoke-InboxCreateWorkflow", "Get-ExecutionRecords", "Complete-DailyContinuationPrompt", "pomodoro_paused", "pomodoro_resumed") },
        @{ File = "SelfTest.Ui.ps1"; Required = @("function Invoke-SelfTestUiScenarios", "finally", "Stop-TranslationRuntime", "Stop-TranslationClipboardListener", "Exit-WatermarkMode", "TranslationClipboardListenerEnabled = `$false") }
    )
    $selfTestPomodoroPath = Join-Path $modulesDir "SelfTest.Pomodoro.ps1"
    $selfTestTasksPath = Join-Path $modulesDir "SelfTest.Tasks.ps1"
    Test-FileDoesNotContain $selfTestPomodoroPath @('$script:TimerState', '$script:TimerPhase', '$script:SecondsRemaining', '$script:CurrentPomodoroTaskId') "SelfTest Pomodoro scenarios must read runtime state through PomodoroRuntime.Queries.ps1 facade."
    Test-FileDoesNotContain $selfTestTasksPath @('$script:TimerState', '$script:TimerPhase', '$script:SecondsRemaining', '$script:CurrentPomodoroTaskId') "SelfTest task scenarios must read runtime state through PomodoroRuntime.Queries.ps1 facade."
    $selfTestPomodoroRaw = Get-Content -LiteralPath $selfTestPomodoroPath -Encoding UTF8 -Raw
    foreach ($required in @("Get-PomodoroRuntimeTimerViewSnapshot", "Test-PomodoroRuntimeIdle")) { if ($selfTestPomodoroRaw -notlike "*$required*") { throw "SelfTest.Pomodoro.ps1 must keep runtime query facade marker: $required" } }
    $selfTestTasksRaw = Get-Content -LiteralPath $selfTestTasksPath -Encoding UTF8 -Raw
    if ($selfTestTasksRaw -notlike "*Test-PomodoroRuntimeIdle*") { throw "SelfTest.Tasks.ps1 must keep runtime idle query marker." }

    foreach ($entry in $requiredMarkersByModule) {
        $raw = Get-Content -LiteralPath (Join-Path $modulesDir $entry.File) -Encoding UTF8 -Raw
        foreach ($required in $entry.Required) { if ($raw -notlike "*$required*") { throw "$($entry.File) missing required marker: $required" } }
    }
    "Self-test task, configuration, task-link, Pomodoro, and UI scenarios are split and cleanup markers are present"
}
Invoke-Check "Architecture boundaries" {
    foreach ($taskModule in @("TaskModel.ps1", "TaskStore.ps1", "TaskQueries.ps1", "TaskOrdering.ps1", "TaskCommands.ps1", "TaskWorkflow.ps1")) {
        Test-FileDoesNotContain (Join-Path $modulesDir $taskModule) @(
            "System.Windows.Forms",
            "MessageBox",
            "Render-CurrentView",
            "Set-Status",
            "Set-ActiveView",
            "Update-TimerLabels"
        ) "$taskModule must not directly call UI APIs."
    }

    $pomodoroBoundaryTerms = @('$script:PomodorosFile', "System.Windows.Forms", "MessageBox", "Render-CurrentView", "Set-Status", "Set-ActiveView", "Update-TimerLabels", "Start-BackgroundAudio", "Stop-BackgroundAudio", "Play-StartSound", "Play-EndSound", "Trigger-Reminder", "Append-PomodoroRecord", "Save-Tasks")
    foreach ($pomodoroModule in @("PomodoroResults.ps1", "PomodoroEvents.ps1", "PomodoroFormat.ps1", "PomodoroEngine.ps1", "PomodoroInlineCountdown.ps1", "PomodoroStarter.ps1")) {
        Test-FileDoesNotContain (Join-Path $modulesDir $pomodoroModule) $pomodoroBoundaryTerms "$pomodoroModule must return state results instead of driving UI."
    }

    Test-FileDoesNotContain (Join-Path $modulesDir "PomodoroRecords.ps1") @(
        "System.Windows.Forms",
        "MessageBox",
        "Render-CurrentView",
        "Set-Status",
        "Set-ActiveView",
        "Update-TimerLabels"
    ) "PomodoroRecords.ps1 must stay free of UI effects."

    Test-FileDoesNotContain (Join-Path $modulesDir "Storage.ps1") @(
        '$script:DataDir',
        '$script:ConfigDir',
        '$script:BackupDir',
        '$script:RootDir'
    ) "Storage.ps1 must use AppState path accessors."

    Test-FileDoesNotContain (Join-Path $modulesDir "SettingsStore.ps1") @(
        '$script:SettingsFile'
    ) "SettingsStore.ps1 must use AppState path accessors."

    Test-FileDoesNotContain (Join-Path $modulesDir "TaskStore.ps1") @(
        '$script:TasksFile'
    ) "TaskStore.ps1 must use AppState path accessors."

    foreach ($translationModule in @(Get-ChildItem -LiteralPath $modulesDir -Filter "WatermarkTranslation*.ps1" -File)) {
        Test-FileDoesNotContain $translationModule.FullName @(
            "Clipboard]::SetText",
            "Clipboard]::SetDataObject",
            "Set-Clipboard",
            "SendKeys",
            "Ctrl+C",
            "^c"
        ) "$($translationModule.Name) may read the clipboard only when explicitly enabled; it must not write clipboard content or simulate copy."
    }

    "Business modules respect current UI boundary rules"
}


Invoke-Check "Automated checks helper boundaries" {
    $coreHelper = Join-Path $supportScriptsDir "AutomatedChecks.Core.ps1"
    $projectHelper = Join-Path $supportScriptsDir "AutomatedChecks.Project.ps1"
    $boundaryHelper = Join-Path $supportScriptsDir "AutomatedChecks.Boundaries.ps1"
    $appResultEventsHelper = Join-Path $supportScriptsDir "AutomatedChecks.AppResultEvents.ps1"
    $notificationHubHelper = Join-Path $supportScriptsDir "AutomatedChecks.NotificationHub.ps1"
    $taskWorkflowHelper = Join-Path $supportScriptsDir "AutomatedChecks.TaskWorkflow.ps1"
    $taskMenuHelper = Join-Path $supportScriptsDir "AutomatedChecks.TaskMenu.ps1"
    $settingsViewHelper = Join-Path $supportScriptsDir "AutomatedChecks.SettingsView.ps1"
    $pomodoroWorkflowHelper = Join-Path $supportScriptsDir "AutomatedChecks.PomodoroWorkflow.ps1"
    $pomodoroRuntimeHelper = Join-Path $supportScriptsDir "AutomatedChecks.PomodoroRuntime.ps1"
    $audioPlaybackHelper = Join-Path $supportScriptsDir "AutomatedChecks.AudioPlayback.ps1"
    $watermarkRuntimeHelper = Join-Path $supportScriptsDir "AutomatedChecks.WatermarkRuntime.ps1"
    $windowStateHelper = Join-Path $supportScriptsDir "AutomatedChecks.WindowState.ps1"
    $translationWorkflowHelper = Join-Path $supportScriptsDir "AutomatedChecks.TranslationWorkflow.ps1"
    $translationProvidersHelper = Join-Path $supportScriptsDir "AutomatedChecks.TranslationProviders.ps1"
    $translationSettingsHelper = Join-Path $supportScriptsDir "AutomatedChecks.TranslationSettings.ps1"
    $translationLookupHelper = Join-Path $supportScriptsDir "AutomatedChecks.TranslationLookup.ps1"
    $watermarkTranslationHelper = Join-Path $supportScriptsDir "AutomatedChecks.WatermarkTranslation.ps1"
    $legacyTranslationHelper = Join-Path $supportScriptsDir "AutomatedChecks.LegacyTranslation.ps1"
    Test-FileDoesNotContain $coreHelper @("TaskPomodoro", "SELFTEST", "TASK_POMODORO", "Translation dictionary", "TaskPomodoroChecks", "Invoke-MainSelfTest", "New-IsolatedProjectCopy") "AutomatedChecks.Core.ps1 must stay generic."
    Test-FileDoesNotContain $projectHelper @('Invoke-Check "') "AutomatedChecks.Project.ps1 must not orchestrate checks."
    Test-FileDoesNotContain $boundaryHelper @('Invoke-Check "') "AutomatedChecks.Boundaries.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $appResultEventsHelper @('Invoke-Check "') "AutomatedChecks.AppResultEvents.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $notificationHubHelper @('Invoke-Check "') "AutomatedChecks.NotificationHub.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $taskWorkflowHelper @('Invoke-Check "') "AutomatedChecks.TaskWorkflow.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $taskMenuHelper @('Invoke-Check "') "AutomatedChecks.TaskMenu.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $settingsViewHelper @('Invoke-Check "') "AutomatedChecks.SettingsView.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $pomodoroWorkflowHelper @('Invoke-Check "') "AutomatedChecks.PomodoroWorkflow.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $pomodoroRuntimeHelper @('Invoke-Check "') "AutomatedChecks.PomodoroRuntime.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $audioPlaybackHelper @('Invoke-Check "') "AutomatedChecks.AudioPlayback.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $watermarkRuntimeHelper @('Invoke-Check "') "AutomatedChecks.WatermarkRuntime.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $windowStateHelper @('Invoke-Check "') "AutomatedChecks.WindowState.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $translationWorkflowHelper @('Invoke-Check "') "AutomatedChecks.TranslationWorkflow.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $translationProvidersHelper @('Invoke-Check "') "AutomatedChecks.TranslationProviders.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $translationSettingsHelper @('Invoke-Check "') "AutomatedChecks.TranslationSettings.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $translationLookupHelper @('Invoke-Check "') "AutomatedChecks.TranslationLookup.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $watermarkTranslationHelper @('Invoke-Check "') "AutomatedChecks.WatermarkTranslation.ps1 must provide reusable boundary assertions without orchestrating checks."
    Test-FileDoesNotContain $legacyTranslationHelper @('Invoke-Check "') "AutomatedChecks.LegacyTranslation.ps1 must provide reusable boundary assertions without orchestrating checks."
    "Automated check helper boundaries are clean"
}

Invoke-Check "App result-event boundaries" { Invoke-AppResultEventsBoundaryCheck $modulesDir }
Invoke-Check "Task workflow boundaries" { Invoke-TaskWorkflowBoundaryCheck $modulesDir }
Invoke-Check "Pomodoro workflow boundaries" { Invoke-PomodoroWorkflowBoundaryCheck $modulesDir }
Invoke-Check "Pomodoro runtime boundaries" { Invoke-PomodoroRuntimeBoundaryCheck $modulesDir }
Invoke-Check "Watermark runtime boundaries" { Invoke-WatermarkRuntimeBoundaryCheck $modulesDir }
Invoke-Check "Translation workflow boundaries" { Invoke-TranslationWorkflowBoundaryCheck $modulesDir }
Invoke-Check "Translation provider boundaries" { Invoke-TranslationProviderBoundaryCheck $modulesDir }
Invoke-Check "Translation settings boundaries" { Invoke-TranslationSettingsBoundaryCheck $modulesDir }
Invoke-Check "Translation lookup boundaries" { Invoke-TranslationLookupBoundaryCheck $modulesDir }
Invoke-Check "Task menu helper boundaries" { Invoke-TaskMenuHelperBoundaryCheck $modulesDir }
Invoke-Check "Settings view boundaries" { Invoke-SettingsViewBoundaryCheck $modulesDir }
Invoke-Check "Notification hub boundaries" { Invoke-NotificationHubBoundaryCheck $modulesDir }
Invoke-Check "Audio playback module boundaries" { Invoke-AudioPlaybackBoundaryCheck $modulesDir }
Invoke-Check "Window state boundaries" { Invoke-WindowStateBoundaryCheck $modulesDir }
Invoke-Check "Watermark translation module boundaries" { Invoke-WatermarkTranslationBoundaryCheck $modulesDir }
Invoke-Check "Legacy translation wrapper boundaries" { Invoke-LegacyTranslationWrapperBoundaryCheck $modulesDir }
Invoke-Check "File size guardrails" {
    $hardChecks = @(
        @{ Path = $mainScript; Max = 600 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.Core.ps1"; Max = 160 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.Project.ps1"; Max = 180 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.Boundaries.ps1"; Max = 10 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.AppResultEvents.ps1"; Max = 80 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.NotificationHub.ps1"; Max = 40 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.TaskWorkflow.ps1"; Max = 100 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.TaskMenu.ps1"; Max = 140 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.SettingsView.ps1"; Max = 70 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.PomodoroWorkflow.ps1"; Max = 100 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.PomodoroRuntime.ps1"; Max = 90 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.AudioPlayback.ps1"; Max = 50 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.WatermarkRuntime.ps1"; Max = 150 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.WindowState.ps1"; Max = 100 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.TranslationWorkflow.ps1"; Max = 120 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.TranslationProviders.ps1"; Max = 90 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.TranslationSettings.ps1"; Max = 100 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.TranslationLookup.ps1"; Max = 90 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.WatermarkTranslation.ps1"; Max = 100 },
        @{ Path = Join-Path $supportScriptsDir "AutomatedChecks.LegacyTranslation.ps1"; Max = 90 },
        @{ Path = Join-Path $modulesDir "AppState.ps1"; Max = 90 },
        @{ Path = Join-Path $modulesDir "TaskModel.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "TaskStore.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TaskQueries.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TaskOrdering.ps1"; Max = 220 },
        @{ Path = Join-Path $modulesDir "TaskCommands.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "TaskWorkflow.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TaskDetails.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "TaskArchive.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "TaskFormat.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "PomodoroRecords.ps1"; Max = 60 },
        @{ Path = Join-Path $modulesDir "AudioPlayback.ps1"; Max = 110 },
        @{ Path = Join-Path $modulesDir "PomodoroAudio.ps1"; Max = 130 },
        @{ Path = Join-Path $modulesDir "PomodoroEffects.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "PomodoroSession.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "PomodoroPlanning.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "AppResultEvents.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "PomodoroCoordinator.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "PomodoroResults.ps1"; Max = 60 },
        @{ Path = Join-Path $modulesDir "PomodoroEvents.ps1"; Max = 50 },
        @{ Path = Join-Path $modulesDir "PomodoroFormat.ps1"; Max = 50 },
        @{ Path = Join-Path $modulesDir "PomodoroEngine.ps1"; Max = 230 },
        @{ Path = Join-Path $modulesDir "PomodoroInlineCountdown.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "PomodoroStarter.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "PomodoroWorkflow.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "PomodoroRuntime.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "PomodoroRuntime.Queries.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "PomodoroRuntimeState.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "AppRelaunch.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "AppMaintenance.ps1"; Max = 160 },
        @{ Path = Join-Path $modulesDir "WindowStateCoordinator.ps1"; Max = 150 },
        @{ Path = Join-Path $modulesDir "WindowPlacement.ps1"; Max = 60 },
        @{ Path = Join-Path $modulesDir "WindowChrome.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "WatermarkRuntime.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "WatermarkMode.ps1"; Max = 130 },
        @{ Path = Join-Path $modulesDir "TranslationPlatform.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "WatermarkTranslation.Platform.ps1"; Max = 30 },
        @{ Path = Join-Path $modulesDir "TranslationProviders.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "TranslationRules.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TranslationLookup.ps1"; Max = 90 },        @{ Path = Join-Path $modulesDir "TranslationDictionaryIndex.ps1"; Max = 110 },
        @{ Path = Join-Path $modulesDir "TranslationDictionary.ps1"; Max = 110 },
        @{ Path = Join-Path $modulesDir "TranslationDictionaryInstall.ps1"; Max = 130 },
        @{ Path = Join-Path $modulesDir "WatermarkTranslation.ps1"; Max = 20 },
        @{ Path = Join-Path $modulesDir "TranslationWorkflow.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TranslationBridge.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TranslationRuntime.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "WatermarkTranslation.Dictionary.ps1"; Max = 20 },
        @{ Path = Join-Path $modulesDir "TranslationSelection.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "SettingsSchema.ps1"; Max = 220 },
        @{ Path = Join-Path $modulesDir "SettingsStore.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "NotificationHub.ps1"; Max = 90 },
        @{ Path = Join-Path $modulesDir "SettingsWorkflow.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "Storage.ps1"; Max = 120 }
    )
    $softChecks = @(
        @{ Path = Join-Path $supportScriptsDir "Invoke-AutomatedChecks.ps1"; Max = 700 },
        @{ Path = Join-Path $supportScriptsDir "New-ReleasePackage.ps1"; Max = 500 },
        @{ Path = Join-Path $supportScriptsDir "Measure-RuntimeFootprint.ps1"; Max = 220 },
        @{ Path = Join-Path $modulesDir "ModuleLoadOrder.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "AudioCatalog.ps1"; Max = 160 },
        @{ Path = Join-Path $modulesDir "DesktopShortcut.ps1"; Max = 260 },
        @{ Path = Join-Path $modulesDir "UiTimer.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "BottomChrome.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "WindowSize.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "WindowDrag.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "HelpSurface.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "WatermarkGhostSurface.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "WatermarkMode.Menu.ps1"; Max = 60 },
        @{ Path = Join-Path $modulesDir "WatermarkToggleButton.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "WatermarkTranslation.Surface.ps1"; Max = 50 },
        @{ Path = Join-Path $modulesDir "TranslationSurface.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "TranslationSettings.ps1"; Max = 190 },
        @{ Path = Join-Path $modulesDir "WatermarkTranslation.Settings.ps1"; Max = 20 },
        @{ Path = Join-Path $modulesDir "UiText.ps1"; Max = 500 },
        @{ Path = Join-Path $modulesDir "UiText.Execution.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "Views.Core.ps1"; Max = 200 },
        @{ Path = Join-Path $modulesDir "Views.Task.Controls.ps1"; Max = 230 },
        @{ Path = Join-Path $modulesDir "Views.Task.Interactions.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "Views.Task.Gestures.ps1"; Max = 90 },
        @{ Path = Join-Path $modulesDir "Views.Task.Items.ps1"; Max = 90 },
        @{ Path = Join-Path $modulesDir "Views.Task.Events.ps1"; Max = 60 },
        @{ Path = Join-Path $modulesDir "Views.Task.Hover.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "Views.Task.ListDrawing.ps1"; Max = 170 },
        @{ Path = Join-Path $modulesDir "Views.Task.Selection.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "Views.Task.DetailsDialog.ps1"; Max = 280 },
        @{ Path = Join-Path $modulesDir "Views.Task.Edit.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "Views.Menu.Builders.ps1"; Max = 90 },
        @{ Path = Join-Path $modulesDir "Views.Task.LinkMenu.ps1"; Max = 60 },
        @{ Path = Join-Path $modulesDir "Views.Task.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "Views.Task.Menu.Actions.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "Views.Task.Menu.ps1"; Max = 110 },
        @{ Path = Join-Path $modulesDir "Views.Timer.Actions.ps1"; Max = 110 },
        @{ Path = Join-Path $modulesDir "Views.Timer.ps1"; Max = 170 },
        @{ Path = Join-Path $modulesDir "Views.Timer.Starter.ps1"; Max = 160 },
        @{ Path = Join-Path $modulesDir "Views.Done.Stats.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "Views.Done.Drawing.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "Views.Done.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "Views.More.ps1"; Max = 70 },
        @{ Path = Join-Path $modulesDir "Views.Settings.ps1"; Max = 170 },
        @{ Path = Join-Path $modulesDir "Views.Settings.Controls.ps1"; Max = 270 },
        @{ Path = Join-Path $modulesDir "Views.Settings.General.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "Views.Settings.Pomodoro.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "Views.Settings.Starter.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "Views.Settings.Apply.ps1"; Max = 110 },
        @{ Path = Join-Path $modulesDir "Views.Timer.SettingsDialog.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "SelfTest.Support.ps1"; Max = 100 },
        @{ Path = Join-Path $modulesDir "SelfTest.Tasks.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "SelfTest.Configuration.ps1"; Max = 170 },
        @{ Path = Join-Path $modulesDir "SelfTest.TaskLinks.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "SelfTest.Pomodoro.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "SelfTest.Ui.ps1"; Max = 270 },
        @{ Path = Join-Path $modulesDir "SelfTest.ps1"; Max = 110 }
    )

    $details = @("Hard guardrails:")
    $details += foreach ($check in $hardChecks) {
        Test-MaxLineCount ([string]$check.Path) ([int]$check.Max)
    }
    $details += "Soft guardrails:"
    $details += foreach ($check in $softChecks) {
        Test-SoftMaxLineCount ([string]$check.Path) ([int]$check.Max)
    }
    $details -join "`n"
}
Invoke-Check "Required launch and media assets" {
    Test-RequiredFile (Join-Path $rootDir "StartTaskPomodoro.vbs")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\focus-start.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\start-soft.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\start-clear.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\end-soft.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\end-clear.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\focus-loop.mp3")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\focus-loop.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\Degrees_of_Clarity.mp3")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\A_Measured_Turn.mp3")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\Clearwater_Path.mp3")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\break-start.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\break-loop.mp3")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\break-loop.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\white-noise-loop.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\pink-noise-loop.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\brown-noise-loop.wav")
    Test-TranslationDictionaryFile (Join-Path $rootDir "assets\dict\watermark-translation-core.tsv")
    Test-RequiredFile (Join-Path $rootDir "assets\dict\NOTICE.md")
    Test-RequiredFile (Join-Path $rootDir "assets\help\translation-api-setup.html")
    Test-RequiredFile (Join-Path $rootDir "assets\sponsor\wechat-sponsor.jpg")

    $icons = @(
        Join-Path $rootDir "assets\icon\task-pomodoro-g-desktop.ico"
        Join-Path $rootDir "assets\icon\task-pomodoro-g.ico"
        Join-Path $rootDir "assets\icon\task-pomodoro.ico"
    )
    if (-not (@($icons | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -gt 0)) {
        throw "No application icon was found."
    }
    "Launch script, audio, dictionary, and icon assets are present"
}

if ($SkipDataFiles) {
    Add-CheckResult "Runtime data schema" "SKIP" "Skipped by -SkipDataFiles"
}
else {
    Invoke-Check "Runtime data schema" {
        $tasksFile = Join-Path $dataDir "tasks.json"
        if (Test-Path -LiteralPath $tasksFile -PathType Leaf) {
            $tasks = Read-JsonFile $tasksFile
            $taskItems = @($tasks)
            $allowedStatuses = @("todo", "done", "archived")
            foreach ($task in $taskItems) {
                Assert-Property $task "id" "task"
                Assert-Property $task "title" "task $($task.id)"
                Assert-Property $task "status" "task $($task.id)"
                Assert-Property $task "createdAt" "task $($task.id)"
                Assert-Property $task "pomodoroCount" "task $($task.id)"
                if ($allowedStatuses -notcontains [string]$task.status) {
                    throw "task $($task.id) has invalid status '$($task.status)'"
                }
                [DateTimeOffset]::Parse([string]$task.createdAt) | Out-Null
                if ([int]$task.pomodoroCount -lt 0) {
                    throw "task $($task.id) has negative pomodoroCount"
                }
            }
        }

        $settingsFile = Join-Path $configDir "settings.json"
        if (Test-Path -LiteralPath $settingsFile -PathType Leaf) {
            $settings = Read-JsonFile $settingsFile
            Assert-Property $settings "Opacity" "settings"
            Assert-Property $settings "WorkMinutes" "settings"
            Assert-Property $settings "ShortBreakMinutes" "settings"
            $opacity = [double]$settings.Opacity
            $taskFontSize = 15.0
            if ($settings.PSObject.Properties.Name -contains "TaskFontSize") {
                $taskFontSize = [double]$settings.TaskFontSize
            }
            $workMinutes = [int]$settings.WorkMinutes
            $breakMinutes = [int]$settings.ShortBreakMinutes
            if ($opacity -lt 0.30 -or $opacity -gt 1.00) {
                throw "settings Opacity is outside 0.30..1.00"
            }
            if ($taskFontSize -lt 9.0 -or $taskFontSize -gt 32.0) {
                throw "settings TaskFontSize is outside 9.0..32.0"
            }
            if ($workMinutes -lt 1 -or $workMinutes -gt 180) {
                throw "settings WorkMinutes is outside 1..180"
            }
            if ($breakMinutes -lt 1 -or $breakMinutes -gt 60) {
                throw "settings ShortBreakMinutes is outside 1..60"
            }
        }

        $pomodorosFile = Join-Path $dataDir "pomodoros.jsonl"
        if (Test-Path -LiteralPath $pomodorosFile -PathType Leaf) {
            $lineNumber = 0
            $allowedResults = @("completed", "interrupted", "skipped_break", "break_completed")
            foreach ($line in Get-Content -LiteralPath $pomodorosFile -Encoding UTF8) {
                $lineNumber++
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                $record = $line | ConvertFrom-Json
                Assert-Property $record "id" "pomodoro line $lineNumber"
                Assert-Property $record "startedAt" "pomodoro line $lineNumber"
                Assert-Property $record "endedAt" "pomodoro line $lineNumber"
                Assert-Property $record "plannedMinutes" "pomodoro line $lineNumber"
                Assert-Property $record "actualMinutes" "pomodoro line $lineNumber"
                Assert-Property $record "result" "pomodoro line $lineNumber"
                if ($allowedResults -notcontains [string]$record.result) {
                    throw "pomodoro line $lineNumber has invalid result '$($record.result)'"
                }
            }
        }

        if (Test-Path -LiteralPath $dataDir -PathType Container) {
            $runtimeFiles = @(Get-ChildItem -LiteralPath $dataDir -File -Include "*.json", "*.jsonl" -Recurse -ErrorAction SilentlyContinue)
            foreach ($file in $runtimeFiles) {
                $raw = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
                if ($raw -match "__selftest") {
                    throw "self-test marker found in runtime data: $($file.FullName)"
                }
            }
        }

        "Runtime data files are parseable"
    }
}

if ($SkipSelfTest) {
    Add-CheckResult "Invalid data recovery" "SKIP" "Skipped with -SkipSelfTest"
}
else {
    Invoke-Check "Invalid data recovery" {
        $copy = New-IsolatedProjectCopy $rootDir
        try {
            $copyRoot = [string]$copy.RootDir
            $copyDataDir = Join-Path $copyRoot "data"
            if (-not (Test-Path -LiteralPath $copyDataDir)) {
                New-Item -ItemType Directory -Path $copyDataDir | Out-Null
            }
            "{ invalid json" | Set-Content -LiteralPath (Join-Path $copyDataDir "tasks.json") -Encoding UTF8
            $output = Invoke-MainSelfTest $copyRoot $true
            $backups = @(Get-ChildItem -LiteralPath (Join-Path $copyDataDir "backups") -Filter "tasks.json.*.invalid.bak" -File -ErrorAction SilentlyContinue)
            if ($backups.Count -lt 1) {
                throw "Invalid tasks.json did not produce an invalid backup."
            }
            "$output`nInvalid backup count=$($backups.Count)"
        }
        finally {
            Remove-IsolatedProjectCopy ([string]$copy.CleanupDir)
        }
    }
}

if ($SkipSelfTest) {
    Add-CheckResult "Main script self-test" "SKIP" "Skipped by -SkipSelfTest"
}
else {
    Invoke-Check "Main script self-test" {
        $selfTestRoot = $rootDir
        $cleanupDir = ""
        if (-not $SelfTestInPlace) {
            $copy = New-IsolatedProjectCopy $rootDir
            $selfTestRoot = [string]$copy.RootDir
            $cleanupDir = [string]$copy.CleanupDir
        }
        try {
            $output = Invoke-MainSelfTest $selfTestRoot ([bool]$SelfTestInPlace)
        }
        finally {
            if (-not $SelfTestInPlace -and -not $KeepSelfTestCopy) {
                Remove-IsolatedProjectCopy $cleanupDir
            }
        }

        $mode = "isolated copy"
        if ($SelfTestInPlace) {
            $mode = "current workspace"
        }
        "$output`nMode: $mode"
    }
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportParent = Split-Path -Parent $ReportPath
    if (-not [string]::IsNullOrWhiteSpace($reportParent) -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -ItemType Directory -Path $reportParent | Out-Null
    }
    $script:Results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

if ($script:HasFailure) {
    exit 1
}

exit 0
