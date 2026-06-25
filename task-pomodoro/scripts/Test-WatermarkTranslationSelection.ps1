param(
    [int]$DurationSeconds = 0
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$form = New-Object System.Windows.Forms.Form
$form.Text = "Watermark translation UIA selection probe"
$form.Width = 560
$form.Height = 260
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

$box = New-Object System.Windows.Forms.TextBox
$box.Multiline = $true
$box.Dock = [System.Windows.Forms.DockStyle]::Top
$box.Height = 140
$box.Font = New-Object System.Drawing.Font("Consolas", 11.0)
$box.Text = "Double click translation, or drag select this short English sentence."

$status = New-Object System.Windows.Forms.Label
$status.Dock = [System.Windows.Forms.DockStyle]::Fill
$status.Padding = New-Object System.Windows.Forms.Padding(8)
$status.Text = "Waiting for UI Automation selection..."

$form.Controls.Add($status)
$form.Controls.Add($box)

function Get-ProbeSelection {
    try {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        if ($null -eq $focused) { return $null }
        $pattern = $null
        if (-not $focused.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern, [ref]$pattern)) { return $null }
        $ranges = $pattern.GetSelection()
        if ($null -eq $ranges -or $ranges.Count -eq 0) { return $null }
        foreach ($range in @($ranges)) {
            $text = ([string]$range.GetText(1201)).Trim()
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $rectText = "no rectangle"
            try {
                $rects = $range.GetBoundingRectangles()
                if ($null -ne $rects -and $rects.Count -ge 4) {
                    $rectText = "x=$([int]$rects[0]), y=$([int]$rects[1]), w=$([int]$rects[2]), h=$([int]$rects[3])"
                }
            }
            catch {}
            return "selection: '$text'`r`n$rectText"
        }
    }
    catch {
        return "UIA read failed: $($_.Exception.Message)"
    }
    return $null
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300
$timer.Add_Tick({
    $selection = Get-ProbeSelection
    if ([string]::IsNullOrWhiteSpace($selection)) {
        $status.Text = "No UI Automation selection."
    }
    else {
        $status.Text = $selection
    }
})

if ($DurationSeconds -gt 0) {
    $closeTimer = New-Object System.Windows.Forms.Timer
    $closeTimer.Interval = [Math]::Max(1, $DurationSeconds) * 1000
    $closeTimer.Add_Tick({
        $closeTimer.Stop()
        $form.Close()
    })
}

$form.Add_Shown({
    $box.Focus()
    $box.Select(13, 11)
    $timer.Start()
    if ($DurationSeconds -gt 0) { $closeTimer.Start() }
})

$form.Add_FormClosed({
    $timer.Stop()
    $timer.Dispose()
    if ($null -ne $closeTimer) {
        $closeTimer.Stop()
        $closeTimer.Dispose()
    }
    $form.Dispose()
})

[System.Windows.Forms.Application]::Run($form)
