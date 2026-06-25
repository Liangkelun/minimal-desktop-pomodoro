# This file is dot-sourced by TaskPomodoro.ps1. It owns local translation dictionary loading and lookup.
function Get-TranslationBuiltinDictionaryPath { return (Join-Path (Get-AppPath "RootDir") "assets\dict\watermark-translation-core.tsv") }
function Get-TranslationUserDictionaryPath {
    $userPath = [string]$script:Settings.TranslationDictionaryPath
    if (-not [string]::IsNullOrWhiteSpace($userPath) -and (Test-Path -LiteralPath $userPath -PathType Leaf)) { return $userPath }
    return ""
}
function Ensure-TranslationDictionaryScanTypes {
    if (([System.Management.Automation.PSTypeName]'TaskPomodoroDictionaryScan').Type) { return }
    Add-Type -Language CSharp -TypeDefinition @"
using System; using System.Collections.Generic; using System.IO; using System.Text;
public static class TaskPomodoroDictionaryScan {
    public static string FindFirst(string path, string[] candidates) {
        if (String.IsNullOrWhiteSpace(path) || candidates == null || candidates.Length == 0 || !File.Exists(path)) return null;
        var wanted = new HashSet<string>(candidates, StringComparer.OrdinalIgnoreCase);
        var found = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        using (var reader = new StreamReader(path, Encoding.UTF8, true)) {
            string line; while ((line = reader.ReadLine()) != null) {
                if (String.IsNullOrWhiteSpace(line) || line[0] == '#') continue;
                int tab = line.IndexOf('\t'); if (tab <= 0) continue;
                string word = line.Substring(0, tab).Trim();
                if (String.Equals(word, "word", StringComparison.OrdinalIgnoreCase)) continue;
                if (wanted.Contains(word) && !found.ContainsKey(word)) { found[word] = line; if (String.Equals(word, candidates[0], StringComparison.OrdinalIgnoreCase)) return line; }
            }
        }
        foreach (string candidate in candidates) { string line; if (found.TryGetValue(candidate, out line)) return line; }
        return null;
    }
}
"@
}
function Remove-TranslationDefinitionPartOfSpeechPrefix([string]$Text) {
    $value = ([string]$Text).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return "" }
    return ([regex]::Replace($value, "(?i)^(?:n|v|vt|vi|adj|adv|prep|pron|conj|interj|int|num|art|abbr|aux|modal|pl|a|ad)\.\s*", "")).Trim()
}
function Convert-TranslationDefinitionToShortText([string]$Text, [int]$MaxParts = 3) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $parts = @($Text -split "\\n|;|\uFF1B|,|\uFF0C|\r?\n" | ForEach-Object { Remove-TranslationDefinitionPartOfSpeechPrefix $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -eq 0) { return $Text.Trim() }
    return (@($parts | Select-Object -First $MaxParts) -join "; ")
}
function Clear-TranslationDictionaryCache { $script:TranslationDictionary = @{}; $script:TranslationDictionaryHits = @{}; $script:TranslationDictionaryMisses = @{}; $script:TranslationDictionaryCacheScope = ""; Clear-TranslationDictionaryIndexCache }
function New-TranslationDictionaryEntry([object[]]$Parts) {
    return [pscustomobject]@{
        Word = ([string]$Parts[0]).Trim().ToLowerInvariant(); Phonetic = if ($Parts.Count -gt 1) { [string]$Parts[1] } else { "" }
        Pos = if ($Parts.Count -gt 2) { [string]$Parts[2] } else { "" }; Translation = if ($Parts.Count -gt 3) { [string]$Parts[3] } else { "" }
        Tags = if ($Parts.Count -gt 4) { [string]$Parts[4] } else { "" }; Frequency = if ($Parts.Count -gt 5) { [string]$Parts[5] } else { "" }
        Exchange = if ($Parts.Count -gt 6) { [string]$Parts[6] } else { "" }
    }
}
function Add-TranslationDictionaryFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    foreach ($line in [System.IO.File]::ReadLines($Path, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#") -or $line.StartsWith("word`t")) { continue }
        $parts = $line -split "`t", 7; if ($parts.Count -lt 4) { continue }
        $word = ([string]$parts[0]).Trim().ToLowerInvariant(); if (-not [string]::IsNullOrWhiteSpace($word)) { $script:TranslationDictionary[$word] = New-TranslationDictionaryEntry $parts }
    }
}
function Load-TranslationDictionary { if ($null -eq $script:TranslationDictionary) { $script:TranslationDictionary = @{} } }
function Reset-TranslationDictionaryLookupCache {
    $scope = @((Get-TranslationBuiltinDictionaryPath), (Get-TranslationUserDictionaryPath)) -join "|"
    if ([string]$script:TranslationDictionaryCacheScope -eq $scope -and $null -ne $script:TranslationDictionaryHits -and $null -ne $script:TranslationDictionaryMisses) { return }
    $script:TranslationDictionaryCacheScope = $scope; $script:TranslationDictionaryHits = @{}; $script:TranslationDictionaryMisses = @{}
}
function Find-TranslationDictionaryEntryInFile([string]$Path, [object[]]$Candidates) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    Reset-TranslationDictionaryLookupCache
    $pending = New-Object System.Collections.ArrayList
    foreach ($candidate in @($Candidates)) {
        $key = "$Path|$(([string]$candidate).ToLowerInvariant())"
        if ($script:TranslationDictionaryHits.ContainsKey($key)) { return $script:TranslationDictionaryHits[$key] }
        if (-not $script:TranslationDictionaryMisses.ContainsKey($key)) { $pending.Add([string]$candidate) | Out-Null }
    }
    if ($pending.Count -eq 0) { return $null }
    $line = Find-TranslationDictionaryLineByIndex $Path @($pending.ToArray())
    if ([string]::IsNullOrWhiteSpace($line) -and -not [bool]$script:TranslationDictionaryLastIndexUsed) { Ensure-TranslationDictionaryScanTypes; $line = [TaskPomodoroDictionaryScan]::FindFirst($Path, [string[]]@($pending.ToArray())) }
    if ([string]::IsNullOrWhiteSpace($line)) { foreach ($candidate in @($pending.ToArray())) { $script:TranslationDictionaryMisses["$Path|$(([string]$candidate).ToLowerInvariant())"] = $true }; return $null }
    $parts = $line -split "`t", 7; if ($parts.Count -lt 4) { return $null }
    $entry = New-TranslationDictionaryEntry $parts; $script:TranslationDictionaryHits["$Path|$([string]$entry.Word)"] = $entry; return $entry
}
function Convert-TranslationDictionaryEntryToResult([object]$Entry, [string]$Text) {
    return [pscustomobject]@{ Text = $Text; Source = "local"; Kind = "term"; Short = (Convert-TranslationDefinitionToShortText ([string]$Entry.Translation) 3); Detail = [string]$Entry.Translation; Word = [string]$Entry.Word; Phonetic = [string]$Entry.Phonetic; Pos = [string]$Entry.Pos; Tags = [string]$Entry.Tags; Frequency = [string]$Entry.Frequency; IsHint = $false }
}
function Get-TranslationLookupCandidates([string]$Text) {
    $term = [regex]::Replace((([string]$Text).Trim().ToLowerInvariant()), "^[^a-z]+|[^a-z]+$", "")
    $items = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace($term)) { $items.Add($term) | Out-Null }
    if ($term.EndsWith("ies") -and $term.Length -gt 4) { $items.Add($term.Substring(0, $term.Length - 3) + "y") | Out-Null }
    if ($term.EndsWith("ing") -and $term.Length -gt 5) { $stem = $term.Substring(0, $term.Length - 3); $items.Add($stem) | Out-Null; $items.Add($stem + "e") | Out-Null }
    if ($term.EndsWith("ed") -and $term.Length -gt 4) { $stem = $term.Substring(0, $term.Length - 2); $items.Add($stem) | Out-Null; $items.Add($stem + "e") | Out-Null }
    if ($term.EndsWith("s") -and $term.Length -gt 3) { $items.Add($term.Substring(0, $term.Length - 1)) | Out-Null }
    return @($items.ToArray() | Select-Object -Unique)
}
function Get-TranslationLocalResult([string]$Text) {
    Load-TranslationDictionary; $candidates = @(Get-TranslationLookupCandidates $Text)
    foreach ($candidate in $candidates) { if ($script:TranslationDictionary.ContainsKey($candidate)) { return Convert-TranslationDictionaryEntryToResult $script:TranslationDictionary[$candidate] $Text } }
    $paths = @(); $userPath = Get-TranslationUserDictionaryPath; $userIsFullDictionary = (-not [string]::IsNullOrWhiteSpace($userPath) -and [System.IO.Path]::GetFileName($userPath) -eq "task-pomodoro-full-dictionary.tsv")
    if (-not [string]::IsNullOrWhiteSpace($userPath) -and [string]$script:Settings.TranslationDictionaryFetchOrder -eq "local-first") { $paths += $userPath }
    if (-not $userIsFullDictionary -or $paths.Count -eq 0) { $paths += (Get-TranslationBuiltinDictionaryPath) }
    if (-not [string]::IsNullOrWhiteSpace($userPath) -and $paths -notcontains $userPath) { $paths += $userPath }
    foreach ($path in $paths) { $entry = Find-TranslationDictionaryEntryInFile $path $candidates; if ($null -ne $entry) { return Convert-TranslationDictionaryEntryToResult $entry $Text } }
    return $null
}