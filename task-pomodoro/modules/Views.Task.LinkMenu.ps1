# This file is dot-sourced before task menus. Keep task-link menu actions separate from menu policy.

function Add-OpenTaskLinkMenuItem([object]$Menu, [string]$TaskId) {
    $taskIdForClick = [string]$TaskId
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = T "OpenTaskLink"
    $item.Tag = $taskIdForClick
    $item.Add_Click({ param($sender, $eventArgs) Open-TaskLink ([string]$sender.Tag) })
    Add-MenuEntry $Menu $item
}
