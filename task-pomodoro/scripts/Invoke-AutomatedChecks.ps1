param(
    [switch]$SkipSelfTest,
    [switch]$SkipDataFiles,
    [switch]$SelfTestInPlace,
    [switch]$KeepSelfTestCopy,
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$script:HasFailure = $false
$script:Results = New-Object System.Collections.Generic.List[object]

function Add-CheckResult([string]$Name, [string]$Status, [string]$Details) {
    $result = [pscustomobject]@{
        name = $Name
        status = $Status
        details = $Details
    }
    $script:Results.Add($result) | Out-Null

    $prefix = "[$Status]"
    if ($Status -eq "PASS") {
        Write-Host "$prefix $Name" -ForegroundColor Green
    }
    elseif ($Status -eq "SKIP") {
        Write-Host "$prefix $Name" -ForegroundColor Yellow
    }
    else {
        Write-Host "$prefix $Name" -ForegroundColor Red
        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host $Details -ForegroundColor Red
        }
    }
}

function Invoke-Check([string]$Name, [scriptblock]$Action) {
    try {
        $details = & $Action
        if ($null -eq $details) {
            $details = ""
        }
        Add-CheckResult $Name "PASS" ([string](@($details) -join "`n"))
    }
    catch {
        $script:HasFailure = $true
        Add-CheckResult $Name "FAIL" $_.Exception.Message
    }
}

function Test-PowerShellFile([string]$Path) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($null -ne $errors -and $errors.Count -gt 0) {
        $items = @($errors | Select-Object -First 8 | ForEach-Object {
            "$($_.Extent.StartLineNumber): $($_.Message)"
        })
        throw ($items -join "`n")
    }
}

function Read-JsonFile([string]$Path) {
    $raw = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    return ($raw | ConvertFrom-Json)
}

function Assert-Property([object]$Object, [string]$Name, [string]$Context) {
    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
        throw "$Context missing required property '$Name'"
    }
}

function Test-RequiredFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required file: $Path"
    }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 0) {
        throw "Required file is empty: $Path"
    }
}

function Test-FileDoesNotContain([string]$Path, [string[]]$Patterns, [string]$Reason) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing file for architecture rule: $Path"
    }
    $matches = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        $found = @(Select-String -LiteralPath $Path -Pattern $pattern -SimpleMatch)
        foreach ($item in $found) {
            $matches.Add("$($item.LineNumber): $pattern") | Out-Null
        }
    }
    if ($matches.Count -gt 0) {
        throw "$Reason`n$($matches -join "`n")"
    }
}

function Test-MaxLineCount([string]$Path, [int]$MaxLines) {
    $lineCount = @(Get-Content -LiteralPath $Path).Count
    if ($lineCount -gt $MaxLines) {
        throw "$([System.IO.Path]::GetFileName($Path)) has $lineCount lines; max is $MaxLines"
    }
    return "$([System.IO.Path]::GetFileName($Path)) lines=$lineCount max=$MaxLines"
}

function Invoke-MainSelfTest([string]$ProjectRoot) {
    $mainScriptPath = Join-Path $ProjectRoot "TaskPomodoro.ps1"
    $powerShellExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
        $powerShellExe = "powershell"
    }

    $output = & $powerShellExe -NoProfile -STA -ExecutionPolicy Bypass -File $mainScriptPath -SelfTest 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (@($output) -join "`n")
    }
    if ((@($output) -join "`n") -notmatch "SELFTEST_OK") {
        throw "Self-test finished without SELFTEST_OK marker: $(@($output) -join "`n")"
    }
    return (@($output) -join "`n")
}

