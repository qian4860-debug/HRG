param([string]$VivadoBin='D:\vivado\2025.1\Vivado\bin',[string]$Matlab='D:\matlab\bin\matlab.exe')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    python -m unittest discover -s . -p test_head_config.py -v 2>&1 | Tee-Object config_unit_tests.log
    if($LASTEXITCODE -ne 0) {throw 'Configuration unit tests failed'}
    $config=Join-Path $PSScriptRoot '..\..\config\head_default.json'
    python prepare_profile_test.py $config --out _work/base --make-variants
    if($LASTEXITCODE -ne 0) {throw 'Variant preparation failed'}
    ./run_profile_spi.ps1 -Config _work/base/runtime_fixture.json -OutFolder _work/runtime -VivadoBin $VivadoBin
    $src=Join-Path $PSScriptRoot '_work\base\custom_src'
    $files=@(Get-ChildItem $src -File -Filter '*.v' | ForEach-Object {$_.FullName})
    & (Join-Path $VivadoBin 'xvlog.bat') --sv --work head_variant -i $src $files tb_custom_head.sv 2>&1 | Tee-Object custom_compile.log
    if($LASTEXITCODE -ne 0) {throw 'Custom head compile failed'}
    & (Join-Path $VivadoBin 'xelab.bat') head_variant.tb_custom_head -s hrg_custom_head --timescale 1ns/1ps 2>&1 | Tee-Object custom_elaborate.log
    if($LASTEXITCODE -ne 0) {throw 'Custom head elaboration failed'}
    & (Join-Path $VivadoBin 'xsim.bat') hrg_custom_head -runall 2>&1 | Tee-Object custom_simulation.log
    $result=Get-Content custom_simulation.log -Raw
    if($LASTEXITCODE -ne 0 -or $result -match 'Fatal:' -or $result -notmatch 'CUSTOM_HEAD_NUMERIC_SCOREBOARD_PASS') {throw 'Custom head numeric checks failed'}
    python ../../tools/head_config.py generate $config --out ../../generated/nominal_unmeasured
    if($LASTEXITCODE -ne 0) {throw 'Default profile generation failed'}
    $testPath=$PSScriptRoot.Replace('\','/').Replace("'","''")
    & $Matlab -batch "addpath('$testPath'); verify_head_profile" 2>&1 | Tee-Object matlab_head_profile.log
    if($LASTEXITCODE -ne 0 -or (Get-Content matlab_head_profile.log -Raw) -notmatch 'GENERATED_MATLAB_HEAD_PROFILE_PASS') {throw 'Generated MATLAB profile failed'}
    Write-Output 'HEAD_CONFIGURATION_TESTS_PASS'
} finally {Pop-Location}
