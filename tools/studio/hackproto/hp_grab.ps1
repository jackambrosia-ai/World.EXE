# Wrist-hacking prototype: window-only capture of the HackPrototype Studio window (PrintWindow), never the desktop.
# then crop the 3D viewport region (window-relative). Never reads any other window.
#   powershell -File v36_grab_pw.ps1 -Out <file.jpg> [-X 19 -Y 223 -W 1036 -H 583]
param([switch]$WholeWindow, [string]$Out, [int]$X = 292, [int]$Y = 215, [int]$W = 1351, [int]$H = 760, [int]$DelayMs = 1500)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class P36 {
 public delegate bool EnumProc(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 public struct RECT { public int L, T, R, B; }
}
"@
$script:hw = [IntPtr]::Zero
[P36]::EnumWindows({ param($h, $l) if ([P36]::IsWindowVisible($h)) { $sb = New-Object System.Text.StringBuilder 512; [void][P36]::GetWindowText($h, $sb, 512); if ($sb.ToString() -like "*WorldEXE_HackPrototype*Roblox Studio*") { $script:hw = $h } }; return $true }, [IntPtr]::Zero) | Out-Null
if ($script:hw -eq [IntPtr]::Zero) { throw "HackPrototype window not found" }
Start-Sleep -Milliseconds $DelayMs
$r = New-Object P36+RECT; [P36]::GetWindowRect($script:hw, [ref]$r) | Out-Null
$ww = $r.R - $r.L; $wh = $r.B - $r.T
$full = New-Object System.Drawing.Bitmap $ww, $wh
$g = [System.Drawing.Graphics]::FromImage($full); $hdc = $g.GetHdc()
[P36]::PrintWindow($script:hw, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc); $g.Dispose()
if ($WholeWindow) { $X = 0; $Y = 0; $W = $ww; $H = $wh }
$crop = $full.Clone((New-Object System.Drawing.Rectangle $X, $Y, $W, $H), $full.PixelFormat)
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 92L
$crop.Save($Out, $codec, $ep); $crop.Dispose(); $full.Dispose()
"saved $Out (window ${ww}x${wh} at $($r.L),$($r.T))"
