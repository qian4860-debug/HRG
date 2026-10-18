# Syntax/synthesis RTL elaboration only. This example FPGA part is a tool
# requirement, not a selected product target or a timing/resource signoff.
set src [file normalize [file join [file dirname [info script]] .. .. src]]
set_property include_dirs [list $src] [current_fileset]
foreach f [glob [file join $src spi_original *.v]] {read_verilog $f}
foreach f [glob [file join $src *.v]] {read_verilog $f}
synth_design -rtl -top hrg_sensor_if_top -part xc7a35tcpg236-1
puts "HRG_RTL_ELABORATION_PASS"
close_design
