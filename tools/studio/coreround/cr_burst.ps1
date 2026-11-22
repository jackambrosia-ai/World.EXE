# Core Round Step 1: a timed burst of window-only grabs (PrintWindow) of the CoreRound Studio window (viewport crop).
#   powershell -File cr_burst.ps1 -OutDir <dir> [-Count 10] [-IntervalMs 200] [-StartDelayMs 0]
# Crop defaults match a 1296x930 Studio window with the default ribbon (viewport at 10,215 .. 1286,850).
param([string]$Match = "*WorldEXE_CoreRound*Roblox Studio*", [string]$OutDir, [int]$Count = 10, [int]$IntervalMs = 200, [int]$StartDelayMs = 0, [int]$X = 10, [int]$Y = 215, [int]$W = 1276, [int]$H = 635)
New-Item -ItemType Directory -Force $OutDir | Out-Null
Start-Sleep -Milliseconds $StartDelayMs
$t0 = Get-Date
for ($i = 0; $i -lt $Count; $i++) {
  $target = $t0.AddMilliseconds($i * $IntervalMs)
  $ms = ($target - (Get-Date)).TotalMilliseconds; if ($ms -gt 0) { Start-Sleep -Milliseconds ([int]$ms) }
  & (Join-Path $PSScriptRoot "cr_grab.ps1") -Match $Match -X $X -Y $Y -W $W -H $H -DelayMs 0 -Out (Join-Path $OutDir ("b_{0:D2}.jpg" -f $i)) | Out-Null
}
"burst done $Count"
