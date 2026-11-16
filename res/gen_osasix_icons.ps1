# Genera los iconos de Osasix Remote a partir de los poligonos del isotipo SVG.
# Uso (desde la raiz del repo):  powershell -ExecutionPolicy Bypass -File res\gen_osasix_icons.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

# Isotipo Osasix (viewBox 103 44 238 307). Todos los trazos son rectos.
$vbX = 103; $vbY = 44; $vbW = 238; $vbH = 307
$left  = @(@(172,44),@(227,44),@(158,154),@(222,260),@(167,260),@(103,154))
$right = @(@(222,135),@(277,135),@(341,241),@(272,351),@(217,351),@(286,241))
$colL = [System.Drawing.ColorTranslator]::FromHtml('#107D7C')
$colR = [System.Drawing.ColorTranslator]::FromHtml('#454555')

function New-LogoPng([int]$size, [double]$pad = 0.08) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $scale = ($size * (1 - 2 * $pad)) / $vbH
    $offX = ($size - $vbW * $scale) / 2
    $offY = ($size - $vbH * $scale) / 2
    foreach ($item in @(@($left, $colL), @($right, $colR))) {
        $pts = foreach ($p in $item[0]) {
            New-Object System.Drawing.PointF(([single](($p[0] - $vbX) * $scale + $offX)), ([single](($p[1] - $vbY) * $scale + $offY)))
        }
        $brush = New-Object System.Drawing.SolidBrush($item[1])
        $g.FillPolygon($brush, [System.Drawing.PointF[]]$pts)
        $brush.Dispose()
    }
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return ,$ms.ToArray()
}

function Save-Png([string]$rel, [int]$size) {
    [System.IO.File]::WriteAllBytes((Join-Path $root $rel), (New-LogoPng $size))
}

function Save-Ico([string]$rel, [int[]]$sizes) {
    $images = foreach ($s in $sizes) { ,(New-LogoPng $s) }
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $s = $sizes[$i]; $len = $images[$i].Length
        $dim = if ($s -ge 256) { 0 } else { $s }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$len); $bw.Write([uint32]$offset)
        $offset += $len
    }
    foreach ($img in $images) { $bw.Write($img) }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes((Join-Path $root $rel), $ms.ToArray())
}

Save-Png 'res\32x32.png' 32
Save-Png 'res\64x64.png' 64
Save-Png 'res\128x128.png' 128
Save-Png 'res\128x128@2x.png' 256
Save-Png 'res\icon.png' 1024
Save-Png 'res\mac-icon.png' 1024
Save-Ico 'res\icon.ico' @(16, 32, 48, 64, 128, 256)
Save-Ico 'res\tray-icon.ico' @(16, 24, 32, 48, 64)
Save-Ico 'flutter\windows\runner\resources\app_icon.ico' @(16, 32, 48, 64, 128, 256)
Write-Host 'Iconos de Osasix Remote generados.'
