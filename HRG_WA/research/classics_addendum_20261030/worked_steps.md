### 自动展开的标量计算痕迹

每一行先使用上方已定义的量；CSV另存每个依赖的当时数值，避免只留最终结果。下面的输入用于复算方法，不是制造商参数。

| 节点 | 算式 | 数值 | 单位 |
|---|---|---:|---|
| `pi` | `pi` | 3.14159265359 | 1 |
| `deg_to_rad` | `pi/180` | 0.0174532925199 | rad/deg |
| `rad_s_to_deg_h` | `180*3600/pi` | 206264.806247 | deg/h per rad/s |
| `f0` | `input` | 1000 | Hz |
| `mass` | `input` | 0.0001 | kg |
| `amplitude` | `input` | 1e-06 | m |
| `Q` | `input` | 10000 | 1 |
| `B` | `input` | 0.27699 | 1 |
| `full_split_Hz` | `input` | 0.2 | Hz |
| `theta` | `50*deg_to_rad` | 0.872664625997 | rad |
| `theta_G` | `20*deg_to_rad` | 0.349065850399 | rad |
| `theta_H` | `-10*deg_to_rad` | -0.174532925199 | rad |
| `input_rate` | `30*deg_to_rad` | 0.523598775598 | rad/s |
| `damping_half_difference` | `input` | 1e-05 | 1/s |
| `alignment_leak` | `input` | 1e-05 | 1 |
| `phase_leak` | `input` | 2e-05 | rad |
| `drive_coupling` | `input` | 2e-05 | N/V |
| `sense_coupling` | `input` | 1e-08 | C/m |
| `Cf` | `input` | 1e-11 | F |
| `Rf` | `input` | 1000000000 | ohm |
| `omega0` | `2*pi*f0` | 6283.18530718 | rad/s |
| `alpha` | `2*B` | 0.55398 | 1 |
| `gamma` | `omega0/(2*Q)` | 0.314159265359 | 1/s |
| `tau_amplitude` | `1/gamma` | 3.18309886184 | s |
| `split_half_rate` | `pi*full_split_Hz` | 0.628318530718 | rad/s |
| `double_angle_G` | `2*(theta-theta_G)` | 1.0471975512 | rad |
| `double_angle_H` | `2*(theta-theta_H)` | 2.09439510239 | rad |
| `cosG` | `cos(double_angle_G)` | 0.5 | 1 |
| `sinG` | `sin(double_angle_G)` | 0.866025403784 | 1 |
| `cosH` | `cos(double_angle_H)` | -0.5 | 1 |
| `sinH` | `sin(double_angle_H)` | 0.866025403784 | 1 |
| `Ca` | `gamma+damping_half_difference*cosG` | 0.314164265359 | 1/s |
| `Cq` | `split_half_rate*sinH` | 0.54413980927 | 1/s |
| `natural_detuning` | `split_half_rate*cosH` | -0.314159265359 | rad/s |
| `bias_damping` | `damping_half_difference*sinG` | 8.66025403784e-06 | rad/s |
| `bias_amplitude_leak` | `alignment_leak*Ca` | 3.14164265359e-06 | rad/s |
| `bias_quadrature_leak` | `phase_leak*Cq` | 1.08827961854e-05 | rad/s |
| `bias_electrical` | `bias_damping+bias_amplitude_leak+bias_quadrature_leak` | 2.26846928768e-05 | rad/s |
| `bias_body` | `-bias_electrical/alpha` | -4.09485773437e-05 | rad/s |
| `bias_body_deg_h` | `bias_body*rad_s_to_deg_h` | -8.44625037188 | deg/h |
| `WA_theta_dot` | `-alpha*input_rate+bias_electrical` | -0.290040565013 | rad/s |
| `WA_estimated_body_rate` | `-WA_theta_dot/alpha` | 0.523557827021 | rad/s |
| `force_normalization` | `2*mass*amplitude*omega0` | 1.25663706144e-06 | N per 1/s |
| `amplitude_force_peak` | `force_normalization*Ca` | 3.94790459229e-07 | N |
| `quadrature_force_peak` | `force_normalization*abs(Cq)` | 6.83786250932e-07 | N |
| `amplitude_voltage_peak` | `amplitude_force_peak/drive_coupling` | 0.0197395229614 | V |
| `quadrature_voltage_peak` | `quadrature_force_peak/drive_coupling` | 0.0341893125466 | V |
| `sense_charge_peak` | `sense_coupling*amplitude` | 1e-14 | C |
| `ideal_charge_output_peak` | `sense_charge_peak/Cf` | 0.001 | V |
| `omega_Rf_Cf` | `omega0*Rf*Cf` | 62.8318530718 | 1 |
| `charge_response_magnitude` | `omega_Rf_Cf/sqrt(1+omega_Rf_Cf^2)` | 0.999873372576 | 1 |
| `actual_charge_output_peak` | `ideal_charge_output_peak*charge_response_magnitude` | 0.000999873372576 | V |
| `charge_phase_offset` | `atan(1/omega_Rf_Cf)` | 0.0159141506995 | rad |
| `single_body_bias_budget` | `0.01/rad_s_to_deg_h` | 4.8481368111e-08 | rad/s |
| `single_electrical_bias_budget` | `alpha*single_body_bias_budget` | 2.68577083061e-08 | rad/s |
| `max_single_alignment_leak` | `single_electrical_bias_budget/abs(Ca)` | 8.5489380135e-08 | 1 |
| `max_single_phase_leak` | `single_electrical_bias_budget/abs(Cq)` | 4.93581021799e-08 | rad |
| `max_differential_timing_skew` | `max_single_phase_leak/omega0` | 7.85558594356e-12 | s |
| `J08_phase_ratio` | `10000*1000/[10*(1000^2-10000^2)]` | -0.010101010101 | 1 |
| `J08_literal_phase` | `atan(J08_phase_ratio)` | -0.0101006665853 | rad |
| `J08_literal_inverseQ` | `0.001*J08_literal_phase/(2*pi)` | -1.60757101558e-06 | 1 |
| `J08_loss_magnitude_inverseQ` | `abs(J08_literal_inverseQ)` | 1.60757101558e-06 | 1 |
| `J09_total_inverseQ_rounded` | `1e-7+1.6e-6` | 1.7e-06 | 1 |
| `J09_Q_global` | `1/J09_total_inverseQ_rounded` | 588235.294118 | 1 |
| `J09_exact_maintenance_deg_s` | `180*10000*J09_total_inverseQ_rounded` | 3.06 | deg/s |
| `J09_approx_maintenance_deg_s` | `180*10000*1.6e-6` | 2.88 | deg/s |
