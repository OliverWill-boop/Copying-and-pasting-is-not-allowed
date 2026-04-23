param(
    [string]$InputScript = (Join-Path $PSScriptRoot 'auto_input_gui_fixed.ps1'),
    [string]$OutputExe = (Join-Path $PSScriptRoot 'AutoInputHelper.exe')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputScript)) {
    throw "Input script not found: $InputScript"
}

$ps2exe = Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue
if (-not $ps2exe) {
    throw @'
Invoke-PS2EXE was not found.

Install it with:
Install-Module ps2exe -Scope CurrentUser

Then rerun:
powershell -ExecutionPolicy Bypass -File .\build_exe_clean.ps1
'@
}

Invoke-PS2EXE `
    -InputFile $InputScript `
    -OutputFile $OutputExe `
    -NoConsole `
    -Title 'Auto Input Helper' `
    -Product 'Auto Input Helper' `
    -Company 'Codex' `
    -Description 'A small helper that waits for a countdown and then types text automatically.'

Write-Host "EXE created: $OutputExe"
