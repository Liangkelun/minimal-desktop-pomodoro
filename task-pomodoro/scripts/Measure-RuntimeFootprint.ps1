param(
    [int]$DurationSeconds = 300,
    [int]$SampleSeconds = 5,
    [string]$ReportPath = "",
    [int]$ProcessId = 0,
    [double]$MaxWorkingSetMB = 0,
    [double]$MaxPrivateMemoryMB = 0,
    [double]$MaxCpuPercent = 0
)

$ErrorActionPreference = "Stop"

function Get-TargetProcessId([int]$RequestedProcessId) {
    if ($RequestedProcessId -gt 0) {
        return $RequestedProcessId
    }

    $candidate = Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -like "*TaskPomodoro.ps1*" -and $_.ProcessId -ne $PID
    } | Sort-Object CreationDate | Select-Object -First 1
    if ($null -eq $candidate) {
        throw "TaskPomodoro.ps1 process was not found. Start the app first, or pass -ProcessId."
    }
    return [int]$candidate.ProcessId
}

function ConvertTo-MB([double]$Bytes) {
    return [Math]::Round(($Bytes / 1MB), 2)
}

if ($DurationSeconds -lt 1) { $DurationSeconds = 1 }
if ($SampleSeconds -lt 1) { $SampleSeconds = 1 }

$targetPid = Get-TargetProcessId $ProcessId
$samples = @()
$startedAt = Get-Date
$deadline = $startedAt.AddSeconds($DurationSeconds)
$previousProcess = Get-Process -Id $targetPid -ErrorAction Stop
$previousAt = Get-Date
$previousCpu = $previousProcess.TotalProcessorTime.TotalSeconds

while ((Get-Date) -le $deadline) {
    $now = Get-Date
    $process = Get-Process -Id $targetPid -ErrorAction Stop
    $cpuSeconds = $process.TotalProcessorTime.TotalSeconds
    $elapsedSeconds = [Math]::Max(0.001, ($now - $previousAt).TotalSeconds)
    $cpuDelta = [Math]::Max(0, ($cpuSeconds - $previousCpu))
    $cpuPercent = [Math]::Round((100 * $cpuDelta / $elapsedSeconds / [Environment]::ProcessorCount), 2)

    $samples += [pscustomobject]@{
        Timestamp = $now.ToString("o")
        WorkingSetMB = ConvertTo-MB $process.WorkingSet64
        PrivateMemoryMB = ConvertTo-MB $process.PrivateMemorySize64
        CpuPercent = $cpuPercent
    }

    $previousAt = $now
    $previousCpu = $cpuSeconds
    if ((Get-Date).AddSeconds($SampleSeconds) -gt $deadline) { break }
    Start-Sleep -Seconds $SampleSeconds
}

if ($samples.Count -lt 1) {
    throw "No samples collected."
}

$summary = [pscustomobject]@{
    ProcessId = $targetPid
    StartedAt = $startedAt.ToString("o")
    EndedAt = (Get-Date).ToString("o")
    DurationSeconds = $DurationSeconds
    SampleSeconds = $SampleSeconds
    SampleCount = $samples.Count
    MaxWorkingSetMB = [Math]::Round((@($samples | Measure-Object WorkingSetMB -Maximum).Maximum), 2)
    AvgWorkingSetMB = [Math]::Round((@($samples | Measure-Object WorkingSetMB -Average).Average), 2)
    MaxPrivateMemoryMB = [Math]::Round((@($samples | Measure-Object PrivateMemoryMB -Maximum).Maximum), 2)
    AvgPrivateMemoryMB = [Math]::Round((@($samples | Measure-Object PrivateMemoryMB -Average).Average), 2)
    MaxCpuPercent = [Math]::Round((@($samples | Measure-Object CpuPercent -Maximum).Maximum), 2)
    AvgCpuPercent = [Math]::Round((@($samples | Measure-Object CpuPercent -Average).Average), 2)
    Samples = $samples
}

$failed = $false
if ($MaxWorkingSetMB -gt 0 -and $summary.MaxWorkingSetMB -gt $MaxWorkingSetMB) { $failed = $true }
if ($MaxPrivateMemoryMB -gt 0 -and $summary.MaxPrivateMemoryMB -gt $MaxPrivateMemoryMB) { $failed = $true }
if ($MaxCpuPercent -gt 0 -and $summary.MaxCpuPercent -gt $MaxCpuPercent) { $failed = $true }

$json = $summary | ConvertTo-Json -Depth 6
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $parent = Split-Path -Parent $ReportPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $ReportPath -Value $json -Encoding UTF8
}

Write-Output $json
if ($failed) { exit 1 }
