# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function ConvertTo-TaskLinkText([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $link = $Text.Trim()
    if ($link -match '^\[[^\]]*\]\((.+)\)$') {
        $link = [string]$Matches[1]
    }
    return $link.Trim().Trim('"').Trim("'").Trim('<').Trim('>')
}

function ConvertTo-TaskLinks([object]$Value) {
    $links = New-Object System.Collections.ArrayList
    if ($null -eq $Value) {
        return @()
    }

    foreach ($item in @($Value)) {
        $text = [string]$item
        foreach ($line in ($text -split "`r?`n")) {
            $link = ConvertTo-TaskLinkText $line
            if (-not [string]::IsNullOrWhiteSpace($link)) {
                $links.Add($link) | Out-Null
            }
        }
    }
    return ,([string[]]$links.ToArray())
}

function Resolve-TaskLinkTarget([object]$Target) {
    if ($null -ne $Target -and ($Target.PSObject.Properties.Name -contains "OpenTarget")) {
        return Resolve-TaskLinkTarget ([string]$Target.OpenTarget)
    }

    $target = ConvertTo-TaskLinkText ([string]$Target)
    if ($target -match '^@\{OpenTarget=(.*); Exists=(True|False); IsPath=(True|False)\}$') {
        $target = ConvertTo-TaskLinkText ([string]$Matches[1])
    }
    if ([string]::IsNullOrWhiteSpace($target)) {
        return [pscustomobject]@{ OpenTarget = ""; Exists = $false; IsPath = $false }
    }

    $target = [Environment]::ExpandEnvironmentVariables($target)
    [System.Uri]$uri = $null
    if ([System.Uri]::TryCreate($target, [System.UriKind]::Absolute, [ref]$uri)) {
        if ($uri.IsFile) {
            $target = $uri.LocalPath
        }
        elseif (-not [string]::IsNullOrWhiteSpace($uri.Scheme)) {
            return [pscustomobject]@{ OpenTarget = $uri.AbsoluteUri; Exists = $true; IsPath = $false }
        }
    }

    $candidates = New-Object System.Collections.ArrayList
    $candidates.Add($target) | Out-Null
    if (-not [System.IO.Path]::IsPathRooted($target)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$script:RootDir)) {
            $candidates.Add((Join-Path $script:RootDir $target)) | Out-Null
        }
        $candidates.Add((Join-Path (Get-Location).Path $target)) | Out-Null
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return [pscustomobject]@{ OpenTarget = (Resolve-Path -LiteralPath $candidate).Path; Exists = $true; IsPath = $true }
        }
    }
    return [pscustomobject]@{ OpenTarget = $target; Exists = $false; IsPath = $true }
}

function Write-TaskLinkDebug([string]$Source, [string]$TaskId, [string]$Target, [object]$Task) {
    try {
        if ([string]$env:TASK_POMODORO_LINK_DEBUG -ne "1") { return }
        if ([string]::IsNullOrWhiteSpace([string]$script:DataDir)) {
            return
        }
        Ensure-Directory $script:DataDir
        if ($null -eq $Task -and -not [string]::IsNullOrWhiteSpace($TaskId)) {
            $Task = Get-TaskById $TaskId
        }
        $title = ""
        $linkCount = 0
        $rawLinks = ""
        if ($null -ne $Task) {
            $title = [string]$Task.title
            [string[]]$links = ConvertTo-TaskLinks $Task.links
            $linkCount = $links.Count
            $rawLinks = ($links -join " | ")
        }
        $line = "$(Get-IsoNow) source=$Source taskId=$TaskId title=$title linkCount=$linkCount target=$Target rawLinks=$rawLinks root=$script:RootDir tasksFile=$script:TasksFile"
        Add-Content -LiteralPath (Join-Path $script:DataDir "open-link-debug.log") -Value $line -Encoding UTF8
    }
    catch {
    }
}

function Get-TaskLinksText([object]$Task) {
    if ($null -eq $Task -or -not ($Task.PSObject.Properties.Name -contains "links")) {
        return ""
    }
    [string[]]$links = ConvertTo-TaskLinks $Task.links
    return ($links -join "`r`n")
}

function Get-FirstTaskLink([object]$Task) {
    [string[]]$links = ConvertTo-TaskLinks $Task.links
    if ($links.Count -gt 0) {
        return [string]$links[0]
    }
    return ""
}

function Set-TaskDetails([string]$Id, [string]$Title, [string]$Notes, [int]$EstimatedPomodoros, [int]$ActualPomodoros, [object]$Links) {
    $task = Get-TaskById $Id
    if ($null -eq $task) {
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($Title)) {
        return $false
    }
    if ($EstimatedPomodoros -lt 0) {
        $EstimatedPomodoros = 0
    }
    if ($ActualPomodoros -lt 0) {
        $ActualPomodoros = 0
    }

    $task.title = $Title.Trim()
    $task.notes = [string]$Notes
    $task.estimatedPomodoroCount = $EstimatedPomodoros
    $task.pomodoroCount = $ActualPomodoros
    $task.links = [string[]](ConvertTo-TaskLinks $Links)
    Save-Tasks
    return $true
}

