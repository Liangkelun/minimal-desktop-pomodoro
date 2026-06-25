# This file is dot-sourced by TaskPomodoro.ps1. It bridges translation selection/workflow notifications to overlay surfaces.

function Clear-TranslationNotificationHandlers {
    Clear-AppNotificationHandlers "TranslationCompleted"
    Clear-AppNotificationHandlers "TranslationFailed"
}

function Register-TranslationNotificationHandlers {
    Clear-TranslationNotificationHandlers
    Register-AppNotificationHandler "TranslationCompleted" {
        param($notification)
        if ($null -ne $notification.Data["Result"]) { Show-TranslationSurfaceResult $notification.Data["Result"] $notification.Data["Rect"] }
    }
    Register-AppNotificationHandler "TranslationFailed" {
        param($notification)
        if ($null -ne $notification.Data["Result"]) { Show-TranslationSurfaceResult $notification.Data["Result"] $notification.Data["Rect"]; return }
        if ([string]$notification.Data["Source"] -eq "uia") { Hide-TranslationSurfaces; Clear-TranslationWorkflowShownState "" | Out-Null }
    }
}

function Show-TranslationText([string]$Text, [System.Drawing.Rectangle]$Rect, [string]$Source) {
    Invoke-TranslationWorkflowRequest $Text $Rect $Source | Out-Null
}

function Update-TranslationSelectionBridge {
    $selection = Get-TranslationSelection
    if ($null -eq $selection) {
        if (Clear-TranslationWorkflowShownState "uia") { Hide-TranslationSurfaces }
        return
    }
    Show-TranslationText ([string]$selection.Text) $selection.Rect "uia"
}