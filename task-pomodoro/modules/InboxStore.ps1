# This file is dot-sourced by TaskPomodoro.ps1. It owns inbox item persistence only.

function New-InboxItemId { return "inbox-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 6) }

function New-InboxItem([string]$Title, [string]$Source = "manual") {
    return [pscustomobject][ordered]@{ id = New-InboxItemId; title = $Title.Trim(); source = $Source; createdAt = Get-IsoNow }
}

function Ensure-InboxItemDefaults([object]$Item) {
    Ensure-Property $Item "id" (New-InboxItemId)
    Ensure-Property $Item "title" ""
    Ensure-Property $Item "source" "manual"
    Ensure-Property $Item "createdAt" (Get-IsoNow)
}

function Load-Inbox {
    $path = Get-AppPath "InboxFile"
    if (-not (Test-Path -LiteralPath $path)) { $script:InboxItems = @(); Save-Inbox; return }
    try {
        $raw = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { $script:InboxItems = @(); return }
        $data = $raw | ConvertFrom-Json
        if ($null -eq $data) { $script:InboxItems = @() } elseif ($data -is [array]) { $script:InboxItems = @($data) } else { $script:InboxItems = @($data) }
        $migrated = $false
        foreach ($item in $script:InboxItems) {
            $before = $item | ConvertTo-Json -Depth 6 -Compress
            Ensure-InboxItemDefaults $item
            $after = $item | ConvertTo-Json -Depth 6 -Compress
            if ($before -ne $after) { $migrated = $true }
        }
        if ($migrated) { Save-Inbox }
    }
    catch {
        Backup-DataFile $path "invalid"
        $script:InboxItems = @()
        Save-Inbox
    }
}

function Save-Inbox { Write-JsonAtomic (Get-AppPath "InboxFile") @($script:InboxItems) }

function Get-InboxItems { return @($script:InboxItems | Sort-Object createdAt) }
function Get-InboxItemById([string]$Id) { foreach ($item in @($script:InboxItems)) { if ([string]$item.id -eq [string]$Id) { return $item } }; return $null }

function Add-InboxItem([string]$Title) {
    if ([string]::IsNullOrWhiteSpace($Title)) { return New-TaskOperationResult $false "" "EnterTaskFirst" $false $null }
    $item = New-InboxItem $Title
    $script:InboxItems = @($script:InboxItems) + $item
    Save-Inbox
    return Add-BehaviorResultEvent (New-TaskOperationResult $true "InboxItemAdded" "" $true $item) "inbox_item_added" "" "" "user" @{ InboxId = [string]$item.id; Title = [string]$item.title }
}

function Remove-InboxItem([string]$Id) {
    $item = Get-InboxItemById $Id
    if ($null -eq $item) { return New-TaskOperationResult $false "" "" $false $null }
    $script:InboxItems = @($script:InboxItems | Where-Object { [string]$_.id -ne [string]$Id })
    Save-Inbox
    return New-TaskOperationResult $true "InboxItemDeleted" "" $true $item
}

function Set-InboxItemTitle([string]$Id, [string]$Title) {
    if ([string]::IsNullOrWhiteSpace($Title)) { return New-TaskOperationResult $false "" "EnterTaskFirst" $false $null }
    $item = Get-InboxItemById $Id
    if ($null -eq $item) { return New-TaskOperationResult $false "" "" $false $null }
    $oldTitle = [string]$item.title
    $item.title = $Title.Trim()
    Save-Inbox
    $result = New-TaskOperationResult $true "InboxItemEdited" "" $true $item
    Add-BehaviorResultEvent $result "inbox_item_edited" "" "" "user" @{ InboxId = [string]$item.id; OldTitle = $oldTitle; Title = [string]$item.title } | Out-Null
    return $result
}