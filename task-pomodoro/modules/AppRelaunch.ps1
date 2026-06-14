# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function ConvertTo-PowerShellSingleQuoted([string]$Value) {
    return "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-ProcessQuotedArgument([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

function ConvertTo-EncodedPowerShellCommand([string]$Command) {
    return [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Command))
}

function New-AppMaintenanceLogPath([string]$Prefix) {
    $logDir = Join-Path (Get-AppPath "DataDir") "logs"
    Ensure-Directory $logDir
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $suffix = [guid]::NewGuid().ToString("N").Substring(0, 6)
    return Join-Path $logDir "$Prefix-$stamp-$suffix.log"
}

function New-AppRelaunchScript([int]$ParentProcessId, [string]$LogPath) {
    $launcher = Join-Path $script:RootDir "StartTaskPomodoro.vbs"
    $scriptPath = Join-Path $script:RootDir "TaskPomodoro.ps1"
    $mutexName = Get-AppScopedMutexName "instance"

    return @(
        '$ErrorActionPreference = "Continue"',
        ('$parentProcessId = ' + [string]$ParentProcessId),
        ('$launcher = ' + (ConvertTo-PowerShellSingleQuoted $launcher)),
        ('$scriptPath = ' + (ConvertTo-PowerShellSingleQuoted $scriptPath)),
        ('$logPath = ' + (ConvertTo-PowerShellSingleQuoted $LogPath)),
        ('$mutexName = ' + (ConvertTo-PowerShellSingleQuoted $mutexName)),
        'function Write-RelaunchLog([string]$Message) { try { Add-Content -LiteralPath $logPath -Value ((Get-Date -Format o) + " " + $Message) -Encoding UTF8 } catch {} }',
        'function ConvertTo-QuotedProcessArgument([string]$Value) { return ''"'' + $Value.Replace(''"'', ''\"'') + ''"'' }',
        'try { New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null } catch {}',
        'Write-RelaunchLog ("helper started parentPid=" + $parentProcessId)',
        'try { Wait-Process -Id $parentProcessId -Timeout 30 -ErrorAction SilentlyContinue; Write-RelaunchLog "parent wait complete" } catch { Write-RelaunchLog ("parent wait error=" + $_.Exception.Message) }',
        '$mutex = $null',
        'try {',
        '    $mutex = [System.Threading.Mutex]::OpenExisting($mutexName)',
        '    if ($mutex.WaitOne(30000)) {',
        '        $mutex.ReleaseMutex()',
        '        Write-RelaunchLog "instance lock released"',
        '    } else {',
        '        Write-RelaunchLog "instance lock wait timeout"',
        '    }',
        '} catch [System.Threading.AbandonedMutexException] {',
        '    try { if ($null -ne $mutex) { $mutex.ReleaseMutex() } } catch {}',
        '    Write-RelaunchLog "instance lock abandoned"',
        '} catch [System.Threading.WaitHandleCannotBeOpenedException] {',
        '    Write-RelaunchLog "instance lock not present"',
        '} catch {',
        '    Write-RelaunchLog ("instance lock wait error=" + $_.Exception.Message)',
        '} finally {',
        '    if ($null -ne $mutex) { $mutex.Dispose() }',
        '}',
        'Start-Sleep -Milliseconds 200',
        'try {',
        '    if (Test-Path -LiteralPath $launcher) {',
        '        Start-Process -FilePath "wscript.exe" -ArgumentList @((ConvertTo-QuotedProcessArgument $launcher)) | Out-Null',
        '        Write-RelaunchLog ("started launcher=" + $launcher)',
        '    } else {',
        '        Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", (ConvertTo-QuotedProcessArgument $scriptPath)) -WindowStyle Hidden | Out-Null',
        '        Write-RelaunchLog ("started script=" + $scriptPath)',
        '    }',
        '} catch {',
        '    Write-RelaunchLog ("start failed=" + $_.Exception.Message)',
        '}'
    ) -join "`r`n"
}

function Start-AppRelaunchHelper([int]$ParentProcessId) {
    $logPath = New-AppMaintenanceLogPath "restart"
    $command = New-AppRelaunchScript $ParentProcessId $logPath
    $encoded = ConvertTo-EncodedPowerShellCommand $command
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-EncodedCommand", $encoded) -WindowStyle Hidden | Out-Null
    return $logPath
}
