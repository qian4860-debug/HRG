$ErrorActionPreference = 'Stop'
$root = 'C:\Users\11725\Desktop\HRG_WA'
$out = Join-Path $root '研究规划与论文路线_20261010\evidence\rtl_sensor_if'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Set-Location $out
$src = Join-Path $root 'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix\HRG_WA'
$files = @(Get-ChildItem (Join-Path $src 'src') -Recurse -File -Filter '*.v' | ForEach-Object { $_.FullName })
$files += Join-Path $src 'testbench\tb_hrg_sensor_if.sv'
$bin = 'D:\vivado\2025.1\Vivado\bin'
& (Join-Path $bin 'xvlog.bat') --sv $files 2>&1 | Tee-Object -FilePath (Join-Path $out 'compile_console.txt')
if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
& (Join-Path $bin 'xelab.bat') tb_hrg_sensor_if -s report_sensor_tb --timescale 1ns/1ps 2>&1 | Tee-Object -FilePath (Join-Path $out 'elaborate_console.txt')
if ($LASTEXITCODE -ne 0) { throw 'xelab failed' }
& (Join-Path $bin 'xsim.bat') report_sensor_tb -runall 2>&1 | Tee-Object -FilePath (Join-Path $out 'simulation_console.txt')
if ($LASTEXITCODE -ne 0) { throw 'xsim failed' }