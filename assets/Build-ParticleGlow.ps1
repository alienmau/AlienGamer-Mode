$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$output = Join-Path $PSScriptRoot 'ParticleGlow.png'
$size = 96
$bitmap = New-Object Drawing.Bitmap($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
    for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
            $dx = ($x - (($size - 1) / 2.0)) / ($size / 2.0)
            $dy = ($y - (($size - 1) / 2.0)) / ($size / 2.0)
            $distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
            if ($distance -ge 1.0) { $alpha = 0 }
            else {
                # Centro definido y halo largo con caída suave hasta transparencia total.
                $core = [Math]::Pow([Math]::Max(0, 1 - ($distance / 0.24)), 1.8)
                $halo = [Math]::Pow(1 - $distance, 2.6)
                $alpha = [Math]::Min(255, [Math]::Round(255 * [Math]::Max($core, $halo * 0.72)))
            }
            $bitmap.SetPixel($x, $y, [Drawing.Color]::FromArgb($alpha, 255, 255, 255))
        }
    }
    $bitmap.Save($output, [Drawing.Imaging.ImageFormat]::Png)
} finally {
    $bitmap.Dispose()
}

Get-Item -LiteralPath $output | Select-Object FullName, Length
