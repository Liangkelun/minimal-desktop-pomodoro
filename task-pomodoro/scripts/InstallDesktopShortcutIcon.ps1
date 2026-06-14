$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$shortcutName = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5Lu75Yqh55Wq6IyE6ZKfLmxuaw=="))
$desktopDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
$shortcutPath = Join-Path $desktopDir $shortcutName
$vbsPath = Join-Path $rootDir "StartTaskPomodoro.vbs"
$iconPath = Join-Path $rootDir "assets\icon\task-pomodoro-g-desktop.ico"
if (-not (Test-Path -LiteralPath $iconPath)) {
    $iconPath = Join-Path $rootDir "assets\icon\task-pomodoro-g.ico"
}
if (-not (Test-Path -LiteralPath $iconPath)) {
    $iconPath = Join-Path $rootDir "assets\icon\task-pomodoro.ico"
}
$wscriptPath = Join-Path $env:WINDIR "System32\wscript.exe"

if (-not (Test-Path -LiteralPath $vbsPath)) {
    throw "Missing launcher: $vbsPath"
}
if (-not (Test-Path -LiteralPath $iconPath)) {
    throw "Missing icon: $iconPath"
}
if (-not (Test-Path -LiteralPath $wscriptPath)) {
    throw "Missing wscript.exe: $wscriptPath"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $wscriptPath
$shortcut.Arguments = '"' + $vbsPath + '"'
$shortcut.WorkingDirectory = $rootDir
$shortcut.IconLocation = "$iconPath,0"
$shortcut.Description = "Task Pomodoro"
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Output "Shortcut=$shortcutPath"
Write-Output "Icon=$iconPath"