function New-IsolatedProjectCopy([string]$SourceRoot) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "TaskPomodoroChecks"
    if (-not (Test-Path -LiteralPath $tempRoot)) {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
    }

    $runRoot = Join-Path $tempRoot ("run-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $runRoot | Out-Null

    $copyRoot = Join-Path $runRoot "task-pomodoro"
    Copy-Item -LiteralPath $SourceRoot -Destination $copyRoot -Recurse -Force

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
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    if (-not $resolvedPath.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside test temp root: $resolvedPath"
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$workspaceRoot = Split-Path -Parent $rootDir
$mainScript = Join-Path $rootDir "TaskPomodoro.ps1"
$modulesDir = Join-Path $rootDir "modules"
$supportScriptsDir = Join-Path $rootDir "scripts"
$dataDir = Join-Path $rootDir "data"
$configDir = Join-Path $rootDir "config"

Invoke-Check "PowerShell syntax: main script" {
    Test-RequiredFile $mainScript
    Test-PowerShellFile $mainScript
    "Parsed TaskPomodoro.ps1"
}

Invoke-Check "PowerShell syntax: support scripts" {
    $files = @(Get-ChildItem -LiteralPath $supportScriptsDir -Filter "*.ps1" -File)
    foreach ($file in $files) {
        Test-PowerShellFile $file.FullName
    }
    "Parsed $($files.Count) support scripts"
}

Invoke-Check "PowerShell syntax: modules" {
    if (-not (Test-Path -LiteralPath $modulesDir -PathType Container)) {
        throw "Missing modules directory: $modulesDir"
    }
    $files = @(Get-ChildItem -LiteralPath $modulesDir -Filter "*.ps1" -File)
    foreach ($file in $files) {
        Test-PowerShellFile $file.FullName
    }
    "Parsed $($files.Count) modules"
}

Invoke-Check "Release metadata" {
    $versionFile = Join-Path $rootDir "VERSION"
    $gitignoreFile = Join-Path $workspaceRoot ".gitignore"
    Test-RequiredFile $gitignoreFile
    Test-RequiredFile (Join-Path $workspaceRoot "README.md")
    Test-RequiredFile (Join-Path $workspaceRoot "CHANGELOG.md")
    Test-RequiredFile (Join-Path $workspaceRoot "LICENSE")
    Test-RequiredFile (Join-Path $workspaceRoot "docs\release-checklist.md")
    Test-RequiredFile $versionFile

    $version = (Get-Content -LiteralPath $versionFile -Encoding UTF8 -Raw).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+([-.][0-9A-Za-z.-]+)?$') {
        throw "VERSION must be semver-like. Current value: $version"
    }
    $gitignore = Get-Content -LiteralPath $gitignoreFile -Encoding UTF8 -Raw
    foreach ($requiredIgnore in @("task-pomodoro/data/", "task-pomodoro/config/", "task-pomodoro/launch.log", "task-pomodoro/update.log", "dist/")) {
        if ($gitignore -notlike "*$requiredIgnore*") {
            throw ".gitignore missing runtime ignore pattern: $requiredIgnore"
        }
    }

    "Release metadata present; version=$version"
}

Invoke-Check "Module load order" {
    $mainRaw = Get-Content -LiteralPath $mainScript -Encoding UTF8 -Raw
    $expectedModules = @(
        "AppState.ps1",
        "UiText.ps1",
        "Storage.ps1",
        "SettingsStore.ps1",
        "TaskModel.ps1",
        "TaskStore.ps1",
        "TaskQueries.ps1",
        "TaskOrdering.ps1",
        "TaskCommands.ps1",
        "TaskDetails.ps1",
        "TaskArchive.ps1",
        "TaskFormat.ps1",
        "PomodoroRecords.ps1",
        "PomodoroAudio.ps1",
        "PomodoroEffects.ps1",
        "PomodoroEngine.ps1",
        "AppRelaunch.ps1",
        "AppMaintenance.ps1",
        "DesktopShortcut.ps1",
        "UiTimer.ps1",
        "BottomChrome.ps1",
        "WindowSize.ps1",
        "WindowDrag.ps1",
        "HelpSurface.ps1",
        "WatermarkMode.ps1",
        "Views.Core.ps1",
        "Views.Task.Controls.ps1",
        "Views.Task.ListDrawing.ps1",
        "Views.Task.DetailsDialog.ps1",
        "Views.Task.Edit.ps1",
        "Views.Task.ps1",
        "Views.Task.Menu.ps1",
        "Views.Timer.ps1",
        "Views.More.ps1",
        "Views.Settings.Controls.ps1",
        "Views.Settings.ps1",
        "SelfTest.ps1"
    )
    $expectedLine = 'foreach ($moduleName in @("' + ($expectedModules -join '", "') + '")) {'
    if ($mainRaw -notlike "*$expectedLine*") {
        throw "TaskPomodoro.ps1 module load order does not match expected order."
    }
    foreach ($module in $expectedModules) {
        Test-RequiredFile (Join-Path $modulesDir $module)
    }
    "Module load order and required modules are present"
}

Invoke-Check "Architecture boundaries" {
    foreach ($taskModule in @("TaskModel.ps1", "TaskStore.ps1", "TaskQueries.ps1", "TaskOrdering.ps1", "TaskCommands.ps1")) {
        Test-FileDoesNotContain (Join-Path $modulesDir $taskModule) @(
            "System.Windows.Forms",
            "MessageBox",
            "Render-CurrentView",
            "Set-Status",
            "Set-ActiveView",
            "Update-TimerLabels"
        ) "$taskModule must not directly call UI APIs."
    }

    Test-FileDoesNotContain (Join-Path $modulesDir "PomodoroEngine.ps1") @(
        '$script:PomodorosFile',
        "System.Windows.Forms",
        "MessageBox",
        "Render-CurrentView",
        "Set-Status",
        "Set-ActiveView",
        "Update-TimerLabels"
    ) "PomodoroEngine.ps1 must return state results instead of driving UI."

    Test-FileDoesNotContain (Join-Path $modulesDir "PomodoroRecords.ps1") @(
        "System.Windows.Forms",
        "MessageBox",
        "Render-CurrentView",
        "Set-Status",
        "Set-ActiveView",
        "Update-TimerLabels"
    ) "PomodoroRecords.ps1 must stay free of UI effects."

    Test-FileDoesNotContain (Join-Path $modulesDir "Storage.ps1") @(
        '$script:DataDir',
        '$script:ConfigDir',
        '$script:BackupDir',
        '$script:RootDir'
    ) "Storage.ps1 must use AppState path accessors."

    Test-FileDoesNotContain (Join-Path $modulesDir "SettingsStore.ps1") @(
        '$script:SettingsFile'
    ) "SettingsStore.ps1 must use AppState path accessors."

    Test-FileDoesNotContain (Join-Path $modulesDir "TaskStore.ps1") @(
        '$script:TasksFile'
    ) "TaskStore.ps1 must use AppState path accessors."

    "Business modules respect current UI boundary rules"
}

Invoke-Check "File size guardrails" {
    $checks = @(
        @{ Path = $mainScript; Max = 600 },
        @{ Path = Join-Path $supportScriptsDir "Invoke-AutomatedChecks.ps1"; Max = 560 },
        @{ Path = Join-Path $supportScriptsDir "New-ReleasePackage.ps1"; Max = 300 },
        @{ Path = Join-Path $modulesDir "AppState.ps1"; Max = 90 },
        @{ Path = Join-Path $modulesDir "TaskModel.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "TaskStore.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TaskQueries.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "TaskOrdering.ps1"; Max = 220 },
        @{ Path = Join-Path $modulesDir "TaskCommands.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "TaskDetails.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "TaskArchive.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "TaskFormat.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "PomodoroRecords.ps1"; Max = 60 },
        @{ Path = Join-Path $modulesDir "PomodoroAudio.ps1"; Max = 150 },
        @{ Path = Join-Path $modulesDir "PomodoroEffects.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "PomodoroEngine.ps1"; Max = 230 },
        @{ Path = Join-Path $modulesDir "AppRelaunch.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "AppMaintenance.ps1"; Max = 160 },
        @{ Path = Join-Path $modulesDir "DesktopShortcut.ps1"; Max = 230 },
        @{ Path = Join-Path $modulesDir "UiTimer.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "BottomChrome.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "WindowSize.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "WindowDrag.ps1"; Max = 80 },
        @{ Path = Join-Path $modulesDir "HelpSurface.ps1"; Max = 160 },
        @{ Path = Join-Path $modulesDir "WatermarkMode.ps1"; Max = 280 },
        @{ Path = Join-Path $modulesDir "UiText.ps1"; Max = 300 },
        @{ Path = Join-Path $modulesDir "SettingsStore.ps1"; Max = 220 },
        @{ Path = Join-Path $modulesDir "Storage.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "Views.Core.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "Views.Task.Controls.ps1"; Max = 210 },
        @{ Path = Join-Path $modulesDir "Views.Task.ListDrawing.ps1"; Max = 130 },
        @{ Path = Join-Path $modulesDir "Views.Task.DetailsDialog.ps1"; Max = 230 },
        @{ Path = Join-Path $modulesDir "Views.Task.Edit.ps1"; Max = 120 },
        @{ Path = Join-Path $modulesDir "Views.Task.ps1"; Max = 260 },
        @{ Path = Join-Path $modulesDir "Views.Task.Menu.ps1"; Max = 340 },
        @{ Path = Join-Path $modulesDir "Views.Timer.ps1"; Max = 180 },
        @{ Path = Join-Path $modulesDir "Views.More.ps1"; Max = 140 },
        @{ Path = Join-Path $modulesDir "Views.Settings.ps1"; Max = 260 },
        @{ Path = Join-Path $modulesDir "Views.Settings.Controls.ps1"; Max = 240 },
        @{ Path = Join-Path $modulesDir "SelfTest.ps1"; Max = 430 }
    )
    $details = foreach ($check in $checks) {
        Test-MaxLineCount ([string]$check.Path) ([int]$check.Max)
    }
    $details -join "`n"
}

Invoke-Check "Required launch and media assets" {
    Test-RequiredFile (Join-Path $rootDir "StartTaskPomodoro.vbs")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\focus-start.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\focus-loop.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\break-start.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\audio\break-loop.wav")
    Test-RequiredFile (Join-Path $rootDir "assets\sponsor\wechat-sponsor.jpg")

    $icons = @(
        Join-Path $rootDir "assets\icon\task-pomodoro-g-desktop.ico"
        Join-Path $rootDir "assets\icon\task-pomodoro-g.ico"
        Join-Path $rootDir "assets\icon\task-pomodoro.ico"
    )
    if (-not (@($icons | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -gt 0)) {
        throw "No application icon was found."
    }
    "Launch script, audio, and icon assets are present"
}

if ($SkipDataFiles) {
    Add-CheckResult "Runtime data schema" "SKIP" "Skipped by -SkipDataFiles"
}
else {
    Invoke-Check "Runtime data schema" {
        $tasksFile = Join-Path $dataDir "tasks.json"
        if (Test-Path -LiteralPath $tasksFile -PathType Leaf) {
            $tasks = Read-JsonFile $tasksFile
            $taskItems = @($tasks)
            $allowedStatuses = @("todo", "done", "archived")
            foreach ($task in $taskItems) {
                Assert-Property $task "id" "task"
                Assert-Property $task "title" "task $($task.id)"
                Assert-Property $task "status" "task $($task.id)"
                Assert-Property $task "createdAt" "task $($task.id)"
                Assert-Property $task "pomodoroCount" "task $($task.id)"
                if ($allowedStatuses -notcontains [string]$task.status) {
                    throw "task $($task.id) has invalid status '$($task.status)'"
                }
                [DateTimeOffset]::Parse([string]$task.createdAt) | Out-Null
                if ([int]$task.pomodoroCount -lt 0) {
                    throw "task $($task.id) has negative pomodoroCount"
                }
            }
        }

        $settingsFile = Join-Path $configDir "settings.json"
        if (Test-Path -LiteralPath $settingsFile -PathType Leaf) {
            $settings = Read-JsonFile $settingsFile
            Assert-Property $settings "Opacity" "settings"
            Assert-Property $settings "WorkMinutes" "settings"
            Assert-Property $settings "ShortBreakMinutes" "settings"
            $opacity = [double]$settings.Opacity
            $taskFontSize = 15.0
            if ($settings.PSObject.Properties.Name -contains "TaskFontSize") {
                $taskFontSize = [double]$settings.TaskFontSize
            }
            $workMinutes = [int]$settings.WorkMinutes
            $breakMinutes = [int]$settings.ShortBreakMinutes
            if ($opacity -lt 0.30 -or $opacity -gt 1.00) {
                throw "settings Opacity is outside 0.30..1.00"
            }
            if ($taskFontSize -lt 9.0 -or $taskFontSize -gt 32.0) {
                throw "settings TaskFontSize is outside 9.0..32.0"
            }
            if ($workMinutes -lt 1 -or $workMinutes -gt 180) {
                throw "settings WorkMinutes is outside 1..180"
            }
            if ($breakMinutes -lt 1 -or $breakMinutes -gt 60) {
                throw "settings ShortBreakMinutes is outside 1..60"
            }
        }

        $pomodorosFile = Join-Path $dataDir "pomodoros.jsonl"
        if (Test-Path -LiteralPath $pomodorosFile -PathType Leaf) {
            $lineNumber = 0
            $allowedResults = @("completed", "interrupted", "skipped_break", "break_completed")
            foreach ($line in Get-Content -LiteralPath $pomodorosFile -Encoding UTF8) {
                $lineNumber++
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                $record = $line | ConvertFrom-Json
                Assert-Property $record "id" "pomodoro line $lineNumber"
                Assert-Property $record "startedAt" "pomodoro line $lineNumber"
                Assert-Property $record "endedAt" "pomodoro line $lineNumber"
                Assert-Property $record "plannedMinutes" "pomodoro line $lineNumber"
                Assert-Property $record "actualMinutes" "pomodoro line $lineNumber"
                Assert-Property $record "result" "pomodoro line $lineNumber"
                if ($allowedResults -notcontains [string]$record.result) {
                    throw "pomodoro line $lineNumber has invalid result '$($record.result)'"
                }
            }
        }

        if (Test-Path -LiteralPath $dataDir -PathType Container) {
            $runtimeFiles = @(Get-ChildItem -LiteralPath $dataDir -File -Include "*.json", "*.jsonl" -Recurse -ErrorAction SilentlyContinue)
            foreach ($file in $runtimeFiles) {
                $raw = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
                if ($raw -match "__selftest") {
                    throw "self-test marker found in runtime data: $($file.FullName)"
                }
            }
        }

        "Runtime data files are parseable"
    }
}

if ($SkipSelfTest) {
    Add-CheckResult "Invalid data recovery" "SKIP" "Skipped with -SkipSelfTest"
}
else {
    Invoke-Check "Invalid data recovery" {
        $copy = New-IsolatedProjectCopy $rootDir
        try {
            $copyRoot = [string]$copy.RootDir
            $copyDataDir = Join-Path $copyRoot "data"
            if (-not (Test-Path -LiteralPath $copyDataDir)) {
                New-Item -ItemType Directory -Path $copyDataDir | Out-Null
            }
            "{ invalid json" | Set-Content -LiteralPath (Join-Path $copyDataDir "tasks.json") -Encoding UTF8
            $output = Invoke-MainSelfTest $copyRoot
            $backups = @(Get-ChildItem -LiteralPath (Join-Path $copyDataDir "backups") -Filter "tasks.json.*.invalid.bak" -File -ErrorAction SilentlyContinue)
            if ($backups.Count -lt 1) {
                throw "Invalid tasks.json did not produce an invalid backup."
            }
            "$output`nInvalid backup count=$($backups.Count)"
        }
        finally {
            Remove-IsolatedProjectCopy ([string]$copy.CleanupDir)
        }
    }
}

if ($SkipSelfTest) {
    Add-CheckResult "Main script self-test" "SKIP" "Skipped by -SkipSelfTest"
}
else {
    Invoke-Check "Main script self-test" {
        $selfTestRoot = $rootDir
        $cleanupDir = ""
        if (-not $SelfTestInPlace) {
            $copy = New-IsolatedProjectCopy $rootDir
            $selfTestRoot = [string]$copy.RootDir
            $cleanupDir = [string]$copy.CleanupDir
        }
        try {
            $output = Invoke-MainSelfTest $selfTestRoot
        }
        finally {
            if (-not $SelfTestInPlace -and -not $KeepSelfTestCopy) {
                Remove-IsolatedProjectCopy $cleanupDir
            }
        }

        $mode = "isolated copy"
        if ($SelfTestInPlace) {
            $mode = "current workspace"
        }
        "$output`nMode: $mode"
    }
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportParent = Split-Path -Parent $ReportPath
    if (-not [string]::IsNullOrWhiteSpace($reportParent) -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -ItemType Directory -Path $reportParent | Out-Null
    }
    $script:Results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

if ($script:HasFailure) {
    exit 1
}

exit 0
