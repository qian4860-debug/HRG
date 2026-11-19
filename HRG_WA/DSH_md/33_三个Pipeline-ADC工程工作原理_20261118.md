# 33 · 三个 Pipeline ADC 工程的工作原理

2026-11-18。对象：

- `techrevzwb/LTC2217a`（LTC2217，16 位 105 Msps）
- `techrevzwb/LTC2255_pipeline`（LTC2255，14 位 125 Msps）
- `techrevzwb/pipeline/Pipelined_ADC`（SMIC 180 nm 的 1.5 位/级流水线原型/测试核）

本文按“系统框图 → 单级残留传递 → 时序 → 数字校正 → 具体单元”讲。Cadence OA 的 `sch.oa` 是二进制，不能像网表一样逐线读取；本文用 **数据手册 + OA 层次中的单元名/引脚名/实例名 + 测试台变量** 还原原理。凡是数据手册没有明说、由层次推断的位分配，文中标“推断”。

---

## 0. 先讲通用 Pipeline ADC：每一级到底做什么

### 0.1 一级流水线的三个动作

每一级（stage）对输入做三件事：

1. **粗量化**：用一个低位数 flash ADC 把输入量化成 \(D_i\)。
2. **重建/相减**：用 DAC 把 \(D_i\) 变回模拟电压，从输入中减掉，得到残差 \(V_{res}\)。
3. **残差放大**：把残差乘以级间增益 \(G_i\)，送到下一级。

写成公式：

\[
V_{res,i}=G_i\left(V_{in,i}-V_{DAC,i}\right)
\]

\[
V_{DAC,i}=D_i\cdot\frac{V_{ref}}{2^{b_i}},\qquad G_i=2^{b_i-1}
\]

其中 \(b_i\) 是该级 flash 的位数，\(D_i\) 是该级的二进制码（0…\(2^{b_i}-1\)）。取 \(G_i=2^{b_i-1}\) 而不是 \(2^{b_i}\)，是故意让残差只占下一级满量程的一半，留出**冗余范围**给比较器失调、DAC 建立误差和残差放大器误差。

### 0.2 为什么是“流水线”

第 \(i\) 级在放大残差时，第 \(i+1\) 级正在采样/量化这个残差；同时第 \(i-1\) 级已经在处理下一个样本。于是：

- **吞吐率**：流水线填满后，每个时钟输出一个样本。
- **延迟**：单个样本要穿过所有级，延迟是若干时钟，不是 1 个时钟。
- **速度瓶颈**：每一级只做低位数 flash + 残差放大，比单级 14/16 位 SAR 的 14/16 次比较快得多。

### 0.3 数字误差校正

各级的输出码不是简单拼接，而是按“重叠位”对齐后相加。若每级有 1 位重叠：

\[
N=b_1+\sum_{i=2}^{S}(b_i-1)
\]

- 5 级、每级 4 位、1 位重叠：\(N=4+4\times3=16\)。
- 6 级、首级 4 位、其余 3 位、1 位重叠：\(N=4+5\times2=14\)。
- 6 级 1.5 位/级 + 末级 2 位：\(N=6\times1+2=8\)。

数字校正的作用：如果某一级 flash 的比较器把码判高/判低半个 LSB，残差会偏出 nominal 范围，但仍在冗余范围内；后级把它量化出来，数字端按重叠位相减/相加，就把这个错误修掉。冗余不是无限的：超过半个粗 LSB 的判决错误仍会饱和/错码。

### 0.4 1.5 位/级的特殊之处

1.5 位/级是最常用的教学/低功耗结构：

- 两个比较器，阈值在 \(\pm V_{ref}/4\)。
- 三个码：\(D=-1,0,+1\)。
- 残差增益 \(G=2\)。
- 传递函数：

| 输入范围 | \(D\) | 残差 |
|---|---|---|
| \(V_{in}>+V_{ref}/4\) | \(+1\) | \(2V_{in}-V_{ref}\) |
| \(-V_{ref}/4\le V_{in}\le +V_{ref}/4\) | \(0\) | \(2V_{in}\) |
| \(V_{in}<-V_{ref}/4\) | \(-1\) | \(2V_{in}+V_{ref}\) |

