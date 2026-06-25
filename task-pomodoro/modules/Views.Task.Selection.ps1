# This file is dot-sourced before task list views. Keep list hit-testing separate from menu policy.

function Select-ListItemAtPoint([System.Windows.Forms.ListBox]$List, [int]$X, [int]$Y) {
    $index = $List.IndexFromPoint($X, $Y)
    $point = New-Object System.Drawing.Point -ArgumentList @($X, $Y)
    if ($index -lt 0 -or $index -ge $List.Items.Count -or -not ($List.GetItemRectangle($index).Contains($point))) {
        $List.ClearSelected()
        Hide-TaskTitlePreview
        return $null
    }
    $item = $List.Items[$index]
    if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.Id)) {
        $List.ClearSelected()
        Hide-TaskTitlePreview
        return $null
    }
    $List.SelectedIndex = $index
    return $item
}

function Clear-TaskSelection {
    if ($null -ne $script:TaskListBox -and -not $script:TaskListBox.IsDisposed) {
        $script:TaskListBox.ClearSelected()
    }
    Hide-TaskTitlePreview
}
