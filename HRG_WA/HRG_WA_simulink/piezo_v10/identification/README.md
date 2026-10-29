# V10离线测试辨识研究

详见工程根目录`V10压电表头_无厂家参数的测试辨识与回填方案.md`。原V10验收不更新。

Python NumPy合成测试：

```powershell
python HRG_WA_simulink/piezo_v10/identification/identify_fixture.py
```

MATLAB：

```matlab
addpath('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10/identification')
p10_verify_identified
```

Python验证5项，MATLAB闭环重放4项。未做新一次Simulink全量验收，不改旧.slx。仅当另行确认物理标尺、B和工作边界后，才可使用`p10_apply_identified`产生配置，再传给`p10_build(p)`；应另存实验模型，避免覆盖旧封存文件。

`identified_profile.json`明确为合成辨识，B和额定限值保持null；`synthetic_complete_profile.json`仅是MATLAB测试显式补充夹具条件的临时配置，虽纳入版本记录，也不可用于实物。Cs之外的显著介电色散、漏电、多端口误差和负载去嵌需进一步建模。

`leakage_S`在此研究接口仅记录。当前V10物理plant没有单独漏电支路；回填器在它相对读取电导不可忽略时拒绝导入，而不是悄悄略去。实测数据还需置信区间、幅度/温度留出验证与多模态拟合，不能用本次极小的合成误差替代。
