# This file is dot-sourced by TaskPomodoro.ps1. It owns translation overlay surface rendering and lifecycle.

function Get-WatermarkTransparentColor { return [System.Drawing.Color]::FromArgb(250, 251, 253) }

function Get-TranslationSurfaceSafePoint([System.Drawing.Size]$Size, [System.Drawing.Point]$Preferred) {
    $screen = [System.Windows.Forms.Screen]::FromPoint($Preferred).WorkingArea
    $x = [Math]::Min([Math]::Max($screen.Left + 4, $Preferred.X), $screen.Right - $Size.Width - 4)
    $y = [Math]::Min([Math]::Max($screen.Top + 4, $Preferred.Y), $screen.Bottom - $Size.Height - 4)
    return New-Object System.Drawing.Point -ArgumentList @([int]$x, [int]$y)
}

function Set-TranslationSurfaceDetailLocation([System.Drawing.Point]$Point) {
    if ($null -eq $script:TranslationSurfaceDetailForm -or $script:TranslationSurfaceDetailForm.IsDisposed) { return }
    $script:TranslationSurfaceDetailForm.Location = Get-TranslationSurfaceSafePoint $script:TranslationSurfaceDetailForm.Size $Point
}

function Get-TranslationSurfaceFontSize {
    if ($null -eq $script:Settings -or -not ($script:Settings.PSObject.Properties.Name -contains "TranslationFontSize")) { return 15.0 }
    try { return [Math]::Min(32.0, [Math]::Max(9.0, [double]$script:Settings.TranslationFontSize)) } catch { return 15.0 }
}

function Get-TranslationSurfaceStyle {
    if ($null -eq $script:Settings -or -not ($script:Settings.PSObject.Properties.Name -contains "TranslationSurfaceStyle")) { return "follow" }
    $style = [string]$script:Settings.TranslationSurfaceStyle
    if ($style -in @("follow", "blur", "solid")) { return $style }
    return "follow"
}

function Get-TranslationSurfaceVisualStyle {
    $style = Get-TranslationSurfaceStyle
    if ($style -eq "follow") { if ([bool]$script:WatermarkMode) { return "blur" } else { return "solid" } }
    return $style
}

function Get-TranslationSurfaceColorMode {
    if ($null -eq $script:Settings -or -not ($script:Settings.PSObject.Properties.Name -contains "TranslationSurfaceColorMode")) { return "black-on-white" }
    $mode = [string]$script:Settings.TranslationSurfaceColorMode
    if ($mode -in @("black-on-white", "white-on-black")) { return $mode }
    return "black-on-white"
}

function Get-TranslationSurfaceVisualSpec {
    $visualStyle = Get-TranslationSurfaceVisualStyle
    $colorMode = Get-TranslationSurfaceColorMode
    $backColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $foreColor = [System.Drawing.Color]::FromArgb(17, 24, 39)
    if ($colorMode -eq "white-on-black") {
        $backColor = [System.Drawing.Color]::FromArgb(17, 24, 39)
        $foreColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
    }

    if ($visualStyle -eq "blur") {
        return [pscustomobject]@{ BackColor = $backColor; ForeColor = $foreColor; MiniOpacity = 0.64; DetailOpacity = 0.70 }
    }

    return [pscustomobject]@{ BackColor = $backColor; ForeColor = $foreColor; MiniOpacity = 0.94; DetailOpacity = 0.96 }
}

