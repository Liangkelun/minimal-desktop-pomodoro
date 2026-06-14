param(
    [string]$Version = "",
    [string]$OutputDir = "",
    [switch]$SkipValidation,
    [switch]$KeepStaging,
    [switch]$ChineseFriendly
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

function ConvertFrom-Base64Text([string]$Value) {
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function New-RootLauncher([string]$PackageRoot, [string]$FileName) {
    $path = Join-Path $PackageRoot $FileName
    $content = @(
        "Option Explicit",
        "",
        "Dim shell, fso, baseDir, appDir, launcher",
        "Set shell = CreateObject(""WScript.Shell"")",
        "Set fso = CreateObject(""Scripting.FileSystemObject"")",
        "",
        "baseDir = fso.GetParentFolderName(WScript.ScriptFullName)",
        "appDir = fso.BuildPath(baseDir, ""task-pomodoro"")",
        "launcher = fso.BuildPath(appDir, ""StartTaskPomodoro.vbs"")",
        "",
        "If Not fso.FileExists(launcher) Then",
        "    MsgBox ""Missing launcher:"" & vbCrLf & launcher, 48, ""Minimal Desktop Pomodoro""",
        "Else",
        "    shell.Run Chr(34) & launcher & Chr(34), 1, False",
        "End If"
    )
    Set-Content -LiteralPath $path -Value $content -Encoding ASCII
}

function Get-CSharpCompilerPath {
    $candidates = @(
        (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
        (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"),
        (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v3.5\csc.exe"),
        (Join-Path $env:WINDIR "Microsoft.NET\Framework\v3.5\csc.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    $command = Get-Command csc.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return [string]$command.Source
    }
    return ""
}

function New-RootExeLauncher([string]$PackageRoot, [string]$FileName, [string]$IconPath) {
    $compiler = Get-CSharpCompilerPath
    if ([string]::IsNullOrWhiteSpace($compiler)) {
        throw "Missing C# compiler for root launcher."
    }
    if (-not (Test-Path -LiteralPath $IconPath -PathType Leaf)) {
        throw "Missing launcher icon: $IconPath"
    }

    $sourcePath = Join-Path $PackageRoot "__root_launcher.cs"
    $outputPath = Join-Path $PackageRoot $FileName
    $source = @(
        "using System;",
        "using System.Diagnostics;",
        "using System.IO;",
        "using System.Windows.Forms;",
        "",
        "internal static class Program",
        "{",
        "    [STAThread]",
        "    private static int Main()",
        "    {",
        "        string baseDir = AppDomain.CurrentDomain.BaseDirectory;",
        "        string launcher = Path.Combine(Path.Combine(baseDir, ""task-pomodoro""), ""StartTaskPomodoro.vbs"");",
        "        if (!File.Exists(launcher))",
        "        {",
        "            MessageBox.Show(""Missing launcher:\r\n"" + launcher, ""Minimal Desktop Pomodoro"", MessageBoxButtons.OK, MessageBoxIcon.Warning);",
        "            return 1;",
        "        }",
        "        ProcessStartInfo startInfo = new ProcessStartInfo();",
        "        startInfo.FileName = launcher;",
        "        startInfo.WorkingDirectory = Path.GetDirectoryName(launcher);",
        "        startInfo.UseShellExecute = true;",
        "        Process.Start(startInfo);",
        "        return 0;",
        "    }",
        "}"
    )
    try {
        Set-Content -LiteralPath $sourcePath -Value $source -Encoding ASCII
        $output = & $compiler @(
            "/nologo",
            "/target:winexe",
            "/platform:anycpu",
            "/reference:System.dll",
            "/reference:System.Windows.Forms.dll",
            "/win32icon:$IconPath",
            "/out:$outputPath",
            $sourcePath
        ) 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Root launcher compile failed:`n$(@($output) -join "`n")"
        }
        if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw "Root launcher was not created: $outputPath"
        }
    }
    finally {
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            Remove-Item -LiteralPath $sourcePath -Force
        }
    }
}

function New-ChineseQuickStart([string]$PackageRoot, [string]$FileName) {
    $lines = @(
        (ConvertFrom-Base64Text "5p6B566A5qGM6Z2i55Wq6IyE6ZKfIOS9v+eUqOivtOaYjg=="),
        "",
        (ConvertFrom-Base64Text "MS4g6K+35YWI6Kej5Y6L5pW05Liq5paH5Lu25aS544CC"),
        (ConvertFrom-Base64Text "Mi4g5Y+M5Ye74oCc5Y+M5Ye75ZCv5YqoIOaegeeugOahjOmdoueVquiMhOmSny5leGXigJ3lkK/liqjnqIvluo/jgII="),
        (ConvertFrom-Base64Text "5aaC5p6c57O757uf5oum5oiqIGV4Ze+8jOS5n+WPr+S7peWPjOWHu+KAnOWPjOWHu+WQr+WKqCDmnoHnroDmoYzpnaLnlarojITpkp8udmJz4oCd44CC"),
        (ConvertFrom-Base64Text "My4g6aaW5qyh5ZCv5Yqo5pe277yM5Y+v5Lul6YCJ5oup5re75Yqg5qGM6Z2i5b+r5o235pa55byP44CC"),
        (ConvertFrom-Base64Text "NC4g6K+35LiN6KaB5Y+q56e75Yqo5ZCv5Yqo5paH5Lu277yM5L+d5oyB5pW05Liq5paH5Lu25aS55a6M5pW044CC")
    )
    Set-Content -LiteralPath (Join-Path $PackageRoot $FileName) -Value $lines -Encoding UTF8
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

function Test-ZipContents([string]$ZipPath, [string]$PackageName, [string]$RootLauncherName, [string]$RootExeLauncherName, [string]$QuickStartName) {
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
        if (-not [string]::IsNullOrWhiteSpace($RootLauncherName)) {
            $required += "$PackageName/$RootLauncherName"
        }
        if (-not [string]::IsNullOrWhiteSpace($RootExeLauncherName)) {
            $required += "$PackageName/$RootExeLauncherName"
        }
        if (-not [string]::IsNullOrWhiteSpace($QuickStartName)) {
            $required += "$PackageName/$QuickStartName"
        }

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

$packageName = "minimal-desktop-pomodoro-v$Version"
$rootLauncherName = "Start Minimal Desktop Pomodoro.vbs"
$rootExeLauncherName = ""
$quickStartName = ""
if ($ChineseFriendly) {
    $packageName = (ConvertFrom-Base64Text "5p6B566A5qGM6Z2i55Wq6IyE6ZKfLXY=") + $Version
    $rootLauncherName = ConvertFrom-Base64Text "5Y+M5Ye75ZCv5YqoIOaegeeugOahjOmdoueVquiMhOmSny52YnM="
    $rootExeLauncherName = ConvertFrom-Base64Text "5Y+M5Ye75ZCv5YqoIOaegeeugOahjOmdoueVquiMhOmSny5leGU="
    $quickStartName = ConvertFrom-Base64Text "5L2/55So6K+05piOLnR4dA=="
}
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
    New-RootLauncher $packageRoot $rootLauncherName
    if (-not [string]::IsNullOrWhiteSpace($rootExeLauncherName)) {
        New-RootExeLauncher $packageRoot $rootExeLauncherName (Join-Path $appRoot "assets\icon\task-pomodoro-g-desktop.ico")
    }
    if (-not [string]::IsNullOrWhiteSpace($quickStartName)) {
        New-ChineseQuickStart $packageRoot $quickStartName
    }

    Copy-RequiredFile (Join-Path $appRoot "TaskPomodoro.ps1") (Join-Path $appPackageRoot "TaskPomodoro.ps1")
    Copy-RequiredFile (Join-Path $appRoot "StartTaskPomodoro.vbs") (Join-Path $appPackageRoot "StartTaskPomodoro.vbs")
    Copy-RequiredFile (Join-Path $appRoot "VERSION") (Join-Path $appPackageRoot "VERSION")
    Copy-RequiredDirectory (Join-Path $appRoot "modules") (Join-Path $appPackageRoot "modules")
    Copy-RequiredDirectory (Join-Path $appRoot "assets\audio") (Join-Path $appPackageRoot "assets\audio")
    Copy-MatchingFiles (Join-Path $appRoot "assets\icon") (Join-Path $appPackageRoot "assets\icon") @("*.ico", "*.png") -RequireAny | Out-Null
    Copy-RequiredDirectory (Join-Path $appRoot "assets\sponsor") (Join-Path $appPackageRoot "assets\sponsor")

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

    $entryCount = Test-ZipContents $zipPath $packageName $rootLauncherName $rootExeLauncherName $quickStartName
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
