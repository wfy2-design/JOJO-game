param(
    [string]$OutputDirectory = "build/ui-captures"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class BattleCaptureWin32 {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint message, IntPtr wParam, IntPtr lParam);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[BattleCaptureWin32]::SetProcessDPIAware() | Out-Null

$projectRoot = Split-Path -Parent $PSScriptRoot
$captureRoot = Join-Path $projectRoot $OutputDirectory
New-Item -ItemType Directory -Force -Path $captureRoot | Out-Null

function Wait-ForWindow([System.Diagnostics.Process]$Process) {
    for ($i = 0; $i -lt 50; $i++) {
        $Process.Refresh()
        if ($Process.MainWindowHandle -ne 0) { return }
        Start-Sleep -Milliseconds 100
    }
    throw "Battle window did not appear"
}

function Capture-Window([System.Diagnostics.Process]$Process, [string]$Name) {
    $Process.Refresh()
    [BattleCaptureWin32+RECT]$rect = New-Object BattleCaptureWin32+RECT
    [BattleCaptureWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -lt 100 -or $height -lt 100) { throw "Invalid window bounds" }
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $captureRoot ($Name + ".png")))
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Send-GameKey([System.Diagnostics.Process]$Process, [int]$VirtualKey,
                      [int]$DelayMs = 250) {
    $Process.Refresh()
    $keyParam = [IntPtr]::new($VirtualKey)
    [BattleCaptureWin32]::PostMessage($Process.MainWindowHandle, 0x0100,
                                     $keyParam, [IntPtr]0) | Out-Null
    [BattleCaptureWin32]::PostMessage($Process.MainWindowHandle, 0x0101,
                                     $keyParam, [IntPtr]0) | Out-Null
    Start-Sleep -Milliseconds $DelayMs
}

function Close-Game([System.Diagnostics.Process]$Process) {
    if ($Process -and -not $Process.HasExited) {
        $Process.CloseMainWindow() | Out-Null
        if (-not $Process.WaitForExit(1500)) { $Process.Kill() }
    }
}

$game = $null
try {
    $game = Start-Process -FilePath (Join-Path $projectRoot "build/battle.exe") `
                          -WorkingDirectory $projectRoot -PassThru
    Wait-ForWindow $game
    Start-Sleep -Milliseconds 350
    Capture-Window $game "00-menu"

    Send-GameKey $game 0x31 1900
    Capture-Window $game "01-action"
    Send-GameKey $game 0x45 300
    Capture-Window $game "02-skills"
    Send-GameKey $game 0x1B 250
    Send-GameKey $game 0x54 300
    Capture-Window $game "03-swap"
    Send-GameKey $game 0x1B 250

    # Repeated normal attacks stop being accepted as soon as DeathSelect begins.
    for ($i = 0; $i -lt 35; $i++) { Send-GameKey $game 0x41 85 }
    Capture-Window $game "04-death-select"
} finally {
    Close-Game $game
}

try {
    $game = Start-Process -FilePath (Join-Path $projectRoot "build/battle.exe") `
                          -WorkingDirectory $projectRoot -PassThru
    Wait-ForWindow $game
    Start-Sleep -Milliseconds 300
    Send-GameKey $game 0x32 1700
    Send-GameKey $game 0x41 120
    Capture-Window $game "05-ai-turn"
} finally {
    Close-Game $game
}

Write-Output "Captured UI states to $captureRoot"
