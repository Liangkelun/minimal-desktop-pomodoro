# This file is dot-sourced by TaskPomodoro.ps1. Keep task workflows UI-free and side-effect-light at load time.

function Invoke-TaskCreateWorkflow([string]$Title, [bool]$ScheduleToday) { return Add-Task $Title $ScheduleToday }

function Invoke-TaskCompleteWorkflow([string]$TaskId) { return Complete-Task $TaskId }

function Invoke-TaskUncompleteWorkflow([string]$TaskId) { return Uncomplete-Task $TaskId }

function Invoke-TaskToggleCompletionWorkflow([string]$TaskId) { return Toggle-TaskCompletion $TaskId }

function Invoke-TaskEndWorkflow([string]$TaskId) { return End-Task $TaskId }

function Invoke-TaskDeleteWorkflow([string]$TaskId) { return Delete-Task $TaskId }

function Invoke-TaskRenameWorkflow([string]$TaskId, [string]$Title) { return Set-TaskTitle $TaskId $Title }

function Invoke-TaskScheduleTodayWorkflow([string]$TaskId) { return Schedule-TaskToday $TaskId }

function Invoke-TaskUnscheduleTodayWorkflow([string]$TaskId) { return Unschedule-TaskToday $TaskId }

function Invoke-TaskPinWorkflow([string]$Mode, [string]$TaskId) { return Pin-TaskToTop $Mode $TaskId }

function Invoke-TaskMoveWorkflow([string]$Mode, [string]$SourceId, [int]$TargetIndex) { return Move-TaskInView $Mode $SourceId $TargetIndex }

function Invoke-TaskDefaultWorkflow([string]$Mode, [string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        return New-TaskOperationResult $false "" "" $false $null
    }
    if ($Mode -eq "today") {
        return New-TaskOperationResult $false "" "" $false $null
    }
    return Schedule-TaskToday $TaskId
}