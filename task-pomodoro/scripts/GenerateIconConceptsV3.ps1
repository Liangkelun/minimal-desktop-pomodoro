Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$outDir = Join-Path $rootDir "assets\icon\concepts-v3"

if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

function New-ColorA([int]$A, [int]$R, [int]$G, [int]$B) {
    return [System.Drawing.Color]::FromArgb($A, $R, $G, $B)
}

function New-Pt([double]$X, [double]$Y) {
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
        $graphics.Clear([System.Drawing.Color]::FromArgb(246, 248, 252))
    }
    return [pscustomobject]@{ Bitmap = $bitmap; Graphics = $graphics }
}

function Draw-ArcLine([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.RectangleF]$Rect, [double]$Width, [System.Drawing.Color]$Color, [int]$Start, [int]$Sweep, [string]$Cap) {
    $pen = New-Object System.Drawing.Pen($Color, [single]($S * $Width))
    if ($Cap -eq "Flat") {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
    }
    else {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    }
    $G.DrawArc($pen, $Rect, $Start, $Sweep)
    $pen.Dispose()
}

function Draw-RingSegments([System.Drawing.Graphics]$G, [double]$S, [double]$X, [double]$Y, [double]$W, [double]$ArcWidth, [string]$Mode) {
    $rect = New-RectF2 ($S * $X) ($S * $Y) ($S * $W) ($S * $W)
    Draw-ArcLine $G $S $rect ($ArcWidth + 0.016) (New-ColorA 62 0 10 34) 125 285 "Round"
    if ($Mode -eq "broken") {
        Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 25 96 255) 146 106 "Round"
        Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 0 218 255) 292 104 "Round"
    }
    elseif ($Mode -eq "sparks") {
        Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 25 96 255) 185 95 "Round"
        Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 0 218 255) 316 95 "Round"
        Draw-ArcLine $G $S $rect ($ArcWidth * 0.45) (New-ColorA 190 126 231 255) 96 42 "Round"
    }
    else {
        Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 25 96 255) 138 142 "Round"
        Draw-ArcLine $G $S $rect $ArcWidth (New-ColorA 255 0 218 255) 280 130 "Round"
    }
}

function Get-FlatDoubles([object]$Values) {
    $flat = New-Object System.Collections.Generic.List[double]
    Add-FlatDouble $flat $Values
    return $flat.ToArray()
}

function Add-FlatDouble([System.Collections.Generic.List[double]]$Flat, [object]$Value) {
    if ($Value -is [System.Array]) {
        foreach ($item in $Value) {
            Add-FlatDouble $Flat $item
        }
    }
    else {
        $Flat.Add([double]$Value)
    }
}

function Get-ScalarDouble([object]$Value) {
    $current = $Value
    while ($current -is [System.Array]) {
        $current = $current[0]
    }
    return [double]$current
}

function Draw-PolylineCheck([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.Color]$Color, [double]$Width, [object]$Pts, [string]$Cap) {
    $coords = Get-FlatDoubles $Pts
    $pen = New-Object System.Drawing.Pen($Color, [single]($S * $Width))
    if ($Cap -eq "Flat") {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Triangle
    }
    else {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    }
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $points = [System.Drawing.PointF[]]@(
        (New-Pt ($S * $coords[0]) ($S * $coords[1])),
        (New-Pt ($S * $coords[2]) ($S * $coords[3])),
        (New-Pt ($S * $coords[4]) ($S * $coords[5]))
    )
    $G.DrawLines($pen, $points)
    $pen.Dispose()
}

function Draw-BezierCheck([System.Drawing.Graphics]$G, [double]$S, [System.Drawing.Color]$Color, [double]$Width, [double]$Dx, [double]$Dy, [string]$Cap) {
    $pen = New-Object System.Drawing.Pen($Color, [single]($S * $Width))
    if ($Cap -eq "Flat") {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Triangle
    }
    else {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    }
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $G.DrawBezier(
        $pen,
        (New-Pt ($S * (0.08 + $Dx)) ($S * (0.55 + $Dy))),
        (New-Pt ($S * (0.19 + $Dx)) ($S * (0.60 + $Dy))),
        (New-Pt ($S * (0.30 + $Dx)) ($S * (0.79 + $Dy))),
        (New-Pt ($S * (0.39 + $Dx)) ($S * (0.74 + $Dy)))
    )
    $G.DrawBezier(
        $pen,
        (New-Pt ($S * (0.39 + $Dx)) ($S * (0.74 + $Dy))),
        (New-Pt ($S * (0.55 + $Dx)) ($S * (0.56 + $Dy))),
        (New-Pt ($S * (0.74 + $Dx)) ($S * (0.31 + $Dy))),
        (New-Pt ($S * (0.94 + $Dx)) ($S * (0.13 + $Dy)))
    )
    $pen.Dispose()
}

