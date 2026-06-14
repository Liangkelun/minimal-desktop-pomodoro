Option Explicit

Dim shell, fso, baseDir, dataDir, logDir, scriptPath, logPath, stamp, command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
dataDir = fso.BuildPath(baseDir, "data")
If Not fso.FolderExists(dataDir) Then
    fso.CreateFolder dataDir
End If
logDir = fso.BuildPath(dataDir, "logs")
If Not fso.FolderExists(logDir) Then
    fso.CreateFolder logDir
End If

scriptPath = fso.BuildPath(baseDir, "TaskPomodoro.ps1")
Randomize
stamp = Year(Now) & Right("0" & Month(Now), 2) & Right("0" & Day(Now), 2) _
    & "-" & Right("0" & Hour(Now), 2) & Right("0" & Minute(Now), 2) & Right("0" & Second(Now), 2) _
    & "-" & Right("0000" & CStr(Int(Rnd() * 10000)), 4)
logPath = fso.BuildPath(logDir, "launch-" & stamp & ".log")

command = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -Command " _
    & Chr(34) & "$ErrorActionPreference='Stop'; " _
    & "$log='" & Replace(logPath, "'", "''") & "'; " _
    & "Set-Content -LiteralPath $log -Value ('launch ' + (Get-Date).ToString('o') + ' root=' + '" & Replace(baseDir, "'", "''") & "') -Encoding UTF8; " _
    & "try { & '" & Replace(scriptPath, "'", "''") & "' *>> $log } " _
    & "catch { $_ | Out-String | Add-Content -LiteralPath $log -Encoding UTF8 }" _
    & Chr(34)

shell.Run command, 1, False
