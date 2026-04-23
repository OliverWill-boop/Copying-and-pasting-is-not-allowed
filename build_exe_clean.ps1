param(
    [string]$InputScript = (Join-Path $PSScriptRoot 'auto_input_gui_fixed.ps1'),
    [string]$OutputExe = (Join-Path $PSScriptRoot 'AutoInputHelper.exe'),
    [string]$IconFile = (Join-Path $PSScriptRoot 'assets\auto-input-helper.ico'),
    [string]$Version = '1.1.0'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputScript)) {
    throw "Input script not found: $InputScript"
}

$iconGenerator = Join-Path $PSScriptRoot 'scripts\generate_app_icon.ps1'
if (-not (Test-Path -LiteralPath $IconFile)) {
    if (-not (Test-Path -LiteralPath $iconGenerator)) {
        throw "Icon file not found and generator script is missing: $IconFile"
    }

    & $iconGenerator -OutputIco $IconFile
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
    -iconFile $IconFile `
    -NoConsole `
    -Title 'Auto Input Helper' `
    -Product 'Auto Input Helper' `
    -Company 'OliverWill-boop' `
    -Version $Version `
    -Copyright 'Copyright (c) 2026 OliverWill-boop' `
    -Description 'A small helper that waits for a countdown and then types text automatically.'

Write-Host "EXE created: $OutputExe"
