# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-CurrentTaskRows {
    $snapshot = Get-WindowRuntimeSizingSnapshot
    if ($null -eq $snapshot) { return 10 }
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $contentHeight = [Math]::Max(0, ([int]$snapshot.Height - [int]$snapshot.PaddingHeight - (Get-TaskRowsWindowSlack)))
    return [int][Math]::Max(1, [Math]::Round($contentHeight / [double]$rowHeight))
}

function Get-TaskRowsWindowSlack { return 8 }


function Get-TaskRowsWindowHeight([int]$Rows) {
    if ($Rows -lt 1) {
        $Rows = 1
    }
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $snapshot = Get-WindowRuntimeSizingSnapshot
    $paddingHeight = if ($null -ne $snapshot) { [int]$snapshot.PaddingHeight } else { 0 }
    return [int]($paddingHeight + ($Rows * $rowHeight) + (Get-TaskRowsWindowSlack))
}

function Ensure-TaskRowsVisible([int]$Rows) {
    $height = Get-TaskRowsWindowHeight $Rows
    Ensure-WindowRuntimeHeight $height
}

function Get-CollapsedTaskRows {
    return 2
}

function Update-SizeToggleButton {
    if ($null -eq $script:SizeToggleButton) {
        return
    }
    if ((Get-CurrentTaskRows) -le (Get-CollapsedTaskRows)) {
        $script:SizeToggleButton.Text = [string][char]0x25A1
    }
    else {
        $script:SizeToggleButton.Text = "-"
    }
}

function Toggle-TaskRowsSize {
    if ((Get-CurrentTaskRows) -le (Get-CollapsedTaskRows)) {
        Resize-WindowForTaskRows 10
    }
    else {
        Resize-WindowForTaskRows (Get-CollapsedTaskRows)
    }
}

function Resize-WindowForTaskRows([int]$Rows) {
    if ($null -eq (Get-WindowRuntimeSizingSnapshot)) { return }
    if ($Rows -lt 1) {
        $Rows = 1
    }
    Set-BottomChromeVisible $false
    $script:BottomChromeSuppressed = $true

    $height = Get-TaskRowsWindowHeight $Rows
    Set-WindowRuntimeHeight $height
    Update-SizeToggleButton
}

function Test-TaskTopDragBand([int]$Y) {
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    return ($Y -ge 0 -and $Y -le [Math]::Max(6, [int][Math]::Ceiling($rowHeight / 3.0)))
}
