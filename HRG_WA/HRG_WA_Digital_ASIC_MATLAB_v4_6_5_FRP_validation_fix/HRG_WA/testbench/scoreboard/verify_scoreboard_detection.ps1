param([string]$VivadoBin = 'D:\vivado\2025.1\Vivado\bin')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
$vectorPath = Join-Path $PSScriptRoot 'dsp_vectors.txt'
$originalBytes = [System.IO.File]::ReadAllBytes($vectorPath)
try {
    $lines = [System.IO.File]::ReadAllLines($vectorPath)
    $fields = $lines[0].Split(' ')
    $fields[8] = '1' # Deliberately corrupt the expected reset Cx by one LSB.
    $lines[0] = $fields -join ' '
    [System.IO.File]::WriteAllLines($vectorPath, $lines)
    & (Join-Path $VivadoBin 'xsim.bat') hrg_scoreboard -runall -testplusarg IMPLEMENTATION_ONLY 2>&1 | Tee-Object detection_simulation.log
    $logText = Get-Content detection_simulation.log -Raw
    if ($logText -notmatch 'IMPLEMENTATION_MISMATCH cycle=1 Cx actual=0 expected=1' -or
        $logText -notmatch 'Implementation scoreboard FAILED' -or
        $logText -match 'IMPLEMENTATION_SCOREBOARD_PASS') {
        throw 'Negative control failed: corrupted expectation was not detected'
    }
    Write-Output 'SCOREBOARD_NEGATIVE_CONTROL_PASS: deliberate one-LSB corruption detected'
} finally {
    [System.IO.File]::WriteAllBytes($vectorPath, $originalBytes)
    Pop-Location
}
