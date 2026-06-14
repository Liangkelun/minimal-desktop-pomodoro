Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$outDir = Join-Path $rootDir "assets\icon\concepts"

if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

function C([int]$A, [int]$R, [int]$G, [int]$B) {
    return [System.Drawing.Color]::FromArgb($A, $R, $G, $B)
}

function P([double]$X, [double]$Y) {
    return New-Object System.Drawing.PointF([single]$X, [single]$Y)
}

function New-RectF2([double]$X, [double]$Y, [double]$W, [double]$H) {
    return New-Object System.Drawing.RectangleF([single]$X, [single]$Y, [single]$W, [single]$H)
}

function New-Canvas([int]$W, [int]$H, [bool]$Transparent) {
    $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    if ($Transparent) {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    }
    else {
        $graphics.Clear([System.Drawing.Color]::FromArgb(248, 250, 252))
    }
    return [pscustomobject]@{ Bitmap = $bitmap; Graphics = $graphics }
}

function Draw-RoundedRect([System.Drawing.Graphics]$G, [System.Drawing.Brush]$Brush, [System.Drawing.RectangleF]$Rect, [double]$Radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = [single]($Radius * 2)
    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $G.FillPath($Brush, $path)
    $path.Dispose()
}

function Draw-Arc([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.RectangleF]$Rect, [double]$Width, [System.Drawing.Color]$Color, [int]$Start, [int]$Sweep) {
    $pen = New-Object System.Drawing.Pen($Color, [single]($S * $Width))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $G.DrawArc($pen, $Rect, $Start, $Sweep)
    $pen.Dispose()
}

function Draw-BlueRing([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.RectangleF]$Rect, [double]$Width, [int]$Start, [int]$Sweep) {
    Draw-Arc $G $S $Rect ($Width + 0.018) (C 52 4 18 45) ($Start + 2) $Sweep
    Draw-Arc $G $S $Rect $Width (C 255 23 104 255) $Start ([Math]::Min(150, $Sweep))
    Draw-Arc $G $S $Rect $Width (C 255 0 214 255) ($Start + 128) ([Math]::Max(30, $Sweep - 128))
}

function Draw-Check([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.Color]$Color, [double]$Width, [double]$Dx, [double]$Dy) {
    $pen = New-Object System.Drawing.Pen($Color, [single]($S * $Width))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $G.DrawLines($pen, [System.Drawing.PointF[]]@(
        (P ($S * (0.27 + $Dx)) ($S * (0.55 + $Dy))),
        (P ($S * (0.43 + $Dx)) ($S * (0.70 + $Dy))),
        (P ($S * (0.74 + $Dx)) ($S * (0.36 + $Dy)))
    ))
    $pen.Dispose()
}

function Draw-ShadowCheck([System.Drawing.Graphics]$G, [double]$S, [double]$Width, [double]$Dx, [double]$Dy) {
    Draw-Check $G $S (C 60 2 16 36) ($Width + 0.018) ($Dx + 0.012) ($Dy + 0.016)
}

function Save-Concept([string]$Name, [scriptblock]$Draw) {
    $size = 256
    $canvas = New-Canvas $size $size $true
    try {
        & $Draw $canvas.Graphics $size
        $path = Join-Path $outDir "$Name.png"
        $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        return $path
    }
    finally {
        $canvas.Graphics.Dispose()
        $canvas.Bitmap.Dispose()
    }
}

$paths = @()

$paths += Save-Concept "A-open-ring-check" {
    param($g, $s)
    Draw-BlueRing $g $s (New-RectF2 ($s * 0.15) ($s * 0.14) ($s * 0.70) ($s * 0.70)) 0.105 145 278
    Draw-ShadowCheck $g $s 0.105 -0.005 0.015
    Draw-Check $g $s ([System.Drawing.Color]::White) 0.098 -0.005 0.005
    Draw-Check $g $s (C 255 18 90 220) 0.045 -0.005 0.005
}

$paths += Save-Concept "B-orbit-check" {
    param($g, $s)
    Draw-Arc $g $s (New-RectF2 ($s * 0.14) ($s * 0.14) ($s * 0.72) ($s * 0.72)) 0.075 (C 255 12 176 255) 32 292
    Draw-Arc $g $s (New-RectF2 ($s * 0.24) ($s * 0.24) ($s * 0.52) ($s * 0.52)) 0.022 (C 120 0 96 255) 210 240
    $dot = New-Object System.Drawing.SolidBrush (C 255 0 230 210)
    $g.FillEllipse($dot, (New-RectF2 ($s * 0.72) ($s * 0.18) ($s * 0.075) ($s * 0.075)))
    $g.FillEllipse($dot, (New-RectF2 ($s * 0.17) ($s * 0.70) ($s * 0.052) ($s * 0.052)))
    $dot.Dispose()
    Draw-ShadowCheck $g $s 0.116 0.005 0.012
    Draw-Check $g $s ([System.Drawing.Color]::White) 0.108 0.005 0.002
}

$paths += Save-Concept "C-tech-tile" {
    param($g, $s)
    $rect = New-RectF2 ($s * 0.12) ($s * 0.12) ($s * 0.76) ($s * 0.76)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $rect, (C 255 10 25 48), (C 255 18 62 112), 45
    Draw-RoundedRect $g $bg $rect ($s * 0.17)
    $bg.Dispose()
    Draw-Arc $g $s (New-RectF2 ($s * 0.22) ($s * 0.20) ($s * 0.56) ($s * 0.56)) 0.066 (C 255 0 222 255) 205 274
    Draw-Arc $g $s (New-RectF2 ($s * 0.22) ($s * 0.20) ($s * 0.56) ($s * 0.56)) 0.020 (C 130 155 244 255) 20 90
    Draw-ShadowCheck $g $s 0.095 -0.010 0.018
    Draw-Check $g $s ([System.Drawing.Color]::White) 0.088 -0.010 0.006
}

