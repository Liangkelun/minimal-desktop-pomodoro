# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for task-list and task-menu boundary assertions.

function Get-PowerShellFunctionNames([string]$Path) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($null -ne $errors -and $errors.Count -gt 0) {
        throw "Cannot parse $([System.IO.Path]::GetFileName($Path)) for function ownership checks."
    }
    return @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name })
}
function Invoke-TaskMenuHelperBoundaryCheck([string]$ModulesDir) {
    $selectionModule = Join-Path $ModulesDir "Views.Task.Selection.ps1"
    $interactionsModule = Join-Path $ModulesDir "Views.Task.Interactions.ps1"
    $gesturesModule = Join-Path $ModulesDir "Views.Task.Gestures.ps1"
    $itemsModule = Join-Path $ModulesDir "Views.Task.Items.ps1"
    $eventsModule = Join-Path $ModulesDir "Views.Task.Events.ps1"
    $builderModule = Join-Path $ModulesDir "Views.Menu.Builders.ps1"
    $linkMenuModule = Join-Path $ModulesDir "Views.Task.LinkMenu.ps1"
    $taskMenuActionsModule = Join-Path $ModulesDir "Views.Task.Menu.Actions.ps1"
    $taskMenuModule = Join-Path $ModulesDir "Views.Task.Menu.ps1"
    $doneStatsModule = Join-Path $ModulesDir "Views.Done.Stats.ps1"
    $doneDrawingModule = Join-Path $ModulesDir "Views.Done.Drawing.ps1"
    $doneModule = Join-Path $ModulesDir "Views.Done.ps1"
    $moreModule = Join-Path $ModulesDir "Views.More.ps1"
    foreach ($requiredFile in @($selectionModule, $interactionsModule, $gesturesModule, $itemsModule, $eventsModule, $builderModule, $linkMenuModule, $taskMenuActionsModule, $taskMenuModule, $doneStatsModule, $doneDrawingModule, $doneModule, $moreModule)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1")
    $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("Views.Task.Selection.ps1", "Views.Task.Gestures.ps1", "Views.Task.Interactions.ps1", "Views.Task.Items.ps1", "Views.Task.Events.ps1", "Views.Menu.Builders.ps1", "Views.Task.LinkMenu.ps1", "Views.Task.Menu.Actions.ps1", "Views.Task.Menu.ps1", "Views.Done.Stats.ps1", "Views.Done.Drawing.ps1", "Views.Done.ps1", "Views.More.ps1")) {
        if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" }
    }
    if ([Array]::IndexOf($loadOrder, "Views.Task.Selection.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Task.ps1")) { throw "Views.Task.Selection.ps1 must load before Views.Task.ps1" }
    if ([Array]::IndexOf($loadOrder, "Views.Task.Gestures.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Task.Interactions.ps1")) { throw "Views.Task.Gestures.ps1 must load before Views.Task.Interactions.ps1" }
    foreach ($dependent in @("Views.Task.Hover.ps1", "Views.Task.ps1")) { if ([Array]::IndexOf($loadOrder, "Views.Task.Interactions.ps1") -gt [Array]::IndexOf($loadOrder, $dependent)) { throw "Views.Task.Interactions.ps1 must load before $dependent" } }
    if ([Array]::IndexOf($loadOrder, "Views.Task.Items.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Task.ps1")) { throw "Views.Task.Items.ps1 must load before Views.Task.ps1" }
    foreach ($dependency in @("Views.Task.Selection.ps1", "Views.Task.Interactions.ps1", "Views.Task.Hover.ps1", "Views.Task.Edit.ps1")) { if ([Array]::IndexOf($loadOrder, $dependency) -gt [Array]::IndexOf($loadOrder, "Views.Task.Events.ps1")) { throw "Views.Task.Events.ps1 must load after $dependency" } }
    if ([Array]::IndexOf($loadOrder, "Views.Task.Events.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Task.ps1")) { throw "Views.Task.Events.ps1 must load before Views.Task.ps1" }
    if ([Array]::IndexOf($loadOrder, "Views.Menu.Builders.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Task.LinkMenu.ps1")) { throw "Views.Menu.Builders.ps1 must load before Views.Task.LinkMenu.ps1" }
    if ([Array]::IndexOf($loadOrder, "Views.Task.LinkMenu.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Task.Menu.Actions.ps1")) { throw "Views.Task.LinkMenu.ps1 must load before Views.Task.Menu.Actions.ps1" }
    if ([Array]::IndexOf($loadOrder, "Views.Task.Menu.Actions.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Task.Menu.ps1")) { throw "Views.Task.Menu.Actions.ps1 must load before Views.Task.Menu.ps1" }
    if ([Array]::IndexOf($loadOrder, "Views.Task.LinkMenu.ps1") -gt [Array]::IndexOf($loadOrder, "Views.Done.ps1")) { throw "Views.Task.LinkMenu.ps1 must load before Views.Done.ps1" }
    foreach ($doneDependency in @("Views.Done.Stats.ps1", "Views.Done.Drawing.ps1")) { if ([Array]::IndexOf($loadOrder, $doneDependency) -gt [Array]::IndexOf($loadOrder, "Views.Done.ps1")) { throw "$doneDependency must load before Views.Done.ps1" } }
    if ([Array]::IndexOf($loadOrder, "Views.Done.ps1") -gt [Array]::IndexOf($loadOrder, "Views.More.ps1")) { throw "Views.Done.ps1 must load before Views.More.ps1" }
    $taskViewModule = Join-Path $ModulesDir "Views.Task.ps1"
    Test-FileDoesNotContain $taskViewModule @("function Invoke-TaskListDefaultClickAction", "function Reset-TaskListClickState", "Get-TodayTasks", "Get-OpenTasks", "Format-TaskLine", "NoTodayTasks", "NoOpenTasks", "Add_MouseDown", "Add_SelectedIndexChanged", "Add_MouseMove", "Add_MouseUp", "Add_DragOver", "Add_DragDrop", "Add_MouseDoubleClick") "Views.Task.ps1 must keep list interaction policy, item projection, and event wiring in dedicated task-list modules."
    Test-FileDoesNotContain $itemsModule @("System.Windows.Forms", "ListBox", "TableLayoutPanel", "TextBox", "Invoke-Task", "Add-Task", "Complete-Task", "Start-Pomodoro", "Start-TaskStarter", "Save-Tasks") "Views.Task.Items.ps1 must stay focused on read-only task-list item projection."
    Test-FileDoesNotContain $eventsModule @("function Render-TaskView", "TableLayoutPanel", "New-Object System.Windows.Forms.TextBox", "ContextMenuStrip", "ToolStripMenuItem", "Get-TaskListItemsForView", "Get-TodayTasks", "Get-OpenTasks", "Format-TaskLine", "Add-MenuItem", "Add-SubMenu", "Show-TaskMenu", "Select-ListItemAtPoint", "Test-TaskTopDragBand", "Start-TaskListWindowDrag", "Start-TaskTitleInlineEdit", "Invoke-TaskMoveWorkflow", "Invoke-TaskListDefaultClickAction", "Invoke-TaskToggleCompletionWorkflow", "DoDragDrop", "PointToClient") "Views.Task.Events.ps1 must stay focused on task-list event registration and delegate interaction policy."
    Test-FileDoesNotContain $interactionsModule @("function Render-TaskView", "TableLayoutPanel", "New-Object System.Windows.Forms.TextBox", "ContextMenuStrip", "ToolStripMenuItem", "Get-TaskListItemsForView", "Get-TodayTasks", "Get-OpenTasks", "Format-TaskLine", "Add-MenuItem", "Add-SubMenu", "(Add-Task ", "(Complete-Task ", "(Start-Pomodoro ", "(Start-TaskStarter ", "function Get-TaskListClickGesture", "function Set-TaskListLastClickState", "function Test-TaskListDragThresholdExceeded", "function Start-TaskListItemDrag", "function Get-TaskListDragSourceId", "function Get-TaskListDropTargetIndex", "DoubleClickSize", "DoubleClickTime", "DoDragDrop", "GetDataPresent", "PointToClient", "IndexFromPoint") "Views.Task.Interactions.ps1 must stay focused on high-level list interaction policy and delegate gesture mechanics."
    Test-FileDoesNotContain $gesturesModule @("Show-TaskMenu", "Invoke-TaskOperationResult", "Invoke-TaskMoveWorkflow", "Invoke-TaskToggleCompletionWorkflow", "Start-TaskTitleInlineEdit", "Open-TaskLink", "Start-PomodoroFromUi", "Invoke-TaskDefaultWorkflow", "Get-TaskListItemsForView", "Render-TaskView", "Format-TaskLine", "Add-MenuItem", "Add-SubMenu", "ContextMenuStrip", "ToolStripMenuItem", "(Add-Task ", "(Complete-Task ", "(Start-Pomodoro ", "(Start-TaskStarter ") "Views.Task.Gestures.ps1 must stay focused on low-level click and drag mechanics."
    $interactionsRaw = Get-Content -LiteralPath $interactionsModule -Encoding UTF8 -Raw
    $mouseDownMatch = [regex]::Match($interactionsRaw, "(?s)function Invoke-TaskListMouseDown.*?(?=function Invoke-TaskListSelectedIndexChanged)")
    if (-not $mouseDownMatch.Success) { throw "Views.Task.Interactions.ps1 must define Invoke-TaskListMouseDown before Invoke-TaskListSelectedIndexChanged." }
    if ($mouseDownMatch.Value -match "DoubleClickSize|DoubleClickTime|withinDoubleArea") { throw "Invoke-TaskListMouseDown must delegate double-click gesture details to click helper functions." }
    $mouseMoveMatch = [regex]::Match($interactionsRaw, "(?s)function Invoke-TaskListMouseMove.*?(?=function Invoke-TaskListMouseUp)")
    if (-not $mouseMoveMatch.Success) { throw "Views.Task.Interactions.ps1 must define Invoke-TaskListMouseMove before Invoke-TaskListMouseUp." }
    if ($mouseMoveMatch.Value -match '\$dx|\$dy|DoDragDrop|deltaX|deltaY') { throw "Invoke-TaskListMouseMove must delegate drag threshold and drag start details to helper functions." }
    $dragDropMatch = [regex]::Match($interactionsRaw, "(?s)function Invoke-TaskListDragDrop.*?(?=function Invoke-TaskListMouseDoubleClick)")
    if (-not $dragDropMatch.Success) { throw "Views.Task.Interactions.ps1 must define Invoke-TaskListDragDrop before Invoke-TaskListMouseDoubleClick." }
    if ($dragDropMatch.Value -match "GetDataPresent|GetData\\(\\[string\\]\\)|PointToClient|IndexFromPoint") { throw "Invoke-TaskListDragDrop must delegate drag data and target index details to helper functions." }
    Test-FileDoesNotContain $taskMenuModule @("function Select-ListItemAtPoint", "function Clear-TaskSelection", "function Add-MenuEntry", "function Add-MenuItem", "function Add-SubMenu", "function Add-OpenTaskLinkMenuItem", "function Invoke-TaskMenu") "Views.Task.Menu.ps1 must keep helper construction and action functions in separate modules."
    Test-FileDoesNotContain $taskMenuModule @("Complete-Task", "Uncomplete-Task", "Delete-Task", "Schedule-TaskToday", "Unschedule-TaskToday", "End-Task", "Pin-TaskToTop", "Start-PomodoroFromUi", "Start-TaskStarter", "Continue-Pomodoro", "Pause-Pomodoro", "Stop-Pomodoro") "Views.Task.Menu.ps1 must call task-menu action wrappers instead of direct task or timer operations."
    Test-FileDoesNotContain $taskMenuModule @('$script:TimerState', '$script:TimerPhase') "Views.Task.Menu.ps1 must read runtime state through PomodoroRuntime.Queries.ps1."
    $taskMenuRaw = Get-Content -LiteralPath $taskMenuModule -Encoding UTF8 -Raw
    if ($taskMenuRaw -notlike "*Test-PomodoroRuntimePaused*") { throw "Views.Task.Menu.ps1 must keep runtime query facade marker: Test-PomodoroRuntimePaused" }
    Test-FileDoesNotContain $taskMenuActionsModule @("ContextMenuStrip", "ToolStripMenuItem", "Add-MenuItem", "Add-SubMenu", "menu.Show", "PointToClient") "Views.Task.Menu.Actions.ps1 must stay action-only and free of menu construction."
    Test-FileDoesNotContain $selectionModule @("ContextMenuStrip", "ToolStripMenuItem", "Open-TaskLink", "Complete-Task", "Delete-Task", "Start-Pomodoro") "Views.Task.Selection.ps1 must stay focused on task-list selection."
    Test-FileDoesNotContain $builderModule @("Open-TaskLink", "Complete-Task", "Delete-Task", "Start-Pomodoro", "Schedule-TaskToday", "Unschedule-TaskToday", "Pin-TaskToTop") "Views.Menu.Builders.ps1 must stay generic and action-free."
    Test-FileDoesNotContain $linkMenuModule @("Complete-Task", "Delete-Task", "Start-Pomodoro", "Edit-TaskDetails", "Resolve-TaskLinkTarget", "Start-Process", "MessageBox") "Views.Task.LinkMenu.ps1 must stay focused on delegating the open-link menu action."
    $taskMenuRaw = Get-Content -LiteralPath $taskMenuModule -Encoding UTF8 -Raw
    $openLinkCallCount = ([regex]::Matches($taskMenuRaw, "Add-OpenTaskLinkMenuItem")).Count
    if ($openLinkCallCount -lt 2) { throw "Views.Task.Menu.ps1 must keep open-link entries in both today and tasks menus." }
    $doneRaw = Get-Content -LiteralPath $doneModule -Encoding UTF8 -Raw
    if ($doneRaw -notlike "*Add-OpenTaskLinkMenuItem*") { throw "Views.Done.ps1 must reuse Add-OpenTaskLinkMenuItem for done-task menus." }
    Test-FileDoesNotContain $doneModule @("function Show-ExecutionStatsDialog", "function Enable-ExecutionRecordDrawing", "function Draw-ExecutionRecordItem", "DrawItemEventArgs") "Views.Done.ps1 must keep stats dialog and owner-draw helpers in dedicated done-view modules."
    Test-FileDoesNotContain $moreModule @("function Render-DoneView", "function Show-ExecutionRecordMenu", "Get-ExecutionRecords", "Add-OpenTaskLinkMenuItem", "ContextMenuStrip") "Views.More.ps1 must stay focused on More navigation and keep completed-task view/menu separate."
    $doneFunctionNames = @(Get-PowerShellFunctionNames $doneModule)
    $moreFunctionNames = @(Get-PowerShellFunctionNames $moreModule)
    foreach ($requiredDoneFunction in @("Render-DoneView", "Show-ExecutionRecordMenu")) {
        if ($doneFunctionNames -notcontains $requiredDoneFunction) { throw "Views.Done.ps1 must define $requiredDoneFunction." }
        if ($moreFunctionNames -contains $requiredDoneFunction) { throw "Views.More.ps1 must not define $requiredDoneFunction." }
    }
    $requiredMarkersByModule = @(
        @{ File = $selectionModule; Required = @("function Select-ListItemAtPoint", "function Clear-TaskSelection", "Hide-TaskTitlePreview") },
        @{ File = $interactionsModule; Required = @("function Invoke-TaskListDefaultClickAction", "function Reset-TaskListClickState", "function Invoke-TaskListMouseDown", "function Invoke-TaskListDragDrop", "function Invoke-TaskListMouseDoubleClick", "Get-TaskListClickGesture", "Start-TaskListItemDrag", "Get-TaskListDropTargetIndex", "Start-PomodoroFromUi", "Invoke-TaskDefaultWorkflow", "Invoke-TaskMoveWorkflow") },
        @{ File = $gesturesModule; Required = @("function Get-TaskListSelectedItemId", "function Get-TaskListClickGesture", "function Set-TaskListLastClickState", "function Test-TaskListDragThresholdExceeded", "function Start-TaskListItemDrag", "function Get-TaskListDragSourceId", "function Get-TaskListDropTargetIndex") },
        @{ File = $itemsModule; Required = @("function Get-TaskListItemsForView", "Format-TaskLine", "NoTodayTasks", "NoOpenTasks") },
        @{ File = $eventsModule; Required = @("function Register-TaskListEventHandlers", "Add_MouseDown", "Invoke-TaskListMouseDown", "Invoke-TaskListDragDrop", "Invoke-TaskListMouseDoubleClick") },
        @{ File = $builderModule; Required = @("function Add-MenuEntry", "function Add-MenuItem", "function Add-SubMenu", "ToolStripMenuItem") },
        @{ File = $linkMenuModule; Required = @("function Add-OpenTaskLinkMenuItem", "Open-TaskLink", "Add-MenuEntry") },
        @{ File = $taskMenuActionsModule; Required = @("function Invoke-TaskMenuCompleteAction", "function Invoke-TaskMenuDeleteAction", "Start-PomodoroFromUi", "Invoke-TaskStarterStartWorkflow", "Invoke-TaskDeleteWorkflow") },
        @{ File = $taskMenuModule; Required = @("function Show-TaskMenu", "Invoke-TaskMenuStartPomodoroAction", "Invoke-TaskMenuStartStarterAction", "Invoke-TaskMenuDeleteAction") },
        @{ File = $doneStatsModule; Required = @("function Show-ExecutionStatsDialog", "Get-ExecutionTaskStatsText", "ExecutionStatsHelpText") },
        @{ File = $doneDrawingModule; Required = @("function Enable-ExecutionRecordDrawing", "function Draw-ExecutionRecordItem", "OwnerDrawFixed") },
        @{ File = $doneModule; Required = @("function Render-DoneView", "function Show-ExecutionRecordMenu", "Get-ExecutionRecords", "Add-OpenTaskLinkMenuItem") },
        @{ File = $moreModule; Required = @("function Render-MoreView", 'Set-ActiveView "done"', "Invoke-DataCheck") }
    )
    foreach ($entry in $requiredMarkersByModule) {
        $raw = Get-Content -LiteralPath $entry.File -Encoding UTF8 -Raw
        foreach ($required in $entry.Required) { if ($raw -notlike "*$required*") { throw "$([System.IO.Path]::GetFileName($entry.File)) missing required marker: $required" } }
    }
    "Task list helpers and task menu helpers are split from view shells"
}
