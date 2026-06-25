# This file is dot-sourced before WatermarkMode.ps1. Keep watermark right-click menu construction out of translation orchestration.

function Add-WatermarkMenuAction([System.Windows.Forms.ContextMenuStrip]$Menu, [string]$TextKey, [scriptblock]$Action, [bool]$Enabled = $true) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = T $TextKey; $item.Enabled = $Enabled; $item.Add_Click($Action)
    $Menu.Items.Add($item) | Out-Null
}

function Invoke-WatermarkMenuDeferredAction([System.Windows.Forms.Control]$Owner, [scriptblock]$Action) {
    if ($null -eq $Action) { return }
    $runner = [System.Action]{ try { & $Action } finally { if ((Test-WatermarkRuntimeActive) -and -not (Test-TranslationSettingsDialogOpen)) { Update-WatermarkRuntimeClickThrough } } }
    if ($null -ne $Owner -and -not $Owner.IsDisposed -and $Owner.IsHandleCreated) { $Owner.BeginInvoke($runner) | Out-Null; return }
    $runner.Invoke()
}

function Show-WatermarkMenu([System.Windows.Forms.Control]$Owner) {
    if ($null -eq $Owner -or $Owner.IsDisposed) { return }
    if (Test-WatermarkRuntimeActive) { Suspend-WatermarkRuntimeClickThrough }
    $menuOwner = $Owner
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    Add-WatermarkMenuAction $menu "WatermarkToggle" { Toggle-WatermarkRuntime } $true
    if ((Test-TranslationRuntimeActive)) { Add-WatermarkMenuAction $menu "TranslationStop" { Invoke-WatermarkMenuDeferredAction $menuOwner { Stop-TranslationRuntime; Set-Status (T "TranslationModeOff") } } $true }
    else { Add-WatermarkMenuAction $menu "WatermarkTranslation" { Invoke-WatermarkMenuDeferredAction $menuOwner { Start-TranslationRuntime } } $true }
    Add-WatermarkMenuAction $menu "TranslationSettings" { Show-TranslationSettingsDialog } $true
    $menu.Add_Closed({ if ((Test-WatermarkRuntimeActive) -and -not (Test-TranslationSettingsDialogOpen)) { Update-WatermarkRuntimeClickThrough } })
    $menu.Show($Owner, (New-Object System.Drawing.Point -ArgumentList @(0, [int]$Owner.Height)))
}