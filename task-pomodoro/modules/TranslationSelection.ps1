# This file is dot-sourced by TaskPomodoro.ps1. It owns translation selection adapters: UIA and opt-in read-only clipboard listening.

function Get-TranslationSelectionFromElement([System.Windows.Automation.AutomationElement]$Element) {
    if ($null -eq $Element) { return $null }
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern, [ref]$pattern)) { return $null }
    $ranges = $pattern.GetSelection()
    if ($null -eq $ranges -or $ranges.Count -eq 0) { return $null }
    foreach ($range in @($ranges)) {
        $rawText = [string]$range.GetText(1201)
        if ($rawText.Length -gt 1200) { continue }
        $text = [regex]::Replace($rawText.Trim(), "\s+", " ")
        if ([string]::IsNullOrWhiteSpace($text) -or $text.Length -gt 1200) { continue }
        $rect = [System.Drawing.Rectangle]::Empty
        try {
            $rects = $range.GetBoundingRectangles()
            if ($null -ne $rects -and $rects.Count -ge 4) { $rect = New-Object System.Drawing.Rectangle -ArgumentList @([int]$rects[0], [int]$rects[1], [int]$rects[2], [int]$rects[3]) }
        }
        catch {}
        return [pscustomobject]@{ Text = $text; Rect = $rect }
    }
    return $null
}

function Get-TranslationSelection {
    Ensure-TranslationPlatformTypes
    try {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        if ($null -eq $focused) { return $null }
        try { if ([int]$focused.Current.ProcessId -eq $PID) { return $null } } catch {}
        $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
        $element = $focused
        for ($depth = 0; $depth -lt 6 -and $null -ne $element; $depth++) {
            $selection = Get-TranslationSelectionFromElement $element
            if ($null -ne $selection) { return $selection }
            try { $element = $walker.GetParent($element) } catch { $element = $null }
        }
    }
    catch { return $null }
    return $null
}

function Test-TranslationUiaSelectionEnabled {
    if ($null -eq $script:Settings -or -not ($script:Settings.PSObject.Properties.Name -contains "TranslationUiaSelectionEnabled")) { return $false }
    try { return [bool]$script:Settings.TranslationUiaSelectionEnabled } catch { return $false }
}
function Test-TranslationClipboardListenerEnabled {
    if ($null -eq $script:Settings -or -not ($script:Settings.PSObject.Properties.Name -contains "TranslationClipboardListenerEnabled")) { return $false }
    try { return [bool]$script:Settings.TranslationClipboardListenerEnabled } catch { return $false }
}

function Get-TranslationClipboardText {
    try {
        if (-not [System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::UnicodeText)) { return "" }
        return [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::UnicodeText)
    }
    catch { return "" }
}

function Stop-TranslationClipboardListener([bool]$ClearHandler = $false) {
    if ($null -ne $script:TranslationClipboardTimer) { $script:TranslationClipboardTimer.Stop(); $script:TranslationClipboardTimer.Dispose(); $script:TranslationClipboardTimer = $null }
    $script:TranslationLastClipboardSequence = 0
    if ($ClearHandler) { $script:TranslationClipboardTextHandler = $null }
}

function Start-TranslationClipboardListener([scriptblock]$OnText = $null) {
    if ($null -ne $OnText) { $script:TranslationClipboardTextHandler = $OnText }
    if (-not (Test-TranslationClipboardListenerEnabled) -or $null -eq $script:TranslationClipboardTextHandler) { Stop-TranslationClipboardListener; return }
    Ensure-TranslationPlatformTypes
    if ($null -eq $script:TranslationClipboardTimer) {
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 600
        $timer.Add_Tick({ Update-TranslationClipboard })
        $script:TranslationClipboardTimer = $timer
    }
    try { $script:TranslationLastClipboardSequence = [TaskPomodoroTranslationNative]::GetClipboardSequenceNumber() } catch { $script:TranslationLastClipboardSequence = 0 }
    $script:TranslationClipboardTimer.Start()
}

function Update-TranslationClipboard {
    if (-not (Test-TranslationClipboardListenerEnabled) -or $null -eq $script:TranslationClipboardTextHandler) { return }
    try { $sequence = [TaskPomodoroTranslationNative]::GetClipboardSequenceNumber() } catch { return }
    if ([uint32]$sequence -eq [uint32]$script:TranslationLastClipboardSequence) { return }
    $script:TranslationLastClipboardSequence = [uint32]$sequence
    $text = Get-TranslationClipboardText
    if (-not [string]::IsNullOrWhiteSpace($text)) { & $script:TranslationClipboardTextHandler $text }
}