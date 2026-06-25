# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Stop-BackgroundAudio {
    Stop-PreviewAudio
    if ($null -ne $script:BackgroundPlayer) {
        try { $script:BackgroundPlayer.Stop(); $script:BackgroundPlayer.Dispose() } catch {}
        $script:BackgroundPlayer = $null
    }
    Stop-ComAudio "BackgroundMediaPlayer"
    $script:BackgroundAudioPhase = ""
    $script:BackgroundAudioVolume = -1
}

function Get-AudioVolume {
    if ($null -ne $script:Settings -and $script:Settings.PSObject.Properties.Name -contains "AudioVolume") { return [int][Math]::Max(0, [Math]::Min(100, [int]$script:Settings.AudioVolume)) }
    return 100
}

function Set-BackgroundAudioVolume([int]$Volume) {
    $Volume = [Math]::Max(0, [Math]::Min(100, $Volume))
    if ([int]$script:BackgroundAudioVolume -eq $Volume) { return }
    $player = Get-Variable -Scope Script -Name "BackgroundMediaPlayer" -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $player) {
        try { $player.settings.volume = $Volume } catch {}
    }
    $script:BackgroundAudioVolume = $Volume
}

function Reset-BackgroundAudioFade {
    $script:BackgroundAudioVolume = -1
    Set-BackgroundAudioVolume (Get-AudioVolume)
}

function Update-BackgroundAudioFade([int]$SecondsRemaining, [string]$Phase) {
    if ($Phase -notin @("work", "break", "starter")) { return }
    $player = Get-Variable -Scope Script -Name "BackgroundMediaPlayer" -ValueOnly -ErrorAction SilentlyContinue
    if ($null -eq $player) { return }
    $fadeSeconds = 8
    if ($SecondsRemaining -gt $fadeSeconds) {
        Reset-BackgroundAudioFade
        return
    }
    $volume = [int][Math]::Round((Get-AudioVolume) * ([Math]::Max(0, $SecondsRemaining) / $fadeSeconds))
    Set-BackgroundAudioVolume $volume
}

function Resolve-AudioFile([string]$CustomPath, [string]$DefaultFileName) {
    if (-not [string]::IsNullOrWhiteSpace($CustomPath) -and (Test-Path -LiteralPath $CustomPath)) {
        return $CustomPath
    }
    return Get-MediaPath $DefaultFileName
}

function Play-StartSound { Play-WavSync (Resolve-AudioFile $script:Settings.StartSoundFile "ding.wav") ([System.Media.SystemSounds]::Asterisk) }

function Play-EndSound {
    # This is the boundary cue after focus ends and before break music starts.
    Play-WavSync (Resolve-AudioFile $script:Settings.EndSoundFile "Alarm01.wav") ([System.Media.SystemSounds]::Exclamation)
}

function Get-BackgroundMediaPath([string]$Phase) {
    if ($Phase -eq "starter") {
        return Resolve-AudioFile $script:Settings.StarterMusicFile "chimes.wav"
    }
    if ($Phase -eq "break") {
        return Resolve-AudioFile $script:Settings.BreakMusicFile "chord.wav"
    }

    return Resolve-AudioFile $script:Settings.WorkMusicFile "chimes.wav"
}

function Play-WorkMusicPreview { Play-Wav (Get-BackgroundMediaPath "work") ([System.Media.SystemSounds]::Asterisk) }

function Play-BreakMusicPreview { Play-Wav (Get-BackgroundMediaPath "break") ([System.Media.SystemSounds]::Asterisk) }

function Play-VolumePreview([int]$Volume) { Play-Wav (Resolve-AudioFile $script:Settings.StartSoundFile "ding.wav") ([System.Media.SystemSounds]::Asterisk) $Volume }

function Start-BackgroundAudio([string]$Phase) {
    Stop-PreviewAudio
    Stop-BackgroundAudio

    if ($Phase -notin @("work", "break", "starter")) { return }
    if ($Phase -eq "work" -and -not [bool]$script:Settings.WorkMusic) { return }
    if ($Phase -eq "break" -and -not [bool]$script:Settings.BreakMusic) { return }
    if ($Phase -eq "starter" -and -not [bool]$script:Settings.StarterMusic) { return }

    $path = Get-BackgroundMediaPath $Phase
    if ([string]::IsNullOrWhiteSpace($path)) { return }

    try {
        $script:BackgroundAudioPhase = $Phase
        Reset-BackgroundAudioFade
        $loop = $false
        if ($Phase -eq "work") {
            $loop = [bool]$script:Settings.WorkMusicLoop
        }
        elseif ($Phase -eq "break") {
            $loop = [bool]$script:Settings.BreakMusicLoop
        }
        elseif ($Phase -eq "starter") {
            $loop = [bool]$script:Settings.StarterMusicLoop
        }
        if (-not (Start-ComAudio $path $loop "BackgroundMediaPlayer" $false (Get-AudioVolume))) { $script:BackgroundMediaPlayer = $null }
    }
    catch {
        $script:BackgroundPlayer = $null
    }
}