$paths += Save-Concept "D-double-ring" {
    param($g, $s)
    Draw-Arc $g $s (New-RectF2 ($s * 0.13) ($s * 0.13) ($s * 0.74) ($s * 0.74)) 0.064 (C 255 18 116 255) 118 314
    Draw-Arc $g $s (New-RectF2 ($s * 0.23) ($s * 0.23) ($s * 0.54) ($s * 0.54)) 0.037 (C 230 0 218 255) -45 252
    Draw-ShadowCheck $g $s 0.125 -0.006 0.011
    Draw-Check $g $s ([System.Drawing.Color]::White) 0.116 -0.006 0.000
    Draw-Check $g $s (C 255 0 108 255) 0.038 -0.006 0.000
}

$paths += Save-Concept "E-chip-gap" {
    param($g, $s)
    Draw-BlueRing $g $s (New-RectF2 ($s * 0.12) ($s * 0.13) ($s * 0.76) ($s * 0.76)) 0.118 200 270
    $chip = New-Object System.Drawing.SolidBrush (C 255 3 121 255)
    Draw-RoundedRect $g $chip (New-RectF2 ($s * 0.61) ($s * 0.12) ($s * 0.14) ($s * 0.14)) ($s * 0.035)
    $chip.Dispose()
    Draw-ShadowCheck $g $s 0.118 0.000 0.020
    Draw-Check $g $s ([System.Drawing.Color]::White) 0.108 0.000 0.010
}

$paths += Save-Concept "F-glass-ring" {
    param($g, $s)
    $soft = New-Object System.Drawing.SolidBrush (C 32 0 164 255)
    $g.FillEllipse($soft, (New-RectF2 ($s * 0.12) ($s * 0.15) ($s * 0.76) ($s * 0.72)))
    $soft.Dispose()
    Draw-Arc $g $s (New-RectF2 ($s * 0.15) ($s * 0.16) ($s * 0.70) ($s * 0.68)) 0.088 (C 255 70 166 255) 155 292
    Draw-Arc $g $s (New-RectF2 ($s * 0.25) ($s * 0.27) ($s * 0.50) ($s * 0.47)) 0.019 (C 140 255 255 255) 210 210
    Draw-ShadowCheck $g $s 0.108 -0.006 0.012
    Draw-Check $g $s (C 255 238 250 255) 0.100 -0.006 0.002
}

$sheet = New-Canvas 960 680 $false
try {
    $g = $sheet.Graphics
    $fontTitle = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $fontLabel = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $fontSmall = New-Object System.Drawing.Font("Segoe UI", 10)
    $textBrush = New-Object System.Drawing.SolidBrush (C 255 28 39 56)
    $mutedBrush = New-Object System.Drawing.SolidBrush (C 255 96 112 132)
    $cardBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $darkCardBrush = New-Object System.Drawing.SolidBrush (C 255 15 23 42)
    $borderPen = New-Object System.Drawing.Pen((C 255 218 226 238), 1)

    $g.DrawString("Task Pomodoro Icon Concepts", $fontTitle, $textBrush, 36, 26)
    $g.DrawString("Blue ring + large check. Compare silhouette and recognition.", $fontSmall, $mutedBrush, 38, 62)

    $labels = @("A  Open Ring", "B  Orbit", "C  Tech Tile", "D  Double Ring", "E  Chip Gap", "F  Glass Ring")

    for ($i = 0; $i -lt $paths.Count; $i++) {
        $col = $i % 3
        $row = [Math]::Floor($i / 3)
        $x = 38 + ($col * 300)
        $y = 100 + ($row * 280)
        $card = New-RectF2 $x $y 260 236
        if ($i -eq 2) {
            Draw-RoundedRect $g $darkCardBrush $card 18
        }
        else {
            Draw-RoundedRect $g $cardBrush $card 18
        }
        $g.DrawRectangle($borderPen, [int]$card.X, [int]$card.Y, [int]$card.Width, [int]$card.Height)
        $img = [System.Drawing.Image]::FromFile($paths[$i])
        try {
            $g.DrawImage($img, [int]($x + 52), [int]($y + 28), 156, 156)
        }
        finally {
            $img.Dispose()
        }
        if ($i -eq 2) {
            $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
            $g.DrawString($labels[$i], $fontLabel, $white, [single]($x + 26), [single]($y + 194))
            $white.Dispose()
        }
        else {
            $g.DrawString($labels[$i], $fontLabel, $textBrush, [single]($x + 26), [single]($y + 194))
        }
    }

    $sheetPath = Join-Path $outDir "icon-concepts-sheet.png"
    $sheet.Bitmap.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Sheet=$sheetPath"
    foreach ($path in $paths) {
        Write-Output "Concept=$path"
    }
}
finally {
    foreach ($obj in @($fontTitle, $fontLabel, $fontSmall, $textBrush, $mutedBrush, $cardBrush, $darkCardBrush, $borderPen)) {
        if ($null -ne $obj) {
            $obj.Dispose()
        }
    }
    $sheet.Graphics.Dispose()
    $sheet.Bitmap.Dispose()
}