优点：比较器阈值离 0 很远，失调容忍度高；DAC 只有 3 个电平；数字校正简单。缺点：每级只贡献 1 个有效位，级数多。

### 0.5 采样保持（SHA）为什么放在最前面

Pipeline 的第一级在采样时会对输入产生回踢（kickback），而且第一级 flash 和 MDAC 的采样时刻必须一致。SHA 的作用：

- 在时钟沿把输入“冻结”在采样电容上；
- 用缓冲放大器驱动第一级，隔离第一级的开关回踢；
- 保证 flash 和 MDAC 看到同一个 held 电压，避免孔径误差。

LTC2217/LTC2255 都有专用输入 S/H；`pipeline` 工程用自举开关 + OTA 做成 SHA。

---

## 1. LTC2217a：16 位 105 Msps，5 级 4 位流水线

### 1.1 公开指标

| 项目 | 数值 |
|---|---|
| 分辨率 | 16 位 |
| 采样率 | 105 Msps |
| 输入范围 | 2.75 Vpp 差分 |
| SNR/噪声底 | 81.2 dBFS SNR（5 MHz 输入）；81.3 dBFS 噪声底 |
| SFDR | 100 dB（70 MHz 时 >90 dB） |
| INL/DNL | ±3.5 LSB / ±1 LSB，无失码 |
| 抖动 | 85 fs RMS |
| S/H 带宽 | 400 MHz 全功率带宽 |
| 电源/功耗 | 3.3 V，1.19 W |
| 输出 | LVDS 或 CMOS；可选数据随机化 |
| 特殊功能 | 内部 dither、时钟占空比稳定器、修调/校准 |

数据手册明确：**5 个 pipelined ADC 级，采样后 7 个时钟给出结果**。

### 1.2 顶层框图

```text
AIN+ / AIN-
   │
   ▼
┌──────────────┐
│  Input S/H   │  SH_AMP + SH_CMFB + SH_BIAS + SH_CLK_GEN
│  (采样保持)   │  采样电容 + 缓冲放大器
└──────┬───────┘
       │ held Vin
       ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Stage 1     │──▶│  Stage 2     │──▶│  Stage 3     │──▶│  Stage 4     │──▶│  Stage 5     │
│ 4b flash     │   │ 4b flash     │   │ 4b flash     │   │ 4b flash     │   │ 4b flash     │
│ 4b DAC       │   │ 4b DAC       │   │ 4b DAC       │   │ 4b DAC       │   │ (final)      │
│ G=8 residue  │   │ G=8 residue  │   │ G=8 residue  │   │ G=8 residue  │   │ no residue   │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │                  │                  │
       └──────────────────┴──────────────────┴──────────────────┴──────────────────┘
                                      │
                                      ▼
                           ┌─────────────────────┐
                           │ Digital correction  │  延迟对齐 + 1 位重叠相加
                           │ + output drivers    │  LVDS/CMOS, randomizer
                           └─────────────────────┘

参考/偏置：REFERENCE_CIRCUIT, VREF_GEN, VCM_GEN, VBIAS, REGULATOR
时钟：CLOCK_DRIVER, CLK_STABILIZER, CLOCK_LATCH, CLK_BUF
修调：TRIMMING_CTRL, TRIMMING_CALIBRATION1..5, FUSE_SEL
抖动：DAC_RES_1/2 + PRBS；输出随机化
```

### 1.3 单级工作原理

以 Stage 1 为例：

1. **采样**：`BOOTSTRAP1` 驱动采样开关，把 S/H 输出采到 `pipcap`（流水线电容阵列）上。
2. **粗量化**：`FLASH_ADC1` 用电阻串 + 比较器阵列把输入量化成 4 位；`DEC_1` 把温度计码编码成 `DEC_A0…A4`。这 5 条判决线对应 **4 位 + 1 位冗余/超范围**（推断）。
3. **重建/相减**：`RESIDUE_CALCULUS1` 根据 flash 码把电容阵列接到 \(V_{ref}\) 或地，完成“减去 \(D_iV_{ref}/16\)”（4 位级）。
4. **残差放大**：`AMP18`（全差分 OTA）把电容阵列上的残差放大 \(G=8\)，输出到下一级的 `pipcap`。
5. **下一级**：Stage 2 在相反的时钟相位采样这个残差，重复上述过程。

