Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

function Get-AppDirectory {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    if ($MyInvocation.MyCommand.Path) {
        return (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }

    $processPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($processPath) {
        return (Split-Path -Parent $processPath)
    }

    return [Environment]::CurrentDirectory
}

$scriptDir = Get-AppDirectory
$logPath = Join-Path $scriptDir 'auto_input_gui.log'

$signature = @'
using System;
using System.Runtime.InteropServices;

public static class NativeTextSender
{
    [StructLayout(LayoutKind.Sequential)]
    public struct GUITHREADINFO
    {
        public uint cbSize;
        public uint flags;
        public IntPtr hwndActive;
        public IntPtr hwndFocus;
        public IntPtr hwndCapture;
        public IntPtr hwndMenuOwner;
        public IntPtr hwndMoveSize;
        public IntPtr hwndCaret;
        public RECT rcCaret;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr ProcessId);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO lpgui);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint WM_CHAR = 0x0102;

    public static IntPtr GetFocusedHandle()
    {
        IntPtr foreground = GetForegroundWindow();
        if (foreground == IntPtr.Zero)
        {
            return IntPtr.Zero;
        }

        uint threadId = GetWindowThreadProcessId(foreground, IntPtr.Zero);
        GUITHREADINFO info = new GUITHREADINFO();
        info.cbSize = (uint)Marshal.SizeOf(typeof(GUITHREADINFO));

        if (!GetGUIThreadInfo(threadId, ref info))
        {
            return foreground;
        }

        if (info.hwndFocus != IntPtr.Zero)
        {
            return info.hwndFocus;
        }

        return foreground;
    }
}
'@

Add-Type -TypeDefinition $signature

function Write-Log {
    param(
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message" -Encoding UTF8
}

$settingsPath = Join-Path $scriptDir 'auto_input_gui.settings.json'

$speedOptions = [ordered]@{
    'Slow'   = 90
    'Normal' = 35
    'Fast'   = 10
}

$state = [ordered]@{
    Mode             = 'Idle'
    RemainingSeconds = 0
    Text             = ''
    CurrentIndex     = 0
    DelayMs          = 35
    TargetHandle     = [IntPtr]::Zero
}

function Get-Settings {
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $settingsPath -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log "Failed to load settings: $($_.Exception.Message)"
        return $null
    }
}

