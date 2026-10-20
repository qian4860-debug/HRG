param(
    [string]$Config=(Join-Path $PSScriptRoot 'head_default.json'),
    [string]$VivadoBin='D:\vivado\2025.1\Vivado\bin'
)
$ErrorActionPreference='Stop'
$configPath=(Resolve-Path -LiteralPath $Config).Path
$headRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$profile=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$out=Join-Path $headRoot ('generated\'+$profile.head_id)
Push-Location $headRoot
try {
    python tools/head_config.py generate $configPath --out $out
    if($LASTEXITCODE -ne 0) {throw 'Invalid profile'}
    python tools/head_config.py activate-build $configPath
    if($LASTEXITCODE -ne 0) {throw 'Header activation failed'}
    $pending=Join-Path $out 'build_pending.json'
    python tools/head_config.py begin-build $configPath --out $pending
    if($LASTEXITCODE -ne 0) {throw 'Build tracking failed'}
    & tools/tests/run_profile_spi.ps1 -Config $configPath -OutFolder (Join-Path $headRoot 'tools\tests\_work\selected') -VivadoBin $VivadoBin
    Push-Location testbench/scoreboard
    try {
        & (Join-Path $VivadoBin 'vivado.bat') -mode batch -source check_rtl_elaboration.tcl -log rtl_elaboration.log -journal rtl_elaboration.jou
        if($LASTEXITCODE -ne 0) {throw 'RTL synthesis elaboration failed'}
    } finally {Pop-Location}
    $manifest=Get-Content (Join-Path $out 'manifest.json') -Raw | ConvertFrom-Json
    $baseline=Get-Content config/scoreboard_baseline.json -Raw | ConvertFrom-Json
    $simulation=Join-Path $headRoot 'tools\tests\profile_simulation.log'
    if($manifest.build_sha256 -eq $baseline.build_sha256) {
        & testbench/scoreboard/run_all.ps1 -VivadoBin $VivadoBin -UseSavedMatlabVectors -SkipElaboration
        $simulation=Join-Path $headRoot 'testbench\scoreboard\top_scoreboard_simulation.log'
    } else {
        Write-Output 'Non-default build: SPI integration and RTL elaboration checked. A head-specific closed-loop numerical regression is still required.'
    }
    python tools/head_config.py finish-build --pending $pending --simulation-log $simulation --elaboration-log testbench/scoreboard/rtl_elaboration.log
    if($LASTEXITCODE -ne 0) {throw 'Build receipt rejected'}
    python tools/head_config.py generate $configPath --out $out
    if($LASTEXITCODE -ne 0) {throw 'Final profile generation failed'}
    python tools/head_config.py check $configPath
    if($LASTEXITCODE -ne 0) {throw 'Profile does not match completed RTL build'}
} finally {Pop-Location}
