# This file is dot-sourced before task list interactions. Keep low-level click and drag mechanics out of interaction policy.

function Get-TaskListSelectedItemId([System.Windows.Forms.ListBox]$List) {
    if ($null -ne $List -and $null -ne $List.SelectedItem) {
        return [string]$List.SelectedItem.Id
    }
    return ""
}

function Test-TaskListClickWithinDoubleArea([System.Windows.Forms.MouseEventArgs]$EventArgs, [System.Drawing.Point]$LastPoint) {
    $doubleSize = [System.Windows.Forms.SystemInformation]::DoubleClickSize
    return ([Math]::Abs([int]$EventArgs.X - [int]$LastPoint.X) -le [Math]::Ceiling([double]$doubleSize.Width / 2.0) -and [Math]::Abs([int]$EventArgs.Y - [int]$LastPoint.Y) -le [Math]::Ceiling([double]$doubleSize.Height / 2.0))
}

function Get-TaskListClickGesture([object]$Tag, [object]$Item, [System.Windows.Forms.MouseEventArgs]$EventArgs) {
    $now = Get-Date
    $elapsed = ($now - [DateTime]$Tag.LastClickAt).TotalMilliseconds
    $sameLastClick = ([string]$Tag.LastClickId -eq [string]$Item.Id)
    $withinDoubleTime = ($elapsed -ge 0 -and $elapsed -le [System.Windows.Forms.SystemInformation]::DoubleClickTime)
    $withinDoubleArea = Test-TaskListClickWithinDoubleArea $EventArgs ([System.Drawing.Point]$Tag.LastClickPoint)
    return [pscustomobject]@{
        Now = $now
        IsDoubleClick = ($EventArgs.Clicks -ge 2 -or ($sameLastClick -and $withinDoubleTime -and $withinDoubleArea))
        RenameCandidate = ($sameLastClick -and $elapsed -gt [System.Windows.Forms.SystemInformation]::DoubleClickTime -and $elapsed -le 2000 -and $withinDoubleArea)
    }
}

function Set-TaskListLastClickState([object]$Tag, [object]$Item, [System.Windows.Forms.MouseEventArgs]$EventArgs, [DateTime]$At) {
    $Tag.LastClickId = [string]$Item.Id
    $Tag.LastClickAt = $At
    $Tag.LastClickPoint = New-Object System.Drawing.Point -ArgumentList @([int]$EventArgs.X, [int]$EventArgs.Y)
}

function Test-TaskListDragStartReady([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.MouseEventArgs]$EventArgs) {
    return ($null -ne $List -and -not $List.IsDisposed -and $null -ne $List.Tag -and $EventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -and -not [string]::IsNullOrWhiteSpace([string]$List.Tag.DragId))
}

function Test-TaskListDragThresholdExceeded([object]$Tag, [System.Windows.Forms.MouseEventArgs]$EventArgs) {
    $deltaX = [Math]::Abs($EventArgs.X - $Tag.DragStart.X)
    $deltaY = [Math]::Abs($EventArgs.Y - $Tag.DragStart.Y)
    return ($deltaX -ge 4 -or $deltaY -ge 4)
}

function Start-TaskListItemDrag([System.Windows.Forms.ListBox]$List) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $List.Tag) { return }
    $List.DoDragDrop([string]$List.Tag.DragId, [System.Windows.Forms.DragDropEffects]::Move) | Out-Null
    $List.Tag.DragId = ""
}

function Test-TaskListDragDataPresent([System.Windows.Forms.DragEventArgs]$EventArgs) {
    return ($null -ne $EventArgs -and $EventArgs.Data.GetDataPresent([string]))
}

function Get-TaskListDragSourceId([System.Windows.Forms.DragEventArgs]$EventArgs) {
    if (-not (Test-TaskListDragDataPresent $EventArgs)) { return "" }
    return [string]$EventArgs.Data.GetData([string])
}

function Get-TaskListDropTargetIndex([System.Windows.Forms.ListBox]$List, [System.Windows.Forms.DragEventArgs]$EventArgs) {
    $point = $List.PointToClient((New-Object System.Drawing.Point -ArgumentList @([int]$EventArgs.X, [int]$EventArgs.Y)))
    return $List.IndexFromPoint($point)
}
