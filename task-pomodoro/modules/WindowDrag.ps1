# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Start-WindowDrag {
    $script:WindowDragStart = [System.Windows.Forms.Cursor]::Position
    $script:WindowDragOrigin = Get-WindowRuntimeLocation
}

function Move-WindowDrag {
    if ($null -eq $script:WindowDragStart -or $null -eq $script:WindowDragOrigin) {
        return
    }
    $current = [System.Windows.Forms.Cursor]::Position
    $newX = [int]([int]$script:WindowDragOrigin.X + [int]$current.X - [int]$script:WindowDragStart.X)
    $newY = [int]([int]$script:WindowDragOrigin.Y + [int]$current.Y - [int]$script:WindowDragStart.Y)
    Set-WindowRuntimeLocation (New-Object System.Drawing.Point -ArgumentList @($newX, $newY))
}

function Stop-WindowDrag {
    $script:WindowDragStart = $null
    $script:WindowDragOrigin = $null
}

function Add-WindowDrag([System.Windows.Forms.Control]$Control) {
    $Control.Add_MouseDown({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Start-WindowDrag
        }
    })
    $Control.Add_MouseMove({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Move-WindowDrag
        }
    })
    $Control.Add_MouseUp({
        Stop-WindowDrag
    })
}
