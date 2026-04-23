param(
    [string]$OutputIco = (Join-Path $PSScriptRoot '..\assets\auto-input-helper.ico'),
    [string]$OutputPng = (Join-Path $PSScriptRoot '..\assets\auto-input-helper.png')
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$icoPath = [System.IO.Path]::GetFullPath($OutputIco)
$pngPath = [System.IO.Path]::GetFullPath($OutputPng)

$icoDir = Split-Path -Parent $icoPath
$pngDir = Split-Path -Parent $pngPath

if (-not (Test-Path -LiteralPath $icoDir)) {
    New-Item -ItemType Directory -Path $icoDir | Out-Null
}

if (-not (Test-Path -LiteralPath $pngDir)) {
    New-Item -ItemType Directory -Path $pngDir | Out-Null
}

$size = 256
$bitmap = New-Object System.Drawing.Bitmap $size, $size
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$backgroundRect = New-Object System.Drawing.Rectangle 16, 16, 224, 224
$accentRect = New-Object System.Drawing.Rectangle 30, 30, 196, 196

$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$radius = 44
$diameter = $radius * 2
$path.AddArc($backgroundRect.X, $backgroundRect.Y, $diameter, $diameter, 180, 90)
$path.AddArc($backgroundRect.Right - $diameter, $backgroundRect.Y, $diameter, $diameter, 270, 90)
$path.AddArc($backgroundRect.Right - $diameter, $backgroundRect.Bottom - $diameter, $diameter, $diameter, 0, 90)
$path.AddArc($backgroundRect.X, $backgroundRect.Bottom - $diameter, $diameter, $diameter, 90, 90)
$path.CloseFigure()

$backgroundBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point 256, 256),
    ([System.Drawing.Color]::FromArgb(31, 87, 255)),
    ([System.Drawing.Color]::FromArgb(18, 153, 255))
)
$graphics.FillPath($backgroundBrush, $path)

$innerBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(248, 251, 255))
$graphics.FillEllipse($innerBrush, $accentRect)

$cursorBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 140, 66))
$graphics.FillRectangle($cursorBrush, 158, 78, 20, 104)

$textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(22, 38, 84))
$font = New-Object System.Drawing.Font 'Segoe UI', 88, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString('Aa', $font, $textBrush, (New-Object System.Drawing.RectangleF 30, 78, 150, 104), $format)

$linePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(180, 198, 220)), 10
$graphics.DrawLine($linePen, 62, 192, 194, 192)
$graphics.DrawLine($linePen, 62, 214, 170, 214)

$bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)

$icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
$fileStream = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create)
try {
    $icon.Save($fileStream)
}
finally {
    $fileStream.Dispose()
    $icon.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
    $backgroundBrush.Dispose()
    $innerBrush.Dispose()
    $cursorBrush.Dispose()
    $textBrush.Dispose()
    $font.Dispose()
    $format.Dispose()
    $linePen.Dispose()
    $path.Dispose()
}

Write-Host "Generated icon: $icoPath"
Write-Host "Generated preview: $pngPath"
