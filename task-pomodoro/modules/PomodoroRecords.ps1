# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Append-PomodoroRecord([string]$TaskId, [string]$StartedAt, [string]$EndedAt, [int]$PlannedMinutes, [int]$ActualSeconds, [string]$Result) {
    $actualMinutes = [Math]::Round(($ActualSeconds / 60.0), 2)
    $record = [pscustomobject]@{
        id = "pomo-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 6)
        taskId = $TaskId
        startedAt = $StartedAt
        endedAt = $EndedAt
        plannedMinutes = $PlannedMinutes
        actualMinutes = $actualMinutes
        result = $Result
    }
    $line = ConvertTo-Json -InputObject $record -Depth 6 -Compress
    Invoke-WithNamedMutex (Get-AppScopedMutexName "data") {
        $line | Add-Content -LiteralPath (Get-AppPath "PomodorosFile") -Encoding UTF8
    }
}
