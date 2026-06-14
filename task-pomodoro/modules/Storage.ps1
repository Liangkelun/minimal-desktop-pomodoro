# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Initialize-Storage {
    Ensure-Directory $script:DataDir
    Ensure-Directory $script:ConfigDir
    Ensure-Directory $script:BackupDir
}

function Get-IsoNow {
    return (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
}

function Get-TodayString {
    return (Get-Date).ToString("yyyy-MM-dd")
}

function Get-AppScopeHash {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(([string]$script:RootDir).ToLowerInvariant())
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([BitConverter]::ToString($hash).Replace("-", "")).Substring(0, 16)
}

function Get-AppScopedMutexName([string]$Suffix) {
    return "Local\MinimalDesktopPomodoro-$Suffix-$(Get-AppScopeHash)"
}

function Invoke-WithNamedMutex([string]$Name, [scriptblock]$Action) {
    $mutex = New-Object System.Threading.Mutex($false, $Name)
    try {
        if (-not $mutex.WaitOne(5000)) {
            throw "Timed out waiting for lock: $Name"
        }
        & $Action
    }
    finally {
        try { $mutex.ReleaseMutex() } catch {}
        $mutex.Dispose()
    }
}

function Ensure-Property([object]$Object, [string]$Name, [object]$Value) {
    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        Add-Member -InputObject $Object -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Backup-DataFile([string]$Path, [string]$Reason) {
    if (Test-Path -LiteralPath $Path) {
        $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $name = [System.IO.Path]::GetFileName($Path)
        $dest = Join-Path $script:BackupDir "$name.$stamp.$Reason.bak"
        Copy-Item -LiteralPath $Path -Destination $dest -Force
    }
}

function Write-JsonAtomic([string]$Path, [object]$Data) {
    Invoke-WithNamedMutex (Get-AppScopedMutexName "data") {
        $tmp = "$Path.$PID.$([guid]::NewGuid().ToString('N')).tmp"
        $json = ConvertTo-Json -InputObject $Data -Depth 12
        if ([string]::IsNullOrWhiteSpace($json)) {
            $json = "[]"
        }
        try {
            $json | Set-Content -LiteralPath $tmp -Encoding UTF8
            Move-Item -LiteralPath $tmp -Destination $Path -Force
        }
        finally {
            if (Test-Path -LiteralPath $tmp) {
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Get-DefaultAudioPath([string]$FileName) {
    $path = Join-Path $script:RootDir "assets\audio\$FileName"
    if (Test-Path -LiteralPath $path) {
        return $path
    }
    return ""
}

function Get-AppIconPath {
    foreach ($fileName in @("task-pomodoro-g.ico", "task-pomodoro.ico")) {
        $path = Join-Path $script:RootDir "assets\icon\$fileName"
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    return ""
}

