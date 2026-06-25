# This file is dot-sourced before WatermarkTranslation.ps1. Keep legacy surface names as compatibility wrappers only.

function Get-ScreenSafePoint([System.Drawing.Size]$Size, [System.Drawing.Point]$Preferred) {
    return Get-TranslationSurfaceSafePoint $Size $Preferred
}

function Set-WatermarkTranslationDetailLocation([System.Drawing.Point]$Point) {
    Set-TranslationSurfaceDetailLocation $Point
}

function Get-WatermarkTranslationFontSize {
    return Get-TranslationSurfaceFontSize
}

function Hide-WatermarkTranslationResultFromTimer {
    Hide-TranslationSurfaceResultFromTimer
}

function Ensure-WatermarkTranslationForms {
    Ensure-TranslationSurfaceForms
}

function Format-WatermarkTranslationDetail([object]$Result) {
    return Format-TranslationSurfaceDetail $Result
}

function Show-WatermarkTranslationResult([object]$Result, [System.Drawing.Rectangle]$Rect) {
    Show-TranslationSurfaceResult $Result $Rect
}

function Hide-WatermarkTranslationSurfaces {
    Hide-TranslationSurfaces
}

function Dispose-WatermarkTranslationSurfaces {
    Dispose-TranslationSurfaces
}