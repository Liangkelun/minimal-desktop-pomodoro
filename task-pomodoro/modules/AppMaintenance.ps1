# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function ConvertTo-PowerShellSingleQuoted([string]$Value) {
    return "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-ProcessQuotedArgument([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Get-AppRepositoryRoot {
    $current = Get-Item -LiteralPath $script:RootDir -ErrorAction SilentlyContinue
    while ($null -ne $current) {
        if (Test-Path -LiteralPath (Join-Path $current.FullName ".git")) {
            return $current.FullName
        }
        $current = $current.Parent
    }
    return ""
}

function Test-GitUpdateEnabled {
    $repoRoot = Get-AppRepositoryRoot
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        return $false
    }
    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
        return $false
    }
    try {
        $remotes = @(git -C $repoRoot remote 2>$null)
        return ($remotes.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$remotes[0]))
    }
    catch {
        return $false
    }
}

function Start-AppInstanceLock {
    $createdNew = $false
    $name = Get-AppScopedMutexName "instance"
    $script:SingleInstanceMutex = New-Object System.Threading.Mutex($true, $name, [ref]$createdNew)
    if ($createdNew) {
        return $true
    }
    $script:SingleInstanceMutex.Dispose()
    $script:SingleInstanceMutex = $null
    [System.Windows.Forms.MessageBox]::Show((T "AppAlreadyRunning"), (T "AppTitle")) | Out-Null
    return $false
}

function Stop-AppInstanceLock {
    if ($null -eq $script:SingleInstanceMutex) {
        return
    }
    try {
        $script:SingleInstanceMutex.ReleaseMutex()
    }
    catch {
    }
    $script:SingleInstanceMutex.Dispose()
    $script:SingleInstanceMutex = $null
}

function Start-TaskPomodoroProcess {
    $launcher = Join-Path $script:RootDir "StartTaskPomodoro.vbs"
    $scriptPath = Join-Path $script:RootDir "TaskPomodoro.ps1"
    if (Test-Path -LiteralPath $launcher) {
        Start-Process -FilePath "wscript.exe" -ArgumentList (ConvertTo-ProcessQuotedArgument $launcher) | Out-Null
        return
    }
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", (ConvertTo-ProcessQuotedArgument $scriptPath)) -WindowStyle Hidden | Out-Null
}

function Restart-TaskPomodoroApp {
    Save-Settings
    $launcher = Join-Path $script:RootDir "StartTaskPomodoro.vbs"
    $scriptPath = Join-Path $script:RootDir "TaskPomodoro.ps1"
    $launcherArg = ConvertTo-PowerShellSingleQuoted (ConvertTo-ProcessQuotedArgument $launcher)
    $scriptPathArg = ConvertTo-PowerShellSingleQuoted (ConvertTo-ProcessQuotedArgument $scriptPath)
    $command = @(
        '$ErrorActionPreference = "Continue"',
        "try { Wait-Process -Id $PID -Timeout 15 -ErrorAction SilentlyContinue } catch {}",
        'Start-Sleep -Milliseconds 200',
        ('if (Test-Path -LiteralPath ' + (ConvertTo-PowerShellSingleQuoted $launcher) + ') {'),
        ('    Start-Process -FilePath "wscript.exe" -ArgumentList @(' + $launcherArg + ')'),
        '} else {',
        ('    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", ' + $scriptPathArg + ') -WindowStyle Hidden'),
        '}'
    ) -join "; "
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Command", $command) -WindowStyle Hidden | Out-Null
    if ($null -ne $script:Form -and -not $script:Form.IsDisposed) {
        $script:Form.Close()
    }
}

function Open-AppFolder {
    Start-Process -FilePath "explorer.exe" -ArgumentList (ConvertTo-ProcessQuotedArgument $script:RootDir) | Out-Null
}

function Invoke-GitUpdateAndRestart {
    if (-not (Test-GitUpdateEnabled)) {
        Show-HelpTopic "HelpUpdate" "UpdateInfoText"
        return
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show((T "UpdateGitConfirm"), (T "HelpUpdate"), [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Information)
    if ($confirm -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    Save-Settings
    $repoRoot = Get-AppRepositoryRoot
    $launcher = Join-Path $script:RootDir "StartTaskPomodoro.vbs"
    $scriptPath = Join-Path $script:RootDir "TaskPomodoro.ps1"
    $logPath = Join-Path $script:RootDir "update.log"
    $launcherArg = ConvertTo-PowerShellSingleQuoted (ConvertTo-ProcessQuotedArgument $launcher)
    $scriptPathArg = ConvertTo-PowerShellSingleQuoted (ConvertTo-ProcessQuotedArgument $scriptPath)
    $command = @(
        '$ErrorActionPreference = "Continue"',
        "try { Wait-Process -Id $PID -Timeout 20 -ErrorAction SilentlyContinue } catch {}",
        ('Set-Location -LiteralPath ' + (ConvertTo-PowerShellSingleQuoted $repoRoot)),
        ('"$(Get-Date -Format o) git pull --ff-only repo=' + $repoRoot.Replace('"', '""') + '" | Add-Content -LiteralPath ' + (ConvertTo-PowerShellSingleQuoted $logPath) + ' -Encoding UTF8'),
        ('git pull --ff-only *>> ' + (ConvertTo-PowerShellSingleQuoted $logPath)),
        '$gitExitCode = $LASTEXITCODE',
        ('"$(Get-Date -Format o) exitCode=$gitExitCode" | Add-Content -LiteralPath ' + (ConvertTo-PowerShellSingleQuoted $logPath) + ' -Encoding UTF8'),
        'if ($gitExitCode -ne 0) { "$(Get-Date -Format o) restarting current version after update failure" | Add-Content -LiteralPath ' + (ConvertTo-PowerShellSingleQuoted $logPath) + ' -Encoding UTF8',
        ('    if (Test-Path -LiteralPath ' + (ConvertTo-PowerShellSingleQuoted $launcher) + ') { Start-Process -FilePath "wscript.exe" -ArgumentList @(' + $launcherArg + ') }'),
        ('    else { Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", ' + $scriptPathArg + ') -WindowStyle Hidden }'),
        '    exit $gitExitCode }',
        ('if (Test-Path -LiteralPath ' + (ConvertTo-PowerShellSingleQuoted $launcher) + ') {'),
        ('    Start-Process -FilePath "wscript.exe" -ArgumentList @(' + $launcherArg + ')'),
        '} else {',
        ('    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", ' + $scriptPathArg + ') -WindowStyle Hidden'),
        '}'
    ) -join "; "

    Set-Status (T "UpdatingAndRestarting")
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Command", $command) -WindowStyle Hidden | Out-Null
    if ($null -ne $script:Form -and -not $script:Form.IsDisposed) {
        $script:Form.Close()
    }
}
