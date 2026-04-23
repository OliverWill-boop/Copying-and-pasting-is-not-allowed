# Copying and pasting is not allowed (Auto Input Helper)

[中文说明](./README.zh-CN.md) | English

![Windows](https://img.shields.io/badge/platform-Windows-0078D6?style=for-the-badge)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge)
![Release Bundle](https://img.shields.io/badge/release-included-2EA043?style=for-the-badge)

This repository contains **Auto Input Helper**, a lightweight Windows desktop utility that simulates keyboard text input after a countdown.

It is designed for situations where you want to:

- paste long text into a field that blocks normal paste (copy/paste disabled)
- prepare text first, move the cursor to a target input, and let the app type it automatically
- share a small no-frills typing helper with non-technical users

## Highlights

- Simple GUI workflow: enter text, click `Start`, wait for the countdown, and auto-type
- Adjustable countdown delay and typing speed
- Persistent local settings
- Runtime logging for troubleshooting
- Standalone packaged `.exe` included in the repository
- Source script and packaging script are both included

## How It Works

1. Launch the app.
2. Enter or paste the text you want to send.
3. Click `Start`.
4. Move the cursor to the target text box within the countdown window.
5. The app sends the text character by character to the currently focused control.

## Repository Structure

```text
.
|-- auto_input_gui_fixed.ps1   # Main GUI source
|-- auto_input_cli.ps1         # CLI helper version
|-- build_exe_clean.ps1        # Build script for the standalone EXE
|-- release/
|   |-- AutoInputHelper.exe    # Packaged distributable
|   `-- release_readme.txt
|-- README.md
`-- README.zh-CN.md
```

## Quick Start

### Option 1: Run the packaged EXE

Open:

`release/AutoInputHelper.exe`

### Option 2: Run from source

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\auto_input_gui_fixed.ps1
```

## Build the EXE

If you want to rebuild the standalone executable:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_exe_clean.ps1
```

The generated file will be:

`AutoInputHelper.exe`

## Logging and Troubleshooting

When the GUI version runs, it writes logs next to the executable or script:

- `auto_input_gui.log`

This helps diagnose:

- startup failures
- focus detection issues
- runtime exceptions

## Notes

- This tool currently targets Windows.
- Some applications may behave differently depending on how they handle keyboard messages.
- Some security tools may inspect the packaged `.exe` on first launch.

## Release Bundle

A ready-to-share distributable is included in:

[`release/`](./release)

## Roadmap Ideas

- global hotkey to cancel typing
- richer input compatibility across more applications
- application targeting presets
- tray mode or mini mode

## License

This repository currently does not include a separate license file. Add one before broader public distribution if needed.
