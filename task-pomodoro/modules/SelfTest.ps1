# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Invoke-SelfTest {
    Invoke-WithNamedMutex (Get-AppScopedMutexName "data") { Invoke-SelfTestCore } 120000
}
function Invoke-SelfTestCore {
    $originalTasks = @($script:Tasks)
    $originalInbox = @($script:InboxItems)
    $selfTestStartedAt = Get-Date
    $originalTasksRaw = $null
    $originalSettingsRaw = $null
    $originalPomodorosRaw = $null
    $originalInboxRaw = $null
    $originalTimerStateRaw = $null
    $originalBehaviorEventsRaw = $null
    if (Test-Path -LiteralPath $script:TasksFile) {
        $originalTasksRaw = Get-Content -LiteralPath $script:TasksFile -Encoding UTF8 -Raw
    }
    if (Test-Path -LiteralPath $script:SettingsFile) {
        $originalSettingsRaw = Get-Content -LiteralPath $script:SettingsFile -Encoding UTF8 -Raw
    }
    if (Test-Path -LiteralPath $script:PomodorosFile) {
        $originalPomodorosRaw = Get-Content -LiteralPath $script:PomodorosFile -Encoding UTF8 -Raw
    }
    if (Test-Path -LiteralPath $script:InboxFile) {
        $originalInboxRaw = Get-Content -LiteralPath $script:InboxFile -Encoding UTF8 -Raw
    }
    if (Test-Path -LiteralPath $script:TimerStateFile) {
        $originalTimerStateRaw = Get-Content -LiteralPath $script:TimerStateFile -Encoding UTF8 -Raw
    }
    if (Test-Path -LiteralPath $script:BehaviorEventsFile) {
        $originalBehaviorEventsRaw = Get-Content -LiteralPath $script:BehaviorEventsFile -Encoding UTF8 -Raw
    }
    try {
        Invoke-SelfTestTaskScenarios { param([string]$TaskId)
            Invoke-SelfTestTaskLinkScenarios $TaskId
        }
        Invoke-SelfTestConfigurationScenarios
        Invoke-SelfTestPomodoroScenarios
        Invoke-SelfTestInboxExecutionScenarios

        Invoke-SelfTestUiScenarios
        Invoke-SelfTestEndTaskScenario

    }
    finally {
        if ($null -ne $originalTasksRaw) {
            Restore-SelfTestFileContent $script:TasksFile $originalTasksRaw
            Load-Tasks
        }
        else {
            $script:Tasks = $originalTasks
            Save-Tasks
        }
        if ($null -ne $originalSettingsRaw) {
            Restore-SelfTestFileContent $script:SettingsFile $originalSettingsRaw
            Load-Settings
        }
        else {
            Save-Settings
        }
        if ($null -ne $originalPomodorosRaw) {
            Restore-SelfTestFileContent $script:PomodorosFile $originalPomodorosRaw
        }
        if ($null -ne $originalInboxRaw) {
            Restore-SelfTestFileContent $script:InboxFile $originalInboxRaw
            Load-Inbox
        }
        else {
            $script:InboxItems = $originalInbox
            Save-Inbox
        }
        if ($null -ne $originalTimerStateRaw) {
            Restore-SelfTestFileContent $script:TimerStateFile $originalTimerStateRaw
        }
        else {
            Clear-PomodoroRuntimeStateFile
        }
        if ($null -ne $originalBehaviorEventsRaw) {
            Restore-SelfTestFileContent $script:BehaviorEventsFile $originalBehaviorEventsRaw
        }
        else {
            Set-Content -LiteralPath $script:BehaviorEventsFile -Value "" -Encoding UTF8 -NoNewline
        }
        Initialize-BehaviorEvents
        Remove-SelfTestBackupArtifacts $selfTestStartedAt
    }
    $openCount = @(Get-OpenTasks).Count
    $todayCount = @(Get-TodayTasks).Count
    Write-Output "SELFTEST_OK open=$openCount today=$todayCount"
}
