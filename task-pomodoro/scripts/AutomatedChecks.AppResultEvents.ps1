# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for neutral result-event boundary assertions.

function Invoke-AppResultEventsBoundaryCheck([string]$ModulesDir) {
    $appEvents = Join-Path $ModulesDir "AppResultEvents.ps1"
    $coordinator = Join-Path $ModulesDir "PomodoroCoordinator.ps1"
    $pomodoroEvents = Join-Path $ModulesDir "PomodoroEvents.ps1"
    $taskCommands = Join-Path $ModulesDir "TaskCommands.ps1"
    $taskArchive = Join-Path $ModulesDir "TaskArchive.ps1"
    $viewsCore = Join-Path $ModulesDir "Views.Core.ps1"
    foreach ($requiredFile in @($appEvents, $pomodoroEvents, $coordinator, $taskCommands, $taskArchive, $viewsCore)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1"); $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("AppResultEvents.ps1", "PomodoroEvents.ps1", "TaskCommands.ps1", "TaskArchive.ps1", "PomodoroCoordinator.ps1", "PomodoroEngine.ps1", "PomodoroStarter.ps1", "PomodoroWorkflow.ps1", "Views.Timer.Starter.ps1", "Views.Core.ps1")) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    foreach ($dependent in @("PomodoroEvents.ps1", "TaskCommands.ps1", "TaskArchive.ps1", "PomodoroCoordinator.ps1", "Views.Core.ps1")) { if ([Array]::IndexOf($loadOrder, "AppResultEvents.ps1") -gt [Array]::IndexOf($loadOrder, $dependent)) { throw "AppResultEvents.ps1 must load before $dependent" } }
    $appEventsRaw = Get-Content -LiteralPath $appEvents -Encoding UTF8 -Raw
    foreach ($required in @("function New-AppEvent", "function Add-AppResultEvents", "function Invoke-AppResultEvents", "Invoke-AppResultEvent")) { if ($appEventsRaw -notlike "*$required*") { throw "AppResultEvents.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $appEvents @("System.Windows.Forms", "Set-Status", "Render-CurrentView", "Update-TimerLabels", "Start-BackgroundAudio", "Stop-BackgroundAudio", "Play-StartSound", "Trigger-Reminder", "Append-PomodoroRecord", "Save-Tasks", "Clear-PomodoroTimerForTaskMutation") "AppResultEvents.ps1 must stay neutral and free of concrete event side effects."
    $pomodoroEventsRaw = Get-Content -LiteralPath $pomodoroEvents -Encoding UTF8 -Raw
    foreach ($required in @("function New-PomodoroEvent", "function Add-PomodoroResultEvents", "function New-PomodoroAppendRecordEvent", "function New-PomodoroStartBackgroundAudioEvent", "function New-PomodoroStopBackgroundAudioEvent", "function New-PomodoroPlayStartSoundEvent", "function New-PomodoroTriggerReminderEvent", "function New-PomodoroIncrementTaskEvent", "function New-PomodoroInterruptedRecordEvent", "function New-PomodoroCompletedWorkRecordEvent", "function New-PomodoroCompletedBreakRecordEvent", "function Get-PomodoroElapsedSeconds", "New-AppEvent", "Add-AppResultEvents")) { if ($pomodoroEventsRaw -notlike "*$required*") { throw "PomodoroEvents.ps1 missing required marker: $required" } }
    foreach ($dependent in @("PomodoroEngine.ps1", "PomodoroStarter.ps1", "PomodoroWorkflow.ps1", "Views.Timer.Starter.ps1")) { if ([Array]::IndexOf($loadOrder, "PomodoroEvents.ps1") -gt [Array]::IndexOf($loadOrder, $dependent)) { throw "PomodoroEvents.ps1 must load before $dependent" } }
    Test-FileDoesNotContain $pomodoroEvents @("function Invoke-AppResultEvent", "System.Windows.Forms", "Set-Status", "Render-CurrentView", "Update-TimerLabels", "Start-BackgroundAudio", "Stop-BackgroundAudio", "Play-StartSound", "Trigger-Reminder", "Append-PomodoroRecord", "Save-Tasks", "Clear-PomodoroTimerForTaskMutation") "PomodoroEvents.ps1 must stay limited to Pomodoro event object helpers."
    Test-FileDoesNotContain $coordinator @("function New-AppEvent", "function Add-AppResultEvents", "function Invoke-AppResultEvents", "function New-PomodoroEvent", "function Add-PomodoroResultEvents") "PomodoroCoordinator.ps1 must keep event object helpers in AppResultEvents.ps1 and PomodoroEvents.ps1."
    $coordinatorRaw = Get-Content -LiteralPath $coordinator -Encoding UTF8 -Raw
    foreach ($required in @("function Invoke-AppResultEvent", "TaskTimerInvalidated", "Invoke-PomodoroTaskInvalidationWorkflow", "StartBackgroundAudio", "AppendPomodoroRecord", "IncrementTaskPomodoro", "function Invoke-PomodoroResultEvents")) { if ($coordinatorRaw -notlike "*$required*") { throw "PomodoroCoordinator.ps1 missing result-event handler marker: $required" } }
    "App result-event helpers are separated from Pomodoro side-effect handlers"
}