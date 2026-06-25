# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for window-state boundary assertions.

function Invoke-WindowStateBoundaryCheck([string]$ModulesDir) {
    $coordinatorModule = Join-Path $ModulesDir "WindowStateCoordinator.ps1"
    $settingsStoreModule = Join-Path $ModulesDir "SettingsStore.ps1"
    $watermarkModeModule = Join-Path $ModulesDir "WatermarkMode.ps1"
    $watermarkRuntimeModule = Join-Path $ModulesDir "WatermarkRuntime.ps1"
    $watermarkGhostModule = Join-Path $ModulesDir "WatermarkGhostSurface.ps1"; $windowDragModule = Join-Path $ModulesDir "WindowDrag.ps1"; $windowSizeModule = Join-Path $ModulesDir "WindowSize.ps1"; $windowPlacementModule = Join-Path $ModulesDir "WindowPlacement.ps1"; $settingsApplyModule = Join-Path $ModulesDir "Views.Settings.Apply.ps1"
    foreach ($requiredFile in @($coordinatorModule, $settingsStoreModule, $watermarkModeModule, $watermarkRuntimeModule, $watermarkGhostModule, $windowDragModule, $windowSizeModule, $windowPlacementModule, $settingsApplyModule)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1")
    $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("SettingsSchema.ps1", "WindowStateCoordinator.ps1", "SettingsStore.ps1", "WindowDrag.ps1", "WindowPlacement.ps1", "WindowSize.ps1", "WatermarkMode.ps1", "WatermarkRuntime.ps1", "WatermarkGhostSurface.ps1", "WindowChrome.ps1", "Views.Settings.Apply.ps1")) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    if ([Array]::IndexOf($loadOrder, "WindowStateCoordinator.ps1") -gt [Array]::IndexOf($loadOrder, "SettingsStore.ps1")) { throw "WindowStateCoordinator.ps1 must load before SettingsStore.ps1" }
    if ([Array]::IndexOf($loadOrder, "SettingsSchema.ps1") -gt [Array]::IndexOf($loadOrder, "WindowStateCoordinator.ps1")) { throw "SettingsSchema.ps1 must load before WindowStateCoordinator.ps1" }
    foreach ($windowConsumer in @("WindowDrag.ps1", "WindowPlacement.ps1", "WindowSize.ps1")) { if ([Array]::IndexOf($loadOrder, "WindowStateCoordinator.ps1") -gt [Array]::IndexOf($loadOrder, $windowConsumer)) { throw "WindowStateCoordinator.ps1 must load before $windowConsumer" } }
    if ([Array]::IndexOf($loadOrder, "WindowChrome.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Settings.Apply.ps1")) { throw "WindowChrome.ps1 must load before Views.Settings.Apply.ps1" }

    $coordinatorRaw = Get-Content -LiteralPath $coordinatorModule -Encoding UTF8 -Raw
    foreach ($required in @("function Get-WindowStateSnapshotForSettings", "function Sync-SettingsWindowStateFromRuntime", "function Apply-SettingsWindowChromeFromSettings", "function Save-WatermarkPreviousLayoutSnapshot", "function Get-WatermarkPreviousLayoutSnapshot", "function Restore-WatermarkPreviousLayout", "function Restore-WatermarkPreviousWindowChrome", "function Clear-WatermarkPreviousLayoutSnapshot", "function Set-WatermarkPreviousOpacity", "function Get-WatermarkPreviousContentBounds", "function Get-WindowRuntimeLocation", "function Set-WindowRuntimeLocation", "function Get-WindowRuntimeSizingSnapshot", "function Ensure-WindowRuntimeHeight", "function Set-WindowRuntimeHeight", "WatermarkPreviousWindowWidth", "WatermarkPreviousOpacity")) { if ($coordinatorRaw -notlike "*$required*") { throw "WindowStateCoordinator.ps1 missing required marker: $required" } }
    $settingsRaw = Get-Content -LiteralPath $settingsStoreModule -Encoding UTF8 -Raw
    foreach ($required in @("Sync-SettingsWindowStateFromRuntime", "Apply-SettingsWindowChromeFromSettings")) { if ($settingsRaw -notlike "*$required*") { throw "SettingsStore.ps1 must delegate through $required." } }
    Test-FileDoesNotContain $settingsStoreModule @("WatermarkPrevious", '$script:Form.') "SettingsStore.ps1 must delegate host window state decisions to WindowStateCoordinator.ps1."
    Test-FileDoesNotContain $watermarkModeModule @('$script:WatermarkPrevious', "function Restore-WatermarkPreviousLayout") "WatermarkMode.ps1 must delegate watermark layout snapshots to WindowStateCoordinator.ps1."
    Test-FileDoesNotContain $watermarkRuntimeModule @('$script:WatermarkPreviousOpacity') "WatermarkRuntime.ps1 must update watermark snapshot opacity through WindowStateCoordinator.ps1."
    Test-FileDoesNotContain $watermarkGhostModule @('$script:WatermarkPreviousContentBounds') "WatermarkGhostSurface.ps1 must read watermark content bounds through WindowStateCoordinator.ps1."
    Test-FileDoesNotContain $windowDragModule @('$script:Form.Location') "WindowDrag.ps1 must move the host window through WindowStateCoordinator.ps1."
    $windowDragRaw = Get-Content -LiteralPath $windowDragModule -Encoding UTF8 -Raw; foreach ($required in @("Get-WindowRuntimeLocation", "Set-WindowRuntimeLocation")) { if ($windowDragRaw -notlike "*$required*") { throw "WindowDrag.ps1 must keep window state facade marker: $required" } }
    Test-FileDoesNotContain $windowSizeModule @('$script:Form.Height', '$script:Form.MinimumSize', '$script:Form.Padding') "WindowSize.ps1 must size the host window through WindowStateCoordinator.ps1."
    $windowSizeRaw = Get-Content -LiteralPath $windowSizeModule -Encoding UTF8 -Raw; foreach ($required in @("Get-WindowRuntimeSizingSnapshot", "Ensure-WindowRuntimeHeight", "Set-WindowRuntimeHeight")) { if ($windowSizeRaw -notlike "*$required*") { throw "WindowSize.ps1 must keep window sizing facade marker: $required" } }
    Test-FileDoesNotContain $windowSizeModule @("Screen]::AllScreens", "PrimaryScreen", "WorkingArea", "function Get-SafeWindowLocation") "WindowSize.ps1 must not own screen placement."
    $placementRaw = Get-Content -LiteralPath $windowPlacementModule -Encoding UTF8 -Raw; foreach ($required in @("function Get-SafeWindowLocation", "Screen]::AllScreens", "PrimaryScreen", "WorkingArea")) { if ($placementRaw -notlike "*$required*") { throw "WindowPlacement.ps1 must keep placement marker: $required" } }; Test-FileDoesNotContain $windowPlacementModule @("Save-Settings", "WindowX", "WindowY", "Watermark", "TranslationRuntime", "Resize-WindowForTaskRows") "WindowPlacement.ps1 must own screen-safe placement only."
    Test-FileDoesNotContain $settingsApplyModule @('$script:Form.TopMost', '$script:Form.Opacity') "Views.Settings.Apply.ps1 must route live host-window chrome through WindowChrome.ps1 or WatermarkRuntime.ps1."
    "Window state persistence decisions are centralized"
}
