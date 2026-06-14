Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$outDir = Join-Path $rootDir "assets\icon"
$sourcePath = Join-Path $outDir "concepts-v2\G-big-check-open-ring.png"
$pngPath = Join-Path $outDir "task-pomodoro-g-256.png"
$icoPath = Join-Path $outDir "task-pomodoro-g.ico"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    & (Join-Path $scriptDir "GenerateIconConceptsV2.ps1") | Out-Null
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Missing selected icon concept: $sourcePath"
}

function New-ResizedBitmap([System.Drawing.Image]$Source, [int]$Size) {
    $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($Source, 0, 0, $Size, $Size)
    $graphics.Dispose()
    return $bitmap
}

function Get-PngBytes([System.Drawing.Bitmap]$Bitmap) {
    $stream = New-Object System.IO.MemoryStream
    $Bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    return $stream.ToArray()
}

function Write-Ico([string]$Path, [System.Drawing.Image]$Source, [int[]]$Sizes) {
    $images = @()
    foreach ($size in $Sizes) {
        $bitmap = New-ResizedBitmap $Source $size
        try {
            $images += [pscustomobject]@{
                Size = $size
                Bytes = Get-PngBytes $bitmap
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }

    $stream = [System.IO.File]::Create($Path)
    $writer = New-Object System.IO.BinaryWriter($stream)
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$images.Count)

        $offset = 6 + (16 * $images.Count)
        foreach ($image in $images) {
            $width = if ($image.Size -ge 256) { 0 } else { $image.Size }
            $writer.Write([byte]$width)
            $writer.Write([byte]$width)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$image.Bytes.Length)
            $writer.Write([UInt32]$offset)
            $offset += $image.Bytes.Length
        }

        foreach ($image in $images) {
            $writer.Write([byte[]]$image.Bytes)
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

$source = [System.Drawing.Image]::FromFile($sourcePath)
try {
    $preview = New-ResizedBitmap $source 256
    try {
        $preview.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $preview.Dispose()
    }

    Write-Ico $icoPath $source @(16, 24, 32, 48, 64, 128, 256)
}
finally {
    $source.Dispose()
}

Write-Output "Selected=G-big-check-open-ring"
Write-Output "PNG=$pngPath"
Write-Output "ICO=$icoPath"
