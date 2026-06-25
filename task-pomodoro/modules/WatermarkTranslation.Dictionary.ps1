# This file is dot-sourced before WatermarkTranslation.ps1. Keep legacy dictionary names as compatibility wrappers only.

function Get-WatermarkTranslationBuiltinDictionaryPath { return Get-TranslationBuiltinDictionaryPath }
function Get-WatermarkTranslationUserDictionaryPath { return Get-TranslationUserDictionaryPath }
function Add-WatermarkTranslationDictionaryFile([string]$Path) { Add-TranslationDictionaryFile $Path }
function Load-WatermarkTranslationDictionary { Load-TranslationDictionary }
function Get-WatermarkTranslationLookupCandidates([string]$Text) { return Get-TranslationLookupCandidates $Text }
function Get-WatermarkTranslationLocalResult([string]$Text) { return Get-TranslationLocalResult $Text }