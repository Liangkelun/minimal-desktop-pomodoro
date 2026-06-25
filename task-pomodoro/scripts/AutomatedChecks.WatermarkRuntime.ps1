# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for Watermark runtime boundary assertions.

function Invoke-WatermarkRuntimeBoundaryCheck([string]$ModulesDir) {
    $toggleButton = Join-Path $ModulesDir "WatermarkToggleButton.ps1"
    $mode = Join-Path $ModulesDir "WatermarkMode.ps1"
    $runtime = Join-Path $ModulesDir "WatermarkRuntime.ps1"
    $windowChrome = Join-Path $ModulesDir "WindowChrome.ps1"
    $externalFiles = @("BottomChrome.ps1", "UiTimer.ps1", "HelpSurface.ps1", "DesktopShortcut.ps1", "Views.Settings.ps1", "Views.Settings.Apply.ps1", "Views.Settings.General.ps1", "TranslationSettings.ps1", "WatermarkTranslation.Settings.ps1", "WatermarkMode.Menu.ps1")
    foreach ($requiredFile in @($toggleButton, $mode, $runtime, $windowChrome)) { Test-RequiredFile $requiredFile }
    foreach ($fileName in $externalFiles) { Test-RequiredFile (Join-Path $ModulesDir $fileName) }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1"); $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("WindowChrome.ps1", "WatermarkToggleButton.ps1", "WatermarkMode.ps1", "WatermarkRuntime.ps1") + $externalFiles) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    if ([Array]::IndexOf($loadOrder, "WindowChrome.ps1") -gt [Array]::IndexOf($loadOrder, "WatermarkMode.ps1")) { throw "WindowChrome.ps1 must load before WatermarkMode.ps1" }
    if ([Array]::IndexOf($loadOrder, "WatermarkToggleButton.ps1") -gt [Array]::IndexOf($loadOrder, "WatermarkMode.ps1")) { throw "WatermarkToggleButton.ps1 must load before WatermarkMode.ps1" }
    if ([Array]::IndexOf($loadOrder, "WatermarkMode.ps1") -gt [Array]::IndexOf($loadOrder, "WatermarkRuntime.ps1")) { throw "WatermarkRuntime.ps1 must load after WatermarkMode.ps1" }
    foreach ($fileName in $externalFiles) { if ([Array]::IndexOf($loadOrder, "WatermarkRuntime.ps1") -gt [Array]::IndexOf($loadOrder, $fileName)) { throw "WatermarkRuntime.ps1 must load before $fileName" } }
    $runtimeRaw = Get-Content -LiteralPath $runtime -Encoding UTF8 -Raw
    foreach ($required in @("function Test-WatermarkRuntimeActive", "function Start-WatermarkRuntime", "function Stop-WatermarkRuntime", "function Toggle-WatermarkRuntime", "function Update-WatermarkRuntimeClickThrough", "function Set-WatermarkRuntimeConfiguredOpacity")) { if ($runtimeRaw -notlike "*$required*") { throw "WatermarkRuntime.ps1 missing required marker: $required" } }
    $windowChromeRaw = Get-Content -LiteralPath $windowChrome -Encoding UTF8 -Raw
    foreach ($required in @("function Test-WindowChromeReady", "function Set-WindowChromeWatermarkActive", "function Set-WindowChromeOpacity", "function Set-WindowChromeTopMost", "function Set-WindowChromeWatermarkExitSize", "function Test-WindowChromeClickThrough", "function Set-WindowChromeClickThrough", "function Test-WindowChromeWatermarkExitPoint")) { if ($windowChromeRaw -notlike "*$required*") { throw "WindowChrome.ps1 missing required marker: $required" } }
    $toggleRaw = Get-Content -LiteralPath $toggleButton -Encoding UTF8 -Raw
    foreach ($required in @("function Ensure-WatermarkToggleButton", "function Update-WatermarkToggleButton", "function Test-WatermarkTogglePoint", "function Test-WatermarkToggleDragActive", "Show-WatermarkMenu", "Toggle-WatermarkMode", "Set-WindowChromeClickThrough")) { if ($toggleRaw -notlike "*$required*") { throw "WatermarkToggleButton.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $mode @("function Ensure-WatermarkToggleButton", "function Update-WatermarkToggleButton", "function Test-WatermarkTogglePoint", "New-Button `"~`"", "Add_MouseDown", "Add_MouseMove", "Add_MouseUp", "`$script:WatermarkToggleDragActive") "WatermarkMode.ps1 must keep toggle-button chrome in WatermarkToggleButton.ps1."
    foreach ($watermarkChromeConsumer in @($mode, $runtime)) { Test-FileDoesNotContain $watermarkChromeConsumer @('$script:Form.Opacity', '$script:Form.TopMost', '$script:Form.WatermarkMode', '$script:Form.WatermarkExitSize', '$script:Form.SetClickThrough', '$script:Form.ClickThroughEnabled') "$([System.IO.Path]::GetFileName($watermarkChromeConsumer)) must use WindowChrome.ps1 for host-window chrome writes." }
    foreach ($watermarkLifecycleFile in @($mode, $runtime)) { Test-FileDoesNotContain $watermarkLifecycleFile @("Start-TranslationRuntime", "Stop-TranslationRuntime", "Test-TranslationRuntimeActive", "Test-TranslationRuntimeTimerCreated") "$([System.IO.Path]::GetFileName($watermarkLifecycleFile)) must not own translation runtime lifecycle." }
    Test-FileDoesNotContain $toggleButton @("function Enter-WatermarkMode", "function Exit-WatermarkMode", "function Restore-WatermarkPreviousLayout", "function Set-WatermarkDefaultTaskView", "Resize-WindowForTaskRows", "Set-BottomChromeVisible", "Apply-WatermarkGhostSurface", "Restore-WatermarkGhostSurface", "WatermarkPreviousWindowWidth", "WatermarkPreviousWindowHeight", "WatermarkPreviousWindowLocation") "WatermarkToggleButton.ps1 must not own watermark layout lifecycle."
    Test-FileDoesNotContain $toggleButton @('$script:Form.SetClickThrough', '$script:Form.ClickThroughEnabled') "WatermarkToggleButton.ps1 must route click-through chrome through WindowChrome.ps1."
    $directRuntimeOps = @("Enter-WatermarkMode", "Exit-WatermarkMode", "Toggle-WatermarkMode", "Update-WatermarkClickThrough", "Update-WatermarkToggleButton", "Get-WatermarkModeOpacity", '$script:WatermarkMode')
    foreach ($fileName in $externalFiles) { Test-FileDoesNotContain (Join-Path $ModulesDir $fileName) $directRuntimeOps "$fileName must use WatermarkRuntime.ps1 instead of WatermarkMode implementation details." }
    "Watermark runtime access is routed through WatermarkRuntime.ps1 and WindowChrome.ps1"
}