# This file is dot-sourced by TaskPomodoro.ps1. It promotes inbox intent into task workflows.

function Invoke-InboxCreateWorkflow([string]$Title) { return Add-InboxItem $Title }
function Invoke-InboxDeleteWorkflow([string]$InboxId) { return Remove-InboxItem $InboxId }
function Invoke-InboxEditWorkflow([string]$InboxId, [string]$Title) { return Set-InboxItemTitle $InboxId $Title }

function Invoke-InboxPromoteWorkflow([string]$InboxId, [bool]$ScheduleToday) {
    $item = Get-InboxItemById $InboxId
    if ($null -eq $item) { return New-TaskOperationResult $false "" "" $false $null }
    $taskResult = Invoke-TaskCreateWorkflow ([string]$item.title) $ScheduleToday
    if (-not [bool]$taskResult.Ok) { return $taskResult }
    $task = $taskResult.Data
    $script:InboxItems = @($script:InboxItems | Where-Object { [string]$_.id -ne [string]$InboxId })
    Save-Inbox
    Add-BehaviorResultEvent $taskResult "inbox_item_promoted" ([string]$task.id) "" "user" @{ InboxId = [string]$item.id; Title = [string]$item.title; ScheduledToday = [bool]$ScheduleToday } | Out-Null
    $taskResult.StatusKey = if ($ScheduleToday) { "InboxItemScheduled" } else { "InboxItemPromoted" }
    if (-not ($taskResult.PSObject.Properties.Name -contains "View")) { Add-Member -InputObject $taskResult -MemberType NoteProperty -Name "View" -Value "" }
    $taskResult.View = if ($ScheduleToday) { "today" } else { "tasks" }
    return $taskResult
}