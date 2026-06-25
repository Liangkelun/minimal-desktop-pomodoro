# This file is dot-sourced by TaskPomodoro.ps1. It owns Pomodoro running tick progression, not UI rendering.

function New-PomodoroRuntimeTickResult([string]$Kind, [bool]$ShouldUpdateTimer = $false, [bool]$ShouldInvalidateTask = $false) { return [pscustomobject]@{ Kind = $Kind; ShouldUpdateTimer = $ShouldUpdateTimer; ShouldInvalidateTask = $ShouldInvalidateTask } }

function Clear-PomodoroRuntimePauseTracking { $script:PomodoroPausedAtDate = $null; $script:PomodoroPauseThresholdsTriggered = @() }

function New-PomodoroRuntimePauseThresholdTick([int]$ThresholdMinutes, [int]$PausedSeconds) {
    $result = New-PomodoroRuntimeTickResult "pause-threshold"
    Add-Member -InputObject $result -MemberType NoteProperty -Name ThresholdMinutes -Value $ThresholdMinutes -Force
    Add-Member -InputObject $result -MemberType NoteProperty -Name PausedSeconds -Value $PausedSeconds -Force
    Add-Member -InputObject $result -MemberType NoteProperty -Name Phase -Value ([string]$script:TimerPhase) -Force
    Add-Member -InputObject $result -MemberType NoteProperty -Name TaskId -Value ([string]$script:CurrentPomodoroTaskId) -Force
    Add-Member -InputObject $result -MemberType NoteProperty -Name PausedAt -Value $(if ($null -eq $script:PomodoroPausedAtDate) { "" } else { $script:PomodoroPausedAtDate.ToString("yyyy-MM-ddTHH:mm:sszzz") }) -Force
    return $result
}

function Get-PomodoroRuntimePauseThresholdTick {
    if ($null -eq $script:PomodoroPausedAtDate) { return $null }
    if ($script:TimerPhase -notin @("work", "break")) { return $null }
    $pausedSeconds = [int][Math]::Max(0, ((Get-Date) - $script:PomodoroPausedAtDate).TotalSeconds)
    foreach ($threshold in @(5, 10)) {
        if ($pausedSeconds -ge ($threshold * 60) -and @($script:PomodoroPauseThresholdsTriggered) -notcontains $threshold) {
            $script:PomodoroPauseThresholdsTriggered = @($script:PomodoroPauseThresholdsTriggered) + $threshold
            return New-PomodoroRuntimePauseThresholdTick $threshold $pausedSeconds
        }
    }
    return $null
}

function Clear-PomodoroRuntimeCurrentTask { $script:CurrentPomodoroTaskId = $null; $script:CurrentPomodoroTaskTitle = T "UnboundFocus" }

function Set-PomodoroRuntimeCurrentTask([string]$TaskId, [string]$TaskTitle) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        Clear-PomodoroRuntimeCurrentTask
        return
    }
    $script:CurrentPomodoroTaskId = [string]$TaskId
    if ([string]::IsNullOrWhiteSpace($TaskTitle)) { $script:CurrentPomodoroTaskTitle = T "UnboundFocus" }
    else { $script:CurrentPomodoroTaskTitle = [string]$TaskTitle }
}

function Clear-PomodoroRuntimePlannedDuration { $script:CurrentPhasePlannedMinutes = 0 }

function Set-PomodoroRuntimeIdleDuration([int]$PlannedMinutes) { $script:SecondsRemaining = [Math]::Max(0, [int]$PlannedMinutes) * 60 }

function Update-PomodoroRuntimeDuration([int]$PlannedMinutes) {
    $minutes = [Math]::Max(0, [int]$PlannedMinutes)
    if ($script:TimerState -eq "idle") {
        Set-PomodoroRuntimeIdleDuration $minutes
        return
    }

    $oldPlannedSeconds = [Math]::Max(1, [int]$script:CurrentPhasePlannedMinutes * 60)
    $elapsed = $oldPlannedSeconds - [int]$script:SecondsRemaining
    if ($script:TimerState -eq "running" -and $null -ne $script:PomodoroStartedAtDate) {
        $elapsed = [int][Math]::Max(0, ((Get-Date) - $script:PomodoroStartedAtDate).TotalSeconds)
    }
    $script:CurrentPhasePlannedMinutes = $minutes
    $script:SecondsRemaining = [Math]::Max(0, ($minutes * 60) - $elapsed)
    if ($script:TimerState -eq "running") {
        $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    }
}

