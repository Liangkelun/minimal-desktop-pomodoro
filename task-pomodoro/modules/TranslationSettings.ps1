# This file is dot-sourced by TaskPomodoro.ps1. It owns translation settings UI and dictionary import dialogs.
function Set-TranslationComboSelection([System.Windows.Forms.ComboBox]$Combo, [string]$Value) {
    $Combo.SelectedIndex = 0
    for ($i = 0; $i -lt $Combo.Items.Count; $i++) { if ([string]$Combo.Items[$i].Value -eq $Value) { $Combo.SelectedIndex = $i; break } }
}
function New-TranslationProviderCombo {
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $combo.DisplayMember = "Label"; $combo.ValueMember = "Value"
    foreach ($item in @(@{ Label = T "TranslationDisabled"; Value = "disabled" }, @{ Label = T "TranslationProviderCustom"; Value = "custom" }, @{ Label = "DeepL"; Value = "deepl" }, @{ Label = T "TranslationProviderBaidu"; Value = "baidu" })) { $combo.Items.Add([pscustomobject]$item) | Out-Null }
    Set-TranslationComboSelection $combo ([string]$script:Settings.TranslationProvider)
    return $combo
}
function New-TranslationSurfaceStyleCombo {
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $combo.DisplayMember = "Label"; $combo.ValueMember = "Value"
    foreach ($item in @(@{ Label = T "TranslationSurfaceStyleFollow"; Value = "follow" }, @{ Label = T "TranslationSurfaceStyleBlur"; Value = "blur" }, @{ Label = T "TranslationSurfaceStyleSolid"; Value = "solid" })) { $combo.Items.Add([pscustomobject]$item) | Out-Null }
    Set-TranslationComboSelection $combo ([string]$script:Settings.TranslationSurfaceStyle)
    return $combo
}
function New-TranslationSurfaceColorModeCombo {
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $combo.DisplayMember = "Label"; $combo.ValueMember = "Value"
    foreach ($item in @(@{ Label = T "TranslationSurfaceColorModeBlackOnWhite"; Value = "black-on-white" }, @{ Label = T "TranslationSurfaceColorModeWhiteOnBlack"; Value = "white-on-black" })) { $combo.Items.Add([pscustomobject]$item) | Out-Null }
    Set-TranslationComboSelection $combo ([string]$script:Settings.TranslationSurfaceColorMode)
    return $combo
}
function New-TranslationPerformanceModeCombo {
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $combo.DisplayMember = "Label"; $combo.ValueMember = "Value"
    foreach ($item in @(@{ Label = T "TranslationModeFast"; Value = "fast" }, @{ Label = T "TranslationModeMemory"; Value = "memory" })) { $combo.Items.Add([pscustomobject]$item) | Out-Null }
    Set-TranslationComboSelection $combo ([string]$script:Settings.TranslationPerformanceMode)
    return $combo
}
function Get-TranslationHelpPagePath { return (Join-Path (Get-AppPath "RootDir") "assets\help\translation-api-setup.html") }
function Open-TranslationHelpPage([string]$Anchor = "") {
    $path = Get-TranslationHelpPagePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $script:Settings.TranslationLastError = "Missing help page: $path"; Set-Status (T "TranslationServiceUnavailable"); return }
    $uri = (New-Object System.Uri($path)).AbsoluteUri
    if (-not [string]::IsNullOrWhiteSpace($Anchor)) { $uri = "$uri#$Anchor" }
    Start-Process $uri | Out-Null
}
function Get-TranslationDictionaryImportButtonText {
    if (-not [string]::IsNullOrWhiteSpace((Get-TranslationUserDictionaryPath))) { return (T "TranslationUnbindDictionary") }
    return (T "TranslationImportDictionary")
}
function Update-TranslationDictionaryImportButton([System.Windows.Forms.Button]$Button) {
    if ($null -ne $Button) { $Button.Text = Get-TranslationDictionaryImportButtonText }
}
function Invoke-TranslationDictionaryImportButton([System.Windows.Forms.Button]$Button) {
    if (-not [string]::IsNullOrWhiteSpace((Get-TranslationUserDictionaryPath))) { Clear-TranslationDictionaryBinding; Set-Status (T "TranslationDictionaryUnbound") }
    else { Show-TranslationDictionaryImportDialog | Out-Null }
    Update-TranslationDictionaryImportButton $Button
}
function Invoke-TranslationFullDictionaryButton([System.Windows.Forms.Button]$ImportButton) {
    if (Install-TranslationFullDictionary) { Set-Status (T "TranslationDictionaryLoaded") }
    else { Set-Status (T "TranslationDictionaryUnavailable"); [System.Windows.Forms.MessageBox]::Show((T "TranslationDictionaryUnavailable"), (T "TranslationDictionaryFull")) | Out-Null }
    Update-TranslationDictionaryImportButton $ImportButton
}
function Add-TranslationSettingsRows([System.Windows.Forms.TableLayoutPanel]$Panel, [int]$StartRow) {
    Add-SettingSection $Panel (T "TranslationSettings") $StartRow
    $provider = New-TranslationProviderCombo; Add-SettingRow $Panel (T "TranslationService") $provider ($StartRow + 1)
    $target = New-Object System.Windows.Forms.ComboBox
    $target.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $target.DisplayMember = "Label"; $target.ValueMember = "Value"
    $target.Items.Add([pscustomobject]@{ Label = T "Chinese"; Value = "zh" }) | Out-Null; $target.Items.Add([pscustomobject]@{ Label = T "English"; Value = "en" }) | Out-Null
    Set-TranslationComboSelection $target ([string]$script:Settings.TranslationTargetLanguage); Add-SettingRow $Panel (T "TranslationTargetLanguage") $target ($StartRow + 2)
    $fontSize = New-Object System.Windows.Forms.NumericUpDown
    $fontSize.Minimum = 9; $fontSize.Maximum = 32; $fontSize.DecimalPlaces = 1; $fontSize.Increment = [decimal]0.5; $fontSize.Value = [decimal](Get-TranslationSurfaceFontSize)
    Add-SettingRow $Panel (T "TranslationFontSize") $fontSize ($StartRow + 3)
    $surfaceStyle = New-TranslationSurfaceStyleCombo; Add-SettingRow $Panel (T "TranslationSurfaceStyle") $surfaceStyle ($StartRow + 4)
    $surfaceColorMode = New-TranslationSurfaceColorModeCombo; Add-SettingRow $Panel (T "TranslationSurfaceColorMode") $surfaceColorMode ($StartRow + 5)
    $performanceMode = New-TranslationPerformanceModeCombo; Add-SettingRow $Panel (T "TranslationPerformanceMode") $performanceMode ($StartRow + 6)
    $clipboard = New-CheckOnlyControl ([bool]$script:Settings.TranslationClipboardListenerEnabled); Add-SettingRow $Panel (T "TranslationClipboardListener") $clipboard.Panel ($StartRow + 7)
    $limit = New-Object System.Windows.Forms.NumericUpDown
    $limit.Minimum = 1000; $limit.Maximum = 2000000; $limit.Increment = 10000; $limit.Value = [decimal]$script:Settings.TranslationMonthlyLimit
    Add-SettingRow $Panel (T "TranslationMonthlyLimit") $limit ($StartRow + 8)
    $endpoint = New-Object System.Windows.Forms.TextBox; $endpoint.Text = [string]$script:Settings.TranslationCustomEndpoint; Add-SettingRow $Panel (T "TranslationEndpoint") $endpoint ($StartRow + 9)
    $customKey = New-Object System.Windows.Forms.TextBox; $customKey.UseSystemPasswordChar = $true; Add-SettingRow $Panel (T "TranslationApiKey") $customKey ($StartRow + 10)
    $deeplMode = New-Object System.Windows.Forms.ComboBox
    $deeplMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; $deeplMode.DisplayMember = "Label"; $deeplMode.ValueMember = "Value"
    $deeplMode.Items.Add([pscustomobject]@{ Label = T "TranslationDeepLFree"; Value = "free" }) | Out-Null; $deeplMode.Items.Add([pscustomobject]@{ Label = T "TranslationDeepLPro"; Value = "pro" }) | Out-Null
    Set-TranslationComboSelection $deeplMode ([string]$script:Settings.TranslationDeepLMode); Add-SettingRow $Panel (T "TranslationDeepLMode") $deeplMode ($StartRow + 11)
    $deeplKey = New-Object System.Windows.Forms.TextBox; $deeplKey.UseSystemPasswordChar = $true; Add-SettingRow $Panel (T "TranslationApiKey") $deeplKey ($StartRow + 12)
    $baiduAppId = New-Object System.Windows.Forms.TextBox; $baiduAppId.Text = [string]$script:Settings.TranslationBaiduAppId; Add-SettingRow $Panel (T "TranslationBaiduAppId") $baiduAppId ($StartRow + 13)
    $baiduSecret = New-Object System.Windows.Forms.TextBox; $baiduSecret.UseSystemPasswordChar = $true; Add-SettingRow $Panel (T "TranslationBaiduSecret") $baiduSecret ($StartRow + 14)
    $apiActions = New-Object System.Windows.Forms.FlowLayoutPanel
    $apiActions.Dock = [System.Windows.Forms.DockStyle]::Fill; $apiActions.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight; $apiActions.WrapContents = $false; $apiActions.BackColor = $Panel.BackColor
    $test = New-Button (T "TranslationTestConnection") 66
    $test.Add_Click({ param($sender, $eventArgs) Apply-TranslationSettingsControls $sender.Tag $false; $ok = Test-TranslationConnection; [System.Windows.Forms.MessageBox]::Show((T $(if ($ok) { "TranslationConnectionOk" } else { "TranslationConnectionFailed" })), (T "TranslationSettings")) | Out-Null })
    $guide = New-Button (T "TranslationApiGuide") 86; $guide.Add_Click({ Open-TranslationHelpPage "api" })
    $apiActions.Controls.Add($test); $apiActions.Controls.Add($guide); Add-SettingRow $Panel (T "TranslationApiGuide") $apiActions ($StartRow + 15)
    $dictActions = New-Object System.Windows.Forms.FlowLayoutPanel
    $dictActions.Dock = [System.Windows.Forms.DockStyle]::Fill; $dictActions.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight; $dictActions.WrapContents = $false; $dictActions.BackColor = $Panel.BackColor
    $import = New-Button (Get-TranslationDictionaryImportButtonText) 86; $import.Add_Click({ param($sender, $eventArgs) Invoke-TranslationDictionaryImportButton $sender })
    $download = New-Button (T "TranslationGetFullDictionary") 86; $download.Tag = $import; $download.Add_Click({ param($sender, $eventArgs) Invoke-TranslationFullDictionaryButton $sender.Tag })
    $dictActions.Controls.Add($import); $dictActions.Controls.Add($download); Add-SettingRow $Panel (T "TranslationDictionaryFull") $dictActions ($StartRow + 16)
    $privacy = New-Object System.Windows.Forms.Label
    $privacy.Text = (T "TranslationPrivacyNote") + " " + (T "TranslationClipboardListenerNote")
    $privacy.Dock = [System.Windows.Forms.DockStyle]::Fill; $privacy.AutoEllipsis = $true; $privacy.BackColor = $Panel.BackColor; $privacy.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99); $privacy.Font = New-Object System.Drawing.Font($privacy.Font.FontFamily, 8.5)
    $Panel.Controls.Add($privacy, 0, ($StartRow + 17)); $Panel.SetColumnSpan($privacy, 2)
    $controls = [pscustomobject]@{ Provider = $provider; Target = $target; SurfaceStyle = $surfaceStyle; SurfaceColorMode = $surfaceColorMode; PerformanceMode = $performanceMode; ClipboardListener = $clipboard.Check; Limit = $limit; CustomEndpoint = $endpoint; CustomKey = $customKey; DeepLMode = $deeplMode; DeepLKey = $deeplKey; BaiduAppId = $baiduAppId; BaiduSecret = $baiduSecret; FontSize = $fontSize }
    $test.Tag = $controls
    return $controls
}
function New-TranslationSettingsPanel {
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Top; $panel.AutoSize = $true; $panel.ColumnCount = 2; $panel.RowCount = 18; $panel.Padding = New-Object System.Windows.Forms.Padding(8); $panel.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 43))) | Out-Null; $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 57))) | Out-Null
    for ($i = 0; $i -lt $panel.RowCount; $i++) { $height = 30; if ($i -eq 0) { $height = 38 } elseif ($i -eq 17) { $height = 58 }; $panel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, $height))) | Out-Null }
    return [pscustomobject]@{ Panel = $panel; Controls = (Add-TranslationSettingsRows $panel 0) }
}
function Get-TranslationSettingsDialog { return Get-Variable -Name TranslationSettingsDialog -Scope Script -ValueOnly -ErrorAction SilentlyContinue }
function Test-TranslationSettingsDialogOpen {
    $dialog = Get-TranslationSettingsDialog
    return ($null -ne $dialog -and -not $dialog.IsDisposed)
}
function Show-TranslationSettingsDialog {
    if ($null -ne $script:TranslationSettingsDialog -and -not $script:TranslationSettingsDialog.IsDisposed) { $script:TranslationSettingsDialog.Activate(); return }
    Suspend-TranslationRuntimeForSettings
    Suspend-WatermarkRuntimeClickThrough
    $dialog = New-Object System.Windows.Forms.Form
    $script:TranslationSettingsDialog = $dialog
    $dialog.Text = T "TranslationSettings"; $dialog.Width = 430; $dialog.Height = 590; $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent; $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow; $dialog.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250); $dialog.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.0)
    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill; $root.RowCount = 2; $root.ColumnCount = 1; $root.BackColor = $dialog.BackColor
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null; $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42))) | Out-Null
    $settingsPanel = New-TranslationSettingsPanel
    $scroll = New-Object System.Windows.Forms.Panel
    $scroll.Dock = [System.Windows.Forms.DockStyle]::Fill; $scroll.AutoScroll = $true; $scroll.BackColor = $dialog.BackColor; $scroll.Controls.Add($settingsPanel.Panel)
    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [System.Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft; $buttons.WrapContents = $false; $buttons.Padding = New-Object System.Windows.Forms.Padding(0, 4, 8, 0); $buttons.BackColor = $dialog.BackColor
    $save = New-Button (T "SaveSettings") 82; $cancel = New-Button (T "Cancel") 70; $save.Tag = $settingsPanel.Controls
    $save.Add_Click({ param($sender, $eventArgs) Apply-TranslationSettingsControls $sender.Tag $false; Save-TranslationSettings; Set-Status (T "SettingsSaved"); $owner = $sender.FindForm(); if ($null -ne $owner) { $owner.DialogResult = [System.Windows.Forms.DialogResult]::OK; $owner.Close() } })
    $cancel.Add_Click({ param($sender, $eventArgs) $owner = $sender.FindForm(); if ($null -ne $owner) { $owner.Close() } })
    $buttons.Controls.Add($save); $buttons.Controls.Add($cancel); $root.Controls.Add($scroll, 0, 0); $root.Controls.Add($buttons, 0, 1); $dialog.Controls.Add($root)
    $dialog.Add_FormClosed({
        param($sender, $eventArgs)
        $script:TranslationSettingsDialog = $null
        try { Resume-TranslationRuntimeAfterSettings; if (Test-WatermarkRuntimeActive) { Update-WatermarkRuntimeClickThrough } }
        catch { if ($null -ne $script:Settings) { $script:Settings.TranslationLastError = [string]$_.Exception.Message } }
    })
    if ($null -ne $script:Form -and -not $script:Form.IsDisposed) { $dialog.Show($script:Form) } else { $dialog.Show() }
}
function Apply-TranslationSettingsControls([object]$Controls, [bool]$UpdateRuntime = $true) {
    if ($null -eq $Controls) { return }
    if ($null -ne $Controls.Provider.SelectedItem) { $script:Settings.TranslationProvider = [string]$Controls.Provider.SelectedItem.Value }
    if ($null -ne $Controls.Target.SelectedItem) { $script:Settings.TranslationTargetLanguage = [string]$Controls.Target.SelectedItem.Value }
    if ($null -ne $Controls.SurfaceStyle.SelectedItem) { $script:Settings.TranslationSurfaceStyle = [string]$Controls.SurfaceStyle.SelectedItem.Value }
    if ($null -ne $Controls.SurfaceColorMode.SelectedItem) { $script:Settings.TranslationSurfaceColorMode = [string]$Controls.SurfaceColorMode.SelectedItem.Value }
    if ($null -ne $Controls.FontSize) { $script:Settings.TranslationFontSize = [double]$Controls.FontSize.Value }
    if ($null -ne $Controls.ClipboardListener) { $script:Settings.TranslationClipboardListenerEnabled = [bool]$Controls.ClipboardListener.Checked }
    $script:Settings.TranslationMonthlyLimit = [int]$Controls.Limit.Value
    $script:Settings.TranslationCustomEndpoint = [string]$Controls.CustomEndpoint.Text
    if (-not [string]::IsNullOrWhiteSpace([string]$Controls.CustomKey.Text)) { $script:Settings.TranslationCustomApiKeyProtected = Protect-TranslationSecret ([string]$Controls.CustomKey.Text) }
    if ($null -ne $Controls.DeepLMode.SelectedItem) { $script:Settings.TranslationDeepLMode = [string]$Controls.DeepLMode.SelectedItem.Value }
    if (-not [string]::IsNullOrWhiteSpace([string]$Controls.DeepLKey.Text)) { $script:Settings.TranslationDeepLApiKeyProtected = Protect-TranslationSecret ([string]$Controls.DeepLKey.Text) }
    $script:Settings.TranslationBaiduAppId = [string]$Controls.BaiduAppId.Text
    if (-not [string]::IsNullOrWhiteSpace([string]$Controls.BaiduSecret.Text)) { $script:Settings.TranslationBaiduSecretProtected = Protect-TranslationSecret ([string]$Controls.BaiduSecret.Text) }
    Normalize-Settings
    if ($UpdateRuntime) { Update-TranslationRuntimeAfterSettingsChanged }
}
function Test-TranslationConnection {
    if (-not (Test-TranslationProviderEnabled)) { return $false }
    $result = Invoke-TranslationProviderApi "test"
    return (-not [string]::IsNullOrWhiteSpace($result))
}
function Show-TranslationDictionaryImportDialog {
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Title = T "TranslationImportDictionary"
    $openDialog.Filter = "TSV dictionary (*.tsv)|*.tsv|All files (*.*)|*.*"
    try {
        if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if (Set-TranslationDictionaryBinding ([string]$openDialog.FileName)) { Set-Status (T "TranslationDictionaryLoaded"); return $true }
            Set-Status (T "TranslationDictionaryUnavailable")
        }
    }
    finally {
        $openDialog.Dispose()
    }
    return $false
}