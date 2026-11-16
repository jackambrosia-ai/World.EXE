# Wrist-hacking prototype: a timed burst of window-only grabs (PrintWindow) of the HackPrototype window.
param([string]$OutDir, [int]$Count = 10, [int]$IntervalMs = 200, [int]$StartDelayMs = 0)
New-Item -ItemType Directory -Force $OutDir | Out-Null
Start-Sleep -Milliseconds $StartDelayMs
$t0 = Get-Date
for ($i = 0; $i -lt $Count; $i++) {
  $target = $t0.AddMilliseconds($i * $IntervalMs)
  $ms = ($target - (Get-Date)).TotalMilliseconds; if ($ms -gt 0) { Start-Sleep -Milliseconds ([int]$ms) }
  & (Join-Path $PSScriptRoot "hp_grab.ps1") -X 11 -Y 215 -W 1914 -H 760 -DelayMs 0 -Out (Join-Path $OutDir ("b_{0:D2}.jpg" -f $i)) | Out-Null
}
"burst done $Count"
