# This file is dot-sourced by TaskPomodoro.ps1. Keep notifications synchronous, in-process, and side-effect-light.

function Initialize-AppNotificationHub {
    if ($null -eq $script:AppNotificationHandlers) {
        $script:AppNotificationHandlers = @{}
    }
    if ($null -eq $script:NotificationLastError) {
        $script:NotificationLastError = ""
    }
}

function Register-AppNotificationHandler([string]$Type, [scriptblock]$Handler) {
    if ([string]::IsNullOrWhiteSpace($Type) -or $null -eq $Handler) { return }
    Initialize-AppNotificationHub
    $existing = @()
    if ($script:AppNotificationHandlers.ContainsKey($Type)) { $existing = @($script:AppNotificationHandlers[$Type]) }
    $script:AppNotificationHandlers[$Type] = @($existing + $Handler)
}

function Clear-AppNotificationHandlers([string]$Type = "") {
    Initialize-AppNotificationHub
    if ([string]::IsNullOrWhiteSpace($Type)) { $script:AppNotificationHandlers.Clear(); return }
    if ($script:AppNotificationHandlers.ContainsKey($Type)) { $script:AppNotificationHandlers.Remove($Type) }
}

function Publish-AppNotification([string]$Type, [hashtable]$Data = @{}) {
    if ([string]::IsNullOrWhiteSpace($Type)) { return $null }
    Initialize-AppNotificationHub
    $notification = [pscustomobject]@{ Type = $Type; Data = $Data; At = Get-Date }
    if (-not $script:AppNotificationHandlers.ContainsKey($Type)) { return $notification }
    foreach ($handler in @($script:AppNotificationHandlers[$Type])) {
        try { & $handler $notification }
        catch { $script:NotificationLastError = [string]$_.Exception.Message }
    }
    return $notification
}