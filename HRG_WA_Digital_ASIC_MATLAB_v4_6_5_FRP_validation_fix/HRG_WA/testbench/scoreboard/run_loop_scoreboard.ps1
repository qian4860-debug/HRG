param([string]$VivadoBin='D:\vivado\2025.1\Vivado\bin')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    python generate_loop_vectors.py
    if($LASTEXITCODE -ne 0) { throw 'Loop reference generation failed' }
    python reference_guard.py
    if($LASTEXITCODE -ne 0) {throw 'MATLAB reference is stale; regenerate with MATLAB'}
    $src=Join-Path $PSScriptRoot '..\..\src'
    $files=@('hrg_pi_aw.v','hrg_controller.v','hrg_dpll.v','hrg_navigation.v') | ForEach-Object {Join-Path $src $_}
    & (Join-Path $VivadoBin 'xvlog.bat') --sv $files tb_hrg_loop_scoreboard.sv 2>&1 | Tee-Object loop_compile.log
    if($LASTEXITCODE -ne 0) {throw 'Loop compile failed'}
    & (Join-Path $VivadoBin 'xelab.bat') tb_hrg_loop_scoreboard -s hrg_loop_scoreboard --timescale 1ns/1ps 2>&1 | Tee-Object loop_elaborate.log
    if($LASTEXITCODE -ne 0) {throw 'Loop elaborate failed'}
    & (Join-Path $VivadoBin 'xsim.bat') hrg_loop_scoreboard -runall 2>&1 | Tee-Object loop_simulation.log
    $result=Get-Content loop_simulation.log -Raw
    if($LASTEXITCODE -ne 0 -or $result -match 'Fatal:' -or $result -notmatch 'LOOP_SCOREBOARD_PASS') {throw 'Loop scoreboard failed'}
} finally {Pop-Location}
