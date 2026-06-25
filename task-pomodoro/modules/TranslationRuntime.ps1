# This file is dot-sourced by TaskPomodoro.ps1. It owns translation runtime lifecycle and resources.

function Get-TranslationRuntimeTimer { return Get-Variable -Name TranslationRuntimeTimer -Scope Script -ValueOnly -ErrorAction SilentlyContinue }
function Test-TranslationRuntimeActive { return [bool](Get-Variable -Name TranslationRuntimeActive -Scope Script -ValueOnly -ErrorAction SilentlyContinue) }
function Test-TranslationRuntimeTimerCreated { return ($null -ne (Get-TranslationRuntimeTimer)) }
function Test-TranslationRuntimeTimerEnabled { $timer = Get-TranslationRuntimeTimer; return ($null -ne $timer -and $timer.Enabled) }
function Test-TranslationMemorySavingMode { return ([string]$script:Settings.TranslationPerformanceMode -eq "memory") }

function Ensure-TranslationRuntimeTimer {
    if (Test-TranslationRuntimeTimerCreated) { return }
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 300
    $timer.Add_Tick({ if (Test-TranslationRuntimeActive) { if (Test-TranslationUiaSelectionEnabled) { Update-TranslationSelectionBridge }; Update-TranslationSurfaceAutoHide } })
    $script:TranslationRuntimeTimer = $timer
}

function Start-TranslationRuntime {
    if ($null -eq $script:Form) { return }
    Ensure-TranslationRuntimeTimer
    $script:TranslationRuntimeActive = $true
    Reset-TranslationWorkflowState
    Register-TranslationNotificationHandlers
    $timer = Get-TranslationRuntimeTimer
    if ($null -ne $timer -and -not $timer.Enabled) { $timer.Start() }
    Start-TranslationClipboardListener { param($text) Show-TranslationText $text ([System.Drawing.Rectangle]::Empty) "clipboard" }
    Set-Status (T "TranslationModeOn")
}

function Stop-TranslationRuntime {
    $script:TranslationRuntimeActive = $false
    $timer = Get-TranslationRuntimeTimer
    if ($null -ne $timer) { $timer.Stop(); $timer.Dispose(); $script:TranslationRuntimeTimer = $null }
    Stop-TranslationClipboardListener $true
    Hide-TranslationSurfaces
    Clear-TranslationNotificationHandlers
    Dispose-TranslationSurfaces
    if (Test-TranslationMemorySavingMode) { Clear-TranslationDictionaryCache; Clear-TranslationLookupCache }
    Reset-TranslationWorkflowState
}

function Start-TranslationRuntimeClipboardListener { Start-TranslationClipboardListener }
function Stop-TranslationRuntimeClipboardListener { Stop-TranslationClipboardListener }

function Suspend-TranslationRuntimeForSettings {
    $timer = Get-TranslationRuntimeTimer
    if ($null -ne $timer -and $timer.Enabled) { $timer.Stop() }
    Stop-TranslationRuntimeClipboardListener
}

function Resume-TranslationRuntimeAfterSettings {
    if (-not (Test-TranslationRuntimeActive)) { return }
    $timer = Get-TranslationRuntimeTimer
    if ($null -ne $timer -and -not $timer.Enabled) { $timer.Start() }
    Start-TranslationRuntimeClipboardListener
}

function Update-TranslationRuntimeAfterSettingsChanged {
    if (-not (Test-TranslationRuntimeActive)) { return }
    Start-TranslationRuntimeClipboardListener
}