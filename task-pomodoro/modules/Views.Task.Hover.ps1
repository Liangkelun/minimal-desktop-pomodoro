# This file is dot-sourced by TaskPomodoro.ps1. Keep functions side-effect-light at load time.

function Get-TaskListTagValue([System.Windows.Forms.ListBox]$List, [string]$Name, [object]$Default) {
    if ($null -ne $List -and $null -ne $List.Tag -and ($List.Tag.PSObject.Properties.Name -contains $Name)) {
        return $List.Tag.PSObject.Properties[$Name].Value
    }
    return $Default
}

function Set-TaskListTagValue([System.Windows.Forms.ListBox]$List, [string]$Name, [object]$Value) {
    if ($null -eq $List -or $null -eq $List.Tag) { return }
    Add-Member -InputObject $List.Tag -MemberType NoteProperty -Name $Name -Value $Value -Force
}

function Update-TaskListHoverState([System.Windows.Forms.ListBox]$List, [int]$X, [int]$Y) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $List.Tag) { return }
    $hoverIndex = -1
    $hoverCheckbox = $false
    $hoverTopDragBand = $false
    $point = New-Object System.Drawing.Point -ArgumentList @($X, $Y)
    $candidateIndex = $List.IndexFromPoint($point)
    if ($candidateIndex -ge 0 -and $candidateIndex -lt $List.Items.Count) {
        $itemBounds = $List.GetItemRectangle($candidateIndex)
        if ($itemBounds.Contains($point)) {
            $hoverIndex = [int]$candidateIndex
            $hoverTopDragBand = Test-TaskTopDragBand $Y
            $hoverCheckbox = ((Test-TaskCheckboxPoint $List $X) -and -not $hoverTopDragBand)
        }
    }
    $oldIndex = [int](Get-TaskListTagValue $List "HoverIndex" -1)
    $oldCheckbox = [bool](Get-TaskListTagValue $List "HoverCheckbox" $false)
    $oldTopDragBand = [bool](Get-TaskListTagValue $List "HoverTopDragBand" $false)
    if ($oldIndex -eq $hoverIndex -and $oldCheckbox -eq $hoverCheckbox -and $oldTopDragBand -eq $hoverTopDragBand) { return }
    Set-TaskListTagValue $List "HoverIndex" $hoverIndex
    Set-TaskListTagValue $List "HoverCheckbox" $hoverCheckbox
    Set-TaskListTagValue $List "HoverTopDragBand" $hoverTopDragBand
    $List.Invalidate()
}

function Clear-TaskListHoverState([System.Windows.Forms.ListBox]$List) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $List.Tag) { return }
    $oldIndex = [int](Get-TaskListTagValue $List "HoverIndex" -1)
    $oldCheckbox = [bool](Get-TaskListTagValue $List "HoverCheckbox" $false)
    $oldTopDragBand = [bool](Get-TaskListTagValue $List "HoverTopDragBand" $false)
    if ($oldIndex -eq -1 -and -not $oldCheckbox -and -not $oldTopDragBand) { return }
    Set-TaskListTagValue $List "HoverIndex" -1
    Set-TaskListTagValue $List "HoverCheckbox" $false
    Set-TaskListTagValue $List "HoverTopDragBand" $false
    $List.Invalidate()
}

function Test-TaskFirstRowBlankDragPoint([System.Windows.Forms.ListBox]$List, [int]$X, [int]$Y) {
    if ($null -eq $List -or $List.IsDisposed) { return $false }
    if ((Get-TaskListMode $List) -notin @("tasks", "today") -or (Test-TaskTopDragBand $Y) -or (Test-TaskCheckboxPoint $List $X)) { return $false }
    $point = New-Object System.Drawing.Point -ArgumentList @($X, $Y)
    if ($List.IndexFromPoint($point) -ne 0) { return $false }
    $bounds = $List.GetItemRectangle(0)
    if (-not $bounds.Contains($point) -or $X -ge ([int]$List.ClientSize.Width - 68)) { return $false }
    $item = $List.Items[0]
    if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.Id)) { return $false }
    $textSize = [System.Windows.Forms.TextRenderer]::MeasureText([string]$item.Display, $List.Font, (New-Object System.Drawing.Size -ArgumentList @(10000, $bounds.Height)), [System.Windows.Forms.TextFormatFlags]::NoPadding)
    return ($X -gt ([int]$bounds.X + 4 + [int]$textSize.Width + 8))
}

function Start-TaskListWindowDrag([System.Windows.Forms.ListBox]$List) {
    if ($null -eq $List -or $List.IsDisposed -or $null -eq $List.Tag) { return }
    $List.Tag.DragId = ""
    $List.Tag.WindowDrag = $true
    Reset-TaskListClickState $List.Tag
    Clear-TaskSelection
    Start-WindowDrag
}
