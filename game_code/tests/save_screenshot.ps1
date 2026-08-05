Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W2 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder sb, int max);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$proc = Get-Process -Name battle -ErrorAction Stop | Select-Object -First 1
$h = $proc.MainWindowHandle
$sb = New-Object System.Text.StringBuilder 256
[W2]::GetWindowText($h, $sb, 256) | Out-Null
[System.IO.File]::WriteAllText("E:\game\game_code\build\window_title.txt", "title=" + $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
[W2+RECT]$r = New-Object W2+RECT
[W2]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
$bmp.Save("E:\game\game_code\build\screenshot.png")
Write-Output "screenshot saved"
$bmp.Dispose(); $g.Dispose()
