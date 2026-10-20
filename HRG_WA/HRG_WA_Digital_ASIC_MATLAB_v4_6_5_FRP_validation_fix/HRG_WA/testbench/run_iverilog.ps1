$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    iverilog -g2012 -I ../src -s tb_hrg_sensor_if -o hrg_tb.vvp -c filelist.f
    if($LASTEXITCODE -ne 0) {throw 'Icarus compile failed'}
    vvp hrg_tb.vvp
} finally {
    Pop-Location
}
