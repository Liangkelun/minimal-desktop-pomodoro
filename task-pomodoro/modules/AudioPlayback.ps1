# This file is dot-sourced before PomodoroAudio.ps1. Keep playback adapters free of Pomodoro phase policy.

function Get-MediaPath([string]$FileName) {
    $path = Join-Path $env:WINDIR "Media\$FileName"
    if (Test-Path -LiteralPath $path) { return $path }
    return $null
}

function Stop-ComAudio([string]$VariableName) {
    $player = Get-Variable -Scope Script -Name $VariableName -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $player) {
        try { $player.controls.stop(); $player.close() } catch {}
        try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($player) } catch {}
        Set-Variable -Scope Script -Name $VariableName -Value $null
    }
}

function Stop-PreviewAudio {
    if ($null -ne $script:PreviewSoundPlayer) {
        try { $script:PreviewSoundPlayer.Stop(); $script:PreviewSoundPlayer.Dispose() } catch {}
        $script:PreviewSoundPlayer = $null
    }
    Stop-ComAudio "PreviewMediaPlayer"
}

function Test-WavAudio([string]$Path) { return ([System.IO.Path]::GetExtension([string]$Path).ToLowerInvariant() -eq ".wav") }

function Start-ComAudio([string]$Path, [bool]$Loop, [string]$Slot, [bool]$Sync, [int]$Volume = -1) {
    try {
        if (-not $Sync -and -not [string]::IsNullOrWhiteSpace($Slot)) { Stop-ComAudio $Slot }
        $player = New-Object -ComObject WMPlayer.OCX
        $player.settings.autoStart = $false
        if ($Volume -lt 0) { $Volume = Get-AudioVolume }
        $player.settings.volume = [Math]::Max(0, [Math]::Min(100, $Volume))
        $player.settings.setMode("loop", $Loop)
        $player.URL = $Path
        $player.controls.play()
        if (-not [string]::IsNullOrWhiteSpace($Slot)) { Set-Variable -Scope Script -Name $Slot -Value $player }
        if ($Sync) {
            $until = (Get-Date).AddSeconds(4)
            while ((Get-Date) -lt $until -and $player.playState -notin @(1, 8)) { Start-Sleep -Milliseconds 100 }
            try { $player.close() } catch {}
            try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($player) } catch {}
        }
        return $true
    }
    catch { return $false }
}

function Play-Wav([string]$Path, [System.Media.SystemSound]$Fallback, [int]$Volume = -1) {
    Stop-PreviewAudio
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try {
            if (Start-ComAudio $Path $false "PreviewMediaPlayer" $false $Volume) { return }
            if (-not (Test-WavAudio $Path)) { throw "unsupported audio" }
            $player = New-Object System.Media.SoundPlayer($Path); $script:PreviewSoundPlayer = $player
            $player.Play()
            return
        }
        catch {}
    }
    if ($null -ne $Fallback) { $Fallback.Play() }
}

function Play-WavSync([string]$Path, [System.Media.SystemSound]$Fallback, [int]$Volume = -1) {
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try {
            if (Start-ComAudio $Path $false "" $true $Volume) { return }
            if (-not (Test-WavAudio $Path)) { throw "unsupported audio" }
            $player = New-Object System.Media.SoundPlayer($Path)
            $player.PlaySync()
            return
        }
        catch {}
    }
    if ($null -ne $Fallback) { $Fallback.Play() }
}