function Get-TranslationSurfaceDistanceToRect([System.Drawing.Point]$Point, [System.Drawing.Rectangle]$Rect) {
    if ($Rect.IsEmpty) { return [double]::PositiveInfinity }
    $dx = 0; if ($Point.X -lt $Rect.Left) { $dx = $Rect.Left - $Point.X } elseif ($Point.X -gt $Rect.Right) { $dx = $Point.X - $Rect.Right }
    $dy = 0; if ($Point.Y -lt $Rect.Top) { $dy = $Rect.Top - $Point.Y } elseif ($Point.Y -gt $Rect.Bottom) { $dy = $Point.Y - $Rect.Bottom }
    return [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
}

function Update-TranslationSurfaceAutoHide {
    $visibleForms = @($script:TranslationSurfaceMiniForm, $script:TranslationSurfaceDetailForm) | Where-Object { $null -ne $_ -and -not $_.IsDisposed -and $_.Visible }
    if ($visibleForms.Count -eq 0) { $script:TranslationSurfaceMouseAwaySince = $null; return }
    $cursor = [System.Windows.Forms.Cursor]::Position
    $near = $false
    foreach ($form in $visibleForms) {
        $bounds = New-Object System.Drawing.Rectangle -ArgumentList @($form.Location, $form.Size)
        if ((Get-TranslationSurfaceDistanceToRect $cursor $bounds) -le 220) { $near = $true; break }
    }
    if (-not $near -and $null -ne $script:TranslationSurfaceAnchorRect -and -not $script:TranslationSurfaceAnchorRect.IsEmpty) {
        $near = ((Get-TranslationSurfaceDistanceToRect $cursor $script:TranslationSurfaceAnchorRect) -le 220)
    }
    if ($near) { $script:TranslationSurfaceMouseAwaySince = $null; return }
    if ($null -eq $script:TranslationSurfaceMouseAwaySince) { $script:TranslationSurfaceMouseAwaySince = Get-Date; return }
    if (((Get-Date) - $script:TranslationSurfaceMouseAwaySince).TotalMilliseconds -ge 700) { Hide-TranslationSurfaces }
}

function Hide-TranslationSurfaceResultFromTimer {
    if ($null -ne $script:TranslationSurfaceHideTimer) { $script:TranslationSurfaceHideTimer.Stop() }
    Clear-TranslationWorkflowShownState "" | Out-Null
    Hide-TranslationSurfaces
}

function Ensure-TranslationSurfaceForms {
    Ensure-TranslationPlatformTypes
    $visual = Get-TranslationSurfaceVisualSpec
    $surfaceColor = $visual.BackColor
    $textColor = $visual.ForeColor
    $fontSize = Get-TranslationSurfaceFontSize
    if ($null -eq $script:TranslationSurfaceMiniForm -or $script:TranslationSurfaceMiniForm.IsDisposed) {
        $mini = New-Object TaskPomodoroNoActivateForm
        $mini.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None; $mini.ShowInTaskbar = $false; $mini.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $mini.BackColor = $surfaceColor; $mini.Opacity = [double]$visual.MiniOpacity; $mini.TopMost = $true; $mini.Padding = New-Object System.Windows.Forms.Padding(6, 3, 6, 3)
        $miniLabel = New-Object System.Windows.Forms.Label
        $miniLabel.AutoSize = $true; $miniLabel.MaximumSize = New-Object System.Drawing.Size(260, 0); $mini.Controls.Add($miniLabel)
        $script:TranslationSurfaceMiniForm = $mini; $script:TranslationSurfaceMiniLabel = $miniLabel
    }
    if ($null -eq $script:TranslationSurfaceDetailForm -or $script:TranslationSurfaceDetailForm.IsDisposed) {
        $detail = New-Object TaskPomodoroTranslationDetailForm
        $detail.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None; $detail.ShowInTaskbar = $false; $detail.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $detail.BackColor = $surfaceColor; $detail.Opacity = [double]$visual.DetailOpacity; $detail.TopMost = $true; $detail.Width = 318; $detail.Height = 120; $detail.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
        $detailLabel = New-Object System.Windows.Forms.Label
        $detailLabel.Dock = [System.Windows.Forms.DockStyle]::Fill; $detailLabel.AutoEllipsis = $true; $detail.Controls.Add($detailLabel)
        $script:TranslationSurfaceDetailForm = $detail; $script:TranslationSurfaceDetailLabel = $detailLabel
    }
    if ($null -ne $script:TranslationSurfaceMiniForm) { $script:TranslationSurfaceMiniForm.BackColor = $surfaceColor; $script:TranslationSurfaceMiniForm.Opacity = [double]$visual.MiniOpacity }
    if ($null -ne $script:TranslationSurfaceDetailForm) { $script:TranslationSurfaceDetailForm.BackColor = $surfaceColor; $script:TranslationSurfaceDetailForm.Opacity = [double]$visual.DetailOpacity }
    foreach ($label in @($script:TranslationSurfaceMiniLabel, $script:TranslationSurfaceDetailLabel)) {
        if ($null -ne $label) { $label.BackColor = $surfaceColor; $label.ForeColor = $textColor }
    }
    if ($null -ne $script:TranslationSurfaceMiniLabel) { $script:TranslationSurfaceMiniLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", $fontSize, [System.Drawing.FontStyle]::Regular) }
    if ($null -ne $script:TranslationSurfaceDetailLabel) { $script:TranslationSurfaceDetailLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", $fontSize, [System.Drawing.FontStyle]::Regular) }
    if ($null -ne $script:TranslationSurfaceDetailForm) { $script:TranslationSurfaceDetailForm.Width = [int][Math]::Max(318, [Math]::Ceiling($fontSize * 24)); $script:TranslationSurfaceDetailForm.Height = [int][Math]::Max(120, [Math]::Ceiling($fontSize * 8.2)) }
    if ($null -eq $script:TranslationSurfaceHideTimer) {
        $hideTimer = New-Object System.Windows.Forms.Timer
        $hideTimer.Interval = 6000
        $hideTimer.Add_Tick({ Hide-TranslationSurfaceResultFromTimer })
        $script:TranslationSurfaceHideTimer = $hideTimer
    }
}

function Format-TranslationSurfaceDetail([object]$Result) {
    if ($null -eq $Result) { return "" }
    if ([bool]$Result.IsHint) { return [string]$Result.Detail }
    $lines = New-Object System.Collections.ArrayList
    $head = [string]$Result.Word
    if (-not [string]::IsNullOrWhiteSpace([string]$Result.Phonetic)) { $head = "$head  /$($Result.Phonetic)/" }
    foreach ($line in @($head, [string]$Result.Pos, [string]$Result.Detail, ((@([string]$Result.Tags, [string]$Result.Frequency) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "  "))) {
        if (-not [string]::IsNullOrWhiteSpace($line)) { $lines.Add($line) | Out-Null }
    }
    return (@($lines.ToArray()) -join "`n")
}

function Show-TranslationSurfaceResult([object]$Result, [System.Drawing.Rectangle]$Rect) {
    if ($null -eq $Result) { return }
    $script:TranslationSurfaceAnchorRect = $Rect
    $script:TranslationSurfaceMouseAwaySince = $null
    Ensure-TranslationSurfaceForms
    $script:TranslationSurfaceMiniLabel.Text = [string]$Result.Short
    $script:TranslationSurfaceMiniForm.AutoSize = $true; $script:TranslationSurfaceMiniForm.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $script:TranslationSurfaceMiniForm.PerformLayout()
    $cursor = [System.Windows.Forms.Cursor]::Position
    $preferred = New-Object System.Drawing.Point -ArgumentList @([int]($cursor.X + 12), [int]($cursor.Y + [Math]::Max(26, [Math]::Ceiling((Get-TranslationSurfaceFontSize) * 1.8))))
    $placeDetailAbove = $false
    if (-not $Rect.IsEmpty) {
        $gap = [int][Math]::Max(6, [Math]::Ceiling((Get-TranslationSurfaceFontSize) * 0.5)); $screen = [System.Windows.Forms.Screen]::FromRectangle($Rect).WorkingArea
        $belowY = [int]($Rect.Bottom + $gap); $aboveY = [int]($Rect.Top - $script:TranslationSurfaceMiniForm.Height - $gap)
        if (($belowY + $script:TranslationSurfaceMiniForm.Height) -le ($screen.Bottom - 4)) { $preferred = New-Object System.Drawing.Point -ArgumentList @([int]$Rect.Left, $belowY) } elseif ($aboveY -ge ($screen.Top + 4)) { $preferred = New-Object System.Drawing.Point -ArgumentList @([int]$Rect.Left, $aboveY); $placeDetailAbove = $true } else { $preferred = New-Object System.Drawing.Point -ArgumentList @([int]$Rect.Left, $belowY) }
    }
    $script:TranslationSurfaceMiniForm.Location = Get-TranslationSurfaceSafePoint $script:TranslationSurfaceMiniForm.Size $preferred
    if (-not $script:TranslationSurfaceMiniForm.Visible) { $script:TranslationSurfaceMiniForm.Show() } else { $script:TranslationSurfaceMiniForm.Refresh() }
    $script:TranslationSurfaceHideTimer.Stop(); $script:TranslationSurfaceHideTimer.Start()
    $script:TranslationSurfaceDetailLabel.Text = Format-TranslationSurfaceDetail $Result
    $detailY = if ($placeDetailAbove) { [int]($script:TranslationSurfaceMiniForm.Location.Y - $script:TranslationSurfaceDetailForm.Height - 4) } else { [int]($script:TranslationSurfaceMiniForm.Location.Y + $script:TranslationSurfaceMiniForm.Height + 4) }; $detailPreferred = New-Object System.Drawing.Point -ArgumentList @([int]$script:TranslationSurfaceMiniForm.Location.X, $detailY)
    Set-TranslationSurfaceDetailLocation $detailPreferred
    if (-not $script:TranslationSurfaceDetailForm.Visible) { $script:TranslationSurfaceDetailForm.Show() } else { $script:TranslationSurfaceDetailForm.Refresh() }
}

function Hide-TranslationSurfaces {
    $script:TranslationSurfaceMouseAwaySince = $null
    if ($null -ne $script:TranslationSurfaceHideTimer) { $script:TranslationSurfaceHideTimer.Stop() }
    foreach ($form in @($script:TranslationSurfaceMiniForm, $script:TranslationSurfaceDetailForm)) { if ($null -ne $form -and -not $form.IsDisposed) { $form.Hide() } }
}

function Dispose-TranslationSurfaces {
    if ($null -ne $script:TranslationSurfaceHideTimer) { $script:TranslationSurfaceHideTimer.Stop(); $script:TranslationSurfaceHideTimer.Dispose() }
    $script:TranslationSurfaceHideTimer = $null
    foreach ($formName in @("TranslationSurfaceMiniForm", "TranslationSurfaceDetailForm")) {
        $form = Get-Variable -Name $formName -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $form -and -not $form.IsDisposed) { $form.Dispose() }
        Set-Variable -Name $formName -Scope Script -Value $null
    }
    $script:TranslationSurfaceMiniLabel = $null; $script:TranslationSurfaceDetailLabel = $null
}
