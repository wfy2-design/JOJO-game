Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$proc = Get-Process -Name battle -ErrorAction Stop | Select-Object -First 1
Start-Sleep -Milliseconds 800
$h = $proc.MainWindowHandle
[Win32+RECT]$r = New-Object Win32+RECT
[Win32]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.Right - $r.Left
$ht = $r.Bottom - $r.Top
Write-Output "window size: ${w}x${ht}"
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)

# 统计关键设计颜色
$bg = 0; $red = 0; $white = 0; $total = 0
for ($y = 0; $y -lt $ht; $y += 3) {
  for ($x = 0; $x -lt $w; $x += 3) {
    $c = $bmp.GetPixel($x, $y)
    $total++
    if ([Math]::Abs($c.R-22) -lt 12 -and [Math]::Abs($c.G-22) -lt 12 -and [Math]::Abs($c.B-30) -lt 12) { $bg++ }
    elseif ($c.R -gt 200 -and $c.G -lt 100 -and $c.B -lt 100) { $red++ }
    elseif ($c.R -gt 220 -and $c.G -gt 220 -and $c.B -gt 220) { $white++ }
  }
}
Write-Output "sample total=$total"
Write-Output "dark-bg pixels=$bg  red-accent pixels=$red  white-text pixels=$white"
$ok = ($bg -gt ($total*0.3)) -and ($red -gt 20) -and ($white -gt 20)
Write-Output ("UI_RENDER_CHECK: " + $(if($ok){"PASS - 界面按设计渲染"}else{"FAIL - 渲染异常"}))
$bmp.Dispose(); $g.Dispose()
