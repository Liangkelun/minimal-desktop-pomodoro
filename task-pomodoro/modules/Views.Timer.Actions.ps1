# This file is dot-sourced by TaskPomodoro.ps1. It owns Pomodoro UI action wrappers, not timer view rendering.

function Start-PomodoroFromUi([string]$TaskId) {
    if (-not (Test-PomodoroRuntimeIdle)) {
        $result = New-PomodoroOperationResult $false "" "" $false $null
        $result.MessageKey = "TimerAlreadyRunning"
        return $result
    }
    $planned = 0
    if (Test-PomodoroStartNeedsPlan $TaskId) {
        $text = [Microsoft.VisualBasic.Interaction]::InputBox((T "PomodoroPlanPrompt"), (T "EstimatedPomodoros"), "1")
        if ([string]::IsNullOrWhiteSpace($text)) { return New-PomodoroOperationResult $false "" "" $false $null }
        try { $planned = [int]$text } catch { $planned = 0 }
        if ($planned -le 0) {
            [System.Windows.Forms.MessageBox]::Show((T "PomodoroPlanInvalid"), (T "AppTitle")) | Out-Null
            return New-PomodoroOperationResult $false "" "" $false $null
        }
    }
    return Invoke-PomodoroStartWorkflow $TaskId $planned ($script:ActiveView -eq "today")
}

function Confirm-AdditionalPomodorosFromUi {
    if (-not (Test-PomodoroCompletionNeedsAdditionalPlan)) { return }
    $text = [Microsoft.VisualBasic.Interaction]::InputBox((T "PomodoroAddPrompt"), (T "EstimatedPomodoros"), "1")
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    try { $count = [int]$text } catch { $count = 0 }
    if ($count -le 0) {
        [System.Windows.Forms.MessageBox]::Show((T "PomodoroAddInvalid"), (T "AppTitle")) | Out-Null
        return
    }
    Invoke-PomodoroAddEstimateWorkflow $count | Out-Null
}

function Complete-PomodoroFromUi {
    if (Test-PomodoroRuntimeStarterPhase) {
        return Complete-TaskStarterFromUi
    }
    Confirm-AdditionalPomodorosFromUi
    return Invoke-PomodoroCompleteWorkflow
}

function Complete-PomodoroTickFromUi {
    try {
        return Complete-PomodoroFromUi
    }
    finally {
        Complete-PomodoroRuntimeCompletion
    }
}