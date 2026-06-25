# This file is dot-sourced by TaskPomodoro.ps1. Keep live host-window chrome writes behind this facade.

function Test-WindowChromeReady {
    return ($null -ne $script:Form -and -not $script:Form.IsDisposed)
}

function Set-WindowChromeWatermarkActive([bool]$Active) {
    if (Test-WindowChromeReady) { $script:Form.WatermarkMode = $Active }
}

function Set-WindowChromeOpacity([double]$Opacity) {
    if (Test-WindowChromeReady) { $script:Form.Opacity = $Opacity }
}

function Set-WindowChromeTopMost([bool]$TopMost) {
    if (Test-WindowChromeReady) { $script:Form.TopMost = $TopMost }
}

function Set-WindowChromeWatermarkExitSize([int]$Size) {
    if (Test-WindowChromeReady) { $script:Form.WatermarkExitSize = $Size }
}

function Test-WindowChromeClickThrough {
    if (-not (Test-WindowChromeReady)) { return $false }
    return [bool]$script:Form.ClickThroughEnabled
}

function Set-WindowChromeClickThrough([bool]$Enabled) {
    if (Test-WindowChromeReady) { $script:Form.SetClickThrough($Enabled) }
}

function Test-WindowChromeWatermarkExitPoint([System.Drawing.Point]$Point, [int]$Size = 28) {
    if (-not (Test-WindowChromeReady)) { return $false }
    return ($Point.X -ge ($script:Form.ClientSize.Width - $Size) -and $Point.Y -le $Size)
}