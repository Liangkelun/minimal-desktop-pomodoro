# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Format-Time([int]$Seconds) {
    if ($Seconds -lt 0) {
        $Seconds = 0
    }
    $minutes = [Math]::Floor($Seconds / 60)
    $remainingSeconds = $Seconds % 60
    return "{0:00}:{1:00}" -f $minutes, $remainingSeconds
}

function New-PomodoroOperationResult(
    [bool]$Ok,
    [string]$StatusKey,
    [string]$View,
    [bool]$ShouldUpdateTimer,
    [object]$Data
) {
    return [pscustomobject]@{
        Ok = $Ok
        StatusKey = $StatusKey
        MessageKey = ""
        View = $View
        ShouldRender = $false
        ShouldUpdateTimer = $ShouldUpdateTimer
        Data = $Data
    }
}

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
        $line | Add-Content -LiteralPath $script:PomodorosFile -Encoding UTF8
    }
}

function Get-MediaPath([string]$FileName) {
    $path = Join-Path $env:WINDIR "Media\$FileName"
    if (Test-Path -LiteralPath $path) {
        return $path
    }
    return $null
}

function Stop-BackgroundAudio {
    if ($null -ne $script:BackgroundPlayer) {
        try {
            $script:BackgroundPlayer.Stop()
            $script:BackgroundPlayer.Dispose()
        }
        catch {
        }
        $script:BackgroundPlayer = $null
    }
}

function Play-Wav([string]$Path, [System.Media.SystemSound]$Fallback) {
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try {
            $player = New-Object System.Media.SoundPlayer($Path)
            $player.Play()
            return
        }
        catch {
        }
    }
    if ($null -ne $Fallback) {
        $Fallback.Play()
    }
}

function Play-WavSync([string]$Path, [System.Media.SystemSound]$Fallback) {
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try {
            $player = New-Object System.Media.SoundPlayer($Path)
            $player.PlaySync()
            return
        }
        catch {
        }
    }
    if ($null -ne $Fallback) {
        $Fallback.Play()
    }
}

function Resolve-AudioFile([string]$CustomPath, [string]$DefaultFileName) {
    if (-not [string]::IsNullOrWhiteSpace($CustomPath) -and (Test-Path -LiteralPath $CustomPath)) {
        return $CustomPath
    }
    return Get-MediaPath $DefaultFileName
}

function Play-StartSound {
    Play-WavSync (Resolve-AudioFile $script:Settings.StartSoundFile "ding.wav") ([System.Media.SystemSounds]::Asterisk)
}

function Play-EndSound {
    # This is the boundary cue after focus ends and before break music starts.
    Play-WavSync (Resolve-AudioFile $script:Settings.EndSoundFile "Alarm01.wav") ([System.Media.SystemSounds]::Exclamation)
}

function Get-BackgroundMediaPath([string]$Phase) {
    if ($Phase -eq "break") {
        return Resolve-AudioFile $script:Settings.BreakMusicFile "chord.wav"
    }

    return Resolve-AudioFile $script:Settings.WorkMusicFile "chimes.wav"
}

function Play-WorkMusicPreview {
    Play-Wav (Get-BackgroundMediaPath "work") ([System.Media.SystemSounds]::Asterisk)
}

function Play-BreakMusicPreview {
    Play-Wav (Get-BackgroundMediaPath "break") ([System.Media.SystemSounds]::Asterisk)
}

function Start-BackgroundAudio([string]$Phase) {
    Stop-BackgroundAudio

    if ($Phase -eq "work" -and -not [bool]$script:Settings.WorkMusic) {
        return
    }
    if ($Phase -eq "break" -and -not [bool]$script:Settings.BreakMusic) {
        return
    }

    $path = Get-BackgroundMediaPath $Phase
    if ([string]::IsNullOrWhiteSpace($path)) {
        return
    }

    try {
        $script:BackgroundPlayer = New-Object System.Media.SoundPlayer($path)
        $loop = $false
        if ($Phase -eq "work") {
            $loop = [bool]$script:Settings.WorkMusicLoop
        }
        elseif ($Phase -eq "break") {
            $loop = [bool]$script:Settings.BreakMusicLoop
        }
        if ($loop) {
            $script:BackgroundPlayer.PlayLooping()
        }
        else {
            $script:BackgroundPlayer.Play()
        }
    }
    catch {
        $script:BackgroundPlayer = $null
    }
}

function Start-Pomodoro([string]$TaskId) {
    $script:CurrentPomodoroTaskId = $TaskId
    $task = $null
    if (-not [string]::IsNullOrWhiteSpace($TaskId)) {
        $task = Get-TaskById $TaskId
    }
    if ($null -ne $task) {
        $script:CurrentPomodoroTaskTitle = $task.title
    }
    else {
        $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
        $script:CurrentPomodoroTaskId = $null
    }

    $script:TimerPhase = "work"
    if ([bool]$script:Settings.StartSoundReminder) {
        Play-StartSound
    }
    $script:PomodoroStartedAt = Get-IsoNow
    $script:PomodoroStartedAtDate = Get-Date
    $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Start-BackgroundAudio "work"
    return New-PomodoroOperationResult $true "Focusing" "timer" $true $script:CurrentPomodoroTaskId
}

function Pause-Pomodoro {
    if ($script:TimerState -ne "running") {
        return New-PomodoroOperationResult $false "" "" $false $null
    }
    $script:SecondsRemaining = [Math]::Max(0, [int][Math]::Ceiling(($script:PomodoroEndAt - (Get-Date)).TotalSeconds))
    $script:TimerState = "paused"
    Stop-BackgroundAudio
    return New-PomodoroOperationResult $true "" "" $true $null
}

