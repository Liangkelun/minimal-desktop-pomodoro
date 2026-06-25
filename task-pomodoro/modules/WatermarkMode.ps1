# This file is dot-sourced by TaskPomodoro.ps1. Keep watermark mode lifecycle separate from toggle-button chrome.

function Update-WatermarkClickThrough {
    if (-not (Test-WindowChromeReady)) { return }
    if (-not $script:WatermarkMode) {
        if (Test-WindowChromeClickThrough) { Set-WindowChromeClickThrough $false }
        return
    }
    if (Test-WatermarkToggleDragActive) {
        if (Test-WindowChromeClickThrough) { Set-WindowChromeClickThrough $false }
        return
    }

    $insideToggle = Test-WatermarkTogglePoint ([System.Windows.Forms.Cursor]::Position)
    $targetClickThrough = -not $insideToggle
    if ((Test-WindowChromeClickThrough) -ne $targetClickThrough) { Set-WindowChromeClickThrough $targetClickThrough }
}
function Toggle-WatermarkMode {
    if ($script:WatermarkMode) {
        Exit-WatermarkMode
    }
    else {
        Enter-WatermarkMode
    }
}

function Get-WatermarkModeOpacity { return 0.50 }

function Set-WatermarkDefaultTaskView([int]$Rows) {
    $script:ActiveView = "today"
    if ($null -ne $script:NavButtons -and $script:NavButtons.Count -gt 0 -and $null -ne $script:ContentPanel -and -not $script:ContentPanel.IsDisposed) {
        Set-ActiveView "today"
    }
    Resize-WindowForTaskRows $Rows
}

function Enter-WatermarkMode([bool]$PreserveLayout = $false) {
    if (-not (Test-WindowChromeReady) -or $script:WatermarkMode) { return }
    $script:WatermarkMode = $true
    Save-WatermarkPreviousLayoutSnapshot $PreserveLayout
    Set-WindowChromeWatermarkActive $true
    Set-WindowChromeOpacity (Get-WatermarkModeOpacity)
    Set-UiTimerInterval 250
    Set-WindowChromeWatermarkExitSize 32
    Set-WindowChromeTopMost $true
    if (-not $PreserveLayout) { Set-BottomChromeVisible $false; $script:BottomChromeSuppressed = $true; Set-WatermarkDefaultTaskView (Get-CollapsedTaskRows) }

    Apply-WatermarkGhostSurface
    if ($PreserveLayout) { Restore-WatermarkPreviousLayout }

    Update-WatermarkToggleButton
    Update-WatermarkClickThrough
}

function Exit-WatermarkMode {
    if (-not (Test-WindowChromeReady)) { return }
    $previousLayout = Get-WatermarkPreviousLayoutSnapshot
    $script:WatermarkMode = $false
    Set-WindowChromeWatermarkActive $false
    $script:BottomChromeSuppressed = $false
    Restore-WatermarkGhostSurface
    Set-UiTimerInterval 1000
    Restore-WatermarkPreviousWindowChrome $previousLayout

    Set-WindowChromeClickThrough $false
    Clear-WatermarkPreviousLayoutSnapshot
    Restore-WatermarkPreviousLayout $previousLayout
    Update-WatermarkToggleButton
    Update-BottomChromeVisibility
}
function Test-WatermarkExitPoint([System.Drawing.Point]$Point) {
    return (Test-WindowChromeWatermarkExitPoint $Point 28)
}