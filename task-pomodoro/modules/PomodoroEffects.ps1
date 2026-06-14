# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Trigger-Reminder {
    if ([bool]$script:Settings.EndSoundReminder) {
        Play-EndSound
    }
    if ([bool]$script:Settings.ColorReminder -and $null -ne $script:Form) {
        $oldFormColor = $script:Form.BackColor
        $oldMainColor = $null
        $oldNavColor = $null
        $oldContentColor = $null
        $oldStatusColor = $null
        if ($null -ne $script:MainPanel) { $oldMainColor = $script:MainPanel.BackColor }
        if ($null -ne $script:NavPanel) { $oldNavColor = $script:NavPanel.BackColor }
        if ($null -ne $script:ContentPanel) { $oldContentColor = $script:ContentPanel.BackColor }
        if ($null -ne $script:StatusLabel) { $oldStatusColor = $script:StatusLabel.BackColor }
        $flashColor = [System.Drawing.Color]::LightGoldenrodYellow
        $script:Form.BackColor = [System.Drawing.Color]::LightGoldenrodYellow
        if ($null -ne $script:MainPanel) { $script:MainPanel.BackColor = $flashColor }
        if ($null -ne $script:NavPanel) { $script:NavPanel.BackColor = $flashColor }
        if ($null -ne $script:ContentPanel) { $script:ContentPanel.BackColor = $flashColor }
        if ($null -ne $script:StatusLabel) { $script:StatusLabel.BackColor = $flashColor }
        $flash = New-Object System.Windows.Forms.Timer
        $flash.Interval = 1500
        $flash.Add_Tick({
            $script:Form.BackColor = $oldFormColor
            if ($null -ne $script:MainPanel) { $script:MainPanel.BackColor = $oldMainColor }
            if ($null -ne $script:NavPanel) { $script:NavPanel.BackColor = $oldNavColor }
            if ($null -ne $script:ContentPanel) { $script:ContentPanel.BackColor = $oldContentColor }
            if ($null -ne $script:StatusLabel) { $script:StatusLabel.BackColor = $oldStatusColor }
            $flash.Stop()
            $flash.Dispose()
        })
        $flash.Start()
    }
    if ([bool]$script:Settings.TaskbarReminder -and $null -ne $script:Form) {
        $script:Form.Activate()
    }
}
