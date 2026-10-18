param(
    [string]$VivadoBin = 'D:\vivado\2025.1\Vivado\bin',
    [string]$Matlab = 'D:\matlab\bin\matlab.exe',
    [switch]$ImplementationOnly,
    [switch]$SkipGeneration
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    python baseline_guard.py
    if ($LASTEXITCODE -ne 0) { throw 'Incompatible baseline build' }
    if (-not $SkipGeneration) {
        & python generate_vectors.py
        if ($LASTEXITCODE -ne 0) { throw 'Vector generation failed' }
        & $Matlab -batch "export_model_vectors"
        if ($LASTEXITCODE -ne 0) { throw 'MATLAB reference generation failed' }
        python reference_guard.py --record
        if ($LASTEXITCODE -ne 0) { throw 'Reference provenance recording failed' }
    }
    python reference_guard.py
    if ($LASTEXITCODE -ne 0) { throw 'MATLAB reference is stale; regenerate with MATLAB' }
    $src = Join-Path $PSScriptRoot '..\..\src'
    $files = @('hrg_nco.v','hrg_dsp_core.v','hrg_pi_aw.v','hrg_controller.v','hrg_cordic.v') | ForEach-Object { Join-Path $src $_ }
    & (Join-Path $VivadoBin 'xvlog.bat') --sv -i $src $files tb_hrg_scoreboard.sv 2>&1 | Tee-Object compile.log
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
    & (Join-Path $VivadoBin 'xelab.bat') tb_hrg_scoreboard -s hrg_scoreboard --timescale 1ns/1ps 2>&1 | Tee-Object elaborate.log
    if ($LASTEXITCODE -ne 0) { throw 'xelab failed' }
    $simArgs = @('hrg_scoreboard','-runall')
    if ($ImplementationOnly) { $simArgs += @('-testplusarg','IMPLEMENTATION_ONLY') }
    & (Join-Path $VivadoBin 'xsim.bat') @simArgs 2>&1 | Tee-Object simulation.log
    $simExit = $LASTEXITCODE
    $logText = Get-Content simulation.log -Raw
    # Some XSim versions return zero after $fatal. Inspect explicit results too.
    if ($simExit -ne 0 -or $logText -match 'Fatal:' -or $logText -notmatch 'IMPLEMENTATION_SCOREBOARD_PASS') {
        throw 'Scoreboard failed; see simulation.log and dsp_comparison.csv'
    }
    if (-not $ImplementationOnly -and $logText -notmatch 'MATLAB_EQUIVALENCE_PASS') {
        throw 'MATLAB equivalence failed'
    }
} finally { Pop-Location }