Stage 2–4 结构相同，只是用了 `FLASH_ADC2/3/4`、`RESIDUE_CALCULUS2/3/4`、`AMP13/12/16` 等不同实例。Stage 5 只有 `FLASH_ADC_5`，对第四级残差做最终 4 位量化，不再产生残差。

### 1.4 时序：5 级、7 个时钟

数据手册的时序：

```text
ENC:   ____/‾‾‾‾\____/‾‾‾‾\____
S/H:   sample | hold  | sample | hold
Stage1:       acquire | residue → Stage2
Stage2:               acquire | residue → Stage3
Stage3:                       acquire | residue → Stage4
Stage4:                               acquire | residue → Stage5
Stage5:                                       final flash
Output: 7 个时钟后有效
```

- `ENC` 低：输入采样到 S/H 电容。
- `ENC` 低→高：保持，S/H 缓冲驱动 Stage 1。
- `ENC` 高：Stage 1 采集；`ENC` 高→低：Stage 1 产生残差，Stage 2 采集。
- 奇/偶级交替，5 级流水线填满后每时钟出一个样本。
- 延迟 7 个时钟：S/H + 5 级 + 输出/校正流水。

### 1.5 数字校正与码权

按 16 位、5 级、每级 4 位、1 位重叠推断：

\[
D_{out}=D_1\cdot2^{12}+D_2\cdot2^9+D_3\cdot2^6+D_4\cdot2^3+D_5
\]

其中每个 \(D_i\) 是 4 位码，但相邻级有 1 位重叠；数字端先按流水延迟对齐，再把重叠位处理掉。实际码权由 `ERROR_CORRECT_1/2` 和 `CORRECTION LOGIC` 决定，不能用简单拼接代替。

### 1.6 校准、修调、dither

从层次看，LTC2217 不是“纯数字后台校准”结构，而是：

- **首级/次级校准**：`FIRST_STAGE_CALIBRATION`、`SECOND_STAGE_CALIBRATION`，用于修首级/次级的增益、失调或电容失配。
- **修调控制**：`TRIMMING_CTRL`、`TRIMMING_CALIBRATION1..5`、`FUSE_SEL`，说明有出厂修调/熔丝选择。
- **S/H 校准**：`SH_CALIBRATION`、`SH_CALIBRATION2`。
- **内部 dither**：`DAC_RES_1/2` 由 PRBS 驱动，叠加在 S/H 输出上，再在数字端减掉；目的是打散量化/INL 与输入的相关性，把杂散变成白噪声。数据手册明确这是可选内部 dither。
- **输出随机化**：可选 data output randomizer，降低输出码的频谱相关性。

这些手段解决的是：电容失配、比较器失调、残差放大器有限增益、量化与输入相关导致的 SFDR 退化。它们不是“提高分辨率”的魔法，而是把 16 位系统的线性度做到 100 dB SFDR。

### 1.7 为什么用 5 级 4 位

- 4 位 flash 只有 15 个比较器，比 5/6 位 flash 简单，负载小，速度快。
- 4 位 DAC 的电容阵列不大，容易匹配；每级 1 位重叠，容忍半个粗 LSB 的误差。
- 5 级即可达到 16 位，延迟 7 个时钟；对 105 Msps 来说，66.7 ns 延迟，吞吐仍是 105 Msps。
- 代价：每级都有 OTA，功耗 1.19 W；这是 16 位 105 Msps 的功耗墙。

---

## 2. LTC2255_pipeline：14 位 125 Msps，6 级流水线

### 2.1 公开指标

