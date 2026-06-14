# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Load-Tasks {
    $tasksFile = Get-AppPath "TasksFile"
    if (-not (Test-Path -LiteralPath $tasksFile)) {
        $script:Tasks = @()
        Save-Tasks
        return
    }

    try {
        $raw = Get-Content -LiteralPath $tasksFile -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $script:Tasks = @()
            return
        }
        $data = $raw | ConvertFrom-Json
        if ($null -eq $data) {
            $script:Tasks = @()
        }
        elseif ($data -is [array]) {
            $script:Tasks = @($data)
        }
        else {
            $script:Tasks = @($data)
        }

        $migrated = $false
        foreach ($task in $script:Tasks) {
            $beforeDefaults = $task | ConvertTo-Json -Depth 8 -Compress
            Ensure-TaskDefaults $task
            $afterDefaults = $task | ConvertTo-Json -Depth 8 -Compress
            if ($beforeDefaults -ne $afterDefaults) {
                $migrated = $true
            }
        }
        if ($migrated) {
            Save-Tasks
        }
    }
    catch {
        Backup-DataFile $tasksFile "invalid"
        $script:Tasks = @()
        Save-Tasks
    }
}

function Save-Tasks {
    Write-JsonAtomic (Get-AppPath "TasksFile") @($script:Tasks)
}
