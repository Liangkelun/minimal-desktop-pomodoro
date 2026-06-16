# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Set-Status([string]$Message) {
    $script:StatusMessage = $Message
    Update-DateLabel
}

function Invoke-AppActionResult([object]$Result) {
    if ($null -eq $Result) {
        return
    }
    if (($Result.PSObject.Properties.Name -contains "MessageKey") -and -not [string]::IsNullOrWhiteSpace([string]$Result.MessageKey)) {
        [System.Windows.Forms.MessageBox]::Show((T ([string]$Result.MessageKey)), (T "AppTitle")) | Out-Null
    }
    if (($Result.PSObject.Properties.Name -contains "StatusKey") -and -not [string]::IsNullOrWhiteSpace([string]$Result.StatusKey)) {
        Set-Status (T ([string]$Result.StatusKey))
    }
    if (($Result.PSObject.Properties.Name -contains "View") -and -not [string]::IsNullOrWhiteSpace([string]$Result.View)) {
        Set-ActiveView ([string]$Result.View)
    }
    elseif (($Result.PSObject.Properties.Name -contains "ShouldRender") -and [bool]$Result.ShouldRender) {
        Render-CurrentView
    }
    if (($Result.PSObject.Properties.Name -contains "ShouldUpdateTimer") -and [bool]$Result.ShouldUpdateTimer) {
        Update-TimerLabels
    }
}

function Invoke-TaskOperationResult([object]$Result) {
    Invoke-AppActionResult $Result
}

function New-Button([string]$Text, [int]$Width) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Width = $Width
    $button.Height = 26
    $button.Margin = New-Object System.Windows.Forms.Padding(1, 2, 1, 2)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(235, 239, 245)
    $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(220, 228, 238)
    $button.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $button.UseVisualStyleBackColor = $false
    return $button
}

function Update-NavText {
    if ($null -eq $script:NavButtons) {
        return
    }
    if ($script:NavButtons.ContainsKey("tasks")) {
        $script:NavButtons["tasks"].Text = T "TaskList"
    }
    if ($script:NavButtons.ContainsKey("today")) {
        $script:NavButtons["today"].Text = T "TodayList"
    }
    if ($script:NavButtons.ContainsKey("timer")) {
        $script:NavButtons["timer"].Text = T "Pomodoro"
    }
    if ($script:NavButtons.ContainsKey("more")) {
        $script:NavButtons["more"].Text = T "More"
    }
    if ($null -ne $script:CloseButton) {
        $script:CloseButton.Text = T "Close"
    }
}

function Set-ActiveView([string]$View) {
    $script:ActiveView = $View
    foreach ($entry in $script:NavButtons.GetEnumerator()) {
        if ($entry.Key -eq $View) {
            $entry.Value.BackColor = [System.Drawing.Color]::FromArgb(226, 234, 244)
        }
        else {
            $entry.Value.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
        }
    }
    Render-CurrentView
}

function Render-CurrentView {
    if ($null -eq $script:ContentPanel) {
        return
    }
    $script:TaskInputRowStyle = $null
    $script:TaskInputBox = $null
    $script:StartButton = $null
    $script:PauseButton = $null
    $script:TaskListBox = $null

    switch ($script:ActiveView) {
        "tasks" { Render-TaskView "tasks" }
        "today" { Render-TaskView "today" }
        "timer" { Render-TimerView }
        "more" { Render-MoreView }
        "done" { Render-DoneView }
        "settings" { Ensure-TaskRowsVisible 11; Render-SettingsView }
        default { Render-TaskView "today" }
    }
    Update-BottomChromeVisibility
}

