# V10.1 压电闭环修订

本目录是V10的独立修订入口，旧V10、辨识分支、电荷域分支及其验收字节保留。所有表头数值、标定参考与安全限值均为**合成测试设定**，没有真实表头测量或额定电压授权。

MATLAB可直接执行：

```matlab
addpath('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10/revision_v10_1');
out = p101_demo;                % 新载波闭环；Scope和模型窗口保留
p101_run_all;                  % MATLAB/Simulink全套验收，重建新模型
q = p101_envelope_config;
q.virtual_rate = 2;
low = p101_demo_low_rate(q);    % 理想包络虚拟进动研究；不代表载波Cp=2已验证
```

已交付两个SLX：`models/hrg_wa_v10_1_piezo.slx`（完整载波闭环，10个Scope、2个Spectrum Analyzer）和 `models/hrg_wa_v10_1_low_rate.slx`（300s低速包络研究）。后者在本目录已加入MATLAB路径后可直接打开，或执行 `p101_build_low_rate` 重建，再 `sim('hrg_wa_v10_1_low_rate')`。双击观察器可打开各节点波形；载波谱单位为dBV。

从工程根目录执行 `python HRG_WA_simulink/piezo_v10/revision_v10_1/run_all.py --matlab D:/matlab/bin/matlab.exe`，会重建全部合成标定/辨识/温漂数据、执行MATLAB及独立Python验收，并生成结果图。需要MATLAB、Simulink、DSP System Toolbox及Python/NumPy。脚本遇到失败立即退出，不自动提交、推送或重新封存。

仅核查已交付字节与证据执行 `python HRG_WA_simulink/piezo_v10/revision_v10_1/check_delivery.py`。重建SLX可能产生不同内部元数据，因此完整重建后应重新审查，而非自动覆盖已验收manifest。

已实现测量合同：

- ADC/DAC采用有符号midtread码域 `-2^(N-1)..2^(N-1)-1`，与物理电压限制取整数域交集；正满量程不能多出一个码。
- 初始化I/Q为零且无效；完整窗口后检查能量、线性驻波可观性D/E、有限值、标定条件数和ADC/DAC截幅。无效窗口冻结积分并撤去驱动力，禁止给出伪有效角度。
- 窗口包含N个输入样本；center是样本时刻均值，end是最后输入时刻，available=end+Ts是Outputs-before-Update首次发布时刻。导航按center评分，每帧只计一次，断效不跨段解包；不根据真值调偏移/延迟或挑分支。
- 显式模型含本征机械阻尼、任意刚度/阻尼主轴及传感负载状态。多负载辨识输出本征参数；禁止把加载后ring-down衰减率直接回填本征阻尼。
- 检测、执行及阻断机械运动的馈通标定分别使用独立已知输入，独立随机种子留出验证。没有独立参考时，只能识别组合传函，不能宣称拆出了全部增益。

诊断输出18列依次为 `Ix,Iy,Qx,Qy,freq,E,linearity,valid,frame_id,start,end,center,available,DAC_clip_count,ADC_clip,Cp_command,age,frame_DAC_clip`。坐标为运动电荷C，不需要虚构质量或N/V、C/m。B未知时仅允许静态电学工况，整机角度/率不能被标成已校准。

已完成六项优先级的基础实现与验证，具体公式、计算、证据和限制见 [实现与验证说明](实现与验证说明.md)。共95项登记检查通过，其中MATLAB/Simulink54项、Python41项；检查数不等于95个独立物理实验。Simulink与MATLAB逐拍replay共用控制tick；另有独立ODE、NumPy物理矩阵、能量平衡、包络复算及Monte Carlo提供不同证据。

基线有效帧800/800、稳态全角RMS 0.003757°、建幅0.131488s、无DAC截幅。原始SI量纲离散化会引入虚假低速漂移，已改为无量纲离散化并通过独立ODE核对。ADC输入白噪声进入完整反馈环；随机时钟误差目前在局部预算中验证。低速虚拟进动保留残差，理想包络Cp=2与载波Cp=0.2的验证范围明确区分。温漂采用一阶标量参数及二阶复数标定矩阵的离线拟合；保留全一阶失败反例，不启用未经验证的PIR、在线辨识或分时复用。

`p101_config.m` 是该修订合成仿真的参数入口。`p101_apply_profile.m` 将端口辨识结果映射到配置，真实B未知时保持未知且只允许静态测试；额定电压仍需外部确认。`p101_temperature_apply.m` 在已辨识温区内应用离线温漂，禁止外推。执行标定含ZOH，修改Ts必须重新标定。

参考推导见工程根目录知识体系总书C03–C23及经典第五版R16–R35；新实现与文献印刷式的极性差异以独立注入验收为准。