function Save-Settings {
    param(
        [int]$DelaySeconds,
        [string]$SpeedName
    )

    $payload = [ordered]@{
        DelaySeconds = $DelaySeconds
        SpeedName    = $SpeedName
    }

    $payload | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

function Set-UiMode {
    param(
        [bool]$Running
    )

    $textBox.Enabled = -not $Running
    $delayInput.Enabled = -not $Running
    $speedCombo.Enabled = -not $Running
    $startButton.Enabled = -not $Running
    $stopButton.Enabled = $Running
    $clearButton.Enabled = -not $Running
}

function Set-Status {
    param(
        [string]$Text,
        [System.Drawing.Color]$Color
    )

    $statusLabel.Text = "Status: $Text"
    $statusLabel.ForeColor = $Color
}

function Reset-RunState {
    $countdownTimer.Stop()
    $typingTimer.Stop()

    $state.Mode = 'Idle'
    $state.RemainingSeconds = 0
    $state.Text = ''
    $state.CurrentIndex = 0
    $state.TargetHandle = [IntPtr]::Zero

    $countdownValueLabel.Text = 'Ready'
    Set-UiMode -Running $false
}

function Show-UiError {
    param(
        [string]$Context,
        [System.Exception]$Exception
    )

    Write-Log "ERROR [$Context]: $($Exception.Message)"
    Write-Log "STACK [$Context]: $($Exception | Out-String)"
    [System.Windows.Forms.MessageBox]::Show(
        "$Context failed: $($Exception.Message)`r`nLog: $logPath",
        'Auto Input Helper',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Finish-Run {
    param(
        [string]$StatusText,
        [System.Drawing.Color]$Color,
        [string]$CountdownText
    )

    Reset-RunState
    $countdownValueLabel.Text = $CountdownText
    Set-Status -Text $StatusText -Color $Color
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Auto Input Helper'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.MinimumSize = New-Object System.Drawing.Size(760, 560)
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 251)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(24, 18)
$titleLabel.Size = New-Object System.Drawing.Size(680, 32)
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.Text = 'Auto Input Helper'
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Location = New-Object System.Drawing.Point(26, 54)
$subtitleLabel.Size = New-Object System.Drawing.Size(700, 24)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 98, 112)
$subtitleLabel.Text = 'Paste text, click Start, switch focus to the target field, then wait for the countdown.'
$form.Controls.Add($subtitleLabel)

$textLabel = New-Object System.Windows.Forms.Label
$textLabel.Location = New-Object System.Drawing.Point(28, 94)
$textLabel.Size = New-Object System.Drawing.Size(120, 24)
$textLabel.Text = 'Text to type'
$form.Controls.Add($textLabel)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(30, 124)
$textBox.Size = New-Object System.Drawing.Size(500, 300)
$textBox.Multiline = $true
$textBox.ScrollBars = 'Vertical'
$textBox.AcceptsReturn = $true
$textBox.AcceptsTab = $true
$textBox.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$form.Controls.Add($textBox)

$charCountLabel = New-Object System.Windows.Forms.Label
$charCountLabel.Location = New-Object System.Drawing.Point(30, 432)
$charCountLabel.Size = New-Object System.Drawing.Size(200, 24)
$charCountLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 98, 112)
$charCountLabel.Text = 'Characters: 0'
$form.Controls.Add($charCountLabel)

$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.Location = New-Object System.Drawing.Point(548, 124)
$rightPanel.Size = New-Object System.Drawing.Size(180, 300)
$rightPanel.BackColor = [System.Drawing.Color]::White
$rightPanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($rightPanel)

$countdownTitleLabel = New-Object System.Windows.Forms.Label
$countdownTitleLabel.Location = New-Object System.Drawing.Point(18, 18)
$countdownTitleLabel.Size = New-Object System.Drawing.Size(140, 24)
$countdownTitleLabel.TextAlign = 'MiddleCenter'
$countdownTitleLabel.Text = 'Countdown'
$rightPanel.Controls.Add($countdownTitleLabel)

$countdownValueLabel = New-Object System.Windows.Forms.Label
$countdownValueLabel.Location = New-Object System.Drawing.Point(10, 48)
$countdownValueLabel.Size = New-Object System.Drawing.Size(156, 80)
$countdownValueLabel.Font = New-Object System.Drawing.Font('Segoe UI', 24, [System.Drawing.FontStyle]::Bold)
$countdownValueLabel.TextAlign = 'MiddleCenter'
$countdownValueLabel.Text = 'Ready'
$rightPanel.Controls.Add($countdownValueLabel)

$delayLabel = New-Object System.Windows.Forms.Label
$delayLabel.Location = New-Object System.Drawing.Point(18, 142)
$delayLabel.Size = New-Object System.Drawing.Size(120, 24)
$delayLabel.Text = 'Delay (sec)'
$rightPanel.Controls.Add($delayLabel)

$delayInput = New-Object System.Windows.Forms.NumericUpDown
$delayInput.Location = New-Object System.Drawing.Point(22, 170)
$delayInput.Size = New-Object System.Drawing.Size(136, 28)
$delayInput.Minimum = 1
$delayInput.Maximum = 30
$delayInput.Value = 6
$rightPanel.Controls.Add($delayInput)

$speedLabel = New-Object System.Windows.Forms.Label
$speedLabel.Location = New-Object System.Drawing.Point(18, 208)
$speedLabel.Size = New-Object System.Drawing.Size(120, 24)
$speedLabel.Text = 'Typing speed'
$rightPanel.Controls.Add($speedLabel)

$speedCombo = New-Object System.Windows.Forms.ComboBox
$speedCombo.Location = New-Object System.Drawing.Point(22, 236)
$speedCombo.Size = New-Object System.Drawing.Size(136, 28)
$speedCombo.DropDownStyle = 'DropDownList'
[void]$speedCombo.Items.AddRange([string[]]$speedOptions.Keys)
$speedCombo.SelectedItem = 'Normal'
$rightPanel.Controls.Add($speedCombo)

$hintLabel = New-Object System.Windows.Forms.Label
$hintLabel.Location = New-Object System.Drawing.Point(24, 464)
$hintLabel.Size = New-Object System.Drawing.Size(704, 24)
$hintLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 98, 112)
$hintLabel.Text = 'Tip: click Start, move the cursor to the target input, then wait for the countdown.'
$form.Controls.Add($hintLabel)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(30, 494)
$startButton.Size = New-Object System.Drawing.Size(150, 36)
$startButton.Text = 'Start'
$startButton.BackColor = [System.Drawing.Color]::FromArgb(48, 132, 255)
$startButton.ForeColor = [System.Drawing.Color]::White
$startButton.FlatStyle = 'Flat'
$startButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($startButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Location = New-Object System.Drawing.Point(192, 494)
$stopButton.Size = New-Object System.Drawing.Size(150, 36)
$stopButton.Text = 'Stop'
$stopButton.Enabled = $false
$stopButton.FlatStyle = 'Flat'
$stopButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(196, 198, 204)
$form.Controls.Add($stopButton)

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Location = New-Object System.Drawing.Point(354, 494)
$clearButton.Size = New-Object System.Drawing.Size(150, 36)
$clearButton.Text = 'Clear'
$clearButton.FlatStyle = 'Flat'
$clearButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(196, 198, 204)
$form.Controls.Add($clearButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(520, 498)
$statusLabel.Size = New-Object System.Drawing.Size(208, 28)
$statusLabel.TextAlign = 'MiddleRight'
$statusLabel.Text = 'Status: Ready'
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(28, 132, 74)
$form.Controls.Add($statusLabel)

$countdownTimer = New-Object System.Windows.Forms.Timer
$countdownTimer.Interval = 1000

$typingTimer = New-Object System.Windows.Forms.Timer
$typingTimer.Interval = 35

$textBox.Add_TextChanged({
    $charCountLabel.Text = "Characters: $($textBox.Text.Length)"
})

$clearButton.Add_Click({
    try {
        Write-Log 'Clear clicked.'
        $textBox.Clear()
        $textBox.Focus() | Out-Null
    }
    catch {
        Show-UiError -Context 'Clear' -Exception $_.Exception
    }
})

$countdownTimer.Add_Tick({
    try {
        if ($state.Mode -ne 'Countdown') {
            $countdownTimer.Stop()
            return
        }

        $state.RemainingSeconds--
        Write-Log "Countdown tick: $($state.RemainingSeconds)"

        if ($state.RemainingSeconds -le 0) {
            $countdownTimer.Stop()

            $targetHandle = [NativeTextSender]::GetFocusedHandle()
            Write-Log "Focused handle: $targetHandle"
            if ($targetHandle -eq [IntPtr]::Zero) {
                Finish-Run -StatusText 'No target found' -Color ([System.Drawing.Color]::Firebrick) -CountdownText 'Failed'
                [System.Windows.Forms.MessageBox]::Show(
                    'No focused input was found. Click Start again and place the cursor in the target input before the countdown ends.',
                    'Auto Input Helper',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }

            $state.TargetHandle = $targetHandle
            $state.Mode = 'Typing'
            $countdownValueLabel.Text = 'Typing'
            Set-Status -Text 'Typing' -Color ([System.Drawing.Color]::FromArgb(48, 132, 255))
            $typingTimer.Interval = [Math]::Max([int]$state.DelayMs, 1)
            $typingTimer.Start()
            Write-Log 'Typing timer started.'
            return
        }

        $countdownValueLabel.Text = [string]$state.RemainingSeconds
        Set-Status -Text "Countdown ($($state.RemainingSeconds)s)" -Color ([System.Drawing.Color]::DarkOrange)
    }
    catch {
        Finish-Run -StatusText 'Error' -Color ([System.Drawing.Color]::Firebrick) -CountdownText 'Error'
        Show-UiError -Context 'Countdown' -Exception $_.Exception
    }
})

$typingTimer.Add_Tick({
    try {
        if ($state.Mode -ne 'Typing') {
            $typingTimer.Stop()
            return
        }

        if ($state.CurrentIndex -ge $state.Text.Length) {
            Finish-Run -StatusText 'Done' -Color ([System.Drawing.Color]::FromArgb(28, 132, 74)) -CountdownText 'Done'
            [System.Media.SystemSounds]::Asterisk.Play()
            Write-Log 'Typing finished.'
            return
        }

        $charCode = [int][char]$state.Text[$state.CurrentIndex]
        [void][NativeTextSender]::SendMessage(
            $state.TargetHandle,
            [NativeTextSender]::WM_CHAR,
            [IntPtr]$charCode,
            [IntPtr]::Zero
        )

        $state.CurrentIndex++
    }
    catch {
        Finish-Run -StatusText 'Error' -Color ([System.Drawing.Color]::Firebrick) -CountdownText 'Error'
        Show-UiError -Context 'Typing' -Exception $_.Exception
    }
})

$startButton.Add_Click({
    try {
        Write-Log 'Start clicked.'
        $text = $textBox.Text
        if ([string]::IsNullOrWhiteSpace($text)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Please enter the text to type first.',
                'Auto Input Helper',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        $selectedSpeed = [string]$speedCombo.SelectedItem
        if (-not $speedOptions.Contains($selectedSpeed)) {
            $selectedSpeed = 'Normal'
            $speedCombo.SelectedItem = $selectedSpeed
        }

        $state.Mode = 'Countdown'
        $state.RemainingSeconds = [int]$delayInput.Value
        $state.Text = $text
        $state.CurrentIndex = 0
        $state.DelayMs = [int]$speedOptions[$selectedSpeed]
        $state.TargetHandle = [IntPtr]::Zero

        $countdownValueLabel.Text = [string]$state.RemainingSeconds
        Set-Status -Text "Countdown ($($state.RemainingSeconds)s)" -Color ([System.Drawing.Color]::DarkOrange)
        Set-UiMode -Running $true

        Save-Settings -DelaySeconds ([int]$delayInput.Value) -SpeedName $selectedSpeed
        Write-Log "Run started. Length=$($text.Length), DelaySeconds=$($state.RemainingSeconds), CharDelayMs=$($state.DelayMs)"
        [System.Media.SystemSounds]::Beep.Play()
        $countdownTimer.Start()
    }
    catch {
        Finish-Run -StatusText 'Error' -Color ([System.Drawing.Color]::Firebrick) -CountdownText 'Error'
        Show-UiError -Context 'Start' -Exception $_.Exception
    }
})

$stopButton.Add_Click({
    try {
        Write-Log 'Stop clicked.'
        Finish-Run -StatusText 'Stopped' -Color ([System.Drawing.Color]::Firebrick) -CountdownText 'Stopped'
    }
    catch {
        Show-UiError -Context 'Stop' -Exception $_.Exception
    }
})

$form.Add_FormClosing({
    try {
        Write-Log 'Form closing.'
        if ($state.Mode -ne 'Idle') {
            $typingTimer.Stop()
            $countdownTimer.Stop()
        }

        Save-Settings -DelaySeconds ([int]$delayInput.Value) -SpeedName ([string]$speedCombo.SelectedItem)
    }
    catch {
        Show-UiError -Context 'Close' -Exception $_.Exception
    }
})

$savedSettings = Get-Settings
if ($savedSettings) {
    if ($savedSettings.DelaySeconds -is [int] -or $savedSettings.DelaySeconds -is [long]) {
        $clampedDelay = [Math]::Min([Math]::Max([int]$savedSettings.DelaySeconds, [int]$delayInput.Minimum), [int]$delayInput.Maximum)
        $delayInput.Value = $clampedDelay
    }

    if ($savedSettings.SpeedName -and $speedOptions.Contains([string]$savedSettings.SpeedName)) {
        $speedCombo.SelectedItem = [string]$savedSettings.SpeedName
    }
}

$textBox.Focus() | Out-Null
Write-Log 'GUI launched.'
[void]$form.ShowDialog()
