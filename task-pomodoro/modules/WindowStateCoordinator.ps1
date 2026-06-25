# This file is dot-sourced by TaskPomodoro.ps1. It owns host window state persistence and watermark layout snapshots.

function Get-WindowContentBoundsSnapshot {
    if ($null -eq $script:Form -or $null -eq $script:ContentPanel -or $script:ContentPanel.IsDisposed) { return $null }
    $point = $script:Form.PointToClient($script:ContentPanel.PointToScreen([System.Drawing.Point]::Empty))
    return New-Object System.Drawing.Rectangle($point.X, $point.Y, [int]$script:ContentPanel.Width, [int]$script:ContentPanel.Height)
}

function Get-WindowRuntimeLocation { if ($null -eq $script:Form) { return $null }; return $script:Form.Location }
function Set-WindowRuntimeLocation([System.Drawing.Point]$Location) { if ($null -eq $script:Form) { return }; $script:Form.Location = $Location }
function Get-WindowRuntimeSizingSnapshot {
    if ($null -eq $script:Form) { return $null }; $paddingHeight = [int]$script:Form.Padding.Vertical; if ($null -ne $script:ContentPanel) { $paddingHeight += [int]$script:ContentPanel.Padding.Vertical }
    $minWidth = 240; if ($null -ne $script:Form.MinimumSize -and [int]$script:Form.MinimumSize.Width -gt 0) { $minWidth = [int]$script:Form.MinimumSize.Width }; return [pscustomobject]@{ Height = [int]$script:Form.Height; PaddingHeight = $paddingHeight; MinimumWidth = $minWidth }
}

function Set-WindowRuntimeMinimumHeight([int]$Height) { $snapshot = Get-WindowRuntimeSizingSnapshot; if ($null -eq $snapshot) { return }; $script:Form.MinimumSize = New-Object System.Drawing.Size([int]$snapshot.MinimumWidth, $Height) }
function Ensure-WindowRuntimeHeight([int]$Height) { $snapshot = Get-WindowRuntimeSizingSnapshot; if ($null -eq $snapshot) { return }; Set-WindowRuntimeMinimumHeight $Height; if ([int]$snapshot.Height -lt $Height) { $script:Form.Height = $Height } }
function Set-WindowRuntimeHeight([int]$Height) { if ($null -eq (Get-WindowRuntimeSizingSnapshot)) { return }; Set-WindowRuntimeMinimumHeight $Height; $script:Form.Height = $Height }

function Save-WatermarkPreviousLayoutSnapshot([bool]$PreserveLayout) {
    if ($null -eq $script:Form) { return }
    $script:WatermarkPreserveLayout = $PreserveLayout
    $script:WatermarkPreviousActiveView = [string]$script:ActiveView
    $script:WatermarkPreviousWindowWidth = [int]$script:Form.Width
    $script:WatermarkPreviousWindowHeight = [int]$script:Form.Height
    $script:WatermarkPreviousWindowLocation = $script:Form.Location
    $script:WatermarkPreviousMinimumSize = $script:Form.MinimumSize
    $script:WatermarkPreviousContentBounds = $null
    if ($PreserveLayout) { $script:WatermarkPreviousContentBounds = Get-WindowContentBoundsSnapshot }
    $script:WatermarkPreviousOpacity = [double]$script:Form.Opacity
    $script:WatermarkPreviousTopMost = [bool]$script:Form.TopMost
}

function Get-WatermarkPreviousLayoutSnapshot {
    if ($null -eq $script:WatermarkPreviousWindowWidth -or $null -eq $script:WatermarkPreviousWindowHeight -or $null -eq $script:WatermarkPreviousWindowLocation) {
        return $null
    }
    return [pscustomobject]@{
        View = [string]$script:WatermarkPreviousActiveView
        Width = [int]$script:WatermarkPreviousWindowWidth
        Height = [int]$script:WatermarkPreviousWindowHeight
        Location = $script:WatermarkPreviousWindowLocation
        MinimumSize = $script:WatermarkPreviousMinimumSize
        ContentBounds = $script:WatermarkPreviousContentBounds
        Opacity = $script:WatermarkPreviousOpacity
        TopMost = $script:WatermarkPreviousTopMost
    }
}

function Get-WatermarkPreviousContentBounds {
    return $script:WatermarkPreviousContentBounds
}