function Draw-RibbonCheck(
    [System.Drawing.Graphics]$G,
    [double]$S,
    [double]$X1,
    [double]$Y1,
    [double]$X2,
    [double]$Y2,
    [double]$X3,
    [double]$Y3,
    [bool]$BlueCore,
    [string]$Cap
) {
    $coordA = Get-ScalarDouble $X1
    $coordB = Get-ScalarDouble $Y1
    $coordC = Get-ScalarDouble $X2
    $coordD = Get-ScalarDouble $Y2
    $coordE = Get-ScalarDouble $X3
    $coordF = Get-ScalarDouble $Y3
    $basePts = @($coordA, $coordB, $coordC, $coordD, $coordE, $coordF)
    $shadowPts = @(($coordA + 0.016), ($coordB + 0.020), ($coordC + 0.016), ($coordD + 0.020), ($coordE + 0.016), ($coordF + 0.020))
    Draw-PolylineCheck -G $G -S $S -Color (New-ColorA 90 0 9 31) -Width 0.178 -Pts $shadowPts -Cap $Cap
    if ($BlueCore) {
        $glintPts = @(($coordA + 0.015), ($coordB - 0.018), ($coordC + 0.020), ($coordD - 0.020), ($coordE + 0.015), ($coordF - 0.018))
        Draw-PolylineCheck -G $G -S $S -Color ([System.Drawing.Color]::White) -Width 0.150 -Pts $basePts -Cap $Cap
        Draw-PolylineCheck -G $G -S $S -Color (New-ColorA 255 23 102 255) -Width 0.104 -Pts $basePts -Cap $Cap
        Draw-PolylineCheck -G $G -S $S -Color (New-ColorA 140 120 232 255) -Width 0.030 -Pts $glintPts -Cap $Cap
    }
    else {
        Draw-PolylineCheck -G $G -S $S -Color (New-ColorA 255 3 32 82) -Width 0.150 -Pts $basePts -Cap $Cap
        Draw-PolylineCheck -G $G -S $S -Color ([System.Drawing.Color]::White) -Width 0.107 -Pts $basePts -Cap $Cap
    }
}

function Draw-BezierRibbon([System.Drawing.Graphics]$G, [double]$S, [bool]$BlueCore) {
    Draw-BezierCheck $G $S (New-ColorA 92 0 9 31) 0.182 0.016 0.020 "Round"
    if ($BlueCore) {
        Draw-BezierCheck $G $S ([System.Drawing.Color]::White) 0.152 0 0 "Round"
        Draw-BezierCheck $G $S (New-ColorA 255 20 96 255) 0.103 0 0 "Round"
    }
    else {
        Draw-BezierCheck $G $S (New-ColorA 255 3 32 82) 0.152 0 0 "Round"
        Draw-BezierCheck $G $S ([System.Drawing.Color]::White) 0.110 0 0 "Round"
    }
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

$paths += Save-Concept "K-wild-sweep" {
    param($g, $s)
    Draw-RingSegments $g $s 0.26 0.20 0.56 0.062 "broken"
    Draw-RibbonCheck -G $g -S $s -X1 0.06 -Y1 0.55 -X2 0.34 -Y2 0.78 -X3 0.95 -Y3 0.13 -BlueCore $false -Cap "Round"
}

$paths += Save-Concept "L-blue-strike" {
    param($g, $s)
    Draw-RingSegments $g $s 0.25 0.21 0.56 0.058 "sparks"
    Draw-RibbonCheck -G $g -S $s -X1 0.07 -Y1 0.58 -X2 0.35 -Y2 0.80 -X3 0.92 -Y3 0.16 -BlueCore $true -Cap "Flat"
}

$paths += Save-Concept "M-calligraphic-guide" {
    param($g, $s)
    Draw-RingSegments $g $s 0.28 0.22 0.52 0.056 "standard"
    Draw-BezierRibbon $g $s $false
}

$paths += Save-Concept "N-breakthrough-mark" {
    param($g, $s)
    Draw-RingSegments $g $s 0.23 0.19 0.62 0.068 "broken"
    Draw-RibbonCheck -G $g -S $s -X1 0.04 -Y1 0.61 -X2 0.33 -Y2 0.82 -X3 0.98 -Y3 0.10 -BlueCore $true -Cap "Round"
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

    $g.DrawString("Task Pomodoro Icon Concepts V3", $fontTitle, $text, 36, 24)
    $g.DrawString("More unruly, action-led check marks. Ring is smaller and partially broken by the direction stroke.", $fontSmall, $muted, 38, 60)

    $labels = @("K  Wild Sweep", "L  Blue Strike", "M  Calligraphic Guide", "N  Breakthrough Mark")
    for ($i = 0; $i -lt $paths.Count; $i++) {
        $x = 36 + ($i * 284)
        $y = 100
        $card = New-RectF2 $x $y 248 590
        $brushPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $radius = 16
        $d = $radius * 2
        $brushPath.AddArc($card.X, $card.Y, $d, $d, 180, 90)
        $brushPath.AddArc($card.Right - $d, $card.Y, $d, $d, 270, 90)
        $brushPath.AddArc($card.Right - $d, $card.Bottom - $d, $d, $d, 0, 90)
        $brushPath.AddArc($card.X, $card.Bottom - $d, $d, $d, 90, 90)
        $brushPath.CloseFigure()
        $g.FillPath($cardBrush, $brushPath)
        $brushPath.Dispose()
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

    $sheetPath = Join-Path $outDir "icon-concepts-v3-sheet.png"
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
