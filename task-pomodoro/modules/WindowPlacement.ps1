# This file is dot-sourced by TaskPomodoro.ps1. It owns screen-safe host window placement helpers.

function Get-SafeWindowLocation([int]$Width, [int]$Height, [object]$X, [object]$Y) {
    if ($null -eq $X -or $null -eq $Y) { return $null }
    try { $x = [int]$X; $y = [int]$Y; $width = [Math]::Max(1, $Width); $height = [Math]::Max(1, $Height) } catch { return $null }
    $rect = New-Object System.Drawing.Rectangle($x, $y, $width, $height); $area = $null
    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) { if ($screen.WorkingArea.IntersectsWith($rect)) { $area = $screen.WorkingArea; break } }
    if ($null -eq $area) {
        $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $x = [int]($area.Left + [Math]::Max(0, ($area.Width - $width) / 2)); $y = [int]($area.Top + [Math]::Max(0, ($area.Height - $height) / 2))
    }
    else {
        if ($width -lt $area.Width) { $x = [int][Math]::Min([Math]::Max($x, $area.Left), ($area.Right - $width)) } else { $x = [int]$area.Left }
        if ($height -lt $area.Height) { $y = [int][Math]::Min([Math]::Max($y, $area.Top), ($area.Bottom - $height)) } else { $y = [int]$area.Top }
    }
    return New-Object System.Drawing.Point($x, $y)
}