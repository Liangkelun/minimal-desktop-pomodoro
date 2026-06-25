# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Invoke-SelfTestUiScenarios {
    $testList = $null
    try {
        $script:TaskRowHeight = 24
        if (-not (Test-TaskTopDragBand 7) -or (Test-TaskTopDragBand 12)) {
            throw "selftest failed: top drag band"
        }

        $testList = New-Object System.Windows.Forms.ListBox
        $testList.Width = 220
        $testList.Height = 72
        $testList.Tag = [pscustomobject]@{ Mode = "tasks" }
        $testList.Items.Add([pscustomobject]@{ Id = "task-1"; Display = "1. task" }) | Out-Null
        $testList.Items.Add([pscustomobject]@{ Id = ""; Display = "empty" }) | Out-Null
        $selectedItem = Select-ListItemAtPoint $testList 4 4
        if ($null -eq $selectedItem -or $testList.SelectedIndex -ne 0) {
            throw "selftest failed: select real list item"
        }
        $testList.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.5)
        $blankDragY = [Math]::Min(14, ($testList.ItemHeight - 2))
        $blankTextSize = [System.Windows.Forms.TextRenderer]::MeasureText("1. task", $testList.Font, (New-Object System.Drawing.Size -ArgumentList @(10000, $testList.ItemHeight)), [System.Windows.Forms.TextFormatFlags]::NoPadding)
        $blankDragX = [Math]::Min(140, (4 + [int]$blankTextSize.Width + 16))
        if ((Test-TaskFirstRowBlankDragPoint $testList 8 4) -or (Test-TaskFirstRowBlankDragPoint $testList 30 $blankDragY) -or -not (Test-TaskFirstRowBlankDragPoint $testList $blankDragX $blankDragY)) {
            throw "selftest failed: first row blank drag point"
        }
        $nullItem = Select-ListItemAtPoint $testList 4 ($testList.ItemHeight + 4)
        if ($null -ne $nullItem -or $testList.SelectedIndex -ne -1) {
            throw "selftest failed: clear placeholder list item"
        }
        $testList.SelectedIndex = 0
        $blankItem = Select-ListItemAtPoint $testList 4 200
        if ($null -ne $blankItem -or $testList.SelectedIndex -ne -1) {
            throw "selftest failed: clear blank list area"
        }
        $testList.SelectedIndex = 0
        $script:TaskListBox = $testList
        Clear-TaskSelection
        if ($testList.SelectedIndex -ne -1) {
            throw "selftest failed: clear task selection"
        }
        $script:TaskListBox = $null
        $testList.Dispose()

        $script:Form = New-Object TaskPomodoroResizableForm
        $script:Form.Height = 100
        $script:Form.Location = New-Object System.Drawing.Point -ArgumentList @(-5000, -5000)
        $script:Form.Opacity = 0.88
        $script:Form.TopMost = $false
        $script:Form.Padding = New-Object System.Windows.Forms.Padding(4)
        $script:Form.MinimumSize = New-Object System.Drawing.Size(240, 34)
        $script:ContentPanel = New-Object System.Windows.Forms.Panel
        $script:ContentPanel.Padding = New-Object System.Windows.Forms.Padding(6, 2, 6, 0)
        $script:MainPanel = New-Object System.Windows.Forms.Panel
        $script:NavRowStyle = New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32)
        $script:TaskInputRowStyle = $null
        $script:TaskRowHeight = 24
        $script:BottomChromeVisible = $true
        $script:SizeToggleButton = New-Object System.Windows.Forms.Button
        $tasksBeforeDoneView = $script:Tasks
        try {
            $script:Tasks = @([pscustomobject]@{ id = "__selftest_done_view__"; title = "__selftest_done_title__"; status = "archived"; completedAt = "2000-01-02T00:00:00+08:00"; archivedAt = ""; createdAt = "2000-01-01T00:00:00+08:00"; pomodoroCount = 2 })
            Render-DoneView
            $doneList = @($script:ContentPanel.Controls[0].Controls | Where-Object { $_ -is [System.Windows.Forms.ListBox] } | Select-Object -First 1)[0]
            if ($null -eq $doneList -or $doneList.Items.Count -ne 2 -or [string]$doneList.Items[1].Id -ne "__selftest_done_view__" -or [string]$doneList.Items[1].Display -notlike "*__selftest_done_title__*") {
                throw "selftest failed: done view archived task"
            }
            $script:Tasks = @()
            Render-DoneView
            $emptyDoneList = @($script:ContentPanel.Controls[0].Controls | Where-Object { $_ -is [System.Windows.Forms.ListBox] } | Select-Object -First 1)[0]
            if ($null -eq $emptyDoneList -or $emptyDoneList.Items.Count -ne 1 -or -not [string]::IsNullOrWhiteSpace([string]$emptyDoneList.Items[0].Id)) {
                throw "selftest failed: done view empty state"
            }
        }
        finally {
            $script:Tasks = $tasksBeforeDoneView
            $script:ContentPanel.Controls.Clear()
        }
        Resize-WindowForTaskRows (Get-CollapsedTaskRows)
        $collapsedHeight = [int]$script:Form.Height
        if ($collapsedHeight -lt 62 -or $collapsedHeight -gt 72) {
            throw "selftest failed: resize collapsed rows"
        }
        $collapsedUsableHeight = $collapsedHeight - [int]$script:Form.Padding.Vertical - [int]$script:ContentPanel.Padding.Vertical - (Get-TaskRowsWindowSlack)
        if ($collapsedUsableHeight -lt ([int]$script:TaskRowHeight * 2)) {
            throw "selftest failed: collapsed view clips task rows"
        }
        if ($script:SizeToggleButton.Text -ne [string][char]0x25A1) {
            throw "selftest failed: size toggle collapsed icon"
        }
        Resize-WindowForTaskRows 10
        if ([int]$script:Form.Height -lt 240 -or [int]$script:Form.Height -le $collapsedHeight) {
            throw "selftest failed: resize ten rows"
        }
        $primaryArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $safePoint = Get-SafeWindowLocation 300 120 ($primaryArea.Right + 200) ($primaryArea.Bottom + 200)
        if ($null -eq $safePoint -or -not $primaryArea.Contains($safePoint)) {
            throw "selftest failed: safe window location"
        }
        if ($script:SizeToggleButton.Text -ne "-") {
            throw "selftest failed: size toggle expanded icon"
        }
        $script:WatermarkToggleButton = $null
        $script:Settings.Opacity = 0.92
        $watermarkCollapsedHeight = Get-TaskRowsWindowHeight (Get-CollapsedTaskRows)
        $watermarkBeforeHeight = [int]$script:Form.Height; $watermarkBeforeWidth = [int]$script:Form.Width; $watermarkBeforeLocation = $script:Form.Location; $watermarkBeforeView = [string]$script:ActiveView
        $formBackColorBeforeWatermark = $script:Form.BackColor
        $transparencyKeyBeforeWatermark = $script:Form.TransparencyKey
        Enter-WatermarkMode
        if (-not $script:WatermarkMode -or -not $script:Form.WatermarkMode -or [Math]::Abs([double]$script:Form.Opacity - 0.50) -gt 0.01) {
            throw "selftest failed: enter watermark"
        }
        if ($null -eq $script:WatermarkGhostPanel -or $script:WatermarkGhostPanel.IsDisposed -or $script:Form.TransparencyKey.ToArgb() -ne (Get-WatermarkTransparentColor).ToArgb()) {
            throw "selftest failed: watermark transparent ghost"
        }
        if ($script:ActiveView -ne "today" -or [int]$script:Form.Height -ne $watermarkCollapsedHeight) {
            throw "selftest failed: watermark collapsed today view"
        }
        $watermarkToggleIndex = $script:Form.Controls.GetChildIndex($script:WatermarkToggleButton)
        $watermarkGhostIndex = $script:Form.Controls.GetChildIndex($script:WatermarkGhostPanel)
        if ($script:WatermarkToggleButton.Text -ne [string][char]0x25B3 -or $script:WatermarkToggleButton.Parent -ne $script:Form -or ($script:Form.Visible -and -not $script:WatermarkToggleButton.Visible) -or $watermarkToggleIndex -gt $watermarkGhostIndex) {
            throw "selftest failed: watermark toggle icon"
        }
        if (-not $script:Form.ClickThroughEnabled) {
            throw "selftest failed: watermark click through"
        }
        $watermarkActiveHeight = [int]$script:Form.Height; $watermarkActiveWidth = [int]$script:Form.Width; $watermarkActiveLocation = $script:Form.Location; $watermarkActiveView = [string]$script:ActiveView; $watermarkActivePreserveLayout = [bool]$script:WatermarkPreserveLayout; Save-Settings; if ([int]$script:Settings.WindowHeight -ne $watermarkBeforeHeight -or $script:Settings.WindowX -ne $watermarkBeforeLocation.X -or $script:Settings.WindowY -ne $watermarkBeforeLocation.Y) { throw "selftest failed: watermark save preserves solid window" }
        Start-TranslationRuntime
        if (-not (Test-TranslationRuntimeActive) -or -not (Test-TranslationRuntimeTimerCreated) -or [bool]$script:WatermarkPreserveLayout -ne $watermarkActivePreserveLayout -or [int]$script:Form.Height -ne $watermarkActiveHeight -or [int]$script:Form.Width -ne $watermarkActiveWidth -or $script:Form.Location -ne $watermarkActiveLocation -or $script:ActiveView -ne $watermarkActiveView) {
            throw "selftest failed: translation preserves collapsed watermark"
        }
        $script:Settings.TranslationLastError = ""; Show-TranslationSettingsDialog; $translationSettingsDialog = Get-TranslationSettingsDialog; if ($null -eq $translationSettingsDialog) { throw "selftest failed: translation settings dialog open" }; $translationSettingsDialog.Close(); [System.Windows.Forms.Application]::DoEvents(); if ((Test-TranslationSettingsDialogOpen) -or -not (Test-TranslationRuntimeTimerEnabled) -or -not [string]::IsNullOrWhiteSpace([string]$script:Settings.TranslationLastError)) { throw "selftest failed: translation settings dialog close" }
        Stop-TranslationRuntime; if ((Test-TranslationRuntimeActive) -or (Test-TranslationRuntimeTimerCreated) -or -not $script:WatermarkMode -or [bool]$script:WatermarkPreserveLayout -ne $watermarkActivePreserveLayout -or [int]$script:Form.Height -ne $watermarkActiveHeight -or [int]$script:Form.Width -ne $watermarkActiveWidth -or $script:Form.Location -ne $watermarkActiveLocation) { throw "selftest failed: stop translation preserves current watermark" }
        Exit-WatermarkMode
        if ($script:WatermarkMode -or $script:Form.WatermarkMode -or [Math]::Abs([double]$script:Form.Opacity - 0.88) -gt 0.01) {
            throw "selftest failed: exit watermark"
        }
        if ($script:Form.ClickThroughEnabled) {
            throw "selftest failed: watermark click through reset"
        }
        if ((Test-TranslationRuntimeActive) -or (Test-TranslationRuntimeTimerCreated)) {
            throw "selftest failed: translation mode cleanup"
        }
        if ($null -ne $script:WatermarkGhostPanel -or $script:Form.BackColor.ToArgb() -ne $formBackColorBeforeWatermark.ToArgb() -or $script:Form.TransparencyKey.ToArgb() -ne $transparencyKeyBeforeWatermark.ToArgb()) {
            throw "selftest failed: watermark ghost restore"
        }
        if ($script:ActiveView -ne $watermarkBeforeView -or [int]$script:Form.Height -ne $watermarkBeforeHeight -or [int]$script:Form.Width -ne $watermarkBeforeWidth -or $script:Form.Location -ne $watermarkBeforeLocation) {
            throw "selftest failed: watermark restores previous layout"
        }
        $script:ActiveView = "tasks"
        Render-CurrentView
        $translationArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea; $translationPreserveLocation = New-Object System.Drawing.Point -ArgumentList @([Math]::Max($translationArea.Left, $translationArea.Right - 360), ($translationArea.Top + 96)); $translationPreserveMinimum = New-Object System.Drawing.Size(240, 34)
        $translationPreserveWidth = 312; $translationPreserveHeight = 137
        $translationTaskFontSize = [double]$script:Settings.TaskFontSize; $translationListFontSize = [double]$script:TaskListBox.Font.Size; $translationListItemHeight = [int]$script:TaskListBox.ItemHeight; $script:Settings.TranslationFontSize = if ($translationListFontSize -lt 20) { 24.0 } else { 9.0 }
        $script:Form.Location = $translationPreserveLocation; $script:Form.MinimumSize = $translationPreserveMinimum
        $script:Form.Width = $translationPreserveWidth; $script:Form.Height = $translationPreserveHeight; $script:Form.PerformLayout(); $translationContentPoint = $script:Form.PointToClient($script:ContentPanel.PointToScreen([System.Drawing.Point]::Empty)); $translationContentBounds = New-Object System.Drawing.Rectangle($translationContentPoint.X, $translationContentPoint.Y, [int]$script:ContentPanel.Width, [int]$script:ContentPanel.Height); $translationNavHeight = [int]$script:NavRowStyle.Height; $translationInputHeight = [int]$script:TaskInputRowStyle.Height
        Start-TranslationRuntime; if (-not (Test-TranslationRuntimeActive) -or $script:WatermarkMode -or [int]$script:Form.Height -ne $translationPreserveHeight -or [int]$script:Form.Width -ne $translationPreserveWidth -or $script:Form.Location -ne $translationPreserveLocation -or [double]$script:Settings.TaskFontSize -ne $translationTaskFontSize -or $null -ne $script:WatermarkGhostPanel) { throw "selftest failed: solid translation preserves layout" }; Show-TranslationSurfaceResult ([pscustomobject]@{ Short = "ok"; Detail = "ok"; Word = "test"; Phonetic = ""; Pos = ""; Tags = ""; Frequency = ""; IsHint = $false }) ([System.Drawing.Rectangle]::Empty); if ([int]$script:Form.Height -ne $translationPreserveHeight -or [int]$script:Form.Width -ne $translationPreserveWidth -or $script:Form.Location -ne $translationPreserveLocation -or [double]$script:Settings.TaskFontSize -ne $translationTaskFontSize) { throw "selftest failed: translation surface preserves host" }; Hide-TranslationSurfaceResultFromTimer; if (($null -ne $script:WatermarkTranslationMiniForm -and $script:WatermarkTranslationMiniForm.Visible) -or ($null -ne $script:WatermarkTranslationDetailForm -and $script:WatermarkTranslationDetailForm.Visible)) { throw "selftest failed: translation surface hide timer" }; Stop-TranslationRuntime; Enter-WatermarkMode $true; Start-TranslationRuntime
        if (-not (Test-TranslationRuntimeActive) -or -not $script:WatermarkMode -or $script:ActiveView -ne "tasks" -or [int]$script:Form.Height -ne $translationPreserveHeight -or [int]$script:Form.Width -ne $translationPreserveWidth -or $script:Form.Location -ne $translationPreserveLocation -or $script:Form.MinimumSize -ne $translationPreserveMinimum -or [double]$script:Settings.TaskFontSize -ne $translationTaskFontSize -or [int]$script:NavRowStyle.Height -ne $translationNavHeight -or [int]$script:TaskInputRowStyle.Height -ne $translationInputHeight) {
            throw "selftest failed: translation preserves layout view=$($script:ActiveView) size=$([int]$script:Form.Width)x$([int]$script:Form.Height) location=$($script:Form.Location) font=$($script:Settings.TaskFontSize)"
        }
        if ($null -eq $script:WatermarkGhostPanel -or [Math]::Abs([double]$script:WatermarkGhostPanel.Font.Size - $translationListFontSize) -gt 0.01 -or [Math]::Abs([double]$script:WatermarkGhostPanel.Font.Size - [double]$script:Settings.TranslationFontSize) -lt 0.01 -or [int]$script:WatermarkGhostPanel.Tag.RowHeight -ne $translationListItemHeight -or $script:WatermarkGhostPanel.Bounds -ne $translationContentBounds -or [int]$script:WatermarkGhostPanel.Padding.Left -ne 0) {
            throw "selftest failed: translation ghost metrics"
        }
        $script:Settings | Add-Member -NotePropertyName TranslationDetailX -NotePropertyValue 123 -Force; $script:Settings | Add-Member -NotePropertyName TranslationDetailY -NotePropertyValue 145 -Force; Normalize-Settings; if (($script:Settings.PSObject.Properties.Name -contains "TranslationDetailX") -or ($script:Settings.PSObject.Properties.Name -contains "TranslationDetailY") -or $null -ne $script:TranslationClipboardTimer) { throw "selftest failed: translation detail position removed or clipboard listener default" }
        $script:Settings.TranslationClipboardListenerEnabled = $true
        Start-TranslationClipboardListener
        if ($null -eq $script:TranslationClipboardTimer) {
            throw "selftest failed: clipboard listener opt-in"
        }
        Exit-WatermarkMode
        if (-not (Test-TranslationRuntimeActive) -or -not (Test-TranslationRuntimeTimerCreated) -or $null -eq $script:TranslationClipboardTimer) {
            throw "selftest failed: exiting watermark must not stop translation runtime"
        }
        if ($script:WatermarkMode -or $script:Form.WatermarkMode -or $script:Form.ClickThroughEnabled) {
            throw "selftest failed: translation exit watermark state"
        }
        if ($script:ActiveView -ne "tasks" -or [int]$script:Form.Height -ne $translationPreserveHeight -or [int]$script:Form.Width -ne $translationPreserveWidth -or $script:Form.Location -ne $translationPreserveLocation -or $script:Form.MinimumSize -ne $translationPreserveMinimum -or [double]$script:Settings.TaskFontSize -ne $translationTaskFontSize) {
            throw "selftest failed: translation exit preserves layout"
        }
        Stop-TranslationRuntime
        if ((Test-TranslationRuntimeActive) -or (Test-TranslationRuntimeTimerCreated) -or $null -ne $script:TranslationClipboardTimer) {
            throw "selftest failed: explicit translation stop cleanup"
        }
        $script:Settings.TranslationClipboardListenerEnabled = $false
        $script:SizeToggleButton.Dispose()
        $script:Form.Dispose()
        $script:ContentPanel.Dispose()
        $script:MainPanel.Dispose()
        $script:Form = $null
        $script:ContentPanel = $null
        $script:MainPanel = $null
        $script:WatermarkToggleButton = $null
    }
    finally {
        try { $translationSettingsDialog = Get-TranslationSettingsDialog; if ($null -ne $translationSettingsDialog -and -not $translationSettingsDialog.IsDisposed) { $translationSettingsDialog.Close() } } catch {}
        try { Stop-TranslationRuntime } catch {}
        try { Stop-TranslationClipboardListener } catch {}
        try { if ($script:WatermarkMode) { Exit-WatermarkMode } } catch {}
        try { if ($null -ne $testList -and -not $testList.IsDisposed) { $testList.Dispose() } } catch {}
        foreach ($controlName in @("SizeToggleButton", "WatermarkToggleButton", "TaskListBox", "ContentPanel", "MainPanel", "Form")) {
            try {
                $control = Get-Variable -Scope Script -Name $controlName -ErrorAction SilentlyContinue
                if ($null -ne $control -and $null -ne $control.Value -and $control.Value -is [System.IDisposable] -and -not $control.Value.IsDisposed) { $control.Value.Dispose() }
            } catch {}
        }
        $script:Form = $null
        $script:ContentPanel = $null
        $script:MainPanel = $null
        $script:TaskListBox = $null
        $script:SizeToggleButton = $null
        $script:WatermarkToggleButton = $null
        $script:WatermarkGhostPanel = $null
        $script:TranslationSettingsDialog = $null
        $script:Settings.TranslationClipboardListenerEnabled = $false
    }
}
