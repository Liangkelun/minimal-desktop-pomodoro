# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

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
