# This file is dot-sourced by TaskPomodoro.ps1. Keep historical translation names as compatibility wrappers only.

function Clear-WatermarkTranslationNotificationHandlers { Clear-TranslationNotificationHandlers }
function Register-WatermarkTranslationNotificationHandlers { Register-TranslationNotificationHandlers }
function Show-WatermarkTranslationText([string]$Text, [System.Drawing.Rectangle]$Rect, [string]$Source) { Show-TranslationText $Text $Rect $Source }
function Update-WatermarkTranslationSelection { if (Test-TranslationRuntimeActive) { Update-TranslationSelectionBridge } }
function Start-WatermarkTranslationMode { Start-TranslationRuntime }
function Stop-WatermarkTranslationMode { Stop-TranslationRuntime }