# This file is dot-sourced by TaskPomodoro.ps1. It owns the local append-only behavior event stream.

function Initialize-BehaviorEvents {
    $path = Get-AppPath "BehaviorEventsFile"
    if (-not (Test-Path -LiteralPath $path)) {
        Invoke-WithNamedMutex (Get-AppScopedMutexName "data") {
            if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType File -Path $path | Out-Null }
        }
    }
    if ($null -eq $script:BehaviorCurrentSessionId) { $script:BehaviorCurrentSessionId = "" }
    if ($null -eq $script:BehaviorCurrentSessionTaskId) { $script:BehaviorCurrentSessionTaskId = "" }
}

function New-BehaviorEventId { return "evt-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 6) }
function New-BehaviorSessionId { return "sess-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 6) }

function Start-BehaviorSessionForTask([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) { return "" }
    if ([string]$script:BehaviorCurrentSessionTaskId -eq [string]$TaskId -and -not [string]::IsNullOrWhiteSpace([string]$script:BehaviorCurrentSessionId)) { return [string]$script:BehaviorCurrentSessionId }
    $script:BehaviorCurrentSessionId = New-BehaviorSessionId
    $script:BehaviorCurrentSessionTaskId = [string]$TaskId
    return [string]$script:BehaviorCurrentSessionId
}

function Get-BehaviorSessionForTask([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) { return "" }
    if ([string]$script:BehaviorCurrentSessionTaskId -eq [string]$TaskId) { return [string]$script:BehaviorCurrentSessionId }
    return ""
}

function Stop-BehaviorSessionForTask([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]$script:BehaviorCurrentSessionTaskId -eq [string]$TaskId) {
        $script:BehaviorCurrentSessionId = ""
        $script:BehaviorCurrentSessionTaskId = ""
    }
}

function New-BehaviorResultEvent([string]$BehaviorType, [string]$TaskId = "", [string]$SessionId = "", [string]$Source = "user", [hashtable]$Payload = @{}) {
    if ($null -eq $Payload) { $Payload = @{} }
    return New-AppEvent "AppendBehaviorEvent" @{ BehaviorType = $BehaviorType; TaskId = $TaskId; SessionId = $SessionId; Source = $Source; Payload = $Payload }
}

function Add-BehaviorResultEvent([object]$Result, [string]$BehaviorType, [string]$TaskId = "", [string]$SessionId = "", [string]$Source = "user", [hashtable]$Payload = @{}) {
    if ($null -eq $Result -or -not [bool]$Result.Ok) { return $Result }
    Add-AppResultEvents $Result @((New-BehaviorResultEvent $BehaviorType $TaskId $SessionId $Source $Payload)) | Out-Null
    return $Result
}

function Append-BehaviorEvent([string]$BehaviorType, [string]$TaskId = "", [string]$SessionId = "", [string]$Source = "user", [object]$Payload = $null) {
    if ([string]::IsNullOrWhiteSpace($BehaviorType)) { return }
    Initialize-BehaviorEvents
    if ($null -eq $Payload) { $Payload = [pscustomobject]@{} }
    $record = [pscustomobject][ordered]@{
        id = New-BehaviorEventId
        at = Get-IsoNow
        type = [string]$BehaviorType
        taskId = [string]$TaskId
        sessionId = [string]$SessionId
        source = if ([string]::IsNullOrWhiteSpace($Source)) { "user" } else { [string]$Source }
        payload = $Payload
    }
    $line = ConvertTo-Json -InputObject $record -Depth 8 -Compress
    Invoke-WithNamedMutex (Get-AppScopedMutexName "data") { $line | Add-Content -LiteralPath (Get-AppPath "BehaviorEventsFile") -Encoding UTF8 }
}

function Get-BehaviorEvents {
    Initialize-BehaviorEvents
    $path = Get-AppPath "BehaviorEventsFile"
    $events = @()
    foreach ($line in @(Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $events += ($line | ConvertFrom-Json) } catch {}
    }
    return @($events)
}

function Get-BehaviorEventsForTask([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) { return @() }
    return @(Get-BehaviorEvents | Where-Object { [string]$_.taskId -eq [string]$TaskId } | Sort-Object at)
}