| 项目 | 数值 |
|---|---|
| 分辨率 | 14 位 |
| 采样率 | 125 Msps（LTC2254 为 105 Msps） |
| 输入范围 | 1 Vpp–2 Vpp 可选 |
| SNR | 72.4 dB（5 MHz） |
| SFDR | 88 dB（5 MHz） |
| INL/DNL | ±1 LSB / ±0.5 LSB，无失码 |
| S/H 带宽 | 640 MHz 全功率带宽 |
| 电源/功耗 | 3 V，395 mW |
| 时钟 | 单端 CLK；可选占空比稳定器 |
| 输出 | 14 位 CMOS，偏移二进制/二进制补码 |

数据手册明确：**6 个 pipelined ADC 级，采样后 5 个时钟给出结果**。

### 2.2 顶层框图

```text
AIN+ / AIN-
   │
   ▼
┌──────────────┐
│  INPUT_SH    │  差分采样电容 + S/H 放大器
│  (输入S/H)   │  640 MHz 全功率带宽
└──────┬───────┘
       │
       ▼
┌─────────────────────────────┐
│  PIPELINED_ADC_STAGE1       │
│  ADC1 (4b flash)            │
│  DAC1 (4b switched-cap)     │
│  AMPLIFIER1 (residue OTA)   │
│  ENC1, CLK_BUF1             │
└──────┬──────────────────────┘
       │ residue
       ▼
┌─────────────────────────────┐
│  PIPELINED_ADC_STAGE2       │
│  ADC2 (3b flash, final)     │
│  ENC2, CLK_BUF2             │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────┐
│ Correction logic    │ 延迟对齐 + 1 位重叠
│ Output drivers      │ 14 位 CMOS
└─────────────────────┘

参考：FLEXIBLE_REFERENCE, BANDGAP, BG_AMP, REF_BUF, RANGE_SELECT, BYPASS
偏置/时钟：BIAS1/2, CLK_BUF, CLK_BUF1/2, CMFB
```

### 2.3 6 级从哪里来

数据手册说 6 级，但当前 OA 顶层只有两个 `PIPELINED_ADC_STAGE` 单元。合理的解释：

- `PIPELINED_ADC_STAGE1` 是“首级 + 后续级”的复用/简化块，内部可包含多级；
- 或者该工程是**部分逆向/部分展开**，只恢复了首级和末级，不能当作完整 6 级链。

从位分配推断：首级 4 位（ADC1 有 15 个比较器输出 OUT1–OUT15），后续 5 级各 3 位（ADC2 有 9 个比较器输出 OUT1–OUT9，含冗余/超范围），每级 1 位重叠：

\[
N=4+5\times(3-1)=14
\]

这与 14 位吻合。实际码权以 `ENC1/ENC2` 和校正逻辑为准。

### 2.4 单级工作原理

以 Stage 1 为例：

1. **输入 S/H**：`INPUT_SH` 在 CLK 低电平时把差分输入采到采样电容；CLK 低→高时保持，缓冲后驱动 Stage 1。
2. **粗量化**：`ADC1` 是 4 位 flash：电阻串产生 15 个阈值，`COMPARATOR` 阵列比较，`ENC1` 编码成 4 位（+冗余）。
3. **重建/相减**：`DAC1` 是开关电容阵列；根据 ADC1 的码，把电容底极板接到 REFH/REFL，完成 \(D_iV_{ref}/16\)（首级 4 位）或 \(D_iV_{ref}/8\)（后续 3 位）的电荷转移。
4. **残差放大**：`AMPLIFIER1` 是全差分 OTA，把残差放大 \(G=8\)（4 位级），送到下一级。
5. **后续级**：3 位级用 \(G=4\)，重复“flash→DAC→residue amp”。
6. **末级**：第 6 级只做 3 位 flash，不再放大。

### 2.5 时序：6 级、5 个时钟

数据手册的时序：

```text
CLK:   ____/‾‾‾‾\____/‾‾‾‾\____
S/H:   sample | hold  | sample | hold
Stage1:       acquire | residue → Stage2
Stage2:               acquire | residue → Stage3
Stage3:                       acquire | residue → Stage4
Stage4:                               acquire | residue → Stage5
Stage5:                                       acquire | residue → Stage6
Stage6:                                               final flash
Output: 5 个时钟后有效
```

