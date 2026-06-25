# This file is dot-sourced by TaskPomodoro.ps1. Keep translation text rules and result models UI-free.

function Get-TranslationSelectionKind([string]$Text) {
    $raw = [string]$Text
    if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -gt 1200) { return "" }
    $clean = [regex]::Replace($raw.Trim(), "\s+", " ")
    if ([string]::IsNullOrWhiteSpace($clean) -or $clean.Length -gt 1200) { return "" }
    if ($clean -match "[\u4e00-\u9fff]" -or $clean -notmatch "[A-Za-z]") { return "" }
    if ($clean.Length -le 80 -and $clean -match "^[A-Za-z][A-Za-z'\-]*(\s+[A-Za-z][A-Za-z'\-]*){0,4}$") { return "term" }
    return "sentence"
}

function New-TranslationResult {
    param(
        [string]$Text = "",
        [string]$Source = "",
        [string]$Kind = "",
        [string]$Short = "",
        [string]$Detail = "",
        [string]$Word = "",
        [string]$Phonetic = "",
        [string]$Pos = "",
        [string]$Tags = "",
        [string]$Frequency = "",
        [bool]$IsHint = $false
    )
    return [pscustomobject]@{ Text = $Text; Source = $Source; Kind = $Kind; Short = $Short; Detail = $Detail; Word = $Word; Phonetic = $Phonetic; Pos = $Pos; Tags = $Tags; Frequency = $Frequency; IsHint = $IsHint }
}

function New-TranslationHintResult([string]$TextKey) {
    $message = T $TextKey
    return New-TranslationResult -Source "hint" -Kind "hint" -Short $message -Detail $message -IsHint $true
}