# This file is dot-sourced by TaskPomodoro.ps1. Keep translation workflow free of overlay rendering and selection listeners.

function Reset-TranslationWorkflowState {
    $script:TranslationWorkflowLastSignature = ""
    $script:TranslationWorkflowLastShownSignature = ""
    $script:TranslationWorkflowLastSource = ""
    $script:TranslationWorkflowLastAt = $null
}

function Test-TranslationWorkflowRecentRequest([string]$Signature, [datetime]$Now) {
    return ($Signature -eq [string]$script:TranslationWorkflowLastSignature -and $null -ne $script:TranslationWorkflowLastAt -and (($Now - $script:TranslationWorkflowLastAt).TotalMilliseconds -lt 250))
}

function Test-TranslationWorkflowAlreadyShown([string]$Signature) {
    return ($Signature -eq [string]$script:TranslationWorkflowLastShownSignature)
}

function Set-TranslationWorkflowLastRequest([string]$Signature, [datetime]$At) {
    $script:TranslationWorkflowLastSignature = $Signature
    $script:TranslationWorkflowLastAt = $At
}

function Set-TranslationWorkflowLastShown([string]$Signature, [string]$Source) {
    $script:TranslationWorkflowLastShownSignature = $Signature
    $script:TranslationWorkflowLastSource = $Source
}

function Clear-TranslationWorkflowShownState([string]$Source) {
    if (-not [string]::IsNullOrWhiteSpace($Source) -and [string]$script:TranslationWorkflowLastSource -ne $Source) { return $false }
    $script:TranslationWorkflowLastShownSignature = ""
    $script:TranslationWorkflowLastSource = ""
    return $true
}

function Get-TranslationWorkflowNotificationType([object]$Result) {
    if ($null -eq $Result) { return "TranslationFailed" }
    if (($Result.PSObject.Properties.Name -contains "IsHint") -and [bool]$Result.IsHint) { return "TranslationFailed" }
    return "TranslationCompleted"
}

function Invoke-TranslationWorkflowRequest([string]$Text, [System.Drawing.Rectangle]$Rect, [string]$Source) {
    $kind = Get-TranslationSelectionKind $Text
    if ([string]::IsNullOrWhiteSpace($kind)) {
        return Publish-AppNotification "TranslationFailed" @{ Source = $Source; Reason = "InvalidSelection"; Rect = $Rect }
    }
    $clean = [regex]::Replace(([string]$Text).Trim(), "\s+", " ")
    $signature = "$Source|$kind|$clean|$($Rect.Left),$($Rect.Top),$($Rect.Width),$($Rect.Height)"
    $now = Get-Date
    if (Test-TranslationWorkflowRecentRequest $signature $now) { return $null }
    if (Test-TranslationWorkflowAlreadyShown $signature) { return $null }
    Set-TranslationWorkflowLastRequest $signature $now
    $result = Get-TranslationResult $clean $kind
    Set-TranslationWorkflowLastShown $signature $Source
    $eventType = Get-TranslationWorkflowNotificationType $result
    return Publish-AppNotification $eventType @{ Text = $clean; Kind = $kind; Source = $Source; Rect = $Rect; Result = $result; Signature = $signature }
}