- 6 级但延迟 5 个时钟，说明采样/保持、级间相位和输出流水有重叠；不要用“级数=延迟”硬套。
- 级数越多，单级位数越少（3 位），每级更快；LTC2255 的 125 Msps 靠的是“多级 + 低位数 + 占空比稳定”。

### 2.6 数字校正与码权

按“首级 4 位 + 5 个 3 位级 + 1 位重叠”推断：

\[
D_{out}=D_1\cdot2^{10}+D_2\cdot2^{8}+D_3\cdot2^{6}+D_4\cdot2^{4}+D_5\cdot2^{2}+D_6
\]

每个 3 位级贡献 2 个有效位；首级贡献 4 位；总共 14 位。数字端先对齐 6 级码，再处理重叠位；`ENC1/ENC2` 和校正逻辑完成温度计码→二进制、延迟对齐、相加。

### 2.7 时钟占空比稳定器与灵活参考

- **占空比稳定器**：CLK 输入允许 40%–60% 占空比；内部稳定到 50%，保证采样/放大相位对称。CLK 停振一段时间后，稳定器需要重新锁定；数据手册提醒此时要先给足够时钟周期。
- **FLEXIBLE_REFERENCE**：通过 `SENSE`/`RANGE_SELECT` 选择 1 Vpp 或 2 Vpp 输入范围；1 Vpp 通常有更好的 SFDR，2 Vpp 有更好的 SNR。
- **BANDGAP/BG_AMP/REF_BUF**：内部带隙基准、缓冲、旁路（BYPASS）保证 REFH/REFL 低阻。

### 2.8 这个工程的完整性

当前 OA 顶层只有 `PIPELINED_ADC_STAGE1` 和 `PIPELINED_ADC_STAGE2` 两个大块，和 datasheet 的 6 级不一致；`ADC2` 只有 9 个比较器输出，也不是完整 3 位 flash 的 7 个比较器（9 个可能含冗余/超范围）。因此：

- 可以把它当作 **首级 4 位 MDAC + 末级 3 位 flash 的逆向/教学核心**；
- 不能把它当作“完整 6 级 14 位 ADC 的逐管级网表”；
- 6 级、5 周期延迟、14 位码权来自数据手册与层次推断，不是从 OA 逐线提取的。

---

## 3. `pipeline/Pipelined_ADC`：1.5 位/级、100 MS/s 原型/测试核

### 3.1 工程定位

- 工艺：SMIC 180 nm（`smic18mmrf`）。
- 电源：1.8 V；共模约 0.9 V；输入 1 Vpp（测试台 `vin_dc=500m`、`vi_ac=500m`）。
- 采样率：测试台 `fs=100M`。
- FFT：512 点，输入约 6.93 MHz，横轴 0–50 MHz，见 `FFT_analysis.jpg`。
- 结构：SHA + 1.5 位/级流水线 + 末级 flash + 数字校正。
- OTA：`OTA`/`OTA_high_gain`/`OTA_wi_idea_cmfb`，测试台标注 `GBW=920MHz`。

### 3.2 顶层框图

```text
VINP/VINN
   │
   ▼
┌──────────────┐
│  SHA         │  自举开关 + OTA + SC_CMFB
│  (采样保持)   │  底板采样，CLKS/CLKH
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────────┐
│  STAGE_1to6（可复用的 1.5 位/级流水级）      │
│                                             │
│  Bootstrapped_switch → sub_ADC (2 comparators) │
│       │                    │                │
│       │                    ▼                │
│       │              encoder (MSB/LSB)      │
│       ▼                    │                │
│  sub_DAC (3-level switched-cap)             │
│       │                    │                │
│       ▼                    │                │
│  OTA + SC_CMFB → residue → next stage       │
└──────┬──────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│  Flash_ADC   │  末级 2 位 flash（电阻串 + 比较器 + encoder）
└──────┬───────┘
       │
       ▼
┌─────────────────────┐
│  Digital_correction │  DFF 延迟对齐 + 半加/全加器 + 重叠位
│  Output             │
└─────────────────────┘
```

