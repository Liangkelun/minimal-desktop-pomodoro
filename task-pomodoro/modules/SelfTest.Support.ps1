# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Restore-SelfTestFileContent([string]$Path, [string]$Content) {
    Invoke-WithNamedMutex (Get-AppScopedMutexName "data") {
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8 -NoNewline
    }
}

function Remove-SelfTestBackupArtifacts([datetime]$StartedAt) {
    $backupDir = Get-AppPath "BackupDir"
    if (-not (Test-Path -LiteralPath $backupDir -PathType Container)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $backupDir -File -Filter "tasks.json.*.bak" -ErrorAction SilentlyContinue) {
        if (Select-String -LiteralPath $file.FullName -Pattern "__selftest" -SimpleMatch -Quiet -ErrorAction SilentlyContinue) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-SelfTestPomodoroAction([object]$Result) {
    Invoke-AppResultEvents $Result
    return $Result
}