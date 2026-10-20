param([string]$VivadoBin = 'D:\vivado\2025.1\Vivado\bin')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    python baseline_guard.py
    if($LASTEXITCODE -ne 0) {throw 'Incompatible baseline build'}
    $src = Join-Path $PSScriptRoot '..\..\src'
    $files = @(Get-ChildItem $src -Recurse -File -Filter '*.v' | ForEach-Object { $_.FullName })
    $files += Join-Path $PSScriptRoot '..\tb_hrg_sensor_if.sv'
    & (Join-Path $VivadoBin 'xvlog.bat') --sv -i $src $files 2>&1 | Tee-Object top_compile.log
    if ($LASTEXITCODE -ne 0) { throw 'Top compile failed' }
    & (Join-Path $VivadoBin 'xelab.bat') tb_hrg_sensor_if -s hrg_top_smoke --timescale 1ns/1ps 2>&1 | Tee-Object top_elaborate.log
    if ($LASTEXITCODE -ne 0) { throw 'Top elaborate failed' }
    & (Join-Path $VivadoBin 'xsim.bat') hrg_top_smoke -runall 2>&1 | Tee-Object top_simulation.log
    if ($LASTEXITCODE -ne 0 -or (Get-Content top_simulation.log -Raw) -notmatch 'HRG_SENSOR_IF_TB PASS') {
        throw 'Top smoke test failed'
    }
} finally { Pop-Location }