function Restore-WatermarkPreviousLayout([object]$Snapshot = $null) {
    if ($null -eq $script:Form) { return }
    if ($null -eq $Snapshot) { $Snapshot = Get-WatermarkPreviousLayoutSnapshot }
    if ($null -eq $Snapshot) { return }
    if (-not [string]::IsNullOrWhiteSpace([string]$Snapshot.View) -and [string]$Snapshot.View -ne [string]$script:ActiveView -and $null -ne $script:ContentPanel -and -not $script:ContentPanel.IsDisposed) {
        Set-ActiveView ([string]$Snapshot.View)
    }
    if ($null -ne $Snapshot.MinimumSize) { $script:Form.MinimumSize = $Snapshot.MinimumSize }
    if ($null -ne $Snapshot.Location) { $script:Form.Location = $Snapshot.Location }
    if ($null -ne $Snapshot.Width -and $null -ne $Snapshot.Height) {
        $script:Form.Width = [int]$Snapshot.Width
        $script:Form.Height = [int]$Snapshot.Height
        Update-SizeToggleButton
    }
}

function Restore-WatermarkPreviousWindowChrome([object]$Snapshot = $null) {
    if ($null -eq $script:Form) { return }
    if ($null -eq $Snapshot) { $Snapshot = Get-WatermarkPreviousLayoutSnapshot }
    if ($null -ne $Snapshot -and $null -ne $Snapshot.Opacity) { $script:Form.Opacity = [double]$Snapshot.Opacity }
    elseif ($null -ne $script:Settings) { $script:Form.Opacity = [double]$script:Settings.Opacity }
    if ($null -ne $Snapshot -and $null -ne $Snapshot.TopMost) { $script:Form.TopMost = [bool]$Snapshot.TopMost }
    elseif ($null -ne $script:Settings) { $script:Form.TopMost = [bool]$script:Settings.TopMost }
}

function Clear-WatermarkPreviousLayoutSnapshot {
    $script:WatermarkPreviousActiveView = $null
    $script:WatermarkPreviousWindowWidth = $null
    $script:WatermarkPreviousWindowHeight = $null
    $script:WatermarkPreviousWindowLocation = $null
    $script:WatermarkPreviousMinimumSize = $null
    $script:WatermarkPreviousContentBounds = $null
    $script:WatermarkPreviousOpacity = $null
    $script:WatermarkPreviousTopMost = $null
    $script:WatermarkPreserveLayout = $false
}

function Set-WatermarkPreviousOpacity([double]$Opacity) {
    $script:WatermarkPreviousOpacity = $Opacity
}

function Get-WindowStateSnapshotForSettings {
    if ($null -eq $script:Form) {
        return $null
    }

    $width = [int]$script:Form.Width
    $height = [int]$script:Form.Height
    $location = $script:Form.Location
    $topMost = [bool]$script:Form.TopMost
    $opacity = [double]$script:Form.Opacity

    $watermarkSnapshot = $null
    if ($script:WatermarkMode) { $watermarkSnapshot = Get-WatermarkPreviousLayoutSnapshot }
    if ($null -ne $watermarkSnapshot) {
        $width = [int]$watermarkSnapshot.Width
        $height = [int]$watermarkSnapshot.Height
        $location = $watermarkSnapshot.Location
        if ($null -ne $watermarkSnapshot.TopMost) { $topMost = [bool]$watermarkSnapshot.TopMost }
        if ($null -ne $watermarkSnapshot.Opacity) { $opacity = [double]$watermarkSnapshot.Opacity }
    }

    return [pscustomobject]@{
        Width = $width
        Height = $height
        X = [int]$location.X
        Y = [int]$location.Y
        TopMost = $topMost
        Opacity = $opacity
    }
}

function Sync-SettingsWindowStateFromRuntime {
    if ($null -eq $script:Settings) {
        return
    }
    $snapshot = Get-WindowStateSnapshotForSettings
    if ($null -eq $snapshot) {
        return
    }

    $script:Settings.WindowWidth = [int]$snapshot.Width
    $script:Settings.WindowHeight = [int]$snapshot.Height
    $script:Settings.WindowX = [int]$snapshot.X
    $script:Settings.WindowY = [int]$snapshot.Y
    $script:Settings.TopMost = [bool]$snapshot.TopMost
    $script:Settings.Opacity = [double]$snapshot.Opacity
}

function Apply-SettingsWindowChromeFromSettings {
    if ($null -eq $script:Form -or $null -eq $script:Settings) {
        return
    }

    $script:Form.TopMost = [bool]$script:Settings.TopMost
    $script:Form.Opacity = [double]$script:Settings.Opacity
}