# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Render-MoreView {
    $script:ContentPanel.Controls.Clear()

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $panel.WrapContents = $false
    $panel.Padding = New-Object System.Windows.Forms.Padding(2)
    Add-BottomChromeTracking $panel

    $done = New-Button (T "ExecutionRecords") 260
    $done.Add_Click({ Set-ActiveView "done" })
    Add-BottomChromeTracking $done
    $panel.Controls.Add($done)

    $check = New-Button (T "DataCheck") 260
    $check.Add_Click({ Invoke-DataCheck })
    Add-BottomChromeTracking $check
    $panel.Controls.Add($check)

    $script:ContentPanel.Controls.Add($panel)
}