### 3.3 1.5 位级的实际电路

`STAGE_1to6` 里的单元：

- `Bootstrapped_switch`：自举采样开关，保持 \(V_{GS}\) 恒定，降低 Ron 的非线性。
- `sub_ADC`：两个比较器（`comparator` + `pre_amp_comparator`），阈值 \(\pm V_{ref}/4\)，输出温度计码。
- `encoder`：把 2 个比较器输出编码成 `MSB/LSB`（3 个合法码：-1/0/+1）。
- `sub_DAC`：3 电平开关电容 DAC；根据 MSB/LSB 把采样电容底极板接到 REFH/REFL/VCM。
- `OTA`/`OTA_high_gain`/`OTA_wi_idea_cmfb`：全差分残差放大器，闭环增益 2；`SC_CMFB` 做开关电容共模反馈。
- `Switch_comp*`：采样/放大相位开关，保证底板采样和电荷转移。
- `SC_CMFB`：开关电容共模反馈，稳定 OTA 输出共模。
- `SHA`/`OPA_SHA`：采样保持；`SHA_1` 是另一个版本。

### 3.4 单级传递

1. **采样**：自举开关把 \(V_{in}\) 采到 \(C_s\) 上，底板接 \(V_{cm}\)。
2. **比较**：两个比较器判断 \(V_{in}\) 是否大于 \(+V_{ref}/4\) 或小于 \(-V_{ref}/4\)，得到 \(D=-1/0/+1\)。
3. **DAC/相减**：根据 \(D\)，把 \(C_s\) 底极板接到 \(V_{ref+}\)、\(V_{cm}\) 或 \(V_{ref-}\)，在电容上形成 \(V_{in}-D V_{ref}/2\) 的电荷。
4. **残差放大**：OTA 闭环，反馈电容 \(C_f=C_s\)，增益 \(G=C_s/C_f=2\)，输出 \(V_{res}=2(V_{in}-D V_{ref}/2)=2V_{in}-D V_{ref}\)。
5. **下一级**：下一级在相反相位采样 \(V_{res}\)。

数值例子（\(V_{ref}=1V\)）：

- \(V_{in}=0.4V\)：\(D=+1\)，\(V_{res}=0.8-1=-0.2V\)。
- \(V_{in}=0.1V\)：\(D=0\)，\(V_{res}=0.2V\)。
- \(V_{in}=-0.4V\)：\(D=-1\)，\(V_{res}=-0.8+1=0.2V\)。

残差始终在 \(\pm V_{ref}/2\) 内，下一级 1.5 位 flash 可以继续量化。

### 3.5 6 级 + 末级 2 位 flash

按单元推断：

- 6 个 1.5 位级，每级贡献 1 个有效位 → 6 位；
- 末级 `Flash_ADC` 输出 `MSB/LSB` 2 位；
- 总分辨率约 **8 位**。

数字校正：

\[
D_{out}=D_1\cdot2^{7}+D_2\cdot2^{6}+\cdots+D_6\cdot2^{2}+D_7
\]

其中 \(D_i\in\{-1,0,+1\}\)，\(D_7\) 是末级 2 位 flash。`Digital_correction` 用 DFF 对齐 6 级码，用半加/全加器把有符号码相加，处理重叠位。

> 重要：当前 `ADC_TOP` 只实例化了一个 `STAGE_1to6` + 一个 `Flash_ADC`，不是完整的 6 级链。`STAGE_1to6` 的命名和单元结构表明它是“可用于第 1–6 级的 1.5 位级”，但顶层没有把 6 级串起来。因此：
> - 把它当作 **1.5 位级 + SHA + 末级 flash 的原型/测试核**；
> - 不要把它当作已完成的 8 位（更不是 12 位）ADC；
> - 8 位是从“6×1.5b + 2b”推断的设计意图，不是当前顶层已经验证的指标。

### 3.6 时序与时钟

