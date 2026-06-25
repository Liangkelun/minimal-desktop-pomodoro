# This file is dot-sourced by TaskPomodoro.ps1. It owns explicit full-dictionary acquisition and binding.

function Get-TranslationFullDictionaryFileName { return "task-pomodoro-full-dictionary.tsv" }

function Get-TranslationFullDictionaryCachePath {
    return (Join-Path (Join-Path (Get-AppPath "DataDir") "dictionaries") (Get-TranslationFullDictionaryFileName))
}

function Get-TranslationFullDictionaryWorkspacePath {
    return (Join-Path (Split-Path -Parent (Get-AppPath "RootDir")) ("local-assets\dictionaries\" + (Get-TranslationFullDictionaryFileName)))
}

function Get-TranslationFullDictionaryRemoteUrls {
    return @(
        "https://github.com/Liangkelun/minimal-desktop-pomodoro/releases/latest/download/task-pomodoro-full-dictionary.tsv",
        "https://gitee.com/Liangkelun/minimal-desktop-pomodoro/releases/download/full-dictionary-latest/task-pomodoro-full-dictionary.tsv"
    )
}

function Test-TranslationDictionaryImportFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $reader = [System.IO.File]::OpenText($Path)
    try {
        if ($reader.ReadLine() -ne "word`tphonetic`tpos`ttranslation`ttags`tfrequency`texchange") { return $false }
        while ($null -ne ($line = $reader.ReadLine())) {
            if (-not [string]::IsNullOrWhiteSpace($line) -and (($line -split "`t", 7).Count -ge 4)) { return $true }
        }
    }
    finally {
        $reader.Dispose()
    }
    return $false
}

function Set-TranslationDictionaryBinding([string]$Path) {
    if (-not (Test-TranslationDictionaryImportFile $Path)) { return $false }
    $script:Settings.TranslationDictionaryPath = [string]$Path
    $script:Settings.TranslationDictionaryFetchOrder = "local-first"
    Clear-TranslationDictionaryCache; Clear-TranslationLookupCache
    Save-TranslationDictionarySettings
    return $true
}

function Clear-TranslationDictionaryBinding {
    $script:Settings.TranslationDictionaryPath = ""
    Clear-TranslationDictionaryCache; Clear-TranslationLookupCache
    Save-TranslationDictionarySettings
}

function Copy-TranslationDictionaryIndexToCache([string]$SourcePath, [string]$CachePath) {
    $sourceIndex = Get-TranslationDictionaryIndexPath $SourcePath
    $cacheIndex = Get-TranslationDictionaryIndexPath $CachePath
    if (Test-Path -LiteralPath $sourceIndex -PathType Leaf) { Copy-Item -LiteralPath $sourceIndex -Destination $cacheIndex -Force }
    elseif (Test-Path -LiteralPath $cacheIndex -PathType Leaf) { Remove-Item -LiteralPath $cacheIndex -Force -ErrorAction SilentlyContinue }
}

function Copy-TranslationDictionaryToCache([string]$Path) {
    $cachePath = Get-TranslationFullDictionaryCachePath
    if ([string]::Equals((Resolve-Path -LiteralPath $Path).Path, $cachePath, [System.StringComparison]::OrdinalIgnoreCase)) { return $cachePath }
    Ensure-Directory (Split-Path -Parent $cachePath)
    Copy-Item -LiteralPath $Path -Destination $cachePath -Force
    Copy-TranslationDictionaryIndexToCache $Path $cachePath
    return $cachePath
}

function Try-Download-TranslationFullDictionaryIndex([string]$DictionaryUrl, [string]$CachePath) {
    $tmp = "$CachePath.$PID.idx.tmp"
    try {
        Invoke-WebRequest -Uri "$DictionaryUrl.idx" -OutFile $tmp -UseBasicParsing -TimeoutSec 5 | Out-Null
        if (Test-Path -LiteralPath $tmp -PathType Leaf) { Move-Item -LiteralPath $tmp -Destination (Get-TranslationDictionaryIndexPath $CachePath) -Force }
    }
    catch {}
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}

function Try-Use-TranslationLocalFullDictionary {
    foreach ($path in @((Get-TranslationFullDictionaryCachePath), (Get-TranslationFullDictionaryWorkspacePath))) {
        if (Test-TranslationDictionaryImportFile $path) { return (Set-TranslationDictionaryBinding (Copy-TranslationDictionaryToCache $path)) }
    }
    return $false
}

function Try-Download-TranslationFullDictionary {
    $cachePath = Get-TranslationFullDictionaryCachePath
    Ensure-Directory (Split-Path -Parent $cachePath)
    foreach ($url in @(Get-TranslationFullDictionaryRemoteUrls)) {
        $tmp = "$cachePath.$PID.tmp"
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 5 | Out-Null
            if (Test-TranslationDictionaryImportFile $tmp) { Move-Item -LiteralPath $tmp -Destination $cachePath -Force; Try-Download-TranslationFullDictionaryIndex $url $cachePath; return (Set-TranslationDictionaryBinding $cachePath) }
        }
        catch {
            $script:Settings.TranslationLastError = [string]$_.Exception.Message
        }
        finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }
    }
    return $false
}

function Install-TranslationFullDictionary {
    if ([string]$script:Settings.TranslationDictionaryFetchOrder -eq "local-first") {
        if (Try-Use-TranslationLocalFullDictionary) { return $true }
        if (Try-Download-TranslationFullDictionary) { return $true }
        return (Try-Use-TranslationLocalFullDictionary)
    }
    if (Try-Download-TranslationFullDictionary) { return $true }
    return (Try-Use-TranslationLocalFullDictionary)
}