# 半球谐振陀螺 HRG 全角模式可仿真模型

本文件夹给出一个可直接在 MATLAB 中运行的全角模式 HRG 包络/慢变量模型。该模型适合进行：

1. 全角模式角输出仿真；
2. 能量控制、正交控制、虚拟进动控制验证；
3. 频率裂解、阻尼不均匀、驱动通道增益/相位/力轴误差分析；
4. ADC 噪声和量化误差对解调角的影响分析。

## 1. 文件说明

- `run_HRG_WA_demo.m`：主仿真脚本，运行后绘图并保存 `HRG_WA_demo_result.mat`。
- `HRG_WA_params.m`：参数表，包括谐振子、控制器、误差源、输入角速率。
- `HRG_WA_rhs.m`：全角模式慢变量状态方程。
- `HRG_WA_output.m`：二次解调变量、角度和角速率输出。
- `HRG_WA_fast_rhs.m`：可选二阶物理振动模型接口，用于后续接入电极力和真实载波解调。

## 2. 状态变量

慢变量状态定义为：

```text
x = [E, Q, theta, iE, iQ, thetaVirt]^T
```

其中：

- `E = a^2 + q^2`：谐振能量；
- `Q = 2*a*q`：正交变量；
- `theta`：物理驻波方位角；
- `iE`：能量误差积分；
- `iQ`：正交误差积分；
- `thetaVirt`：虚拟进动角积分。

## 3. 核心模型

```text
E_dot = -2*dampMean*E - dTauInv*cos(4*(theta-thetaTau))*E + f_a

Q_dot = -2*dampMean*Q - 2*dOmega*E*sin(4*(theta-thetaOmega)) + f_q

theta_dot = -cBryan*Omega + thetaVirt_dot
            + 0.5*dTauInv*sin(4*(theta-thetaTau))
            + 0.5*dOmega*cos(4*(theta-thetaOmega))*Q/E
            + driveRateError
```

PI 控制律：

```text
f_a = KpE*(E0-E) + KiE*integral(E0-E)
f_q = KpQ*(Q0-Q) + KiQ*integral(Q0-Q)
```

角输出：

```text
input_angle_est = -(theta - theta0 - thetaVirt)/cBryan
```

二次解调变量：

```text
D = sqrt(E^2-Q^2)
S = D*sin(4*theta)
R = D*cos(4*theta)
theta_est = unwrap(atan2(S,R))/4
```

注意：全角 HRG 的检测信号通常包含 `cos(2*theta)` 和 `sin(2*theta)`，而二次解调得到的 `S/R` 中包含 `sin(4*theta)` 和 `cos(4*theta)`，因此驻波角需要除以 4。

## 4. 运行方法

在 MATLAB 当前目录切换到本文件夹，然后运行：

```matlab
run_HRG_WA_demo
```

默认输入角速率为：

```text
0–5 s:     0 deg/s
5–35 s:   +20 deg/s
35–50 s:  -10 deg/s
50–60 s:  0 deg/s
```

理论输入角为 450 deg 左右。脚本会输出最终角误差、RMS 角误差、最大正交量和稳态能量。

## 5. 如何替换为自己的陀螺参数

在 `HRG_WA_params.m` 中修改：

- `p.f0`：谐振频率；
- `p.Qfactor`：品质因数；
- `p.cBryan`：Bryan 因子/进动因子，必须标定；
- `p.err.dTauInv` 与 `p.err.thetaTau`：阻尼不均匀幅值和轴角；
- `p.err.dOmega` 与 `p.err.thetaOmega`：频率裂解和刚度轴角；
- `p.ctrl.KpE/KiE/KpQ/KiQ`：能量与正交 PI 控制器；
- `p.inputOmegaFcn`：输入角速率函数；
- `p.ctrl.virtualRateFcn`：虚拟进动角速率函数。

## 6. 后续扩展

若要建立更接近实物的数字控制系统，可继续加入：

1. PLL/NCO 相位跟踪；
2. C/V 检测增益不对称、相位延迟和温度漂移；
3. DAC/ADC 量化噪声；
4. RLS/Kalman 参数辨识；
5. 频率裂解二力前馈补偿；
6. 阻尼不均匀在线补偿；
7. 分时单通道检测模型。
