# This file is dot-sourced by Invoke-AutomatedChecks.ps1. Keep it free of project-specific check sequencing.

function Add-CheckResult([string]$Name, [string]$Status, [string]$Details) {
    $result = [pscustomobject]@{
        name = $Name
        status = $Status
        details = $Details
    }
    $script:Results.Add($result) | Out-Null

    $prefix = "[$Status]"
    if ($Status -eq "PASS") {
        Write-Host "$prefix $Name" -ForegroundColor Green
    }
    elseif ($Status -eq "WARN") {
        Write-Host "$prefix $Name" -ForegroundColor Yellow
        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host $Details -ForegroundColor Yellow
        }
    }
    elseif ($Status -eq "SKIP") {
        Write-Host "$prefix $Name" -ForegroundColor Yellow
    }
    else {
        Write-Host "$prefix $Name" -ForegroundColor Red
        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host $Details -ForegroundColor Red
        }
    }
}

function Invoke-Check([string]$Name, [scriptblock]$Action) {
    try {
        $details = & $Action
        if ($null -eq $details) {
            $details = ""
        }
        Add-CheckResult $Name "PASS" ([string](@($details) -join "`n"))
    }
    catch {
        $script:HasFailure = $true
        Add-CheckResult $Name "FAIL" $_.Exception.Message
    }
}

function Test-PowerShellFile([string]$Path) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($null -ne $errors -and $errors.Count -gt 0) {
        $items = @($errors | Select-Object -First 8 | ForEach-Object {
            "$($_.Extent.StartLineNumber): $($_.Message)"
        })
        throw ($items -join "`n")
    }
}

function Read-JsonFile([string]$Path) {
    $raw = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    return ($raw | ConvertFrom-Json)
}

function Assert-Property([object]$Object, [string]$Name, [string]$Context) {
    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
        throw "$Context missing required property '$Name'"
    }
}

function Test-RequiredFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required file: $Path"
    }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 0) {
        throw "Required file is empty: $Path"
    }
}

function Test-FileDoesNotContain([string]$Path, [string[]]$Patterns, [string]$Reason) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing file for architecture rule: $Path"
    }
    $matches = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        $found = @(Select-String -LiteralPath $Path -Pattern $pattern -SimpleMatch)
        foreach ($item in $found) {
            $matches.Add("$($item.LineNumber): $pattern") | Out-Null
        }
    }
    if ($matches.Count -gt 0) {
        throw "$Reason`n$($matches -join "`n")"
    }
}

function Test-MaxLineCount([string]$Path, [int]$MaxLines) {
    $lineCount = @(Get-Content -LiteralPath $Path).Count
    if ($lineCount -gt $MaxLines) {
        throw "$([System.IO.Path]::GetFileName($Path)) has $lineCount lines; max is $MaxLines"
    }
    return "$([System.IO.Path]::GetFileName($Path)) lines=$lineCount max=$MaxLines"
}

function Test-SoftMaxLineCount([string]$Path, [int]$MaxLines) {
    $lineCount = @(Get-Content -LiteralPath $Path).Count
    $fileName = [System.IO.Path]::GetFileName($Path)
    if ($lineCount -gt $MaxLines) {
        $message = "$fileName lines=$lineCount soft-max=$MaxLines"
        Add-CheckResult "File size soft guardrail" "WARN" $message
        return "$message WARN"
    }
    return "$fileName lines=$lineCount soft-max=$MaxLines"
}
