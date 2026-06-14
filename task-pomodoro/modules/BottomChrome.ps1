# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Set-BottomChromeVisible([bool]$Visible) {
    if ($script:BottomChromeVisible -eq $Visible) {
        return
    }
    $script:BottomChromeVisible = $Visible

    if ($Visible) {
        $script:NavRowStyle.Height = 30
        if ($null -ne $script:TaskInputRowStyle) {
            $script:TaskInputRowStyle.Height = 32
        }
    }
    else {
        $script:NavRowStyle.Height = 0
        if ($null -ne $script:TaskInputRowStyle) {
            $script:TaskInputRowStyle.Height = 0
        }
    }
    if ($null -ne $script:MainPanel) {
        $script:MainPanel.PerformLayout()
    }
    if ($null -ne $script:ContentPanel) {
        $script:ContentPanel.PerformLayout()
    }
}

function Update-BottomChromeVisibility {
    if ($null -eq $script:Form -or $null -eq $script:NavRowStyle) {
        return
    }
    Update-WatermarkToggleButton
    if ($script:WatermarkMode) {
        Set-BottomChromeVisible $false
        return
    }

    $bounds = $script:Form.RectangleToScreen($script:Form.ClientRectangle)
    $cursor = [System.Windows.Forms.Cursor]::Position
    $inside = $bounds.Contains($cursor)
    $rowHeight = 24
    if ($null -ne $script:TaskRowHeight -and [int]$script:TaskRowHeight -gt 0) {
        $rowHeight = [int]$script:TaskRowHeight
    }
    $revealPixels = [Math]::Max(8, [int][Math]::Ceiling($rowHeight / 3.0))
    $keepPixels = [Math]::Max(54, ($rowHeight + 36))
    if ($script:BottomChromeSuppressed) {
        if (-not $inside -or $cursor.Y -lt ($bounds.Bottom - $keepPixels)) {
            $script:BottomChromeSuppressed = $false
        }
        else {
            Set-BottomChromeVisible $false
            return
        }
    }

    $bottomPixels = $revealPixels
    if ($script:BottomChromeVisible) {
        $bottomPixels = $keepPixels
    }
    $nearBottom = ($inside -and $cursor.Y -ge ($bounds.Bottom - $bottomPixels))
    $inputFocused = ($null -ne $script:TaskInputBox -and $script:TaskInputBox.Focused)
    $shouldShow = ($nearBottom -or $inputFocused)

    Set-BottomChromeVisible $shouldShow
}

function Add-BottomChromeTracking([System.Windows.Forms.Control]$Control) {
    $Control.Add_MouseMove({
        Update-WatermarkToggleButton
        Update-BottomChromeVisibility
    })
    $Control.Add_MouseEnter({
        Update-WatermarkToggleButton
        Update-BottomChromeVisibility
    })
}
