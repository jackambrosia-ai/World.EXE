# Core Round Step 1E: tile capture frames into one contact sheet (local evidence only).
#   powershell -File cr_sheet.ps1 -InDir <dir> -Out <sheet.jpg> [-Cols 4] [-Width 420] [-Pick "3,5,7,9"]
param([string]$InDir, [string]$Out, [int]$Cols = 4, [int]$Width = 420, [string]$Pick = "")
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem $InDir -Filter *.jpg | Sort-Object Name
if ($Pick) { $idx = $Pick.Split(",") | ForEach-Object { [int]$_ }; $files = $idx | ForEach-Object { $files[$_] } }
$first = [System.Drawing.Image]::FromFile($files[0].FullName)
$h = [int]($first.Height * $Width / $first.Width); $first.Dispose()
$rows = [math]::Ceiling($files.Count / $Cols)
$sheet = New-Object System.Drawing.Bitmap ($Cols * $Width), ($rows * $h)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font "Consolas", 11
for ($i = 0; $i -lt $files.Count; $i++) {
  $im = [System.Drawing.Image]::FromFile($files[$i].FullName)
  $x = ($i % $Cols) * $Width; $y = [math]::Floor($i / $Cols) * $h
  $g.DrawImage($im, $x, $y, $Width, $h); $im.Dispose()
  $g.DrawString($files[$i].BaseName, $font, [System.Drawing.Brushes]::Yellow, $x + 4, $y + 4)
}
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 88L
$sheet.Save($Out, $codec, $ep); $g.Dispose(); $sheet.Dispose()
"sheet $Out ($($files.Count) frames)"