- `CLKS`：采样时钟；`CLKH`：保持/放大时钟；`CLKSA`：SHA 的采样时钟。
- 底板采样：采样时底板接 \(V_{cm}\)，保持时断开，避免信号相关电荷注入。
- 两相不重叠：Stage \(i\) 放大时，Stage \(i+1\) 采样；OTA 的输入/输出相位错开。
- 测试台 `fs=100M`，周期 10 ns；`maxstep=40p`，`tran stop=7u`，512 点 FFT。

### 3.7 这个工程的完整性

- `ADC_TOP` 只有一级 + 末级 flash；完整 6 级链未在当前 schematic 中闭合。
- `Digital_correction` 有大量 DFF/adder，说明设计意图是完整流水线校正；但顶层没有对应 6 级实例。
- `FFT_analysis.jpg` 是 100 MS/s、512 点、约 6.93 MHz 输入的频谱，可用于看 SNDR/SFDR 趋势；不能把它当成完整 8/12 位 ADC 的最终测试报告。

---

## 4. 三者对比

| 项目 | LTC2217a | LTC2255_pipeline | pipeline/Pipelined_ADC |
|---|---|---|---|
| 类型 | 商用 16 位 105 Msps | 商用 14 位 125 Msps | 180 nm 教学/原型核 |
| 流水线级数 | 5 级 | 6 级（datasheet） | 6 级 1.5 位/级（设计意图） |
| 每级位数 | 约 4 位/级（推断） | 首级 4 位 + 后续 3 位（推断） | 1.5 位/级 |
| 级间增益 | 8 | 首级 8，后续 4 | 2 |
| 总位数 | 16 | 14 | 约 8（推断） |
| 输入 S/H | 专用 SH_AMP | 专用 INPUT_SH | 自举开关 + OTA SHA |
| 延迟 | 7 时钟（66.7 ns @105M） | 5 时钟（40 ns @125M） | 约 6 时钟（60 ns @100M，推断） |
| 数字校正 | 延迟对齐 + 1 位重叠 + 修调 | 延迟对齐 + 1 位重叠 | DFF + 半加/全加器 + 重叠位 |
| 校准/修调 | 首级/次级校准、trim、fuse、dither | 工厂 trim、灵活参考、占空比稳定 | 无显式校准，只有数字校正 |
| 参考 | 内部 REFERENCE_CIRCUIT/VREF/VCM | FLEXIBLE_REFERENCE/BANDGAP | vrefp/vrefn 外部 |
| 功耗 | 1.19 W | 395 mW | 未给出完整指标 |
| 工程完整性 | 5 级链基本完整 | 只展开 2 个 stage 块，部分逆向 | 只展开 1 级 + 末级 flash，部分实现 |

---

## 5. 对全角 TDM ADC 的启示（简短）

1. **Pipeline 的速度来自“每级低位数 + 级间并行”**，不是来自单个 OTA 的 GBW。LTC2217 用 5 级 4 位，LTC2255 用 6 级 3 位，都是把比较器/电容的负担拆小。
2. **级间增益 \(G=2^{b-1}\) 是“用 1 位冗余换容差”**；没有冗余，比较器失调/建立误差会直接错码。
3. **SHA 不是可有可无**：它决定孔径、回踢和第一级采样匹配；全角 TDM 的双通道同步尤其需要。
4. **校准/trim 是 16 位/14 位系统达到 80–100 dB SFDR 的关键**；只靠拓扑不够。
5. **Pipeline 的代价是 OTA 功耗和级间记忆**；对 5.44 MS/s、12 位的全角 TDM，是否值得，仍要用“同窗角误差/每有效帧能量”判断，不能只看位宽。

---

## 6. 文件地图

### LTC2217a

