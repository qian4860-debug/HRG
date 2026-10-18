param([string]$VivadoBin='D:\vivado\2025.1\Vivado\bin')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    python baseline_guard.py
    if($LASTEXITCODE -ne 0) {throw 'Incompatible baseline build'}
    python generate_top_vectors.py
    if($LASTEXITCODE -ne 0) {throw 'Top reference generation failed'}
    $src=Join-Path $PSScriptRoot '..\..\src'
    $files=@(Get-ChildItem $src -Recurse -File -Filter '*.v' | ForEach-Object {$_.FullName})
    & (Join-Path $VivadoBin 'xvlog.bat') --sv -i $src $files tb_hrg_top_scoreboard.sv 2>&1 | Tee-Object top_scoreboard_compile.log
    if($LASTEXITCODE -ne 0) {throw 'Top compile failed'}
    & (Join-Path $VivadoBin 'xelab.bat') tb_hrg_top_scoreboard -s hrg_top_scoreboard --timescale 1ns/1ps 2>&1 | Tee-Object top_scoreboard_elaborate.log
    if($LASTEXITCODE -ne 0) {throw 'Top elaborate failed'}
    & (Join-Path $VivadoBin 'xsim.bat') hrg_top_scoreboard -runall 2>&1 | Tee-Object top_scoreboard_simulation.log
    $result=Get-Content top_scoreboard_simulation.log -Raw
    if($LASTEXITCODE -ne 0 -or $result -match 'Fatal:' -or $result -notmatch 'TOP_SCOREBOARD_PASS') {throw 'Top scoreboard failed'}
} finally {Pop-Location}
