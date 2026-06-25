# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for audio playback boundary assertions.

function Invoke-AudioPlaybackBoundaryCheck([string]$ModulesDir) {
    $audioPlayback = Join-Path $ModulesDir "AudioPlayback.ps1"
    $pomodoroAudio = Join-Path $ModulesDir "PomodoroAudio.ps1"
    Test-RequiredFile $audioPlayback
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1")
    $loadOrder = Get-TaskPomodoroModuleLoadOrder
    if ([Array]::IndexOf($loadOrder, "AudioPlayback.ps1") -lt 0) { throw "ModuleLoadOrder.ps1 missing AudioPlayback.ps1" }
    if ([Array]::IndexOf($loadOrder, "AudioPlayback.ps1") -gt [Array]::IndexOf($loadOrder, "PomodoroAudio.ps1")) { throw "AudioPlayback.ps1 must load before PomodoroAudio.ps1" }
    Test-FileDoesNotContain $audioPlayback @('$script:Settings', '$script:TimerPhase', "function Start-BackgroundAudio", "function Stop-BackgroundAudio", "function Get-BackgroundMediaPath", "function Resolve-AudioFile") "AudioPlayback.ps1 must stay below Pomodoro phase and settings policy."
    Test-FileDoesNotContain $pomodoroAudio @("New-Object -ComObject WMPlayer.OCX", "New-Object System.Media.SoundPlayer", "System.Media.SoundPlayer(") "PomodoroAudio.ps1 must use AudioPlayback.ps1 for low-level playback adapters."
    $playbackRaw = Get-Content -LiteralPath $audioPlayback -Encoding UTF8 -Raw
    foreach ($required in @("function Get-MediaPath", "function Test-WavAudio", "function Start-ComAudio", "function Stop-ComAudio", "function Play-Wav", "function Play-WavSync", "function Stop-PreviewAudio")) {
        if ($playbackRaw -notlike "*$required*") { throw "AudioPlayback.ps1 missing required marker: $required" }
    }
    $policyRaw = Get-Content -LiteralPath $pomodoroAudio -Encoding UTF8 -Raw
    foreach ($required in @("function Get-AudioVolume", "function Resolve-AudioFile", "function Play-StartSound", "function Play-EndSound", "function Start-BackgroundAudio", "function Stop-BackgroundAudio", "function Update-BackgroundAudioFade")) {
        if ($policyRaw -notlike "*$required*") { throw "PomodoroAudio.ps1 missing required marker: $required" }
    }
    "Audio playback adapters are split from Pomodoro audio policy"
}
