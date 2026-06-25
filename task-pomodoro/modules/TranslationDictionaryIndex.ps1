# This file is dot-sourced by TaskPomodoro.ps1. It owns compact local dictionary offset indexes.

function Get-TranslationDictionaryIndexPath([string]$Path) { if ([string]::IsNullOrWhiteSpace($Path)) { return "" }; return "$Path.idx" }
function Test-TranslationDictionaryIndexFresh([string]$Path) {
    $indexPath = Get-TranslationDictionaryIndexPath $Path
    return (-not [string]::IsNullOrWhiteSpace($indexPath) -and (Test-Path -LiteralPath $Path -PathType Leaf) -and (Test-Path -LiteralPath $indexPath -PathType Leaf))
}
function Clear-TranslationDictionaryIndexCache {
    $indexVariable = Get-Variable -Scope Script -Name TranslationDictionaryIndexes -ErrorAction SilentlyContinue
    if ($null -ne $indexVariable -and $null -ne $indexVariable.Value) { foreach ($index in @($indexVariable.Value.Values)) { try { $index.Stream.Dispose() } catch {} } }
    $script:TranslationDictionaryIndexes = @{}
}
function Open-TranslationDictionaryIndex([string]$Path) {
    $indexPath = Get-TranslationDictionaryIndexPath $Path
    $stream = [System.IO.File]::Open($indexPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = New-Object System.IO.BinaryReader($stream)
    try {
        $magic = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(5))
        if ($magic -ne "TPDK2") { throw "bad dictionary index magic" }
        $indexedBytes = $reader.ReadInt64()
        $dictionaryBytes = (Get-Item -LiteralPath $Path).Length
        if ($indexedBytes -ne $dictionaryBytes) { throw "stale dictionary index" }
        $count = $reader.ReadInt32(); $wordBlobBytes = $reader.ReadInt32(); $recordBytes = [int64]$count * 18
        $indexBytes = (Get-Item -LiteralPath $indexPath).Length
        if ($count -lt 1 -or $wordBlobBytes -lt $count -or $recordBytes -gt [int]::MaxValue -or $wordBlobBytes -gt [int]::MaxValue -or (21 + $recordBytes + [int64]$wordBlobBytes) -ne $indexBytes) { throw "invalid dictionary index size" }
        $records = $reader.ReadBytes([int]$recordBytes); $words = $reader.ReadBytes($wordBlobBytes)
        if ($records.Length -ne $recordBytes -or $words.Length -ne $wordBlobBytes) { throw "truncated dictionary index" }
    }
    finally { $reader.Dispose() }
    return [pscustomobject]@{ Path = $Path; DictionaryBytes = $dictionaryBytes; Count = $count; Records = $records; Words = $words; Stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite) }
}
function Get-TranslationDictionaryIndex([string]$Path) {
    if (-not (Test-TranslationDictionaryIndexFresh $Path)) { return $null }
    $indexVariable = Get-Variable -Scope Script -Name TranslationDictionaryIndexes -ErrorAction SilentlyContinue
    if ($null -eq $indexVariable -or $null -eq $indexVariable.Value) { $script:TranslationDictionaryIndexes = @{} }
    if ($script:TranslationDictionaryIndexes.ContainsKey($Path)) { return $script:TranslationDictionaryIndexes[$Path] }
    try { $script:TranslationDictionaryIndexes[$Path] = Open-TranslationDictionaryIndex $Path; return $script:TranslationDictionaryIndexes[$Path] }
    catch { return $null }
}
function Compare-TranslationDictionaryIndexedWord([object]$Index, [int]$Entry, [byte[]]$Target) {
    $record = $Entry * 18; $wordOffset = [System.BitConverter]::ToInt32($Index.Records, $record); $wordLength = [System.BitConverter]::ToUInt16($Index.Records, $record + 4)
    $min = [System.Math]::Min($wordLength, $Target.Length)
    for ($i = 0; $i -lt $min; $i++) { $diff = [int]$Index.Words[$wordOffset + $i] - [int]$Target[$i]; if ($diff -ne 0) { return $diff } }
    return ($wordLength - $Target.Length)
}
function Find-TranslationDictionaryIndexEntry([object]$Index, [string]$Word) {
    if ([string]::IsNullOrWhiteSpace($Word)) { return -1 }
    $target = [System.Text.Encoding]::UTF8.GetBytes($Word.Trim().ToLowerInvariant()); $low = 0; $high = [int]$Index.Count - 1
    while ($low -le $high) {
        $mid = $low + [int](($high - $low) / 2); $compare = Compare-TranslationDictionaryIndexedWord $Index $mid $target
        if ($compare -eq 0) { return $mid }
        if ($compare -lt 0) { $low = $mid + 1 } else { $high = $mid - 1 }
    }
    return -1
}
function Read-TranslationDictionaryIndexedLine([object]$Index, [int]$Entry) {
    $record = $Entry * 18; $offset = [System.BitConverter]::ToInt64($Index.Records, $record + 6); $length = [System.BitConverter]::ToInt32($Index.Records, $record + 14)
    if ($length -le 0 -or $length -gt 65536 -or $offset -lt 0 -or $offset -gt ([int64]$Index.DictionaryBytes - [int64]$length)) { throw "invalid dictionary index line range" }
    $bytes = New-Object byte[] $length; [void]$Index.Stream.Seek($offset, [System.IO.SeekOrigin]::Begin); $read = 0
    while ($read -lt $length) { $count = $Index.Stream.Read($bytes, $read, $length - $read); if ($count -le 0) { return $null }; $read += $count }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}
function Find-TranslationDictionaryLineByIndex([string]$Path, [object[]]$Candidates) {
    $script:TranslationDictionaryLastIndexUsed = $false
    $index = Get-TranslationDictionaryIndex $Path
    if ($null -eq $index) { return $null }
    $script:TranslationDictionaryLastIndexUsed = $true
    try {
        foreach ($candidate in @($Candidates)) { $entry = Find-TranslationDictionaryIndexEntry $index ([string]$candidate); if ($entry -ge 0) { return (Read-TranslationDictionaryIndexedLine $index $entry) } }
        return $null
    }
    catch {
        try { $index.Stream.Dispose() } catch {}
        if ($null -ne $script:TranslationDictionaryIndexes -and $script:TranslationDictionaryIndexes.ContainsKey($Path)) { $script:TranslationDictionaryIndexes.Remove($Path) }
        $script:TranslationDictionaryLastIndexUsed = $false
        return $null
    }
}