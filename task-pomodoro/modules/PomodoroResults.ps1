# This file is dot-sourced by TaskPomodoro.ps1. It owns Pomodoro operation result object shape.

function New-PomodoroOperationResult(
    [bool]$Ok,
    [string]$StatusKey,
    [string]$View,
    [bool]$ShouldUpdateTimer,
    [object]$Data,
    [object[]]$Events = @()
) {
    return [pscustomobject]@{
        Ok = $Ok
        StatusKey = $StatusKey
        MessageKey = ""
        View = $View
        ShouldRender = $false
        ShouldUpdateTimer = $ShouldUpdateTimer
        Data = $Data
        Events = @($Events)
    }
}