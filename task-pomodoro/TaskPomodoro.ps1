param(
    [switch]$SelfTest
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

if (-not ([System.Management.Automation.PSTypeName]'TaskPomodoroResizableForm').Type) {
    Add-Type -Language CSharp -ReferencedAssemblies @("System.Windows.Forms", "System.Drawing") -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class TaskPomodoroResizableForm : Form
{
    private const int WM_NCHITTEST = 0x0084;
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_LAYERED = 0x00080000;
    private const int HTLEFT = 10;
    private const int HTRIGHT = 11;
    private const int HTTOP = 12;
    private const int HTTOPLEFT = 13;
    private const int HTTOPRIGHT = 14;
    private const int HTBOTTOM = 15;
    private const int HTBOTTOMLEFT = 16;
    private const int HTBOTTOMRIGHT = 17;
    private const int HTCLIENT = 1;
    private const int HTTRANSPARENT = -1;
    private int resizeGripSize = 6;
    private bool watermarkMode = false;
    private bool clickThroughEnabled = false;
    private int watermarkExitSize = 26;

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    public int ResizeGripSize
    {
        get { return resizeGripSize; }
        set { resizeGripSize = value; }
    }
    public bool WatermarkMode
    {
        get { return watermarkMode; }
        set { watermarkMode = value; }
    }
    public int WatermarkExitSize
    {
        get { return watermarkExitSize; }
        set { watermarkExitSize = value; }
    }
    public bool ClickThroughEnabled
    {
        get { return clickThroughEnabled; }
    }
    public void SetClickThrough(bool enabled)
    {
        if (!this.IsHandleCreated)
        {
            clickThroughEnabled = enabled;
            return;
        }

        int style = GetWindowLong(this.Handle, GWL_EXSTYLE);
        if (enabled)
        {
            style = style | WS_EX_LAYERED | WS_EX_TRANSPARENT;
        }
        else
        {
            style = style & ~WS_EX_TRANSPARENT;
        }
        SetWindowLong(this.Handle, GWL_EXSTYLE, style);
        clickThroughEnabled = enabled;
    }

    protected override void WndProc(ref Message m)
    {
        base.WndProc(ref m);
        if (m.Msg != WM_NCHITTEST || this.WindowState != FormWindowState.Normal)
        {
            return;
        }

        int raw = unchecked((int)m.LParam.ToInt64());
        int x = (short)(raw & 0xffff);
        int y = (short)((raw >> 16) & 0xffff);
        Point point = this.PointToClient(new Point(x, y));
        if (WatermarkMode)
        {
            int exitSize = Math.Max(16, WatermarkExitSize);
            if (point.X >= this.ClientSize.Width - exitSize && point.Y <= exitSize)
            {
                m.Result = (IntPtr)HTCLIENT;
            }
            else
            {
                m.Result = (IntPtr)HTTRANSPARENT;
            }
            return;
        }

        int grip = Math.Max(2, ResizeGripSize);
        bool left = point.X <= grip;
        bool right = point.X >= this.ClientSize.Width - grip;
        bool top = point.Y <= grip;
        bool bottom = point.Y >= this.ClientSize.Height - grip;

        if (left && top) m.Result = (IntPtr)HTTOPLEFT;
        else if (right && top) m.Result = (IntPtr)HTTOPRIGHT;
        else if (left && bottom) m.Result = (IntPtr)HTBOTTOMLEFT;
        else if (right && bottom) m.Result = (IntPtr)HTBOTTOMRIGHT;
        else if (left) m.Result = (IntPtr)HTLEFT;
        else if (right) m.Result = (IntPtr)HTRIGHT;
        else if (top) m.Result = (IntPtr)HTTOP;
        else if (bottom) m.Result = (IntPtr)HTBOTTOM;
    }
}
"@
}

$ErrorActionPreference = "Stop"

$script:RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataDir = Join-Path $script:RootDir "data"
$script:ConfigDir = Join-Path $script:RootDir "config"
$script:BackupDir = Join-Path $script:DataDir "backups"
$script:TasksFile = Join-Path $script:DataDir "tasks.json"
$script:PomodorosFile = Join-Path $script:DataDir "pomodoros.jsonl"
$script:SettingsFile = Join-Path $script:ConfigDir "settings.json"

$script:ModulesDir = Join-Path $script:RootDir "modules"
foreach ($moduleName in @("UiText.ps1", "Storage.ps1", "SettingsStore.ps1", "TaskStore.ps1", "TaskDetails.ps1", "TaskArchive.ps1", "TaskFormat.ps1", "PomodoroEngine.ps1", "AppMaintenance.ps1", "WindowBehavior.ps1", "Views.Core.ps1", "Views.Task.Controls.ps1", "Views.Task.DetailsDialog.ps1", "Views.Task.Edit.ps1", "Views.Task.ps1", "Views.Task.Menu.ps1", "Views.Timer.ps1", "Views.More.ps1", "Views.Settings.Controls.ps1", "Views.Settings.ps1", "SelfTest.ps1")) {
    . (Join-Path $script:ModulesDir $moduleName)
}

function Invoke-DataCheck {
    try {
        Load-Tasks
        Save-Tasks
        Load-Settings
        Save-Settings
        [System.Windows.Forms.MessageBox]::Show((T "TasksFileReadable"), (T "DataCheckDone")) | Out-Null
        Set-Status (T "DataOk")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T "DataCheck")) | Out-Null
    }
    Render-CurrentView
}

