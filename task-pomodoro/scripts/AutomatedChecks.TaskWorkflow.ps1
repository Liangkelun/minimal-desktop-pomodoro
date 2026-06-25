# This file is dot-sourced by Invoke-AutomatedChecks.ps1 for task workflow boundary assertions.

function Invoke-TaskWorkflowBoundaryCheck([string]$ModulesDir) {
    $workflow = Join-Path $ModulesDir "TaskWorkflow.ps1"
    $commands = Join-Path $ModulesDir "TaskCommands.ps1"
    $taskView = Join-Path $ModulesDir "Views.Task.ps1"
    $taskEdit = Join-Path $ModulesDir "Views.Task.Edit.ps1"
    $taskMenuActions = Join-Path $ModulesDir "Views.Task.Menu.Actions.ps1"
    foreach ($requiredFile in @($workflow, $commands, $taskView, $taskEdit, $taskMenuActions)) { Test-RequiredFile $requiredFile }
    . (Join-Path $ModulesDir "ModuleLoadOrder.ps1"); $loadOrder = Get-TaskPomodoroModuleLoadOrder
    foreach ($moduleName in @("TaskCommands.ps1", "TaskWorkflow.ps1", "Views.Task.Edit.ps1", "Views.Task.ps1", "Views.Task.Menu.Actions.ps1")) { if ([Array]::IndexOf($loadOrder, $moduleName) -lt 0) { throw "ModuleLoadOrder.ps1 missing $moduleName" } }
    if ([Array]::IndexOf($loadOrder, "TaskCommands.ps1") -gt [Array]::IndexOf($loadOrder, "TaskWorkflow.ps1")) { throw "TaskWorkflow.ps1 must load after TaskCommands.ps1" }
    foreach ($viewModule in @("Views.Task.Edit.ps1", "Views.Task.ps1", "Views.Task.Menu.Actions.ps1")) { if ([Array]::IndexOf($loadOrder, "TaskWorkflow.ps1") -gt [Array]::IndexOf($loadOrder, $viewModule)) { throw "TaskWorkflow.ps1 must load before $viewModule" } }
    $workflowRaw = Get-Content -LiteralPath $workflow -Encoding UTF8 -Raw
    foreach ($required in @("function Invoke-TaskCreateWorkflow", "function Invoke-TaskCompleteWorkflow", "function Invoke-TaskRenameWorkflow", "function Invoke-TaskMoveWorkflow", "function Invoke-TaskDefaultWorkflow")) { if ($workflowRaw -notlike "*$required*") { throw "TaskWorkflow.ps1 missing required marker: $required" } }
    Test-FileDoesNotContain $workflow @("System.Windows.Forms", "MessageBox", "InputBox", "Set-Status", "Render-CurrentView") "TaskWorkflow.ps1 must stay UI-free."
    Test-FileDoesNotContain $commands @("Start-Pomodoro", "Pause-Pomodoro", "Continue-Pomodoro", "Stop-Pomodoro", "Complete-Pomodoro", "Start-TaskStarter", "Complete-TaskStarter", "Invoke-TaskDefaultAction") "TaskCommands.ps1 must stay in the task domain and must not call Pomodoro or starter state machines."
    $directTaskOps = @("(Add-Task ", "(Complete-Task ", "(Uncomplete-Task ", "(Toggle-TaskCompletion ", "(Schedule-TaskToday ", "(Unschedule-TaskToday ", "(End-Task ", "(Delete-Task ", "(Set-TaskTitle ", "(Move-TaskInView ", "(Pin-TaskToTop ", "(Invoke-TaskDefaultAction ")
    foreach ($viewFile in @($taskView, $taskEdit, $taskMenuActions)) { Test-FileDoesNotContain $viewFile $directTaskOps "$([System.IO.Path]::GetFileName($viewFile)) must use TaskWorkflow.ps1 for task mutations." }
    "Task UI mutations are routed through TaskWorkflow.ps1"
}