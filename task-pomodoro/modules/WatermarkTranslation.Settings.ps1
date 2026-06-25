# This file is dot-sourced after TranslationSettings.ps1. Keep historical translation settings names as compatibility wrappers only.

function Show-WatermarkTranslationSettingsDialog { Show-TranslationSettingsDialog }
function Apply-WatermarkTranslationSettingsControls([object]$Controls, [bool]$UpdateRuntime = $true) { Apply-TranslationSettingsControls $Controls $UpdateRuntime }
function Test-WatermarkTranslationConnection { return Test-TranslationConnection }
function Show-WatermarkTranslationDictionaryImportDialog { Show-TranslationDictionaryImportDialog }