function Start-PomodoroRuntimePhase([string]$Phase, [int]$PlannedMinutes) {
    Clear-PomodoroRuntimePauseTracking
    $script:TimerPhase = [string]$Phase
    $script:PomodoroStartedAt = Get-IsoNow
    $script:PomodoroStartedAtDate = Get-Date
    $script:CurrentPhasePlannedMinutes = [Math]::Max(0, [int]$PlannedMinutes)
    $script:SecondsRemaining = [int]$script:CurrentPhasePlannedMinutes * 60
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Save-PomodoroRuntimeState
}

function Pause-PomodoroRuntimePhase { $script:SecondsRemaining = [Math]::Max(0, [int][Math]::Ceiling(($script:PomodoroEndAt - (Get-Date)).TotalSeconds)); $script:PomodoroPausedAtDate = Get-Date; $script:PomodoroPauseThresholdsTriggered = @(); $script:TimerState = "paused"; Save-PomodoroRuntimeState }

function Resume-PomodoroRuntimePhase { Clear-PomodoroRuntimePauseTracking; $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining); $script:TimerState = "running"; Save-PomodoroRuntimeState }

function Set-PomodoroRuntimeIdleWorkState([bool]$ClearTask = $true) {
    Clear-PomodoroRuntimePauseTracking
    $script:TimerState = "idle"
    $script:TimerPhase = "work"
    Set-PomodoroRuntimeIdleDuration (Get-PomodoroWorkMinutes)
    if ($ClearTask) { Clear-PomodoroRuntimeCurrentTask }
    Clear-PomodoroRuntimeStateFile
}

function Start-PomodoroRuntimeCompletion {
    if ([bool]$script:TimerCompletionInProgress) { return $false }
    $script:SecondsRemaining = 0
    $script:TimerCompletionInProgress = $true
    return $true
}

function Complete-PomodoroRuntimeCompletion { $script:TimerCompletionInProgress = $false }

function Test-PomodoroRuntimeTaskInvalidationNeeded { return ($script:TimerPhase -in @("starter", "work", "break") -and -not [string]::IsNullOrWhiteSpace([string]$script:CurrentPomodoroTaskId)) }

function Update-PomodoroRuntimeAudioAfterSettingsChange {
    if ($script:TimerState -eq "running") { Start-BackgroundAudio ([string]$script:TimerPhase) }
    elseif ($script:TimerState -ne "paused") { Stop-BackgroundAudio }
}

function Update-PomodoroRuntimeAfterGeneralSettingsChange { Update-PomodoroRuntimeAudioAfterSettingsChange; if ($script:TimerState -eq "idle") { Set-PomodoroRuntimeIdleDuration ([int]$script:Settings.WorkMinutes) } }

function Update-PomodoroRuntimeTick {
    if ($script:TimerState -eq "paused") { $pauseTick = Get-PomodoroRuntimePauseThresholdTick; if ($null -ne $pauseTick) { Save-PomodoroRuntimeState }; return $pauseTick }
    if ($script:TimerState -ne "running") { return $null }
    $remaining = [int][Math]::Ceiling(($script:PomodoroEndAt - (Get-Date)).TotalSeconds)
    if ($remaining -le 0) {
        if (-not (Start-PomodoroRuntimeCompletion)) { return New-PomodoroRuntimeTickResult "busy" }
        return New-PomodoroRuntimeTickResult "complete"
    }
    $script:SecondsRemaining = $remaining
    Save-PomodoroRuntimeState
    Update-BackgroundAudioFade $remaining ([string]$script:TimerPhase)
    return New-PomodoroRuntimeTickResult "tick" $true (Test-PomodoroRuntimeTaskInvalidationNeeded)
}
