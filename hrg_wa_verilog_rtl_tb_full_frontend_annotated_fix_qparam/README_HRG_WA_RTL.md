# HRG 全角模式完整 RTL/Testbench 模型

本代码包在上一版 `E/Q/S/R` 接口级模型基础上，继续增加了原始检测采样级数字前端，形成完整链路：

```text
raw ADC x/y
 -> NCO sin/cos reference
 -> IQ mixer
 -> 3rd-order CIC decimator
 -> 5-tap FIR low-pass
 -> Cx/Sx/Cy/Sy
 -> E/Q/S/R calculation
 -> CORDIC atan2(S,R)
 -> phase unwrap and whole-angle output
 -> rate output LPF
 -> energy/quadrature PI control
 -> DAC fa/fq
 -> plant model feedback
```

## 目录

```text
rtl/
  hrg_nco_sincos.v          32-bit NCO + 256-point sin/cos ROM, synthesizable
  hrg_iq_mixer.v            x/y 与 sin/cos 参考同步混频，synthesizable
  hrg_cic_decimator.v       三阶 CIC 抽取低通，synthesizable
  hrg_fir5_lpf.v            5-tap FIR 低通，synthesizable
  hrg_eqsr_calc.v           Cx/Sx/Cy/Sy 到 E/Q/S/R 计算，synthesizable
  hrg_demod_frontend.v      NCO/IQ/CIC/FIR/EQSR 数字前端顶层，synthesizable
  hrg_cordic_atan2.v        CORDIC atan2(S,R)，synthesizable
  hrg_pi_ctrl.v             PI 控制器，synthesizable
  hrg_phase_angle_rate.v    相位展开、角度/速率输出，synthesizable
  hrg_wa_if_top.v           E/Q/S/R 接口级核心，synthesizable
  hrg_wa_full_top.v         raw ADC 到控制输出的完整顶层，synthesizable

tb/
  hrg_wa_plant_model.sv       E/Q/S/R 慢变量 plant，旧版接口级 TB 使用
  hrg_wa_raw_plant_model.sv   原始载波级 x/y plant，完整链路 TB 使用
  tb_hrg_wa_if_top.sv         旧版 E/Q/S/R 接口级 TB
  tb_hrg_wa_full_top.sv       新增完整 raw-front-end TB
```

## 推荐仿真入口

完整链路仿真使用：

```bash
iverilog -g2012 -f tb_filelist.f -s tb_hrg_wa_full_top -o sim_full
vvp sim_full
```

或在 Questa/ModelSim 中：

```tcl
vlog -f tb_filelist.f
vsim tb_hrg_wa_full_top
run -all
```

仿真会生成：

```text
tb_hrg_wa_full_output.csv
```

CSV 包含输入角速度、输入角度、RTL 输出角度/速率、E/Q/S/R、Cx/Sx/Cy/Sy、控制量和状态字，可用于和 MATLAB golden model 对比。

## 默认采样配置

默认 testbench 使用：

```text
raw ADC sample rate : 64 kHz
NCO carrier         : 8 kHz
CIC decimation R    : 64
control/EQSR rate   : 1 kHz
```

因此 NCO 相位增量为：

```verilog
cfg_nco_phase_inc = 32'h2000_0000; // 2^32 / 8
```

## 定点格式

```text
raw adc_x/y   : signed Q1.15
sin/cos ref   : signed Q1.15
mixer output  : signed Q2.30
Cx/Sx/Cy/Sy   : signed Q2.30
E/Q/S/R       : signed Q2.30
fa/fq         : signed Q2.30
angle_out     : signed 64-bit binary-turn，2^32 = 360 deg
rate_out      : signed Q16.16 deg/s
```

## E/Q/S/R 计算关系

同步解调后：

```text
Cx = LPF(2*x*cos_ref)
Sx = LPF(2*x*sin_ref)
Cy = LPF(2*y*cos_ref)
Sy = LPF(2*y*sin_ref)
```

然后：

```text
E = Cx^2 + Sx^2 + Cy^2 + Sy^2
Q = 2*(Cx*Sy - Cy*Sx)
R = Cx^2 + Sx^2 - Cy^2 - Sy^2
S = 2*(Cx*Cy + Sx*Sy)
```

对于 HRG 二阶模态：

```text
atan2(S,R) = 4*theta
```

再由 `hrg_phase_angle_rate.v` 完成相位展开、驻波角换算和 Bryan 因子输出角度。

## 工程说明

1. 当前 `hrg_nco_sincos.v` 使用 256 点 ROM，适合 FPGA 原型和 ASIC ROM 估算；若 ASIC 面积更敏感，可替换为 CORDIC/NCO 相位旋转器。
2. 当前 `hrg_cic_decimator.v` 默认 R=64、三阶，归一化移位为 18 位，即除以 64^3。
3. 当前 FIR 是简单 `[1 4 6 4 1]/16`，用于功能验证；实际芯片可根据噪声带宽和相位延迟重新设计 FIR 系数。
4. 完整顶层 `hrg_wa_full_top.v` 是可综合的数字链路；`tb/*.sv` 中 plant 和统计部分不可综合，仅用于验证。


## 详细注释版说明

本压缩包在原 RTL/testbench 基础上只增加中文注释，保持所有文件名、模块名、端口名和调用层次不变。注释重点覆盖：

- NCO 相位累加与 sin/cos 参考生成；
- IQ 同步混频与 Cx/Sx/Cy/Sy 基带量含义；
- CIC 抽取低通与 FIR 平滑低通；
- E/Q/S/R 的全角模式物理意义；
- CORDIC `atan2(S,R)=4θ` 角度解算；
- 4θ 相位展开、RUN 清零、Bryan 因子补偿、角速度低通；
- 能量环 PI、正交环 PI、状态机与状态字；
- 慢变量 plant testbench 和原始载波级 plant testbench 的区别。

这些注释用于后续 FPGA/ASIC RTL 设计评审、论文说明和 testbench 维护，不改变可综合逻辑。


## 正交控制符号与参数检查修正说明

本版本保持所有文件名、模块名、端口名和主逻辑结构不变，只调整 testbench 中正交环配置参数。

检查结论：
- `q_err = cfg_q_set - adc_q`，当 `Q < 0` 时 `q_err > 0`。
- plant 中 `dQ = ... + fq`，因此 `fq > 0` 会推动 `Q` 向正方向变化。
- 所以正交控制符号方向是正确的，不应反接。

原始参数中 `KpQ=0.750`、`KiQ=0.00100` 对当前完整 RAW 前端模型偏激进，叠加前端解调延迟、CIC/FIR 群延迟和启动瞬态后，容易造成 `fq_pi/dac_fq` 撞限幅，`fq_sat=1`，最终 `status_word=0xA`。

修正参数：
- `cfg_kp_q`：0.750 -> 0.300
- `cfg_ki_q`：0.00100 -> 0.00008
- `cfg_fq_limit`：0.180 -> 0.250
- `cfg_integ_limit`：0.150 -> 0.120，兼顾能量环稳态补能和正交环抗 wind-up

重新仿真时重点观察：
- `dut.u_core.q_err` 应逐渐靠近 0；
- `dut.u_core.fq_pi` / `dut.dac_fq` 不应长期贴限幅；
- `dut.u_core.fq_sat` 在 RUN 稳态应为 0 或只短暂脉冲；
- `dut.eqsr_q` 或 `q_out` 应从约 -0.04 收敛到更接近 0，目标 `|Q| < 0.02`；
- 最终 `status_word` 目标为 `0x00000003`。
