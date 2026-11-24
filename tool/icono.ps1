# Dibuja el icono (calendario + reloj, con los colores de Paleta.claro) y lo guarda en Windows y Android.
# Uso: .\tool\icono.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
Add-Type -AssemblyName System.Drawing

function Color($hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
$linea = Color '#B0643A'; $cabecera = Color '#E09668'; $papel = Color '#FAF7F2'; $fondo = Color '#EEE6D8'

function Rect-Redondo($x, $y, $w, $h, $r) {
  $p = New-Object Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  , $p
}

# El dibujo mide 250 x 220. $chico: menos detalle y trazo grueso, para 16 a 32 px.
function Dibujar($g, [bool]$chico) {
  $t = if ($chico) { 16 } else { 7 }
  $pluma = New-Object Drawing.Pen $linea, $t
  $pluma.LineJoin = 'Round'; $pluma.StartCap = 'Round'; $pluma.EndCap = 'Round'
  $bLinea = New-Object Drawing.SolidBrush $linea
  $bPapel = New-Object Drawing.SolidBrush $papel
  $bCab = New-Object Drawing.SolidBrush $cabecera

  $cuerpo = Rect-Redondo 8 24 196 148 14
  $g.FillPath($bPapel, $cuerpo)
  $g.SetClip($cuerpo); $g.FillRectangle($bCab, 0, 0, 220, 66); $g.ResetClip()
  $g.DrawLine($pluma, 8, 66, 204, 66)
  $g.DrawPath($pluma, $cuerpo)

  foreach ($x in $(if ($chico) { 58, 154 } else { 40, 84, 128, 172 })) {
    if ($chico) { $g.DrawLine($pluma, $x, 12, $x, 36) }
    else { $a = Rect-Redondo ($x - 7) 6 14 36 7; $g.FillPath($bPapel, $a); $g.DrawPath($pluma, $a) }
  }
  if ($chico) {
    foreach ($c in @(38, 92), @(86, 92), @(38, 130)) { $g.FillRectangle($bLinea, $c[0], $c[1], 26, 24) }
  } else {
    foreach ($fila in 0, 1) { foreach ($col in 0..(3 - $fila)) {
      $g.DrawPath($pluma, (Rect-Redondo (28 + 43 * $col) (80 + 43 * $fila) 27 27 3))
    } }
  }

  # Reloj: dos aros y agujas; un hueco lo separa del calendario.
  $cx = 194; $cy = 164; $r = if ($chico) { 54 } else { 50 }
  $g.CompositingMode = 'SourceCopy'
  $g.FillEllipse([Drawing.Brushes]::Transparent, $cx - $r - 6, $cy - $r - 6, 2 * $r + 12, 2 * $r + 12)
  $g.CompositingMode = 'SourceOver'
  $g.FillEllipse($bPapel, $cx - $r, $cy - $r, 2 * $r, 2 * $r)
  $i = if ($chico) { $r } else { 36 }
  $g.FillEllipse($bPapel, $cx - $i, $cy - $i, 2 * $i, 2 * $i)
  $m = $r - $t / 2
  $g.DrawEllipse($pluma, $cx - $m, $cy - $m, 2 * $m, 2 * $m)
  if (-not $chico) { $g.DrawEllipse($pluma, $cx - 36, $cy - 36, 72, 72) }
  $largo = if ($chico) { 26 } else { 22 }
  $g.DrawLines($pluma, [Drawing.PointF[]]@((New-Object Drawing.PointF $cx, ($cy - $largo)), (New-Object Drawing.PointF $cx, $cy), (New-Object Drawing.PointF ($cx + $largo - 4), $cy)))
}

# Cuadro de $lado px con el dibujo centrado ocupando $ancho px. Se dibuja al cuádruple y se achica: bordes limpios.
function Cuadro($lado, $ancho, $relleno) {
  $n = 4 * $lado; $e = 4 * $ancho / 250
  $grande = New-Object Drawing.Bitmap $n, $n
  $g = [Drawing.Graphics]::FromImage($grande)
  $g.SmoothingMode = 'AntiAlias'
  $g.TranslateTransform(($n - 250 * $e) / 2, ($n - 222 * $e) / 2); $g.ScaleTransform($e, $e)
  Dibujar $g ($lado -le 32)
  $g.Dispose()
  $b = New-Object Drawing.Bitmap $lado, $lado
  $g = [Drawing.Graphics]::FromImage($b)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.SmoothingMode = 'AntiAlias'
  if ($relleno) { $g.FillPath((New-Object Drawing.SolidBrush $fondo), (Rect-Redondo 0 0 ($lado - 1) ($lado - 1) ($lado * .22))) }
  $g.DrawImage($grande, 0, 0, $lado, $lado)
  $g.Dispose(); $grande.Dispose()
  , $b
}

function Guardar-Png($bmp, $ruta) {
  New-Item -ItemType Directory -Force (Split-Path $ruta) | Out-Null
  $bmp.Save((Join-Path $PWD $ruta), [Drawing.Imaging.ImageFormat]::Png)
}

# .ico: 256 px en PNG y el resto como mapa de bits de 32 bits, que es lo que entienden todos los lectores.
function Guardar-Ico($lados, $ruta) {
  $cuadros = foreach ($l in $lados) {
    $b = Cuadro $l $l $false
    $ms = New-Object IO.MemoryStream
    if ($l -eq 256) { $b.Save($ms, [Drawing.Imaging.ImageFormat]::Png) }
    else {
      $w = New-Object IO.BinaryWriter $ms
      $w.Write([int]40); $w.Write([int]$l); $w.Write([int](2 * $l)); $w.Write([int16]1); $w.Write([int16]32)
      foreach ($k in 1..6) { $w.Write([int]0) }
      for ($y = $l - 1; $y -ge 0; $y--) { for ($x = 0; $x -lt $l; $x++) { $w.Write($b.GetPixel($x, $y).ToArgb()) } }
      $w.Write((New-Object byte[] ([int]([math]::Ceiling($l / 32) * 4 * $l)))) # máscara vacía: manda la transparencia
    }
    [pscustomobject]@{ Lado = $l; Datos = $ms.ToArray() }
  }
  $ms = New-Object IO.MemoryStream
  $w = New-Object IO.BinaryWriter $ms
  $w.Write([int16]0); $w.Write([int16]1); $w.Write([int16]$cuadros.Count)
  $pos = 6 + 16 * $cuadros.Count
  foreach ($c in $cuadros) {
    $w.Write([byte]($c.Lado % 256)); $w.Write([byte]($c.Lado % 256)); $w.Write([int16]0)
    $w.Write([int16]1); $w.Write([int16]32); $w.Write([int]$c.Datos.Length); $w.Write([int]$pos)
    $pos += $c.Datos.Length
  }
  foreach ($c in $cuadros) { $w.Write([byte[]]$c.Datos) }
  [IO.File]::WriteAllBytes((Join-Path $PWD $ruta), $ms.ToArray())
}

Guardar-Ico @(16, 20, 24, 32, 40, 48, 64, 128, 256) 'windows\runner\resources\app_icon.ico'
Copy-Item 'windows\runner\resources\app_icon.ico' 'assets\tray.ico'

# Android 8+: el sistema recorta la forma; el dibujo va en la zona segura (264 de 432 px). Antes: cuadro propio.
$res = 'android\app\src\main\res'
Guardar-Png (Cuadro 432 216 $false) "$res\drawable-xxxhdpi\ic_launcher_foreground.png"
foreach ($d in @('mdpi', 48), @('hdpi', 72), @('xhdpi', 96), @('xxhdpi', 144), @('xxxhdpi', 192)) {
  Guardar-Png (Cuadro $d[1] ($d[1] * .74) $true) "$res\mipmap-$($d[0])\ic_launcher.png"
}
