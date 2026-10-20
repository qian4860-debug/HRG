# 表头配置与参数生成

现在只需编辑一份JSON表头档案。默认入口为 `head_default.json`，其中数值仍是**未实测的仿真基线**，`measurement_status=assumed`。不要把它当作实际器件标定结果。每只表头复制一份文件，用独立 `head_id` 保存。

以下命令均在 `HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA` 目录执行。生成器只使用Python标准库，不连接或写入任何硬件。

## 以后拿到参数时怎么操作

```powershell
Copy-Item config/head_default.json config/head_001.json
# 编辑 head_001.json：填写实际参数、head_id、测量状态和来源说明。
python tools/head_config.py generate config/head_001.json --out generated/head_001
python tools/head_config.py check config/head_001.json
```

`check` 返回：

| 退出码 | 含义 | 下一步 |
|---|---|---|
| 0 | 编译字段和当前RTL源码与完成构建记录一致 | 使用新生成的MATLAB参数/SPI计划，再验证该表头闭环性能 |
| 2 | 需要重新编译，或没有完成构建记录 | 查看JSON结果中具体变化字段，然后执行下面的构建命令 |
| 3 | 配置非法、格式不支持或证据无效 | 修正报告的问题；不要忽略错误继续加载 |

确需重新编译时：

```powershell
./config/build_head.ps1 -Config config/head_001.json
```

这个显式构建命令才会将目标头文件装载到 `src/hrg_head_config.vh`。它依次生成文件、记录构建前源码哈希、通过真实SPI管脚仿真检查配置、执行Vivado RTL综合展开，再记录 `config/compiled_rtl.json`。若是当前基线编译参数，还会运行已有全套scoreboard；非基线参数不会冒用旧的固定参考向量，必须另做该表头的闭环数值验收。

`generate` 本身只创建目标目录中的候选文件，不修改正在使用的RTL头文件，也不会将“生成成功”当成“已编译成功”。重新编译记录不能用 `generate` 刷新覆盖；必须有构建开始之后的新仿真/综合通过记录，且构建期间RTL没有变化。

## 文件内容与分类

| 配置区域 | 内容 | 生效位置 |
|---|---|---|
| `mechanical` | 频率、Q、Bryan、目标能量、初值、阻尼与刚度误差 | MATLAB；其中频率/Bryan/目标能量另生成SPI值，f0/Q/目标能量用于估算平均阻尼保持驱动 |
| `detection`、`drive` | 检测/驱动矩阵、相位、偏置、DAC实际增益 | MATLAB物理模型；当前RTL没有相应在线矩阵补偿，生成器不会声称已写入硬件 |
| `runtime` | 双PI增益、虚拟进动、RUN保持驱动、速率低通、使能位 | SPI，不要求重编译 |
| `build` | 采样率、控制率、流水线深度、限幅、斜率、DPLL系数、状态机时序和门限、DAC量程 | 生成RTL宏，需要重新编译 |
| `architecture` | ADC/DAC位宽、ADC归一化、NCO位宽、滤波拓扑 | 当前固定实现；改变会明确报错，需要先修改源码/数值合同 |

编译指纹对整个 `build` 和 `architecture` 计算，记录还包含全部RTL及头文件内容的哈希。即使头文件中的ID没改，手工修改RTL或生成常量也会使旧构建记录失效。比较基于编译参数，不按表头名字判断，因此两只表头可以共享同一已编译版本。

`build.legacy_defaults` 是兼容旧软件“零选默认值”协议的冷启动默认码，不是本次要写入的运行参数。一般保持原样。它们也是编译字段，修改后必须重编译。

## 自动生成的文件

每个 `generated/<head_id>/` 包含：

- `hrg_head_params.m`：MATLAB参数函数，调用原 `HRG_WA_v46_params(u)` 完成单位转换及派生量重算。
- `spi_words.json`：寄存器地址、请求物理量、定点码、量化后数值及小端4字节。
- `spi_plan.json`：有顺序的初始化计划，含等待ADC样本的操作。
- `spi_commands.txt`：操作码1为SPI单字节写，操作码2为等待指定有效ADC样本数。
- `spi_config.h`：等价C命令数组；`HRG_PROFILE_REQUIRES_RECOMPILE` 表示生成时的构建兼容状态。
- `hrg_head_config.vh`：待编译的宏定义，禁止手工修改。
- `manifest.json`：配置指纹、编译分类/差异、派生常量和验证边界。

