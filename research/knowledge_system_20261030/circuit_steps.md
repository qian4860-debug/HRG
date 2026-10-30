## 电路贯通算例：逐节点计算表

本表每个依赖均在上文定义；CSV另存其当时操作数。全部为演示值。

| 节点 | 算式 | 数值 | 单位 |
|---|---|---:|---|
| `pi` | `pi` | 3.14159265359 | 1 |
| `kB` | `SI exact` | 1.380649e-23 | J/K |
| `T` | `assumed input` | 300 | K |
| `carrier_Hz` | `assumed input` | 1000 | Hz |
| `omega` | `2*pi*carrier_Hz` | 6283.18530718 | rad/s |
| `Ct` | `assumed input` | 1e-10 | F |
| `Cf` | `assumed input` | 1e-11 | F |
| `noise_gain` | `1+Ct/Cf` | 11 | 1 |
| `GBW` | `assumed single-pole input` | 10000000 | Hz |
| `closed_bandwidth` | `GBW/noise_gain` | 909090.909091 | Hz |
| `input_noise_target` | `assumed input` | 1e-08 | V/sqrt(Hz) |
| `MOS_noise_gamma` | `long-channel teaching assumption` | 0.666666666667 | 1 |
| `noise_topology_factor` | `teaching assumption` | 2 | 1 |
| `gm_min` | `4*kB*T*MOS_noise_gamma*noise_topology_factor/input_noise_target^2` | 0.00022090384 | S |
| `gm_ID` | `teaching assumption` | 15 | 1/V |
| `input_device_ID` | `gm_min/gm_ID` | 1.47269226667e-05 | A |
| `ADC_bits` | `teaching assumption` | 16 | bit |
| `ADC_span` | `teaching assumption` | 2 | V |
| `ADC_LSB` | `ADC_span/2^ADC_bits` | 3.0517578125e-05 | V |
| `quantization_RMS` | `ADC_LSB/sqrt(12)` | 8.80966597274e-06 | V |
| `sample_C_min` | `kB*T/quantization_RMS^2` | 5.33685807203e-11 | F |
| `acquisition_time` | `teaching assumption` | 2e-06 | s |
| `settling_constants` | `(ADC_bits+1)*ln(2)` | 11.7835020695 | 1 |
| `acquisition_tau_max` | `acquisition_time/settling_constants` | 1.6972882834e-07 | s |
| `effective_R_max` | `acquisition_tau_max/sample_C_min` | 3180.31369861 | ohm |
| `ideal_fullscale_SNR` | `10*log10[(ADC_span^2/8)/(ADC_LSB^2/12)]` | 98.090511203 | dB |
| `ADC_signal_peak` | `teaching assumption` | 0.001 | V |
| `signal_fraction` | `ADC_signal_peak/(ADC_span/2)` | 0.001 | 1 |
| `SNR_without_PGA` | `ideal_fullscale_SNR+20*log10(signal_fraction)` | 38.090511203 | dB |
| `PGA` | `teaching assumption` | 100 | 1 |
| `SNR_with_PGA` | `ideal_fullscale_SNR+20*log10(signal_fraction*PGA)` | 78.090511203 | dB |
| `DAC_rate` | `teaching assumption` | 40000 | sample/s |
| `DAC_Ts` | `1/DAC_rate` | 2.5e-05 | s |
| `hold_argument` | `pi*carrier_Hz*DAC_Ts` | 0.0785398163397 | rad |
| `hold_magnitude` | `sin(hold_argument)/hold_argument` | 0.998972233249 | 1 |
| `hold_phase_deg` | `-hold_argument*180/pi` | -4.5 | deg |
| `drive_Cp` | `teaching assumption` | 1e-08 | F |
| `drive_Vpeak` | `teaching assumption` | 1 | V |
| `sinusoidal_drive_Ipeak` | `omega*drive_Cp*drive_Vpeak` | 6.28318530718e-05 | A |
| `sinusoidal_min_slew` | `omega*drive_Vpeak` | 6283.18530718 | V/s |
| `startup_step` | `teaching assumption` | 5 | V |
| `startup_rise` | `teaching assumption` | 1e-06 | s |
| `startup_capacitive_current` | `drive_Cp*startup_step/startup_rise` | 0.05 | A |
| `feedthrough_Cds` | `teaching assumption` | 1e-13 | F |
| `feedthrough_Ipeak` | `omega*feedthrough_Cds*drive_Vpeak` | 6.28318530718e-10 | A |
| `motion_charge_peak` | `teaching assumption` | 1e-14 | C |
| `motion_Ipeak` | `omega*motion_charge_peak` | 6.28318530718e-11 | A |
| `noise_filter_pole` | `teaching assumption` | 100 | Hz |
| `filter_ENBW` | `pi*noise_filter_pole/2` | 157.079632679 | Hz |
| `filtered_voltage_RMS` | `input_noise_target*sqrt(filter_ENBW)` | 1.25331413732e-07 | V |
| `reference_charge_step` | `teaching assumption` | 1e-12 | C |
| `reference_decoupling` | `teaching assumption` | 1e-08 | F |
| `reference_instantaneous_step` | `reference_charge_step/reference_decoupling` | 0.0001 | V |
