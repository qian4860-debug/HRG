param(
    [string]$VivadoBin='D:\vivado\2025.1\Vivado\bin',
    [string]$Matlab='D:\matlab\bin\matlab.exe',
    [switch]$UseSavedMatlabVectors,
    [switch]$SkipElaboration
)
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    python generate_loop_vectors.py
    if($LASTEXITCODE -ne 0) {throw 'Reference generation failed'}
    if($UseSavedMatlabVectors) {
        python generate_vectors.py
        if($LASTEXITCODE -ne 0) {throw 'Reference generation failed'}
        ./run_scoreboard.ps1 -VivadoBin $VivadoBin -SkipGeneration
    } else {./run_scoreboard.ps1 -VivadoBin $VivadoBin -Matlab $Matlab}
    ./run_loop_scoreboard.ps1 -VivadoBin $VivadoBin
    ./run_top_scoreboard.ps1 -VivadoBin $VivadoBin
    ./run_top_smoke.ps1 -VivadoBin $VivadoBin
    ./verify_scoreboard_detection.ps1 -VivadoBin $VivadoBin
    if(-not $SkipElaboration) {
        & (Join-Path $VivadoBin 'vivado.bat') -mode batch -source check_rtl_elaboration.tcl -log rtl_elaboration.log -journal rtl_elaboration.jou
        if($LASTEXITCODE -ne 0 -or (Get-Content rtl_elaboration.log -Raw) -notmatch 'HRG_RTL_ELABORATION_PASS') {throw 'RTL elaboration failed'}
    }
    python analyze_results.py
    if($LASTEXITCODE -ne 0) {throw 'Verification summary failed'}
} finally {Pop-Location}
