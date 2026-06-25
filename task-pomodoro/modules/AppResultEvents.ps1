# This file is dot-sourced by TaskPomodoro.ps1. It owns neutral result-event helpers, not event side effects.

function New-AppEvent([string]$Type, [hashtable]$Data = @{}) {
    $event = [ordered]@{ Type = $Type }
    foreach ($entry in $Data.GetEnumerator()) {
        $event[$entry.Key] = $entry.Value
    }
    return [pscustomobject]$event
}

function Add-AppResultEvents([object]$Result, [object[]]$Events) {
    if ($null -eq $Result) { return $Result }
    $existing = @()
    if ($Result.PSObject.Properties.Name -contains "Events") {
        $existing = @($Result.Events)
    }
    Add-Member -InputObject $Result -MemberType NoteProperty -Name Events -Value (@($Events) + $existing) -Force
    return $Result
}

function Invoke-AppResultEvents([object]$Result) {
    if ($null -eq $Result -or -not ($Result.PSObject.Properties.Name -contains "Events")) { return }
    foreach ($event in @($Result.Events)) {
        if ($null -eq $event -or -not ($event.PSObject.Properties.Name -contains "Type")) { continue }
        Invoke-AppResultEvent $event
    }
}