param(
    [Parameter(Mandatory = $true)]
    [string]$Executable,
    [int]$Runs = 32
)

$ErrorActionPreference = "Stop"
$seenA = $false
$seenB = $false
$counts = @{ A = 0; B = 0 }

for ($i = 0; $i -lt $Runs; $i++) {
    $result = (& $Executable --coin-only).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Coin probe failed with exit code $LASTEXITCODE"
    }
    if ($result -eq "A") {
        $seenA = $true
        $counts.A++
    } elseif ($result -eq "B") {
        $seenB = $true
        $counts.B++
    } else {
        throw "Unexpected coin probe output: $result"
    }
}

Write-Output "Independent coin tosses: Team A=$($counts.A), Team B=$($counts.B)"
if (-not ($seenA -and $seenB)) {
    Write-Error "Coin toss did not produce both teams across $Runs independent launches"
    exit 1
}
