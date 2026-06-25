# This file is dot-sourced by TaskPomodoro.ps1. It owns online translation provider adapters and usage accounting.

function Test-TranslationProviderEnabled { return ([string]$script:Settings.TranslationProvider -in @("custom", "deepl", "baidu")) }
function Get-TranslationMonthKey { return (Get-Date).ToString("yyyy-MM") }

function Add-TranslationCharacterUsage([int]$Count) {
    $month = Get-TranslationMonthKey
    if ([string]$script:Settings.TranslationMonthKey -ne $month) { $script:Settings.TranslationMonthKey = $month; $script:Settings.TranslationMonthChars = 0 }
    $script:Settings.TranslationMonthChars = [int]$script:Settings.TranslationMonthChars + [Math]::Max(0, $Count)
    try { Save-TranslationRuntimeSettings } catch {}
}

function Test-TranslationCharacterBudget([string]$Text) {
    $month = Get-TranslationMonthKey
    if ([string]$script:Settings.TranslationMonthKey -ne $month) { return $true }
    return (([int]$script:Settings.TranslationMonthChars + $Text.Length) -le [int]$script:Settings.TranslationMonthlyLimit)
}

function Get-Md5Hex([string]$Text) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { return (($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text)) | ForEach-Object { $_.ToString("x2") }) -join "") }
    finally { $md5.Dispose() }
}

function Invoke-TranslationProviderApi([string]$Text) {
    if (-not (Test-TranslationProviderEnabled) -or -not (Test-TranslationCharacterBudget $Text)) { return $null }
    $provider = [string]$script:Settings.TranslationProvider
    $target = [string]$script:Settings.TranslationTargetLanguage
    $script:Settings.TranslationLastError = ""
    try {
        if ($provider -eq "custom") {
            $endpoint = [string]$script:Settings.TranslationCustomEndpoint
            if ([string]::IsNullOrWhiteSpace($endpoint)) { return $null }
            $headers = @{}
            $key = Unprotect-TranslationSecret ([string]$script:Settings.TranslationCustomApiKeyProtected)
            if (-not [string]::IsNullOrWhiteSpace($key)) { $headers["X-API-Key"] = $key }
            $body = @{ text = $Text; source = "auto"; target = $target } | ConvertTo-Json -Compress
            $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -Headers $headers -ContentType "application/json; charset=utf-8" -TimeoutSec 5
            if ($null -ne $response -and ($response.PSObject.Properties.Name -contains "translation")) { Add-TranslationCharacterUsage $Text.Length; return [string]$response.translation }
        }
        elseif ($provider -eq "deepl") {
            $key = Unprotect-TranslationSecret ([string]$script:Settings.TranslationDeepLApiKeyProtected)
            if ([string]::IsNullOrWhiteSpace($key)) { return $null }
            $endpoint = if ([string]$script:Settings.TranslationDeepLMode -eq "pro") { "https://api.deepl.com/v2/translate" } else { "https://api-free.deepl.com/v2/translate" }
            $deeplTarget = if ($target -eq "zh") { "ZH" } else { $target.ToUpperInvariant() }
            $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body @{ auth_key = $key; text = $Text; target_lang = $deeplTarget } -TimeoutSec 5
            if ($null -ne $response.translations -and $response.translations.Count -gt 0) { Add-TranslationCharacterUsage $Text.Length; return [string]$response.translations[0].text }
        }
        elseif ($provider -eq "baidu") {
            $appId = [string]$script:Settings.TranslationBaiduAppId
            $secret = Unprotect-TranslationSecret ([string]$script:Settings.TranslationBaiduSecretProtected)
            if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($secret)) { return $null }
            $salt = [string][int][double]((Get-Date).ToUniversalTime() - [datetime]"1970-01-01").TotalSeconds
            $sign = Get-Md5Hex ($appId + $Text + $salt + $secret)
            $response = Invoke-RestMethod -Uri "https://fanyi-api.baidu.com/api/trans/vip/translate" -Method Post -Body @{ q = $Text; from = "auto"; to = $target; appid = $appId; salt = $salt; sign = $sign } -TimeoutSec 5
            if ($null -ne $response.trans_result -and $response.trans_result.Count -gt 0) { Add-TranslationCharacterUsage $Text.Length; return [string]$response.trans_result[0].dst }
        }
    }
    catch { $script:Settings.TranslationLastError = $_.Exception.Message; return $null }
    return $null
}
