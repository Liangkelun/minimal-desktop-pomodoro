# This file is dot-sourced by TaskPomodoro.ps1. It persists Pomodoro runtime state for restart recovery.

function Get-PomodoroRuntimeStateFile { return Get-AppPath "TimerStateFile" }

function Get-PomodoroRuntimeStateSnapshot {
    $snapshot = Get-PomodoroRuntimeTimerViewSnapshot
    $state = [string]$snapshot.State
    if ($state -notin @("running", "paused")) {
        return [pscustomobject][ordered]@{ Version = 1; State = "idle"; SavedAt = Get-IsoNow }
    }
    return [pscustomobject][ordered]@{
        Version = 1
        State = $state
        Phase = [string]$snapshot.Phase
        TaskId = [string]$snapshot.TaskId
        TaskTitle = [string]$snapshot.TaskTitle
        RemainingSeconds = [int]$snapshot.RemainingSeconds
        PlannedMinutes = [int]$snapshot.PlannedMinutes
        StartedAt = [string]$snapshot.StartedAt
        EndAt = [string]$snapshot.EndAt
        PausedAt = [string]$snapshot.PausedAt
        PauseThresholdsTriggered = @($snapshot.PauseThresholdsTriggered)
        SessionWorkMinutes = [int]$script:PomodoroSessionWorkMinutes
        SessionBreakMinutes = [int]$script:PomodoroSessionBreakMinutes
        SessionMaxRounds = [int]$script:PomodoroSessionMaxRounds
        SessionStartedCount = [int]$script:PomodoroSessionStartedCount
        SessionAutoStartNext = $script:PomodoroSessionAutoStartNext
        SavedAt = Get-IsoNow
    }
}

function Save-PomodoroRuntimeState {
    Write-JsonAtomic (Get-PomodoroRuntimeStateFile) (Get-PomodoroRuntimeStateSnapshot)
}

function Clear-PomodoroRuntimeStateFile {
    Write-JsonAtomic (Get-PomodoroRuntimeStateFile) ([pscustomobject][ordered]@{ Version = 1; State = "idle"; SavedAt = Get-IsoNow })
}

function Restore-PomodoroRuntimeSessionState([object]$State) {
    if ($State.PSObject.Properties.Name -contains "SessionWorkMinutes") { $script:PomodoroSessionWorkMinutes = [int]$State.SessionWorkMinutes }
    if ($State.PSObject.Properties.Name -contains "SessionBreakMinutes") { $script:PomodoroSessionBreakMinutes = [int]$State.SessionBreakMinutes }
    if ($State.PSObject.Properties.Name -contains "SessionMaxRounds") { $script:PomodoroSessionMaxRounds = [int]$State.SessionMaxRounds }
    if ($State.PSObject.Properties.Name -contains "SessionStartedCount") { $script:PomodoroSessionStartedCount = [int]$State.SessionStartedCount }
    if ($State.PSObject.Properties.Name -contains "SessionAutoStartNext") { $script:PomodoroSessionAutoStartNext = $State.SessionAutoStartNext }
    if ([int]$script:PomodoroSessionMaxRounds -le 0 -and [string]$State.Phase -ne "starter") { Ensure-PomodoroSession ([string]$State.TaskId) }
    if ([int]$script:PomodoroSessionStartedCount -le 0 -and [string]$State.Phase -in @("work", "break")) { $script:PomodoroSessionStartedCount = 1 }
}

function Restore-PomodoroRuntimeState {
    $path = Get-PomodoroRuntimeStateFile
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try {
        $raw = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $false }
        $state = $raw | ConvertFrom-Json
    }
    catch {
        Backup-DataFile $path "invalid"
        Clear-PomodoroRuntimeStateFile
        return $false
    }

    if ($null -eq $state -or [string]$state.State -notin @("running", "paused")) { return $false }
    if ([string]$state.Phase -notin @("work", "break", "starter")) { Clear-PomodoroRuntimeStateFile; return $false }
    if ([string]::IsNullOrWhiteSpace([string]$state.TaskId) -or $null -eq (Get-TaskById ([string]$state.TaskId))) {
        Clear-PomodoroRuntimeStateFile
        return $false
    }

    $remaining = [int][Math]::Max(0, [int]$state.RemainingSeconds)
    $endAt = ConvertTo-LocalDateTimeOrNull ([string]$state.EndAt)
    if ([string]$state.State -eq "running" -and $null -ne $endAt) {
        $remaining = [int][Math]::Max(0, [Math]::Ceiling(($endAt - (Get-Date)).TotalSeconds))
    }

    $pausedAt = ConvertTo-LocalDateTimeOrNull ([string]$state.PausedAt)
    if ([string]$state.State -eq "paused" -and $null -ne $pausedAt) {
        $savedAt = ConvertTo-LocalDateTimeOrNull ([string]$state.SavedAt)
        if ($null -ne $savedAt -and $savedAt -gt $pausedAt) {
            $pausedSecondsAtSave = [Math]::Max(0, ($savedAt - $pausedAt).TotalSeconds)
            $pausedAt = (Get-Date).AddSeconds(-$pausedSecondsAtSave)
        }
    }

    $task = Get-TaskById ([string]$state.TaskId)
    Restore-PomodoroRuntimeSessionState $state
    $script:TimerState = [string]$state.State
    $script:TimerPhase = [string]$state.Phase
    $script:SecondsRemaining = $remaining
    $script:CurrentPomodoroTaskId = [string]$state.TaskId
    $script:CurrentPomodoroTaskTitle = if ($null -ne $task) { [string]$task.title } else { [string]$state.TaskTitle }
    $script:PomodoroStartedAt = [string]$state.StartedAt
    $script:PomodoroStartedAtDate = ConvertTo-LocalDateTimeOrNull ([string]$state.StartedAt)
    $script:CurrentPhasePlannedMinutes = [int][Math]::Max(0, [int]$state.PlannedMinutes)
    if ([int]$script:CurrentPhasePlannedMinutes -le 0) { $script:CurrentPhasePlannedMinutes = [int][Math]::Ceiling($remaining / 60.0) }
    $script:PomodoroEndAt = (Get-Date).AddSeconds($remaining)
    $script:TimerCompletionInProgress = $false
    $script:PomodoroPausedAtDate = if ([string]$state.State -eq "paused") { $pausedAt } else { $null }
    $script:PomodoroPauseThresholdsTriggered = @($state.PauseThresholdsTriggered | ForEach-Object { [int]$_ })
    return $true
}
