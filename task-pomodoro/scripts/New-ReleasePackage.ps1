param(
    [string]$Version = "",
    [string]$OutputDir = "",
    [switch]$SkipValidation,
    [switch]$KeepStaging
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

function New-RequiredDirectory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Copy-RequiredFile([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Missing required file: $Source"
    }
    $parent = Split-Path -Parent $Destination
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-RequiredDirectory $parent
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-RequiredDirectory([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Missing required directory: $Source"
    }
    New-RequiredDirectory $Destination
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Copy-MatchingFiles([string]$SourceDir, [string]$DestinationDir, [string[]]$Patterns, [switch]$RequireAny) {
    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        throw "Missing source directory: $SourceDir"
    }
    New-RequiredDirectory $DestinationDir

    $copied = 0
    foreach ($pattern in $Patterns) {
        $files = @(Get-ChildItem -LiteralPath $SourceDir -Filter $pattern -File)
        foreach ($file in $files) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $DestinationDir $file.Name) -Force
            $copied++
        }
    }

    if ($RequireAny -and $copied -lt 1) {
        throw "No files matched required patterns in $SourceDir"
    }

    return $copied
}

function Remove-SafeTempDirectory([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "TaskPomodoroRelease"
    $resolvedTempRoot = (Resolve-Path -LiteralPath $tempRoot).Path.TrimEnd("\")
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    if (-not $resolvedPath.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside release temp root: $resolvedPath"
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Invoke-PackageValidation([string]$AppPackageRoot) {
    $checkScript = Join-Path $AppPackageRoot "scripts\Invoke-AutomatedChecks.ps1"
    if (-not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        throw "Missing package validation script: $checkScript"
    }

    $powerShellExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
        $powerShellExe = "powershell"
    }

    $output = & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $checkScript -SkipDataFiles 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Package validation failed:`n$(@($output) -join "`n")"
    }

    return (@($output) -join "`n")
}

function Assert-NoRuntimeState([string]$PackageRoot) {
    $forbidden = @(
        "task-pomodoro\data",
        "task-pomodoro\config",
        "task-pomodoro\launch.log",
        "task-pomodoro\update.log",
        "task-pomodoro\dist"
    )

    foreach ($relativePath in $forbidden) {
        $path = Join-Path $PackageRoot $relativePath
        if (Test-Path -LiteralPath $path) {
            throw "Release package contains runtime state: $relativePath"
        }
    }
}

function Test-ZipContents([string]$ZipPath, [string]$PackageName) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = @($archive.Entries | ForEach-Object { $_.FullName -replace "\\", "/" })
        $required = @(
            "$PackageName/.gitignore",
            "$PackageName/README.md",
            "$PackageName/CHANGELOG.md",
            "$PackageName/LICENSE",
            "$PackageName/task-pomodoro/TaskPomodoro.ps1",
            "$PackageName/task-pomodoro/VERSION",
            "$PackageName/task-pomodoro/modules/TaskStore.ps1",
            "$PackageName/task-pomodoro/scripts/Invoke-AutomatedChecks.ps1"
        )

        foreach ($entry in $required) {
            if ($entries -notcontains $entry) {
                throw "Release zip is missing required entry: $entry"
            }
        }

        $forbidden = @($entries | Where-Object {
            $_ -match "/task-pomodoro/(data|config)/" -or
            $_ -match "/task-pomodoro/launch\.log$" -or
            $_ -match "/task-pomodoro/update\.log$" -or
            $_ -match "/task-pomodoro/dist/"
        })
        if ($forbidden.Count -gt 0) {
            throw "Release zip contains runtime state:`n$($forbidden -join "`n")"
        }

        return $entries.Count
    }
    finally {
        $archive.Dispose()
    }
}

function Compress-ReleaseArchive([string]$SourcePath, [string]$DestinationPath) {
    $lastError = $null
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            if ($attempt -gt 1) {
                Start-Sleep -Milliseconds (250 * $attempt)
            }
            if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
                Remove-Item -LiteralPath $DestinationPath -Force
            }
            Compress-Archive -LiteralPath $SourcePath -DestinationPath $DestinationPath -Force
            return
        }
        catch {
            $lastError = $_
            if ($attempt -eq 5) {
                throw $lastError
            }
        }
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$appRoot = Split-Path -Parent $scriptDir
$workspaceRoot = Split-Path -Parent $appRoot

if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionFile = Join-Path $appRoot "VERSION"
    if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) {
        throw "Missing VERSION file: $versionFile"
    }
    $Version = (Get-Content -LiteralPath $versionFile -Encoding UTF8 -Raw).Trim()
}

if ($Version -notmatch '^\d+\.\d+\.\d+([-.][0-9A-Za-z.-]+)?$') {
    throw "Version must be semver-like. Current value: $Version"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $workspaceRoot "dist"
}
else {
    $OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
}

$packageName = "task-pomodoro-v$Version"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "TaskPomodoroRelease"
New-RequiredDirectory $tempRoot
$runRoot = Join-Path $tempRoot ("run-" + [guid]::NewGuid().ToString("N"))
$packageRoot = Join-Path $runRoot $packageName
$appPackageRoot = Join-Path $packageRoot "task-pomodoro"

try {
    New-RequiredDirectory $appPackageRoot

    Copy-RequiredFile (Join-Path $workspaceRoot ".gitignore") (Join-Path $packageRoot ".gitignore")
    Copy-RequiredFile (Join-Path $workspaceRoot "README.md") (Join-Path $packageRoot "README.md")
    Copy-RequiredFile (Join-Path $workspaceRoot "CHANGELOG.md") (Join-Path $packageRoot "CHANGELOG.md")
    Copy-RequiredFile (Join-Path $workspaceRoot "LICENSE") (Join-Path $packageRoot "LICENSE")
    Copy-RequiredDirectory (Join-Path $workspaceRoot "docs") (Join-Path $packageRoot "docs")

    Copy-RequiredFile (Join-Path $appRoot "TaskPomodoro.ps1") (Join-Path $appPackageRoot "TaskPomodoro.ps1")
    Copy-RequiredFile (Join-Path $appRoot "StartTaskPomodoro.vbs") (Join-Path $appPackageRoot "StartTaskPomodoro.vbs")
    Copy-RequiredFile (Join-Path $appRoot "VERSION") (Join-Path $appPackageRoot "VERSION")
    Copy-RequiredDirectory (Join-Path $appRoot "modules") (Join-Path $appPackageRoot "modules")
    Copy-RequiredDirectory (Join-Path $appRoot "assets\audio") (Join-Path $appPackageRoot "assets\audio")
    Copy-MatchingFiles (Join-Path $appRoot "assets\icon") (Join-Path $appPackageRoot "assets\icon") @("*.ico", "*.png") -RequireAny | Out-Null

    $packageScriptsDir = Join-Path $appPackageRoot "scripts"
    foreach ($scriptName in @(
        "Invoke-AutomatedChecks.ps1",
        "New-ReleasePackage.ps1",
        "InstallDesktopShortcutIcon.ps1",
        "InspectDesktopShortcut.ps1",
        "RefreshDesktopIcons.ps1"
    )) {
        Copy-RequiredFile (Join-Path $scriptDir $scriptName) (Join-Path $packageScriptsDir $scriptName)
    }

    Assert-NoRuntimeState $packageRoot

    if (-not $SkipValidation) {
        $validationOutput = Invoke-PackageValidation $appPackageRoot
        Write-Host $validationOutput
    }
    else {
        Write-Host "[SKIP] Package validation"
    }

    Assert-NoRuntimeState $packageRoot

    New-RequiredDirectory $OutputDir
    $zipPath = Join-Path $OutputDir "$packageName.zip"
    if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-ReleaseArchive $packageRoot $zipPath
    $zipItem = Get-Item -LiteralPath $zipPath
    if ($zipItem.Length -le 0) {
        throw "Release zip is empty: $zipPath"
    }

    $entryCount = Test-ZipContents $zipPath $packageName
    Write-Host "[PASS] Release package"
    Write-Host "Package: $zipPath"
    Write-Host "Entries: $entryCount"
}
finally {
    if (-not $KeepStaging) {
        Remove-SafeTempDirectory $runRoot
    }
    else {
        Write-Host "Staging: $runRoot"
    }
}
