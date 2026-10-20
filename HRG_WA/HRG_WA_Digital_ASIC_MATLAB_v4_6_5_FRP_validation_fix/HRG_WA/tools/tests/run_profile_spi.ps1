param(
    [string]$Config=(Join-Path $PSScriptRoot '..\..\config\head_default.json'),
    [string]$OutFolder=(Join-Path $PSScriptRoot '_work\selected'),
    [string]$VivadoBin='D:\vivado\2025.1\Vivado\bin'
)
$ErrorActionPreference='Stop'
$configPath=(Resolve-Path -LiteralPath $Config).Path
Push-Location $PSScriptRoot
try {
    python prepare_profile_test.py $configPath --out $OutFolder
    if($LASTEXITCODE -ne 0) {throw 'Profile fixture generation failed'}
    $outPath=(Resolve-Path -LiteralPath $OutFolder).Path
    $src=Join-Path $PSScriptRoot '..\..\src'
    $files=@(Get-ChildItem $src -Recurse -File -Filter '*.v' | ForEach-Object {$_.FullName})
    & (Join-Path $VivadoBin 'xvlog.bat') --sv -i $src $files tb_hrg_profile_spi.sv 2>&1 | Tee-Object profile_compile.log
    if($LASTEXITCODE -ne 0) {throw 'Profile SPI compile failed'}
    & (Join-Path $VivadoBin 'xelab.bat') tb_hrg_profile_spi -s hrg_profile_spi --timescale 1ns/1ps 2>&1 | Tee-Object profile_elaborate.log
    if($LASTEXITCODE -ne 0) {throw 'Profile SPI elaboration failed'}
    $plan=(Join-Path $outPath 'spi_commands.txt').Replace('\','/')
    $expected=(Join-Path $outPath 'spi_expected.txt').Replace('\','/')
    & (Join-Path $VivadoBin 'xsim.bat') hrg_profile_spi -runall -testplusarg "PLAN_$plan" -testplusarg "EXPECTED_$expected" 2>&1 | Tee-Object profile_simulation.log
    $result=Get-Content profile_simulation.log -Raw
    if($LASTEXITCODE -ne 0 -or $result -match 'Fatal:' -or $result -notmatch 'HEAD_PROFILE_SCOREBOARD_PASS') {throw 'Generated SPI plan did not match RTL'}
} finally {Pop-Location}
