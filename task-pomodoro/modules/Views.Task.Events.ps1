# This file is dot-sourced before task list views. Keep task list event registration separate from interaction policy.

function Register-TaskListEventHandlers([System.Windows.Forms.ListBox]$List) {
    if ($null -eq $List -or $List.IsDisposed) { return }
    $List.Add_MouseDown({ param($sender, $eventArgs) Invoke-TaskListMouseDown $sender $eventArgs })
    $List.Add_SelectedIndexChanged({ param($sender, $eventArgs) Invoke-TaskListSelectedIndexChanged $sender })
    $List.Add_MouseMove({ param($sender, $eventArgs) Invoke-TaskListMouseMove $sender $eventArgs })
    $List.Add_MouseUp({ param($sender, $eventArgs) Invoke-TaskListMouseUp $sender })
    $List.Add_DragOver({ param($sender, $eventArgs) Invoke-TaskListDragOver $eventArgs })
    $List.Add_DragDrop({ param($sender, $eventArgs) Invoke-TaskListDragDrop $sender $eventArgs })
    $List.Add_MouseDoubleClick({ param($sender, $eventArgs) Invoke-TaskListMouseDoubleClick $sender $eventArgs })
}