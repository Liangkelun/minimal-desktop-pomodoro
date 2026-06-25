# This file is dot-sourced before translation modules. It owns translation platform helpers only.

function Ensure-TranslationPlatformTypes {
    if ($script:TranslationPlatformTypesReady) { return }
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    Add-Type -AssemblyName System.Security
    if (-not ([System.Management.Automation.PSTypeName]'TaskPomodoroNoActivateForm').Type) {
        Add-Type -Language CSharp -ReferencedAssemblies @("System.Windows.Forms", "System.Drawing") -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;

public class TaskPomodoroNoActivateForm : Form
{
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TRANSPARENT;
            return cp;
        }
    }
}

public class TaskPomodoroTranslationDetailForm : Form
{
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WM_NCHITTEST = 0x0084;
    private const int HTTRANSPARENT = -1;
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams { get { CreateParams cp = base.CreateParams; cp.ExStyle |= WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TRANSPARENT; return cp; } }
    protected override void WndProc(ref Message m)
    {
        base.WndProc(ref m);
        if (m.Msg == WM_NCHITTEST && this.WindowState == FormWindowState.Normal) { m.Result = (IntPtr)HTTRANSPARENT; }
    }
}
"@
    }
    if (-not ([System.Management.Automation.PSTypeName]'TaskPomodoroTranslationNative').Type) {
        Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class TaskPomodoroTranslationNative
{
    [DllImport("user32.dll")]
    public static extern uint GetClipboardSequenceNumber();
}
"@
    }
    $script:TranslationPlatformTypesReady = $true
}

function Protect-TranslationSecret([string]$Secret) {
    if ([string]::IsNullOrWhiteSpace($Secret)) { return "" }
    Ensure-TranslationPlatformTypes
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    $protected = [System.Security.Cryptography.ProtectedData]::Protect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Convert]::ToBase64String($protected)
}

function Unprotect-TranslationSecret([string]$ProtectedSecret) {
    if ([string]::IsNullOrWhiteSpace($ProtectedSecret)) { return "" }
    Ensure-TranslationPlatformTypes
    try {
        $bytes = [Convert]::FromBase64String($ProtectedSecret)
        $raw = [System.Security.Cryptography.ProtectedData]::Unprotect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [System.Text.Encoding]::UTF8.GetString($raw)
    }
    catch { return "" }
}