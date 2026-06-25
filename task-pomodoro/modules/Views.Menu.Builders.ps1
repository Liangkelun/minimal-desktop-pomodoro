# This file is dot-sourced before task menus. Keep generic WinForms menu construction here.

function Add-MenuEntry([object]$Menu, [System.Windows.Forms.ToolStripItem]$Item) {
    if ($Menu -is [System.Windows.Forms.ToolStripMenuItem]) {
        $Menu.DropDownItems.Add($Item) | Out-Null
    }
    else {
        $Menu.Items.Add($Item) | Out-Null
    }
}

function Add-MenuItem([object]$Menu, [string]$Text, [string]$TaskId, [scriptblock]$Action) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    $item.Tag = $TaskId
    $item.Add_Click($Action)
    Add-MenuEntry $Menu $item
}

function Add-SubMenu([object]$Menu, [string]$Text) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    Add-MenuEntry $Menu $item
    return $item
}
