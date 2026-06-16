# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-CurrentTaskRows {
    if ($null -eq $script:Form) {
        return 10
    }
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $paddingHeight = [int]$script:Form.Padding.Vertical
    if ($null -ne $script:ContentPanel) {
        $paddingHeight += [int]$script:ContentPanel.Padding.Vertical
    }
    $contentHeight = [Math]::Max(0, ([int]$script:Form.Height - $paddingHeight - (Get-TaskRowsWindowSlack)))
    return [int][Math]::Max(1, [Math]::Round($contentHeight / [double]$rowHeight))
}

function Get-TaskRowsWindowSlack {
    return 8
}

function Get-TaskRowsWindowHeight([int]$Rows) {
    if ($Rows -lt 1) {
        $Rows = 1
    }
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $paddingHeight = [int]$script:Form.Padding.Vertical
    if ($null -ne $script:ContentPanel) {
        $paddingHeight += [int]$script:ContentPanel.Padding.Vertical
    }
    return [int]($paddingHeight + ($Rows * $rowHeight) + (Get-TaskRowsWindowSlack))
}

function Ensure-TaskRowsVisible([int]$Rows) {
    if ($null -eq $script:Form) {
        return
    }
    $height = Get-TaskRowsWindowHeight $Rows
    $minWidth = 240
    if ($null -ne $script:Form.MinimumSize -and [int]$script:Form.MinimumSize.Width -gt 0) {
        $minWidth = [int]$script:Form.MinimumSize.Width
    }
    $script:Form.MinimumSize = New-Object System.Drawing.Size($minWidth, $height)
    if ([int]$script:Form.Height -lt $height) {
        $script:Form.Height = $height
    }
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
    if ($null -eq $script:Form) {
        return
    }
    if ($Rows -lt 1) {
        $Rows = 1
    }
    Set-BottomChromeVisible $false
    $script:BottomChromeSuppressed = $true

    $height = Get-TaskRowsWindowHeight $Rows
    if ($height -lt $script:Form.MinimumSize.Height) {
        $height = $script:Form.MinimumSize.Height
    }
    $script:Form.Height = $height
    Update-SizeToggleButton
}

function Test-TaskTopDragBand([int]$Y) {
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    return ($Y -ge 0 -and $Y -le [Math]::Max(6, [int][Math]::Ceiling($rowHeight / 3.0)))
}
