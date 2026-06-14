$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class ShellRefresh {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@

[ShellRefresh]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
Start-Process -FilePath (Join-Path $env:WINDIR "System32\ie4uinit.exe") -ArgumentList "-show" -WindowStyle Hidden -Wait
Write-Output "Desktop icon refresh requested."
