# V10.1 压电闭环修订

本目录是V10的独立修订入口，旧V10、辨识分支、电荷域分支及其验收字节保留。所有表头数值、标定参考与安全限值均为**合成测试设定**，没有真实表头测量或额定电压授权。

MATLAB进入本目录后执行 `p101_demo`，打开新模型 `models/hrg_wa_v10_1_piezo.slx` 及持续显示的Scope；仿真结束保留窗口，不保存覆盖已验收SLX。`p101_verify_measurement` 执行完整MATLAB/Simulink测量验收。Python先执行 `fit_calibration.py`、`identify_multiload.py`，再执行 `verify_measurement.py`；标定文件已随Git跟踪。

已实现测量合同：

- ADC/DAC采用有符号midtread码域 `-2^(N-1)..2^(N-1)-1`，与物理电压限制取整数域交集；正满量程不能多出一个码。
- 初始化I/Q为零且无效；完整窗口后检查能量、线性驻波可观性D/E、有限值、标定条件数和ADC/DAC截幅。无效窗口冻结积分并撤去驱动力，禁止给出伪有效角度。
- 窗口包含N个输入样本；center是样本时刻均值，end是最后输入时刻，available=end+Ts是Outputs-before-Update首次发布时刻。导航按center评分，每帧只计一次，断效不跨段解包；不根据真值调偏移/延迟或挑分支。
- 显式模型含本征机械阻尼、任意刚度/阻尼主轴及传感负载状态。多负载辨识输出本征参数；禁止把加载后ring-down衰减率直接回填本征阻尼。
- 检测、执行及阻断机械运动的馈通标定分别使用独立已知输入，独立随机种子留出验证。没有独立参考时，只能识别组合传函，不能宣称拆出了全部增益。

诊断输出18列依次为 `Ix,Iy,Qx,Qy,freq,E,linearity,valid,frame_id,start,end,center,available,DAC_clip_count,ADC_clip,Cp_command,age,frame_DAC_clip`。坐标为运动电荷C，不需要虚构质量或N/V、C/m。B未知时仅允许静态电学工况，整机角度/率不能被标成已校准。

六项优先级的进一步低速、预算、温漂验证及最终验收结果随本目录后续证据登记；不启用未经验证的PIR、在线辨识或分时复用。参考推导见工程根目录知识体系总书C03–C23及经典第五版R16–R35；新实现与文献印刷式的极性差异以独立注入验收为准。