function Initialize-State {
    Initialize-Storage
    Load-Settings
    Load-Tasks
    if (-not (Test-Path -LiteralPath $script:PomodorosFile)) {
        Invoke-WithNamedMutex (Get-AppScopedMutexName "data") {
            if (-not (Test-Path -LiteralPath $script:PomodorosFile)) {
                "" | Set-Content -LiteralPath $script:PomodorosFile -Encoding UTF8
            }
        }
    }
    $script:ActiveView = "today"
    $script:TimerState = "idle"
    $script:TimerPhase = "work"
    $script:SecondsRemaining = [int]$script:Settings.WorkMinutes * 60
    $script:CurrentPomodoroTaskId = $null
    $script:CurrentPomodoroTaskTitle = T "UnboundFocus"
    $script:PomodoroStartedAt = $null
    $script:PomodoroStartedAtDate = $null
    $script:PomodoroEndAt = $null
    $script:BackgroundPlayer = $null
    $script:StatusMessage = ""
    $script:WatermarkMode = $false
    $script:WatermarkPreviousOpacity = $null
    $script:WatermarkPreviousTopMost = $null
    $script:WatermarkToggleButton = $null
    $script:WatermarkToggleDragActive = $false
    $script:WatermarkToggleDragMoved = $false
    $script:WatermarkToggleDragStart = $null
    $script:HelpButton = $null
    $script:TaskPreviewToolTip = $null
    $script:TaskPreviewPanel = $null
    Invoke-DailyArchiveIfDue | Out-Null
}

