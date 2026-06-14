Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$outDir = Join-Path $rootDir "assets\icon\concepts-v2"

if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

function New-ColorA([int]$A, [int]$R, [int]$G, [int]$B) {
    return [System.Drawing.Color]::FromArgb($A, $R, $G, $B)
}

function New-Pt([double]$X, [double]$Y) {
    return New-Object System.Drawing.PointF([single]$X, [single]$Y)
}

function New-RectF([double]$X, [double]$Y, [double]$W, [double]$H) {
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
        $graphics.Clear([System.Drawing.Color]::FromArgb(246, 248, 252))
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

function Draw-ArcLine([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.RectangleF]$Rect, [double]$Width, [System.Drawing.Color]$Color, [int]$Start, [int]$Sweep) {
    $pen = New-Object System.Drawing.Pen($Color, [single]($S * $Width))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $G.DrawArc($pen, $Rect, $Start, $Sweep)
    $pen.Dispose()
}

function Draw-GuideRing([System.Drawing.Graphics]$G, [double]$S, [double]$X, [double]$Y, [double]$W, [double]$ArcWidth, [int]$Start, [int]$Sweep) {
    $rect = New-RectF ($S * $X) ($S * $Y) ($S * $W) ($S * $W)
    Draw-ArcLine $G $S $rect ($ArcWidth + 0.020) (New-ColorA 72 3 18 48) ($Start + 3) $Sweep
    Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 21 99 255) $Start ([Math]::Min(150, $Sweep))
    Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 0 218 255) ($Start + 130) ([Math]::Max(30, $Sweep - 130))
}

function Draw-CheckPath([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.Color]$Color, [double]$Width, [double]$Dx, [double]$Dy, [string]$Cap) {
    $pen = New-Object System.Drawing.Pen($Color, [single]($S * $Width))
    if ($Cap -eq "Flat") {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
    }
    else {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    }
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $G.DrawLines($pen, [System.Drawing.PointF[]]@(
        (New-Pt ($S * (0.12 + $Dx)) ($S * (0.56 + $Dy))),
        (New-Pt ($S * (0.36 + $Dx)) ($S * (0.79 + $Dy))),
        (New-Pt ($S * (0.88 + $Dx)) ($S * (0.22 + $Dy)))
    ))
    $pen.Dispose()
}

function Draw-BigWhiteCheck([System.Drawing.Graphics]$G, [double]$S, [double]$Dx, [double]$Dy) {
    Draw-CheckPath $G $S (New-ColorA 88 0 10 30) 0.165 ($Dx + 0.014) ($Dy + 0.018) "Round"
    Draw-CheckPath $G $S (New-ColorA 255 5 34 83) 0.142 $Dx $Dy "Round"
    Draw-CheckPath $G $S ([System.Drawing.Color]::White) 0.102 $Dx $Dy "Round"
}

function Draw-BigBlueCheck([System.Drawing.Graphics]$G, [double]$S, [double]$Dx, [double]$Dy) {
    Draw-CheckPath $G $S (New-ColorA 90 0 10 30) 0.170 ($Dx + 0.014) ($Dy + 0.018) "Round"
    Draw-CheckPath $G $S ([System.Drawing.Color]::White) 0.145 $Dx $Dy "Round"
    Draw-CheckPath $G $S (New-ColorA 255 22 101 255) 0.100 $Dx $Dy "Round"
}

function Draw-ArrowTip([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.Color]$Color, [double]$Dx, [double]$Dy) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddPolygon([System.Drawing.PointF[]]@(
        (New-Pt ($S * (0.875 + $Dx)) ($S * (0.205 + $Dy))),
        (New-Pt ($S * (0.900 + $Dx)) ($S * (0.350 + $Dy))),
        (New-Pt ($S * (0.748 + $Dx)) ($S * (0.262 + $Dy)))
    ))
    $brush = New-Object System.Drawing.SolidBrush $Color
    $G.FillPath($brush, $path)
    $brush.Dispose()
    $path.Dispose()
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

function Draw-Checker([System.Drawing.Graphics]$G, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $a = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(224, 230, 240))
    $G.FillRectangle($a, $X, $Y, $W, $H)
    $cell = 12
    for ($yy = $Y; $yy -lt ($Y + $H); $yy += $cell) {
        for ($xx = $X; $xx -lt ($X + $W); $xx += $cell) {
            if (((($xx - $X) / $cell) + (($yy - $Y) / $cell)) % 2 -eq 0) {
                $G.FillRectangle($b, $xx, $yy, $cell, $cell)
            }
        }
    }
    $a.Dispose()
    $b.Dispose()
}

$paths = @()

$paths += Save-Concept "G-big-check-open-ring" {
    param($g, $s)
    Draw-GuideRing $g $s 0.25 0.20 0.56 0.076 138 284
    Draw-BigWhiteCheck $g $s 0.000 0.000
}

