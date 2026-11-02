# 证据说明

`plant_coefficient_check_A_damping.m` / `plant_coefficient_check_B_split.m` 是**独立于任何文献排版符号**的自洽性检查：
直接积分两自由度线性振子，用恰好一个载波周期的滑动平均解调，按 `HRG_WA_v46_simulate.m` 自己的定义构造 `E,Q,R,S,θ`，
再数值微分与 `local_plant_step` 的右端逐项拟合。

- Case A（只有阻尼各向异性，Δf=0）：θ̇ 最佳拟合系数 **k=0.2500**，代码写 0.5。
- Case B（只有频裂）：θ̇ 拟合 **−3.1413e−5 = −0.25×splitRad**，代码写 **+0.5×splitRad**；
  Q̇ 拟合系数 1.05e−4，代码写 2×splitRad=2.51e−4。
- Ė 方程量级一致（比值 0.89，含未清零的数值偏差）。

运行方式：`matlab -batch "run('evidence/plant_coefficient_check_A_damping.m')"`（需 MATLAB，单文件约 20 s）。
控制台输出见 `plant_coefficient_check_output.txt`。

边界：这是慢变量模型的自洽性检查，不是对 Lynch 原文的逐页核对；文献层结论以 `压电全角验证总书第五版` 的逐式转写为准。


