# Genera los iconos PNG de la PWA /trenes/ con System.Drawing
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

# Dibuja un tren de frente estilizado (paleta de la app) sobre $g
function Draw-Train([System.Drawing.Graphics]$g, [float]$cx, [float]$cy, [float]$s) {
  $ink    = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,23,33,43))
  $coral  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,242,107,80))
  $gold   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,244,185,66))
  $paper  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,247,243,233))

  # cuerpo de la locomotora
  $bw = 1.5*$s; $bh = 1.1*$s; $bx = $cx - $bw/2; $by = $cy - $bh/2
  $body = New-RoundedRectPath $bx $by $bw $bh (0.32*$s)
  $g.FillPath($coral, $body)
  $g.DrawPath((New-Object System.Drawing.Pen ($ink.Color), (0.09*$s)), $body)

  # techo / franja dorada
  $roofW = 1.1*$s; $roofH = 0.22*$s
  $roof = New-RoundedRectPath ($cx-$roofW/2) ($by - 0.18*$s) $roofW $roofH (0.1*$s)
  $g.FillPath($gold, $roof)

  # ventanilla
  $ww = 0.62*$s; $wh = 0.44*$s
  $win = New-RoundedRectPath ($cx-$ww/2) ($by + 0.2*$s) $ww $wh (0.1*$s)
  $g.FillPath($paper, $win)
  $g.DrawPath((New-Object System.Drawing.Pen ($ink.Color), (0.06*$s)), $win)

  # faro
  $hl = 0.14*$s
  $g.FillEllipse($gold, ($cx - 0.5*$s), ($by + $bh - 0.36*$s), $hl, $hl)

  # ruedas
  $wr = 0.17*$s
  foreach ($dx in -0.42, 0.42) {
    $wx = $cx + $dx*$s - $wr; $wy = $by + $bh - 0.06*$s
    $g.FillEllipse($ink, $wx, $wy, $wr*2, $wr*2)
    $g.FillEllipse($paper, ($wx + 0.05*$s), ($wy + 0.05*$s), $wr*1.1, $wr*1.1)
  }

  # vía
  $pen = New-Object System.Drawing.Pen ($ink.Color), (0.09*$s)
  $g.DrawLine($pen, ($cx - 1.05*$s), ($by + $bh + 0.30*$s), ($cx + 1.05*$s), ($by + $bh + 0.30*$s))
  $g.DrawLine($pen, ($cx - 0.75*$s), ($by + $bh + 0.42*$s), ($cx + 0.75*$s), ($by + $bh + 0.42*$s))
}

function New-Icon([int]$size, [string]$file, [bool]$maskable, [bool]$transparentBg) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

  $teal = [System.Drawing.Color]::FromArgb(255,17,100,102)
  $scale = 0.26; if ($maskable) { $scale = 0.24 }
  $s = $size * $scale                             # escala del tren
  $cy = $size * 0.44
  $cx = $size * 0.5

  if ($maskable) {
    # fondo a sangre completa (zona segura 80%)
    $g.Clear($teal)
  } elseif ($transparentBg) {
    $g.Clear([System.Drawing.Color]::Transparent)
    $pad = $size * 0.06
    $bg = New-RoundedRectPath $pad $pad ($size - 2*$pad) ($size - 2*$pad) ($size * 0.24)
    $brush = New-Object System.Drawing.SolidBrush $teal
    $g.FillPath($brush, $bg)
  } else {
    $g.Clear($teal)
  }

  Draw-Train $g $cx $cy $s

  if ($maskable) {
    # sutil viñeta circular para dar profundidad
  }
  $g.Dispose()
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "OK $file ($size px)"
}

New-Icon 192 (Join-Path $PSScriptRoot "icon-192.png") $false $false
New-Icon 512 (Join-Path $PSScriptRoot "icon-512.png") $false $false
New-Icon 512 (Join-Path $PSScriptRoot "maskable-512.png") $true $false
New-Icon 180 (Join-Path $PSScriptRoot "apple-touch-icon.png") $false $false
New-Icon 32  (Join-Path $PSScriptRoot "favicon-32.png") $false $false
New-Icon 16  (Join-Path $PSScriptRoot "favicon-16.png") $false $false
Write-Host 'Iconos generados.'
