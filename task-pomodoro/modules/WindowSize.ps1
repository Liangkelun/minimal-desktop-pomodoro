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

function Update-SizeToggleButton {
    if ($null -eq $script:SizeToggleButton) {
        return
    }
    if ((Get-CurrentTaskRows) -le 1) {
        $script:SizeToggleButton.Text = [string][char]0x25A1
    }
    else {
        $script:SizeToggleButton.Text = "-"
    }
}

function Toggle-TaskRowsSize {
    if ((Get-CurrentTaskRows) -le 1) {
        Resize-WindowForTaskRows 10
    }
    else {
        Resize-WindowForTaskRows 1
    }
}

function Resize-WindowForTaskRows([int]$Rows) {
    if ($null -eq $script:Form) {
        return
    }
    if ($Rows -lt 1) {
        $Rows = 1
    }
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    Set-BottomChromeVisible $false
    $script:BottomChromeSuppressed = $true

    $paddingHeight = [int]$script:Form.Padding.Vertical
    if ($null -ne $script:ContentPanel) {
        $paddingHeight += [int]$script:ContentPanel.Padding.Vertical
    }
    $height = $paddingHeight + ($Rows * $rowHeight) + (Get-TaskRowsWindowSlack)
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
