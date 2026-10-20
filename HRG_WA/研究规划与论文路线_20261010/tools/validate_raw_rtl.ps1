$ErrorActionPreference = 'Stop'
$root = 'C:\Users\11725\Desktop\HRG_WA'
$out = Join-Path $root '研究规划与论文路线_20261010\evidence\rtl_raw_frontend'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Set-Location $out
$src = Join-Path $root 'hrg_wa_verilog_rtl_tb_full_frontend_annotated_fix_qparam'
$files = @(Get-ChildItem (Join-Path $src 'rtl') -File -Filter '*.v' | ForEach-Object { $_.FullName })
$files += @(Get-ChildItem (Join-Path $src 'tb') -File -Filter '*.sv' | ForEach-Object { $_.FullName })
$bin = 'D:\vivado\2025.1\Vivado\bin'
& (Join-Path $bin 'xvlog.bat') --sv $files 2>&1 | Tee-Object -FilePath (Join-Path $out 'compile_console.txt')
if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
& (Join-Path $bin 'xelab.bat') tb_hrg_wa_full_top -s report_raw_tb --timescale 1ns/1ps 2>&1 | Tee-Object -FilePath (Join-Path $out 'elaborate_console.txt')
if ($LASTEXITCODE -ne 0) { throw 'xelab failed' }
& (Join-Path $bin 'xsim.bat') report_raw_tb -runall 2>&1 | Tee-Object -FilePath (Join-Path $out 'simulation_console.txt')
if ($LASTEXITCODE -ne 0) { throw 'xsim failed' }