function Continue-Pomodoro {
    if ($script:TimerState -ne "paused") {
        return New-PomodoroOperationResult $false "" "" $false $null
    }
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Start-BackgroundAudio $script:TimerPhase
    return New-PomodoroOperationResult $true "" "" $true $null
}

function Stop-Pomodoro {
    if ($script:TimerState -eq "idle") {
        $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
        Stop-BackgroundAudio
        return New-PomodoroOperationResult $true "" "" $true $null
    }

    $ended = Get-IsoNow
    $elapsed = 0
    if ($null -ne $script:PomodoroStartedAtDate) {
        $elapsed = [int][Math]::Max(0, ((Get-Date) - $script:PomodoroStartedAtDate).TotalSeconds)
    }
    if ($script:TimerPhase -eq "break") {
        Append-PomodoroRecord $null $script:PomodoroStartedAt $ended ([int]$script:Settings.ShortBreakMinutes) $elapsed "skipped_break"
    }
    else {
        Append-PomodoroRecord $script:CurrentPomodoroTaskId $script:PomodoroStartedAt $ended ([int]$script:Settings.WorkMinutes) $elapsed "interrupted"
    }
    Stop-BackgroundAudio
    $script:TimerState = "idle"
    $script:TimerPhase = "work"
    $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    $script:CurrentPomodoroTaskId = $null
    $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
    return New-PomodoroOperationResult $true "PomodoroInterrupted" "" $true $null
}

function Complete-Pomodoro {
    if ($script:TimerPhase -eq "break") {
        return Complete-Break
    }

    $ended = Get-IsoNow
    $plannedSeconds = [int]$script:Settings.WorkMinutes * 60
    Append-PomodoroRecord $script:CurrentPomodoroTaskId $script:PomodoroStartedAt $ended ([int]$script:Settings.WorkMinutes) $plannedSeconds "completed"

    if (-not [string]::IsNullOrWhiteSpace($script:CurrentPomodoroTaskId)) {
        $task = Get-TaskById $script:CurrentPomodoroTaskId
        if ($null -ne $task) {
            $task.pomodoroCount = [int]$task.pomodoroCount + 1
            Save-Tasks
        }
    }

    Stop-BackgroundAudio
    Trigger-Reminder
    return Start-BreakTimer
}

function Start-BreakTimer {
    $script:TimerPhase = "break"
    $script:PomodoroStartedAt = Get-IsoNow
    $script:PomodoroStartedAtDate = Get-Date
    $script:SecondsRemaining = [int]$script:Settings.ShortBreakMinutes * 60
    $script:PomodoroEndAt = (Get-Date).AddSeconds($script:SecondsRemaining)
    $script:TimerState = "running"
    Start-BackgroundAudio "break"
    return New-PomodoroOperationResult $true "BreakFocusing" "" $true $null
}

function Complete-Break {
    $ended = Get-IsoNow
    $plannedSeconds = [int]$script:Settings.ShortBreakMinutes * 60
    Append-PomodoroRecord $null $script:PomodoroStartedAt $ended ([int]$script:Settings.ShortBreakMinutes) $plannedSeconds "break_completed"

    Stop-BackgroundAudio
    $script:TimerState = "idle"
    $script:TimerPhase = "work"
    $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    $script:CurrentPomodoroTaskId = $null
    $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
    return New-PomodoroOperationResult $true "BreakDone" "" $true $null
}

function Trigger-Reminder {
    if ([bool]$script:Settings.EndSoundReminder) {
        Play-EndSound
    }
    if ([bool]$script:Settings.ColorReminder -and $null -ne $script:Form) {
        $oldFormColor = $script:Form.BackColor
        $oldMainColor = $null
        $oldNavColor = $null
        $oldContentColor = $null
        $oldStatusColor = $null
        if ($null -ne $script:MainPanel) { $oldMainColor = $script:MainPanel.BackColor }
        if ($null -ne $script:NavPanel) { $oldNavColor = $script:NavPanel.BackColor }
        if ($null -ne $script:ContentPanel) { $oldContentColor = $script:ContentPanel.BackColor }
        if ($null -ne $script:StatusLabel) { $oldStatusColor = $script:StatusLabel.BackColor }
        $flashColor = [System.Drawing.Color]::LightGoldenrodYellow
        $script:Form.BackColor = [System.Drawing.Color]::LightGoldenrodYellow
        if ($null -ne $script:MainPanel) { $script:MainPanel.BackColor = $flashColor }
        if ($null -ne $script:NavPanel) { $script:NavPanel.BackColor = $flashColor }
        if ($null -ne $script:ContentPanel) { $script:ContentPanel.BackColor = $flashColor }
        if ($null -ne $script:StatusLabel) { $script:StatusLabel.BackColor = $flashColor }
        $flash = New-Object System.Windows.Forms.Timer
        $flash.Interval = 1500
        $flash.Add_Tick({
            $script:Form.BackColor = $oldFormColor
            if ($null -ne $script:MainPanel) { $script:MainPanel.BackColor = $oldMainColor }
            if ($null -ne $script:NavPanel) { $script:NavPanel.BackColor = $oldNavColor }
            if ($null -ne $script:ContentPanel) { $script:ContentPanel.BackColor = $oldContentColor }
            if ($null -ne $script:StatusLabel) { $script:StatusLabel.BackColor = $oldStatusColor }
            $flash.Stop()
            $flash.Dispose()
        })
        $flash.Start()
    }
    if ([bool]$script:Settings.TaskbarReminder -and $null -ne $script:Form) {
        $script:Form.Activate()
    }
}

