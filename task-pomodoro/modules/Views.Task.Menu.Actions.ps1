# This file is dot-sourced before Views.Task.Menu.ps1. Keep menu click actions separate from menu construction.

function Invoke-TaskMenuCompleteAction([string]$TaskId) { Invoke-TaskOperationResult (Invoke-TaskCompleteWorkflow $TaskId) }

function Invoke-TaskMenuUncompleteAction([string]$TaskId) { Invoke-TaskOperationResult (Invoke-TaskUncompleteWorkflow $TaskId) }

function Invoke-TaskMenuScheduleTodayAction([string]$TaskId) { Invoke-TaskOperationResult (Invoke-TaskScheduleTodayWorkflow $TaskId) }

function Invoke-TaskMenuUnscheduleTodayAction([string]$TaskId) { Invoke-TaskOperationResult (Invoke-TaskUnscheduleTodayWorkflow $TaskId) }

function Invoke-TaskMenuEndAction([string]$TaskId) { Invoke-TaskOperationResult (Invoke-TaskEndWorkflow $TaskId) }

function Invoke-TaskMenuPinTodayAction([string]$TaskId) { Invoke-TaskOperationResult (Invoke-TaskPinWorkflow "today" $TaskId) }

function Invoke-TaskMenuPinTasksAction([string]$TaskId) { Invoke-TaskOperationResult (Invoke-TaskPinWorkflow "tasks" $TaskId) }

function Invoke-TaskMenuEditAction([string]$TaskId) { Edit-TaskDetails $TaskId }

function Invoke-TaskMenuStartPomodoroAction([string]$TaskId) { Invoke-AppActionResult (Start-PomodoroFromUi $TaskId) }

function Invoke-TaskMenuStartStarterAction([string]$TaskId) { Invoke-AppActionResult (Invoke-TaskStarterStartWorkflow $TaskId) }

function Invoke-TaskMenuContinueTimerAction([string]$TaskId) { Invoke-AppActionResult (Invoke-PomodoroPauseOrContinueWorkflow) }

function Invoke-TaskMenuPauseTimerAction([string]$TaskId) { Invoke-AppActionResult (Invoke-PomodoroPauseOrContinueWorkflow) }

function Invoke-TaskMenuStopTimerAction([string]$TaskId) { Invoke-AppActionResult (Invoke-PomodoroStopWorkflow) }

function Invoke-TaskMenuStarterSettingsAction([string]$TaskId) { Show-TaskStarterSettingsDialog }

function Invoke-TaskMenuDeleteAction([string]$TaskId) {
    $confirm = [System.Windows.Forms.MessageBox]::Show((T "DeleteTaskConfirm"), (T "DeleteTask"), [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($confirm -eq [System.Windows.Forms.DialogResult]::OK) {
        Invoke-TaskOperationResult (Invoke-TaskDeleteWorkflow $TaskId)
    }
}
