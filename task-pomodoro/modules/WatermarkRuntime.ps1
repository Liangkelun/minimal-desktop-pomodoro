# This file is dot-sourced by TaskPomodoro.ps1. Keep Watermark runtime access behind this facade.

function Test-WatermarkRuntimeActive { return [bool]$script:WatermarkMode }

function Start-WatermarkRuntime([bool]$PreserveLayout = $false) { Enter-WatermarkMode $PreserveLayout }

function Stop-WatermarkRuntime { Exit-WatermarkMode }

function Toggle-WatermarkRuntime { Toggle-WatermarkMode }

function Get-WatermarkRuntimeOpacity { return Get-WatermarkModeOpacity }

function Update-WatermarkRuntimeToggleButton { Update-WatermarkToggleButton }

function Update-WatermarkRuntimeClickThrough { Update-WatermarkClickThrough }

function Suspend-WatermarkRuntimeClickThrough {
    if ((Test-WatermarkRuntimeActive) -and (Test-WindowChromeReady)) {
        Set-WindowChromeClickThrough $false
    }
}

function Set-WatermarkRuntimeConfiguredOpacity([double]$Opacity) {
    if (-not (Test-WindowChromeReady)) { return }
    if (Test-WatermarkRuntimeActive) {
        Set-WatermarkPreviousOpacity $Opacity
        Set-WindowChromeOpacity (Get-WatermarkRuntimeOpacity)
        Update-WatermarkRuntimeToggleButton
        return
    }
    Set-WindowChromeOpacity $Opacity
}