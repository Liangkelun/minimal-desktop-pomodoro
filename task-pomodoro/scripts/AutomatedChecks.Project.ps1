# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for project-specific helpers.
function Test-TranslationDictionaryFile([string]$Path) {
    Test-RequiredFile $Path
    $expectedHeader = "word`tphonetic`tpos`ttranslation`ttags`tfrequency`texchange"
    $requiredWords = @("be", "example", "translation", "document")
    $seen = @{}
    $rowCount = 0
    $reader = [System.IO.File]::OpenText($Path)
    try {
        $header = $reader.ReadLine()
        if ($header -ne $expectedHeader) {
            throw "Translation dictionary header is unexpected: $header"
        }
        while ($null -ne ($line = $reader.ReadLine())) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            $rowCount++
            $word = ($line -split "`t", 2)[0]
            if ($requiredWords -contains $word) {
                $seen[$word] = $true
            }
        }
    }
    finally {
        $reader.Dispose()
    }
    if ($rowCount -lt 1000) {
        throw "Translation dictionary is too small: rows=$rowCount"
    }
    foreach ($word in $requiredWords) {
        if (-not $seen.ContainsKey($word)) {
            throw "Translation dictionary missing core word: $word"
        }
    }
    $indexMessage = Test-TranslationDictionaryIndexFile $Path
    return "Translation dictionary rows=$rowCount; $indexMessage"
}

function Test-TranslationDictionaryIndexFile([string]$DictionaryPath) {
    $indexPath = "$DictionaryPath.idx"
    Test-RequiredFile $indexPath
    $stream = [System.IO.File]::Open($indexPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = New-Object System.IO.BinaryReader($stream)
    try {
        $magic = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(5))
        if ($magic -ne "TPDK2") { throw "Translation dictionary index has unexpected magic: $magic" }
        $indexedBytes = $reader.ReadInt64()
        $entryCount = $reader.ReadInt32()
        $wordBlobBytes = $reader.ReadInt32()
    }
    finally { $reader.Dispose() }
    $dictionaryBytes = (Get-Item -LiteralPath $DictionaryPath).Length
    if ($indexedBytes -ne $dictionaryBytes) { throw "Translation dictionary index is stale: indexed=$indexedBytes dictionary=$dictionaryBytes" }
    if ($entryCount -lt 1000) { throw "Translation dictionary index is too small: entries=$entryCount" }
    if ($wordBlobBytes -lt $entryCount) { throw "Translation dictionary index word blob is unexpectedly small: bytes=$wordBlobBytes entries=$entryCount" }
    return "index entries=$entryCount bytes=$((Get-Item -LiteralPath $indexPath).Length)"
}

function Invoke-MainSelfTest([string]$ProjectRoot, [bool]$UseProjectData = $false) {
    $mainScriptPath = Join-Path $ProjectRoot "TaskPomodoro.ps1"
    $powerShellExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
        $powerShellExe = "powershell"
    }

    $previousSelfTestInPlace = $env:TASK_POMODORO_SELFTEST_IN_PLACE
    try {
        if ($UseProjectData) { $env:TASK_POMODORO_SELFTEST_IN_PLACE = "1" } else { Remove-Item Env:TASK_POMODORO_SELFTEST_IN_PLACE -ErrorAction SilentlyContinue }
        $output = & $powerShellExe -NoProfile -STA -ExecutionPolicy Bypass -File $mainScriptPath -SelfTest 2>&1
    }
    finally {
        if ($null -eq $previousSelfTestInPlace) { Remove-Item Env:TASK_POMODORO_SELFTEST_IN_PLACE -ErrorAction SilentlyContinue } else { $env:TASK_POMODORO_SELFTEST_IN_PLACE = $previousSelfTestInPlace }
    }
    if ($LASTEXITCODE -ne 0) {
        throw (@($output) -join "`n")
    }
    if ((@($output) -join "`n") -notmatch "SELFTEST_OK") {
        throw "Self-test finished without SELFTEST_OK marker: $(@($output) -join "`n")"
    }
    return (@($output) -join "`n")
}

function Test-InboxStartupStatePreserved([string]$MainScriptPath) {
    $raw = Get-Content -LiteralPath $MainScriptPath -Encoding UTF8 -Raw
    $loadIndex = $raw.IndexOf("    Load-Inbox", [System.StringComparison]::Ordinal)
    if ($loadIndex -lt 0) {
        throw "TaskPomodoro.ps1 must load inbox data during startup."
    }

    $clearPattern = '    $script:InboxItems = @()'
    $searchIndex = 0
    while ($searchIndex -lt $raw.Length) {
        $clearIndex = $raw.IndexOf($clearPattern, $searchIndex, [System.StringComparison]::Ordinal)
        if ($clearIndex -lt 0) { break }
        if ($clearIndex -gt $loadIndex) {
            throw "TaskPomodoro.ps1 clears loaded inbox state after Load-Inbox."
        }
        $searchIndex = $clearIndex + $clearPattern.Length
    }
    return "Load-Inbox is present and no later inbox state reset was found."
}
function New-IsolatedProjectCopy([string]$SourceRoot) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "TaskPomodoroChecks"
    if (-not (Test-Path -LiteralPath $tempRoot)) {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
    }

    $runRoot = Join-Path $tempRoot ("run-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $runRoot | Out-Null

    $copyRoot = Join-Path $runRoot "task-pomodoro"
    New-Item -ItemType Directory -Path $copyRoot | Out-Null
    $skipNames = @("data", "config", "dist", "reports", ".cache")
    foreach ($item in Get-ChildItem -LiteralPath $SourceRoot -Force) {
        if ($skipNames -contains $item.Name -or $item.Name -in @("launch.log", "update.log")) {
            continue
        }
        Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $copyRoot $item.Name) -Recurse -Force
    }

    return [pscustomobject]@{
        RootDir = $copyRoot
        CleanupDir = $runRoot
    }
}

function Remove-IsolatedProjectCopy([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "TaskPomodoroChecks"
    $resolvedTempRoot = (Resolve-Path -LiteralPath $tempRoot).Path.TrimEnd("\")
    $resolvedTempRootWithSeparator = $resolvedTempRoot + "\"
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    if (-not $resolvedPath.StartsWith($resolvedTempRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside test temp root: $resolvedPath"
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}
