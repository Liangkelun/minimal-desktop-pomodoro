# This file is dot-sourced before task list drawing. Keep inline countdown projection read-only.

function Get-TaskInlineCountdownState([string]$TaskId) {
    $snapshot = Get-PomodoroRuntimeInlineCountdownSnapshot $TaskId
    if ($null -eq $snapshot) { return $null }
    return [pscustomobject]@{
        TaskId = [string]$snapshot.TaskId
        Kind = [string]$snapshot.Kind
        RemainingSeconds = [int]$snapshot.RemainingSeconds
        Text = Format-Time ([int]$snapshot.RemainingSeconds)
    }
}

function Get-TaskInlineCountdownText([string]$TaskId) {
    $state = Get-TaskInlineCountdownState $TaskId
    if ($null -eq $state) { return "" }
    return [string]$state.Text
}