```text
techrevzwb/LTC2217a/LTC2217/
├─ Top/schematic/sch.oa                 顶层：5 级 + S/H + 参考/时钟/修调
├─ SH_AMP/                             输入采样保持放大器
├─ FIRST_PIPELINED_ADC_STAGE/          第 1 级：pipcap, FLASH_ADC1, RESIDUE_CALCULUS1, AMP18
├─ SECOND_PIPELINED_ADC_STAGE/         第 2 级
├─ THIRD_PIPELINED_ADC_STAGE/          第 3 级
├─ FOURTH_PIPELINED_ADC_STAGE/         第 4 级
├─ FIFTH_PIPELINED_ADC_STAGE/          第 5 级：FLASH_ADC_5
├─ FLASH_ADC1..4, FLASH_ADC_5/         各级 flash
├─ RESIDUE_CALCULUS1..4/               各级 DAC/残差计算
├─ AMP12/13/16/18/                     残差放大器
├─ REFERENCE_CIRCUIT/, VREF_GEN/, VCM_GEN/
├─ CLOCK_DRIVER/, CLK_STABILIZER/, CLOCK_LATCH/
├─ TRIMMING_CTRL/, TRIMMING_CALIBRATION1..5/, FUSE_SEL/
└─ ERROR_CORRECT_1/2/, CORRECTION LOGIC（顶层）
```

### LTC2255_pipeline

```text
techrevzwb/LTC2255_pipeline/LTC2255/
├─ Top/schematic/sch.oa                 顶层：INPUT_SH + STAGE1 + STAGE2 + 参考/时钟
├─ INPUT_SH/                           输入采样保持
├─ PIPELINED_ADC_STAGE1/               首级：ADC1 + DAC1 + AMPLIFIER1 + ENC1
├─ PIPELINED_ADC_STAGE2/               末级：ADC2 + ENC2
├─ ADC1/, ADC2/                        flash 子 ADC
├─ DAC1/                               开关电容 DAC
├─ AMPLIFIER1/, AMP1..6/               残差放大器
├─ ENC1/, ENC2/, LATCH/                编码/锁存
├─ FLEXIBLE_REFERENCE/, BANDGAP/, REF_BUF/
├─ CLK_BUF/, CLK_BUF1/2/, CMFB/
└─ RANGE_SELECT/, BYPASS/, PAD_AIN_P/N/
```

### pipeline/Pipelined_ADC

```text
techrevzwb/pipeline/Pipelined_ADC/
├─ ADC_TOP/schematic/sch.oa             顶层：SHA + STAGE_1to6 + Flash_ADC + IBIAS
├─ SHA/, SHA_1/, OPA_SHA/              采样保持
├─ STAGE_1to6/                         1.5 位级：sub_ADC + sub_DAC + OTA + SC_CMFB + encoder
├─ sub_ADC/, sub_DAC/, encoder/        1.5 位子 ADC/DAC/编码
├─ Flash_ADC/                          末级 2 位 flash
├─ OTA/, OTA_high_gain/, OTA_wi_idea_cmfb/, SC_CMFB/
├─ Bootstrapped_switch/, Switch_comp*/ 自举开关/相位开关
├─ Digital_correction/                 DFF + 半加/全加器
├─ Testbench_ADC_TOP/                  fs=100M, 1Vpp, 512 点 FFT
└─ FFT_analysis.jpg                    100MS/s、约 6.93MHz 输入的 FFT
```

---

## 7. 证据与边界

- LTC2217 数据手册：`techrevzwb/芯片说明/LTC2217.pdf`；5 级、7 周期、16 位、2.75Vpp、1.19W、81.3dBFS、100dB SFDR、85fs、dither/randomizer。
- LTC2255 数据手册：`techrevzwb/芯片说明/LTC2255.pdf`；6 级、5 周期、14 位、1–2Vpp、395mW、72.4dB SNR、88dB SFDR、占空比稳定器。
- OA 层次：`Top/schematic/sch.oa`、各级 `schematic/sch.oa`；用可打印字符串提取实例/单元/引脚名，不能替代 Virtuoso 打开原图。
- 测试台：`Testbench_ADC_TOP/spectre_state1/variables.state` 给出 `fs=100M`、`vin_dc=500m`、`vi_ac=500m`；`analyses.state` 给出 `stop=7u`、`maxstep=40p`。
- 位分配（4 位/级、4+3 位、1.5 位/级）是从数据手册位数、级数、比较器/判决线数量推断；正式结论需在 Virtuoso 中核对 `DEC_*`、`ENC*`、`Digital_correction` 的位宽。
