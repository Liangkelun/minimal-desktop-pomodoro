param(
    [Parameter(Mandatory = $true)][string]$EcDictCsv,
    [string]$OutputPath = "",
    [int]$MaxWords = -1,
    [switch]$Full,
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $root "assets\dict\watermark-translation-core.tsv"
}

if (-not (Test-Path -LiteralPath $EcDictCsv -PathType Leaf)) {
    throw "ECDICT csv not found: $EcDictCsv"
}

$builder = Join-Path $root "scripts\Build-TranslationDictionary.py"
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
    throw "Dictionary builder not found: $builder"
}

$effectiveMaxWords = $MaxWords
if ($effectiveMaxWords -lt 0) { $effectiveMaxWords = if ($Full) { 0 } else { 50000 } }
$args = @($builder, "--ecdict-csv", $EcDictCsv, "--output", $OutputPath, "--max-words", $effectiveMaxWords)
if ($Full) { $args += "--include-all" }
& $Python @args
if ($LASTEXITCODE -ne 0) {
    throw "Dictionary builder failed with exit code $LASTEXITCODE"
}