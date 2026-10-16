# HRG sensor-interface synthesizable RTL

This directory implements the synthesizable sensor-side digital chain specified
by the V4.6.5 MATLAB model. The top level is `src/hrg_sensor_if_top.v`.

## Implemented hardware boundary

- signed 18-bit, two-channel ADC interface with `adc_valid_i`;
- 32-bit phase-accumulator / 18-bit amplitude NCO;
- four mixers, three-stage CIC with R=40/M=1, and shared five-tap
  `[1 2 3 2 1]/9` FIR;
- V4.6.5 E/Q/R/S/L invariant equations and Q formats;
- 18-iteration vectoring CORDIC and continuous angle/rate code generation;
- energy and quadrature PI control, anti-windup by conditional integration,
  command limiting, and three-control-cycle actuator pipeline;
- three signed 16-bit DAC interfaces;
- status/snapshot/realtime telemetry through the supplied SPIRegPG2 protocol.

The MATLAB plant, noise injection, Monte-Carlo code, offline metrics, Kalman
floating-point reference, online RLS/EKF calibration and FRP training/oracle are
verification algorithms, not part of this sensor-interface synthesis boundary.
Their observability hooks remain available through E/Q/R/S/L, phase, rate and
status outputs; a production implementation may add those blocks after their
fixed-point formats and safety requirements are frozen.

## Clocking and numeric conventions

`clk` is the ASIC system clock. `adc_valid_i` must pulse for one `clk` period at
40 kS/s. The default FCW is `0x20000000`, corresponding to 5 kHz at 40 kS/s.
The control output rate is therefore 1 kHz. ADC input codes use Q2.16, demodulated
outputs Q6.22, invariants Q8.24, and control commands Q6.22.

## SPI protocol and register adaptation

Files under `src/spi_original/` are byte-identical copies of the relevant files
from `Vlg_SPIReg-master.zip`; no source line in those files was changed. The
original protocol has a 7-bit byte address and three 112-byte pages rather than
the MATLAB model's suggested 16-bit APB/AXI-Lite address. Page selection remains
the protocol's extended byte `0x70`. Consequently, the core page-0 byte offsets
are retained directly, and pages 1/2 are reserved for calibration/advanced
extensions.

Page-0 implemented fields (little-endian 32-bit words):

| Byte offset | Name | Encoding |
|---:|---|---|
| `0x00` | CTRL | bit0 global, bit1 energy PI, bit2 quadrature PI, bit3 virtual |
| `0x28` | ENERGY_KP | signed Q16.16; zero selects model default 2.4 |
| `0x2C` | ENERGY_KI | signed Q16.16; zero selects model default 0.35 |
| `0x30` | QUAD_KP | signed Q16.16; zero selects model default 7.0 |
| `0x34` | QUAD_KI | signed Q16.16; zero selects model default 1.4 |
| `0x40` | ENERGY_REF | signed Q8.24; zero selects model default 1.0 |
| `0x44` | VIRTUAL_RATE | signed Q6.22 |
| `0x50` | NCO_FCW | unsigned; zero selects `0x20000000` |

Snapshot read-only bytes `0x71..0x7F` carry `{phase4[23:0], Q, E, STATUS}`
from least-significant byte upward. Command `0xF0` uses the original realtime
packet formatter and CRC-8 implementation; its payload is phase, temperature and
update flags.

## Verification

`testbench/tb_hrg_sensor_if.sv` is self-checking. It writes CTRL through the
actual SPI pins, applies a coherent 5 kHz two-axis carrier, waits through CIC/FIR
startup, and checks output cadence, energy, CORDIC quadrant, status and overflow.

With Icarus Verilog installed:

```powershell
cd HRG_WA/testbench
./run_iverilog.ps1
```

For another simulator, compile `testbench/filelist.f` with SystemVerilog enabled.

## Model equivalence scoreboard (2026-10-15)

An executed XSim scoreboard is available under `testbench/scoreboard/`.
See [the verification report](testbench/scoreboard/README_等价性验证报告.md)
for coverage, numeric differences, logs and reproduction commands.
The existing implementation checks pass in the tested scenarios, but strict
comparison against the original MATLAB front end fails (1698 differing fields
across 350 transactions). The original coherent-carrier smoke test passing does
not establish model equivalence. `run_scoreboard.ps1` defaults to strict mode
and reports this failure; `-ImplementationOnly` is an explicitly narrower check.
