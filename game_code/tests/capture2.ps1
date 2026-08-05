Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W3 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$h = 0
for ($i = 0; $i -lt 30; $i++) {
    $proc = Get-Process -Name battle -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.MainWindowHandle -ne 0) { $h = $proc.MainWindowHandle; break }
    Start-Sleep -Milliseconds 200
}
if ($h -eq 0) { Write-Output "NO WINDOW"; exit 1 }
[W3+RECT]$r = New-Object W3+RECT
[W3]::GetWindowRect($h, [ref]$r) | Out-Null
if ([W3]::IsIconic($h)) { Write-Output "WINDOW MINIMIZED"; exit 1 }
$w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
Start-Sleep -Seconds 2
[W3]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
Write-Output "window: ${w}x${ht} at ($($r.Left),$($r.Top))"
if ($w -lt 100 -or $ht -lt 100) { Write-Output "BAD RECT"; exit 1 }
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
$bmp.Save("E:\game\game_code\build\screenshot2.png")
Write-Output "saved screenshot2.png ${w}x${ht}"
$bmp.Dispose(); $g.Dispose()
