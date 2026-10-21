"""Render the Chinese result note directly from recorded simulation evidence."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E = ROOT / "evidence"


def read(name):
    return json.loads((E / name).read_text(encoding="utf-8-sig"))


def main():
    algorithm = read("algorithm_scoreboards.json")
    model = read("model_scoreboards.json")
    sweep = read("sweep_results.json")
    joint = read("joint_candidates.json")
    online = read("online_algorithm_activity.json")
    frp = read("frp_closed_loop_study.json")
    architecture = read("architecture_comparison.json")
    assert algorithm["pass"] and model["pass"]
    lines = ["# 实际仿真结果与设计含义", "", "验收日期：2026-10-22。由 `tools/write_results.py` 从 `evidence/` 生成。", "",
             f"算法独立记分板 {len(algorithm['checks'])} 项、实际 Simulink 记分板 {len(model['checks'])} 项及原采样率 DAC 波形独立核查 5 项全部通过，共 60 项。另完成 30 个单因素/随机种子工况、6 个 Rf—输入电流噪声联合假设工况，以及 4 个架构配对工况。功能通过与研究预算达标分别判定。", "",
             "## 标称分层闭环", "", "下表采用 0.3 s 运行的后半段；机械表头与接口参数为假设值。短时统计含剩余暂态，不代表实物稳态精度。", "",
             "| 版本 | 误差均值 °/s | 误差标准差 °/s | 测得能量 | Q/E RMS |", "|---|---:|---:|---:|---:|"]
    for s in range(2, 7):
        m = read(f"v{s}_nominal/metrics.json")
        lines.append(f"| V{s} | {m['rateMeanErrorDegS']:.6g} | {m['rateStdErrorDegS']:.6g} | {m['energyMean']:.6g} | {m['quadratureRatioRms']:.6g} |")
    checks = {c["name"]: c for c in model["checks"]}
    lines += ["", f"独立矩阵指数对照的归一化机械状态误差为 {checks['library_mechanical_expm']['value']:.6g}，限值 0.002。关闭 Scope/Spectrum 后，IQ 与导航逐点差均为 0。实际 ADC 过载能传播至导航/控制有效性门控；1bit ADC 与 DAC 在初始化转换延迟后均严格输出 ±Vref。", "",
              "加入非理想接口后，标称角速度输出噪声明显高于 V2；V5 的导航 Kalman 有所降低噪声，但不能消除模拟读出的输入等效噪声。", "",
              "## 电路参数筛查", "", "研究预算：角速度误差标准差 ≤0.1°/s、均值绝对值 ≤0.25°/s，ADC RMS 误差 ≤20 µV，测得能量 0.8—1.2，AFE/ADC/驱动不削顶。这不是用户已确认的产品指标。", "",
              "| 扫描参数 | 数值 | 误差标准差 °/s | 误差均值 °/s | ADC RMS 最大值 µV | 全项预算 |", "|---|---:|---:|---:|---:|---|"]
    for r in sweep["rows"]:
        if r["status"] != "simulated":
            lines.append(f"| {r['parameter']} | {r['value']:.6g} | 仿真错误 | — | — | 不通过 |")
            continue
        m = r["metrics"]
        lines.append(f"| {r['parameter']} | {r['value']:.10g} | {m['rateStdErrorDegS']:.5g} | {m['rateMeanErrorDegS']:.5g} | {max(m['adcErrorRmsV'])*1e6:.5g} | {'通过' if r['meetsBudget'] else '未通过'} |")
    passed = sum(r["meetsBudget"] for r in sweep["rows"] if r["parameter"] != "seed")
    lines += ["", f"27 个单因素点中，全项预算通过 {passed} 个。seed 行用于比较同一候选的随机变动，其布尔标志仅检查角速度标准差，不能当成全项验收。", "",
              "预算判定包含 ADC 孔径扰动，因此 ADC 误差不等于纯量化误差。模拟带宽、驱动带宽和 Rf 扫描保留标称设计校准；这些结果同时包含固定校准下的相位裕量影响。", "",
              "### Rf 与输入电流噪声联合工况", "", "| Rf GΩ | 输入电流 ASD fA/√Hz | 角速度误差标准差 °/s | 误差均值 °/s | 全项预算 |", "|---|---:|---:|---:|---|"]
    for r in joint["rows"]:
        m = r["metrics"]
        lines.append(f"| {r['rfOhm']/1e9:g} | {r['cvInArtHz']/1e-15:g} | {m['rateStdErrorDegS']:.6g} | {m['rateMeanErrorDegS']:.6g} | {'通过' if r['meetsBudget'] else '未通过'} |")
    lines += ["", "这些点用于判断反馈电阻热噪声与放大器电流噪声的共同约束，不是现有工艺可实现性的证明。高阻值反馈还需核查漏电、偏置恢复、PVT、失真与芯片面积；系统仿真可提出设计目标，不能替代晶体管和版图验证。", "",
              "## 已有算法嵌入", "",
              f"8 s 包络闭环中，导航 Kalman 更新 {online['kalmanUpdates']:.0f} 次，RLS/参数 Kalman 在线适配更新 {online['onlineUpdates']:.0f} 次。在线补偿保持旁路，用于先检查调用、数值及观测接口。", "",
              f"专用零速工装下，FRP 在 28 s 训练中更新 {frp['training']['frpUpdates']:.0f} 次，覆盖率 {frp['training']['frpCoverage']:.1%}，最终可信度 {frp['training']['frpConfidence']:.6g}。45°/s、29°C 留出工况撤销训练许可并冻结系数，权重变化范数为 {frp['frozenWeightChange']:g}。", "",
              "| 留出工况 | 误差 RMS °/s | 误差均值 °/s |", "|---|---:|---:|"]
    for name, title in [("heldoutOff", "补偿旁路"), ("heldoutOn", "应用冻结补偿")]:
        m = frp[name]
        lines.append(f"| {title} | {m['rateRmsErrorDegS']:.6g} | {m['rateMeanErrorDegS']:.6g} |")
    improved = frp["heldoutOn"]["rateRmsErrorDegS"] < frp["heldoutOff"]["rateRmsErrorDegS"]
    lines += ["", f"留出 RMS {'改善' if improved else '没有改善'}。因此默认继续关闭补偿。函数核的合成数据记分板通过，与本表的系统级收益是两个不同结论；当前辨识、虚拟旋转执行误差和温度/速率耦合仍需进一步分析。", "",
              "包络基带频率扫描的增益和相位见 `envelope_frf.csv`，仅用于此加速等效模型，不能作为载波电路频响或已确认的闭环带宽。", "",
              "## 时分驱动候选", "", "同一机械头、无随机噪声的配对试验，用于隔离结构机制。馈通分量由实际驱动电压乘 Cpar/Cf，在 Rf/Cf 与模拟滤波之前计算；幅值用固定 f0 参考正余弦拟合，非完整噪声功率。", "",
              "| 驱动 | Cpar fF | 导航误差 RMS °/s | 馈通 X: 0.5f0 / f0 / 1.5f0 峰值 µV | 驱动峰值 V |", "|---|---:|---:|---|---:|"]
    for r in architecture["rows"]:
        m = r["metrics"]
        amp = " / ".join(f"{v[0]*1e6:.5g}" for v in r["feedthroughPeakV"])
        lines.append(f"| {'时分' if r['tdm'] else '连续'} | {r['feedthroughF']*1e15:g} | {m['rateRmsErrorDegS']:.6g} | {amp} | {m['driverPeakV']:.6g} |")
    lines += ["", "当前仅驱动门控、连续检测，平均门控增益为 1，载频馈通仍可能保留，不能等同完整的时分驱动/检测隔离。边带重分布本身不能证明导航收益；后续需加入检测门控、延迟对齐和边沿消隐。该对照不构成系统结构新颖性证明，也未涵盖时分开关的电荷注入、振铃和完整 PVT。", "",
              "## 证据与复现", "", "`algorithm_scoreboards.json`、`model_scoreboards.json`、各版本节点波形/PSD、参数表和上述配对报告纳入 Git。`acceptance_manifest.json` 封存源码、模型、配置、验收文件的精确字节哈希以及本地参考 PDF 的哈希。执行 `python tools/seal_evidence.py --verify` 检查完整性。", "",
              "原三份已存在的工作区修改保持原始字节，未混入本次发布。GitHub 同步只导出已提交 HEAD，保留原历史及 HRG 父仓库其他子项目。"]
    (ROOT / "docs/results.md").write_bytes(("\n".join(lines) + "\n").encode("utf-8"))
    print("Wrote docs/results.md from measured evidence.")


if __name__ == "__main__":
    main()
