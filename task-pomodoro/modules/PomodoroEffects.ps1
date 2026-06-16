# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Stop-ColorReminderFlash([bool]$Restore) {
    if ($null -ne $script:ColorReminderFlashTimer) {
        $script:ColorReminderFlashTimer.Stop()
        $script:ColorReminderFlashTimer.Dispose()
        $script:ColorReminderFlashTimer = $null
    }
    if (-not $Restore -or $null -eq $script:ColorReminderFlashRestore) {
        $script:ColorReminderFlashRestore = $null
        return
    }

    $state = $script:ColorReminderFlashRestore
    if ($null -ne $script:Form) { $script:Form.BackColor = $state.Form }
    if ($null -ne $script:MainPanel -and $null -ne $state.Main) { $script:MainPanel.BackColor = $state.Main }
    if ($null -ne $script:NavPanel -and $null -ne $state.Nav) { $script:NavPanel.BackColor = $state.Nav }
    if ($null -ne $script:ContentPanel -and $null -ne $state.Content) { $script:ContentPanel.BackColor = $state.Content }
    if ($null -ne $script:StatusLabel -and $null -ne $state.Status) { $script:StatusLabel.BackColor = $state.Status }
    $script:ColorReminderFlashRestore = $null
}

function Trigger-Reminder {
    if ([bool]$script:Settings.EndSoundReminder) {
        Play-EndSound
    }
    if ([bool]$script:Settings.ColorReminder -and $null -ne $script:Form) {
        Stop-ColorReminderFlash $true
        $oldFormColor = $script:Form.BackColor
        $oldMainColor = $null
        $oldNavColor = $null
        $oldContentColor = $null
        $oldStatusColor = $null
        if ($null -ne $script:MainPanel) { $oldMainColor = $script:MainPanel.BackColor }
        if ($null -ne $script:NavPanel) { $oldNavColor = $script:NavPanel.BackColor }
        if ($null -ne $script:ContentPanel) { $oldContentColor = $script:ContentPanel.BackColor }
        if ($null -ne $script:StatusLabel) { $oldStatusColor = $script:StatusLabel.BackColor }
        $script:ColorReminderFlashRestore = [pscustomobject]@{
            Form = $oldFormColor
            Main = $oldMainColor
            Nav = $oldNavColor
            Content = $oldContentColor
            Status = $oldStatusColor
        }
        $flashColor = [System.Drawing.Color]::LightGoldenrodYellow
        $script:Form.BackColor = [System.Drawing.Color]::LightGoldenrodYellow
        if ($null -ne $script:MainPanel) { $script:MainPanel.BackColor = $flashColor }
        if ($null -ne $script:NavPanel) { $script:NavPanel.BackColor = $flashColor }
        if ($null -ne $script:ContentPanel) { $script:ContentPanel.BackColor = $flashColor }
        if ($null -ne $script:StatusLabel) { $script:StatusLabel.BackColor = $flashColor }
        $flash = New-Object System.Windows.Forms.Timer
        $flash.Interval = 1500
        $flash.Add_Tick({
            Stop-ColorReminderFlash $true
        })
        $script:ColorReminderFlashTimer = $flash
        $flash.Start()
    }
    if ([bool]$script:Settings.TaskbarReminder -and $null -ne $script:Form) {
        $script:Form.Activate()
    }
}