function Initialize-Ui {
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:Form = New-Object TaskPomodoroResizableForm
    $script:Form.Text = T "AppTitle"
    $script:Form.Width = [int]$script:Settings.WindowWidth
    $script:Form.Height = [int]$script:Settings.WindowHeight
    $script:Form.MinimumSize = New-Object System.Drawing.Size(240, 34)
    $script:Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $script:Form.Padding = New-Object System.Windows.Forms.Padding(4)
    $script:Form.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $script:Form.ResizeGripSize = 6
    $iconPath = Get-AppIconPath
    if (-not [string]::IsNullOrWhiteSpace($iconPath)) {
        try {
            $script:Form.Icon = New-Object System.Drawing.Icon($iconPath)
            $script:Form.ShowIcon = $true
        }
        catch {
            $script:Form.ShowIcon = $false
        }
    }
    else {
        $script:Form.ShowIcon = $false
    }
    $script:Form.TopMost = [bool]$script:Settings.TopMost
    $script:Form.Opacity = [double]$script:Settings.Opacity
    $script:Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    if ($null -ne $script:Settings.WindowX -and $null -ne $script:Settings.WindowY) {
        $script:Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $script:Form.Location = New-Object System.Drawing.Point([int]$script:Settings.WindowX, [int]$script:Settings.WindowY)
    }
    $script:Form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.5)
    $script:Form.MaximizeBox = $false

    $main = New-Object System.Windows.Forms.TableLayoutPanel
    $main.Dock = [System.Windows.Forms.DockStyle]::Fill
    $main.ColumnCount = 1
    $main.RowCount = 2
    $main.Margin = New-Object System.Windows.Forms.Padding(0)
    $main.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) | Out-Null
    $script:MainPanel = $main
    $script:NavRowStyle = $main.RowStyles[1]
    $script:BottomChromeVisible = $true
    $script:BottomChromeSuppressed = $false
    $script:Form.Controls.Add($main)
    Add-WindowDrag $main
    Add-BottomChromeTracking $script:Form
    Add-BottomChromeTracking $main

    $nav = New-Object System.Windows.Forms.TableLayoutPanel
    $nav.Dock = [System.Windows.Forms.DockStyle]::Fill
    $nav.ColumnCount = 2
    $nav.RowCount = 1
    $nav.Padding = New-Object System.Windows.Forms.Padding(3, 1, 3, 1)
    $nav.Margin = New-Object System.Windows.Forms.Padding(0)
    $nav.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $nav.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $nav.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 64))) | Out-Null
    $nav.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $script:NavPanel = $nav
    $main.Controls.Add($nav, 0, 1)
    Add-WindowDrag $nav
    Add-BottomChromeTracking $nav

    $navButtonsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $navButtonsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $navButtonsPanel.WrapContents = $false
    $navButtonsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $navButtonsPanel.Padding = New-Object System.Windows.Forms.Padding(0)
    $navButtonsPanel.Margin = New-Object System.Windows.Forms.Padding(0)
    $navButtonsPanel.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $nav.Controls.Add($navButtonsPanel, 0, 0)
    Add-WindowDrag $navButtonsPanel
    Add-BottomChromeTracking $navButtonsPanel

    $script:NavButtons = @{}
    $taskButton = New-Button (T "TaskList") 46
    $taskButton.Add_Click({ Set-ActiveView "tasks" })
    $script:NavButtons["tasks"] = $taskButton
    $navButtonsPanel.Controls.Add($taskButton)

    $todayButton = New-Button (T "TodayList") 46
    $todayButton.Add_Click({ Set-ActiveView "today" })
    $script:NavButtons["today"] = $todayButton
    $navButtonsPanel.Controls.Add($todayButton)

    $timerButton = New-Button (T "Pomodoro") 46
    $timerButton.Add_Click({ Set-ActiveView "timer" })
    $script:NavButtons["timer"] = $timerButton
    $navButtonsPanel.Controls.Add($timerButton)

    $moreButton = New-Button (T "More") 52
    $moreButton.Add_Click({ Set-ActiveView "more" })
    $script:NavButtons["more"] = $moreButton
    $navButtonsPanel.Controls.Add($moreButton)

    $windowButtonsPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $windowButtonsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $windowButtonsPanel.ColumnCount = 2
    $windowButtonsPanel.RowCount = 1
    $windowButtonsPanel.Margin = New-Object System.Windows.Forms.Padding(0)
    $windowButtonsPanel.Padding = New-Object System.Windows.Forms.Padding(0)
    $windowButtonsPanel.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    $windowButtonsPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 28))) | Out-Null
    $windowButtonsPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $windowButtonsPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $nav.Controls.Add($windowButtonsPanel, 1, 0)
    Add-BottomChromeTracking $windowButtonsPanel

    $sizeToggleButton = New-Button "." 24
    $sizeToggleButton.Dock = [System.Windows.Forms.DockStyle]::Fill
    $sizeToggleButton.Margin = New-Object System.Windows.Forms.Padding(0)
    $sizeToggleButton.Add_Click({ Toggle-TaskRowsSize })
    $script:SizeToggleButton = $sizeToggleButton
    $windowButtonsPanel.Controls.Add($sizeToggleButton, 0, 0)
    Add-BottomChromeTracking $sizeToggleButton
    Update-SizeToggleButton

    $closeButton = New-Button (T "Close") 34
    $closeButton.Dock = [System.Windows.Forms.DockStyle]::Fill
    $closeButton.Margin = New-Object System.Windows.Forms.Padding(0)
    $closeButton.Add_Click({ $script:Form.Close() })
    $script:CloseButton = $closeButton
    $windowButtonsPanel.Controls.Add($closeButton, 1, 0)
    Add-BottomChromeTracking $closeButton

    $script:StatusLabel = $null

    $script:ContentPanel = New-Object System.Windows.Forms.Panel
    $script:ContentPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:ContentPanel.Padding = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
    $script:ContentPanel.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
    Add-WindowDrag $script:ContentPanel
    Add-BottomChromeTracking $script:ContentPanel
    $main.Controls.Add($script:ContentPanel, 0, 0)
    Ensure-WatermarkToggleButton

    $script:UiTimer = New-Object System.Windows.Forms.Timer
    $script:UiTimer.Interval = 1000
    $script:UiTimer.Add_Tick({ Timer-Tick })
    $script:UiTimer.Start()

    $script:Form.Add_FormClosing({
        $script:Form.SetClickThrough($false)
        Stop-BackgroundAudio
        Save-Settings
    })

    Update-DateLabel
    Set-ActiveView "today"
}

function Start-TaskPomodoroApp {
    Initialize-Ui
    [System.Windows.Forms.Application]::Run($script:Form)
}

if (-not $SelfTest -and -not (Start-AppInstanceLock)) {
    exit 0
}
try {
    Initialize-State
    if ($SelfTest) {
        Invoke-SelfTest
        exit 0
    }
    Start-TaskPomodoroApp
}
finally {
    if (-not $SelfTest) {
        Stop-AppInstanceLock
    }
}
