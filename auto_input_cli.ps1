param(
    [string]$Text,
    [string]$TextFile,
    [int]$DelaySeconds = 6,
    [int]$CharDelayMs = 35,
    [string]$LogPath = (Join-Path $PSScriptRoot 'auto_input.log'),
    [switch]$FromClipboard
)

$ErrorActionPreference = 'Stop'

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
    Add-Content -LiteralPath $LogPath -Value "[$timestamp] $Message" -Encoding UTF8
}

function Get-InputText {
    if ($PSBoundParameters.ContainsKey('Text') -and $null -ne $Text) {
        return $Text
    }

    if ($PSBoundParameters.ContainsKey('TextFile') -and $TextFile) {
        if (-not (Test-Path -LiteralPath $TextFile)) {
            throw "Text file not found: $TextFile"
        }

        return Get-Content -LiteralPath $TextFile -Encoding UTF8 -Raw
    }

    if ($FromClipboard) {
        Add-Type -AssemblyName System.Windows.Forms
        return [System.Windows.Forms.Clipboard]::GetText()
    }

    Write-Host 'Paste or type the text to send.'
    Write-Host 'Finish input with a single line: :end'
    Write-Host ''

    $lines = New-Object System.Collections.Generic.List[string]
    while ($true) {
        $line = Read-Host
        if ($line -eq ':end') {
            break
        }

        [void]$lines.Add($line)
    }

    return [string]::Join([Environment]::NewLine, $lines)
}

function Send-WindowText {
    param(
        [string]$Value,
        [int]$DelayMs
    )

    $targetHandle = [NativeTextSender]::GetFocusedHandle()
    Write-Log "Focused handle: $targetHandle"

    if ($targetHandle -eq [IntPtr]::Zero) {
        throw 'Could not find a focused window or input control.'
    }

    foreach ($char in $Value.ToCharArray()) {
        [void][NativeTextSender]::SendMessage(
            $targetHandle,
            [NativeTextSender]::WM_CHAR,
            [IntPtr][int][char]$char,
            [IntPtr]::Zero
        )

        if ($DelayMs -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

try {
    Write-Log '----- run started -----'
    Write-Log "Parameters: DelaySeconds=$DelaySeconds, CharDelayMs=$CharDelayMs, FromClipboard=$FromClipboard"

    $textToSend = Get-InputText
    if ([string]::IsNullOrWhiteSpace($textToSend)) {
        throw 'Input text is empty.'
    }

    Write-Log "Input length: $($textToSend.Length)"

    Write-Host ''
    Write-Host "Collected $($textToSend.Length) characters."
    Write-Host "Move the cursor to the target input within $DelaySeconds seconds."
    Write-Host 'Press Ctrl+C now if you want to cancel.'
    Write-Host ''

    for ($i = $DelaySeconds; $i -ge 1; $i--) {
        Write-Host "$i..."
        Write-Log "Countdown: $i"
        Start-Sleep -Seconds 1
    }

    Write-Host 'Typing...'
    Write-Log 'Typing started.'
    Send-WindowText -Value $textToSend -DelayMs $CharDelayMs
    Write-Log 'Typing finished.'
    Write-Host 'Done.'
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "STACK: $($_.ScriptStackTrace)"
    Write-Host ''
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "See log: $LogPath" -ForegroundColor Yellow
    exit 1
}
