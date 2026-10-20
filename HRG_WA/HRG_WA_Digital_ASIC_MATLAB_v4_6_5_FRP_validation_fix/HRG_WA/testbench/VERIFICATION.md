# Verification record

- Front end: pyslang 11.0.0 (SystemVerilog parser + semantic elaboration)
- Sources: all 14 files under `src` plus `tb_hrg_sensor_if.sv`
- Default timescale supplied to the compiler: `1ns/1ps` (the unmodified SPI
  sources do not declare one)
- Result: **0 errors**, 57 warnings

Warnings are signedness/intentional fixed-point truncation notices plus existing
warnings in the unchanged SPI package (unnamed generate blocks, parameter-width
comparisons and missing final newline). No protocol file was edited to silence
them.

Event-driven simulation was not executed in the delivery environment because
Icarus Verilog, Verilator, Questa and Xcelium were not installed. Run
`run_iverilog.ps1` on a machine with Icarus Verilog to execute the self-checking
testbench.

The copied protocol files were SHA-256 compared with the archive extraction;
all nine comparisons passed byte-for-byte.
