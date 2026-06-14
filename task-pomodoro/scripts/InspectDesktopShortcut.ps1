$ErrorActionPreference = "Stop"

$shortcutName = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5Lu75Yqh55Wq6IyE6ZKfLmxuaw=="))
$desktopDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
$shortcutPath = Join-Path $desktopDir $shortcutName

if (-not (Test-Path -LiteralPath $shortcutPath)) {
    throw "Missing shortcut: $shortcutPath"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)

Write-Output "Path=$shortcutPath"
Write-Output "Icon=$($shortcut.IconLocation)"
Write-Output "Target=$($shortcut.TargetPath)"
Write-Output "Args=$($shortcut.Arguments)"
