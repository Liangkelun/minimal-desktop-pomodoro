# This file is dot-sourced by TaskPomodoro.ps1. It owns Pomodoro text formatting helpers.

function Format-Time([int]$Seconds) {
    if ($Seconds -lt 0) {
        $Seconds = 0
    }
    $minutes = [Math]::Floor($Seconds / 60)
    $remainingSeconds = $Seconds % 60
    return "{0:00}:{1:00}" -f $minutes, $remainingSeconds
}

function Get-TaskStarterText([string]$Value) {
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function Get-TaskStarterLabel {
    $minutes = Get-TaskStarterMinutes
    if ([string]$script:Settings.Language -eq "en-US") { return "Start $minutes min" }
    return (T "TaskStarterMenu") + " $minutes " + (Get-TaskStarterText "5YiG6ZKf")
}

function Get-TaskStarterAgainText {
    $minutes = Get-TaskStarterMinutes
    if ([string]$script:Settings.Language -eq "en-US") { return "Another $minutes min" }
    return (Get-TaskStarterText "5YaN5YGa") + " $minutes " + (Get-TaskStarterText "5YiG6ZKf")
}