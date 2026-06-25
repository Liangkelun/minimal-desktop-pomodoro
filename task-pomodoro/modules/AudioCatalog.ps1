# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function ConvertFrom-AudioTextB64([string]$Value) {
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function New-AudioCatalogEntry([string[]]$Kinds, [string]$FileName, [string]$ZhB64, [string]$EnLabel, [string]$Source, [string]$License) {
    return [pscustomobject]@{
        Kinds = $Kinds
        FileName = $FileName
        ZhB64 = $ZhB64
        EnLabel = $EnLabel
        Source = $Source
        License = $License
    }
}

function Get-AudioCatalogItems {
    return @(
        New-AudioCatalogEntry @("start") "focus-start.wav" "5LiT5rOo5byA5aeL" "Focus start" "Project bundled" "Project"
        New-AudioCatalogEntry @("start") "break-start.wav" "5LyR5oGv5byA5aeL" "Break start" "Project bundled" "Project"
        New-AudioCatalogEntry @("start") "start-soft.wav" "6L275p+U5byA5aeL" "Soft start" "Generated" "Project"
        New-AudioCatalogEntry @("start") "start-clear.wav" "5riF5Lqu5byA5aeL" "Clear start" "Generated" "Project"
        New-AudioCatalogEntry @("end") "break-start.wav" "5LyR5oGv5byA5aeL" "Break start" "Project bundled" "Project"
        New-AudioCatalogEntry @("end") "focus-start.wav" "5LiT5rOo5byA5aeL" "Focus start" "Project bundled" "Project"
        New-AudioCatalogEntry @("end") "end-soft.wav" "5p+U5ZKM57uT5p2f" "Soft finish" "Generated" "Project"
        New-AudioCatalogEntry @("end") "end-clear.wav" "5riF5Lqu57uT5p2f" "Clear finish" "Generated" "Project"
        New-AudioCatalogEntry @("work", "starter") "focus-loop.mp3" "5LiT5rOo5b6q546v" "Focus loop" "Project bundled" "Project"
        New-AudioCatalogEntry @("break") "break-loop.mp3" "5LyR5oGv5b6q546v" "Break loop" "Project bundled" "Project"
        New-AudioCatalogEntry @("work", "starter") "Degrees_of_Clarity.mp3" "5riF5pmw5oSf" "Clarity" "Project bundled" "Project"
        New-AudioCatalogEntry @("work", "starter") "A_Measured_Turn.mp3" "56iz5a6a5o6o6L+b" "Measured turn" "Project bundled" "Project"
        New-AudioCatalogEntry @("work", "break", "starter") "Clearwater_Path.mp3" "5riF5rC05bCP5b6E" "Clearwater path" "Project bundled" "Project"
        New-AudioCatalogEntry @("work", "break", "starter") "white-noise-loop.wav" "55m95Zmq6Z+z" "White noise" "Generated" "Project"
        New-AudioCatalogEntry @("work", "break", "starter") "pink-noise-loop.wav" "57KJ5Zmq6Z+z" "Pink noise" "Generated" "Project"
        New-AudioCatalogEntry @("work", "break", "starter") "brown-noise-loop.wav" "5qOV5Zmq6Z+z" "Brown noise" "Generated" "Project"
    )
}

function Get-AudioCatalogItemsForKind([string]$Kind) {
    return @(Get-AudioCatalogItems | Where-Object { @($_.Kinds) -contains $Kind -and -not [string]::IsNullOrWhiteSpace((Get-DefaultAudioPath $_.FileName)) })
}

function Get-AudioCatalogItemPath([object]$Item) {
    if ($null -eq $Item) { return "" }
    return Get-DefaultAudioPath ([string]$Item.FileName)
}

function Get-AudioCatalogLabel([object]$Item) {
    if ($null -eq $Item) { return "" }
    if ([string]$script:Settings.Language -eq "en-US") { return [string]$Item.EnLabel }
    return ConvertFrom-AudioTextB64 ([string]$Item.ZhB64)
}


function Get-AudioCustomPrefix {
    if ([string]$script:Settings.Language -eq "en-US") { return "Custom - " }
    return (ConvertFrom-AudioTextB64 "6Ieq6YCJ") + " - "
}

function New-AudioLibraryItem([object]$CatalogItem) {
    return [pscustomobject]@{
        Label = Get-AudioCatalogLabel $CatalogItem
        Path = Get-AudioCatalogItemPath $CatalogItem
        IsCustom = $false
    }
}

function New-CustomAudioLibraryItem([string]$Path) {
    $name = [System.IO.Path]::GetFileName($Path)
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $Path }
    return [pscustomobject]@{
        Label = (Get-AudioCustomPrefix) + $name
        Path = $Path
        IsCustom = $true
    }
}

function Get-AudioCatalogDefaultPath([string]$Kind) {
    $item = @(Get-AudioCatalogItemsForKind $Kind | Select-Object -First 1)
    if ($item.Count -lt 1) { return "" }
    return Get-AudioCatalogItemPath $item[0]
}