MATLAB使用方法：模型文件位于RTL工程目录 `HRG_WA` 的上一级。在RTL工程目录作为当前工作目录时执行：

```matlab
addpath('..');
addpath(fullfile('generated','head_001'));
p = hrg_head_params('rtl');   % 开启位真前端，关闭本轮RTL没有实现的补偿/估计算法
% 或 p = hrg_head_params('model'); % 保留原模型相应功能开关
r = HRG_WA_v46_simulate(p);
```

函数从原用户配置继承未在表头档案中覆盖的仿真场景、噪声等设置，不覆盖原始模型源码。物理增益在MATLAB中保留输入实数；SPI使用显式定点量化值，可从 `spi_words.json` 比较量化误差。该函数不自动调参，也不保证新表头已经稳定。

固定虚拟进动在MATLAB中映射为频率0、相位π/2的常量激励，并按CTRL的全局/虚拟使能位开关。手动RUN保持驱动及其余CTRL环路使能仅记录在 `p.head`；原MATLAB状态机仍有自己的机械前馈和模式逻辑，不能把这份参数覆盖文件当作任意SPI控制序列的逐拍仿真器。

## SPI计划与零值

生成的计划顺序是：选择page0 → CTRL=0 → 写 `0x04=0x48524731` → 写全部运行寄存器 → 等待R+2个有效ADC样本 → 写最终CTRL。

`0x04` 是新增的显式值标记。启用后0就是实际零，允许关闭积分项或设置零保持驱动；未写该标记的旧软件仍使用原有的零选默认值语义。暖机样本让DPLL在关闭状态装载配置基准FCW，避免非5 kHz表头从旧复位频率开始。

每个 `write8` 是独立CS事务：地址字节最高位为0，随后发送一个数据字节。不要将等待ADC样本的操作码当作SPI数据发出，也不要直接用4字节裸数据代替原SPI字节写协议。

`runtime.energy_hold=null` 时自动按 `2*pi*f0/Q*energy_target` 估算，表示归一化模型中的平均阻尼保持驱动；它不是电压，也没有自动补偿各向异性、驱动矩阵及温漂。实际表头可用标定后的控制量替换。`virtual_rate_rad_s` 的单位为弧度/秒，DAC虚拟进动满量程配置单位为度/秒。

能量锁定窗口和ACQUIRE判断已改为相对于当前SPI能量参考计算；不再写死在E=1附近。采样/控制率、CIC增益、积分步长、导航比例、斜率步长和起振计数均从生成头文件取得。

## 检查与限制

生成器会拒绝未知字段、重复JSON键、NaN、越界定点码、非整数抽取比、零品质因数、负Bryan系数、超出奈奎斯特的频率范围、不支持的位宽以及量程/限幅不一致。抽取比当前支持24～1024，命令流水线支持1～16拍；这些范围仍需实际综合与时序验证。

```powershell
# 编码、重编译判定、SPI集成、非默认时基数值测试及生成MATLAB文件验证
./tools/tests/run_config_tests.ps1
```

当前已测：默认SPI码与旧实现一致；一组6200 Hz/Bryan=0.3/Eref=1.2/零Ki/负正交保持驱动的SPI计划；一组80 kS/s、2 kHz控制率、四拍流水线的PI、DPLL、斜率及导航数值检查；默认完整scoreboard和RTL综合展开。

非默认编译配置也已实际执行一次完整的“改头文件—SPI集成检查—综合展开—记录构建”流程，并在完成后恢复默认配置重新回归。相关原始记录保存在 `evidence_20261018/`；非默认配置的记录明确标为配置集成检查，不代表其完整闭环性能已验收。

构建记录只核对本地RTL构建。没有读取实体芯片或FPGA的镜像ID，`hardware_image_identity_verified` 始终为false；没有执行映射、布局布线或面积/时序签核。非默认表头的闭环性能、真实模拟通道和器件误差仍需要独立验证。检测/驱动标定字段只进入模型，不能把生成SPI文件理解为这些误差已被硬件补偿。