$paths += Save-Concept "H-blue-action-check" {
    param($g, $s)
    Draw-GuideRing $g $s 0.23 0.20 0.57 0.070 195 270
    Draw-BigBlueCheck $g $s 0.000 0.000
}

$paths += Save-Concept "I-arrow-guide-check" {
    param($g, $s)
    Draw-GuideRing $g $s 0.24 0.21 0.56 0.064 118 300
    Draw-CheckPath $g $s (New-ColorA 92 0 10 30) 0.158 0.012 0.018 "Round"
    Draw-CheckPath $g $s ([System.Drawing.Color]::White) 0.135 0.000 0.000 "Flat"
    Draw-ArrowTip $g $s ([System.Drawing.Color]::White) 0.000 0.000
    Draw-CheckPath $g $s (New-ColorA 255 21 101 255) 0.078 0.000 0.000 "Flat"
    Draw-ArrowTip $g $s (New-ColorA 255 21 101 255) -0.010 0.010
}

$paths += Save-Concept "J-dark-tech-badge" {
    param($g, $s)
    $rect = New-RectF ($s * 0.08) ($s * 0.08) ($s * 0.84) ($s * 0.84)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $rect, (New-ColorA 255 8 22 48), (New-ColorA 255 18 66 118), 45
    Draw-RoundedRect $g $bg $rect ($s * 0.18)
    $bg.Dispose()
    Draw-GuideRing $g $s 0.25 0.20 0.56 0.066 158 282
    Draw-BigWhiteCheck $g $s 0.000 0.000
}

$sheet = New-Canvas 1180 760 $false
try {
    $g = $sheet.Graphics
    $fontTitle = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $fontSmall = New-Object System.Drawing.Font("Segoe UI", 10)
    $fontLabel = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $text = New-Object System.Drawing.SolidBrush (New-ColorA 255 20 31 48)
    $muted = New-Object System.Drawing.SolidBrush (New-ColorA 255 92 106 126)
    $cardBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $border = New-Object System.Drawing.Pen((New-ColorA 255 218 226 238), 1)
    $dark = New-Object System.Drawing.SolidBrush (New-ColorA 255 15 23 42)
    $blue = New-Object System.Drawing.SolidBrush (New-ColorA 255 20 98 162)
    $light = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)

    $g.DrawString("Task Pomodoro Icon Concepts V2", $fontTitle, $text, 36, 24)
    $g.DrawString("Large check dominates. Ring is a smaller guidance track. Each option is previewed on light, dark, blue, and checker backgrounds.", $fontSmall, $muted, 38, 60)

    $labels = @("G  Big Check / Open Ring", "H  Blue Action Check", "I  Arrow Guide Check", "J  Dark Tech Badge")
    for ($i = 0; $i -lt $paths.Count; $i++) {
        $x = 36 + ($i * 284)
        $y = 100
        $card = New-RectF $x $y 248 590
        Draw-RoundedRect $g $cardBrush $card 16
        $g.DrawRectangle($border, [int]$card.X, [int]$card.Y, [int]$card.Width, [int]$card.Height)
        $g.DrawString($labels[$i], $fontLabel, $text, [single]($x + 20), [single]($y + 20))

        $img = [System.Drawing.Image]::FromFile($paths[$i])
        try {
            Draw-Checker $g ($x + 34) ($y + 58) 180 180
            $g.DrawImage($img, [int]($x + 34), [int]($y + 58), 180, 180)

            $previewY = $y + 276
            $bgBrushes = @($light, $dark, $blue)
            for ($j = 0; $j -lt 3; $j++) {
                $px = $x + 24 + ($j * 70)
                $g.FillRectangle($bgBrushes[$j], $px, $previewY, 58, 58)
                $g.DrawRectangle($border, $px, $previewY, 58, 58)
                $g.DrawImage($img, $px + 6, $previewY + 6, 46, 46)
            }
            Draw-Checker $g ($x + 24) ($previewY + 80) 58 58
            $g.DrawRectangle($border, $x + 24, $previewY + 80, 58, 58)
            $g.DrawImage($img, $x + 30, $previewY + 86, 46, 46)
        }
        finally {
            $img.Dispose()
        }

        $g.DrawString("large preview", $fontSmall, $muted, [single]($x + 24), [single]($y + 248))
        $g.DrawString("light / dark / blue", $fontSmall, $muted, [single]($x + 24), [single]($y + 342))
        $g.DrawString("checker transparency", $fontSmall, $muted, [single]($x + 24), [single]($y + 424))
    }

    $sheetPath = Join-Path $outDir "icon-concepts-v2-sheet.png"
    $sheet.Bitmap.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Sheet=$sheetPath"
    foreach ($path in $paths) {
        Write-Output "Concept=$path"
    }
}
finally {
    foreach ($obj in @($fontTitle, $fontSmall, $fontLabel, $text, $muted, $cardBrush, $border, $dark, $blue, $light)) {
        if ($null -ne $obj) {
            $obj.Dispose()
        }
    }
    $sheet.Graphics.Dispose()
    $sheet.Bitmap.Dispose()
}
