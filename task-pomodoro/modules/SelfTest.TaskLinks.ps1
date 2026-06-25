# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Invoke-SelfTestTaskLinkScenarios([string]$TaskId) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) { throw "selftest failed: missing task link scenario task id" }
        if (-not (Set-TaskDetails $TaskId "__selftest_details__" "__selftest_notes__" 3 5 @("https://example.com", "C:\temp\example.txt"))) {
            throw "selftest failed: set task details"
        }
        $convertedSingleLink = ConvertTo-TaskLinks "D:\single.docx"
        $convertedManyLinks = ConvertTo-TaskLinks "D:\one.docx`r`nD:\two.docx"
        if (-not ($convertedSingleLink -is [string[]]) -or $convertedSingleLink.Count -ne 1 -or $convertedSingleLink[0] -ne "D:\single.docx") {
            throw "selftest failed: single link conversion returns stable array"
        }
        if (-not ($convertedManyLinks -is [string[]]) -or $convertedManyLinks.Count -ne 2 -or $convertedManyLinks[1] -ne "D:\two.docx") {
            throw "selftest failed: multiline link conversion returns stable array"
        }
        $detailsTask = Get-TaskById $TaskId
        if (
            $detailsTask.title -ne "__selftest_details__" -or
            $detailsTask.notes -ne "__selftest_notes__" -or
            [int]$detailsTask.estimatedPomodoroCount -ne 3 -or
            [int]$detailsTask.pomodoroCount -ne 5 -or
            (Get-FirstTaskLink $detailsTask) -ne "https://example.com"
        ) {
            throw "selftest failed: task details persisted"
        }
        $linksText = Get-TaskLinksText $detailsTask
        if ($linksText -ne "https://example.com`r`nC:\temp\example.txt") {
            throw "selftest failed: task links multiline text"
        }
        $hadLinkDebugEnv = Test-Path Env:\TASK_POMODORO_LINK_DEBUG
        $originalLinkDebugEnv = [string]$env:TASK_POMODORO_LINK_DEBUG
        $originalDataDir = $script:DataDir
        $linkDebugDir = Join-Path $script:DataDir "__selftest_link_debug__"
        try {
            Remove-Item -LiteralPath $linkDebugDir -Recurse -Force -ErrorAction SilentlyContinue
            $script:DataDir = $linkDebugDir
            Remove-Item Env:\TASK_POMODORO_LINK_DEBUG -ErrorAction SilentlyContinue
            Write-TaskLinkDebug "SelfTestDefault" $TaskId "https://example.com/private" $detailsTask
            if (Test-Path -LiteralPath (Join-Path $linkDebugDir "open-link-debug.log")) { throw "selftest failed: task link debug writes by default" }
            $env:TASK_POMODORO_LINK_DEBUG = "1"
            Write-TaskLinkDebug "SelfTestEnabled" $TaskId "https://example.com/private" $detailsTask
            if (-not (Test-Path -LiteralPath (Join-Path $linkDebugDir "open-link-debug.log"))) { throw "selftest failed: task link debug opt-in" }
        }
        finally {
            $script:DataDir = $originalDataDir
            if ($hadLinkDebugEnv) { $env:TASK_POMODORO_LINK_DEBUG = $originalLinkDebugEnv } else { Remove-Item Env:\TASK_POMODORO_LINK_DEBUG -ErrorAction SilentlyContinue }
            Remove-Item -LiteralPath $linkDebugDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (-not (Set-TaskDetails $TaskId "__selftest_details__" "__selftest_notes__" 3 5 "D:\example.docx")) {
            throw "selftest failed: set single task link"
        }
        $singleLinkTask = Get-TaskById $TaskId
        if (@($singleLinkTask.links).Count -ne 1 -or (Get-FirstTaskLink $singleLinkTask) -ne "D:\example.docx" -or (Get-TaskLinksText $singleLinkTask) -ne "D:\example.docx") {
            throw "selftest failed: single task link stays whole"
        }
        $legacyLinkTask = [pscustomobject]@{ links = "D:\legacy.docx" }
        Ensure-TaskDefaults $legacyLinkTask
        if (-not ($legacyLinkTask.links -is [array]) -or @($legacyLinkTask.links).Count -ne 1 -or (Get-FirstTaskLink $legacyLinkTask) -ne "D:\legacy.docx") {
            throw "selftest failed: legacy string task link normalized"
        }

        $linkTestFile = Join-Path $script:DataDir "selftest link file.txt"
        "selftest" | Set-Content -LiteralPath $linkTestFile -Encoding UTF8
        try {
            $resolvedPath = Resolve-TaskLinkTarget $linkTestFile
            $resolvedFileUri = Resolve-TaskLinkTarget ([System.Uri]::new($linkTestFile).AbsoluteUri)
            $resolvedMarkdown = Resolve-TaskLinkTarget ("[local](" + $linkTestFile + ")")
            if (-not $resolvedPath.Exists -or -not $resolvedFileUri.Exists -or -not $resolvedMarkdown.Exists) {
                throw "selftest failed: resolve local task link"
            }
        }
        finally {
            Remove-Item -LiteralPath $linkTestFile -Force -ErrorAction SilentlyContinue
        }
        $longLinkRoot = Join-Path $script:DataDir "__selftest__\has spaces\long local path for task link resolution\01_current_main"
        Ensure-Directory $longLinkRoot
        $longLinkFile = Join-Path $longLinkRoot "Foresight_Main_Manuscript_Chinese_Review_20260604.docx"
        "selftest" | Set-Content -LiteralPath $longLinkFile -Encoding UTF8
        try {
            $mixedLinks = ConvertTo-TaskLinks ("`"$longLinkFile`"`r`n`r`n<https://example.com/work>`r`n[local]($longLinkFile)")
            if ($mixedLinks.Count -ne 3 -or $mixedLinks[0] -ne $longLinkFile -or $mixedLinks[1] -ne "https://example.com/work" -or $mixedLinks[2] -ne $longLinkFile) {
                throw "selftest failed: mixed long task links"
            }
            foreach ($candidate in @($longLinkFile, ('"' + $longLinkFile + '"'), ('<' + $longLinkFile + '>'), ("[local](" + $longLinkFile + ")"), ([System.Uri]::new($longLinkFile).AbsoluteUri))) {
                $resolvedLongPath = Resolve-TaskLinkTarget $candidate
                if (-not $resolvedLongPath.Exists -or [string]$resolvedLongPath.OpenTarget -ne $longLinkFile) {
                    throw "selftest failed: resolve long local task link"
                }
            }
            $resolvedObject = Resolve-TaskLinkTarget ([pscustomobject]@{ OpenTarget = $longLinkFile; Exists = $true; IsPath = $true })
            $resolvedObjectText = Resolve-TaskLinkTarget ("@{OpenTarget=$longLinkFile; Exists=True; IsPath=True}")
            if ([string]$resolvedObject.OpenTarget -ne $longLinkFile -or [string]$resolvedObjectText.OpenTarget -ne $longLinkFile) {
                throw "selftest failed: resolve parsed task link target"
            }
        }
        finally {
            Remove-Item -LiteralPath (Join-Path $script:DataDir "__selftest__") -Recurse -Force -ErrorAction SilentlyContinue
        }
        $originalOpenTaskLink = (Get-Command Open-TaskLink).ScriptBlock
        $script:SelfTestOpenTaskLinkId = ""
        $menu = New-Object System.Windows.Forms.ContextMenuStrip
        try {
            $submenu = Add-SubMenu $menu "selftest-more"
            Add-MenuItem $menu "selftest-root" "root-task-id" { param($sender, $eventArgs) $script:SelfTestOpenTaskLinkId = [string]$sender.Tag }
            Add-MenuItem $submenu "selftest-child" "child-task-id" { param($sender, $eventArgs) $script:SelfTestOpenTaskLinkId = [string]$sender.Tag }
            if ($menu.Items.Count -lt 2 -or $menu.Items[0].Text -ne "selftest-more" -or $menu.Items[1].Tag -ne "root-task-id") {
                throw "selftest failed: add root menu item attachment"
            }
            if ($submenu.DropDownItems.Count -ne 1 -or $submenu.DropDownItems[0].Tag -ne "child-task-id") {
                throw "selftest failed: add submenu item attachment"
            }
            $menu.Items[1].PerformClick()
            if ($script:SelfTestOpenTaskLinkId -ne "root-task-id") {
                throw "selftest failed: root menu click tag"
            }
            $submenu.DropDownItems[0].PerformClick()
            if ($script:SelfTestOpenTaskLinkId -ne "child-task-id") {
                throw "selftest failed: submenu click tag"
            }
            Set-Item -Path Function:\Open-TaskLink -Value { param([string]$Id) $script:SelfTestOpenTaskLinkId = $Id }
            Add-OpenTaskLinkMenuItem $submenu "menu-task-id"
            $submenu.DropDownItems[1].PerformClick()
            if ($script:SelfTestOpenTaskLinkId -ne "menu-task-id") {
                throw "selftest failed: open task link submenu click"
            }
        }
        finally {
            Set-Item -Path Function:\Open-TaskLink -Value $originalOpenTaskLink
            $menu.Dispose()
            Remove-Variable -Name SelfTestOpenTaskLinkId -Scope Script -ErrorAction SilentlyContinue
        }
}
