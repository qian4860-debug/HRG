$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    iverilog -g2012 -s tb_hrg_sensor_if -o hrg_tb.vvp -c filelist.f
    vvp hrg_tb.vvp
} finally {
    Pop-Location
}
